import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:noor/app/l10n/gen/app_localizations.dart';
import 'package:noor/data/library_controller.dart';
import 'package:noor/data/media_item.dart';
import 'package:noor/data/online_media_service.dart';
import 'package:noor/data/download_options.dart';
import 'package:noor/features/downloads/downloads_page.dart';

class FakeOnline extends OnlineMediaService {
  FakeOnline(super.library, Directory root) : super(downloadRoot: root);
  int resolves = 0;
  int transfers = 0;
  bool pausedTransfer = false;
  @override
  bool get hasTransfer => pausedTransfer;
  @override
  bool get canResume => pausedTransfer;
  DownloadOptions? lastOptions;
  @override
  Future<ResolvedMedia> resolve(String input) async {
    resolves++;
    return ResolvedMedia(
      sourceUrl: input,
      url: 'https://example.org/video.mp4',
      title: 'Video',
    );
  }

  @override
  Future<MediaItem> download(
    String input, {
    DownloadOptions options = const DownloadOptions(),
  }) async {
    transfers++;
    lastOptions = options;
    return MediaItem(
      path: 'download.mp4',
      title: 'Video',
      addedAt: DateTime.now(),
    );
  }
}

void main() {
  late Directory dir;
  late LibraryController library;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('noor_online_');
    library = LibraryController.forFile(File('${dir.path}/library.json'));
  });
  tearDown(() async {
    library.dispose();
    await library.flush();
    await dir.delete(recursive: true);
  });

  test('web validation rejects local paths and credentials', () {
    expect(isWebUrl('https://www.youtube.com/watch?v=test'), isTrue);
    expect(isWebUrl('file:///private/video.mp4'), isFalse);
    expect(isWebUrl('https://user:password@example.org/video.mp4'), isFalse);
    expect(isWebUrl('https://'), isFalse);
  });
  test('direct streaming accepts containers and adaptive manifests with query strings', () {
    for (final ext in ['MP4', 'mkv', 'webm', 'avi', 'm3u8', 'mpd']) {
      expect(
        isDirectMediaUrl('https://example.org/movie.$ext?token=test'),
        isTrue,
      );
    }
    expect(isDirectMediaUrl('https://youtube.com/watch?v=test'), isFalse);
  });
  test('a direct stream does not import or download the video', () async {
    final service = OnlineMediaService(library, downloadRoot: dir);
    final media = await service.resolve('https://example.org/movie.mkv');
    expect(media.url, 'https://example.org/movie.mkv');
    expect(library.isEmpty, isTrue);
    expect(service.downloads, isEmpty);
    service.dispose();
  });
  test('history includes only app download files', () async {
    final root = Directory('${dir.path}/downloads');
    final service = OnlineMediaService(library, downloadRoot: root);
    library.importPath('${root.path}/video-a/media.mp4', title: 'Downloaded');
    library.importPath('${dir.path}/external.mp4');
    expect(service.downloads.single.title, 'Downloaded');
    service.dispose();
  });
  test('extractor must return a web stream URL', () {
    expect(
      () => ResolvedMedia.fromMap('https://example.org', {
        'url': 'file:///secret',
      }),
      throwsFormatException,
    );
  });

  test('first download creates its permanent directory before running the engine', () async {
    final root = Directory('${dir.path}/new-downloads');
    final service = OnlineMediaService(library, downloadRoot: root);
    // The isolated test process has no engine bundle. Failure must occur after
    // creating the output directory, without publishing a completed video.
    await expectLater(
      service.download('https://example.org/movie.mp4'),
      throwsA(anything),
    );
    expect(await root.exists(), isTrue);
    expect(library.isEmpty, isTrue);
    service.dispose();
  });

  testWidgets(
    'Streaming is independently available even when downloading is possible',
    (tester) async {
      final service = FakeOnline(library, dir);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: DownloadsPage(library: library, online: service),
            ),
          ),
          GoRoute(
            path: '/player',
            builder: (_, state) => Scaffold(
              body: Text('Watching ${(state.extra as ResolvedMedia).title}'),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Download video'), findsOneWidget);
      expect(find.text('Streaming — watch online'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'https://www.youtube.com/watch?v=sample',
      );
      await tester.ensureVisible(find.text('Download video'));
      await tester.tap(find.text('Download video'));
      await tester.pumpAndSettle();
      expect(service.transfers, 1);
      expect(service.resolves, 0);
      expect(service.lastOptions!.audioOnly, isFalse);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<bool>));
      await tester.tap(find.byType(DropdownButtonFormField<bool>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Audio only (MP3)').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('320 kbps').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Download audio'));
      await tester.tap(find.text('Download audio'));
      await tester.pumpAndSettle();
      expect(service.transfers, 2);
      expect(service.lastOptions!.audioOnly, isTrue);
      expect(service.lastOptions!.audioBitrate, 320);
      // A paused transfer must block a second download, but allow streaming.
      service.pausedTransfer = true;
      service.notifyListeners();
      await tester.pumpAndSettle();
      final downloadButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Download audio'),
      );
      expect(downloadButton.onPressed, isNull);
      await tester.ensureVisible(find.text('Streaming — watch online'));
      await tester.tap(find.text('Streaming — watch online'));
      await tester.pumpAndSettle();
      expect(find.text('Watching Video'), findsOneWidget);
      expect(service.resolves, 1);
      expect(service.transfers, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      service.dispose();
    },
  );
}
