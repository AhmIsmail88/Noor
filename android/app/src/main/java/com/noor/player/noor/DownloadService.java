package com.noor.player.noor;

import android.app.*;
import android.content.*;
import android.net.*;
import android.os.*;
import io.flutter.plugin.common.*;
import org.json.JSONObject;
import java.io.File;
import java.nio.file.Files;
import java.util.*;

/** One durable transfer, independent of the Activity and Flutter engine. */
public final class DownloadService extends Service {
    private static volatile boolean alive;
    private static final String PREFS = "noor_transfer";
    private JSONObject job;
    private OnlineMediaBridge engine;
    private final Handler main = new Handler(Looper.getMainLooper());
    private boolean running, stopping, resumeAfterStop;
    private int failures;
    private long lastUpdate;
    private PowerManager.WakeLock wake;

    static Map<String, Object> status(Context c) throws Exception {
        String raw = c.getSharedPreferences(PREFS, 0).getString("job", "{}");
        JSONObject json = new JSONObject(raw);
        Map<String, Object> map = new HashMap<>();
        Iterator<String> keys = json.keys();
        while (keys.hasNext()) { String key = keys.next(); map.put(key, json.get(key)); }
        if (!map.isEmpty()) map.put("alive", alive);
        return map;
    }
    static void dispatch(Context c, String action, Map<String, Object> args) throws Exception {
        if (Build.VERSION.SDK_INT < 26) throw new IllegalStateException("Background downloads require Android 8 or newer");
        Intent intent = new Intent(c, DownloadService.class).setAction(action);
        if (args != null) intent.putExtra("arguments", new JSONObject(args).toString());
        c.startForegroundService(intent);
    }
    private void save() throws Exception {
        if (!getSharedPreferences(PREFS, 0).edit().putString("job", job.toString()).commit())
            throw new java.io.IOException("Could not save download state");
    }
    private void state(String value) throws Exception { job.put("state", value); save(); notifyProgress(); }
    @Override public void onCreate() {
        super.onCreate();
        alive = true;
        getSystemService(NotificationManager.class).createNotificationChannel(
            new NotificationChannel("noor-downloads", "NOOR downloads", NotificationManager.IMPORTANCE_LOW));
        wake = ((PowerManager)getSystemService(POWER_SERVICE)).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "noor:download");
        engine = new OnlineMediaBridge(getApplicationContext(), null);
        engine.onListen(null, new EventChannel.EventSink() {
            public void success(Object event) {
                if (!running || stopping) return;
                try {
                    Object progress = ((Map<?, ?>)event).get("progress");
                    if (progress instanceof Number) job.put("progress", ((Number)progress).doubleValue());
                    if (System.currentTimeMillis() - lastUpdate > 1000) {
                        lastUpdate = System.currentTimeMillis(); state("downloading");
                    }
                } catch (Exception e) { fail(e.toString()); }
            }
            public void error(String code, String message, Object details) { fail(message); }
            public void endOfStream() {}
        });
    }
    private PendingIntent action(String name, int id) {
        return PendingIntent.getForegroundService(this, id, new Intent(this, DownloadService.class).setAction(name),
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }
    private Notification notification() {
        String state = job == null ? "preparing" : job.optString("state");
        boolean paused = state.equals("paused") || state.equals("failed");
        boolean done = state.equals("completed") || state.equals("cancelled");
        int percent = job == null ? 0 : Math.max(0, Math.min(100, (int)job.optDouble("progress", 0)));
        String text = switch(state) {
            case "paused" -> "التحميل متوقف مؤقتًا";
            case "waiting" -> "انتظار الاتصال — ستتم إعادة المحاولة";
            case "completed" -> "اكتمل الحفظ في Download/NOOR";
            case "failed" -> "تعذّر التحميل — يمكنك الاستكمال";
            case "cancelled" -> "تم إلغاء التحميل";
            case "publishing" -> "جارٍ حفظ الملف";
            default -> "جارٍ التحميل " + percent + "%";
        };
        Notification.Builder b = new Notification.Builder(this, "noor-downloads")
            .setSmallIcon(R.drawable.ic_noor_notification).setContentTitle("NOOR")
            .setContentText(text).setOnlyAlertOnce(true).setOngoing(!paused && !done)
            .setContentIntent(PendingIntent.getActivity(this, 0, getPackageManager().getLaunchIntentForPackage(getPackageName()),
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE));
        if (!done) {
            b.setProgress(100, percent, state.equals("preparing") || state.equals("waiting") || state.equals("publishing"));
            if (!state.equals("publishing")) b.addAction(new Notification.Action.Builder(null,
                paused ? "استكمال" : "إيقاف مؤقت", action(paused ? "jobResume" : "jobPause", 21)).build());
            if (!state.equals("publishing")) b.addAction(new Notification.Action.Builder(null, "إلغاء", action("jobCancel", 22)).build());
        }
        return b.build();
    }
    private void notifyProgress() { getSystemService(NotificationManager.class).notify(4101, notification()); }
    @Override public int onStartCommand(Intent intent, int flags, int id) {
        try {
            if (job == null) job = new JSONObject(getSharedPreferences(PREFS, 0).getString("job", "{}"));
            startForeground(4101, notification());
            String action = intent == null ? "jobResume" : intent.getAction();
            if ("jobStart".equals(action)) {
                if (running || (!job.optString("state").matches("|completed|cancelled"))) return START_STICKY;
                job = new JSONObject(intent.getStringExtra("arguments"));
                File root = new File(getFilesDir(), "downloads"); root.mkdirs();
                File dir = new File(root, "job-" + UUID.randomUUID());
                if (!dir.mkdirs()) throw new java.io.IOException("Cannot create download folder");
                job.put("directory", dir.getAbsolutePath()); job.put("progress", 0);
                state("preparing");
            } else if ("jobPause".equals(action) || "jobCancel".equals(action)) {
                if (job.optString("state").equals("publishing")) return START_STICKY;
                stopping = true;
                state(action.equals("jobPause") ? "paused" : "cancelled");
                engine.onMethodCall(new MethodCall("cancel", null), ignored());
                if (!running) finish();
                return START_NOT_STICKY;
            } else if (job.optString("state").matches("completed|cancelled|")) {
                finish(); return START_NOT_STICKY;
            } else if (intent == null && job.optString("state").equals("paused")) {
                finish(); return START_NOT_STICKY;
            }
            if (running && stopping) resumeAfterStop = true;
            if (!running) { stopping = false; failures = 0; run(); }
            return START_STICKY;
        } catch (Exception e) { fail(e.toString()); return START_NOT_STICKY; }
    }
    private MethodChannel.Result ignored() {
        return new MethodChannel.Result() {
            public void success(Object value) {}
            public void error(String c, String m, Object d) {}
            public void notImplemented() {}
        };
    }
    private void run() throws Exception {
        if (stopping || running) return;
        ConnectivityManager cm = getSystemService(ConnectivityManager.class);
        NetworkCapabilities caps = cm.getNetworkCapabilities(cm.getActiveNetwork());
        String host = Uri.parse(job.optString("url")).getHost();
        boolean loopback = "127.0.0.1".equals(host) || "localhost".equals(host) || "::1".equals(host);
        if (!loopback && (caps == null || !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET))) {
            state("waiting"); main.postDelayed(this::retry, 5000); return;
        }
        running = true;
        if (!wake.isHeld()) wake.acquire();
        state("preparing");
        Map<String, Object> args = new HashMap<>();
        for (String key : new String[]{"url", "directory", "audioOnly", "maxHeight", "audioBitrate"}) args.put(key, job.get(key));
        engine.onMethodCall(new MethodCall("download", args), new MethodChannel.Result() {
            public void success(Object value) {
                if (stopping) { stopped(); return; }
                try { publish((Map<String, Object>)value); } catch (Exception e) { running = false; fail(e.toString()); }
            }
            public void error(String code, String message, Object details) {
                running = false;
                if (stopping) { stopped(); return; }
                try {
                    job.put("error", message);
                    if (++failures >= 5 || permanent(message)) { fail(message); return; }
                    state("waiting"); main.postDelayed(DownloadService.this::retry, Math.min(60000, 5000L << failures));
                } catch (Exception e) { fail(e.toString()); }
            }
            public void notImplemented() { running = false; fail("Engine unavailable"); }
        });
    }
    private void stopped() {
        running = false;
        if (resumeAfterStop && !job.optString("state").equals("cancelled")) {
            resumeAfterStop = false; stopping = false;
            main.postDelayed(this::retry, 50);
        } else finish();
    }
    private void retry() { try { run(); } catch (Exception e) { fail(e.toString()); } }
    /** Retrying cannot fix these; fail at once so the reason is shown. */
    private static boolean permanent(String message) {
        if (message == null) return false;
        for (String reason : new String[]{"Unsupported URL", "is not a valid URL", "valid public web link",
                "Private video", "Video unavailable", "This video is unavailable", "Sign in to confirm",
                "requested format is not available", "larger than max-filesize", "Invalid quality",
                "Invalid output directory"}) {
            if (message.contains(reason)) return true;
        }
        return false;
    }
    private void publish(Map<String, Object> result) throws Exception {
        File file = new File((String)result.get("path"));
        JSONObject info = new JSONObject(new String(Files.readAllBytes(new File(job.getString("directory"), "media.info.json").toPath()), java.nio.charset.StandardCharsets.UTF_8));
        boolean audio = job.optBoolean("audioOnly");
        int resolution = Math.min(info.optInt("width"), info.optInt("height"));
        int cap = job.optInt("maxHeight");
        if (!audio && cap > 0 && resolution > cap) throw new IllegalStateException("Requested resolution unavailable");
        String title = (String)result.get("title");
        String tag = audio ? "MP3 " + job.optInt("audioBitrate") + "kbps" : resolution + "p";
        String base = title.substring(0, Math.min(title.length(), 100));
        String name = base + ((audio || resolution > 0) ? " [" + tag + "]" : "") + file.getName().substring(file.getName().lastIndexOf('.'));
        job.put("title", title); job.put("sizeBytes", file.length()); state("publishing");
        Map<String, Object> args = new HashMap<>(); args.put("path", file.getAbsolutePath()); args.put("name", name); args.put("durable", true);
        engine.onMethodCall(new MethodCall("publish", args), new MethodChannel.Result() {
            public void success(Object value) {
                running = false;
                try {
                    Map<?, ?> saved = (Map<?, ?>)value;
                    job.put("path", saved.get("uri")); job.put("location", saved.get("location"));
                    job.put("progress", 100); state("completed"); file.delete(); finish();
                } catch (Exception e) { fail(e.toString()); }
            }
            public void error(String c, String m, Object d) { running = false; fail(m); }
            public void notImplemented() { running = false; fail("Publisher unavailable"); }
        });
    }
    private void fail(String error) {
        try { if (job != null) { job.put("error", error); state("failed"); } } catch (Exception ignored) {}
        stopping = true; finish();
    }
    private void finish() {
        if (job != null && job.optString("state").matches("completed|cancelled")) {
            try {
                File dir = new File(job.getString("directory")).getCanonicalFile();
                String root = new File(getFilesDir(), "downloads").getCanonicalPath() + File.separator;
                if (dir.getPath().startsWith(root) && dir.getName().startsWith("job-") && dir.exists()) {
                    try (java.util.stream.Stream<java.nio.file.Path> paths = Files.walk(dir.toPath())) {
                        paths.sorted(Comparator.reverseOrder()).forEach(path -> { try { Files.deleteIfExists(path); } catch (Exception ignored) {} });
                    }
                }
            } catch (Exception ignored) {}
        }
        if (wake.isHeld()) wake.release();
        stopForeground(STOP_FOREGROUND_DETACH); stopSelf();
    }
    @Override public void onTimeout(int startId, int fgsType) {
        stopping = true;
        try { state("paused"); } catch (Exception ignored) {}
        engine.onMethodCall(new MethodCall("cancel", null), ignored());
        finish();
    }
    @Override public void onDestroy() {
        main.removeCallbacksAndMessages(null);
        alive = false;
        engine.close();
        if (wake.isHeld()) wake.release();
        super.onDestroy();
    }
    @Override public IBinder onBind(Intent intent) { return null; }
}
