import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:noor/main.dart' as app;
import 'package:noor/app/app.dart';
import 'package:noor/data/library_controller.dart';
import 'package:noor/features/player/player_page.dart';

Future<void> tick(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> playback(WidgetTester tester, String label) async {
  for (var i = 0; i < 100; i++) {
    await tick(tester);
    if (find.byType(Video).evaluate().isNotEmpty) {
      final player = tester.widget<Video>(find.byType(Video)).controller.player;
      if (player.state.position.inMilliseconds > 700 &&
          player.state.duration > Duration.zero) {
        break;
      }
    }
    if (find.byIcon(Icons.error_outline).evaluate().isNotEmpty) break;
  }
  expect(find.byIcon(Icons.error_outline), findsNothing, reason: label);
  final controller = tester.widget<Video>(find.byType(Video)).controller;
  await tester.runAsync(
    () => controller.waitUntilFirstFrameRendered.timeout(
      const Duration(seconds: 15),
    ),
  );
  expect(
    controller.player.state.duration,
    greaterThan(Duration.zero),
    reason: label,
  );
  expect(
    controller.player.state.position.inMilliseconds,
    greaterThan(700),
    reason: label,
  );
  debugPrint(
    'NOOR VERIFIED $label: rendered frame, duration=${controller.player.state.duration}, position=${controller.player.state.position}',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native formats, back, next, completed download and streaming', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    final library = tester.widget<NoorApp>(find.byType(NoorApp)).library;
    final root = Platform.isAndroid
        ? '/data/user/0/com.noor.player.noor/files/format-fixtures'
        : '${Directory.current.path}/build';
    final router = GoRouter.of(
      tester.element(find.text('تحميل أو Streaming من رابط').first),
    );
    const names = [
      'noor_android_h264.mp4',
      'noor_smoke.mp4',
      'noor_format_h264.mkv',
      'noor_format_vp9.webm',
      'noor_format_mpeg4.avi',
    ];
    for (final name in names) {
      final path = '$root/$name';
      expect(
        await tester.runAsync(() => File(path).exists()),
        isTrue,
        reason: path,
      );
      library.importPath(path);
      router.push('/player', extra: path);
      await tester.pump();
      await playback(tester, name);
      for (var i = 0; i < 7; i++) {
        await tick(tester);
      }
      await tester.tap(find.byTooltip('رجوع').hitTestable().first);
      await tester.pumpAndSettle();
      expect(find.byType(PlayerPage), findsNothing);
    }
    router.push('/player', extra: '$root/noor_android_h264.mp4');
    await tester.pump();
    await playback(tester, 'next source');
    if (find.byIcon(Icons.skip_next).hitTestable().evaluate().isEmpty) {
      await tester.tap(find.byType(Video));
      await tester.pump(const Duration(milliseconds: 250));
    }
    final next = find.byIcon(Icons.skip_next).hitTestable();
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(of: next, matching: find.byType(IconButton)).first,
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(next);
    await tester.pump();
    await playback(tester, 'next target');
    expect(
      tester.widget<PlayerPage>(find.byType(PlayerPage)).path,
      isNot('$root/noor_android_h264.mp4'),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(PlayerPage), findsNothing);
    router.push('/player', extra: '$root/noor_format_h264.mkv');
    await tester.pump();
    await playback(tester, 'edge back source');
    final bounds = tester.getRect(find.byType(Video));
    await tester.dragFrom(Offset(bounds.left + 2, bounds.center.dy), const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerPage), findsNothing);
    debugPrint('NOOR VERIFIED edge swipe back');
    final before = library
        .query('', LibraryFilter.all)
        .map((e) => e.path)
        .toSet();
    await tester.tap(find.text('تحميل أو Streaming من رابط').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'https://www.youtube.com/shorts/zqOyW5hmeAw',
    );
    await tester.tap(find.text('تحميل الفيديو'));
    for (var i = 0; i < 300; i++) {
      await tick(tester);
      if (library
          .query('', LibraryFilter.all)
          .any((e) => !before.contains(e.path))) {
        break;
      }
    }
    final downloaded = library
        .query('', LibraryFilter.all)
        .where((e) => !before.contains(e.path))
        .single;
    expect(
      await tester.runAsync(() => File(downloaded.path).length()),
      greaterThan(100000),
    );
    final tile = find.widgetWithText(ListTile, downloaded.title).first;
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pump();
    await playback(tester, 'completed download');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    final stream = find.text('Streaming — مشاهدة مباشرة');
    await tester.ensureVisible(stream);
    await tester.tap(stream);
    for (var i = 0; i < 240; i++) {
      await tick(tester);
      if (find.byType(PlayerPage).evaluate().isNotEmpty) break;
    }
    expect(
      tester.widget<PlayerPage>(find.byType(PlayerPage)).onlineSource,
      isNotNull,
    );
    await playback(tester, 'YouTube Streaming');
    expect(library.query('', LibraryFilter.all).length, before.length + 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.runAsync(library.flush);
  }, timeout: const Timeout(Duration(minutes: 12)));
}
