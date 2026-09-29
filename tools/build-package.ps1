param([string]$Version = '2.0.0')

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
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  if (Test-Path -LiteralPath $package) { Remove-Item -LiteralPath $package -Force }
  $archive = [System.IO.Compression.ZipFile]::Open($package, [System.IO.Compression.ZipArchiveMode]::Create)
  try {
    foreach ($file in Get-ChildItem -LiteralPath $stage -Recurse -File) {
      $entry = $file.FullName.Substring($stage.Length + 1).Replace('\', '/')
      [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $archive, $file.FullName, $entry, [System.IO.Compression.CompressionLevel]::Optimal
      ) | Out-Null
    }
  }
  finally {
    $archive.Dispose()
  }
  Write-Output $package
}
finally {
  if (Test-Path -LiteralPath $stage) {
    Remove-Item -LiteralPath $stage -Recurse -Force
  }
}
