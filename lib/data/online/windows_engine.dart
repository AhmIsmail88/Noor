import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'links.dart';

/// Progress parsed from the engine's output; see [parseProgressLine].
typedef EngineProgress = ({double fraction, double? speed, Duration? eta});

/// The bundled yt-dlp.exe (with node.exe and ffmpeg.exe) next to Noor.exe.
/// Runs one process at a time; the caller owns transfer state and passes
/// in what the engine needs to know about it.
class WindowsEngine {
  WindowsEngine([Directory? directory])
    : directory =
          directory ??
          Directory(p.join(p.dirname(Platform.resolvedExecutable), 'engines'));

  final Directory directory;
  File get _executable => File(p.join(directory.path, 'yt-dlp.exe'));
  Process? _process;

  static const missing =
      'Online engine files are missing. Use the complete NOOR Windows folder.';

  /// Runs the engine for [source] and returns its stdout (progress lines
  /// excluded). Throws StateError with stderr on a non-zero exit, and
  /// 'Cancelled' when [cancelled] is true once it ends.
  Future<String> run(
    String source,
    List<String> options, {
    required Future<void> Function(int pid) track,
    required bool Function() stopRequested,
    required bool Function() cancelled,
    required void Function(EngineProgress progress) onProgress,
    Duration? timeout,
    void Function()? onTimeout,
  }) async {
    final executable = _executable;
    final node = File(p.join(directory.path, 'node.exe'));
    if (!await executable.exists() || !await node.exists()) {
      throw StateError(missing);
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
      if (await File(p.join(directory.path, 'ffmpeg.exe')).exists()) ...[
        '--ffmpeg-location',
        directory.path,
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
      await track(process.pid);
    } catch (_) {
      process.kill();
      rethrow;
    }
    if (stopRequested()) process.kill();
    final output = StringBuffer();
    final errors = StringBuffer();
    const decoder = Utf8Decoder(allowMalformed: true);
    final stdoutDone = process.stdout
        .transform(decoder)
        .transform(const LineSplitter())
        .forEach((line) {
          if (line.contains('__NOOR_PROGRESS__')) {
            final parsed = parseProgressLine(line);
            if (parsed != null) onProgress(parsed);
          } else {
            output.writeln(line);
          }
        });
    final stderrDone = process.stderr.transform(decoder).forEach(errors.write);
    final watchdog = timeout == null || onTimeout == null
        ? null
        : Timer(timeout, onTimeout);
    try {
      final code = await process.exitCode;
      await Future.wait([stdoutDone, stderrDone]);
      if (cancelled()) throw StateError('Cancelled');
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

  /// Stops the running engine and its children (ffmpeg, node).
  Future<void> kill() async {
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

  /// yt-dlp's version, or null when the engine is missing or fails.
  Future<String?> version() async {
    final exe = _executable;
    if (!await exe.exists()) return null;
    final result = await Process.run(exe.path, [
      '--ignore-config',
      '--version',
    ], runInShell: false);
    return result.exitCode == 0 ? '${result.stdout}'.trim() : null;
  }

  /// Self-update (yt-dlp -U) in place; throws StateError on failure.
  Future<void> update() async {
    final exe = _executable;
    if (!await exe.exists()) throw StateError(missing);
    final result = await Process.run(exe.path, [
      '--ignore-config',
      '--encoding',
      'utf-8',
      '-U',
    ], runInShell: false);
    if (result.exitCode != 0) {
      throw StateError('${result.stderr}${result.stdout}'.trim());
    }
  }
}
