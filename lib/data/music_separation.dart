import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'library_controller.dart';
import 'media_import_store.dart';
import 'media_item.dart';
import 'online/windows_engine.dart' show engineEnvironment;

/// What to keep when separating a file's audio.
enum SeparationMode {
  /// Keep voices (speech, recitation, singing); drop the music.
  removeMusic,

  /// Keep the music; drop the voices.
  musicOnly,
}

enum SeparationStage { preparing, separating, saving }

/// The file has no audio stream to separate.
class NoAudioError implements Exception {
  const NoAudioError();
}

class SeparationJob {
  SeparationJob(this.item, this.mode);
  final MediaItem item;
  final SeparationMode mode;
  SeparationStage stage = SeparationStage.preparing;
  double progress = 0;
}

/// Splits a file's audio with Demucs (htdemucs, converted from Meta's
/// weights; see tool/demucs) and saves a new copy next to the downloads.
/// Windows only, one job at a time; the original file is never changed.
class MusicSeparationService extends ChangeNotifier {
  MusicSeparationService(this.library, {Directory? engines})
    : _engines =
          engines ??
          Directory(p.join(p.dirname(Platform.resolvedExecutable), 'engines'));

  final LibraryController library;
  final Directory _engines;
  static const _desktopChannel = MethodChannel('noor/download_tray');

  File get _demucs => File(p.join(_engines.path, 'demucs', 'demucs.exe'));
  File get _model =>
      File(p.join(_engines.path, 'demucs', 'htdemucs-4s-f16.bin'));
  File get _ffmpeg => File(p.join(_engines.path, 'ffmpeg.exe'));
  File get _ffprobe => File(p.join(_engines.path, 'ffprobe.exe'));

  bool _available = false;
  bool _disposed = false;

  /// True once the engine files were found (see [checkAvailable]).
  bool get available => _available;
  SeparationJob? current;
  Process? _process;
  bool _cancelled = false;

  Future<void> checkAvailable() async {
    final found =
        !kIsWeb &&
        Platform.isWindows &&
        await _demucs.exists() &&
        await _model.exists() &&
        await _ffmpeg.exists() &&
        await _ffprobe.exists();
    if (found != _available) {
      _available = found;
      _changed();
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Separates [item] and adds the result to the library as [title].
  Future<MediaItem> separate(
    MediaItem item,
    SeparationMode mode, {
    required String title,
  }) async {
    if (current != null) throw StateError('A separation is already running.');
    if (!_available) throw StateError('The separation engine is missing.');
    final job = current = SeparationJob(item, mode);
    _cancelled = false;
    _changed();
    final work = await Directory(
      p.join((await getApplicationSupportDirectory()).path, 'separation'),
    ).create(recursive: true).then((d) => d.createTemp('job-'));
    try {
      if (!await _hasAudio(item.path)) throw const NoAudioError();
      final hasVideo = await _hasVideo(item.path);
      final input = p.join(work.path, 'input.wav');
      await _run(_ffmpeg, [
        '-v', 'error', '-y', '-i', item.path, //
        '-vn', '-ac', '2', '-ar', '44100', '-c:a', 'pcm_s16le', input,
      ]);
      final seconds = (await File(input).length()) / (44100 * 2 * 2);
      job
        ..stage = SeparationStage.separating
        ..progress = 0.05;
      _changed();

      final stems = p.join(work.path, 'stems');
      final workers = separationWorkers(
        Duration(milliseconds: (seconds * 1000).round()),
        Platform.numberOfProcessors,
      );
      final progress = <int, double>{};
      await _run(
        _demucs,
        [_model.path, input, stems, '${workers.threads}'],
        environment: {'OMP_NUM_THREADS': '${workers.openMp}'},
        onLine: (line) {
          final parsed = parseDemucsProgress(line);
          if (parsed == null) return;
          progress[parsed.thread] = parsed.fraction;
          final average =
              progress.values.fold<double>(0, (a, b) => a + b) /
              workers.threads;
          // Separation is about 5%–90% of the whole job.
          final overall = 0.05 + 0.85 * average.clamp(0, 1);
          if (overall - job.progress >= 0.005) {
            job.progress = overall;
            _changed();
          }
        },
      );

      job
        ..stage = SeparationStage.saving
        ..progress = 0.9;
      _changed();
      final mixed = p.join(work.path, 'mixed.wav');
      String stem(String name) => p.join(stems, name);
      await _run(_ffmpeg, [
        '-v', 'error', '-y', //
        if (mode == SeparationMode.removeMusic) ...[
          '-i',
          stem('target_3_vocals.wav'),
          '-c:a',
          'pcm_s16le',
        ] else ...[
          '-i', stem('target_0_drums.wav'), //
          '-i', stem('target_1_bass.wav'),
          '-i', stem('target_2_other.wav'),
          '-filter_complex', 'amix=inputs=3:normalize=0',
          '-c:a', 'pcm_s16le',
        ],
        mixed,
      ]);

      final target = await _outputFile(item, mode, hasVideo: hasVideo);
      await _run(_ffmpeg, [
        '-v', 'error', '-y', //
        if (hasVideo) ...[
          // Keep the picture and subtitles as they are; only audio changes.
          '-i', item.path, '-i', mixed,
          '-map', '0:v:0', '-map', '1:a:0', '-map', '0:s?',
          '-c:v', 'copy', '-c:s', 'copy', '-c:a', 'aac', '-b:a', '192k',
          '-shortest',
        ] else ...[
          '-i',
          mixed,
          '-c:a',
          'libmp3lame',
          '-b:a',
          '256k',
        ],
        target.path,
      ]);
      final result = library.importPath(
        target.path,
        title: title,
        isAudio: !hasVideo,
        isDownload: true,
        savedLocation: target.path,
      );
      await library.flush();
      job.progress = 1;
      return result;
    } finally {
      current = null;
      _process = null;
      _changed();
      try {
        await work.delete(recursive: true);
      } on FileSystemException {
        /* Retried by nothing; it is in the app's own folder. */
      }
    }
  }

  Future<void> cancel() async {
    if (current == null) return;
    _cancelled = true;
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

  Future<bool> _hasAudio(String path) async {
    final output = await _run(_ffprobe, [
      '-v', 'error', '-select_streams', 'a', //
      '-show_entries', 'stream=index', '-of', 'csv=p=0', path,
    ]);
    return output.trim().isNotEmpty;
  }

  /// An MP3's cover picture is a "video" stream too; it does not count.
  Future<bool> _hasVideo(String path) async {
    final output = await _run(_ffprobe, [
      '-v', 'error', '-select_streams', 'v', //
      '-show_entries', 'stream_disposition=attached_pic',
      '-of', 'csv=p=0', path,
    ]);
    return LineSplitter.split(output)
        .any((line) => line.trim().isNotEmpty && line.trim() != '1');
  }

  Future<File> _outputFile(
    MediaItem item,
    SeparationMode mode, {
    required bool hasVideo,
  }) async {
    final downloads = await getDownloadsDirectory();
    if (downloads == null) throw StateError('Downloads folder unavailable');
    final folder = await Directory(p.join(downloads.path, 'NOOR'))
        .create(recursive: true);
    final base = separatedFileName(item.title, mode);
    final extension = hasVideo ? '.mkv' : '.mp3';
    var file = File(p.join(folder.path, '$base$extension'));
    for (var n = 1; await file.exists(); n++) {
      file = File(p.join(folder.path, '$base ($n)$extension'));
    }
    return file;
  }

  Future<String> _run(
    File executable,
    List<String> args, {
    Map<String, String>? environment,
    void Function(String line)? onLine,
  }) async {
    if (_cancelled) throw StateError('Cancelled');
    final process = await Process.start(
      executable.path,
      args,
      // Minimal PATH, like the download engine (see engineEnvironment).
      environment: engineEnvironment(
        _engines.path,
        extra: environment ?? const {},
      ),
      includeParentEnvironment: false,
      runInShell: false,
    );
    _process = process;
    try {
      // Ends the engine with Noor (Windows job object in the runner).
      await _desktopChannel.invokeMethod<void>('trackProcess', process.pid);
    } catch (_) {
      /* Not fatal: cancel() still stops it. */
    }
    final output = StringBuffer();
    final errors = StringBuffer();
    const decoder = Utf8Decoder(allowMalformed: true);
    final stdoutDone = process.stdout
        .transform(decoder)
        .transform(const LineSplitter())
        .forEach((line) {
          if (onLine != null) {
            onLine(line);
          } else {
            output.writeln(line);
          }
        });
    final stderrDone = process.stderr.transform(decoder).forEach(errors.write);
    final code = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);
    if (_cancelled) throw StateError('Cancelled');
    if (code != 0) {
      final text = errors.toString().trim();
      throw StateError(text.isEmpty ? 'Separation failed ($code).' : text);
    }
    return output.toString();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(cancel());
    super.dispose();
  }
}

/// `[THREAD 3] ( 45.000%) message` printed by demucs.cpp's threaded CLI.
({int thread, double fraction})? parseDemucsProgress(String line) {
  final match = RegExp(r'^\[THREAD (\d+)\] \(\s*([\d.]+)%\)').firstMatch(line);
  if (match == null) return null;
  return (
    thread: int.parse(match.group(1)!),
    fraction: (double.parse(match.group(2)!) / 100).clamp(0.0, 1.0),
  );
}

/// The file name of a separated copy, e.g. "Song [No music]".
String separatedFileName(String title, SeparationMode mode) {
  final suffix = mode == SeparationMode.removeMusic
      ? '[No music]'
      : '[Music only]';
  final base = MediaImportStore.safeFileName(
    String.fromCharCodes(title.runes.take(100)),
  );
  return '$base $suffix';
}

/// Worker threads and OpenMP threads per worker for demucs_mt, from the
/// audio length and the CPU's logical processors.
///
/// Measured on an i7-14700F (28 threads), 256 s of audio: 8 workers x 3
/// OpenMP threads 387 s; 8 x default OpenMP 318–444 s; 8 or 16 x 1 OpenMP
/// ~605 s; 4 x 6 953 s. A worker needs ~100 s per ~7.8 s model window
/// (10 s with one worker: 229 s), so wall time is about
/// ceil(windows / workers) x 100 s: use one worker per window, up to 8.
/// Each worker holds its own buffers (8 used ~4.2 GB), so smaller CPUs get
/// half their threads as workers.
({int threads, int openMp}) separationWorkers(Duration audio, int processors) {
  final cpu = processors < 1 ? 1 : processors;
  final windows = (audio.inMilliseconds / 7800).ceil();
  final byLength = windows.clamp(1, 8);
  final threads = byLength.clamp(1, (cpu ~/ 2).clamp(1, 8));
  final openMp = (cpu ~/ threads).clamp(1, 4);
  return (threads: threads, openMp: openMp);
}
