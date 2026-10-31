class DownloadOptions {
  const DownloadOptions({
    this.audioOnly = false,
    this.maxHeight = 720,
    this.audioBitrate = 192,
    this.subtitles = false,
  });
  final bool audioOnly;

  /// Embed Arabic/English subtitles in the MKV when the source has them.
  /// Ignored for audio-only downloads.
  final bool subtitles;

  /// Only uploaded subtitles: automatic ones are machine-made and their
  /// many translations are often rate-limited, which fails the download.
  static const subtitleLanguages = 'ar.*,en.*';

  /// Zero selects the highest available quality, without upscaling.
  final int maxHeight;
  final int audioBitrate;
  static const heights = [0, 2160, 1440, 1080, 720, 480, 360, 240, 144];
  static const bitrates = [128, 192, 320];

  void validate() {
    if (!heights.contains(maxHeight) || !bitrates.contains(audioBitrate)) {
      throw ArgumentError('Invalid download quality');
    }
  }

  String get format => audioOnly ? 'ba/b' : 'bv*+ba/b';

  // Resolution means the shorter dimension, including portrait/Shorts videos.
  bool acceptsDimensions(num? width, num? height) =>
      audioOnly ||
      maxHeight == 0 ||
      width == null ||
      height == null ||
      width <= 0 ||
      height <= 0 ||
      (width < height ? width : height) <= maxHeight;

  List<String> get arguments {
    validate();
    return [
      '--format',
      format,
      if (audioOnly) ...[
        '--extract-audio',
        '--audio-format',
        'mp3',
        '--audio-quality',
        '${audioBitrate}K',
      ] else ...[
        '--format-sort',
        maxHeight == 0 ? 'res' : 'res:$maxHeight',
        '--merge-output-format',
        'mkv',
        if (subtitles) ...[
          '--write-subs',
          '--sub-langs',
          subtitleLanguages,
          '--embed-subs',
        ],
      ],
    ];
  }

  Map<String, Object> toMap() => {
    'audioOnly': audioOnly,
    'maxHeight': maxHeight,
    'audioBitrate': audioBitrate,
    'subtitles': subtitles,
  };
}
