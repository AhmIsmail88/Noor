import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noor/data/link_playlist.dart';

void main() {
  test('a real channel page lists its videos', () {
    // yt-dlp 2026.10.26, https://www.youtube.com/@jawed/videos, flat.
    final info = jsonDecode(
      File('test/fixtures/jawed_videos.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final list = LinkPlaylist.fromInfo(info);
    expect(list.title, 'jawed - Videos');
    expect(
      list.entries.single.url,
      'https://www.youtube.com/watch?v=jNQXAC9IVRw',
    );
    expect(list.entries.single.title, 'Me at the zoo');
    expect(list.entries.single.duration, const Duration(seconds: 19));
  });

  test(
    'a single video is not a list; bad and repeated entries are skipped',
    () {
      expect(
        LinkPlaylist.fromInfo({'_type': 'video', 'title': 'x'}).entries,
        isEmpty,
      );
      final list = LinkPlaylist.fromInfo({
        '_type': 'playlist',
        'entries': [
          {'url': 'https://example.org/a', 'title': ''},
          {'url': 'https://example.org/a', 'title': 'again'},
          {'url': 'not-a-link', 'webpage_url': 'https://example.org/b'},
          {'url': 'id-only'},
          {'_type': 'playlist', 'url': 'https://example.org/tab'},
        ],
      });
      expect(list.entries.map((e) => e.url), [
        'https://example.org/a',
        'https://example.org/b',
      ]);
      expect(list.entries.first.title, 'https://example.org/a');
    },
  );
}
