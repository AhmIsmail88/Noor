import 'package:flutter_test/flutter_test.dart';
import 'package:noor/data/online_error.dart';

void main() {
  test('real engine messages map to a plain reason', () {
    // Messages observed on Windows and Android on 2026-10-31.
    const cases = {
      'ERROR: [youtube] zqOyW5hmeAw: Video unavailable. This video is no '
              'longer available because the YouTube account associated with '
              'this video has been terminated.':
          OnlineErrorKind.unavailable,
      'ERROR: [youtube] aaaaaaaaaaa: This video is unavailable':
          OnlineErrorKind.unavailable,
      'WARNING: [youtube] [Errno 7] No address associated with hostname. '
              'Retrying (1/1)...':
          OnlineErrorKind.network,
      'ERROR: [generic] background-fixture: Unable to download webpage: '
              '[Errno 111] Connection refused':
          OnlineErrorKind.network,
      "ERROR: [youtube] x: Private video. Sign in if you've been granted "
              'access to this video':
          OnlineErrorKind.private,
      "ERROR: [youtube] x: Sign in to confirm you're not a bot":
          OnlineErrorKind.loginRequired,
      'ERROR: Unsupported URL: https://example.com/page':
          OnlineErrorKind.unsupported,
      'Bad state: No video at or below 144p was available.':
          OnlineErrorKind.quality,
      'Requested resolution unavailable': OnlineErrorKind.quality,
      'ERROR: unable to write data: [Errno 28] No space left on device':
          OnlineErrorKind.storage,
      'Online engine files are missing. Use the complete NOOR Windows folder.':
          OnlineErrorKind.engine,
      'Something unexpected': OnlineErrorKind.other,
    };
    for (final entry in cases.entries) {
      expect(classifyOnlineError(entry.key), entry.value, reason: entry.key);
    }
    expect(classifyOnlineError(null), OnlineErrorKind.other);
  });

  test('a removed page is unavailable, not a network problem', () {
    expect(
      classifyOnlineError(
        'ERROR: [generic] x: Unable to download webpage: HTTP Error 404',
      ),
      OnlineErrorKind.unavailable,
    );
  });
}
