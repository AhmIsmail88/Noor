import 'package:flutter_test/flutter_test.dart';
import 'package:noor/data/online_media_service.dart';

void main() {
  test('the link is found in text shared by apps', () {
    const cases = {
      // TikTok wraps the short link in a sentence and hashtags.
      'Check out this video! #fyp https://vm.tiktok.com/ZMabc123/ '
              'via @someone':
          'https://vm.tiktok.com/ZMabc123/',
      'https://youtu.be/jNQXAC9IVRw?si=xyz':
          'https://youtu.be/jNQXAC9IVRw?si=xyz',
      'Watch (https://www.facebook.com/watch/?v=123).':
          'https://www.facebook.com/watch/?v=123',
      'https://x.com/user/status/1, nice!': 'https://x.com/user/status/1',
      'رابط الفيديو: https://www.tiktok.com/@a/video/1 شاهد':
          'https://www.tiktok.com/@a/video/1',
    };
    for (final entry in cases.entries) {
      expect(firstWebUrl(entry.key), entry.value, reason: entry.key);
    }
  });

  test('text without a web link yields nothing', () {
    expect(firstWebUrl('just some words'), isNull);
    expect(firstWebUrl('ftp://example.org/file'), isNull);
    expect(firstWebUrl('https://user:pass@example.org/'), isNull);
  });
}
