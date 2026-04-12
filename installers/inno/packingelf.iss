#define MyAppName "包貨小精靈"
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#ifndef RepoRoot
  #error RepoRoot must be provided to ISCC.
#endif

[Setup]
AppId={{7BC07E11-77D1-4D37-B4DB-B8C6606D0E76}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=Meridian
DefaultDirName={autopf}\Meridian\PackingElf
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#RepoRoot}\dist
OutputBaseFilename=PackingElf-Setup-{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
SetupIconFile={#RepoRoot}\desktop-app\ui\assets\images\app_icon.ico
UninstallDisplayIcon={app}\PackingElf Client\packingelf.exe
PrivilegesRequired=lowest
ChangesAssociations=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Types]
Name: "full"; Description: "安裝 Client 與 Host"
Name: "clientonly"; Description: "只安裝 Client"
Name: "hostonly"; Description: "只安裝 Host"
Name: "custom"; Description: "自訂安裝"; Flags: iscustom

[Components]
Name: "client"; Description: "包貨小精靈 Client"; Types: full clientonly custom; Flags: fixed
Name: "host"; Description: "包貨小精靈 Host"; Types: full hostonly custom

[Tasks]
Name: "desktopicon_client"; Description: "建立 Client 桌面捷徑"; Components: client; Flags: unchecked
Name: "desktopicon_host"; Description: "建立 Host 桌面捷徑"; Components: host; Flags: unchecked

[Dirs]
Name: "{app}\PackingElf Client"; Components: client
Name: "{app}\PackingElf Host"; Components: host

[Files]
Source: "{#RepoRoot}\dist\portable\PackingElf Client\*"; DestDir: "{app}\PackingElf Client"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: client
Source: "{#RepoRoot}\dist\portable\PackingElf Host\*"; DestDir: "{app}\PackingElf Host"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: host

[Icons]
Name: "{group}\包貨小精靈 Client"; Filename: "{app}\PackingElf Client\packingelf.exe"; Components: client
Name: "{autodesktop}\包貨小精靈 Client"; Filename: "{app}\PackingElf Client\packingelf.exe"; Tasks: desktopicon_client; Components: client
Name: "{group}\包貨小精靈 Host"; Filename: "{app}\PackingElf Host\PackingElf Host.exe"; Components: host
Name: "{autodesktop}\包貨小精靈 Host"; Filename: "{app}\PackingElf Host\PackingElf Host.exe"; Tasks: desktopicon_host; Components: host
Name: "{group}\解除安裝 包貨小精靈"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\PackingElf Client\packingelf.exe"; Description: "啟動包貨小精靈 Client"; Flags: nowait postinstall skipifsilent; Components: client; Check: not WizardIsComponentSelected('host') or WizardIsComponentSelected('client')
Filename: "{app}\PackingElf Host\PackingElf Host.exe"; Description: "啟動包貨小精靈 Host"; Flags: nowait postinstall skipifsilent; Components: host; Check: not WizardIsComponentSelected('client') or WizardIsComponentSelected('host')
