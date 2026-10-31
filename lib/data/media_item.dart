class MediaItem {
  MediaItem({
    required this.path,
    required this.title,
    required this.addedAt,
    this.sizeBytes,
    this.durationMs = 0,
    this.positionMs = 0,
    this.lastPlayedAt,
    this.favorite = false,
    this.contentHash,
    this.playbackGroup,
    this.isDownload = false,
    this.isAudio = false,
    this.savedLocation,
  });

  final String path; // unique key
  String title;
  final DateTime addedAt;
  int? sizeBytes;
  int durationMs;
  int positionMs;
  DateTime? lastPlayedAt;
  bool favorite;
  final String? contentHash;
  String? playbackGroup;
  final bool isDownload;
  final bool isAudio;
  final String? savedLocation;
  bool get isContentUri => Uri.tryParse(path)?.scheme == 'content';

  double get progress =>
      durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0;

  /// Use at most 5% of the duration as the completion margin for short clips.
  bool get isFinished =>
      durationMs > 0 &&
      positionMs > 0 &&
      positionMs >= durationMs - (durationMs ~/ 20).clamp(0, 10000);

  Map<String, dynamic> toJson() => {
    'path': path,
    'title': title,
    'addedAt': addedAt.toIso8601String(),
    'sizeBytes': sizeBytes,
    'durationMs': durationMs,
    'positionMs': positionMs,
    'lastPlayedAt': lastPlayedAt?.toIso8601String(),
    'favorite': favorite,
    'contentHash': contentHash,
    'playbackGroup': playbackGroup,
    'isDownload': isDownload,
    'isAudio': isAudio,
    'savedLocation': savedLocation,
  };

  static MediaItem? fromJson(Map<String, dynamic> j) {
    final path = j['path'];
    if (path is! String || path.isEmpty) return null;
    return MediaItem(
      path: path,
      title: (j['title'] as String?) ?? titleFromPath(path),
      addedAt:
          DateTime.tryParse((j['addedAt'] as String?) ?? '') ?? DateTime.now(),
      sizeBytes: (j['sizeBytes'] as num?)?.toInt(),
      durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
      positionMs: (j['positionMs'] as num?)?.toInt() ?? 0,
      lastPlayedAt: DateTime.tryParse((j['lastPlayedAt'] as String?) ?? ''),
      favorite: (j['favorite'] as bool?) ?? false,
      contentHash: j['contentHash'] as String?,
      playbackGroup: j['playbackGroup'] as String?,
      isDownload: j['isDownload'] == true,
      isAudio: j['isAudio'] == true,
      savedLocation: j['savedLocation'] as String?,
    );
  }
}

String titleFromPath(String path) {
  final name = path.split(RegExp(r'[\\/]')).last;
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}
