package com.noor.player.noor;

import android.content.Context;
import android.content.ContentValues;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import android.webkit.MimeTypeMap;
import android.os.Handler;
import android.os.Looper;
import com.yausername.youtubedl_android.YoutubeDL;
import com.yausername.youtubedl_android.YoutubeDLRequest;
import com.yausername.youtubedl_android.YoutubeDLResponse;
import com.yausername.ffmpeg.FFmpeg;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import org.json.JSONObject;
import java.io.File;
import java.io.FileInputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.atomic.AtomicBoolean;

/** Native extraction runs off the UI thread; no account/cookies are accessed. */
public final class OnlineMediaBridge implements MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private final Context context;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final AtomicBoolean busy = new AtomicBoolean(false);
    private final AtomicBoolean cancelled = new AtomicBoolean(false);
    private final MethodChannel methods;
    private final EventChannel events;
    private EventChannel.EventSink sink;
    private boolean prepared;
    private final String processId = "noor-" + java.util.UUID.randomUUID();

    public OnlineMediaBridge(Context context, BinaryMessenger messenger) {
        this.context = context;
        if (messenger == null) { methods = null; events = null; return; }
        methods = new MethodChannel(messenger, "noor/online_media");
        events = new EventChannel(messenger, "noor/online_progress");
        methods.setMethodCallHandler(this);
        events.setStreamHandler(this);
    }

    @Override public void onListen(Object args, EventChannel.EventSink sink) { this.sink = sink; }
    @Override public void onCancel(Object args) { sink = null; }

    @Override public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (call.method.equals("jobStatus")) {
            try { result.success(DownloadService.status(context)); }
            catch (Exception error) { result.error("state", error.toString(), null); }
            return;
        }
        if (call.method.startsWith("job")) {
            try {
                DownloadService.dispatch(context, call.method, (Map<String, Object>)call.arguments);
                result.success(null);
            } catch (Exception error) { result.error("download_service", error.toString(), null); }
            return;
        }
        if (call.method.equals("openDownloads")) {
            try {
                Uri folder = android.provider.DocumentsContract.buildDocumentUri(
                    "com.android.externalstorage.documents", "primary:Download/NOOR");
                android.content.Intent view = new android.content.Intent(android.content.Intent.ACTION_VIEW)
                    .setDataAndType(folder, android.provider.DocumentsContract.Document.MIME_TYPE_DIR)
                    .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK);
                try { context.startActivity(view); }
                catch (android.content.ActivityNotFoundException missing) {
                    context.startActivity(new android.content.Intent(android.app.DownloadManager.ACTION_VIEW_DOWNLOADS)
                        .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK));
                }
                result.success(null);
            } catch (Exception error) {
                result.error("folder_unavailable", "Open Downloads/NOOR in your file manager.", null);
            }
            return;
        }
        if (call.method.equals("exists")) {
            try (Cursor cursor = context.getContentResolver().query(Uri.parse(call.argument("uri")), new String[]{"_id"}, null, null, null)) {
                result.success(cursor == null ? null : cursor.moveToFirst());
            } catch (Exception error) { result.success(null); }
            return;
        }
        if (call.method.equals("canRead")) {
            String value = call.argument("uri");
            try (android.os.ParcelFileDescriptor fd = context.getContentResolver().openFileDescriptor(Uri.parse(value), "r")) {
                result.success(fd != null);
            } catch (Exception error) { result.success(false); }
            return;
        }
        if (call.method.equals("cancel")) {
            cancelled.set(true);
            YoutubeDL.getInstance().destroyProcessById(processId);
            result.success(null);
            return;
        }
        if (call.method.equals("engineVersion") || call.method.equals("updateEngine")) {
            boolean update = call.method.equals("updateEngine");
            // Only an update must exclude resolve/download; reading the version
            // just queues on the same single worker thread.
            if (update && !busy.compareAndSet(false, true)) {
                result.error("busy", "Another operation is already running.", null); return;
            }
            worker.execute(() -> {
                try {
                    prepare();
                    if (update) YoutubeDL.getInstance().updateYoutubeDL(context, YoutubeDL.UpdateChannel._STABLE);
                    String version = YoutubeDL.getInstance().versionName(context);
                    main.post(() -> result.success(version));
                } catch (Throwable error) {
                    String message = error.getMessage() == null ? error.toString() : error.getMessage();
                    main.post(() -> result.error("engine", message, null));
                } finally {
                    if (update) busy.set(false);
                }
            });
            return;
        }
        if (!call.method.equals("resolve") && !call.method.equals("download") && !call.method.equals("publish")
                && !call.method.equals("playlist")) {
            result.notImplemented(); return;
        }
        if (!busy.compareAndSet(false, true)) {
            result.error("busy", "Another operation is already running.", null); return;
        }
        cancelled.set(false);
        Runnable timeout = () -> {
            cancelled.set(true);
            YoutubeDL.getInstance().destroyProcessById(processId);
        };
        if (call.method.equals("resolve") || call.method.equals("playlist")) main.postDelayed(timeout, 600000);
        worker.execute(() -> {
            try {
                if (call.method.equals("publish")) {
                    Map<String, Object> published = publish(call);
                    main.post(() -> result.success(published));
                    return;
                }
                String url = call.argument("url");
                android.net.Uri uri = url == null ? android.net.Uri.EMPTY : android.net.Uri.parse(url);
                if (!("https".equals(uri.getScheme()) || "http".equals(uri.getScheme())) ||
                    uri.getHost() == null || uri.getUserInfo() != null) {
                    throw new IllegalArgumentException("Enter a valid public web link.");
                }
                prepare();
                if (cancelled.get()) throw new InterruptedException("Cancelled");
                YoutubeDLRequest request = new YoutubeDLRequest(url);
                request.addOption("--ignore-config");
                // A playlist listing must not also pass --no-playlist: option order is
                // not guaranteed by the request builder.
                if (!call.method.equals("playlist")) request.addOption("--no-playlist");
                request.addOption("--socket-timeout", "20");
                request.addOption("--retries", "1");
                request.addOption("--extractor-retries", "1");
                request.addOption("--max-filesize", "2G");
                Map<String, Object> output;
                if (call.method.equals("playlist")) {
                    request.addOption("--yes-playlist");
                    request.addOption("--flat-playlist");
                    request.addOption("--playlist-end", "500");
                    request.addOption("--dump-single-json");
                    YoutubeDLResponse response = YoutubeDL.getInstance().execute(request, processId, null);
                    JSONObject data = new JSONObject(response.getOut());
                    output = new HashMap<>();
                    output.put("_type", data.optString("_type"));
                    output.put("title", data.optString("title"));
                    java.util.List<Map<String, Object>> entries = new java.util.ArrayList<>();
                    org.json.JSONArray list = data.optJSONArray("entries");
                    if (list != null) for (int i = 0; i < list.length(); i++) {
                        JSONObject e = list.optJSONObject(i);
                        if (e == null) continue;
                        Map<String, Object> entry = new HashMap<>();
                        for (String key : new String[]{"_type", "url", "webpage_url", "title"})
                            if (e.has(key) && !e.isNull(key)) entry.put(key, e.optString(key));
                        if (e.has("duration") && !e.isNull("duration")) entry.put("duration", e.optDouble("duration"));
                        entries.add(entry);
                    }
                    output.put("entries", entries);
                } else if (call.method.equals("resolve")) {
                    request.addOption("--format", "best[height<=720]/best");
                    request.addOption("--dump-single-json");
                    request.addOption("--skip-download");
                    YoutubeDLResponse response = YoutubeDL.getInstance().execute(request, processId, null);
                    JSONObject data = new JSONObject(response.getOut());
                    output = new HashMap<>();
                    output.put("url", data.optString("url"));
                    output.put("title", data.optString("title", uri.getHost()));
                    Map<String, Object> headers = new HashMap<>();
                    JSONObject raw = data.optJSONObject("http_headers");
                    if (raw != null) {
                        Iterator<String> keys = raw.keys();
                        while (keys.hasNext()) {
                            String key = keys.next(); headers.put(key, raw.optString(key));
                        }
                    }
                    output.put("http_headers", headers);
                    // Compact format list for the quality picker (see LinkQualities).
                    output.put("duration", data.isNull("duration") ? null : data.optDouble("duration"));
                    java.util.List<Map<String, Object>> formats = new java.util.ArrayList<>();
                    org.json.JSONArray list = data.optJSONArray("formats");
                    if (list != null) for (int i = 0; i < list.length(); i++) {
                        JSONObject f = list.optJSONObject(i);
                        if (f == null) continue;
                        Map<String, Object> format = new HashMap<>();
                        for (String key : new String[]{"width", "height", "filesize", "filesize_approx", "tbr"})
                            if (f.has(key) && !f.isNull(key)) format.put(key, f.optDouble(key));
                        for (String key : new String[]{"vcodec", "acodec"})
                            if (f.has(key) && !f.isNull(key)) format.put(key, f.optString(key));
                        formats.add(format);
                    }
                    output.put("formats", formats);
                } else {
                    Boolean audioValue = call.argument("audioOnly");
                    boolean audioOnly = Boolean.TRUE.equals(audioValue);
                    Integer requestedHeight = call.argument("maxHeight");
                    int height = requestedHeight == null ? 720 : requestedHeight;
                    Integer requestedBitrate = call.argument("audioBitrate");
                    int bitrate = requestedBitrate == null ? 192 : requestedBitrate;
                    if (!java.util.Arrays.asList(0,2160,1440,1080,720,480,360,240,144).contains(height) ||
                        !java.util.Arrays.asList(128,192,320).contains(bitrate)) throw new IllegalArgumentException("Invalid quality");
                    String format = audioOnly ? "ba/b" : "bv*+ba/b";
                    request.addOption("--format", format);
                    if (audioOnly) {
                        request.addOption("--extract-audio");
                        request.addOption("--audio-format", "mp3");
                        request.addOption("--audio-quality", bitrate + "K");
                    } else {
                        request.addOption("--format-sort", height == 0 ? "res" : "res:" + height);
                        request.addOption("--merge-output-format", "mkv");
                        if (Boolean.TRUE.equals(call.argument("subtitles"))) {
                            // Same as DownloadOptions.arguments (Dart).
                            request.addOption("--write-subs");
                            request.addOption("--sub-langs", "ar.*,en.*");
                            request.addOption("--embed-subs");
                        }
                    }
                    String path = call.argument("directory");
                    if (path == null) throw new IllegalArgumentException("No output directory");
                    File directory = new File(path).getCanonicalFile();
                    String root = new File(context.getFilesDir(), "downloads").getCanonicalPath() + File.separator;
                    if (!directory.getPath().startsWith(root)) throw new IllegalArgumentException("Invalid output directory");
                    directory.mkdirs();
                    request.addOption("--continue");
                    request.addOption("--part");
                    request.addOption("--write-info-json");
                    request.addOption("--newline");
                    request.addOption("--output", new File(directory, "media.%(ext)s").getAbsolutePath());
                    YoutubeDL.getInstance().execute(request, processId, (percent, eta, line) -> {
                        main.post(() -> {
                            if (sink != null) {
                                Map<String, Object> progress = new HashMap<>();
                                progress.put("progress", percent);
                                progress.put("eta", eta);
                                Double speed = speedOf(line);
                                if (speed != null) progress.put("speed", speed);
                                sink.success(progress);
                            }
                        });
                        return kotlin.Unit.INSTANCE;
                    });
                    File media = null;
                    File[] files = directory.listFiles();
                    if (files != null) for (File file : files) {
                        if (file.getName().matches("media\\.(mp4|webm|mkv|mov|avi|flv|wmv|mpeg|mpg|ts|m4v|3gp|mp3|m4a|opus|ogg|wav|flac|aac)") && file.length() > 0) {
                            media = file; break;
                        }
                    }
                    if (media == null) throw new IllegalStateException("No downloadable video was returned. Try Streaming.");
                    String title = uri.getHost();
                    File info = new File(directory, "media.info.json");
                    if (info.exists()) {
                        title = new JSONObject(new String(Files.readAllBytes(info.toPath()), StandardCharsets.UTF_8))
                            .optString("title", title);
                    }
                    output = new HashMap<>();
                    output.put("path", media.getAbsolutePath()); output.put("title", title);
                }
                if (cancelled.get()) throw new InterruptedException("Cancelled");
                main.post(() -> result.success(output));
            } catch (Throwable error) {
                String message = error.getMessage() == null ? error.toString() : error.getMessage();
                if (message.length() > 1200) message = message.substring(message.length() - 1200);
                final String detail = message;
                main.post(() -> result.error(cancelled.get() ? "cancelled" : "source_unavailable", detail, null));
            } finally {
                busy.set(false);
                main.removeCallbacks(timeout);
            }
        });
    }

    private static final java.util.regex.Pattern SPEED =
        java.util.regex.Pattern.compile("at\\s+~?\\s*([\\d.]+)\\s*([KMGT]?)(i?)B/s");

    /** Bytes per second from a progress line such as "... at 1.23MiB/s ETA 00:07". */
    static Double speedOf(String line) {
        if (line == null) return null;
        java.util.regex.Matcher m = SPEED.matcher(line);
        if (!m.find()) return null;
        double base = m.group(3).isEmpty() ? 1000 : 1024;
        int power = "KMGT".indexOf(m.group(2)) + 1; // "" -> 0
        try { return Double.parseDouble(m.group(1)) * Math.pow(base, power); }
        catch (NumberFormatException e) { return null; }
    }

    private Map<String, Object> publish(MethodCall call) throws Exception {
        if (Build.VERSION.SDK_INT < 29) {
            throw new IllegalStateException("Saving to public Downloads requires Android 10 or newer.");
        }
        String path = call.argument("path");
        String name = call.argument("name");
        if (path == null || name == null || name.isEmpty()) throw new IllegalArgumentException("Missing file");
        File source = new File(path).getCanonicalFile();
        String root = new File(context.getFilesDir(), "downloads").getCanonicalPath() + File.separator;
        if (!source.getPath().startsWith(root) || !source.isFile() || source.length() == 0) {
            throw new IllegalArgumentException("Invalid NOOR download");
        }
        // A durable receipt makes a publish retry idempotent after process death.
        boolean durable = Boolean.TRUE.equals(call.argument("durable"));
        android.util.AtomicFile receipt = new android.util.AtomicFile(new File(source.getParentFile(), "published.json"));
        if (durable && receipt.getBaseFile().exists()) {
            JSONObject old = new JSONObject(new String(receipt.readFully(), StandardCharsets.UTF_8));
            Uri oldUri = Uri.parse(old.getString("uri"));
            try (Cursor cursor = context.getContentResolver().query(oldUri,
                    new String[]{MediaStore.MediaColumns.IS_PENDING, MediaStore.MediaColumns.SIZE, MediaStore.MediaColumns.DISPLAY_NAME}, null, null, null)) {
                if (cursor != null && cursor.moveToFirst()) {
                    if (cursor.getInt(0) == 0 && cursor.getLong(1) == source.length()) {
                        Map<String,Object> existing = new HashMap<>();
                        existing.put("uri", oldUri.toString()); existing.put("location", "Download/NOOR/" + cursor.getString(2));
                        return existing;
                    }
                    context.getContentResolver().delete(oldUri, null, null);
                }
            }
            receipt.delete();
        }
        name = name.replaceAll("[<>:\"/\\\\|?*\\p{Cntrl}]", "_");
        String extension = name.substring(name.lastIndexOf('.') + 1).toLowerCase(java.util.Locale.ROOT);
        String mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
        if (mime == null) mime = "application/octet-stream";
        ContentValues values = new ContentValues();
        values.put(MediaStore.MediaColumns.DISPLAY_NAME, name);
        values.put(MediaStore.MediaColumns.MIME_TYPE, mime);
        values.put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/NOOR");
        values.put(MediaStore.MediaColumns.IS_PENDING, 1);
        Uri target = context.getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values);
        if (target == null) throw new java.io.IOException("Could not create public download");
        try {
            if (durable) {
                java.io.FileOutputStream record = receipt.startWrite();
                try {
                    record.write(new JSONObject().put("uri", target.toString()).toString().getBytes(StandardCharsets.UTF_8));
                    receipt.finishWrite(record);
                } catch (Exception error) { receipt.failWrite(record); throw error; }
            }
            try (FileInputStream input = new FileInputStream(source);
                 OutputStream output = context.getContentResolver().openOutputStream(target, "w")) {
                if (output == null) throw new java.io.IOException("Could not open public download");
                byte[] buffer = new byte[65536];
                int count;
                while ((count = input.read(buffer)) != -1) {
                    if (cancelled.get()) throw new InterruptedException("Cancelled");
                    output.write(buffer, 0, count);
                }
                output.flush();
            }
            if (cancelled.get()) throw new InterruptedException("Cancelled");
            ContentValues ready = new ContentValues();
            ready.put(MediaStore.MediaColumns.IS_PENDING, 0);
            if (context.getContentResolver().update(target, ready, null, null) != 1) {
                throw new java.io.IOException("Could not finalize public download");
            }
            try (Cursor cursor = context.getContentResolver().query(target,
                    new String[]{MediaStore.MediaColumns.DISPLAY_NAME}, null, null, null)) {
                if (cursor != null && cursor.moveToFirst()) name = cursor.getString(0);
            }
            Map<String, Object> published = new HashMap<>();
            published.put("uri", target.toString());
            published.put("location", Environment.DIRECTORY_DOWNLOADS + "/NOOR/" + name);
            return published;
        } catch (Exception error) {
            context.getContentResolver().delete(target, null, null);
            if (durable) receipt.delete();
            throw error;
        }
    }

    private void prepare() throws Exception {
        if (prepared) return;
        YoutubeDL.getInstance().init(context);
        FFmpeg.getInstance().init(context);
        // User's first online action prepares the current tested extraction engine.
        if (YoutubeDL.getInstance().versionName(context) == null) {
            YoutubeDL.getInstance().updateYoutubeDL(context, YoutubeDL.UpdateChannel._STABLE);
        }
        prepared = true;
    }

    public void close() {
        cancelled.set(true);
        YoutubeDL.getInstance().destroyProcessById(processId);
        if (methods != null) methods.setMethodCallHandler(null);
        if (events != null) events.setStreamHandler(null);
        sink = null;
        worker.shutdownNow();
    }
}
