import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:noor/main.dart' as app;
import 'package:noor/app/l10n/gen/app_localizations.dart';
import 'package:noor/features/downloads/downloads_page.dart';
import 'package:noor/features/player/player_page.dart';

// YouTube's CDN answers a share of fresh stream URLs with HTTP 403; the
// player must recover without showing an error. Several opens in a row so
// at least one meets a refusal.
const video = 'https://youtu.be/We-VzLatuOU';
const rounds = 4;

Future<void> tick(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('YouTube Streaming opens every time', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
    await tester.tap(find.text(l.navDownloads).last);
    await tester.pumpAndSettle();
    for (var round = 1; round <= rounds; round++) {
      final online = tester
          .widget<DownloadsPage>(find.byType(DownloadsPage))
          .online;
      tester.widget<TextField>(find.byType(TextField)).controller!.text = video;
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.streaming));
      await tester.pump();
      for (
        var i = 0;
        i < 90 && find.byType(PlayerPage).evaluate().isEmpty;
        i++
      ) {
        await tick(tester);
      }
      expect(online.error, isNull, reason: online.error);
      var position = Duration.zero;
      for (var i = 0; i < 60; i++) {
        await tick(tester);
        final player = tester
            .widget<Video>(find.byType(Video))
            .controller
            .player;
        position = player.state.position;
        if (player.state.playing && position > const Duration(seconds: 2)) {
          break;
        }
      }
      expect(
        find.textContaining(l.playerError('').trim()),
        findsNothing,
        reason: 'playback error shown in round $round',
      );
      expect(position, greaterThan(const Duration(seconds: 2)));
      debugPrint('NOOR VERIFIED YouTube stream round $round: $position');
      GoRouter.of(tester.element(find.byType(PlayerPage))).pop();
      for (var i = 0; i < 6; i++) {
        await tick(tester);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
