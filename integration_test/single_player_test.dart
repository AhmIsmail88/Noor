import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:noor/main.dart' as app;
import 'package:noor/app/app.dart';
import 'package:noor/app/player_route.dart';
import 'package:noor/features/player/player_page.dart';

Future<void> tick(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

List<Player> players(WidgetTester tester) => tester
    .widgetList<Video>(find.byType(Video, skipOffstage: false))
    .map((video) => video.controller.player)
    .toList();

/// Waits until the top player is playing [path] and its position advances.
Future<Player> playing(WidgetTester tester, String path) async {
  for (var i = 0; i < 60; i++) {
    await tick(tester);
    final pages = find.byType(PlayerPage);
    if (pages.evaluate().isEmpty) continue;
    if (tester.widget<PlayerPage>(pages.last).path != path) continue;
    final player = tester
        .widget<Video>(find.byType(Video).last)
        .controller
        .player;
    if (player.state.playing && player.state.position.inMilliseconds > 700) {
      return player;
    }
  }
  fail('$path did not start playing');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('only one video plays when a second one is opened', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    final library = tester.widget<NoorApp>(find.byType(NoorApp)).library;
    final root = Platform.isAndroid
        ? '/data/user/0/com.noor.player.noor/files/format-fixtures'
        : '${Directory.current.path}/build';
    final first = '$root/noor_smoke.mp4';
    final second = '$root/noor_format_h264.mkv';
    final third = '$root/noor_format_vp9.webm';
    for (final path in [first, second, third]) {
      expect(await tester.runAsync(() => File(path).exists()), isTrue);
      // Start from zero: a saved position from an earlier run can resume
      // a 15-second fixture so close to its end that it finishes mid-check.
      library.importPath(path).positionMs = 0;
    }
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));

    openPlayerRoute(router, first);
    await tester.pump();
    await playing(tester, first);

    // "Play" on the download-complete snackbar during playback.
    openPlayerRoute(router, second);
    await tester.pump();
    await playing(tester, second);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byType(PlayerPage, skipOffstage: false), findsOneWidget);
    expect(players(tester).where((p) => p.state.playing), hasLength(1));
    debugPrint('NOOR VERIFIED replace: one player, one sound');

    // A raw push still stacks pages; the older player must fall silent.
    router.push('/player', extra: third);
    await tester.pump();
    await playing(tester, third);
    final all = players(tester);
    expect(all, hasLength(2));
    for (var i = 0; i < 4; i++) {
      await tick(tester);
    }
    expect(all.where((p) => p.state.playing), hasLength(1));
    expect(all.last.state.playing, isTrue);
    debugPrint('NOOR VERIFIED stacked: older player paused');

    router.pop();
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(PlayerPage, skipOffstage: false), findsNothing);
    await tester.runAsync(library.flush);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
