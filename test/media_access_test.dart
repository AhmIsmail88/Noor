import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noor/data/library_controller.dart';
import 'package:noor/data/media_access.dart';

void main() {
  test(
    'missing downloads disappear, inaccessible and unrelated entries stay',
    () async {
      final dir = await Directory.systemTemp.createTemp('noor-prune-');
      final file = File('${dir.path}/library.json');
      final library = LibraryController.forFile(file);
      library.importPath('missing.mp4', isDownload: true);
      library.importPath('offline.mp4', isDownload: true);
      library.importPath('present.mp3', isDownload: true, isAudio: true);
      library.importPath('personal.mp4');
      await library.pruneMissingDownloads(
        exists: (path) async => switch (path) {
          'missing.mp4' => false,
          'offline.mp4' => null,
          _ => true,
        },
      );
      expect(library.findByPath('missing.mp4'), isNull);
      expect(library.query('', LibraryFilter.all), hasLength(3));
      final reopened = LibraryController.forFile(file);
      await reopened.load();
      expect(reopened.findByPath('missing.mp4'), isNull);
      library.dispose();
      reopened.dispose();
      await library.flush();
      await reopened.flush();
      await dir.delete(recursive: true);
    },
  );
  test(
    'folder opens supported media in order without copying originals',
    () async {
      final dir = await Directory.systemTemp.createTemp('noor-folder-');
      final library = LibraryController.forFile(
        File('${dir.path}/library.json'),
      );
      for (final name in ['b.mp4', 'a.mp3', 'skip.txt']) {
        await File('${dir.path}/$name').writeAsString('fixture');
      }
      final items = await importMediaReferences(library, [dir.path]);
      expect(items, hasLength(2));
      expect(items.first.isAudio, isTrue);
      expect(items.first.path, '${dir.path}${Platform.pathSeparator}a.mp3');
      expect(await Directory('${dir.path}/media').exists(), isFalse);
      library.dispose();
      await library.flush();
      await dir.delete(recursive: true);
    },
  );
}
