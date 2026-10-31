import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noor/data/video_folder.dart';
import 'package:noor/data/library_controller.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'folder queue includes only immediate video files in name order',
    () async {
      final root = await Directory.systemTemp.createTemp('noor-queue-');
      try {
        for (final name in ['b.MKV', 'a.mp4', 'notes.txt', 'c.webm']) {
          await File(p.join(root.path, name)).writeAsBytes([1]);
        }
        await Directory(p.join(root.path, 'nested.mp4')).create();
        final paths = await folderVideos(p.join(root.path, 'a.mp4'));
        expect(paths.map(p.basename), ['a.mp4', 'b.MKV', 'c.webm']);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  test('an audio file queues only its audio siblings', () async {
    final root = await Directory.systemTemp.createTemp('noor-audio-queue-');
    try {
      for (final name in ['2.mp3', '1.FLAC', 'clip.mp4', '3.m4a']) {
        await File(p.join(root.path, name)).writeAsBytes([1]);
      }
      final paths = await folderVideos(p.join(root.path, '2.mp3'));
      expect(paths.map(p.basename), ['1.FLAC', '2.mp3', '3.m4a']);
    } finally {
      await root.delete(recursive: true);
    }
  });
  test(
    'Android document selection group survives durable import and reload',
    () async {
      final root = await Directory.systemTemp.createTemp('noor-group-');
      final db = File(p.join(root.path, 'library.json'));
      final library = LibraryController.forFile(db);
      try {
        final source = await File(p.join(root.path, 'sample.mp4'))
            .writeAsBytes([1, 2]);
        final item = await library.importManagedFile(
          source.path,
          'sample.mp4',
          playbackGroup: 'selection-1',
        );
        await library.flush();
        final reloaded = LibraryController.forFile(db);
        await reloaded.load();
        expect(reloaded.findByPath(item.path)?.playbackGroup, 'selection-1');
        reloaded.dispose();
        await reloaded.flush();
      } finally {
        library.dispose();
        await library.flush();
        await root.delete(recursive: true);
      }
    },
  );
}
