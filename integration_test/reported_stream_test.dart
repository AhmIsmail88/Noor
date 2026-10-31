import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:noor/main.dart' as app;
import 'package:noor/features/downloads/downloads_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('reported long stream survives error and retries at midpoint', (tester) async {
    Future<void> tick() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      await tester.pump();
    }
    Future<void> until(bool Function() ready) async {
      for (var i = 0; i < 90 && !ready(); i++) { await tick(); }
      expect(ready(), isTrue);
    }
    await app.main();
    await tester.pumpAndSettle();
    await tester.tap(find.text('تحميل أو Streaming من رابط').first);
    await tester.pumpAndSettle();
    final page = tester.widget<DownloadsPage>(find.byType(DownloadsPage));
    final source = await tester.runAsync(() => page.online.resolve(
      'https://www.youtube.com/watch?v=F4URi9KJ6-k'));
    final router = GoRouter.of(tester.element(find.byType(DownloadsPage)));
    unawaited(router.push('/player', extra: source));
    await tester.pump();
    await until(() => find.byType(Video).evaluate().isNotEmpty);
    final player = tester.widget<Video>(find.byType(Video)).controller.player;
    await until(() => player.state.position.inSeconds > 1);
    await player.seek(const Duration(minutes: 32));
    await until(() => player.state.position.inSeconds >= 1922);
    final surface = tester.element(find.byType(Video));
    player.platform!.errorController.add('Injected recoverable streaming error');
    await tick();
    expect(tester.element(find.byType(Video)), same(surface));
    final before = player.state.position;
    for (var i = 0; i < 10; i++) { await tick(); }
    expect(player.state.position, greaterThan(before));
    await tester.tap(find.text('إعادة المحاولة'));
    await until(() => player.state.playing && player.state.position >= before);
    debugPrint('NOOR_REPORTED_STREAM_RETRY_OK ${player.state.position}');
    router.pop();
    await tester.pumpAndSettle();
  }, timeout: const Timeout(Duration(minutes: 6)));
}
