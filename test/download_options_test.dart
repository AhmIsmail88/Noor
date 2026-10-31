import 'package:flutter_test/flutter_test.dart';
import 'package:noor/data/download_options.dart';
import 'package:noor/data/media_item.dart';

void main() {
  test('each video quality caps both separate and combined formats', () {
    for (final height in DownloadOptions.heights.where((h) => h > 0)) {
      final options = DownloadOptions(maxHeight: height);
      expect(options.format, 'bv*+ba/b');
      expect(
        options.arguments,
        containsAllInOrder(['--format-sort', 'res:$height']),
      );
      expect(
        options.arguments,
        containsAllInOrder(['--merge-output-format', 'mkv']),
      );
      expect(options.arguments, isNot(contains('--extract-audio')));
    }
    expect(const DownloadOptions(maxHeight: 0).format, 'bv*+ba/b');
    expect(
      const DownloadOptions(maxHeight: 360).acceptsDimensions(360, 640),
      isTrue,
    );
    expect(
      const DownloadOptions(maxHeight: 144).acceptsDimensions(360, 640),
      isFalse,
    );
    expect(
      const DownloadOptions(maxHeight: 144).acceptsDimensions(144, 256),
      isTrue,
    );
    expect(
      const DownloadOptions(maxHeight: 360).acceptsDimensions(640, 360),
      isTrue,
    );
  });
  test('audio mode extracts MP3 at the chosen bitrate', () {
    for (final bitrate in DownloadOptions.bitrates) {
      final args = DownloadOptions(
        audioOnly: true,
        audioBitrate: bitrate,
      ).arguments;
      expect(
        args,
        containsAllInOrder([
          '--format',
          'ba/b',
          '--extract-audio',
          '--audio-format',
          'mp3',
          '--audio-quality',
          '${bitrate}K',
        ]),
      );
      expect(args, isNot(contains('--merge-output-format')));
    }
    expect(
      () => const DownloadOptions(maxHeight: -1).arguments,
      throwsArgumentError,
    );
    expect(
      () => const DownloadOptions(audioBitrate: 0).arguments,
      throwsArgumentError,
    );
  });
  test(
    'public download metadata survives serialization without path rewriting',
    () {
      final item = MediaItem(
        path: 'content://media/external/downloads/123',
        title: 'Title',
        addedAt: DateTime.now(),
        isDownload: true,
        isAudio: true,
        savedLocation: 'Download/NOOR/Title.mp3',
        sizeBytes: 123,
      );
      final restored = MediaItem.fromJson(item.toJson())!;
      expect(restored.path, item.path);
      expect(restored.isContentUri, isTrue);
      expect(restored.isAudio, isTrue);
      expect(restored.isDownload, isTrue);
      expect(restored.savedLocation, item.savedLocation);
      expect(restored.sizeBytes, 123);
    },
  );
}
