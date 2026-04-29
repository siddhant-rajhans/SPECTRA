# Downloads the YAMNet TFLite model + AudioSet class map into
# frontend/assets/models so the SPECTRA app can run on-device sound classification.
#
# Re-running is idempotent — files only download if missing.
#
# Usage (from frontend/):
#   pwsh ./scripts/setup_yamnet.ps1
#   $env:YAMNET_TFLITE_URL = '...' ; pwsh ./scripts/setup_yamnet.ps1   # override

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$assetsDir = Join-Path $scriptDir '..\assets\models'
New-Item -ItemType Directory -Force -Path $assetsDir | Out-Null

$modelUrl = if ($env:YAMNET_TFLITE_URL) { $env:YAMNET_TFLITE_URL } else { 'https://www.kaggle.com/api/v1/models/google/yamnet/tfLite/classification-tflite/1/download' }
$labelsUrl = if ($env:YAMNET_LABELS_URL) { $env:YAMNET_LABELS_URL } else { 'https://raw.githubusercontent.com/tensorflow/models/master/research/audioset/yamnet/yamnet_class_map.csv' }

$modelFile = Join-Path $assetsDir 'yamnet.tflite'
$labelsFile = Join-Path $assetsDir 'yamnet_class_map.csv'

function Test-Tflite($path) {
  if (-not (Test-Path $path)) { return $false }
  $fs = [System.IO.File]::OpenRead($path)
  try {
    $buf = New-Object byte[] 8
    [void]$fs.Read($buf, 0, 8)
    return ($buf[4] -eq 0x54 -and $buf[5] -eq 0x46 -and $buf[6] -eq 0x4C -and $buf[7] -eq 0x33)
  } finally { $fs.Dispose() }
}

function Get-IfMissing($url, $out) {
  if ((Test-Path $out) -and ((Get-Item $out).Length -gt 1024)) {
    Write-Host "  [skip] $(Split-Path -Leaf $out) already present"
    return
  }
  Write-Host "  [get]  $url"
  Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
}

Write-Host 'Fetching YAMNet assets...'
Get-IfMissing $labelsUrl $labelsFile

if (Test-Tflite $modelFile) {
  Write-Host '  [skip] yamnet.tflite already valid'
} else {
  $download = "$modelFile.download"
  Get-IfMissing $modelUrl $download
  $tmpDir = Join-Path $env:TEMP ('yamnet_' + [Guid]::NewGuid())
  New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

  $bytes = New-Object byte[] 4
  $fs = [System.IO.File]::OpenRead($download)
  try { [void]$fs.Read($bytes, 0, 4) } finally { $fs.Dispose() }

  if ($bytes[0] -eq 0x1F -and $bytes[1] -eq 0x8B) {
    Write-Host '  [extract] gzip'
    $gz = [System.IO.File]::OpenRead($download)
    $payload = Join-Path $tmpDir 'payload'
    $out = [System.IO.File]::Create($payload)
    $gzip = New-Object System.IO.Compression.GzipStream($gz, [System.IO.Compression.CompressionMode]::Decompress)
    try { $gzip.CopyTo($out) } finally { $gzip.Dispose(); $out.Dispose(); $gz.Dispose() }
    # Inner payload is typically tar.
    if (Get-Command tar -ErrorAction SilentlyContinue) {
      tar -xf $payload -C $tmpDir
    }
  } elseif ($bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B) {
    Write-Host '  [extract] zip'
    Expand-Archive -Path $download -DestinationPath $tmpDir -Force
  } else {
    Copy-Item $download (Join-Path $tmpDir 'yamnet.tflite')
  }

  $tflite = Get-ChildItem -Path $tmpDir -Filter '*.tflite' -Recurse | Select-Object -First 1
  if (-not $tflite) { throw 'Could not locate .tflite inside the downloaded archive' }
  Move-Item -Force $tflite.FullName $modelFile
  Remove-Item -Recurse -Force $tmpDir
  Remove-Item -Force $download

  if (-not (Test-Tflite $modelFile)) {
    throw 'Downloaded file is not a valid TFLite model (TFL3 magic missing)'
  }
}

Write-Host ''
Write-Host "Done. Files in $assetsDir :"
Get-ChildItem $assetsDir | Format-Table Name, Length
