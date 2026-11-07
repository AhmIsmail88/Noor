import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noor/main.dart' as app;
import 'package:noor/app/app.dart';
import 'package:noor/app/l10n/gen/app_localizations.dart';
import 'package:noor/data/library_controller.dart';
import 'package:noor/data/media_item.dart';
import 'package:noor/features/library/library_page.dart';
import 'package:noor/features/library/media_tile.dart';
import 'package:path/path.dart' as p;

// Windows only: needs engines\demucs (tool/setup_windows_demucs.ps1) and
// the fixtures build\separation-fixture.{mp3,mkv} (16 s of speech + music;
// the .mkv adds the noor_format_h264.mkv picture).
Future<void> tick(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('remove music / music only make new copies in the library', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    final library = tester.widget<NoorApp>(find.byType(NoorApp)).library;
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
    final build = '${Directory.current.path}${Platform.pathSeparator}build';
    final engines = p.join(p.dirname(Platform.resolvedExecutable), 'engines');
    Future<String> probe(List<String> args) async => (await tester.runAsync(
      () =>
          Process.run(p.join(engines, 'ffprobe.exe'), ['-v', 'error', ...args]),
    ))!.stdout.toString().trim();

    await tester.tap(find.text(l.navLibrary).last);
    await tester.pumpAndSettle();
    final separation = tester
        .widget<LibraryPage>(find.byType(LibraryPage))
        .separation!;
    for (var i = 0; i < 20 && !separation.available; i++) {
      await tick(tester);
    }
    expect(separation.available, isTrue, reason: 'engines\\demucs missing');

    var sawNoAudio = false;
    Future<MediaItem?> run(String fixture, String action) async {
      final source = library.importPath(p.join(build, fixture));
      await tester.pumpAndSettle();
      final before = library
          .query('', LibraryFilter.all)
          .map((e) => e.path)
          .toSet();
      final row = find.byWidgetPredicate(
        (w) => w is MediaTile && w.item.path == source.path,
      );
      await tester.scrollUntilVisible(
        row,
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(
        find.descendant(of: row, matching: find.byTooltip(l.moreActions)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(action).last);
      await tester.pump();
      final started = DateTime.now();
      var sawProgress = false;
      for (var i = 0; i < 600; i++) {
        await tick(tester);
        if (separation.current != null) sawProgress = true;
        if (find.text(l.separationNoAudio).evaluate().isNotEmpty) {
          sawNoAudio = true;
        }
        if (separation.current == null && i > 2) break;
      }
      final added = library
          .query('', LibraryFilter.all)
          .where((e) => !before.contains(e.path))
          .toList();
      debugPrint(
        'NOOR separation "$action" on $fixture: '
        '${DateTime.now().difference(started).inSeconds}s, '
        'progress shown=$sawProgress, new=${added.map((e) => e.title)}',
      );
      return added.isEmpty ? null : added.single;
    }

    // 1. Audio: remove the music, keep the voice.
    final voice = (await run('separation-fixture.mp3', l.removeMusic))!;
    expect(voice.title, contains(l.noMusicSuffix));
    expect(voice.isAudio, isTrue);
    expect(p.extension(voice.path), '.mp3');
    final voiceSeconds = double.parse(
      await probe([
        '-show_entries',
        'format=duration',
        '-of',
        'csv=p=0',
        voice.path,
      ]),
    );
    expect(voiceSeconds, closeTo(16, 0.5));
    debugPrint('NOOR VERIFIED remove music: ${voice.path} ${voiceSeconds}s');

    // 2. Video: keep the music; the picture is copied, not re-encoded.
    final music = (await run('separation-fixture.mkv', l.musicOnly))!;
    expect(music.title, contains(l.musicOnlySuffix));
    expect(music.isAudio, isFalse);
    final streams = await probe([
      '-show_entries',
      'stream=codec_type,codec_name',
      '-of',
      'csv=p=0',
      music.path,
    ]);
    expect(streams, contains('h264,video'));
    expect(streams, contains('aac,audio'));
    debugPrint('NOOR VERIFIED music only: ${music.path} [$streams]');

    // 3. A video without sound is refused at once with a clear message.
    // Earlier "Ready" messages would queue ahead of it; clear them first.
    ScaffoldMessenger.of(tester.element(find.byType(LibraryPage)))
        .clearSnackBars();
    await tester.pumpAndSettle();
    final silent = await run('noor_format_h264.mkv', l.removeMusic);
    expect(silent, isNull);
    expect(sawNoAudio, isTrue, reason: 'no-audio message shown');
    debugPrint('NOOR VERIFIED no audio refused');

    await tester.runAsync(library.flush);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
