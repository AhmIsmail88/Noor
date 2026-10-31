param([string]$Executable = (Join-Path $PSScriptRoot '../build/windows/x64/runner/Release/Noor.exe'))
$ErrorActionPreference = 'Stop'
$noorExe = (Resolve-Path -LiteralPath $Executable).Path
if ([IO.Path]::GetFileName($noorExe) -ne 'Noor.exe') { throw 'Select the built Noor executable.' }
# Per-user Open With registration. Does not replace any default player/UserChoice.
$noorClasses = 'HKCU:\Software\Classes'
$noorApplication = Join-Path $noorClasses 'Applications\Noor.exe'
New-Item -Path "$noorApplication\shell\open\command" -Force | Out-Null
Set-Item -Path "$noorApplication\shell\open\command" -Value ('"' + $noorExe + '" "%1"')
New-ItemProperty -Path $noorApplication -Name FriendlyAppName -Value 'NOOR' -PropertyType String -Force | Out-Null
New-Item -Path "$noorApplication\SupportedTypes" -Force | Out-Null
$noorType = Join-Path $noorClasses 'NOOR.Media'
New-Item -Path "$noorType\shell\open\command" -Force | Out-Null
Set-Item -Path $noorType -Value 'NOOR media'
Set-Item -Path "$noorType\shell\open\command" -Value ('"' + $noorExe + '" "%1"')
New-Item -Path "$noorType\DefaultIcon" -Force | Out-Null
Set-Item -Path "$noorType\DefaultIcon" -Value ('"' + $noorExe + '",0')
foreach ($noorExtension in @('mp4','mkv','avi','mov','webm','mpeg','mpg','m4v','3gp','ts','flv','wmv','mp3','m4a','aac','opus','ogg','wav','flac','wma')) {
    New-ItemProperty -Path "$noorApplication\SupportedTypes" -Name ".$noorExtension" -Value '' -PropertyType String -Force | Out-Null
    $noorOpenWith = "$noorClasses\.$noorExtension\OpenWithProgids"
    New-Item -Path $noorOpenWith -Force | Out-Null
    New-ItemProperty -Path $noorOpenWith -Name 'NOOR.Media' -Value '' -PropertyType String -Force | Out-Null
}
Write-Output "NOOR added to Open With for this user: $noorExe"
