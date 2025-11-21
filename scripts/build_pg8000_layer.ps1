#requires -version 5.1
$ErrorActionPreference = 'Stop'

# Paths
$root = (Get-Location).Path
$layerDir = Join-Path $root 'lambda_layer_rds'
$pythonDir = Join-Path $layerDir 'python'
$workDir = Join-Path $layerDir 'work'

# Ensure directories
New-Item -ItemType Directory -Force -Path $layerDir | Out-Null
New-Item -ItemType Directory -Force -Path $pythonDir | Out-Null
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

function Get-WheelUrl {
  param([string]$PackageName)
  Write-Host "Fetching $PackageName metadata from PyPI..."
  $meta = Invoke-RestMethod -UseBasicParsing -Uri ("https://pypi.org/pypi/{0}/json" -f $PackageName)
  $version = $meta.info.version
  $releaseFiles = $meta.releases.$version
  if (-not $releaseFiles) {
    throw "No releases found for $PackageName $version"
  }
  # Prefer py3-none-any wheel
  $wheel = $releaseFiles | Where-Object { $_.packagetype -eq 'bdist_wheel' -and $_.filename -match 'py3-none-any' } | Select-Object -First 1
  if (-not $wheel) {
    # Any wheel fallback
    $wheel = $releaseFiles | Where-Object { $_.packagetype -eq 'bdist_wheel' } | Select-Object -First 1
  }
  if (-not $wheel) {
    throw "No wheel found for $PackageName $version (need a wheel to avoid building)"
  }
  return $wheel.url
}

# Download wheels
$pgWheelUrl = Get-WheelUrl -PackageName 'pg8000'
Write-Host ("Downloading pg8000 wheel: {0}" -f $pgWheelUrl)
$pgWheelPath = Join-Path $workDir 'pg8000.whl'
Invoke-WebRequest -UseBasicParsing -Uri $pgWheelUrl -OutFile $pgWheelPath

$scrampWheelUrl = Get-WheelUrl -PackageName 'scramp'
Write-Host ("Downloading scramp wheel: {0}" -f $scrampWheelUrl)
$scrampWheelPath = Join-Path $workDir 'scramp.whl'
Invoke-WebRequest -UseBasicParsing -Uri $scrampWheelUrl -OutFile $scrampWheelPath

# Extract wheels
$pgExtract = Join-Path $workDir 'pg8000_extracted'
$scrampExtract = Join-Path $workDir 'scramp_extracted'
if (Test-Path $pgExtract) { Remove-Item -Recurse -Force $pgExtract }
if (Test-Path $scrampExtract) { Remove-Item -Recurse -Force $scrampExtract }
# Expand .whl (wheel is a zip) by copying to .zip first
$pgZip = Join-Path $workDir 'pg8000.zip'
if (Test-Path $pgZip) { Remove-Item -Force $pgZip }
Copy-Item -Force $pgWheelPath $pgZip
Expand-Archive -Force -LiteralPath $pgZip -DestinationPath $pgExtract
# Expand scramp wheel
$scrampZip = Join-Path $workDir 'scramp.zip'
if (Test-Path $scrampZip) { Remove-Item -Force $scrampZip }
Copy-Item -Force $scrampWheelPath $scrampZip
Expand-Archive -Force -LiteralPath $scrampZip -DestinationPath $scrampExtract

# Assemble python/ structure
# pg8000
if (Test-Path (Join-Path $pgExtract 'pg8000')) {
  Copy-Item -Recurse -Force (Join-Path $pgExtract 'pg8000') (Join-Path $pythonDir 'pg8000')
}
$pgDist = Get-ChildItem -Path $pgExtract -Directory | Where-Object { $_.Name -like 'pg8000-*.dist-info' } | Select-Object -First 1
if ($pgDist) {
  Copy-Item -Recurse -Force $pgDist.FullName $pythonDir
}

# scramp dependency
if (Test-Path (Join-Path $scrampExtract 'scramp')) {
  Copy-Item -Recurse -Force (Join-Path $scrampExtract 'scramp') (Join-Path $pythonDir 'scramp')
}
$scrampDist = Get-ChildItem -Path $scrampExtract -Directory | Where-Object { $_.Name -like 'scramp-*.dist-info' } | Select-Object -First 1
if ($scrampDist) {
  Copy-Item -Recurse -Force $scrampDist.FullName $pythonDir
}

# Create ZIP
$zipPath = Join-Path $layerDir 'pg8000_layer.zip'
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
Write-Host ("Creating ZIP: {0}" -f $zipPath)
Compress-Archive -Force -Path $pythonDir -DestinationPath $zipPath
Write-Host ("Done. Layer ZIP at {0}" -f $zipPath)
