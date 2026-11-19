#ifndef AppVersion
  #error AppVersion is required
#endif

[Setup]
AppId=AccountingJournalPy
AppName=Журнал заявок
AppVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\AccountingJournalPy
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=journal.ico
UninstallDisplayIcon={app}\AccountingJournal.exe
OutputDir=..\release
OutputBaseFilename=AccountingJournal-Setup-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Files]
Source: "..\dist\AccountingJournal\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Журнал заявок"; Filename: "{app}\AccountingJournal.exe"
Name: "{autodesktop}\Журнал заявок"; Filename: "{app}\AccountingJournal.exe"

[Run]
Filename: "{app}\AccountingJournal.exe"; Description: "Открыть журнал заявок"; Flags: nowait postinstall skipifsilent
