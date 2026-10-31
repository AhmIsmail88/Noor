import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/app/settings.dart';
import 'package:noor/app/theme.dart';

void main() {
  test('language and theme survive reopening after rapid changes', () async {
    final dir = await Directory.systemTemp.createTemp('noor-settings-');
    try {
      final file = File('${dir.path}/settings.json');
      final settings = AppSettings.forFile(file);
      settings.setLocale(const Locale('en'));
      settings.setThemeMode(ThemeMode.light);
      settings.setThemeMode(ThemeMode.system);
      await settings.flush();
      final reloaded = AppSettings.forFile(file);
      await reloaded.load();
      expect(reloaded.locale.languageCode, 'en');
      expect(reloaded.themeMode, ThemeMode.system);
      settings.dispose();
      reloaded.dispose();
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test('unknown settings version is preserved', () async {
    final dir = await Directory.systemTemp.createTemp('noor-settings-');
    try {
      final file = await File('${dir.path}/settings.json')
          .writeAsString('{"version":99}');
      final settings = AppSettings.forFile(file);
      await settings.load();
      settings.setLocale(const Locale('en'));
      await settings.flush();
      expect(await file.readAsString(), '{"version":99}');
      settings.dispose();
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test('both themes use the bundled Cairo family', () {
    expect(darkTheme().textTheme.bodyMedium!.fontFamily, 'Cairo');
    expect(lightTheme().textTheme.bodyMedium!.fontFamily, 'Cairo');
  });
}
