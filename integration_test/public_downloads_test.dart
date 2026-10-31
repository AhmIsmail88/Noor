import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:noor/app/l10n/gen/app_localizations.dart';
import 'package:noor/main.dart' as app;
import 'package:noor/app/app.dart';
import 'package:noor/data/library_controller.dart';
import 'package:noor/features/downloads/downloads_page.dart';
import 'package:noor/features/player/player_page.dart';

Future<void> tick(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> choose(WidgetTester tester, Finder field, String label) async {
  await top(tester);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> top(WidgetTester tester) async {
  final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
  scroll.position.jumpTo(0);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('public downloads at two video caps and audio-only MP3', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    final library = tester.widget<NoorApp>(find.byType(NoorApp)).library;
    // Labels follow the app language (the phone may be set to English).
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
    await tester.tap(find.text(l.onlineVideo).first);
    await tester.pumpAndSettle();
    final online = tester
        .widget<DownloadsPage>(find.byType(DownloadsPage))
        .online;

    Future<void> downloadAndPlay({
      required int quality,
      bool audio = false,
    }) async {
      final before = library
          .query('', LibraryFilter.all)
          .map((item) => item.path)
          .toSet();
      await top(tester);
      if (audio) {
        await choose(
          tester,
          find.byType(DropdownButtonFormField<bool>),
          l.audioOnlyMp3,
        );
        await choose(
          tester,
          find.byKey(const ValueKey('audio-quality')),
          '128 kbps',
        );
      } else {
        await choose(
          tester,
          find.byKey(const ValueKey('video-quality')),
          '${quality}p',
        );
      }
      await top(tester);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(
        find.byType(TextField),
        'https://www.youtube.com/watch?v=jNQXAC9IVRw',
      );
      FocusScope.of(tester.element(find.byType(TextField))).unfocus();
      await tester.pumpAndSettle();
      final button = find.text(audio ? l.downloadAudio : l.downloadVideo);
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(button);
      await tester.pump();
      // A Windows job is set up before it turns busy; let it start first.
      for (var i = 0; i < 10 && !(online.busy || online.hasTransfer); i++) {
        await tick(tester);
      }
      for (var i = 0; i < 480 && (online.busy || online.hasTransfer); i++) {
        await tick(tester);
      }
      // A CDN URL can expire/be refused transiently. Exercise one ordinary UI
      // retry with freshly extracted URLs; don't hide a repeated source failure.
      if (online.error?.contains('403') == true) {
        debugPrint(
          'NOOR source returned HTTP 403; retrying once through Download.',
        );
        for (var i = 0; i < 6; i++) {
          await tick(tester);
        }
        await tester.scrollUntilVisible(
          button,
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(button);
        await tester.pump();
        for (var i = 0; i < 480 && (online.busy || online.hasTransfer); i++) {
          await tick(tester);
        }
      }
      expect(online.busy, isFalse);
      expect(online.error, isNull, reason: online.error);
      final item = library
          .query('', LibraryFilter.all)
          .where((item) => !before.contains(item.path))
          .single;
      expect(item.isDownload, isTrue);
      expect(item.isAudio, audio);
      expect(item.sizeBytes, greaterThan(10000));
      expect(online.downloads.any((entry) => entry.path == item.path), isTrue);
      if (Platform.isAndroid) {
        expect(item.isContentUri, isTrue);
        expect(item.savedLocation, startsWith('Download/NOOR/'));
        expect(
          await tester.runAsync(
            () =>
                const MethodChannel('noor/online_media')
                    .invokeMethod<bool>('canRead', {'uri': item.path}),
          ),
          isTrue,
        );
      } else {
        expect(await tester.runAsync(() => File(item.path).exists()), isTrue);
        expect(item.savedLocation, contains('NOOR'));
      }
      if (audio) {
        expect(item.savedLocation!.toLowerCase(), endsWith('.mp3'));
      }
      // Tap the newly completed row (the newest duplicate title is first).
      final row = find.widgetWithText(ListTile, item.title).first;
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(row);
      await tester.pump();
      for (var i = 0; i < 100; i++) {
        await tick(tester);
        if (find.byIcon(Icons.error_outline).evaluate().isNotEmpty) break;
        if (find.byType(Video).evaluate().isNotEmpty &&
            tester
                    .widget<Video>(find.byType(Video))
                    .controller
                    .player
                    .state
                    .position
                    .inMilliseconds >
                900) {
          break;
        }
      }
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.byType(PlayerPage), findsOneWidget);
      final controller = tester.widget<Video>(find.byType(Video)).controller;
      expect(controller.player.state.position.inMilliseconds, greaterThan(900));
      expect(controller.player.state.duration, greaterThan(Duration.zero));
      if (!audio) {
        await tester.runAsync(
          () => controller.waitUntilFirstFrameRendered.timeout(
            const Duration(seconds: 15),
          ),
        );
        final w = controller.player.state.videoParams.w!;
        final h = controller.player.state.videoParams.h!;
        expect(
          w < h ? w : h,
          allOf(greaterThan(0), lessThanOrEqualTo(quality)),
        );
      } else {
        expect(find.byIcon(Icons.audiotrack), findsOneWidget);
        expect(controller.player.state.videoParams.h ?? 0, 0);
      }
      debugPrint(
        'NOOR PUBLIC VERIFIED audio=$audio cap=$quality h=${controller.player.state.videoParams.h} uri=${item.path} location=${item.savedLocation} bytes=${item.sizeBytes}',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.runAsync(library.flush);
      final reloaded = await tester.runAsync(LibraryController.open);
      expect(
        reloaded!.findByPath(item.path)?.savedLocation,
        item.savedLocation,
      );
      reloaded.dispose();
      await tester.runAsync(reloaded.flush);
    }

    await downloadAndPlay(quality: 360);
    await downloadAndPlay(quality: 144);
    await downloadAndPlay(quality: 0, audio: true);
    expect(
      library
          .query('', LibraryFilter.all)
          .where((item) => item.isDownload)
          .length,
      greaterThanOrEqualTo(3),
    );
  }, timeout: const Timeout(Duration(minutes: 15)));
}
