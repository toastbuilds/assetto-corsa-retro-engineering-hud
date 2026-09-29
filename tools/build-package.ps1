param([string]$Version = '1.0.0')

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $project 'dist'
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ('retro-ui-' + [guid]::NewGuid().ToString('N'))
$app = Join-Path $stage 'apps\lua\RetroUI'
$package = Join-Path $dist "RetroUI-v$Version.zip"

New-Item -ItemType Directory -Path $app, $dist -Force | Out-Null
try {
  foreach ($name in @('src', 'ui', 'modules', 'assets')) {
    Copy-Item -LiteralPath (Join-Path $project $name) -Destination $app -Recurse
  }
  foreach ($name in @('app.lua', 'RetroUI.lua', 'manifest.ini', 'LICENSE', 'THIRD_PARTY_NOTICES.md')) {
    Copy-Item -LiteralPath (Join-Path $project $name) -Destination $app
  }
  Compress-Archive -Path (Join-Path $stage 'apps') -DestinationPath $package -CompressionLevel Optimal -Force
  Write-Output $package
}
finally {
  if (Test-Path -LiteralPath $stage) {
    Remove-Item -LiteralPath $stage -Recurse -Force
  }
}
