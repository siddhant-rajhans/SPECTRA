# SPECTRA - build a release APK with the laptop's LAN IP baked in,
# then install it on the connected Pixel.
#
# Run from anywhere:
#   powershell -ExecutionPolicy Bypass -File E:\research\spectra\frontend\scripts\build_and_install.ps1
#
# Optional flags:
#   -BackendHost 192.168.1.42:3001   # skip auto-detect
#   -SkipBuild                       # just install the existing APK
#   -SkipInstall                     # just build, don't push to phone

[CmdletBinding()]
param(
  [string]$BackendHost = '',
  [switch]$SkipBuild,
  [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'

# --- Tooling --------------------------------------------------------------

$env:JAVA_HOME = 'C:\Program Files\Microsoft\jdk-17.0.18.8-hotspot'
$env:ANDROID_HOME = 'C:\Android\sdk'
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

$flutter = 'C:\flutter\bin\flutter.bat'
$adb = 'C:\Android\sdk\platform-tools\adb.exe'

foreach ($p in @($flutter, $adb)) {
  if (-not (Test-Path $p)) { throw "Missing tool: $p" }
}

# --- LAN IP auto-detect ---------------------------------------------------

if (-not $BackendHost) {
  $candidates = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
      $_.IPAddress -notlike '127.*' -and
      $_.IPAddress -notlike '169.254.*' -and
      $_.PrefixOrigin -ne 'WellKnown' -and
      ($_.InterfaceAlias -match 'Wi-?Fi|Ethernet')
    } |
    Sort-Object -Property @{Expression={$_.InterfaceAlias -match 'Wi-?Fi'}} -Descending

  if (-not $candidates) {
    throw "No Wi-Fi or Ethernet IPv4 address found. Pass -BackendHost <ip>:3001 explicitly."
  }
  $ip = $candidates[0].IPAddress
  $BackendHost = "${ip}:3001"
  Write-Host "Detected LAN IP: $ip on $($candidates[0].InterfaceAlias)"
}

Write-Host "Backend host that will be baked into the APK: $BackendHost"
Write-Host ""

# --- Project root ---------------------------------------------------------

$frontend = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $frontend
Write-Host "Working dir: $frontend"

# --- Build ---------------------------------------------------------------

if (-not $SkipBuild) {
  Write-Host ""
  Write-Host "=== flutter pub get ==="
  & $flutter pub get
  if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

  Write-Host ""
  Write-Host "=== flutter build apk --release ==="
  & $flutter build apk --release --dart-define "BACKEND_HOST=$BackendHost"
  if ($LASTEXITCODE -ne 0) { throw "Release build failed" }
}

$apk = Join-Path $frontend 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) { throw "APK not found at $apk - did the build succeed?" }
$apkSize = "{0:N1} MB" -f ((Get-Item $apk).Length / 1MB)
Write-Host ""
Write-Host "Built: $apk ($apkSize)"

# --- Install -------------------------------------------------------------

if ($SkipInstall) { return }

Write-Host ""
Write-Host "=== adb devices ==="
& $adb devices
$devices = (& $adb devices) -split "`n" |
  Where-Object { $_ -match '^\S+\s+device$' }

if (-not $devices) {
  Write-Host ""
  Write-Host "No device connected over ADB. To install:"
  Write-Host "  1. Plug the Pixel into this laptop with USB."
  Write-Host "  2. On the phone, accept the USB debugging RSA prompt."
  Write-Host "  3. Re-run this script (or just: adb install -r `"$apk`")."
  return
}

Write-Host ""
Write-Host "=== adb install -r ==="
& $adb install -r $apk
if ($LASTEXITCODE -ne 0) { throw "adb install failed" }

Write-Host ""
Write-Host "Done. On first launch grant the Microphone permission, then tap Listen on the Home tab."
Write-Host "If the app reports 'Connection error', open Profile -> Backend Server and verify $BackendHost."
