"""Run alongside background_test.dart; exercise actual Home and screen-off."""
import subprocess, time, sys
from pathlib import Path
adb = 'E:/Coding/SDK/platform-tools/adb.exe'
log = Path(sys.argv[1])
seen = set()
deadline = time.time() + 800
while time.time() < deadline:
    text = log.read_text(encoding='utf-8', errors='replace') if log.exists() else ''
    for kind in ['LOCAL', 'STREAM']:
        if 'NOOR_TEST_BACKGROUND_' + kind in text and kind not in seen:
            seen.add(kind)
            subprocess.run([adb, 'shell', 'input', 'keyevent', '3'], check=True)
            subprocess.run([adb, 'shell', 'input', 'keyevent', '223'], check=True)
            print('SCREEN_OFF ' + kind, flush=True)
            time.sleep(16)
            subprocess.run([adb, 'shell', 'input', 'keyevent', '224'], check=True)
            subprocess.run([adb, 'shell', 'wm', 'dismiss-keyguard'], check=True)
            subprocess.run([adb, 'shell', 'am', 'start', '-n', 'com.noor.player.noor/.MainActivity'], check=True)
            print('SCREEN_ON ' + kind, flush=True)
    if len(seen) == 2 or 'Some tests failed' in text: break
    time.sleep(1)
