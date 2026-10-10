param(
  [string]$AssettoCorsaRoot,
  [ValidateSet('leaderboard', 'relative', 'condition', 'laps', 'timer', 'instruments')][string]$App,
  [string[]]$SharedFiles = @(),
  [switch]$Finalize,
  [switch]$Validated
)

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot

function Resolve-GameRoot {
  param([string]$Requested)
  $candidates = @()
  if ($Requested) { $candidates += $Requested }
  $candidates += @(
    'C:\Program Files (x86)\Steam\steamapps\common\assettocorsa',
    'D:\SteamLibrary\steamapps\common\assettocorsa',
    'D:\Steam\steamapps\common\assettocorsa'
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath (Join-Path $candidate 'apps\lua')) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }
  throw 'Assetto Corsa was not found. Pass -AssettoCorsaRoot with the game directory.'
}

function Assert-ChildPath {
  param([string]$Parent, [string]$Child)
  $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
  $childFull = [System.IO.Path]::GetFullPath($Child)
  if (-not $childFull.StartsWith($parentFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Path escapes the intended directory: $childFull"
  }
}

$game = Resolve-GameRoot $AssettoCorsaRoot
$luaApps = Join-Path $game 'apps\lua'
$backupRoot = Join-Path $game '_RetroUI-Backups'
$stateFile = Join-Path $backupRoot 'migration.json'
$target = Join-Path $luaApps 'RetroUI'
Assert-ChildPath $game $backupRoot
Assert-ChildPath $game $target

# Partial deployment backs up the installed app before copying selected files.
if ($App) {
  if (-not (Test-Path -LiteralPath (Join-Path $target 'manifest.ini'))) { throw 'Install RetroUI before deploying one app.' }
  $backup = Join-Path $backupRoot ((Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + $App)
  New-Item -ItemType Directory -Path $backup -Force | Out-Null
  Copy-Item -LiteralPath $target -Destination (Join-Path $backup 'previous-RetroUI') -Recurse
  $files = @()
  if ($App -eq 'condition') {
    $files += @('ui/car_condition.lua', 'src/condition_settings.lua', 'src/tyre_grip.lua')
  } elseif ($App -eq 'instruments') {
    $files += @('app.lua', 'src/hybrid.lua', 'ui/hybrid_gauge.lua', 'src/telemetry.lua', 'src/instrument_state.lua',
      'ui/dial.lua', 'ui/side_instruments.lua', 'ui/gt7_retro.lua', 'src/settings.lua')
    $files += @('src/dial_variants.lua', 'ui/analog_variants.lua', 'src/digital_dial_variants.lua', 'ui/digital_variants.lua', 'src/dial_readout.lua', 'src/gt7_dial_styles.lua', 'src/gt7_settings.lua')
    $files += Get-ChildItem -LiteralPath (Join-Path $project 'assets/dial_variants') -File -Filter '*.png' |
      ForEach-Object { $_.FullName.Substring($project.Length + 1) }
  } else {
    $module = Join-Path $project ('modules/' + $App)
    $files += Get-ChildItem -LiteralPath $module -Recurse -File | Where-Object { $_.Extension -eq '.lua' } | ForEach-Object { $_.FullName.Substring($project.Length + 1) }
  }
  $files += $SharedFiles
  foreach ($file in $files | Select-Object -Unique) {
    $source = Join-Path $project $file
    $destination = Join-Path $target $file
    Assert-ChildPath $project $source
    Assert-ChildPath $target $destination
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    try {
      Copy-Item -LiteralPath $source -Destination $destination -Force
    } catch {
      if ($_.Exception.Message -notmatch 'user-mapped section') { throw }
      # CSP can memory-map loaded PNGs. Keep its old file alive in the backup
      # and put the replacement at the original path for the next app reload.
      $mappedBackup = Join-Path $backup ('mapped-files/' + $file)
      Assert-ChildPath $backup $mappedBackup
      Assert-ChildPath $target $destination
      New-Item -ItemType Directory -Path (Split-Path -Parent $mappedBackup) -Force | Out-Null
      Move-Item -LiteralPath $destination -Destination $mappedBackup
      try {
        Copy-Item -LiteralPath $source -Destination $destination
      } catch {
        Move-Item -LiteralPath $mappedBackup -Destination $destination
        throw
      }
    }
    if ((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $destination).Hash) { throw "Installed file mismatch: $file" }
  }
  if ($App -eq 'instruments') {
    foreach ($retired in @('stack', 'twin')) {
      foreach ($theme in @('dark', 'light')) {
        foreach ($layer in @('back', 'front')) {
          $obsolete = Join-Path $target ("assets/dial_variants/{0}_{1}_{2}.png" -f $retired, $theme, $layer)
          Assert-ChildPath $target $obsolete
          if (Test-Path -LiteralPath $obsolete) { Remove-Item -LiteralPath $obsolete }
        }
      }
    }
  }
  (Get-Item -LiteralPath (Join-Path $target 'RetroUI.lua')).LastWriteTime = Get-Date
  Write-Output "Installed and SHA256 verified: $App ($($files.Count) files)"
  Write-Output "Backup: $backup"
  return
}

$legacyNames = @('RetroEngineeringHUD', 'MulticlassRelative', 'CMRTRetroDeltaBar',
  'RetroEngineeringLeaderboard', 'RetroEngineeringTelemetry')

if ($Finalize) {
  if (-not $Validated) { throw 'First validate Retro UI in Assetto Corsa, then rerun with -Finalize -Validated.' }
  if (-not (Test-Path -LiteralPath $stateFile)) { throw 'Migration state was not found. Install Retro UI first.' }
  if (-not (Test-Path -LiteralPath (Join-Path $target 'manifest.ini'))) { throw 'Retro UI installation was not found.' }
  $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
  foreach ($name in $legacyNames) {
    $old = Join-Path $luaApps $name
    $retired = Join-Path $state.backupPath ('retired-' + $name)
    Assert-ChildPath $game $old
    Assert-ChildPath $backupRoot $retired
    if ((Test-Path -LiteralPath $old) -and -not (Test-Path -LiteralPath $retired)) {
      Move-Item -LiteralPath $old -Destination $retired
      Write-Output "Retired $name to $retired"
    }
  }
  Write-Output 'Legacy apps retired. Their backups and CSP preferences remain available.'
  return
}

$build = Join-Path $PSScriptRoot 'build-package.ps1'
$zip = & $build
$backup = Join-Path $backupRoot (Get-Date -Format 'yyyyMMdd-HHmmss')
$legacyBackup = Join-Path $backup 'legacy-apps'
New-Item -ItemType Directory -Path $legacyBackup -Force | Out-Null

foreach ($name in $legacyNames) {
  $old = Join-Path $luaApps $name
  if (Test-Path -LiteralPath $old) {
    Copy-Item -LiteralPath $old -Destination $legacyBackup -Recurse
  }
}

$documentsDelta = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Assetto Corsa\CMRTRetroDeltaBar'
if (Test-Path -LiteralPath $documentsDelta) {
  Copy-Item -LiteralPath $documentsDelta -Destination $backup -Recurse
}

$stage = Join-Path $backup 'stage'
Expand-Archive -LiteralPath $zip -DestinationPath $stage
$stagedApp = Join-Path $stage 'apps\lua\RetroUI'
if (-not (Test-Path -LiteralPath (Join-Path $stagedApp 'manifest.ini'))) {
  throw 'Built package is missing the Retro UI manifest.'
}

foreach ($pair in @(
  @{ app = 'MulticlassRelative'; module = 'relative' },
  @{ app = 'RetroEngineeringLeaderboard'; module = 'leaderboard' }
)) {
  $currentMap = Join-Path $target ('modules\' + $pair.module + '\classes.ini')
  $oldMap = Join-Path (Join-Path $luaApps $pair.app) 'classes.ini'
  $sourceMap = if (Test-Path -LiteralPath $currentMap) { $currentMap }
    elseif (Test-Path -LiteralPath $oldMap) { $oldMap }
    else { $null }
  if ($sourceMap) {
    Copy-Item -LiteralPath $sourceMap -Destination (Join-Path $stagedApp ('modules\' + $pair.module + '\classes.ini')) -Force
  }
}

if (Test-Path -LiteralPath $target) {
  $previous = Join-Path $backup 'previous-RetroUI'
  Assert-ChildPath $backupRoot $previous
  Move-Item -LiteralPath $target -Destination $previous
}
Assert-ChildPath $backupRoot $stagedApp
Move-Item -LiteralPath $stagedApp -Destination $target
# CSP can notice the brief gap while the old folder is moved away. Touch the
# entry script after installation so a running game retries loading the app.
(Get-Item -LiteralPath (Join-Path $target 'RetroUI.lua')).LastWriteTime = Get-Date
@{ backupPath = $backup; installedAt = (Get-Date).ToString('o'); gameRoot = $game } |
  ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding UTF8

Write-Output "Installed Retro UI at $target"
Write-Output "Backup: $backup"
Write-Output 'Validate all panels in Assetto Corsa. Then run this script with -Finalize -Validated to retire old apps.'
