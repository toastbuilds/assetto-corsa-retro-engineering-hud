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

Choose wheel life, pressure, ideal-pressure delta or temperature as the main readout. Remaining tyre life appears as a 12 segment vertical bar beside each wheel, with lit segments showing the remaining tread and the numeric value retained. Core/surface mixing starts at 80/20 and can be adjusted. Physical tyre references take priority over estimated values.

The detail panel opens on hover or during pitlane visits and can be kept open. It shows compound, stint, per-axle references and grip information when available. Estimated references use `~`; incomplete stint history uses **FROM OBSERVATION**.

## Relative and Leaderboard

Relative filters nearby traffic by class or shows all classes, with configurable rows, gap smoothing, sector strip, records and weather. Its order follows physical track proximity, including cars from another lap.

Leaderboard supports 3–10 rows. Practice/qualifying displays best laps and sector references; races show position movement, last laps and gaps relative to the player. Sector validity that cannot be determined stays neutral. Speed-based gap estimates use `~`.

Class overrides live in `modules/relative/classes.ini` and `modules/leaderboard/classes.ini`. Back up edited maps before ZIP updates. Reset all creates a backup before restoring the defaults.

## Delta, Timer and Laps

Delta compares current progress against local lap references. Timer shows lap clocks, completed results and final-lap state for fixed or timed races, with optional audio and sound previews. Its clock keeps a fixed font size; sector/lap results hold and flash for 2 seconds, with BEST on the left and relative delta on the right, both at the same height as the clock; FINAL LAP spans the full width underneath. Laps controls visible history, auto-placement and the lap-change animation switch.

## Telemetry and Map

Telemetry displays input/FFB histories and associated driving channels. Map switches between the full circuit and a car-centred mini map, with fixed or rotating orientation, numbered selected/all cars and configurable track/marker sizes.

Map backgrounds use dots or a radial surface. Off-track and flag alerts depend on the simulation's reported state; four-wheel-off highlighting is suppressed in pitlane.

## Race Notices

Open **Retro UI Race Notices** from the CSP sidebar. The English banner has no redundant heading and shares the global theme and opacity. It is empty when no notice is active, and suppressed in pitlane, replays and after the finish. Default placement is centered below the Timer; move it and disable Auto-placement to keep a custom position. Right-click to anchor it.

- **BLUE FLAG** uses the simulation's official flag. The class and physical gap come from the full Relative grid, even when its window is closed or filtered. Unknown causes stay generic; estimated gaps use `~`.
- **REPAIR REQUIRED** shows the affected component for the damaged lap. Crossing the next finish line without pitting dismisses that warning. Unchanged damage stays dismissed; significant fresh damage can trigger a new warning. Default thresholds are 20% bodywork, 5% suspension and 20% engine/gearbox damage. A puncture also triggers a warning. Thresholds are adjustable.
- **BOX IN 3 LAPS / BOX IN 2 LAPS** use the complete laps of fuel remaining, calculated from observed fuel consumption and the Leaderboard fuel reserve. At the finish line with three or two full fuel laps remaining, the reminder appears for five seconds. With one complete lap or less remaining at a crossing, **BOX THIS LAP** stays visible. Refuelling, pit entry and session resets clear the reminder. An unknown consumption estimate or enough fuel to finish suppresses the warning. Timers pause with the simulation.
- **REAR CAR CLOSING / REAR ATTACK INCOMING** only track the class rival behind from Battle. The notice appears while the rival gains more than 1 s/lap, or gains at least 0.5 s/lap with a catch estimate under two laps. The detail shows who is behind and your loss per lap; the right number is estimated **LAPS TO CATCH** (gap divided by closing rate). Amber marks rapid closing from further away; red marks a catch within two laps. A full observed lap is required. Incomplete data, a rival in pits, final results or a rival physically ahead suppress the notice. It disappears when its trigger no longer applies.
- **EST. REPAIR** is an approximation for full bodywork, suspension and engine repair, using the car's `car.ini` pit rates (seconds per 10% damage), the worst body zone and suspension corner, and reported engine damage. It excludes refuelling, tyre replacement and pitlane travel. Mod-specific procedures may differ. Missing rates, gearbox damage, punctures or unavailable damage data show `--` rather than a fabricated time.

Priority is new repair warning, official blue flag, pit reminder, then rear battle warning. Personalization has eight-second previews for all four states. Each notice type can be disabled independently.

## Resets and persistence

Basics opens by default. Personalization and Advanced expand when needed. Presets modify composition without locking subsequent edits. Reset appearance changes presentation; Reset all restores the local instrument after confirmation. General has separate shared resets.

Stored settings keep their existing keys when upgrading to the single complete package. Feature availability no longer depends on a package edition.

All standalone variants reuse the original bezel turn indicators and lower lamp. Variant faces use the shared theme palette and GT7 instrument illumination, including the headlight transition and flasher response. Digital 6 Orbit has a dedicated upper-left turbo/AERO/battery gauge and upper-right fuel gauge.

Digital 2 and 4 use turbo/AERO/battery and fuel semicircular tracks along the inner bezel. Digital 2 raises the brake/throttle bars to clear the RPM display; Digital 4 omits the RPM scale numbers. Digital 6 fills both upper perimeter bars upward, omits units, and follows the outer circumference with the brake and throttle tracks.

Standalone faces omit descriptive captions while retaining measurements and TC/ABS/PIT status abbreviations. Digital 6 uses a larger speed/gear circle with a steering sphere traveling around its outer ring; the steering visibility setting controls this sphere.

Digital 3 uses a steering sphere around the central speed/gear circle, with auxiliary dots beneath the RPM arc and the auxiliary reading above the RPM value.

Digital 1 uses a graduated steering line above the speed readout. Digital 2 and 4 omit auxiliary units and place channel icons below their perimeter bars. Digital 6 raises its central circle and uses a graduated steering ring. Standalone fuel readouts turn red below 15% and flash below 10%.

Analog pedal tracks fill upward in Classic Shelf, Fan and Concentric; Spoke fills both tracks outward from the centre and uses an illuminated steering marker on its hub ring. Concentric has a smaller opaque central readout, a 10% background in its opening, and opposing lower auxiliary and upper fuel arcs with icons and no units.


Concentric omits numeric RPM and auxiliary readings; its auxiliary icons sit to the right of their arcs. Its steering track and lower auxiliary arc are raised. The needle draws above pedal tracks and beneath the opaque central readout.

## Battle Panel

Open **Retro UI Battle Panel** from the CSP sidebar. It shows the drivers directly ahead and behind in your class, ordered by race position, even when other classes or lapped traffic are nearby. Default placement is at the middle left. Global theme and opacity apply.

**Basics:** scale and gap history. **Personalization:** auto-placement, stay visible and an eight-second preview. Right-click to anchor the panel.

The right number shows seconds gained (+, green) or lost (-, red) per lap, replacing the interval to the rival. The enlarged history graphs rise when you gain and fall when you lose against either rival. Trends require one full lap of continuous data and compare the gap at the same track position over up to three laps; `--` is shown while collecting data. `~` marks estimated rates. Rival changes, pit stops, restarts and replay seeks clear history. Unavailable rivals retain their PIT/OFF/RET status; a missing trend stays neutral. Class detection follows Leaderboard settings. Outside a race the panel displays its availability message.
