import 'package:flutter_test/flutter_test.dart';
import 'package:noor/data/online_media_service.dart';

void main() {
  test('real engine progress lines give percent, speed and time left', () {
    // Printed by yt-dlp 2026.10.26 on Windows with NOOR's template.
    final p = parseProgressLine('__NOOR_PROGRESS__ 34.8%|2863796.406248677|7')!;
    expect(p.fraction, closeTo(0.348, 1e-9));
    expect(p.speed, closeTo(2863796.4, 0.1));
    expect(p.eta, const Duration(seconds: 7));
  });

  test('unknown speed or time left is NA', () {
    final p = parseProgressLine('__NOOR_PROGRESS__  0.0%|NA|NA')!;
    expect(p.fraction, 0);
    expect(p.speed, isNull);
    expect(p.eta, isNull);
  });

  test('the old percent-only form still parses; other lines do not', () {
    expect(parseProgressLine('__NOOR_PROGRESS__100.0%')!.fraction, 1);
    expect(parseProgressLine('[download] Destination: media.mkv'), isNull);
  });
}
