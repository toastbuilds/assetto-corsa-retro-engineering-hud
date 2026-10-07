# Changelog

## 2.5.1

### Fixed

- Digital Dial ABS now displays its own level instead of the TC level, including zero and unavailable channels.
- Leaderboard records position crossings even when CSP callbacks are unavailable, and uses continuous position history for live intervals.
- Distance/speed fallback keeps gaps available while history is incomplete; estimates are marked `~`.
- Online rivals with a lap counter stuck at zero retain continuous timing across observed finish-line crossings.

### Changed

- One free, complete distribution: all GT7 layouts, component controls and Laps animations are included.
- Release archive is now `RetroUI-v2.5.1.zip`. The installation folder and stored preferences remain unchanged.
- Packages include runtime Lua, class maps, the two notification sounds, user documentation and licenses. Concept art, reference images and stock footage are excluded.
- CI runs regression suites and verifies package contents, source fidelity, version and SHA-256 before preparing a draft release.
- English GitHub README, user guide, settings reference, video gallery and release notes. Optional Ko-fi configuration is prepared for the future account.

## 2.5.0

- Expanded map markers and off-track/flag alerts.
- Improved tyre readouts, units, temperature mixing, references and stint detail.
- Compact leaderboard rows, sector references, position movement and timing improvements.

Earlier release history: https://github.com/yukkine0704/assetto-corsa-retro-engineering-hud/releases
