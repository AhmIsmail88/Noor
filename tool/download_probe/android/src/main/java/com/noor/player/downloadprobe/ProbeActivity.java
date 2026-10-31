package com.noor.player.downloadprobe;

import android.app.Activity;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.widget.TextView;
import com.yausername.youtubedl_android.YoutubeDL;
import com.yausername.youtubedl_android.YoutubeDLRequest;
import com.yausername.youtubedl_android.YoutubeDLResponse;
import com.yausername.ffmpeg.FFmpeg;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;

/** Separate debug-only experiment. No changes to the NOOR app or its library. */
public class ProbeActivity extends Activity {
    private final AtomicBoolean done = new AtomicBoolean();
    private TextView status;
    private static final Set<String> HOSTS = new HashSet<>(Arrays.asList(
        "youtube.com", "www.youtube.com", "youtu.be", "m.youtube.com",
        "facebook.com", "www.facebook.com", "m.facebook.com", "fb.watch",
        "tiktok.com", "www.tiktok.com", "vm.tiktok.com", "vt.tiktok.com",
        "x.com", "www.x.com", "twitter.com", "www.twitter.com"));

    @Override public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        status = new TextView(this);
        status.setText("NOOR download experiment — preparing runtime");
        status.setPadding(30, 100, 30, 30);
        setContentView(status);
        String url = getIntent().getStringExtra("url");
        Uri uri = url == null ? Uri.EMPTY : Uri.parse(url);
        boolean local = getIntent().getBooleanExtra("local_fixture", false)
            && "http".equals(uri.getScheme()) && "127.0.0.1".equals(uri.getHost());
        if (uri.getUserInfo() != null || !(local ||
            ("https".equals(uri.getScheme()) && HOSTS.contains(uri.getHost())))) {
            status.setText("A public URL from an approved site is required.");
            return;
        }
        Thread worker = new Thread(() -> runProbe(url), "noor-download-probe");
        worker.start();
        new android.os.Handler(getMainLooper()).postDelayed(() -> {
            if (!done.get()) YoutubeDL.getInstance().destroyProcessById("noor-probe");
        }, 180000);
    }

    private void runProbe(String url) {
        long started = System.currentTimeMillis();
        File run = new File(getFilesDir(), "probe-" + started);
        run.mkdirs();
        JSONObject result = new JSONObject();
        try {
            result.put("url", url).put("platform", "android")
                .put("downloaded", false).put("validated", false);
            YoutubeDL.getInstance().init(this);
            FFmpeg.getInstance().init(this);
            // An explicit experiment update, never a silent update in NOOR.
            if (getIntent().getBooleanExtra("update_engine", false)) {
                YoutubeDL.getInstance().updateYoutubeDL(this, YoutubeDL.UpdateChannel._STABLE);
            }
            result.put("engine", YoutubeDL.getInstance().versionName(this));
            YoutubeDLRequest request = new YoutubeDLRequest(url);
            request.addOption("--ignore-config");
            request.addOption("--no-playlist");
            request.addOption("--no-progress");
            request.addOption("--socket-timeout", "20");
            request.addOption("--retries", "1");
            request.addOption("--extractor-retries", "1");
            request.addOption("--max-filesize", "100M");
            request.addOption("--write-info-json");
            request.addOption("--format", "best[height<=480]/best");
            request.addOption("--output", new File(run, "media.%(ext)s").getAbsolutePath());
            YoutubeDLResponse response = YoutubeDL.getInstance().execute(request, "noor-probe", null);
            Files.write(new File(run, "download.log").toPath(),
                (response.getOut() + "\n" + response.getErr()).getBytes(StandardCharsets.UTF_8));
            result.put("exitCode", response.getExitCode());
            JSONArray files = new JSONArray();
            File[] entries = run.listFiles();
            if (entries != null) for (File file : entries) {
                if (!file.getName().matches("media\\.(mp4|webm|mkv|mov|flv|avi)") || file.length() == 0) continue;
                MediaMetadataRetriever retriever = new MediaMetadataRetriever();
                try {
                    retriever.setDataSource(file.getAbsolutePath());
                    String width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH);
                    String duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
                    android.graphics.Bitmap frame = retriever.getFrameAtTime(0);
                    boolean valid = frame != null && width != null;
                    if (frame != null) frame.recycle();
                    result.put("validated", valid);
                    files.put(new JSONObject().put("name", file.getName()).put("bytes", file.length())
                        .put("width", width).put("durationMs", duration));
                } finally { retriever.release(); }
            }
            result.put("files", files).put("downloaded", response.getExitCode() == 0 && files.length() > 0);
        } catch (Throwable error) {
            try { result.put("error", error.toString()); } catch (Exception ignored) { }
        } finally {
            done.set(true);
            try {
                result.put("elapsedMs", System.currentTimeMillis() - started);
                Files.write(new File(run, "result.json").toPath(), result.toString(2).getBytes(StandardCharsets.UTF_8));
                Files.write(new File(getFilesDir(), "latest-result.json").toPath(), result.toString(2).getBytes(StandardCharsets.UTF_8));
            } catch (Exception error) { Log.e("NoorProbe", "Cannot save experiment result", error); }
            Log.i("NoorProbe", result.toString());
            runOnUiThread(() -> status.setText(result.toString()));
        }
    }
}
