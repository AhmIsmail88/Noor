param([string]$Serial = 'R5GL101Q6TW', [string]$TestPath = 'integration_test/online_flow_test.dart')
$ErrorActionPreference = 'Stop'
$noorRoot = Split-Path -Parent $PSScriptRoot
$noorAdb = 'E:/Coding/SDK/platform-tools/adb.exe'
$noorDart = 'E:/flutter/bin/cache/dart-sdk/bin/dart.exe'
$noorFlutter = 'E:/flutter/bin/cache/flutter_tools.snapshot'
Push-Location $noorRoot
try {
    # Back up private app data before a real-device test. Never use Flutter's
    # default post-test uninstall against the user's installed application.
    $noorBackup = Join-Path $noorRoot ('build/device-backups/noor-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.tar')
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $noorBackup) | Out-Null
    @'
import subprocess,sys
adb,serial,destination=sys.argv[1:]
package='com.noor.player.noor'
paths=[]
for name in ['files','app_flutter','shared_prefs']:
    check=subprocess.run([adb,'-s',serial,'shell','run-as',package,'ls','-d',name],capture_output=True)
    if check.returncode == 0: paths.append(name)
if not paths: raise SystemExit('No installed NOOR data found; install and prepare fixtures first.')
with open(destination,'wb') as output:
    subprocess.run([adb,'-s',serial,'exec-out','run-as',package,'tar','-cf','-',*paths],stdout=output,check=True)
print('Private app backup saved: '+destination)
'@ | python - $noorAdb $Serial $noorBackup
    if ($LASTEXITCODE -ne 0) { throw 'App backup failed; test was not started.' }
    $env:NOOR_GRADLE_OFFLINE = '1'
    & $noorDart $noorFlutter test $TestPath -d $Serial --no-pub --no-uninstall
    if ($LASTEXITCODE -ne 0) { throw 'Device integration test failed; app retained.' }
} finally {
    Pop-Location
}
