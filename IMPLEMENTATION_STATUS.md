# IMPLEMENTATION_STATUS

Legend: DONE / PARTIAL / BLOCKED / NOT STARTED. DONE only after build + run on the target OS.

## Verification update — 22 October 2026

Persistence/player/import and online UI implemented. 24 unit/widget tests passed.
Windows debug build and local MP4 playback/resume verified, including app close
and reopen. Android H.264 playback, pause/exit saving, Home/background saving,
and resume after process restart verified on Samsung SM-A176B (Android 16).
Android debug APK build succeeded after the cross-drive Kotlin cache workaround.
See `docs/PLAYER_FIXES_VERIFICATION.md` for evidence and remaining checks.
Permanent Android imports, original filenames, legacy migration, and MPEG-4
software decoding verified on the phone, including playback after picker-cache
removal. See `docs/ANDROID_IMPORT_AND_CODEC_VERIFICATION.md`.

## Phase 0
| Item | Status | Evidence |
|---|---|---|
| Android + Windows project, shell, AR/EN | PARTIAL | Windows and Android startup verified; full language switching check pending |
| Local playback play/pause/seek | PARTIAL | Windows and Android H.264 playback/resume verified; full seek/codec checks pending |

## Phase 1
| Item | Status | Notes |
|---|---|---|
| Icon (crescent + play, purple) | PARTIAL | files generated; Windows .ico included; Android needs flutter_launcher_icons run |
| Purple UI theme from icon palette | DONE | seen in running Windows and Android builds |
| Persist imported media, resume, history, favorites | PARTIAL | 17 tests passed; playback/resume/restart verified; Android imports survive picker-cache removal; favorites UI checks pending |
| Library UI (search, filters, favorites, remove) | PARTIAL | written, not yet run |
| Fullscreen, speed, volume/mute, audio+subtitle tracks | PARTIAL | written, not yet run |
| Windows keyboard shortcuts (Space, arrows, M, F, Esc) | PARTIAL | Space/Esc used during Windows playback test; remaining shortcuts pending |
| Playlists | NOT STARTED | |
| Android background audio + lock-screen controls | NOT STARTED | needs a native media-service spike; gate requires a physical-device test |
| Keep-screen-awake while playing (Android) | NOT STARTED | |
| Android file access that survives cache cleanup | DONE (tested local files) | permanent app-private copies; legacy migration, original names and resume after picker-cache removal verified; cloud providers/large files pending |

## Phase 2 — online UI integration (in progress)

Latest verification (2026-10-24): public downloads in Download/NOOR, video
resolution selection (including portrait), and audio-only MP3 passed integrated
UI tests on Android and Windows. The actual 360x640 / 144x256 video streams and
128kbps MP3-only stream were independently checked using ffprobe. Phone file-manager
playback passed in Video Player and Voice Recorder QuickPlayer. Normal APK is
installed, and the normal Windows build is restored. Cairo is bundled locally;
locale/theme now persist and were verified through a real phone restart.
32 tests pass and analysis is clean. The old private download was also exported
through the UI, retaining its 24.3-second position. Details:
`docs/PUBLIC_DOWNLOADS_VERIFICATION.md`. Proposed next work is prioritized in
`docs/IMPROVEMENTS_ROADMAP_AR.md`.

Home/Downloads now expose independent Download and Streaming, link paste,
progress/cancel, error details, permanent completed downloads and Play.
Android native engine and portable Windows engine are integrated. 24 unit/
widget tests passed; final analysis clean and Android/Windows builds succeeded.
2026-10-24: Windows integrated UI test passed: download, Completed playback,
independent Streaming, MP4/H.264, MP4/MPEG-4, MKV/H.264, WebM/VP9,
AVI/MPEG-4, persistent Back, edge Back and Next. 26 unit/widget tests pass;
analysis clean; normal Windows build rebuilt after the integration test.
Android's corrected path handoff, Completed playback and independent Streaming
now pass on the physical phone too, along with all five format/codec fixtures,
Back, edge swipe and Next. Normal APK installed after tests; download and library
survived the final in-place update. VP9 hardware fallback error UI was repaired.
An earlier misconfigured test uninstalled the old Android app/private data;
this incident and the new no-uninstall/backup safeguards are documented in the
verification report. No recovery of the earlier library is claimed.
Back and Next are implemented; Android supports persistent multi-document
selection groups, while Windows discovers immediate folder siblings.
See `docs/PLAYBACK_NAVIGATION_VERIFICATION.md` for the current evidence.
See `docs/ONLINE_MEDIA_IMPLEMENTATION.md` for honest verification limits.

### Prior isolated extraction/download experiment

Experimental four-site support and direct APK/Windows distribution accepted.
One user-provided YouTube Shorts sample downloaded and validated on Windows and
Samsung SM-A176B / Android 16; SHA-256 matches. Facebook/TikTok/X await samples.
The UI has since been implemented as above; durable jobs remain NOT STARTED.
The earlier probe tooling remains separate. See `docs/DOWNLOAD_PROBE_RESULTS.md`
and ADR 0002.
