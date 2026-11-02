; Noor installer (Inno Setup 6). Build the Windows release with its engines
; first (see README), then:
;   ISCC.exe windows\installer\noor.iss   ->  dist\Noor-Setup.exe

#define AppVersion "1.0.0"
#define Bundle "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{8C1F5B2E-6D4A-4E8B-9A3F-2B7C0D9E4F11}
AppName=Noor
AppVersion={#AppVersion}
AppVerName=Noor {#AppVersion}
AppPublisher=Noor
VersionInfoVersion={#AppVersion}
; Per-user install without admin rights. Required, not only convenient: the
; in-app engine update (yt-dlp -U) rewrites files in {app}\engines.
PrivilegesRequired=lowest
DefaultDirName={autopf}\Noor
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Same name as the single-instance mutex in windows/runner/main.cpp.
AppMutex=NOOR.Player.Application
CloseApplications=yes
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\Noor.exe
UninstallDisplayName=Noor
OutputDir=..\..\dist
OutputBaseFilename=Noor-Setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"

[CustomMessages]
english.OpenWithTask=Add Noor to "Open with" for video and audio files
arabic.OpenWithTask=إضافة نور إلى «فتح باستخدام» لملفات الفيديو والصوت

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "openwith"; Description: "{cm:OpenWithTask}"

[Files]
Source: "{#Bundle}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.old"

[Icons]
Name: "{autoprograms}\Noor"; Filename: "{app}\Noor.exe"
Name: "{autodesktop}\Noor"; Filename: "{app}\Noor.exe"; Tasks: desktopicon

; Per-user "Open with" entries, the same as tool/register_windows_open_with.ps1.
; They never replace the user's default player.
#define AppKey "Software\Classes\Applications\Noor.exe"
#define ProgId "Software\Classes\NOOR.Media"
#dim Exts[20] {"mp4", "mkv", "avi", "mov", "webm", "mpeg", "mpg", "m4v", "3gp", "ts", "flv", "wmv", "mp3", "m4a", "aac", "opus", "ogg", "wav", "flac", "wma"}

[Registry]
Root: HKCU; Subkey: "{#AppKey}"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "Noor"; Flags: uninsdeletekey; Tasks: openwith
Root: HKCU; Subkey: "{#AppKey}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\Noor.exe"" ""%1"""; Tasks: openwith
Root: HKCU; Subkey: "{#ProgId}"; ValueType: string; ValueName: ""; ValueData: "Noor media"; Flags: uninsdeletekey; Tasks: openwith
Root: HKCU; Subkey: "{#ProgId}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: """{app}\Noor.exe"",0"; Tasks: openwith
Root: HKCU; Subkey: "{#ProgId}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\Noor.exe"" ""%1"""; Tasks: openwith
#sub ExtEntries
  #define Ext Exts[I]
Root: HKCU; Subkey: "{#AppKey}\SupportedTypes"; ValueType: string; ValueName: ".{#Ext}"; ValueData: ""; Tasks: openwith
Root: HKCU; Subkey: "Software\Classes\.{#Ext}\OpenWithProgids"; ValueType: string; ValueName: "NOOR.Media"; ValueData: ""; Flags: uninsdeletevalue; Tasks: openwith
#endsub
#define I
#for {I = 0; I < 20; I++} ExtEntries

[Run]
Filename: "{app}\Noor.exe"; Description: "{cm:LaunchProgram,Noor}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Left by the in-app engine update. The library and settings in
; %APPDATA%\com.noor.player are kept.
Type: files; Name: "{app}\engines\*.old"
