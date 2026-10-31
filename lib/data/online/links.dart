/// Pure helpers for web links, shared text and the Windows engine's
/// progress output. No state; safe to use anywhere.
library;

class ResolvedMedia {
  const ResolvedMedia({
    required this.sourceUrl,
    required this.url,
    required this.title,
    this.headers = const {},
  });
  final String sourceUrl;
  final String url;
  final String title;
  final Map<String, String> headers;

  factory ResolvedMedia.fromMap(String source, Map<String, dynamic> data) {
    final url = data['url'] as String?;
    if (url == null || !isWebUrl(url)) {
      throw const FormatException(
        'No playable stream was returned by this source.',
      );
    }
    final headers = <String, String>{};
    final raw = data['http_headers'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.key is String && entry.value is String) {
          headers[entry.key as String] = entry.value as String;
        }
      }
    }
    // Some CDNs (TikTok) refuse the stream without the extractor's session
    // cookies, which yt-dlp reports separately from http_headers.
    final cookies = data['cookies'];
    if (cookies is String &&
        !headers.keys.any((k) => k.toLowerCase() == 'cookie')) {
      final cookie = cookieHeader(cookies);
      if (cookie.isNotEmpty) headers['Cookie'] = cookie;
    }
    return ResolvedMedia(
      sourceUrl: source,
      url: url,
      title: data['title'] as String? ?? Uri.parse(source).host,
      headers: headers,
    );
  }
}

/// Turns yt-dlp's `cookies` field (Set-Cookie style: `a=1; Domain=…; Path=/;
/// Secure; b="2"; Expires=…`) into a request `Cookie` header: `a=1; b=2`.
String cookieHeader(String setCookies) {
  const attributes = {
    'domain',
    'path',
    'expires',
    'max-age',
    'secure',
    'httponly',
    'samesite',
    'priority',
    'partitioned',
    'version',
    'comment',
  };
  final pairs = <String>[];
  for (final part in setCookies.split(';')) {
    final token = part.trim();
    final eq = token.indexOf('=');
    if (eq <= 0) continue; // flags such as Secure
    final name = token.substring(0, eq).trim();
    if (attributes.contains(name.toLowerCase())) continue;
    var value = token.substring(eq + 1).trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    pairs.add('$name=$value');
  }
  return pairs.join('; ');
}

bool isWebUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

/// The first web link in shared text, e.g. TikTok's "Check out this video
/// https://vm.tiktok.com/ZM6abc/ #fyp". Trailing punctuation is dropped.
String? firstWebUrl(String text) {
  for (final match in RegExp(r'https?://[^\s<>"]+').allMatches(text)) {
    final url = match.group(0)!.replaceFirst(RegExp(r'[.,;:!?)\]]+$'), '');
    if (isWebUrl(url)) return url;
  }
  return null;
}

bool isDirectMediaUrl(String value) => RegExp(
  r'\.(mp4|mkv|webm|avi|mov|flv|wmv|mpeg|mpg|m4v|3gp|ts|m3u8|mpd)$',
  caseSensitive: false,
).hasMatch(Uri.parse(value).path);

/// Parses `__NOOR_PROGRESS__ 45.3%|1234.5|12` (speed in B/s, eta in s;
/// either may be `NA`) printed by the Windows engine's progress template.
({double fraction, double? speed, Duration? eta})? parseProgressLine(
  String line,
) {
  final match = RegExp(r'__NOOR_PROGRESS__\s*([\d.]+)%(?:\|([^|]*)\|(\S*))?')
      .firstMatch(line);
  if (match == null) return null;
  final fraction = (double.parse(match.group(1)!) / 100).clamp(0.0, 1.0);
  final speed = double.tryParse(match.group(2)?.trim() ?? '');
  final seconds = double.tryParse(match.group(3)?.trim() ?? '');
  return (
    fraction: fraction,
    speed: speed == null || speed <= 0 ? null : speed,
    eta: seconds == null || seconds < 0
        ? null
        : Duration(seconds: seconds.round()),
  );
}
