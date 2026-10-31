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
import 'package:noor/data/library_controller.dart';
import 'package:noor/data/media_item.dart';
import 'package:noor/features/downloads/downloads_page.dart';
import 'package:noor/features/library/media_thumbnail.dart';
import 'package:noor/features/library/media_tile.dart';

// TED-Ed, 4:17, uploaded Arabic and English subtitles (checked 2026-10-31).
const withSubtitles = 'https://www.youtube.com/watch?v=l_NYrWqUR40';
const channel = 'https://www.youtube.com/@jawed/videos'; // one video

Future<void> tick(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('thumbnail, subtitles with speed, and channel picking', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    final noor = tester.widget<NoorApp>(find.byType(NoorApp));
    final library = noor.library;
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    Future<void> waitFor(bool Function() done, String what, int ticks) async {
      for (var i = 0; i < ticks && !done(); i++) {
        await tick(tester);
      }
      expect(done(), isTrue, reason: what);
    }

    Set<String> paths() =>
        library.query('', LibraryFilter.all).map((e) => e.path).toSet();

    // 1. A frame is captured past 10% and shown in the library.
    final root = Platform.isAndroid
        ? '/data/user/0/com.noor.player.noor/files/format-fixtures'
        : '${Directory.current.path}/build';
    final clip = library.importPath('$root/noor_format_vp9.webm')
      ..positionMs = 0
      ..thumbnailPath = null;
    openPlayerRoute(router, clip.path);
    await waitFor(() => clip.thumbnailPath != null, 'thumbnail captured', 40);
    final thumb = File(clip.thumbnailPath!);
    final bytes = await tester.runAsync(() => thumb.length());
    debugPrint('NOOR VERIFIED thumbnail: ${thumb.path} ($bytes bytes)');
    expect(bytes, greaterThan(2048));
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.navLibrary).last);
    await tester.pumpAndSettle();
    // The library may be long (phone) and hold other items with the same
    // title; scroll to the row of this exact path.
    final row = find.byWidgetPredicate(
      (w) => w is MediaTile && w.item.path == clip.path,
    );
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.descendant(of: row, matching: find.byType(MediaThumbnail)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.byType(Image)),
      findsOneWidget,
    );

    // 2. Subtitles embedded in a download, with speed and time left.
    await tester.tap(find.text(l.navDownloads).last);
    await tester.pumpAndSettle();
    final online = tester
        .widget<DownloadsPage>(find.byType(DownloadsPage))
        .online;
    await tester.enterText(find.byType(TextField), withSubtitles);
    await tester.tap(find.byKey(const ValueKey('video-quality')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('144p').last);
    await tester.pumpAndSettle();
    final subtitlesSwitch = find.widgetWithText(
      SwitchListTile,
      l.includeSubtitles,
    );
    await tester.ensureVisible(subtitlesSwitch);
    await tester.tap(subtitlesSwitch);
    await tester.pumpAndSettle();
    var before = paths();
    await tester.ensureVisible(find.text(l.downloadVideo));
    await tester.tap(find.text(l.downloadVideo));
    await tester.pump();
    double? seenSpeed;
    Duration? seenEta;
    for (var i = 0; i < 300 && paths().difference(before).isEmpty; i++) {
      seenSpeed ??= online.speed;
      seenEta ??= online.eta;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(online.error, isNull, reason: online.error);
    final subtitled = library.findByPath(paths().difference(before).single)!;
    debugPrint(
      'NOOR VERIFIED card stats: speed=$seenSpeed B/s, eta=$seenEta, '
      'file=${subtitled.savedLocation}',
    );
    expect(seenSpeed, isNotNull, reason: 'speed shown while downloading');
    openPlayerRoute(router, subtitled.path);
    List<String> subtitleLanguages() {
      final videos = find.byType(Video);
      if (videos.evaluate().isEmpty) return [];
      return tester
          .widget<Video>(videos)
          .controller
          .player
          .state
          .tracks
          .subtitle
          .where((t) => t.id != 'auto' && t.id != 'no')
          .map((t) => t.language ?? t.title ?? t.id)
          .toList();
    }

    await waitFor(
      () => subtitleLanguages().length >= 2,
      'embedded subtitle tracks',
      30,
    );
    debugPrint('NOOR VERIFIED subtitles: ${subtitleLanguages()}');
    router.pop();
    await tester.pumpAndSettle();

    // 3. Pick from a channel; the choice downloads through the queue.
    before = paths();
    // Back to the top of the page: the link field and buttons are there.
    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
    }
    // After the player closes, keyboard focus is elsewhere and enterText
    // would type into the wrong client; set the field's text directly.
    tester.widget<TextField>(find.byType(TextField)).controller!.text = channel;
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.pickFromPlaylist));
    await tester.pump();
    final seen = <String>{};
    for (var i = 0; i < 60 && find.text(l.selectAll).evaluate().isEmpty; i++) {
      seen.add('busy=${online.busy} stage=${online.stage} err=${online.error}');
      for (final t in [l.notAPlaylist, l.invalidLink]) {
        if (find.text(t).evaluate().isNotEmpty) seen.add('shown: $t');
      }
      await tick(tester);
    }
    debugPrint(
      'NOOR playlist states: $seen buttons='
      '${find.text(l.pickFromPlaylist).evaluate().length} '
      'hit=${find.text(l.pickFromPlaylist).hitTestable().evaluate().length}',
    );
    expect(find.text(l.selectAll), findsOneWidget, reason: 'playlist dialog');
    expect(find.text('Me at the zoo'), findsOneWidget);
    await tester.tap(find.text(l.downloadSelected(1)));
    await tester.pumpAndSettle();
    await waitFor(
      () =>
          paths().difference(before).length == 1 &&
          !online.hasTransfer &&
          online.queue.isEmpty,
      'channel pick downloaded via the queue',
      240,
    );
    final MediaItem picked = library.findByPath(
      paths().difference(before).single,
    )!;
    debugPrint('NOOR VERIFIED channel pick: ${picked.savedLocation}');
    expect(picked.title, 'Me at the zoo');
    await tester.runAsync(library.flush);
  }, timeout: const Timeout(Duration(minutes: 12)));
}
