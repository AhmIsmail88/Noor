import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import 'package:noor/main.dart' as app;
import 'package:noor/features/downloads/downloads_page.dart';
import 'package:noor/features/player/player_page.dart';
import 'package:noor/data/online_media_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'durable pause, resume, outage and background local/stream playback',
    (tester) async {
      Future<void> tick([int seconds = 1]) async {
        await tester.runAsync(
          () => Future<void>.delayed(Duration(seconds: seconds)),
        );
        await tester.pump();
      }

      Future<void> until(bool Function() ready, {int seconds = 180}) async {
        for (var i = 0; i < seconds && !ready(); i++) {
          await tick();
        }
        expect(ready(), isTrue);
      }

      Future<void> connection(bool online) async {
        final client = HttpClient();
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:18765/${online ? 'online' : 'offline'}'),
        );
        await (await request.close()).drain<void>();
        client.close();
      }

      await app.main();
      await tester.pumpAndSettle();
      await tester.tap(find.text('تحميل أو Streaming من رابط').first);
      await tester.pumpAndSettle();
      final page = tester.widget<DownloadsPage>(find.byType(DownloadsPage));
      final online = page.online;
      if (online.hasTransfer) {
        await online.cancel();
        await tick(3);
      }
      await connection(true);
      unawaited(
        online
            .download('http://127.0.0.1:18765/background-fixture.mp4')
            .then<void>(
              (_) {},
              onError: (Object e) {
                debugPrint('NOOR stopped transfer: $e');
              },
            ),
      );
      await until(
        () =>
            online.stage == OnlineStage.downloading &&
            online.canPause &&
            (online.progress ?? 0) > .08 &&
            (online.progress ?? 0) < .95,
      );
      await online.pause();
      await until(() => online.stage == OnlineStage.paused);
      final paused = online.progress;
      await tick(3);
      expect(online.stage, OnlineStage.paused);
      expect(online.progress, paused);
      debugPrint('NOOR_TEST_PAUSE_OK');
      await online.resume();
      await until(
        () =>
            online.stage == OnlineStage.downloading &&
            (online.progress ?? 0) > .20,
      );
      await connection(false);
      await until(
        () =>
            online.stage == OnlineStage.waiting ||
            online.stage == OnlineStage.failed,
      );
      debugPrint('NOOR_TEST_OUTAGE_OK');
      await connection(true);
      if (online.canResume) await online.resume();
      await until(() => online.stage == OnlineStage.completed);
      final item = online.lastDownload!;
      expect(item.isDownload, isTrue);
      expect(item.savedLocation, contains('NOOR'));
      debugPrint('NOOR_TEST_DOWNLOAD_OK ${item.path}');
      final router = GoRouter.of(tester.element(find.byType(DownloadsPage)));
      for (final stream in [false, true]) {
        router.push(
          '/player',
          extra: stream
              ? await online.resolve(
                  'http://127.0.0.1:18765/background-fixture.mp4',
                )
              : item.path,
        );
        await tester.pump();
        await until(() => find.byType(Video).evaluate().isNotEmpty);
        final video = tester.widget<Video>(find.byType(Video));
        final player = video.controller.player;
        await until(
          () => player.state.playing && player.state.position.inSeconds > 1,
        );
        final before = player.state.position;
        debugPrint('NOOR_TEST_BACKGROUND_${stream ? 'STREAM' : 'LOCAL'}');
        if (Platform.isWindows) await windowManager.minimize();
        await tick(20);
        expect(player.state.playing, isTrue);
        expect(
          player.state.position,
          greaterThan(before + const Duration(seconds: 12)),
        );
        debugPrint(
          'NOOR_TEST_BACKGROUND_OK_${stream ? 'STREAM' : 'LOCAL'} ${player.state.position}',
        );
        if (Platform.isWindows) {
          await windowManager.restore();
          await windowManager.show();
        }
        if (stream) {
          // A recoverable engine error must not detach the video texture while
          // playback continues, and retry must retain the streaming position.
          final element = tester.element(find.byType(Video));
          player.platform!.errorController.add(
            'Injected transient network error',
          );
          await tick();
          expect(find.byType(Video), findsOneWidget);
          expect(tester.element(find.byType(Video)), same(element));
          final retryPosition = player.state.position;
          await tester.tap(find.text('إعادة المحاولة'));
          await until(
            () =>
                player.state.playing && player.state.position >= retryPosition,
          );
          expect(player.state.position.inSeconds, greaterThan(12));
          debugPrint(
            'NOOR_TEST_STREAM_ERROR_RETRY_OK ${player.state.position}',
          );
        }
        await tick(4);
        router.pop();
        await tester.pumpAndSettle();
      }
      expect(find.byType(PlayerPage), findsNothing);
      // Cancel retains no runnable task, even after a new service attaches.
      unawaited(
        online
            .download('http://127.0.0.1:18765/cancel-fixture.mp4')
            .then<void>((_) {}, onError: (Object _) {}),
      );
      await until(
        () =>
            (online.progress ?? 0) > .03 &&
            online.stage == OnlineStage.downloading,
      );
      await online.cancel();
      await until(() => online.stage == OnlineStage.cancelled);
      debugPrint('NOOR_TEST_CANCEL_OK');
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
