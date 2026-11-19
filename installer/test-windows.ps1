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

Invoke-Installer $installer '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
if (-not (Test-Path $shortcut)) { throw "Desktop shortcut was not created" }

$target = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcut).TargetPath
if ($target -ne $exe) { throw "Desktop shortcut points to $target" }

$journal = Start-Process -FilePath $target -WorkingDirectory $programDir -PassThru
try {
    $deadline = (Get-Date).AddSeconds(40)
    do {
        Start-Sleep -Milliseconds 250
        $journal.Refresh()
        if ($journal.HasExited) { throw "Journal exited with code $($journal.ExitCode)" }
        if ($journal.MainWindowTitle -eq 'Журнал заявок' -and (Test-Path $dataFile)) { break }
    } while ((Get-Date) -lt $deadline)

    if ($journal.MainWindowTitle -ne 'Журнал заявок') { throw "Journal window did not open" }
    $tickets = Get-Content -LiteralPath $dataFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($tickets.Count -ne 5) { throw "Expected five tickets, found $($tickets.Count)" }
    if (-not $journal.CloseMainWindow() -or -not $journal.WaitForExit(10000)) {
        throw "Journal did not close"
    }
} finally {
    if (-not $journal.HasExited) { Stop-Process -Id $journal.Id }
}

Invoke-Installer $uninstaller '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
if (Test-Path $exe) { throw "Uninstaller left the executable installed" }
if (Test-Path $shortcut) { throw "Uninstaller left the desktop shortcut" }
if (-not (Test-Path $dataFile)) { throw "Uninstaller removed the journal data" }
