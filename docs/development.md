# Development and releases

## Checks

Install Node.js and Python with the pinned Lupa dependency, then run:

```powershell
npm ci
python -m pip install -r requirements-dev.txt
npm run check:lua
python tools/test-lua.py
```

The Lua runner isolates suites in Lua 5.2 runtimes. Checks cover settings migration, 13 windows, CSP callbacks, geometry, timing, tyre data, hybrids, illumination, independent ABS/TC values, race notices, both Dash compositions and live/replay history changes.

## Dash previews

Run `python tools/preview-dashboard.py` to render both Dash compositions in dark/light themes at the default 1280 × 220 and minimum 900 × 160 sizes, plus vacuum, active telltales and headlights on/off. The images are written to `output/dashboard/` and use simulated vehicle telemetry; CSP antialiasing and live signals still require an in-game check.

## Race Notices previews

With Pillow installed alongside Lupa, render the actual Lua panel with simulated race data:

```powershell
python tools/preview-notices.py
```

The script writes `outputs/overtake-summary-dark.png` and `outputs/overtake-summary-light.png`, plus the existing notice and battle sheets. Overtake examples cover human and AI drivers, measured and estimated approach pace, insufficient history, recent rival yellow flags and track exits, and long names, at normal and compact sizes. These previews exercise the tracker, notice formatter and Lua renderer; CSP antialiasing and live telemetry require an in-game check. Generated images stay in the ignored output folders.

`outputs/overtake-expanded-dark.png` and `outputs/overtake-expanded-light.png` show the optional four-lap gap graph with complete history, an incident-related gap collapse and a partially observed race, at 660 × 264 and 420 × 168.

## Pedal layer previews

Pedal-layer previews use the live estimator and Lua renderers with simulated controls:

```powershell
python tools/preview-pedals.py
```

`output/pedal-layers/` contains dark/light comparisons for Classic, no intervention, TC/ABS, shift cut, auto-blip and unavailable physics, plus sheets of all GT7 compositions and all Dial pedal variants. `tests/pedal_layers.lua` covers the estimate, availability, pause/reset handling, frame rates and both sizes/themes.

## Build

Set `VERSION` in `manifest.ini` and add `docs/releases/vX.Y.Z.md` and a changelog entry. The build reads the manifest version by default and rejects a mismatched explicit version.

```powershell
powershell -ExecutionPolicy Bypass -File tools/build-package.ps1
python tools/check-package.py dist/RetroUI-v2.7.0.zip
```

There is one complete package. Runtime assets are explicitly allowed in the build; adding an image, video or scratch file to `assets/` does not ship it automatically. `check-package.py` compares archive contents and hashes against the source tree, checks dependencies and verifies the SHA-256 companion file.

## Local installation and migration

```powershell
powershell -ExecutionPolicy Bypass -File tools/install-retro-ui.ps1 -AssettoCorsaRoot 'PATH\assettocorsa'
```

The installer backs up the installed app and separate older apps, preserves customized class maps and installs the package. Delta records in `Documents/Assetto Corsa/CMRTRetroDeltaBar` remain available.

After validating the unified app, retire older app folders with:

```powershell
powershell -ExecutionPolicy Bypass -File tools/install-retro-ui.ps1 -AssettoCorsaRoot 'PATH\assettocorsa' -Finalize -Validated
```

Retired folders are moved into `_RetroUI-Backups`. Restore a backup by closing the game and copying the previous app back into `apps/lua/RetroUI`. Old app preferences can differ because CSP storage is scoped to the installed app identity.

## GitHub release

Use Conventional Commits. Main/PR workflows run syntax, regressions, build and package verification. A matching `vX.Y.Z` tag prepares a **draft** GitHub Release with the ZIP and checksum; it does not publish it automatically. Inspect the artifacts and release notes, then publish the draft when ready.

Avoid including promotional media in the game ZIP. Selected GIFs and the original 38 MP4 clips live under `promo/` for the GitHub README and media gallery. These are rendered UI previews with simulated inputs.

## Optional donations

Optional support links are [Ko-fi](https://ko-fi.com/R6R0MLVVS) and [PayPal](https://paypal.me/WendyGalvezSanchez). `.github/FUNDING.yml` configures Ko-fi and the custom PayPal link for GitHub's sponsor button. No donation is needed to enable any feature.

The README uses Ko-fi's official GitHub image button:

```markdown
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/R6R0MLVVS)
```

For a website that supports JavaScript embeds, use the supplied widget with the same account and button colour:

```html
<script type='text/javascript' src='https://storage.ko-fi.com/cdn/widget/Widget_2.js'></script>
<script type='text/javascript'>kofiwidget2.init('Support me on Ko-fi', '#72a4f2', 'R6R0MLVVS');kofiwidget2.draw();</script>
```

GitHub configuration reference: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/displaying-a-sponsor-button-in-your-repository
