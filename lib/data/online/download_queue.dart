import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../download_options.dart';
import 'links.dart';

class QueuedDownload {
  const QueuedDownload(this.url, this.options);
  final String url;
  final DownloadOptions options;

  Map<String, Object> toJson() => {'url': url, ...options.toMap()};

  static QueuedDownload? fromJson(Map<dynamic, dynamic> json) {
    final url = json['url'];
    if (url is! String || !isWebUrl(url)) return null;
    final options = DownloadOptions(
      audioOnly: json['audioOnly'] == true,
      maxHeight: (json['maxHeight'] as num?)?.toInt() ?? 720,
      audioBitrate: (json['audioBitrate'] as num?)?.toInt() ?? 192,
      subtitles: json['subtitles'] == true,
    );
    try {
      options.validate();
    } on ArgumentError {
      return null;
    }
    return QueuedDownload(url, options);
  }
}

/// The saved queue. Damaged entries are skipped; an unreadable file gives
/// an empty queue rather than blocking downloads.
Future<List<QueuedDownload>> loadQueue(File file) async {
  if (!await file.exists()) return [];
  try {
    final data = jsonDecode(await file.readAsString());
    return [
      if (data is List)
        for (final entry in data)
          if (entry is Map) ?QueuedDownload.fromJson(entry),
    ];
  } catch (error) {
    debugPrint('Ignoring unreadable download queue: $error');
    return [];
  }
}

/// Atomic replace: a crash mid-write leaves the previous queue intact.
Future<void> saveQueue(File file, List<QueuedDownload> queue) async {
  try {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode([for (final item in queue) item.toJson()]),
      flush: true,
    );
    await temp.rename(file.path);
  } catch (error) {
    debugPrint('Download queue save failed: $error');
  }
}
