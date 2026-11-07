import 'package:flutter_test/flutter_test.dart';
import 'package:noor/data/music_separation.dart';

void main() {
  test('demucs progress lines give the thread and its fraction', () {
    // Printed by demucs_mt.cpp (commit 4edae497) on Windows.
    final p = parseDemucsProgress(
      '[THREAD 6] ( 45.000%) 3., apply_model mix shape: (2, 343980)',
    )!;
    expect(p.thread, 6);
    expect(p.fraction, closeTo(0.45, 1e-9));
    expect(parseDemucsProgress('[THREAD 0] (0.000%) buffers.z: 2, 2049, 336'), (
      thread: 0,
      fraction: 0.0,
    ));
    expect(
      parseDemucsProgress('Loaded model (533 tensors,  80.08 MB)'),
      isNull,
    );
    expect(parseDemucsProgress('Encoder Status: 0'), isNull);
  });

  test('separated copies are named after the title and the mode', () {
    expect(
      separatedFileName('Song: live?', SeparationMode.removeMusic),
      'Song_ live_ [No music]',
    );
    expect(
      separatedFileName('تلاوة', SeparationMode.musicOnly),
      'تلاوة [Music only]',
    );
  });

  test('worker counts follow the measured timings', () {
    // i7-14700F (28 threads), 4:16 song: 8 workers x 3 OpenMP was fastest.
    expect(separationWorkers(const Duration(seconds: 256), 28), (
      threads: 8,
      openMp: 3,
    ));
    // 10 s is two ~7.8 s windows: one worker each, not one for both.
    expect(separationWorkers(const Duration(seconds: 10), 28).threads, 2);
    // A smaller CPU gets half its threads as workers (memory per worker).
    expect(separationWorkers(const Duration(minutes: 4), 8), (
      threads: 4,
      openMp: 2,
    ));
    expect(separationWorkers(const Duration(minutes: 4), 1), (
      threads: 1,
      openMp: 1,
    ));
  });
}
