import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

class StoredMedia {
  const StoredMedia(this.path, this.contentHash);
  final String path;
  final String contentHash;
}

/// Copies imports outside the OS cache, with bounded memory and atomic publish.
class MediaImportStore {
  MediaImportStore(this.directory);
  final Directory directory;

  Future<StoredMedia> save(File source, String originalName) async {
    await directory.create(recursive: true);
    final staging = await directory.createTemp('.import-');
    try {
      final partial = File(p.join(staging.path, 'data.part'));
      await source.openRead().pipe(partial.openWrite());
      final hash = (await sha256.bind(partial.openRead()).first).toString();
      final destination = Directory(p.join(directory.path, hash));
      await destination.create(recursive: true);
      final name = safeFileName(originalName);
      final target = File(p.join(destination.path, name));
      if (!await target.exists()) {
        await partial.rename(target.path);
      }
      return StoredMedia(target.path, hash);
    } finally {
      await staging.delete(recursive: true);
    }
  }

  static String safeFileName(String name) {
    final cleaned = p
        .basename(name.replaceAll('\\', '/'))
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'[. ]+$'), '');
    return cleaned.isEmpty || cleaned == '.' || cleaned == '..'
        ? 'video'
        : cleaned;
  }
}
