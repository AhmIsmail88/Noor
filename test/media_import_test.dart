import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noor/data/library_controller.dart';
import 'package:noor/data/media_import_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory cache;
  late File libraryFile;
  late LibraryController library;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('noor_import_');
    cache = await Directory(p.join(root.path, 'cache')).create();
    libraryFile = File(p.join(root.path, 'support', 'library.json'));
    library = LibraryController.forFile(libraryFile);
  });

  tearDown(() async {
    await library.flush();
    library.dispose();
    await library.flush();
    await root.delete(recursive: true);
  });

  test('import keeps original name and bytes after cache deletion', () async {
    final source = await File(p.join(cache.path, '23467.mp4'))
        .writeAsBytes([1, 2, 3, 4]);
    final item = await library.importManagedFile(
      source.path,
      'رحلة العائلة.mp4',
    );
    expect(item.title, 'رحلة العائلة');
    expect(p.basename(item.path), 'رحلة العائلة.mp4');
    await cache.delete(recursive: true);
    expect(await File(item.path).readAsBytes(), [1, 2, 3, 4]);
    final reloaded = LibraryController.forFile(libraryFile);
    await reloaded.load();
    expect(reloaded.findByPath(item.path)?.title, 'رحلة العائلة');
    reloaded.dispose();
    await reloaded.flush();
  });

  test(
    'migration and reselect preserve progress and restore original title',
    () async {
      final source = await File(p.join(cache.path, '23465.mp4'))
          .writeAsBytes([5, 6, 7]);
      library.importPath(source.path);
      library.saveProgress(source.path, positionMs: 23400, durationMs: 60000);
      library.toggleFavorite(source.path);
      await library.migrateCachedImports(cache);
      final migrated = library.query('', LibraryFilter.all).single;
      expect(p.isWithin(cache.path, migrated.path), isFalse);
      expect(migrated.positionMs, 23400);
      final renamed = await library.importManagedFile(
        source.path,
        'Original.mp4',
      );
      expect(library.query('', LibraryFilter.all), hasLength(1));
      expect(renamed.title, 'Original');
      expect(renamed.positionMs, 23400);
      expect(renamed.favorite, isTrue);
    },
  );

  test('same name with different bytes never overwrites a video', () async {
    final a = await File(p.join(cache.path, 'a')).writeAsBytes([1]);
    final b = await File(p.join(cache.path, 'b')).writeAsBytes([2]);
    final first = await library.importManagedFile(a.path, 'Movie.mp4');
    final second = await library.importManagedFile(b.path, 'Movie.mp4');
    expect(first.path, isNot(second.path));
    expect(await File(first.path).readAsBytes(), [1]);
    expect(await File(second.path).readAsBytes(), [2]);
  });

  test(
    'missing source does not add a library item or leave a partial copy',
    () async {
      await expectLater(
        library.importManagedFile(
          p.join(cache.path, 'missing.mp4'),
          'Movie.mp4',
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(library.isEmpty, isTrue);
      final media = Directory(p.join(libraryFile.parent.path, 'media'));
      expect(await media.list().toList(), isEmpty);
    },
  );

  test('unavailable legacy cache is retained for recovery', () async {
    final missing = p.join(cache.path, 'missing.mp4');
    library.importPath(missing);
    await library.migrateCachedImports(cache);
    expect(library.findByPath(missing), isNotNull);
  });

  test('untrusted file names cannot escape managed storage', () {
    expect(MediaImportStore.safeFileName('../../Movie.mp4'), 'Movie.mp4');
    expect(MediaImportStore.safeFileName(r'..\..\Movie.mp4'), 'Movie.mp4');
    expect(MediaImportStore.safeFileName('..'), 'video');
  });
}
