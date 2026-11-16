<# : batch part of the RunLog installer, which runs the PowerShell below
@echo off
set "RL_SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content -LiteralPath $env:RL_SELF) -join [Environment]::NewLine)"
if errorlevel 1 pause
exit /b
#>
# Puts the RunLog launcher in your user folder, and RunLog and RunLog Coach icons on your desktop
# and Start menu.
# No admin rights needed. Nothing else on your computer is changed.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Base = if ($env:RUNLOG_BASE) { $env:RUNLOG_BASE } else { 'https://raw.githubusercontent.com/runlog-app/runlog/main' }
$Dir = Join-Path $env:LOCALAPPDATA 'RunLog'
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
Write-Host 'Installing RunLog...'
Invoke-WebRequest -UseBasicParsing -Uri "$Base/RunLog.ps1" -OutFile (Join-Path $Dir 'RunLog.ps1')
Invoke-WebRequest -UseBasicParsing -Uri "$Base/RunLog.ico" -OutFile (Join-Path $Dir 'RunLog.ico')

$shell = New-Object -ComObject WScript.Shell
$places = @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))
Invoke-WebRequest -UseBasicParsing -Uri "$Base/Coach.ico" -OutFile (Join-Path $Dir 'Coach.ico')
$apps = @(@{ Lnk = 'RunLog.lnk'; App = 'RunLog'; Ico = 'RunLog.ico'; Desc = 'RunLog: your running, from your own data' },
          @{ Lnk = 'RunLog Coach.lnk'; App = 'Coach'; Ico = 'Coach.ico'; Desc = 'RunLog Coach: your training plan, from your RunLog data' })
foreach ($place in $places) {
  foreach ($a in $apps) {
    $lnk = $shell.CreateShortcut((Join-Path $place $a.Lnk))
    $lnk.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $lnk.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + (Join-Path $Dir 'RunLog.ps1') + '" -App ' + $a.App
    $lnk.IconLocation = Join-Path $Dir $a.Ico
    $lnk.WindowStyle = 7
    $lnk.Description = $a.Desc
    $lnk.Save()
  }
}

# Old copies: RunLog or RunLog Coach files saved by hand (a test file, a download) on the desktop or in
# Downloads or Documents. Your data is in your browser, not in these files, so the installed apps see
# it too. Moved (never deleted) into the RunLog folder, after asking, so only the icons are left.
$old = @()
$looks = foreach ($folder in @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:USERPROFILE 'Downloads'),
                                [Environment]::GetFolderPath('MyDocuments'), (Join-Path $env:USERPROFILE 'Desktop')) | Select-Object -Unique) {
  if ($folder -and (Test-Path $folder)) { Get-ChildItem -LiteralPath $folder -File -Filter '*.htm*' -ErrorAction SilentlyContinue }
}
foreach ($f in $looks) {
  # Skip big files and files that live only in OneDrive (reading would download them).
  if ($f.Length -gt 30MB -or ($f.Attributes -band 0x00400000) -or ($f.Attributes -band [IO.FileAttributes]::Offline)) { continue }
  try {
    $fs = [IO.File]::OpenRead($f.FullName); $buf = New-Object byte[] 4096; $n = $fs.Read($buf, 0, 4096); $fs.Close()
    $head = [Text.Encoding]::UTF8.GetString($buf, 0, $n)
    if ($head -match '<title>RunLog( Coach)?</title>') { $old += $f }
  } catch { }
}
if ($old.Count -gt 0) {
  Write-Host ''
  Write-Host 'Found older RunLog files you saved yourself:'
  $old | ForEach-Object { Write-Host ('  ' + $_.FullName) }
  Write-Host 'Your data is kept: it lives in your browser, and the RunLog icons open the same data.'
  $answer = Read-Host 'Move these into the RunLog folder so only the up-to-date apps are left? (Y/n)'
  if ($answer -notmatch '^[nN]') {
    $keep = Join-Path $Dir ('Old copies\' + (Get-Date -Format 'yyyy-MM-dd'))
    New-Item -ItemType Directory -Force -Path $keep | Out-Null
    foreach ($f in $old) {
      $to = Join-Path $keep $f.Name; $i = 2
      while (Test-Path $to) { $to = Join-Path $keep ($f.BaseName + " ($i)" + $f.Extension); $i++ }
      try { Move-Item -LiteralPath $f.FullName -Destination $to } catch { Write-Host ('  Could not move ' + $f.Name + ' (is it open?)') }
    }
    Write-Host "Moved to $keep"
  }
}
Write-Host 'Done. RunLog and RunLog Coach are on your desktop. Opening RunLog now...'
& (Join-Path $Dir 'RunLog.ps1')
