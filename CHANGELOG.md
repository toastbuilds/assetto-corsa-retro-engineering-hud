# Changelog

## 2.8.0

### Added

- Per-app themes and color palettes.
- New horizontal Dash with two layouts.
- 16 GT7 mini-gauge styles, selectable separately for speed and RPM.
- Slipstream glow on GT7 speed dials.
- Race Notices overtake recaps and an optional four-lap gap graph.
- Suggested corner gear and pedal traces that show input alongside estimated output, including TC and ABS.
- Online connection bars on the Leaderboard.

### Improved

- Leaderboard puts session time and lap progress up front, marks estimates with `~`, and drops air and track temperatures.
- Timer catches the last lap in timed races. Its clock stays centered, and sector/delta text stays the same size.
- Smoother GT7 lighting and needles, clearer fuel warnings and redline marks, and more reliable overtake detection.

## 2.7.0

### Added

- Added analog Jewel, Spectrum, Track, Halo and Snap Selector dial faces, plus digital Jewel, Spectrum, Core Capsule, Halo, Floating, Orbit and Snap Selector faces.
- Added animated Snap gear selectors to standalone and GT7 RPM dials. The next gear lights red above the configured redline threshold by 2%; the previous gear lights blue at or below 55% RPM.
- Added Halo, Jewel and Spectrum options for GT7 auxiliary gauges, with matching analog and digital treatments.
- Integrated class-rival pace tracking into Race Notices, replacing the separate Battle Panel. Added green attack opportunities for a rival ahead when gaining at least 0.5 s/lap with a predicted catch under four laps. Rear threat thresholds are unchanged; notices have independent controls and previews.

### Improved

- Standardized standalone Dial selector names to match GT7: descriptive names such as Halo, Jewel and Spectrum replace numbered concept codes. Stored selections remain compatible.
- GT7 and standalone dial faces now keep their layouts distinct while sharing theme colors, status indicators and auxiliary data.
- GT7 Jewel RPM limiter strokes now leave clear gaps around the crown dots.
- The original standalone dial backlight now follows GT7's eased 220 ms illumination transition, including needle, readouts and auxiliary indicators.
- Refined RPM and speed readout placement, gear selector alignment, auxiliary gauge spacing and warning-light visibility across the new dial faces.

## 2.6.0

### Added

- Rear Battle notices warn only about the class rival behind: closing faster than 1 s/lap, or at least 0.5 s/lap with a predicted catch under two laps. The banner shows loss per lap and estimated laps to catch, with amber/red severity and an independent toggle/preview.

- Battle Panel: class rivals ahead and behind, live intervals, gap history and trends at matching track positions over up to three laps. English UI, shared theme/opacity, independent scaling and placement.
- Race Notices: a compact English banner for blue flags with class/gap, repair warnings and automatic fuel-based pit reminders. Pit notices include estimated full repair time from the car's own pit rates, with no redundant banner heading.
- Car Condition: remaining tyre life uses a 12 segment vertical bar beside each tyre, while retaining the numeric readout.
- Four new analog Dial layouts: Concentric, Fan, Shelf and Spoke, each with light and dark finishes.
- Five digital Dial variants with distinct layouts, steering details and perimeter gauges.
- GT7 side dials that adapt their composition to the selected instrument style, including hybrid readouts and lower auxiliary arcs.
- More control over dial variants, indicators and visual details in Settings.

### Improved

- Battle Panel: the right readout shows signed seconds gained or lost per lap in green/red. Enlarged graphs replace the explanatory trend text and rise for gains or fall for losses against either rival.

- Race Notices: fuel autonomy triggers five-second reminders at finish-line crossings with three or two complete laps remaining; the final fuel lap keeps BOX THIS LAP visible. Ignored repair warnings clear after the damaged lap, with new damage able to trigger a fresh warning.

- Timer panels now center lap times and deltas more clearly, keep clock sizing stable, and show a full-width final-lap result banner.
- Final-lap detection now also uses Assetto Corsa's native signal; result flashes last two seconds.
- Approaching FAST rows blink while keeping their text readable.
- Analog redline blocks and GT7 limiter animation are clearer.
- Lap row fades preserve each row's colors.

### For creators

- Added previews and shell-building tools for the new instrument variants.

Earlier release history: https://github.com/yukkine0704/assetto-corsa-retro-engineering-hud/releases

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
