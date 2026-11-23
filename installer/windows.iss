#ifndef AppVersion
  #error AppVersion is required
#endif

[Setup]
AppId=AccountingJournalPy
AppName=Журнал заявок
AppVersion={#AppVersion}
DefaultDirName={autopf}\AccountingJournalPy
DisableDirPage=no
DisableProgramGroupPage=yes
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
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

[Messages]
russian.ConfirmUninstall=Удалить «Журнал заявок» вместе с заявками и настройками?%n%nПеред удалением можно сохранить резервную копию в отдельной папке.

[Files]
Source: "..\dist\AccountingJournal\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Журнал заявок"; Filename: "{app}\AccountingJournal.exe"
Name: "{autodesktop}\Журнал заявок"; Filename: "{app}\AccountingJournal.exe"

[Registry]
Root: HKCU; Subkey: "Software\AccountingJournalPy"; Flags: dontcreatekey uninsdeletekeyifempty
Root: HKCU; Subkey: "Software\AccountingJournalPy\Journal"; Flags: dontcreatekey uninsdeletekey

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\AccountingJournalPy"
Type: dirifempty; Name: "{app}"

[Run]
Filename: "{app}\AccountingJournal.exe"; Description: "Открыть журнал заявок"; Flags: nowait postinstall skipifsilent
