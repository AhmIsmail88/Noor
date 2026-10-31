# Experimental site downloads — 22 October 2026

## Agreed scope

Later integration work is tracked separately in `ONLINE_MEDIA_IMPLEMENTATION.md`;
the results below describe the earlier standalone engine experiment.

Experimental YouTube/Facebook/TikTok/X support, distributed directly as Android
APK and Windows builds. Start with public, authorized, no-login samples. Actual
download plus media validation is required before a platform/site is marked as
working. No download UI, background job implementation, login/cookies, private
posts, playlists or DRM work was added in this experiment.

## Results

| Site | Windows | Android phone | Evidence / next step |
|---|---|---|---|
| YouTube | PASS for one supplied Shorts URL | PASS for the same URL | See evidence below |
| Facebook | NOT TESTED | NOT TESTED | Await user-supplied authorized public sample |
| TikTok | NOT TESTED | NOT TESTED | Await user-supplied authorized public sample |
| X | NOT TESTED | NOT TESTED | Await user-supplied authorized public sample |

This does not certify every YouTube URL, high-resolution adaptive formats,
region-restricted content, future engine versions, or production job recovery.

## YouTube sample evidence

User supplied `https://www.youtube.com/shorts/zqOyW5hmeAw` in response to the
request for a permitted sample. No browser login, cookies, proxy, or external
download service was used.

| Measurement | Windows | Samsung SM-A176B, Android 16/API 36 |
|---|---|---|
| Download exit code | 0 | 0 |
| Actual file | MP4, format 18 | MP4, format 18 |
| Bytes | 6,403,684 | 6,403,684 |
| Duration | 86.122667 seconds | 86,123 ms |
| Validation | FFprobe: H.264 + AAC; FFmpeg decoded first 3 seconds successfully | MediaMetadataRetriever extracted width 360 and decoded an actual video frame |
| Runtime | yt-dlp 2026.10.21, yt-dlp-ejs 0.8.0, Node v24.19.0 | wrapper 0.18.1, updated yt-dlp 2026.10.21, bundled QuickJS |
| Measured elapsed time | 6.69 seconds for download invocation | 30.537 seconds including first-run runtime setup/update and media validation |

The timings are not a throughput comparison: first-run setup differs.

Both downloaded files have the same SHA-256:

`008a52b58ed4b315a11727dbb2ff57fd71341e89ce4daf50960088b691e90b9a`

Local experiment artifacts (not committed binaries):

- Windows result/log/media:
  `build/download_probe/windows/youtube/1792669825071680200/`
- Android host result: `build/download_probe/android-results/youtube/result.json`
- Android app-owned result/media:
  `/data/user/0/com.noor.player.downloadprobe/files/probe-1792669987242/`
- Android test APK:
  `build/download_probe/android/outputs/apk/debug/NoorDownloadProbe-debug.apk`

## Architecture and reproducibility

Windows uses a Python venv under ignored `build/download_probe`. Android uses a
standalone Gradle project and separate app ID `com.noor.player.downloadprobe`.
The main NOOR app, its Gradle dependencies, and download page were not modified.
See `tool/download_probe/README.md` for commands and dependency notes.

The test selects an already muxed, modest-resolution format; this proves actual
extraction and download. It does not prove separate audio/video merging or
durable Android foreground downloads. Download limits: 100 MB, bounded retries,
host timeout 180 seconds on Windows / 210 seconds on Android.

Probe Python files compile, and the Windows probe rejects URLs outside the
approved host list. Standalone Android APK builds and runs on the physical
phone. NOOR's Flutter sources were unchanged, so its unrelated test suite was
not rerun for this isolated tooling experiment.

## Distribution dependency decision still needed

The candidate Android wrapper is GPL-3.0. Its FFmpeg, Python, JavaScript runtime
and other components have their own license obligations. The experiment is
isolated so it does not silently impose a production dependency choice on NOOR.
Before distributing an integrated engine, settle license compatibility,
corresponding source/third-party notices and the runtime update design.

Upstream sources reviewed:

- https://github.com/yt-dlp/yt-dlp
- https://github.com/yt-dlp/yt-dlp/wiki/EJS
- https://github.com/yausername/youtubedl-android
