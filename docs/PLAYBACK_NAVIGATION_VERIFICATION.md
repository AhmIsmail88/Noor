# Playback navigation and integrated online checks — 2026-10-24

## Implemented behavior

- A Back button stays available when playback controls hide. An inward swipe
  starting within 28 logical pixels of either video edge also requests Back.
- Back exits fullscreen first, then returns to the previous page. Windows also
  accepts Escape, Alt+Left and Browser Back. Shell pages have a Back button to Home.
- Next (or N on Windows) opens the next video by filename, saves the current
  progress, and replaces the player route so Back does not traverse old videos.
  The last video has a disabled Next button. Streaming has no folder queue.
- Windows can read immediate video siblings in the selected file's directory.
  Android's document picker grants only the selected documents. Select multiple
  videos together via “Open one or more videos”; NOOR copies them into durable
  storage and persists their selection group for Next. Selecting one Android
  document does not grant access to unselected files in its original folder.

## Verified Windows results

`integration_test/online_flow_test.dart` completed successfully on Windows.
Evidence: `build/windows-integration.log` (All tests passed).

The test uses the actual app router, buttons and native media_kit engine. Each
playback check awaits a rendered frame and checks positive duration and advancing
position. Generated local fixtures are used; no unrelated online samples.

| Check | Result |
| --- | --- |
| MP4 / H.264 | Rendered and advanced |
| MP4 / MPEG-4 Part 2 | Rendered and advanced |
| MKV / H.264 | Rendered and advanced |
| WebM / VP9 | Rendered and advanced |
| AVI / MPEG-4 Part 2 | Rendered and advanced |
| Back after controls hide | Returned to previous page |
| Next | Replaced player and rendered next file |
| Edge swipe Back | Returned to previous page |
| Authorized YouTube sample download | Appeared in Completed; local playback rendered |
| Streaming same downloadable sample | Rendered and advanced; did not add a library entry |

The YouTube URL is the user's supplied `zqOyW5hmeAw` Shorts sample. Facebook,
TikTok and X still need user-provided permitted samples for verified coverage.

26 unit/widget tests passed, including folder filtering/order, durable Android
selection groups and the previous download-directory regression.

## Android

Samsung SM-A176B / Android 16: the complete integrated test passed. Evidence:
`build/android-retained-integration-final.log` (All tests passed). All five
format/codec fixtures rendered and advanced, including WebM/VP9 after fixing
the error UI that previously hid mpv's successful hardware-to-software fallback.
Next, hidden-controls Back, edge Back, Completed playback and YouTube Streaming
passed on the phone itself.

The normal APK was then installed with `adb install -r`. The serialized library
was byte-identical before and after the update. The completed download remained
6,403,684 bytes with SHA-256
`008a52b58ed4b315a11727dbb2ff57fd71341e89ce4daf50960088b691e90b9a`.
Normal-app UI verified the item in Completed and rendered it after reopening;
the resume notice showed 00:01. The physical Android Back key returned to Downloads.
Screenshots: `build/noor-final-completed.png`, `build/noor-final-playing.png`.

The actual Android document picker was also used to select MKV and WebM together.
Both original names were preserved in durable managed storage with the same
persisted group. Next was enabled, and the normal APK rendered the next WebM
file (screenshot `build/noor-final-next.png`, generated timestamp 00:05.333).

### Test incident and safeguards

An earlier attempted Android integration test was mistakenly run with Flutter's
default post-test uninstall setting against the main application ID. It removed
the previous NOOR installation and its app-private library/media. No backup of
that earlier private data was available; restoration is not claimed. External
original files were not deleted by this work. The user was informed immediately
after this was diagnosed.

Subsequent tests explicitly use `--no-uninstall`. `tool/verify_android.ps1` also
backs up private data before testing and aborts if backup fails. Current verified
test/download data is backed up under `build/device-backups/`, including
`noor-20261024-final.tar`. These backups contain the new data, not the lost older
library. The installed application is the normal APK, not the integration entrypoint.

These checks cover the listed codecs/containers, not every codec profile or DRM.
