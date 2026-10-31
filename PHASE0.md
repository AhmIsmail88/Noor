# Phase 0 setup (Windows PowerShell)

```powershell
flutter doctor -v
flutter create --platforms=android,windows --org com.noor.player noor
cd noor
# copy the contents of this zip over the new project (lib/, l10n.yaml, *.md)
flutter pub add media_kit media_kit_video media_kit_libs_video file_picker go_router intl
flutter pub add flutter_localizations --sdk=flutter
```

In `pubspec.yaml`, under the existing `flutter:` section, add `generate: true`:

```yaml
flutter:
  generate: true
  uses-material-design: true
```

Delete the template test `test/widget_test.dart` (it references the old counter app), then:

```powershell
flutter gen-l10n
dart format .
flutter analyze
flutter run -d windows
flutter devices
flutter run -d <android-device-id>
```

Windows needs Developer Mode enabled (Settings > For developers) for plugin symlinks.
