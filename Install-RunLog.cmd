<# : batch part of the RunLog installer, which runs the PowerShell below
@echo off
set "RL_SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content -LiteralPath $env:RL_SELF) -join [Environment]::NewLine)"
if errorlevel 1 pause
exit /b
#>
# Puts the RunLog launcher in your user folder and a RunLog icon on your desktop and Start menu.
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
foreach ($place in $places) {
  $lnk = $shell.CreateShortcut((Join-Path $place 'RunLog.lnk'))
  $lnk.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $lnk.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + (Join-Path $Dir 'RunLog.ps1') + '"'
  $lnk.IconLocation = Join-Path $Dir 'RunLog.ico'
  $lnk.WindowStyle = 7
  $lnk.Description = 'RunLog: your running, from your own data'
  $lnk.Save()
}
Write-Host 'Done. RunLog is on your desktop. Opening it now...'
& (Join-Path $Dir 'RunLog.ps1')
