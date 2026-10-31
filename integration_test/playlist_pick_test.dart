import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noor/main.dart' as app;
import 'package:noor/app/l10n/gen/app_localizations.dart';
import 'package:noor/features/downloads/downloads_page.dart';

Future<void> tick(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('channel link opens the picker', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
    await tester.tap(find.text(l.navDownloads).last);
    await tester.pumpAndSettle();
    final online = tester
        .widget<DownloadsPage>(find.byType(DownloadsPage))
        .online;
    await tester.enterText(
      find.byType(TextField),
      'https://www.youtube.com/@jawed/videos',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.pickFromPlaylist));
    await tester.pump();
    final seen = <String>{};
    for (var i = 0; i < 40 && find.text(l.selectAll).evaluate().isEmpty; i++) {
      seen.add('busy=${online.busy} stage=${online.stage} err=${online.error}');
      for (final t in [l.notAPlaylist, l.invalidLink]) {
        if (find.text(t).evaluate().isNotEmpty) seen.add('shown: $t');
      }
      await tick(tester);
    }
    debugPrint('NOOR playlist states: $seen');
    expect(find.text(l.selectAll), findsOneWidget);
    debugPrint('NOOR VERIFIED picker opened');
  });
}
