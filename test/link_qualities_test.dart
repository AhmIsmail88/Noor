import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noor/data/link_qualities.dart';

void main() {
  test('real YouTube formats become caps with sizes', () {
    // yt-dlp 2026.10.21 output for "Me at the zoo" (jNQXAC9IVRw), trimmed.
    final info = jsonDecode(
      File('test/fixtures/zoo_formats.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final q = LinkQualities.fromInfo(info);
    // Only 144p and 240p exist: higher caps would download the same file.
    expect(q.caps.keys.toSet(), {0, 144, 240});
    // The real 240p download was 474,596 bytes (AV1 395 + Opus 251).
    expect(q.caps[240], inInclusiveRange(400000, 650000));
    expect(q.caps[0], q.caps[240]);
    expect(q.caps[144]!, lessThan(q.caps[240]!));
    expect(q.duration, const Duration(seconds: 19));
    expect(q.mp3Size(128), 19 * 16000);
  });

  test('portrait video uses the shorter side, like the download filter', () {
    final q = LinkQualities.fromInfo({
      'duration': 10,
      'formats': [
        {
          'width': 1080,
          'height': 1920,
          'vcodec': 'avc1',
          'acodec': 'mp4a',
          'filesize': 9000000,
        },
        {
          'width': 360,
          'height': 640,
          'vcodec': 'avc1',
          'acodec': 'mp4a',
          'filesize': 1000000,
        },
      ],
    });
    expect(q.caps, {360: 1000000, 1080: 9000000, 0: 9000000});
  });

  test('a link without a format list offers no choices', () {
    expect(LinkQualities.fromInfo({'url': 'https://x/v.mp4'}).caps, isEmpty);
    expect(LinkQualities.fromInfo({}).mp3Size(128), isNull);
  });
}
