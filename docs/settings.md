# Retro UI settings reference

Use **Retro UI Settings** from the CSP app sidebar. Every instrument is included in the free download.

## General

Shared light/dark themes, speed units, Celsius/Fahrenheit, psi/bar/kPa, content/background opacity, RPM warning/redline thresholds, fallback RPM and blinking alerts. Local scale and geometry remain independent per instrument.

## Dial and GT7

- Switch between analog and digital modes. GT7 speed and RPM dials can use different modes.
- In the standalone analog dial, select **Variant**: Original, Classic Shelf, Fan, Concentric or Spoke. Original remains the upgrade default; digital mode keeps its existing composition.
- Retired variants 2 and 4 revert to Original. Variant 5 has a transparent opening and an opaque central speed face; its center stays opaque when background opacity is reduced.
- In digital mode, **Variant** offers Original plus 1 Bridge, 2 Column, 3 Radial, 4 Offset and 6 Orbit. Analog and digital selections are saved independently. The digital faces are drawn natively, including segmented RPM, pedal bars, indicators and the auxiliary readout. The original digital face remains the default.
- The four analog variants include brake/throttle tracks, optional clutch and steering, independent TC/ABS levels, flags and a handbrake triangle. Lights can be hidden. Auxiliary screens adapt to turbo, fuel or electric delivery/recovery plus battery charge; Turbo on a car without turbo retains the AERO display.
- Select one of 24 analog needle geometries. The standalone RPM needle and GT7 speed/RPM needles keep separate selections.
- Adjust GT7 side dial scale/spacing and status indicator size.
- Choose GT7 presets or customize central speed, gear, steering, RPM bar, pedal position/style, radar and flags independently.
- Select Grip limit, FFB, Pedal history or Hidden for the lower panel.
- Set the standalone auxiliary gauge to Auto, Turbo, Fuel or Electric. Auto prioritizes supported hybrid telemetry where appropriate.
- Optional vacuum simulation uses throttle and boost; it is not a measured manifold vacuum channel.
- The headlights trigger the internal backlight. ABS and TC intervention indicators are independent; enabled numeric readouts show their respective levels.

## Car Condition

Choose wheel life, pressure, ideal-pressure delta or temperature as the main readout. Core/surface mixing starts at 80/20 and can be adjusted. Physical tyre references take priority over estimated values.

The detail panel opens on hover or during pitlane visits and can be kept open. It shows compound, stint, per-axle references and grip information when available. Estimated references use `~`; incomplete stint history uses **FROM OBSERVATION**.

## Relative and Leaderboard

Relative filters nearby traffic by class or shows all classes, with configurable rows, gap smoothing, sector strip, records and weather. Its order follows physical track proximity, including cars from another lap.

Leaderboard supports 3–10 rows. Practice/qualifying displays best laps and sector references; races show position movement, last laps and gaps relative to the player. Sector validity that cannot be determined stays neutral. Speed-based gap estimates use `~`.

Class overrides live in `modules/relative/classes.ini` and `modules/leaderboard/classes.ini`. Back up edited maps before ZIP updates. Reset all creates a backup before restoring the defaults.

## Delta, Timer and Laps

Delta compares current progress against local lap references. Timer shows lap clocks, completed results and final-lap state for fixed or timed races, with optional audio and sound previews. Laps controls visible history, auto-placement and the lap-change animation switch.

## Telemetry and Map

Telemetry displays input/FFB histories and associated driving channels. Map switches between the full circuit and a car-centred mini map, with fixed or rotating orientation, numbered selected/all cars and configurable track/marker sizes.

Map backgrounds use dots or a radial surface. Off-track and flag alerts depend on the simulation's reported state; four-wheel-off highlighting is suppressed in pitlane.

## Resets and persistence

Basics opens by default. Personalization and Advanced expand when needed. Presets modify composition without locking subsequent edits. Reset appearance changes presentation; Reset all restores the local instrument after confirmation. General has separate shared resets.

Stored settings keep their existing keys when upgrading to the single complete package. Feature availability no longer depends on a package edition.
