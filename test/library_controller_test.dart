import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:noor/data/library_controller.dart';
import 'package:noor/data/media_item.dart';

void main() {
  late Directory dir;
  late File file;
  final controllers = <LibraryController>[];
  LibraryController controller() {
    final c = LibraryController.forFile(file);
    controllers.add(c);
    return c;
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('noor_test');
    file = File('${dir.path}${Platform.pathSeparator}library.json');
  });

  tearDown(() async {
    await Future.wait(controllers.map((c) => c.flush()));
    controllers.clear();
    await dir.delete(recursive: true);
  });

  test('restore undoes a removal with history intact', () async {
    final c = controller();
    final item = c.importPath('${dir.path}/clip.mp4');
    c.saveProgress(item.path, positionMs: 30000, durationMs: 90000);
    c.toggleFavorite(item.path);
    c.remove(item.path);
    expect(c.findByPath(item.path), isNull);
    c.restore(item);
    final back = c.findByPath(item.path)!;
    expect(back.positionMs, 30000);
    expect(back.favorite, isTrue);
  });

  test('missing files are found in the background', () async {
    final c = controller();
    final present = File('${dir.path}/present.mp4');
    await present.writeAsBytes([1]);
    c.importPath(present.path);
    c.importPath('${dir.path}/gone.mp4');
    expect(c.isMissing('${dir.path}/gone.mp4'), isFalse);
    await c.checkFiles();
    expect(c.isMissing('${dir.path}/gone.mp4'), isTrue);
    expect(c.isMissing(present.path), isFalse);
    await present.delete();
    await c.checkFiles();
    expect(c.isMissing(present.path), isTrue);
  });

  test('short clips are not finished at zero or halfway', () {
    final item = MediaItem(
      path: '/short.mp4',
      title: 'short',
      addedAt: DateTime.now(),
      durationMs: 8000,
    );
    expect(item.isFinished, isFalse);
    item.positionMs = 4000;
    expect(item.isFinished, isFalse);
    item.positionMs = 8000;
    expect(item.isFinished, isTrue);
  });

  test('successive flushes persist the latest edit', () async {
    final c = controller();
    c.importPath('/latest.mp4');
    await c.flush();
    c.saveProgress('/latest.mp4', positionMs: 2000, durationMs: 8000);
    await c.flush();
    c.saveProgress('/latest.mp4', positionMs: 4000, durationMs: 8000);
    await c.flush();
    c.dispose();
    final reloaded = controller();
    await reloaded.load();
    expect(reloaded.findByPath('/latest.mp4')?.positionMs, 4000);
    reloaded.dispose();
  });

  test('progress is bounded by the duration', () {
    final c = controller();
    c.importPath('/bounded.mp4');
    c.saveProgress('/bounded.mp4', positionMs: -100, durationMs: 8000);
    expect(c.findByPath('/bounded.mp4')?.positionMs, 0);
    c.saveProgress('/bounded.mp4', positionMs: 9000, durationMs: 8000);
    expect(c.findByPath('/bounded.mp4')?.positionMs, 8000);
    c.dispose();
  });

  test('an invalid item does not discard subsequent valid items', () async {
    await file.writeAsString(
      jsonEncode({
        'version': 1,
        'items': [
          {'path': '/bad.mp4', 'title': 42},
          {'path': '/good.mp4', 'title': 'Good'},
        ],
      }),
    );
    final c = controller();
    await c.load();
    expect(c.findByPath('/good.mp4')?.title, 'Good');
    expect(await File('${file.path}.corrupt').exists(), isFalse);
    c.dispose();
  });

  test('a future format is never overwritten', () async {
    const original = '{"version":99,"items":[]}';
    await file.writeAsString(original);
    final c = controller();
    await c.load();
    c.importPath('/new.mp4');
    await c.flush();
    expect(await file.readAsString(), original);
    c.dispose();
  });

  test('dispose flushes a pending edit without waiting for debounce', () async {
    final c = controller();
    c.importPath('/last.mp4');
    c.saveProgress('/last.mp4', positionMs: 1234, durationMs: 8000);
    c.dispose();
    await c.flush();
    final reloaded = controller();
    await reloaded.load();
    expect(reloaded.findByPath('/last.mp4')?.positionMs, 1234);
    reloaded.dispose();
  });

  test('import is idempotent and derives the title from the file name', () {
    final c = controller();
    final a = c.importPath('/videos/My Movie.mp4');
    final b = c.importPath('/videos/My Movie.mp4');
    expect(identical(a, b), isTrue);
    expect(a.title, 'My Movie');
    expect(c.query('', LibraryFilter.all).length, 1);
    c.dispose();
  });

  test('progress and favorites survive a reload', () async {
    final a = controller();
    a.importPath('/videos/a.mp4');
    a.saveProgress('/videos/a.mp4', positionMs: 42000, durationMs: 600000);
    a.toggleFavorite('/videos/a.mp4');
    await a.flush();
    a.dispose();

    final b = controller();
    await b.load();
    final item = b.findByPath('/videos/a.mp4')!;
    expect(item.positionMs, 42000);
    expect(item.durationMs, 600000);
    expect(item.favorite, isTrue);
    expect(item.lastPlayedAt, isNotNull);
    b.dispose();
  });

  test('continueWatching skips finished and barely-started items', () {
    final c = controller();
    for (final p in ['/a.mp4', '/b.mp4', '/c.mp4']) {
      c.importPath(p);
    }
    c.saveProgress('/a.mp4', positionMs: 60000, durationMs: 600000);
    c.saveProgress(
      '/b.mp4',
      positionMs: 595000,
      durationMs: 600000,
    ); // finished
    c.saveProgress(
      '/c.mp4',
      positionMs: 2000,
      durationMs: 600000,
    ); // barely started
    expect(c.continueWatching.map((i) => i.path), ['/a.mp4']);
    c.dispose();
  });

  test('query filters by text and by favorites', () {
    final c = controller();
    c.importPath('/x/Alpha.mp4');
    c.importPath('/x/Beta.mp4');
    c.toggleFavorite('/x/Beta.mp4');
    expect(c.query('alp', LibraryFilter.all).single.title, 'Alpha');
    expect(c.query('', LibraryFilter.favorites).single.title, 'Beta');
    c.dispose();
  });

  test('a corrupt library file is ignored instead of crashing', () async {
    await file.writeAsString('{ not json');
    final c = controller();
    await c.load();
    expect(c.isEmpty, isTrue);
    c.dispose();
  });
}
