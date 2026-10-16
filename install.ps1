# PeriCode one-line installer for Windows.
#
#   irm https://github.com/eddyficial/pericode-releases/releases/latest/download/install.ps1 | iex
#
# Downloads the latest PeriCode installer, checks it against the published
# SHA-256 checksum, installs it for the current user (no admin rights), adds
# `pericode` to PATH and checks the result. Node and Python are bundled inside
# PeriCode, so nothing else needs to be installed first. Run it again at any
# time to update.
#
# Options (set before running): $env:PERICODE_VERSION = "0.2.0" installs that
# version instead of the latest.

& {
  $ErrorActionPreference = "Stop"
  $ProgressPreference = "SilentlyContinue"   # Invoke-WebRequest is far faster without the progress bar
  $repo = "eddyficial/pericode-releases"

  function Say([string]$Text) { Write-Host "==> $Text" -ForegroundColor Cyan }
  function Ok([string]$Text) { Write-Host "    $Text" -ForegroundColor Green }
  function Fail([string]$Text) { Write-Host "PeriCode was not installed: $Text" -ForegroundColor Red; throw $Text }

  Say "Checking this computer"
  if ($env:OS -ne "Windows_NT") { Fail "this installer is for Windows. On Linux or macOS use install.sh." }
  if (-not [Environment]::Is64BitOperatingSystem) { Fail "PeriCode needs 64-bit Windows." }
  $build = [Environment]::OSVersion.Version.Build
  if ($build -lt 17763) { Fail "PeriCode needs Windows 10 version 1809 or later (this is build $build)." }
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  Ok "64-bit Windows, build $build"
  Ok "Node.js and Python are included with PeriCode; nothing else to install"

  Say "Finding the latest PeriCode release"
  $api = if ($env:PERICODE_VERSION) { "https://api.github.com/repos/$repo/releases/tags/v$($env:PERICODE_VERSION)" } else { "https://api.github.com/repos/$repo/releases/latest" }
  try { $release = Invoke-RestMethod -UseBasicParsing -Headers @{ "User-Agent" = "pericode-installer" } $api }
  catch { Fail "could not reach GitHub ($($_.Exception.Message)). Check your internet connection and try again." }
  $exe = $release.assets | Where-Object { $_.name -like "PericodeSetup-*.exe" } | Select-Object -First 1
  $sums = $release.assets | Where-Object { $_.name -eq "SHA256SUMS.txt" } | Select-Object -First 1
  if (-not $exe -or -not $sums) { Fail "release $($release.tag_name) has no installer or checksum file." }
  Ok "$($release.tag_name): $($exe.name) ($([math]::Round($exe.size / 1MB)) MB)"

  $dir = Join-Path ([IO.Path]::GetTempPath()) "pericode-install-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
  New-Item -ItemType Directory -Force $dir | Out-Null

  Say "Downloading"
  $exePath = Join-Path $dir $exe.name
  Invoke-WebRequest -UseBasicParsing $exe.browser_download_url -OutFile $exePath
  $sumsText = (Invoke-WebRequest -UseBasicParsing $sums.browser_download_url).Content
  if ($sumsText -is [byte[]]) { $sumsText = [Text.Encoding]::ASCII.GetString($sumsText) }

  Say "Checking the download"
  $expected = ($sumsText -split "`n" | Where-Object { $_ -match [regex]::Escape($exe.name) } | Select-Object -First 1) -replace '\s.*$', ''
  $actual = (Get-FileHash $exePath -Algorithm SHA256).Hash.ToLower()
  if (-not $expected -or $actual -ne $expected.Trim().ToLower()) { Fail "the download does not match its published checksum. Nothing was installed." }
  Ok "SHA-256 matches"

  # The installer is per-user by default (PrivilegesRequired=lowest), so it
  # needs no admin rights and lands in %LOCALAPPDATA%\Programs\PeriCode.
  Say "Installing PeriCode for $env:USERNAME (no admin rights needed)"
  $setup = Start-Process -FilePath $exePath -Wait -PassThru -ArgumentList @(
    "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/TASKS=addtopath", "/LOG=`"$dir\setup.log`""
  )
  if ($setup.ExitCode -ne 0) { Fail "the installer exited with code $($setup.ExitCode). Its log is at $dir\setup.log" }

  # Where the installer put it (its uninstall entry records the folder).
  $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{B5E7A1F2-9D4C-4F8E-A6B1-3D2C1E7F8A9B}_is1"
  $appDir = (Get-ItemProperty $key -ErrorAction SilentlyContinue).InstallLocation
  if (-not $appDir) { $appDir = Join-Path $env:LOCALAPPDATA "Programs\PeriCode" }
  $appDir = $appDir.TrimEnd('\')
  $launcher = Join-Path $appDir "pericode.cmd"
  if (-not (Test-Path $launcher)) { Fail "the installer finished but $launcher is missing. Its log is at $dir\setup.log" }
  Ok "Installed to $appDir"
  Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue

  # The installer put PeriCode on the user PATH; make it usable in this window too.
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
  $cmd = Get-Command pericode -ErrorAction SilentlyContinue
  if ($cmd -and (Split-Path $cmd.Source).TrimEnd('\') -ne $appDir) {
    Write-Host "    Note: 'pericode' in a terminal runs another copy first: $($cmd.Source)" -ForegroundColor Yellow
    Write-Host "    Remove that one (for a source install: npm unlink -g pericode) to use this install." -ForegroundColor Yellow
  }

  Say "Checking PeriCode"
  & $launcher doctor
  Write-Host ""
  Write-Host "PeriCode is ready. Open a new terminal and run: pericode" -ForegroundColor Green
  Write-Host "The first run walks you through signing in to Claude, ChatGPT or GitHub Copilot."
}
