# Download experiments (not production download UI)

These tools do not modify NOOR's download screen, package, or library. Android
uses a separate package, `com.noor.player.downloadprobe`, built only for testing.
Use only samples you own or are authorized to download. No login/cookies,
private posts, playlists or DRM handling. A successful extractor response alone
does not count as a successful download: a media file and video validation are
required. Tests use a small muxed format first; adaptive HD merging and durable
background jobs are separate work.

## Windows

Create a venv under `build/download_probe/venv` and install `yt-dlp[default]`.
Node must be installed for YouTube; FFprobe must be on PATH for validation.

```powershell
python -m venv build/download_probe/venv
& build/download_probe/venv/Scripts/python.exe -m pip install -r tool/download_probe/requirements.txt
& build/download_probe/venv/Scripts/python.exe tool/download_probe/windows_probe.py 'HTTPS_SAMPLE_URL' --output build/download_probe/windows/site
```

For a new experiment, record `pip freeze`, the Node version, sample provenance,
engine version, elapsed time, bytes, duration, codecs, and validation result.
Raw metadata and media outputs stay under ignored `build/`, not source control.

## Android

The standalone Gradle project lives under `tool/download_probe/android`. Supply
its ignored `local.properties` with the Android SDK directory. Build it with the
existing `android/gradle/wrapper/gradle-wrapper.jar` and Android Studio's Java:

```powershell
& 'C:/Program Files/Android/Android Studio/jbr/bin/java.exe' -classpath android/gradle/wrapper/gradle-wrapper.jar org.gradle.wrapper.GradleWrapperMain -p tool/download_probe/android assembleDebug --console=plain
& E:/Coding/SDK/platform-tools/adb.exe -s DEVICE_SERIAL install -r build/download_probe/android/outputs/apk/debug/NoorDownloadProbe-debug.apk
python tool/download_probe/android_probe.py 'HTTPS_SAMPLE_URL' --adb E:/Coding/SDK/platform-tools/adb.exe --serial DEVICE_SERIAL --output build/download_probe/android-results/site --update-engine
```

Check the actual APK filename emitted by Gradle before installing. The probe
downloads into its private files directory, records JSON, and validates a video
frame using MediaMetadataRetriever. Its engine update is explicitly requested
with `--update-engine`. The main app receives no automatic executable updates.
The harness caps files at 100 MB and requests bounded network retries; its host
runner stops the probe if it does not report within 210 seconds.

Both probes support `--local-fixture` for an explicitly requested HTTP video
served on 127.0.0.1 (use `adb reverse` for Android). This is a transport/runtime
smoke test, not evidence that any social site works.

## Dependencies and distribution decision

- Windows experiment: yt-dlp 2026.10.21 + yt-dlp-ejs 0.8.0, Node v24.19.0.
- Android candidate: `io.github.junkfood02.youtubedl-android:library:0.18.1`
  and its matching FFmpeg component; no production dependency was added.
- The Android wrapper is GPL-3.0; bundled runtime/FFmpeg/JavaScript components
  have their own licenses. Direct APK/Windows distribution does not waive
  source/notice obligations. Record the final component list, build options,
  licenses and corresponding-source plan before shipping a production engine.
- Upstream references: https://github.com/yt-dlp/yt-dlp,
  https://github.com/yt-dlp/yt-dlp/wiki/EJS,
  https://github.com/yausername/youtubedl-android.
