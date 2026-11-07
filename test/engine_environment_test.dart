import 'package:flutter_test/flutter_test.dart';
import 'package:noor/data/online/windows_engine.dart';

void main() {
  test('engines get a minimal PATH whatever its spelling', () {
    final env = engineEnvironment(
      r'C:\Noor\engines',
      source: {
        'Path': r'C:\Users\x\AppData\Local\Programs\Cua\cua-driver\bin;C:\a',
        'PATH': r'C:\b',
        'SystemRoot': r'C:\Windows',
        'TEMP': r'C:\t',
      },
      extra: {'OMP_NUM_THREADS': '3'},
    );
    final pathKeys = env.keys.where((k) => k.toLowerCase() == 'path');
    expect(pathKeys, ['PATH']);
    expect(env['PATH'], r'C:\Noor\engines;C:\Windows\System32;C:\Windows');
    expect(env['PATH'], isNot(contains('cua-driver')));
    expect(env['TEMP'], r'C:\t', reason: 'the rest is kept');
    expect(env['OMP_NUM_THREADS'], '3');
  });
}
