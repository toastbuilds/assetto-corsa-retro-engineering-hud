param(
  [Parameter(Mandatory = $true)][string]$AssettoCorsaRoot,
  [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$game = (Resolve-Path -LiteralPath $AssettoCorsaRoot).Path
$target = Join-Path $game 'apps\lua\RetroUI'
$cutoff = (Get-Date).Date
$files = @('app.lua', 'src\window_anchor.lua', 'ui\anchor_feedback.lua',
  'modules\leaderboard\src\settings.lua', 'modules\delta\src\display.lua')
$backupRoots = @((Join-Path $game '_RetroUI-Backups'),
  (Join-Path $game 'apps\lua\_install-backup'), (Join-Path $project '_install-backup'))

function Assert-ChildPath([string]$Parent, [string]$Child) {
  $root = [IO.Path]::GetFullPath($Parent).TrimEnd('\', '/') + '\'
  $resolved = [IO.Path]::GetFullPath($Child)
  if (-not $resolved.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Path escapes intended directory: $resolved"
  }
}

function Assert-NoLink([string]$Path) {
  if ((Get-Item -LiteralPath $Path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw "Refusing linked path: $Path"
  }
}

if (-not (Test-Path -LiteralPath (Join-Path $target 'manifest.ini'))) {
  throw "Retro UI is not installed at $target"
}
Assert-ChildPath $game $target
foreach ($path in @($game, (Join-Path $game 'apps'), (Join-Path $game 'apps\lua'), $target)) {
  Assert-NoLink $path
}
foreach ($file in $files) {
  $source = Join-Path $project $file
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing source: $source" }
}

$oldBackups = @()
foreach ($root in $backupRoots) {
  if (-not (Test-Path -LiteralPath $root)) { continue }
  Assert-NoLink $root
  foreach ($directory in Get-ChildItem -LiteralPath $root -Directory -Force) {
    Assert-ChildPath $root $directory.FullName
    Assert-NoLink $directory.FullName
    $date = $directory.CreationTime.Date
    if ($directory.Name -match '(?<!\d)(20\d{6})(?!\d)') {
      $date = [datetime]::ParseExact($Matches[1], 'yyyyMMdd', [Globalization.CultureInfo]::InvariantCulture)
    }
    if ($date -lt $cutoff) {
      $oldBackups += [pscustomobject]@{Root = $root; Path = $directory.FullName; Date = $date}
    }
  }
}
Write-Output "Install target: $target"
Write-Output "Backup cutoff: $($cutoff.ToString('yyyy-MM-dd'))"
foreach ($root in $backupRoots) {
  Write-Output "$root : $(@($oldBackups | Where-Object { $_.Root -eq $root }).Count) old backups"
}
if (-not $Apply) { Write-Output 'Preview only. Use -Apply to install and remove the listed old backups.'; return }

# Validate every recursive deletion target before changing the installation.
foreach ($backup in $oldBackups) {
  Assert-ChildPath $backup.Root (Resolve-Path -LiteralPath $backup.Path).Path
  $links = @(Get-ChildItem -LiteralPath $backup.Path -Recurse -Force |
    Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint })
  if ($links.Count) { throw "Backup contains linked paths: $($backup.Path)" }
}

$saved = Join-Path $backupRoots[0] ('lock-feedback-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
Assert-ChildPath $backupRoots[0] $saved
New-Item -ItemType Directory -Path $saved -ErrorAction Stop | Out-Null
foreach ($file in $files + @('RetroUI.lua')) {
  $installed = Join-Path $target $file
  Assert-ChildPath $target $installed
  if (Test-Path -LiteralPath $installed) {
    $destination = Join-Path $saved $file
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $installed -Destination $destination
  }
}
foreach ($file in $files) {
  $source = Join-Path $project $file
  $destination = Join-Path $target $file
  Assert-ChildPath $target $destination
  Copy-Item -LiteralPath $source -Destination $destination -Force
  if ((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $destination).Hash) {
    throw "Installed file differs from source: $file"
  }
}
(Get-Item -LiteralPath (Join-Path $target 'RetroUI.lua')).LastWriteTime = Get-Date
Write-Output "Installed and verified $($files.Count) files. Today's recovery copy: $saved"

$deleted = 0
foreach ($backup in $oldBackups) {
  Assert-ChildPath $backup.Root (Resolve-Path -LiteralPath $backup.Path).Path
  Assert-NoLink $backup.Path
  Remove-Item -LiteralPath $backup.Path -Recurse -Force
  if (Test-Path -LiteralPath $backup.Path) { throw "Backup was not removed: $($backup.Path)" }
  $deleted++
}
Write-Output "Removed $deleted backup directories older than $($cutoff.ToString('yyyy-MM-dd'))."
foreach ($root in $backupRoots) {
  if (Test-Path -LiteralPath $root) {
    Write-Output "Remaining backups in $root : $(@(Get-ChildItem -LiteralPath $root -Directory -Force).Count)"
  }
}
