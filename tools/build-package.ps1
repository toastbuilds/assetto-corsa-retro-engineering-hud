param(
  [string]$Version = '2.3.0',
  [ValidateSet('free', 'premium')][string]$Edition = 'premium'
)

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $project 'dist'
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ('retro-ui-' + [guid]::NewGuid().ToString('N'))
# Resolve and constrain the staging target before the recursive cleanup below.
$stage = [System.IO.Path]::GetFullPath($stage)
$stageRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
if (-not $stage.StartsWith($stageRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    (Split-Path -Leaf $stage) -notmatch '^retro-ui-[0-9a-f]{32}$') {
  throw 'Package staging directory must be a generated child of the temporary directory.'
}
$app = Join-Path $stage 'apps\lua\RetroUI'
$package = Join-Path $dist "RetroUI-$($Edition.ToUpperInvariant())-v$Version.zip"

New-Item -ItemType Directory -Path $app, $dist -Force | Out-Null
try {
  foreach ($name in @('src', 'ui', 'modules', 'assets')) {
    Copy-Item -LiteralPath (Join-Path $project $name) -Destination $app -Recurse
  }
  foreach ($name in @('app.lua', 'RetroUI.lua', 'manifest.ini', 'LICENSE', 'THIRD_PARTY_NOTICES.md')) {
    Copy-Item -LiteralPath (Join-Path $project $name) -Destination $app
  }
  if ($Edition -eq 'free') {
    foreach ($name in @('src/edition.lua', 'src/gt7_retro_layout.lua', 'src/gt7_settings.lua', 'src/theme.lua', 'ui/gt7_retro.lua')) {
      $snapshot = Join-Path $project ('free-edition/' + $name)
      Copy-Item -LiteralPath $snapshot -Destination (Join-Path $app $name) -Force
    }
  }
  $editionLabel = if ($Edition -eq 'free') { 'Free' } else { 'Premium' }
  Set-Content -LiteralPath (Join-Path $app 'EDITION.txt') -Value @(
    "Retro UI $editionLabel edition v$Version"
    if ($Edition -eq 'free') { 'Includes the Classic GT7 layout.' }
    else { 'Includes the Premium GT7 component editor with Classic, Modern, Outer Pedals, and Steering Dial presets.' }
  ) -Encoding UTF8
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
