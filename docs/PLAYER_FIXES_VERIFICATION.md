# Persistence and player fixes — 22 October 2026

## Changes

- Save playback on pause, player exit, and app lifecycle transitions.
- Windows close captures current playback progress and awaits queued writes.
- Serialize writes, retain unsaved revisions on failure, and skip clean writes.
- Isolate malformed library entries; preserve unsupported library versions.
- Short clips use a completion margin of 5%, capped at ten seconds.
- Open paused, apply the saved position, then play. Guard asynchronous steps
  against player disposal; a resume duration timeout reports an error.
- Show a loading/buffering indicator; narrow Windows transport uses two rows.
- Disable Kotlin incremental compilation because Pub sources on C: and the
  project on E: triggered a cross-drive incremental-cache exception.

## Verified

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: 11 tests passed, including short clips, successive
  writes, progress bounds, malformed entries, future versions, and dispose flush.
- Windows debug build succeeded.
- Android debug APK build succeeded after disabling Kotlin incremental
  compilation: `build/app/outputs/flutter-apk/app-debug.apk` (retry: 100 seconds).
- Using the Computer Use plugin, opened a generated 60-second local MP4,
  verified rendered playback, paused with Space, returned with Escape, and
  reopened from Continue Watching: resume message showed 00:14.
- Closed Windows normally, reopened the final executable, and resumed the
  persisted progress (the test video rendered beyond 00:30).
- Android physical-device test: Samsung SM-A176B, Android 16/API 36, 22 October
  2026. Installed debug APK with `adb install -r` (no data clearing).
- Generated H.264 baseline/yuv420p MP4 (90 seconds) played visibly. After pause
  and leaving the player, app-owned JSON contained `positionMs: 52066` and
  `durationMs: 90000`. Reopening showed the resume message `00:52` and a video
  frame at 00:52.533 (`build/android-resume.png`).
- Pressed Home while playing; stored position became `64400`. Force-stopped
  only NOOR after that background save, relaunched it, and confirmed the same
  stored position. Reopening showed resume `01:04` and a rendered frame at
  01:06.333 (`build/android-restart-resume.png`). Returned to home afterward.
- Leaving the player during decoder startup did not overwrite the existing
  saved position (it remained `64400`).

## Still requires verification

- Narrow-window controls were changed but minimum-width resizing was not
  successfully established during the UI smoke test.
- Android background audio/lock-screen controls remain unverified.
- Cache paths/numeric titles and the MPEG-4 hardware-probe error were subsequently
  fixed and tested: see `ANDROID_IMPORT_AND_CODEC_VERIFICATION.md` for current
  evidence (17 passing tests and device playback after picker-cache removal).
- Audio/subtitle track switching and fullscreen need their separate device tests.
- Flutter Windows accessibility emitted AXTree update errors; the accessibility
  tree sometimes remained on the home page while video was visibly playing.
- Normal shutdown is covered; forced process termination or OS termination can
  still interrupt in-flight disk writes.

Download-site support remains undecided; no download implementation was added.
