# Development and releases

## Checks

Install Node.js and Python with the pinned Lupa dependency, then run:

```powershell
npm ci
python -m pip install -r requirements-dev.txt
npm run check:lua
python tools/test-lua.py
```

The Lua runner isolates suites in Lua 5.2 runtimes. Checks cover settings migration, 11 windows, CSP callbacks, geometry, timing, tyre data, hybrids, illumination, independent ABS/TC values and live/replay history changes.

## Build

Set `VERSION` in `manifest.ini` and add `docs/releases/vX.Y.Z.md` and a changelog entry. The build reads the manifest version by default and rejects a mismatched explicit version.

```powershell
powershell -ExecutionPolicy Bypass -File tools/build-package.ps1
python tools/check-package.py dist/RetroUI-v2.5.1.zip
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

After creating the author's Ko-fi account, replace the empty mapping in `.github/FUNDING.yml` with `ko_fi: ACCOUNT_NAME` and add the verified account URL to the README and user guide. No donation is needed to enable any feature. GitHub configuration reference: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/displaying-a-sponsor-button-in-your-repository
