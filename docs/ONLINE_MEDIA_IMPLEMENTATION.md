# Download and Streaming UI — 22 October 2026

## User flow

Home now has **تحميل أو Streaming من رابط**. The Downloads tab has the same
page: link entry, clipboard paste, independent Download and Streaming buttons,
progress, cancellation, reason details on failure, and completed videos with a
Play button. Streaming remains selectable even if the video is downloadable.
The user can also try Streaming after a download failure; neither option is
guaranteed if the source denies access.

The page handles HTTP/HTTPS source links. Direct MP4/MKV/WebM/AVI/MOV/FLV/WMV/
MPEG/M4V/3GP/TS/HLS/DASH links can be sent directly to the player; site pages
are resolved by yt-dlp into a playable URL plus required HTTP headers. Retry
refreshes expiring site stream URLs. Streams are not imported as local files.

Completed downloads live in application-support `downloads/video-*/`, outside
cache, and are registered in the persistent library with the source title.
Only completed media is listed. Existing local file import/resume is retained.

## Runtime

- Android: `OnlineMediaBridge` runs extraction off the main thread and reports
  progress over an EventChannel. The first online action initializes the native
  runtime and prepares the current yt-dlp engine. No login or browser cookies.
- Windows: the app executes `engines/yt-dlp.exe` directly with an argument list,
  portable Node and FFmpeg alongside the app. No shell interpolation or Python
  installation is required. `tool/setup_windows_online_engine.ps1` prepares the
  folder and verifies official yt-dlp/Node SHA-256 checksums.
- Single foreground operation, bounded retries and a ten-minute operation
  watchdog. Keep the app open. Durable download jobs, pause/resume after process
  exit, background notifications, adaptive high-resolution selection, export,
  and signed runtime-update design remain follow-up work.

## Verification and current limits

- 24 unit/widget tests passed, including independent Download vs Streaming,
  direct format/manifest recognition, rejected URLs, history isolation, and a
  regression for creation of the first download directory.
- Final `flutter analyze --no-pub`: no issues. Final Windows debug build succeeded.
- Integrated Android APK builds succeeded, including the canonical path
  correction. The latest APK has not been installed after the control stop.
  Windows engine files were prepared and checksum-verified.
- Observed both actions in the actual NOOR interface on phone and Windows.
- Actual phone Download received a complete 6,403,684-byte sample MP4, but the
  Dart handoff rejected the returned path. Canonical path validation was added
  to accommodate Android app-directory aliases; its full end-to-end recheck
  remains pending.
- The first missing-download-directory error was reproduced, fixed and covered
  by a regression test.
- Windows Computer Use was stopped by the user's physical Escape key. No
  further app input was sent after that interruption. Real UI verification of
  Streaming and the corrected completed-download handoff remains pending.
- `integration_test/online_flow_test.dart` is prepared for an authorized
  full UI check; it has not been run in this turn.

The player still uses media_kit/FFmpeg rather than restricting playback to MP4.
The existing Android MPEG-4 software-decoding workaround is preserved.
Generated fixtures for MKV/H.264, WebM/VP9 and AVI/MPEG-4 were copied to the test
phone, but their new device playback checks remain pending. Container support
does not mean every codec/profile/DRM combination is playable.

## 2026-10-24 Windows end-to-end verification

Supersedes the earlier Windows pending status: the actual integrated Flutter UI
test passed Download -> Completed -> local playback and independent Streaming
for the user-provided YouTube sample. Native rendered-frame and advancing-position
checks passed for both. Five local format/codec fixtures and Back/Next/edge-swipe
checks also passed. Normal Windows build restored after the test. 26 unit/widget
tests pass and analysis is clean. Android device verification subsequently passed
the same integrated flow, five formats and navigation. Normal APK installed and
Completed playback verified after reopening. The verification report documents
the earlier test uninstall incident and the required backup/no-uninstall workflow.
See `PLAYBACK_NAVIGATION_VERIFICATION.md` and `build/windows-integration.log`.

## Native and executable dependencies

Android now integrates youtubedl-android library/FFmpeg 0.18.1. The wrapper is
GPL-3.0; using direct APK distribution does not remove corresponding-source or
notice obligations. Source is available at:

- https://github.com/yausername/youtubedl-android
- https://repo.maven.apache.org/maven2/io/github/junkfood02/youtubedl-android/

Windows uses yt-dlp 2026.10.21 and Node v24.19.0. Their downloaded license files,
runtime provenance and FFmpeg build configuration are kept beside the engines.
The packaged yt-dlp executable contains additional bundled components, beyond
the Python project's own license; retain their notices and matching sources.

- https://github.com/yt-dlp/yt-dlp/releases/tag/2026.10.21
- https://github.com/nodejs/node/tree/v24.19.0
- https://github.com/yausername/youtubedl-android/blob/master/BUILD_FFMPEG.md
- https://ffmpeg.org/legal.html

These are local development builds, not a published release. Before external
distribution, package the application/dependency corresponding sources and
notices and settle the combined distribution license. No store publication or
external upload was performed.
