param([ValidateSet('Debug','Release')][string]$Configuration = 'Debug')
$ErrorActionPreference = 'Stop'
$noorWorkspace = Split-Path -Parent $PSScriptRoot
$noorEngine = Join-Path $noorWorkspace "build/windows/x64/runner/$Configuration/engines"
New-Item -ItemType Directory -Force -Path $noorEngine | Out-Null
$noorYtVersion = '2026.10.26'
$noorNodeVersion = 'v24.19.0'
$noorChecksums = (Invoke-WebRequest "https://github.com/yt-dlp/yt-dlp/releases/download/$noorYtVersion/SHA2-256SUMS" -TimeoutSec 60).Content
if ($noorChecksums -is [byte[]]) { $noorChecksums = [Text.Encoding]::UTF8.GetString($noorChecksums) }
$noorExpected = (($noorChecksums -split "`n" | Where-Object { $_ -match '\s\*?yt-dlp\.exe\s*$' }) -split '\s+')[0]
if (-not $noorExpected) { throw 'yt-dlp checksum not found' }
$noorYtExe = Join-Path $noorEngine 'yt-dlp.exe'
if (!(Test-Path $noorYtExe) -or (Get-FileHash $noorYtExe).Hash -ne $noorExpected) {
    Invoke-WebRequest "https://github.com/yt-dlp/yt-dlp/releases/download/$noorYtVersion/yt-dlp.exe" -OutFile $noorYtExe -TimeoutSec 120
}
if ((Get-FileHash $noorYtExe).Hash -ne $noorExpected) { throw 'yt-dlp checksum mismatch' }
$noorNodeSums = (Invoke-WebRequest "https://nodejs.org/dist/$noorNodeVersion/SHASUMS256.txt" -TimeoutSec 60).Content
if ($noorNodeSums -is [byte[]]) { $noorNodeSums = [Text.Encoding]::UTF8.GetString($noorNodeSums) }
$noorNodeHash = (($noorNodeSums -split "`n" | Where-Object { $_ -match '\swin-x64/node\.exe\s*$' }) -split '\s+')[0]
if (-not $noorNodeHash) { throw 'Node checksum not found' }
$noorNodeExe = Join-Path $noorEngine 'node.exe'
if (!(Test-Path $noorNodeExe) -or (Get-FileHash $noorNodeExe).Hash -ne $noorNodeHash) {
    $noorInstalledNode = Get-Command node.exe -ErrorAction SilentlyContinue
    if ($noorInstalledNode -and (Get-FileHash $noorInstalledNode.Source).Hash -eq $noorNodeHash) {
        Copy-Item -LiteralPath $noorInstalledNode.Source -Destination $noorNodeExe
    } else {
        Invoke-WebRequest "https://nodejs.org/dist/$noorNodeVersion/win-x64/node.exe" -OutFile $noorNodeExe -TimeoutSec 120
    }
}
if ((Get-FileHash $noorNodeExe).Hash -ne $noorNodeHash) { throw 'Node checksum mismatch' }
$noorFfmpeg = Get-Command ffmpeg.exe -ErrorAction Stop
Copy-Item -LiteralPath $noorFfmpeg.Source -Destination (Join-Path $noorEngine 'ffmpeg.exe') -Force
$noorFfprobe = Get-Command ffprobe.exe -ErrorAction SilentlyContinue
if ($noorFfprobe) { Copy-Item -LiteralPath $noorFfprobe.Source -Destination (Join-Path $noorEngine 'ffprobe.exe') -Force }
& $noorFfmpeg.Source -version | Set-Content (Join-Path $noorEngine 'FFMPEG-BUILD.txt') -Encoding utf8
Invoke-WebRequest 'https://raw.githubusercontent.com/nodejs/node/v24.19.0/LICENSE' -OutFile (Join-Path $noorEngine 'NODE-LICENSE.txt') -TimeoutSec 60
Invoke-WebRequest 'https://raw.githubusercontent.com/yt-dlp/yt-dlp/2026.10.26/LICENSE' -OutFile (Join-Path $noorEngine 'YT-DLP-LICENSE.txt') -TimeoutSec 60
@"
NOOR online engine: local test package
yt-dlp $noorYtVersion executable: https://github.com/yt-dlp/yt-dlp/releases/tag/$noorYtVersion
Node ${noorNodeVersion}: https://nodejs.org/dist/$noorNodeVersion/
FFmpeg executable: copied from $($noorFfmpeg.Source); see FFMPEG-BUILD.txt.
Native/executable bundles contain additional third-party components and notices.
See docs/ONLINE_MEDIA_IMPLEMENTATION.md for corresponding-source/distribution notes.
"@ | Set-Content (Join-Path $noorEngine 'COMPONENTS.txt') -Encoding utf8
Write-Output "Online engine prepared at $noorEngine"
