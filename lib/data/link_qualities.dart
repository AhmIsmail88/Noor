import 'download_options.dart';

/// The qualities a link really offers, as the resolution caps the download
/// options understand, each with an approximate size.
class LinkQualities {
  const LinkQualities({this.duration, required this.caps});

  final Duration? duration;

  /// Cap (as in [DownloadOptions.heights]) → approximate bytes, or null when
  /// the source gives no size. Only caps that change the result are listed;
  /// key 0 means "highest available". Empty when the link has no video list.
  final Map<int, int?> caps;

  /// MP3 is re-encoded at a constant bitrate, so its size follows duration.
  int? mp3Size(int kbps) =>
      duration == null ? null : duration!.inSeconds * kbps * 1000 ~/ 8;

  /// [info] is yt-dlp's JSON for one video (`--dump-single-json`).
  factory LinkQualities.fromInfo(Map<dynamic, dynamic> info) {
    final seconds = _num(info['duration']);
    final duration = seconds == null || seconds <= 0
        ? null
        : Duration(milliseconds: (seconds * 1000).round());
    int? sizeOf(Map<dynamic, dynamic> f) {
      final exact = _num(f['filesize']) ?? _num(f['filesize_approx']);
      if (exact != null && exact > 0) return exact.round();
      final tbr = _num(f['tbr']);
      return tbr != null && seconds != null
          ? (tbr * seconds * 125).round()
          : null;
    }

    final formats = info['formats'] is List
        ? (info['formats'] as List).whereType<Map<dynamic, dynamic>>()
        : const <Map<dynamic, dynamic>>[];
    bool has(Object? codec) => codec is String && codec != 'none';

    int? bestAudio;
    for (final f in formats) {
      if (has(f['vcodec']) || !has(f['acodec'])) continue;
      final size = sizeOf(f);
      if (size != null && (bestAudio == null || size > bestAudio)) {
        bestAudio = size;
      }
    }

    // Resolution means the shorter side, matching DownloadOptions (Shorts).
    // The extractor prefers efficient codecs, so the smallest known size at
    // a resolution is the closest estimate of what it downloads.
    final byResolution = <int, int?>{};
    for (final f in formats) {
      if (!has(f['vcodec'])) continue;
      final w = _num(f['width']);
      final h = _num(f['height']);
      final resolution = (w != null && h != null && w > 0 && h > 0)
          ? (w < h ? w : h).round()
          : h?.round();
      if (resolution == null || resolution <= 0) continue;
      var size = sizeOf(f);
      if (size != null && !has(f['acodec'])) {
        size = bestAudio == null ? null : size + bestAudio;
      }
      final known = byResolution[resolution];
      if (!byResolution.containsKey(resolution) ||
          (size != null && (known == null || size < known))) {
        byResolution[resolution] = size;
      }
    }

    final caps = <int, int?>{};
    final resolutions = byResolution.keys.toList()..sort();
    final ascending = DownloadOptions.heights.where((h) => h > 0).toList()
      ..sort();
    for (final r in resolutions) {
      // The smallest cap that still includes r; later (larger) r overwrite,
      // because a cap downloads the best resolution at or below it.
      final cap = ascending.where((c) => c >= r).firstOrNull;
      if (cap != null) caps[cap] = byResolution[r];
    }
    if (resolutions.isNotEmpty) caps[0] = byResolution[resolutions.last];
    return LinkQualities(duration: duration, caps: caps);
  }
}

double? _num(Object? value) => value is num ? value.toDouble() : null;
