# Public downloads, quality, MP3 and Cairo — 2026-10-24

## Verified outcomes

Physical phone: Samsung SM-A176B / Android 16. The app's real Download controls
were used for the user-supplied YouTube sample `zqOyW5hmeAw`. The same test passed
on Windows. Logs:

- `build/public-download-android-verified.log` — All tests passed.
- `build/public-download-windows-final-verified.log` — All tests passed.
- `build/public-download-unit.log` — 32 tests passed.
- `build/public-download-analyze.log` — No issues found.

| Choice | Actual file streams | Android folder | NOOR playback |
| --- | --- | --- | --- |
| 360p | AV1 360×640 + Opus, MKV | Download/NOOR | Rendered frame, advancing position |
| 144p | H.264 144×256 + Opus, MKV | Download/NOOR | Rendered frame, advancing position |
| MP3 128kbps | MP3 audio, 128000 bits/s, no video stream | Download/NOOR | Duration and position advanced; audio display |

Actual public files were pulled from `/sdcard/Download/NOOR` and inspected with
ffprobe. Resolution/codec assertions passed on the files themselves, separately
from the UI. Machine-readable evidence: `build/public-proof/android-manifest.json`
and `build/public-proof/windows-manifest.json`. Quality is the shorter dimension
for portrait and landscape videos. Selection prefers the requested resolution or
the best available below it, never fabricates/upscales a missing resolution.
Known dimensions are checked before publishing to reject a result above the cap.

The external DocumentsUI file manager showed the NOOR directory and all three
files. The 360p file was opened through its ordinary Open With chooser in the
phone's Video Player and visibly rendered. The MP3 was opened from the file
manager in Samsung Voice Recorder QuickPlayer; the screenshot shows 00:03 / 01:26
and Pause. Its normal audio permission was temporarily allowed for the test and
then revoked to restore its prior denied state. No default handler was changed.

Screenshots: `build/public-proof/external-video.png`,
`build/public-proof/external-audio-progress.png`. These verify the phone's
installed players; compatibility with every external player is not claimed.

## Storage and UI

- Android uses MediaStore Downloads with pending rows until a full successful
  copy; failure/cancellation removes the newly created pending row. Public-save
  support currently requires Android 10+. Older devices need a SAF destination
  workflow before this feature can be called supported there.
- The public content URI becomes the library entry. The temporary private media
  file is removed after successful publishing; there is no permanent second full
  media copy. Legacy private downloads have a Save to phone Downloads action.
- Windows files go in the user's Downloads/NOOR folder. Existing names receive
  suffixes instead of being overwritten. Filenames include the actual resolution
  or MP3 bitrate when known.
- Completed entries include audio and video. The UI offers video caps from 144p
  to 2160p and highest available, MP3 at 128/192/320kbps, a saved-location label,
  success feedback with Play, and a folder button. On the tested phone, that
  button opened the actual Download/NOOR document directory.
- Cairo is bundled locally for dark/light themes and player, including its OFL
  license. Source: https://github.com/google/fonts/tree/main/ofl/cairo .
- Language/theme preferences now persist to `noor_settings.json`. A physical
  phone test changed to English/light, force-stopped/reopened, verified English
  and the persisted light preference, then restored Arabic/dark and reopened.
  Screenshot: `build/public-proof/english-light-restarted.png`.

The normal APK was built and installed with `adb install -r` after the integration
test. All 13 library entries present before that update remained afterward.
Backups were taken before device testing; no uninstall was used for this work.
Final app artifact: `build/noor-normal-arm64-debug.apk` (development build).

The legacy private MP4 was subsequently exported using the actual save-to-phone
button. It became `content://media/external/downloads/23973`, retaining
6,403,684 bytes, duration 86,122ms and resume position 24,300ms. Final normal-app
MP3 playback was rechecked after installing the final APK: the Cairo player
showed the audio display and 00:02 / 01:26 (resuming from 00:01). Screenshots:
`build/public-proof/noor-final-audio-player.png` and
`build/public-proof/noor-final-completed-cairo.png`.

Final APK SHA-256:
`C2D22EB4015378FA3B098532A44B583C6EB1F07BCCC189077FD4F27B37D5EE87`.

## Limits and follow-up

An earlier Windows run received a source HTTP 403 on one video request. A later
complete run passed all three cases. Source access can change; this remains
experimental site support. Facebook/TikTok/X still lack permitted sample tests.
Background jobs and download continuation after app termination are not yet
implemented. The settings store preserves unknown/unreadable versions rather
than overwriting them. Public files deleted outside NOOR are checked on playback;
the library does not yet live-refresh external deletions.

References used for implementation:

- https://developer.android.com/training/data-storage/shared/media
- https://github.com/yt-dlp/yt-dlp#sorting-formats
