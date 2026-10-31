import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/settings.dart';
import 'data/library_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Cairo',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });

  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(480, 360));
  }

  LibraryController library;
  try {
    library = await LibraryController.open();
  } catch (e) {
    // Storage unavailable: run with a temporary library instead of crashing.
    debugPrint('Library store unavailable: $e');
    library = LibraryController.forFile(
      File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}noor_library.json',
      ),
    );
  }

  AppSettings settings;
  try {
    settings = await AppSettings.open();
  } catch (_) {
    settings = AppSettings();
  }
  runApp(NoorApp(settings: settings, library: library));
}
