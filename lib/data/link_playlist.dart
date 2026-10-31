import 'online_media_service.dart' show isWebUrl;

class PlaylistEntry {
  const PlaylistEntry({required this.url, required this.title, this.duration});
  final String url;
  final String title;
  final Duration? duration;
}

/// The videos of a playlist, channel or profile page, from yt-dlp's
/// `--flat-playlist --dump-single-json` (fast: no per-video extraction).
class LinkPlaylist {
  const LinkPlaylist({required this.title, required this.entries});
  final String title;

  /// Empty when the link is a single video.
  final List<PlaylistEntry> entries;

  factory LinkPlaylist.fromInfo(Map<dynamic, dynamic> info) {
    final type = info['_type'];
    final raw = info['entries'];
    final entries = <PlaylistEntry>[];
    if ((type == 'playlist' || type == 'multi_video') && raw is List) {
      final seen = <String>{};
      for (final entry in raw.whereType<Map<dynamic, dynamic>>()) {
        // Nested playlists (e.g. a channel's tabs) are not expanded here.
        if (entry['_type'] == 'playlist') continue;
        final url = [
          entry['url'],
          entry['webpage_url'],
        ].whereType<String>().where(isWebUrl).firstOrNull;
        if (url == null || !seen.add(url)) continue;
        final seconds = entry['duration'];
        entries.add(
          PlaylistEntry(
            url: url,
            title: entry['title'] is String && entry['title'] != ''
                ? entry['title'] as String
                : url,
            duration: seconds is num && seconds > 0
                ? Duration(seconds: seconds.round())
                : null,
          ),
        );
      }
    }
    return LinkPlaylist(
      title: info['title'] is String ? info['title'] as String : '',
      entries: entries,
    );
  }
}
