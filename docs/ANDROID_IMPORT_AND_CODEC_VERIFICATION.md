# Android permanent imports and MPEG-4 — 22 October 2026

## Implementation

- Android uses the document picker with video extension filters. Its returned
  display name is kept instead of deriving the title from a photo-provider ID.
- Copy each selected file into application-support `media/<SHA-256>/<name>`
  using streamed I/O and a temporary staging directory. Publish only a complete
  copy. SHA-256 distinguishes different videos with the same filename.
- Migrate existing cache-based records at startup, keeping progress, history,
  favorites and added date. Missing cache files remain listed for recovery.
- Reselecting identical content restores its original title and updates the
  existing record rather than resetting progress or duplicating the record.
- Legacy numeric names cannot be reconstructed from the old JSON alone. They
  are retained during migration until the original is selected again.
- Copying needs additional app storage. Imports are app-private and survive
  cache removal, but uninstalling/clearing application data removes them.

## MPEG-4 diagnosis

Before the fix, on Samsung SM-A176B / Android 16, decoder logs showed:

1. Attempt `mpeg4_mediacodec-mediacodec-copy`.
2. Surface/native window unavailable, unsupported/unknown profile, MediaCodec
   fails to start, and `Could not open codec` is emitted.
3. mpv falls back to software decoding and produces video frames.

The UI treated the failed hardware probe as a fatal playback error, even though
the backend recovered. Android now excludes MPEG-4 Part 2 from `hwdec-codecs`.
GPU rendering and hardware decoding for H.264/HEVC and other listed codecs stay
enabled. Software MPEG-4 can cost more CPU/battery; large/high-resolution files
still require performance testing. This is not a guarantee for all codecs.

## Verification

- Clean Flutter analysis; 17 tests passed (11 existing + 6 import tests).
- Android debug APK and Windows debug executable both built successfully.
- Reinstalled on the same Samsung phone without clearing application data.
- Old MPEG-4 and H.264 records migrated to `files/media`; their saved positions
  remained 27266 ms and 76066 ms at migration.
- Selected `noor_android_h264.mp4` and `noor_smoke.mp4` in the document picker.
  Numeric titles were replaced, added dates/history survived, and library count
  stayed at two. The H.264 resume message remained `01:16`.
- MPEG-4 visibly rendered; logs showed software decoding without a failed
  hardware probe. H.264 logs still showed hardware decoding (mediacodec-copy).
- Android's `pm clear --cache-only` stalled and was stopped. Instead, verified
  the app-private cache path and removed only `cache/file_picker` containing the
  generated test copies. Confirmed the app cache listing was empty.
- Restarted NOOR. Both titles and records remained. MPEG-4 resumed from `00:31`
  and visibly rendered at 00:34.933. H.264 resumed from `01:16` and visibly
  rendered at 01:19.400. No cache files were recreated by those playback tests.
- Left NOOR on its home page; original files in Downloads were preserved.

Local screenshots (build artifacts):

- `build/android-original-name.png`
- `build/android-mpeg4-fixed.png`
- `build/android-mpeg4-after-cache-clear.png`
- `build/android-h264-after-cache-clear.png`

Cloud document providers, multi-gigabyte imports, storage exhaustion, and
interruption mid-copy still need device coverage. Unit tests cover missing
sources, partial-copy cleanup, filename traversal, collisions, migration,
reselection, and survival after cache removal.
