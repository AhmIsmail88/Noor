import 'dart:io';

import 'package:path/path.dart' as p;

bool isVideoFile(String path) => const {
  '.mp4',
  '.mkv',
  '.webm',
  '.avi',
  '.mov',
  '.flv',
  '.wmv',
  '.mpeg',
  '.mpg',
  '.m4v',
  '.3gp',
  '.ts',
}.contains(p.extension(path).toLowerCase());

bool isAudioFile(String path) => const {
  '.mp3',
  '.m4a',
  '.aac',
  '.opus',
  '.ogg',
  '.wav',
  '.flac',
  '.wma',
}.contains(p.extension(path).toLowerCase());

/// Only immediate siblings; never follow a symlink into another directory.
/// An audio file queues its audio siblings, so Next also works for music.
Future<List<String>> folderVideos(String path) async {
  final files = <String>[];
  final matches = isAudioFile(path) ? isAudioFile : isVideoFile;
  try {
    await for (final entry in File(path).parent.list(followLinks: false)) {
      if (entry is File && matches(entry.path)) files.add(entry.path);
    }
  } on FileSystemException {
    return [path];
  }
  files.sort(
    (a, b) =>
        p.basename(a).toLowerCase().compareTo(p.basename(b).toLowerCase()),
  );
  return files;
}
