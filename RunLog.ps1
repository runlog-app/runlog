# RunLog launcher for Windows: RunLog, or RunLog Coach with -App Coach.
# Checks for a new version, downloads it if there is one, and opens it in its own window.
# Both apps sit in the same folder and open in the same browser, so the Coach reads RunLog's data.
# Your data is never touched: it lives in your browser, not in this folder.
# Works offline: without internet it opens the copy you already have.

param([ValidateSet('RunLog', 'Coach')][string]$App = 'RunLog')
$ErrorActionPreference = 'Stop'
$Base = if ($env:RUNLOG_BASE) { $env:RUNLOG_BASE } else { 'https://raw.githubusercontent.com/runlog-app/runlog/main' }
$Dir = Join-Path $env:LOCALAPPDATA 'RunLog'
$Name = if ($App -eq 'Coach') { 'Coach' } else { 'RunLog' }
$Html = Join-Path $Dir "$Name.html"
$VerName = if ($App -eq 'Coach') { 'coach-version.txt' } else { 'version.txt' }
$VerFile = Join-Path $Dir $VerName
New-Item -ItemType Directory -Force -Path $Dir | Out-Null

try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  # version.txt (coach-version.txt) holds "<version> <sha256 of the .html>".
  $remote = ([string](Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 -Uri "$Base/$VerName").Content).Trim()
  $local = if (Test-Path $VerFile) { (Get-Content -Raw $VerFile).Trim() } else { '' }
  if ($remote -match '^\S+\s+[0-9a-f]{64}$' -and ($remote -ne $local -or -not (Test-Path $Html))) {
    $sha = ($remote -split '\s+')[1]
    $tmp = "$Html.download"
    Invoke-WebRequest -UseBasicParsing -TimeoutSec 120 -Uri "$Base/$Name.html" -OutFile $tmp
    if ((Get-FileHash -Algorithm SHA256 $tmp).Hash.ToLower() -eq $sha) {
      if (Test-Path $Html) { Copy-Item $Html (Join-Path $Dir "$Name.previous.html") -Force }
      Move-Item $tmp $Html -Force
      Set-Content -Path $VerFile -Value $remote -Encoding ASCII
    } else {
      Remove-Item $tmp -Force   # incomplete or changed download: keep the copy we have
    }
  }
} catch {
  # No internet or GitHub unreachable: open the copy we have.
}

if (-not (Test-Path $Html)) {
  Add-Type -AssemblyName System.Windows.Forms
  [System.Windows.Forms.MessageBox]::Show("$(if ($App -eq 'Coach') { 'RunLog Coach' } else { 'RunLog' }) could not be downloaded. Check your internet connection and try again.", 'RunLog') | Out-Null
  exit 1
}

# Open in the browser that opens HTML files on this computer (the one a double-clicked RunLog.html
# used), so RunLog finds the data already saved there. Chrome and Edge each keep their own copy.
$chrome = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
            "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
          "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
$choice = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.html\UserChoice',
            'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice') |
  ForEach-Object { (Get-ItemProperty -ErrorAction SilentlyContinue $_).ProgId } | Where-Object { $_ } | Select-Object -First 1
$browser = if ($choice -like 'ChromeHTML*' -and $chrome) { $chrome } elseif ($edge) { $edge } else { $chrome }

$url = ([Uri]$Html).AbsoluteUri
if ($browser) { Start-Process -FilePath $browser -ArgumentList "--app=`"$url`"" } else { Start-Process $Html }
