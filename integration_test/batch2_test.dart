import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noor/main.dart' as app;
import 'package:noor/app/app.dart';
import 'package:noor/app/l10n/gen/app_localizations.dart';
import 'package:noor/data/library_controller.dart';
import 'package:noor/features/downloads/downloads_page.dart';

const sample = 'https://www.youtube.com/watch?v=jNQXAC9IVRw'; // 19 s

Future<void> tick(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('engine version, real qualities, queue and engine update', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    final noor = tester.widget<NoorApp>(find.byType(NoorApp));
    final library = noor.library;
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
    Future<void> waitFor(bool Function() done, String what, int ticks) async {
      for (var i = 0; i < ticks && !done(); i++) {
        await tick(tester);
      }
      expect(done(), isTrue, reason: what);
    }

    // 1. Settings shows the engine version.
    await tester.tap(find.text(l.navSettings).last);
    await tester.pumpAndSettle();
    await waitFor(
      () => find
          .textContaining(l.engineVersion('').trim())
          .evaluate()
          .isNotEmpty,
      'engine version shown',
      40,
    );
    final versionText = tester
        .widget<Text>(find.textContaining(l.engineVersion('').trim()))
        .data!;
    debugPrint('NOOR VERIFIED engine version: $versionText');

    // 2. Real qualities for the link.
    await tester.tap(find.text(l.navDownloads).last);
    await tester.pumpAndSettle();
    final online = tester
        .widget<DownloadsPage>(find.byType(DownloadsPage))
        .online;
    await tester.enterText(find.byType(TextField), sample);
    await tester.tap(find.text(l.checkQualities));
    await tester.pump();
    await waitFor(() => !online.busy, 'probe finished', 120);
    expect(online.error, isNull, reason: online.error);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('video-quality')));
    await tester.pumpAndSettle();
    final labels = tester
        .widgetList<Text>(find.textContaining('p · ≈'))
        .map((t) => t.data!)
        .toSet();
    debugPrint('NOOR VERIFIED qualities: $labels');
    expect(labels.any((t) => t.startsWith('240p')), isTrue);
    expect(labels.any((t) => t.startsWith('144p')), isTrue);
    expect(labels.any((t) => t.startsWith('720p')), isFalse);
    await tester.tap(find.textContaining('144p · ≈').last);
    await tester.pumpAndSettle();

    // 3. Download, queue a second link meanwhile, and let it start alone.
    final before = library
        .query('', LibraryFilter.all)
        .map((e) => e.path)
        .toSet();
    await tester.tap(find.text(l.downloadVideo));
    await tester.pump();
    await waitFor(() => online.hasTransfer, 'first download started', 20);
    await tester.enterText(find.byType(TextField), '$sample&noor=queued');
    await tester.pumpAndSettle();
    // "Add to queue" only exists while the slot is taken, so the second
    // download can only start from the queue (it may start at once: the
    // 144p sample finishes in seconds).
    await tester.tap(find.text(l.addToQueue));
    await tester.pumpAndSettle();
    await waitFor(
      () =>
          library
                  .query('', LibraryFilter.all)
                  .where((e) => !before.contains(e.path))
                  .length ==
              2 &&
          !online.hasTransfer &&
          online.queue.isEmpty,
      'both downloads finished, the second from the queue',
      400,
    );
    final added = library
        .query('', LibraryFilter.all)
        .where((e) => !before.contains(e.path))
        .map((e) => e.savedLocation)
        .toList();
    debugPrint('NOOR VERIFIED queue: $added');

    // 4. Engine update from Settings.
    await tester.tap(find.text(l.navSettings).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.engineUpdate));
    await tester.pump();
    await waitFor(() => !online.engineUpdating, 'engine update ended', 240);
    await tester.pump();
    final after = tester
        .widget<Text>(find.textContaining(l.engineVersion('').trim()))
        .data!;
    debugPrint('NOOR VERIFIED engine update: $versionText -> $after');
    expect(after, isNot(l.engineVersionUnknown));
    await tester.runAsync(library.flush);
  }, timeout: const Timeout(Duration(minutes: 12)));
}
