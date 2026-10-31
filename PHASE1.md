# Phase 1 — apply on Windows (PowerShell, inside the `noor` project)

1. Copy this zip's contents over the project (it overwrites `lib/main.dart`, `lib/app/{app,theme,router}.dart`,
   both ARB files, home/library pages, player page). `shell.dart`, `settings_page.dart`, `downloads_page.dart`
   are not touched, so your edits there stay.
   NOTE: the ARB files are replaced by a superset of the old keys. If you edited the ARB files yourself, merge instead.

2. Dependencies:
   ```powershell
   flutter pub add path_provider window_manager
   flutter pub add --dev flutter_launcher_icons
   ```

3. Add to `pubspec.yaml` (top level, not inside `flutter:`):
   ```yaml
   flutter_launcher_icons:
     android: true
     ios: false
     image_path: "assets/icon/icon.png"
     adaptive_icon_background: "#1A0F33"
     adaptive_icon_foreground: "assets/icon/icon_foreground.png"
   ```

4. Build and check:
   ```powershell
   dart run flutter_launcher_icons
   flutter gen-l10n
   dart format .
   flutter analyze
   flutter test
   flutter clean
   flutter run -d windows
   ```
   (`flutter clean` makes Windows pick up the new `app_icon.ico`. If the old icon still shows in the taskbar, restart Explorer or rename the exe once.)

5. Android: `flutter run -d <device>`. Optional: change `android:label` in `AndroidManifest.xml` to `نور`.

Known limits: on Android the file picker may hand back a cached copy; if the OS clears the cache,
the library entry shows "File not found". The fix (copy to app storage or keep the content URI) comes with the Android spike.
