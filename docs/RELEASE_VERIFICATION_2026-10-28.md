# Release verification — 2026-10-28

## Final artifacts
- `dist/NOOR-Android-arm64.apk`: ordinary ARM64 Release, installed in place successfully on MTN-NX1. Cold launch after final update: 1560 ms (single measurement).
- `dist/NOOR-Windows/noor.exe`: rebuilt Windows Release with complete runtime and engines. Process launched successfully from final distribution directory.
- `dist/NOOR-Windows.zip`: portable Windows distribution. The executable requires the accompanying files.

## Confirmed on MTN-NX1
- Video picker selected the generated H.264/AAC MP4. Visible frame timestamp advanced from 00:11.292 to 00:41.458 across Home/background/return.
- Audio button opened ACTION_OPEN_DOCUMENT with audio/*; selected generated MP3. Media session PLAYING and player position 00:51 of 02:00 confirmed.
- Final corrected Release opened direct HTTP Streaming from inside NOOR while a previous download was paused. Visible frame timestamp advanced from 00:04.500 to 00:39.708 across Home/background/return.
- Generated direct-link sample downloaded successfully, including time in background, to Download/NOOR/noor-stream.mp4 (10,049,198 bytes). Listed in completed downloads.
- Deleted only that generated downloaded file externally; rescanned MediaStore and returned to NOOR. Its completed row disappeared. Personal media was not deleted.
- Final installation retained app data.

Evidence: `build/release-proof/before.png`, `after.png`, `audio-frame.png`, `stream-final-before.png`, `stream-final-after.png`, `completed.xml`, `deleted.xml`.

## Code changes and validation
- Paused Android transfers no longer mark the service busy and block Streaming.
- Resume availability follows durable job state, independent of the most recent resolve operation.
- A pending transfer disables starting another download.
- Removed unreachable legacy Android branch from Windows transfer execution and updated outdated download text.
- Extended widget regression coverage for Streaming with an existing paused transfer.
- 34 tests passed; analyzer reported no issues. Logs: `build/final-unit-tests.log`, `build/final-analysis.log`.
- Android build: `build/release-final.log`; Windows build: `build/windows-final.log`.

## Boundaries / still pending
- These background playback checks used Home, not an extended locked-screen/Doze endurance test. Force-stop survival is not claimed for playback.
- Direct HTTP Streaming was tested; this does not establish every social-platform URL works.
- Full Android network-loss/process-kill resume and notification-button matrix still needs a completed end-to-end pass.
- Windows local/Streaming background and download retry previously passed integration tests; final packaged executable received a launch smoke check, not a fresh full UI matrix. Explorer drag/drop and actual Open With chooser flow remain to be fully retested.
- Missing-download reconciliation was verified for NOOR downloads; manually imported library references are not covered by that pruning rule.
- This is a direct-install experimental release, using the existing signing configuration, not a store publication.

## Cleanup
Removed old debug APK copies, old download-probe APK, and old Windows Debug runner output after the new Release artifacts were built. Current generated Release outputs remain for rebuilds; distribution files are consolidated under dist.
