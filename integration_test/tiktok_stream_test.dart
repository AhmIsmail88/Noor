import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:noor/main.dart' as app;
import 'package:noor/app/l10n/gen/app_localizations.dart';
import 'package:noor/features/downloads/downloads_page.dart';
import 'package:noor/features/player/player_page.dart';

// yt-dlp's own TikTok test video; its CDN needs the tt_chain_token cookie.
const tiktok = 'https://www.tiktok.com/@scout2015/video/6718335390845095173';

Future<void> tick(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('TikTok plays with Streaming', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
    await tester.tap(find.text(l.navDownloads).last);
    await tester.pumpAndSettle();
    final online = tester
        .widget<DownloadsPage>(find.byType(DownloadsPage))
        .online;
    tester.widget<TextField>(find.byType(TextField)).controller!.text = tiktok;
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.streaming));
    await tester.pump();
    for (var i = 0; i < 90 && find.byType(PlayerPage).evaluate().isEmpty; i++) {
      await tick(tester);
    }
    expect(online.error, isNull, reason: online.error);
    final page = tester.widget<PlayerPage>(find.byType(PlayerPage));
    expect(page.onlineSource, isNotNull);
    debugPrint(
      'NOOR stream headers: ${page.onlineSource!.headers.keys.toList()}',
    );
    expect(page.onlineSource!.headers.keys, contains('Cookie'));
    var position = Duration.zero;
    for (var i = 0; i < 40; i++) {
      await tick(tester);
      final player = tester.widget<Video>(find.byType(Video)).controller.player;
      position = player.state.position;
      if (player.state.playing && position > const Duration(seconds: 2)) {
        break;
      }
    }
    final playerError = find.textContaining(l.playerError('').trim());
    expect(playerError, findsNothing, reason: 'playback error shown');
    expect(position, greaterThan(const Duration(seconds: 2)));
    debugPrint('NOOR VERIFIED TikTok streaming: position=$position');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
