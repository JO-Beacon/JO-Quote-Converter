#define MyAppName "JO-引号转换"
#define MyAppVersion "0.0.3"
#define MyAppPublisher "JO-Beacon"
#define MyAppExeName "jo_quote_converter.exe"
#define MyArchiveClass "JOQuoteConverter.Archive"

[Setup]
AppId={{3A0EB77F-0F7A-4934-94F2-8F299643BFB8}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\JO-Quote-Converter
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
SetupIconFile=..\windows\runner\resources\app_icon.ico
LicenseFile=..\LICENSE
OutputDir=..\build\installer
OutputBaseFilename=JO-Quote-Converter-Setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
ChangesAssociations=yes

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

[Registry]
Root: HKCU; Subkey: "Software\Classes\.joquoteconverter"; ValueType: string; ValueData: "{#MyArchiveClass}"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\{#MyArchiveClass}"; ValueType: string; ValueData: "JO-引号转换存档"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\{#MyArchiveClass}\DefaultIcon"; ValueType: string; ValueData: "{app}\{#MyAppExeName},0"
Root: HKCU; Subkey: "Software\Classes\{#MyArchiveClass}\shell\open\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%1"""
Root: HKCU; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".joquoteconverter"; ValueData: ""

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "启动 {#MyAppName}"; Flags: nowait postinstall skipifsilent
