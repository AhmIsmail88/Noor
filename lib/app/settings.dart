import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AppSettings extends ChangeNotifier {
  AppSettings() : _file = null;
  AppSettings.forFile(File file) : _file = file;
  final File? _file;
  Future<void> _writes = Future.value();
  bool _readOnly = false;
  Locale _locale = const Locale('ar');
  ThemeMode _themeMode = ThemeMode.dark;

  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;

  static Future<AppSettings> open() async {
    final directory = await getApplicationSupportDirectory();
    final settings = AppSettings.forFile(
      File(p.join(directory.path, 'noor_settings.json')),
    );
    await settings.load();
    return settings;
  }

  Future<void> load() async {
    if (_file == null || !await _file.exists()) return;
    try {
      final data = jsonDecode(await _file.readAsString());
      if (data is! Map || data['version'] != 1) {
        _readOnly = true;
        return;
      }
      if (['ar', 'en'].contains(data['locale'])) {
        _locale = Locale(data['locale'] as String);
      }
      _themeMode =
          ThemeMode.values
              .where((mode) => mode.name == data['theme'])
              .firstOrNull ??
          ThemeMode.dark;
    } catch (error) {
      _readOnly = true;
      debugPrint('Settings unreadable; preserving the original file: $error');
    }
  }

  void _save() {
    if (_file == null || _readOnly) return;
    final data = jsonEncode({
      'version': 1,
      'locale': _locale.languageCode,
      'theme': _themeMode.name,
    });
    _writes = _writes
        .then((_) async {
          await _file.parent.create(recursive: true);
          final temporary = File('${_file.path}.tmp');
          await temporary.writeAsString(data, flush: true);
          await temporary.rename(_file.path);
        })
        .catchError((Object error) {
          debugPrint('Settings save failed: $error');
        });
  }

  Future<void> flush() => _writes;

  void setLocale(Locale value) {
    _locale = value;
    _save();
    notifyListeners();
  }

  void setThemeMode(ThemeMode value) {
    _themeMode = value;
    _save();
    notifyListeners();
  }
}
