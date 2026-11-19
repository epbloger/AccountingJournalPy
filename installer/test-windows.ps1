$ErrorActionPreference = 'Stop'

$installer = Resolve-Path 'release\AccountingJournal-Setup-x64.exe'
$programDir = Join-Path $env:LOCALAPPDATA 'Programs\AccountingJournalPy'
$dataFile = Join-Path $env:LOCALAPPDATA 'AccountingJournalPy\tickets.json'
$shortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Журнал заявок.lnk'
$exe = Join-Path $programDir 'AccountingJournal.exe'
$uninstaller = Join-Path $programDir 'unins000.exe'

function Invoke-Installer($Path, $Arguments) {
    $result = Start-Process -FilePath $Path -ArgumentList $Arguments -Wait -PassThru
    if ($result.ExitCode -ne 0) {
        throw "$Path failed with exit code $($result.ExitCode)"
    }
}

function Test-InstalledJournal($expectedHash = $null) {
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
        if ($tickets.Count -ne 5) { throw "Expected five tickets, found $($tickets.Count)" }
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

Invoke-Installer $uninstaller $silent
if (Test-Path $exe) { throw "Uninstaller left the executable installed" }
if (Test-Path $shortcut) { throw "Uninstaller left the desktop shortcut" }
if (-not (Test-Path $dataFile)) { throw "Uninstaller removed the journal data" }
