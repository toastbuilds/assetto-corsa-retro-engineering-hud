param([string]$Version, [switch]$Provisional)

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$versionLine = Select-String -LiteralPath (Join-Path $project 'manifest.ini') -Pattern '^VERSION = (\d+\.\d+\.\d+)$'
if (-not $versionLine) { throw 'manifest.ini has no semantic version.' }
$manifestVersion = $versionLine.Matches[0].Groups[1].Value
if (-not $Version) { $Version = $manifestVersion }
if ($Version -ne $manifestVersion) { throw "Package version $Version does not match manifest version $manifestVersion." }
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
$packageName = if ($Provisional) { "RetroUI-v$Version-provisional.zip" } else { "RetroUI-v$Version.zip" }
$package = Join-Path $dist $packageName

New-Item -ItemType Directory -Path $app, $dist -Force | Out-Null
try {
  # Git ignores do not control Copy-Item: distribute only runtime files.
  foreach ($name in @('src', 'ui', 'modules')) {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $project $name) -Recurse -File -Filter '*.lua') {
      $relative = $file.FullName.Substring($project.Length + 1)
      $destination = Join-Path $app $relative
      New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
      Copy-Item -LiteralPath $file.FullName -Destination $destination
    }
  }
  foreach ($relative in @('modules/relative/classes.ini', 'modules/leaderboard/classes.ini',
      'assets/notification-qqv87.wav', 'assets/notification-d4s3s.wav', 'docs/settings.md')) {
    $destination = Join-Path $app $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $project $relative) -Destination $destination
  }
  $shellFiles = Get-ChildItem -LiteralPath (Join-Path $project 'assets/dial_variants') -File -Filter '*.png'
  if ($shellFiles.Count -ne 16) { throw 'Expected 16 analog dial shell layers.' }
  foreach ($file in $shellFiles) {
    $destination = Join-Path $app ('assets/dial_variants/' + $file.Name)
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination
  }
  foreach ($name in @('app.lua', 'RetroUI.lua', 'manifest.ini', 'LICENSE', 'THIRD_PARTY_NOTICES.md', 'CHANGELOG.md')) {
    Copy-Item -LiteralPath (Join-Path $project $name) -Destination $app
  }
  Copy-Item -LiteralPath (Join-Path $project 'docs/user-guide.md') -Destination (Join-Path $app 'README.md')
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  if (Test-Path -LiteralPath $package) { Remove-Item -LiteralPath $package -Force }
  $archive = [System.IO.Compression.ZipFile]::Open($package, [System.IO.Compression.ZipArchiveMode]::Create)
  try {
    foreach ($file in Get-ChildItem -LiteralPath $stage -Recurse -File | Sort-Object FullName) {
      $entry = $file.FullName.Substring($stage.Length + 1).Replace('\', '/')
      [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $archive, $file.FullName, $entry, [System.IO.Compression.CompressionLevel]::Optimal
      ) | Out-Null
    }
  }
  finally {
    $archive.Dispose()
  }
  $hash = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLowerInvariant()
  Set-Content -LiteralPath "$package.sha256" -Value "$hash  $(Split-Path -Leaf $package)" -Encoding ASCII
  Write-Output $package
}
finally {
  if (Test-Path -LiteralPath $stage) {
    Remove-Item -LiteralPath $stage -Recurse -Force
  }
}
