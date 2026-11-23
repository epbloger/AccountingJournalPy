$ErrorActionPreference = 'Stop'

$installer = Resolve-Path 'release\AccountingJournal-Setup-x64.exe'
$programDir = Join-Path $env:LOCALAPPDATA 'Programs\AccountingJournalPy'
$dataDir = Join-Path $env:LOCALAPPDATA 'AccountingJournalPy'
$dataFile = Join-Path $dataDir 'tickets.json'
$shortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Журнал заявок.lnk'
$startMenuShortcut = Join-Path ([Environment]::GetFolderPath('Programs')) 'Журнал заявок.lnk'
$exe = Join-Path $programDir 'AccountingJournal.exe'
$uninstaller = Join-Path $programDir 'unins000.exe'

function Invoke-Installer($Path, $Arguments) {
    $result = Start-Process -FilePath $Path -ArgumentList $Arguments -Wait -PassThru
    if ($result.ExitCode -ne 0) {
        throw "$Path failed with exit code $($result.ExitCode)"
    }
}

function Test-InstalledJournal($expectedHash = $null, $expectedCount = 5) {
    if (-not (Test-Path $shortcut)) { throw "Desktop shortcut was not created" }

    $launch = [System.Diagnostics.ProcessStartInfo]::new($shortcut)
    $launch.UseShellExecute = $true
    $journal = [System.Diagnostics.Process]::Start($launch)
    if (-not $journal) { throw "Desktop shortcut did not start the journal process" }
    try {
        $deadline = (Get-Date).AddSeconds(40)
        do {
            Start-Sleep -Milliseconds 250
            $journal.Refresh()
            if ($journal.HasExited) { throw "Journal exited with code $($journal.ExitCode)" }
            if ($journal.MainWindowTitle -eq 'Журнал заявок' -and (Test-Path $dataFile)) { break }
        } while ((Get-Date) -lt $deadline)

        if ($journal.MainWindowTitle -ne 'Журнал заявок') { throw "Journal window did not open" }
        if ($journal.MainModule.FileName -ne $exe) { throw "Desktop shortcut opened an unexpected executable" }
        $tickets = Get-Content -LiteralPath $dataFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($tickets.Count -ne $expectedCount) {
            throw "Expected $expectedCount tickets, found $($tickets.Count)"
        }
        if ($expectedHash -and (Get-FileHash -LiteralPath $dataFile).Hash -ne $expectedHash) {
            throw "Running the upgraded journal changed existing ticket data"
        }
        if (-not $journal.CloseMainWindow() -or -not $journal.WaitForExit(10000)) {
            throw "Journal did not close"
        }
    } finally {
        if (-not $journal.HasExited) { Stop-Process -Id $journal.Id }
    }
}

$silent = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
$previousInstaller = Join-Path $env:RUNNER_TEMP 'AccountingJournal-Previous.exe'
Invoke-WebRequest -Uri 'https://github.com/epbloger/AccountingJournalPy/releases/download/v1.0.2/AccountingJournal-Setup-x64.exe' -OutFile $previousInstaller
Invoke-Installer $previousInstaller $silent
Test-InstalledJournal

$previousTickets = Get-Content -LiteralPath $dataFile -Raw -Encoding UTF8 | ConvertFrom-Json
$previousTickets[0].description = 'Проверка сохранения заявки при обновлении'
$previousTickets | ConvertTo-Json -AsArray | Set-Content -LiteralPath $dataFile -Encoding UTF8
$previousHash = (Get-FileHash -LiteralPath $dataFile).Hash

Invoke-Installer $installer $silent
if ((Get-FileHash -LiteralPath $dataFile).Hash -ne $previousHash) {
    throw "Upgrading changed existing ticket data"
}
Test-InstalledJournal $previousHash

$settingsKey = 'HKCU:\Software\AccountingJournalPy'
$journalSettings = Join-Path $settingsKey 'Journal'
$null = New-Item -Path $journalSettings -Force
Set-ItemProperty -LiteralPath $journalSettings -Name darkTheme -Value 'true'
Test-InstalledJournal $previousHash

$cache = Join-Path $dataDir 'cache'
$null = New-Item -Path $cache -ItemType Directory
Set-Content -LiteralPath (Join-Path $cache 'test.tmp') -Value 'Uninstall cleanup check'
$backup = Join-Path $env:RUNNER_TEMP 'journal-backup.json'
Copy-Item -LiteralPath $dataFile -Destination $backup
if (-not (Test-Path -LiteralPath $startMenuShortcut)) { throw "Start menu shortcut was not created" }

function Test-UninstalledJournal {
    Invoke-Installer $uninstaller $silent
    $deadline = (Get-Date).AddSeconds(10)
    while ((Test-Path -LiteralPath $programDir) -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 250
    }
    $uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\AccountingJournalPy_is1'
    foreach ($path in @($programDir, $dataDir, $shortcut, $startMenuShortcut, $settingsKey, $uninstallKey)) {
        if (Test-Path -LiteralPath $path) { throw "Uninstaller left $path behind" }
    }
}

Test-UninstalledJournal
if ((Get-FileHash -LiteralPath $backup).Hash -ne $previousHash) {
    throw "Uninstall changed the backup saved outside the journal folders"
}

Invoke-Installer $installer $silent
Test-InstalledJournal -expectedCount 0
Test-UninstalledJournal
