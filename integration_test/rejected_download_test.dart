import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noor/app/l10n/gen/app_localizations.dart';
import 'package:noor/main.dart' as app;
import 'package:noor/features/downloads/downloads_page.dart';

Future<void> tick(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('a removed video fails at once and keeps Download available', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    // Labels follow the app language (the phone may be set to English).
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
    await tester.tap(find.text(l.onlineVideo).first);
    await tester.pumpAndSettle();
    final online = tester
        .widget<DownloadsPage>(find.byType(DownloadsPage))
        .online;
    // This sample's YouTube channel was terminated (verified 2026-10-31).
    await tester.enterText(
      find.byType(TextField),
      'https://www.youtube.com/shorts/zqOyW5hmeAw',
    );
    final started = DateTime.now();
    await tester.tap(find.text(l.downloadVideo));
    await tester.pump();
    for (var i = 0; i < 120 && (online.busy || online.error == null); i++) {
      await tick(tester);
    }
    final elapsed = DateTime.now().difference(started);
    debugPrint('NOOR rejected after $elapsed: ${online.error}');
    expect(online.error, contains('unavailable'));
    // Before the fix: five attempts with waits of 10+20+30+40 seconds.
    expect(elapsed, lessThan(const Duration(seconds: 45)));
    expect(online.hasTransfer, isFalse);
    final download = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l.downloadVideo),
    );
    expect(download.onPressed, isNotNull);
    debugPrint('NOOR VERIFIED rejected: reason shown, Download available');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
