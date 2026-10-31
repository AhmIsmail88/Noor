# Noor

A video and audio player for **Android** and **Windows** that also downloads
or streams links from YouTube, TikTok, Facebook and X (via yt-dlp).
Arabic and English UI.

## Features

- Local playback (media_kit / libmpv): resume, speed, audio and subtitle
  tracks, external SRT/VTT, fullscreen, next in folder or selection,
  autoplay next.
- Library with search, favorites, recent, thumbnails and undo.
- Online: download (video up to a chosen resolution, or MP3) or stream;
  real quality list with sizes; download queue; playlists and channels;
  embedded Arabic/English subtitles; speed and time left.
- Android: background downloads with notifications, saved to
  `Download/NOOR`; Share → Noor from other apps.
- Windows: tray controls, single instance, "Open with Noor".

## Build

```powershell
flutter pub get
flutter gen-l10n
# Windows: put yt-dlp, node and ffmpeg next to the build
powershell -ExecutionPolicy Bypass -File tool/setup_windows_online_engine.ps1 -Configuration Release
flutter build windows --release
flutter build apk --release --target-platform android-arm64
```

The Windows build needs `build/windows/x64/runner/<Configuration>/engines`
(see `tool/setup_windows_online_engine.ps1`). On Android the engine is
bundled by youtubedl-android and updated from Settings.

## Tests

- Unit and widget tests: `flutter test`
- Integration tests run the real app against its real data folder; back it
  up first. On Windows: `flutter test integration_test/<name>.dart -d windows`.
  On Android always use `tool/verify_android.ps1 -TestPath integration_test/<name>.dart`:
  it backs up the app data and never uninstalls the app. Afterwards,
  reinstall a release build: the test build is a slow debug build.
- Test videos (`noor_*.mp4/mkv/webm/avi`) are expected in `build/` on Windows
  and in the app's `files/format-fixtures` on Android.
- `background_test.dart` also needs `tool/background_fixture_server.py`
  (and `tool/background_phone_watch.py` on a phone).

## Layout

- `lib/app` — app shell, router, settings, theme, translations
- `lib/data` — library, download options, online service
  (`online/` holds link helpers, the Windows engine and the queue)
- `lib/features` — home, library, downloads, player, settings pages
- `android/…/noor` — download and playback services, share/open handling
- `windows/runner` — window, tray and single-instance handling
- `docs` — verification reports and decisions (ADR)
