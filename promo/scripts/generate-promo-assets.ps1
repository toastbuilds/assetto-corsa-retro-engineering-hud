param([switch]$StillsOnly,[switch]$MotionOnly)
$ErrorActionPreference = 'Stop'
$promoRoot = Split-Path $PSScriptRoot -Parent
$repoRoot = Split-Path $promoRoot -Parent
Push-Location -LiteralPath $repoRoot
try {
  if (-not $MotionOnly) {
    python promo/scripts/generate.py --inventory --stills --extras
    if ($LASTEXITCODE -ne 0) { throw 'PNG generation failed' }
    python promo/scripts/coverage.py
    if ($LASTEXITCODE -ne 0) { throw 'Supplementary coverage failed' }
    python promo/scripts/refresh-sheets.py
    if ($LASTEXITCODE -ne 0) { throw 'Publication sheets failed' }
  }
  if (-not $StillsOnly) {
    python promo/scripts/generate.py --motion
    if ($LASTEXITCODE -ne 0) { throw 'Motion generation failed' }
  }
  python promo/scripts/generate.py --validate
  if ($LASTEXITCODE -ne 0) { throw 'Asset validation failed' }
  python promo/scripts/report.py
  if ($LASTEXITCODE -ne 0) { throw 'Documentation generation failed' }
} finally { Pop-Location }
