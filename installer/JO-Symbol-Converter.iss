#define MyAppName "JO-符号转换"
#define MyAppVersion "0.0.5"
#define MyAppFullVersion "0.0.5+5"
#define MyAppPublisher "JO-Beacon"
#define MyAppExeName "jo_symbol_converter.exe"
#define MyArchiveClass "JOSymbolConverter.Archive"

[Setup]
AppId={{3A0EB77F-0F7A-4934-94F2-8F299643BFB8}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\JO-Symbol-Converter
DefaultGroupName={#MyAppName}
UsePreviousAppDir=no
UninstallDisplayIcon={app}\{#MyAppExeName}
SetupIconFile=..\windows\runner\resources\app_icon.ico
LicenseFile=..\LICENSE
OutputDir=..\build\installer
OutputBaseFilename=JO-Symbol-Converter-Setup-{#MyAppFullVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
ChangesAssociations=yes

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Tasks]
Name: "startmenu"; Description: "创建开始菜单项"; GroupDescription: "快捷方式："
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "快捷方式："; Flags: unchecked

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startmenu
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Classes\.josymbolconverter"; ValueType: string; ValueData: "{#MyArchiveClass}"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\.joquoteconverter"; ValueType: string; ValueData: "{#MyArchiveClass}"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\{#MyArchiveClass}"; ValueType: string; ValueData: "JO-符号转换存档"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\{#MyArchiveClass}\DefaultIcon"; ValueType: string; ValueData: "{app}\{#MyAppExeName},0"
Root: HKCU; Subkey: "Software\Classes\{#MyArchiveClass}\shell\open\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%1"""
Root: HKCU; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".josymbolconverter"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".joquoteconverter"; ValueData: ""

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "启动 {#MyAppName}"; Flags: nowait postinstall skipifsilent
