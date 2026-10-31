import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'library_controller.dart';
import 'media_item.dart';
import 'download_options.dart';
import 'media_import_store.dart';

enum OnlineStage {
  idle,
  preparing,
  downloading,
  completed,
  failed,
  cancelled,
  paused,
  waiting,
}

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
    return ResolvedMedia(
      sourceUrl: source,
      url: url,
      title: data['title'] as String? ?? Uri.parse(source).host,
      headers: headers,
    );
  }
}

bool isWebUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

bool isDirectMediaUrl(String value) => RegExp(
  r'\.(mp4|mkv|webm|avi|mov|flv|wmv|mpeg|mpg|m4v|3gp|ts|m3u8|mpd)$',
  caseSensitive: false,
).hasMatch(Uri.parse(value).path);

/// Coordinates durable transfers; completed files live outside OS cache.
class OnlineMediaService extends ChangeNotifier {
  OnlineMediaService(this.library, {Directory? downloadRoot})
    : _root = downloadRoot;
  final LibraryController library;
  static const _channel = MethodChannel('noor/online_media');
  static const _events = EventChannel('noor/online_progress');
  StreamSubscription<dynamic>? _subscription;
  Process? _process;
  Directory? _root;
  Timer? _poll;
  Map<String, dynamic>? _job;
  bool _loadingJob = false;
  bool _pausing = false;
  bool _polling = false;
  String? _lastNativeSnapshot;
  Future<void> _jobWrites = Future<void>.value();
  bool get hasTransfer =>
      _job != null &&
      _job!.containsKey('url') &&
      // 'rejected' is a failure no retry can fix: it is final, and must not
      // keep the Download button disabled the way a resumable failure does.
      !['completed', 'cancelled', 'rejected'].contains(_job!['state']);
  bool get canResume =>
      hasTransfer && (_job?['state'] == 'paused' || _job?['state'] == 'failed');
  bool get canPause =>
      hasTransfer && !canResume && _job?['state'] != 'publishing';
  static const _desktopChannel = MethodChannel('noor/download_tray');
  bool _disposed = false;
  bool busy = false;
  bool _cancelled = false;
  bool _resolving = false;
  OnlineStage stage = OnlineStage.idle;
  double? progress;
  String? error;
  MediaItem? lastDownload;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadHistory() async {
    _root ??= Directory(
      p.join((await getApplicationSupportDirectory()).path, 'downloads'),
    );
    if (!_loadingJob) {
      _loadingJob = true;
      if (Platform.isAndroid) {
        await _refreshJob();
        if (hasTransfer && _job?['alive'] == false && !canResume) {
          await _channel.invokeMethod<void>('jobResume');
        }
        _poll ??= Timer.periodic(
          const Duration(seconds: 1),
          (_) => unawaited(_refreshJob()),
        );
      } else if (Platform.isWindows) {
        _desktopChannel.setMethodCallHandler((call) async {
          if (call.method == 'pause') await pause();
          if (call.method == 'resume') await resume();
          if (call.method == 'cancel') await cancel();
        });
        final saved = File(p.join(_root!.path, 'active-job.json'));
        if (await saved.exists()) {
          try {
            final data = jsonDecode(await saved.readAsString());
            _job = data is Map<String, dynamic> ? data : null;
          } catch (error) {
            // A truncated snapshot must not block every future download.
            debugPrint('Ignoring unreadable download state: $error');
            _job = null;
          }
          if (hasTransfer) {
            stage = OnlineStage.paused;
            if (_job!['state'] != 'paused' && _job!['state'] != 'failed') {
              unawaited(resume());
            }
          }
        }
      }
    }
    _changed();
  }

  Future<void> reconcileDownloads() async {
    try {
      await library.pruneMissingDownloads(
        exists: (path) async {
          if (path.startsWith('content:')) {
            return _channel.invokeMethod<bool>('exists', {'uri': path});
          }
          return File(path).exists();
        },
      );
    } catch (e) {
      debugPrint('Download refresh: $e');
    }
  }

  Future<void> _cleanFinishedJob() async {
    if (!Platform.isWindows || _job == null || hasTransfer) return;
    final path = _job!['directory'] as String?;
    if (path == null || _root == null) return;
    final directory = Directory(path);
    if (!await directory.exists()) return;
    final root = await _root!.resolveSymbolicLinks();
    final resolved = await directory.resolveSymbolicLinks();
    if (p.isWithin(root, resolved) && p.basename(resolved).startsWith('job-')) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> _persistJob() async {
    if (_job == null || !Platform.isWindows) return;
    final target = File(p.join(_root!.path, 'active-job.json'));
    final temp = File('${target.path}.tmp');
    final snapshot = jsonEncode(_job);
    // A failed write must not poison the chain for every later snapshot.
    final write = _jobWrites.then((_) async {
      await target.parent.create(recursive: true);
      await temp.writeAsString(snapshot, flush: true);
      await temp.rename(target.path);
    });
    _jobWrites = write.catchError((Object error) {
      debugPrint('Download state save failed: $error');
    });
    await _jobWrites;
  }

  Future<void> _refreshJob() async {
    if (_disposed || _polling) return;
    _polling = true;
    try {
      final value = await _channel.invokeMapMethod<String, dynamic>(
        'jobStatus',
      );
      if (value == null || value.isEmpty) return;
      final snapshot = jsonEncode(value);
      if (snapshot == _lastNativeSnapshot) return;
      _lastNativeSnapshot = snapshot;
      _job = Map<String, dynamic>.from(value);
      final state = _job!['state'];
      stage = switch (state) {
        'completed' => OnlineStage.completed,
        'cancelled' => OnlineStage.cancelled,
        'paused' => OnlineStage.paused,
        'waiting' => OnlineStage.waiting,
        'failed' || 'rejected' => OnlineStage.failed,
        'downloading' => OnlineStage.downloading,
        _ => OnlineStage.preparing,
      };
      // A resolve for Streaming owns `busy`; a job snapshot must not clear it.
      if (!_resolving) busy = hasTransfer && !canResume;
      progress = ((_job!['progress'] as num? ?? 0) / 100)
          .clamp(0, 1)
          .toDouble();
      error = stage == OnlineStage.failed ? _job!['error'] as String? : null;
      final path = _job!['path'];
      if (state == 'completed' && path is String && path.isNotEmpty) {
        if (await _channel.invokeMethod<bool>('exists', {'uri': path}) ==
            false) {
          library.remove(path);
          await library.flush();
          _changed();
          return;
        }
        lastDownload =
            library.findByPath(path) ??
            library.importPath(
              path,
              title: _job!['title'] as String? ?? titleFromPath(path),
              isDownload: true,
              isAudio: _job!['audioOnly'] == true,
              savedLocation: _job!['location'] as String?,
              sizeBytes: (_job!['sizeBytes'] as num?)?.toInt(),
            );
        await library.flush();
      }
      _changed();
    } finally {
      _polling = false;
    }
  }

  Future<void> pause() async {
    if (!canPause) return;
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('jobPause');
      await _refreshJob();
    } else {
      _pausing = true;
      _job!['state'] = 'paused';
      await _persistJob();
      await _killProcess();
    }
  }

  Future<void> resume() async {
    if (!hasTransfer) return;
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('jobResume');
      await _refreshJob();
    } else if (!busy) {
      _pausing = false;
      unawaited(_runWindowsJob().then<void>((_) {}, onError: (Object _) {}));
    }
  }

  Future<MediaItem> download(
    String input, {
    DownloadOptions options = const DownloadOptions(),
  }) async {
    options.validate();
    if (!isWebUrl(input)) throw const FormatException('Invalid URL');
    await loadHistory();
    if (busy || hasTransfer) {
      throw StateError('Finish or cancel the current download first.');
    }
    if (Platform.isAndroid) {
      progress = 0;
      error = null;
      busy = true;
      stage = OnlineStage.preparing;
      _changed();
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      try {
        await _channel.invokeMethod<void>('jobStart', {
          'id': id,
          'url': input.trim(),
          ...options.toMap(),
        });
      } catch (e) {
        busy = false;
        stage = OnlineStage.failed;
        error = _message(e);
        _changed();
        rethrow;
      }
      final started = DateTime.now();
      do {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await _refreshJob();
        if (_disposed) throw StateError('UI detached');
        // The service ignores a start it cannot accept; never wait forever.
        if (_job?['id'] != id &&
            DateTime.now().difference(started) > const Duration(seconds: 30)) {
          busy = false;
          stage = OnlineStage.failed;
          error = 'The download service did not start. Try again.';
          _changed();
          throw StateError(error!);
        }
      } while (_job?['id'] != id ||
          (stage != OnlineStage.completed &&
              stage != OnlineStage.failed &&
              stage != OnlineStage.cancelled));
      if (stage != OnlineStage.completed || lastDownload == null) {
        throw StateError(error ?? 'Cancelled');
      }
      return lastDownload!;
    }
    await _root!.create(recursive: true);
    final dir = await _root!.createTemp('job-');
    _job = {
      'url': input.trim(),
      ...options.toMap(),
      'directory': dir.path,
      'state': 'preparing',
    };
    _pausing = false;
    _cancelled = false;
    await _persistJob();
    return _runWindowsJob();
  }

  Future<MediaItem> _runWindowsJob() async {
    final job = _job!;
    final options = DownloadOptions(
      audioOnly: job['audioOnly'] == true,
      maxHeight: (job['maxHeight'] as num?)?.toInt() ?? 720,
      audioBitrate: (job['audioBitrate'] as num?)?.toInt() ?? 192,
    );
    for (var attempt = 0; ; attempt++) {
      try {
        job['state'] = 'downloading';
        await _persistJob();
        await _tray();
        final item = await _downloadWindowsOnce(
          job['url'] as String,
          options: options,
        );
        job['state'] = 'completed';
        await _persistJob();
        await _cleanFinishedJob();
        await _tray();
        return item;
      } catch (e) {
        if (_pausing || _cancelled || attempt >= 4 || _isPermanent(e)) {
          job['state'] = _pausing
              ? 'paused'
              : _cancelled
              ? 'cancelled'
              : _isPermanent(e)
              ? 'rejected'
              : 'failed';
          stage = _pausing
              ? OnlineStage.paused
              : _cancelled
              ? OnlineStage.cancelled
              : OnlineStage.failed;
          busy = false;
          if (_pausing) error = null;
          await _persistJob();
          await _cleanFinishedJob();
          await _tray();
          _changed();
          rethrow;
        }
        job['state'] = 'waiting';
        stage = OnlineStage.waiting;
        busy = true;
        await _persistJob();
        _changed();
        await _tray();
        for (var second = 0; second < 10 * (attempt + 1); second++) {
          if (_pausing || _cancelled) break;
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        busy = false;
        if (_pausing || _cancelled) {
          job['state'] = _pausing ? 'paused' : 'cancelled';
          stage = _pausing ? OnlineStage.paused : OnlineStage.cancelled;
          await _persistJob();
          await _cleanFinishedJob();
          await _tray();
          _changed();
          rethrow;
        }
      }
    }
  }

  /// Retrying cannot fix these; waiting 100 seconds only hides the reason.
  bool _isPermanent(Object e) {
    if (e is FormatException || e is ArgumentError || e is UnsupportedError) {
      return true;
    }
    final text = e.toString();
    return const [
      'Unsupported URL',
      'is not a valid URL',
      'Private video',
      'Video unavailable',
      'This video is unavailable',
      'Sign in to confirm',
      'requested format is not available',
      'No video at or below',
      'Requested resolution unavailable',
      'engine files are missing',
      'File is larger than max-filesize',
      'Invalid job directory',
      'outside the output directory',
    ].any(text.contains);
  }

  Future<void> _tray() async {
    if (!Platform.isWindows) return;
    await _desktopChannel.invokeMethod<void>('update', {
      'active': hasTransfer,
      'paused': canResume,
      'text': 'NOOR — ${stage.name} ${((progress ?? 0) * 100).round()}%',
    });
  }

  List<MediaItem> get downloads => _root == null
      ? []
      : library
            .query('', LibraryFilter.all)
            .where(
              (item) => item.isDownload || p.isWithin(_root!.path, item.path),
            )
            .toList();

  Future<T> _operation<T>(Future<T> Function() work) async {
    if (busy) throw StateError('Another operation is in progress.');
    busy = true;
    _cancelled = false;
    error = null;
    progress = null;
    stage = OnlineStage.preparing;
    _changed();
    try {
      final value = await work();
      if (_cancelled) throw StateError('Cancelled');
      stage = OnlineStage.completed;
      return value;
    } catch (e) {
      stage = _cancelled ? OnlineStage.cancelled : OnlineStage.failed;
      error = _cancelled ? null : _message(e);
      rethrow;
    } finally {
      busy = false;
      _process = null;
      _changed();
    }
  }

  String _message(Object e) {
    final text = e is PlatformException ? e.message ?? e.code : e.toString();
    return text.length > 1200 ? text.substring(text.length - 1200) : text;
  }

  Future<ResolvedMedia> resolve(String input) async {
    if (busy) throw StateError('Another operation is in progress.');
    _resolving = true;
    try {
      return await _resolve(input);
    } finally {
      _resolving = false;
    }
  }

  Future<ResolvedMedia> _resolve(String input) => _operation(() async {
    final source = input.trim();
    if (!isWebUrl(source)) {
      throw const FormatException('Enter a valid HTTP or HTTPS link.');
    }
    if (isDirectMediaUrl(source)) {
      return ResolvedMedia(
        sourceUrl: source,
        url: source,
        title: titleFromPath(Uri.decodeComponent(Uri.parse(source).path)),
      );
    }
    final Map<String, dynamic> data;
    if (Platform.isAndroid) {
      _listenNative();
      final raw = await _channel.invokeMapMethod<String, dynamic>('resolve', {
        'url': source,
      });
      data = Map<String, dynamic>.from(raw ?? {});
    } else if (Platform.isWindows) {
      final output = await _windows(source, [
        '--format',
        'best[height<=720]/best',
        '--dump-single-json',
        '--skip-download',
      ]);
      data = jsonDecode(output) as Map<String, dynamic>;
    } else {
      throw UnsupportedError(
        'Online sources are available on Android and Windows.',
      );
    }
    return ResolvedMedia.fromMap(source, data);
  });

  Future<MediaItem> _downloadWindowsOnce(
    String input, {
    DownloadOptions options = const DownloadOptions(),
  }) => _operation(() async {
    options.validate();
    final source = input.trim();
    if (!isWebUrl(source)) {
      throw const FormatException('Enter a valid HTTP or HTTPS link.');
    }
    await loadHistory();
    await _root!.create(recursive: true);
    final directory = _job == null
        ? await _root!.createTemp('video-')
        : Directory(_job!['directory'] as String);
    final canonicalRoot = await _root!.resolveSymbolicLinks();
    if (!p.isWithin(canonicalRoot, await directory.resolveSymbolicLinks())) {
      throw StateError('Invalid job directory');
    }
    String? title;
    String? filePath;
    if (!Platform.isWindows) {
      throw UnsupportedError('This transfer requires Windows.');
    }
    {
      await _windows(source, [
        ...options.arguments,
        '--continue',
        '--part',
        '--write-info-json',
        '--newline',
        '--progress-template',
        'download:__NOOR_PROGRESS__%(progress._percent_str)s',
        '--output',
        p.join(directory.path, 'media.%(ext)s'),
      ]);
      final info = File(p.join(directory.path, 'media.info.json'));
      if (await info.exists()) {
        final data =
            jsonDecode(await info.readAsString()) as Map<String, dynamic>;
        title = data['title'] as String?;
      }
      await for (final file in directory.list()) {
        if (file is File &&
            RegExp(
              r'^media\.(mp4|mkv|webm|mov|avi|flv|wmv|mpeg|mpg|m4v|3gp|ts|mp3|m4a|opus|ogg|wav|flac|aac)$',
              caseSensitive: false,
            ).hasMatch(p.basename(file.path))) {
          filePath = file.path;
          break;
        }
      }
    }
    if (_cancelled || _pausing) throw StateError('Stopped');
    if (filePath == null ||
        !await File(filePath).exists() ||
        await File(filePath).length() == 0) {
      throw StateError(
        'The source did not provide a downloadable video file. Try Streaming.',
      );
    }
    // Reject output outside this transfer's staging directory.
    final actualDirectory = await directory.resolveSymbolicLinks();
    final actualFile = await File(filePath).resolveSymbolicLinks();
    if (!p.isWithin(p.normalize(actualDirectory), p.normalize(actualFile))) {
      if (kDebugMode) {
        debugPrint(
          'NOOR download path mismatch: $actualDirectory / $actualFile',
        );
      }
      throw StateError('The downloaded file was outside the output directory.');
    }
    final infoFile = File(p.join(directory.path, 'media.info.json'));
    String? qualityTag = options.audioOnly
        ? 'MP3 ${options.audioBitrate}kbps'
        : null;
    if (!options.audioOnly && await infoFile.exists()) {
      final info =
          jsonDecode(await infoFile.readAsString()) as Map<String, dynamic>;
      if (!options.acceptsDimensions(
        info['width'] as num?,
        info['height'] as num?,
      )) {
        throw StateError(
          'No video at or below ${options.maxHeight}p was available. Choose a higher resolution.',
        );
      }
      final width = info['width'] as num?;
      final height = info['height'] as num?;
      if (width != null && height != null && width > 0 && height > 0) {
        qualityTag = '${(width < height ? width : height).round()}p';
      }
    }
    final item = await _savePublic(
      File(actualFile),
      title ?? titleFromPath(Uri.parse(source).path),
      options,
      qualityTag: qualityTag,
    );
    await library.flush();
    lastDownload = item;
    progress = 1;
    return item;
  });

  String _downloadName(String title, String extension) {
    final base = MediaImportStore.safeFileName(
      String.fromCharCodes(title.runes.take(100)),
    );
    return '$base$extension';
  }

  Future<MediaItem> _savePublic(
    File file,
    String title,
    DownloadOptions options, {
    String? qualityTag,
  }) async {
    final size = await file.length();
    final name = _downloadName(
      qualityTag == null ? title : '$title [$qualityTag]',
      p.extension(file.path),
    );
    String path;
    String location;
    if (Platform.isAndroid) {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'publish',
        {'path': file.path, 'name': name},
      );
      path = result?['uri'] as String? ?? '';
      final uri = Uri.tryParse(path);
      if (uri?.scheme != 'content' || uri?.authority != 'media') {
        throw StateError('The public download could not be saved.');
      }
      location = result?['location'] as String? ?? 'Download/NOOR/$name';
    } else {
      final downloads = await getDownloadsDirectory();
      if (downloads == null) {
        throw StateError('The Downloads folder is unavailable.');
      }
      final folder = await Directory(p.join(downloads.path, 'NOOR'))
          .create(recursive: true);
      var target = File(
        _job?['publicTarget'] as String? ?? p.join(folder.path, name),
      );
      if (!p.isWithin(folder.path, target.path)) {
        throw StateError('Invalid public target');
      }
      var counter = 1;
      while (_job?['publicTarget'] == null && await target.exists()) {
        target = File(
          p.join(
            folder.path,
            '${p.basenameWithoutExtension(name)} (${counter++})${p.extension(name)}',
          ),
        );
      }
      if (_job != null) {
        _job!['publicTarget'] = target.path;
        await _persistJob();
      }
      if (!await target.exists() || await target.length() != size) {
        final partial = File('${target.path}.noor-part');
        await file.copy(partial.path);
        await partial.rename(target.path);
      }
      path = target.path;
      location = path;
    }
    final item = library.importPath(
      path,
      title: title,
      isDownload: true,
      isAudio: options.audioOnly,
      savedLocation: location,
      sizeBytes: size,
    );
    await library.flush();
    // The public file is now the playable library entry; don't retain a second
    // full media copy in private storage. An unsuccessful export retains it.
    try {
      await file.delete();
    } on FileSystemException {
      /* Retry cleanup later. */
    }
    return item;
  }

  Future<MediaItem> saveExistingToDownloads(MediaItem old) =>
      _operation(() async {
        if (!Platform.isAndroid || old.isContentUri) return old;
        await loadHistory();
        final root = await _root!.resolveSymbolicLinks();
        final file = File(await File(old.path).resolveSymbolicLinks());
        if (!p.isWithin(root, file.path)) {
          throw StateError('Not a NOOR download.');
        }
        final item = await _savePublic(
          file,
          old.title,
          DownloadOptions(audioOnly: old.isAudio),
        );
        item.positionMs = old.positionMs;
        item.durationMs = old.durationMs;
        item.favorite = old.favorite;
        item.lastPlayedAt = old.lastPlayedAt;
        library.remove(old.path);
        await library.flush();
        lastDownload = item;
        return item;
      });

  void _listenNative() {
    _subscription ??= _events.receiveBroadcastStream().listen(
      (event) {
        if (!busy || event is! Map) return;
        final value = event['progress'];
        if (value is num) {
          progress = (value.toDouble() / 100).clamp(0, 1);
          stage = OnlineStage.downloading;
        }
        _changed();
      },
      onError: (Object e) {
        error = _message(e);
        _changed();
      },
    );
  }

  Future<String> _windows(String source, List<String> options) async {
    final engines = Directory(
      p.join(p.dirname(Platform.resolvedExecutable), 'engines'),
    );
    final executable = File(p.join(engines.path, 'yt-dlp.exe'));
    final node = File(p.join(engines.path, 'node.exe'));
    if (!await executable.exists() || !await node.exists()) {
      throw StateError(
        'Online engine files are missing. Use the complete NOOR Windows folder.',
      );
    }
    final args = [
      '--ignore-config',
      // Piped output otherwise uses the ANSI code page (e.g. cp1256 for
      // Arabic titles), which the UTF-8 decoder below cannot read.
      '--encoding',
      'utf-8',
      '--no-playlist',
      '--socket-timeout',
      '20',
      '--retries',
      '1',
      '--extractor-retries',
      '1',
      '--max-filesize',
      '2G',
      '--js-runtimes',
      'node:${node.path}',
      if (await File(p.join(engines.path, 'ffmpeg.exe')).exists()) ...[
        '--ffmpeg-location',
        engines.path,
      ],
      ...options,
      '--',
      source,
    ];
    final process = await Process.start(
      executable.path,
      args,
      runInShell: false,
    );
    _process = process;
    try {
      await _desktopChannel.invokeMethod<void>('trackProcess', process.pid);
    } catch (_) {
      process.kill();
      rethrow;
    }
    if (_cancelled || _pausing) process.kill();
    final output = StringBuffer();
    final errors = StringBuffer();
    const decoder = Utf8Decoder(allowMalformed: true);
    final stdoutDone = process.stdout
        .transform(decoder)
        .transform(const LineSplitter())
        .forEach((line) {
          if (line.contains('__NOOR_PROGRESS__')) {
            final match = RegExp(r'__NOOR_PROGRESS__\s*([\d.]+)%')
                .firstMatch(line);
            if (match != null) {
              progress = (double.parse(match.group(1)!) / 100).clamp(0, 1);
              stage = OnlineStage.downloading;
              _changed();
              unawaited(_tray());
            }
          } else {
            output.writeln(line);
          }
        });
    final stderrDone = process.stderr.transform(decoder).forEach(errors.write);
    final watchdog = _resolving
        ? Timer(const Duration(minutes: 10), () {
            unawaited(cancel());
          })
        : null;
    try {
      final code = await process.exitCode;
      await Future.wait([stdoutDone, stderrDone]);
      if (_cancelled) throw StateError('Cancelled');
      if (code != 0) {
        throw StateError(
          errors.isEmpty ? 'This source is unavailable.' : errors.toString(),
        );
      }
      return output.toString();
    } finally {
      watchdog?.cancel();
      if (identical(_process, process)) _process = null;
    }
  }

  Future<void> _killProcess() async {
    final process = _process;
    if (process != null) {
      await Process.run('taskkill', [
        '/PID',
        '${process.pid}',
        '/T',
        '/F',
      ], runInShell: false);
    }
  }

  Future<void> cancel() async {
    // Cancel only the resolve; a paused transfer must survive it.
    if (_resolving) {
      _cancelled = true;
      if (Platform.isAndroid) {
        await _channel.invokeMethod<void>('cancel');
      } else {
        await _killProcess();
      }
      return;
    }
    if (hasTransfer) {
      if (Platform.isAndroid) {
        await _channel.invokeMethod<void>('jobCancel');
        await _refreshJob();
      } else {
        _cancelled = true;
        _pausing = false;
        _job!['state'] = 'cancelled';
        await _persistJob();
        await _killProcess();
        if (!busy) {
          await _cleanFinishedJob();
          stage = OnlineStage.cancelled;
          await _tray();
          _changed();
        }
      }
      return;
    }
    if (!busy) return;
    _cancelled = true;
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('cancel');
    } else {
      await _killProcess();
    }
  }

  Future<void> openDownloadsFolder() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('openDownloads');
    } else if (Platform.isWindows) {
      final root = await getDownloadsDirectory();
      if (root == null) throw StateError('Downloads unavailable');
      final folder = Directory(p.join(root.path, 'NOOR'));
      await Process.start('explorer.exe', [
        await folder.exists() ? folder.path : root.path,
      ], runInShell: false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    if (!hasTransfer) unawaited(cancel());
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
