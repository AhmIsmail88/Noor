import 'package:flutter_test/flutter_test.dart';
import 'package:noor/data/online_media_service.dart';

void main() {
  // yt-dlp 2026.10.26 `cookies` for a TikTok video (values shortened).
  const tiktok =
      'ttwid=1%7Cii3a%7C1793445307; Domain=.tiktok.com; Path=/; Secure; '
      'Expires=1824549307; tt_csrf_token=229HXJfL-FeC0s; Domain=.tiktok.com; '
      'Path=/; Secure; tt_chain_token="uCFtVIqlSJFZSL0ZiHM8ug=="; '
      'Domain=.tiktok.com; Path=/; Secure; Expires=1808997307';

  test('Set-Cookie style text becomes a Cookie header', () {
    expect(
      cookieHeader(tiktok),
      'ttwid=1%7Cii3a%7C1793445307; tt_csrf_token=229HXJfL-FeC0s; '
      'tt_chain_token=uCFtVIqlSJFZSL0ZiHM8ug==',
    );
    expect(cookieHeader(''), '');
  });

  test('streaming carries the cookies the CDN requires', () {
    final media = ResolvedMedia.fromMap('https://www.tiktok.com/@a/video/1', {
      'url': 'https://v19-webapp-prime.tiktok.com/video/x',
      'title': 't',
      'http_headers': {'Referer': 'https://www.tiktok.com/'},
      'cookies': tiktok,
    });
    expect(media.headers['Referer'], 'https://www.tiktok.com/');
    expect(media.headers['Cookie'], contains('tt_chain_token='));
  });

  test('an explicit Cookie header is not replaced', () {
    final media = ResolvedMedia.fromMap('https://x.org/v', {
      'url': 'https://cdn.x.org/v.mp4',
      'http_headers': {'cookie': 'a=1'},
      'cookies': 'b=2; Path=/',
    });
    expect(media.headers, {'cookie': 'a=1'});
  });
}
