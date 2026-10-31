import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'library_controller.dart';
import 'media_item.dart';

const mediaAccessChannel = MethodChannel('noor/media_access');
const audioExtensions = [
  'mp3',
  'm4a',
  'aac',
  'opus',
  'ogg',
  'wav',
  'flac',
  'wma',
];
const videoExtensions = [
  'mp4',
  'mkv',
  'avi',
  'mov',
  'webm',
  'mpeg',
  'mpg',
  'm4v',
  '3gp',
  'ts',
  'flv',
  'wmv',
];

Future<List<MediaItem>> importMediaReferences(
  LibraryController library,
  List<dynamic> entries,
) async {
  final items = <MediaItem>[];
  for (final entry in entries) {
    if (entry is String) {
      final type = await FileSystemEntity.type(entry);
      if (type == FileSystemEntityType.directory) {
        final files = await Directory(entry)
            .list()
            .where((e) => e is File)
            .toList();
        files.sort(
          (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
        );
        items.addAll(
          await importMediaReferences(
            library,
            files.map((e) => e.path).toList(),
          ),
        );
      } else if (type == FileSystemEntityType.file) {
        final ext = p.extension(entry).replaceFirst('.', '').toLowerCase();
        if ([...audioExtensions, ...videoExtensions].contains(ext)) {
          items.add(
            library.importPath(entry, isAudio: audioExtensions.contains(ext)),
          );
        }
      }
    } else if (entry is Map && entry['path'] is String) {
      var path = entry['path'] as String;
      if (path.startsWith('file:')) path = Uri.parse(path).toFilePath();
      items.add(
        library.importPath(
          path,
          title: entry['title'] as String?,
          isAudio: entry['isAudio'] == true,
          sizeBytes: (entry['sizeBytes'] as num?)?.toInt(),
        ),
      );
    }
  }
  if (Platform.isAndroid) await library.groupSelection(items);
  await library.flush();
  return items;
}
