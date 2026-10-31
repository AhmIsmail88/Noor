import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:noor/main.dart' as app;
import 'package:noor/app/app.dart';
import 'package:noor/app/l10n/gen/app_localizations.dart';
import 'package:noor/app/player_route.dart';
import 'package:noor/features/player/player_page.dart';
import 'package:path/path.dart' as p;

Future<void> tick(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('a finished video counts down and opens the next one', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    final noor = tester.widget<NoorApp>(find.byType(NoorApp));
    expect(noor.settings.autoplayNext, isTrue);
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
    final root = Platform.isAndroid
        ? '/data/user/0/com.noor.player.noor/files/format-fixtures'
        : '${Directory.current.path}/build';
    // Folder order: … noor_format_vp9.webm, noor_smoke.mp4
    final first = '$root/noor_format_vp9.webm';
    final next = '$root/noor_smoke.mp4';
    noor.library.importPath(first).positionMs = 0;
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    openPlayerRoute(router, first);
    await tester.pump();

    for (var i = 0; i < 40; i++) {
      await tick(tester);
      final videos = find.byType(Video);
      if (videos.evaluate().isEmpty) continue;
      final player = tester.widget<Video>(videos).controller.player;
      if (player.state.playing && player.state.duration > Duration.zero) {
        await player.seek(player.state.duration - const Duration(seconds: 1));
        break;
      }
    }
    var sawCountdown = false;
    for (var i = 0; i < 30; i++) {
      await tick(tester);
      if (find.text(l.playNow).evaluate().isNotEmpty) sawCountdown = true;
      final pages = find.byType(PlayerPage);
      if (pages.evaluate().isNotEmpty &&
          p.equals(tester.widget<PlayerPage>(pages.last).path, next)) {
        break;
      }
    }
    // Let the replaced page finish its exit transition.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(sawCountdown, isTrue, reason: 'Up-next card was not shown');
    expect(
      p.equals(tester.widget<PlayerPage>(find.byType(PlayerPage)).path, next),
      isTrue,
    );
    expect(find.byType(PlayerPage, skipOffstage: false), findsOneWidget);
    debugPrint('NOOR VERIFIED autoplay: countdown shown, next video opened');
    router.pop();
    await tester.pumpAndSettle();
    await tester.runAsync(noor.library.flush);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
