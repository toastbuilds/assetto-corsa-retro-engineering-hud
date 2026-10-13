# Retro UI settings reference

Use **Retro UI Settings** from the CSP app sidebar. Every instrument is included in the free download.

## General

Shared light/dark themes, speed units, Celsius/Fahrenheit, psi/bar/kPa, content/background opacity, RPM warning/redline thresholds, fallback RPM and blinking alerts. Local scale and geometry remain independent per instrument.

## Dial and GT7

- Switch between analog and digital modes. GT7 speed and RPM dials can use different modes.
- In the standalone analog dial, select **Variant**: Original, Classic Shelf, Fan, Track (3A), Halo (6A), Jewel (1A), Spectrum (2A), Concentric, Spoke or Snap Selector. Original remains the upgrade default.
- Retired analog variants 2 and 4 revert to Original. Analog 5 Concentric has a transparent opening and an opaque central speed face; its center stays opaque when background opacity is reduced.
- In digital mode, **Variant** offers Original plus 1 Bridge, 2 Column, 3 Radial, 4 Offset, 5D Core Capsule, 6D Halo, 1D Jewel, 2D Spectrum, 4D Floating, 6 Orbit and Snap Selector. Analog and digital selections are saved independently. The digital faces are drawn natively, including segmented RPM, pedal bars, indicators and the auxiliary readout. The original digital face remains the default.
- **Snap Selector** puts RPM across the outer upper arc, R and the car's forward gears on a larger upper inner arc around the selector, and speed near the bottom. The four status alerts flank the selector just above the brake and throttle pedals, leaving the bottom for the handbrake and flag warnings. The plate and notch snap toward the highlighted gear in 120 ms with a restrained rebound; the central numeral stays upright and updates immediately. N appears only in the centre and holds the last notch position. Unknown gear counts fall back to six, expanding if a higher gear is observed. **Animate gear selector** switches to an immediate notch update. The original bezel lamps, theme/backlighting, fuel warnings, auxiliary tracks, brake/throttle pedals, steering and status symbols remain available.
- Analog **Snap Selector** keeps the needle tachometer, moves the highlighted R/1–6 selector to its center and puts speed below it. Fuel and turbo/ERS use icon-only side bars; TC, ABS, lights and pit alerts sit above the brake/throttle indicators. This layout omits clutch and steering to preserve the open face.
- Analog variants include brake/throttle tracks, optional clutch and steering, TC/ABS states, flags and a handbrake triangle. Lights can be hidden. Auxiliary screens adapt to turbo, fuel or electric delivery/recovery plus battery charge; Turbo on a car without turbo retains the AERO display.
- Select one of 24 analog needle geometries. The standalone RPM needle and GT7 speed/RPM needles keep separate selections.
- Adjust GT7 side dial scale/spacing and status indicator size.
- Choose GT7 presets or customize central speed, gear, steering, RPM bar, pedal position/style, radar and flags independently.
- GT7 side dials add Track, Halo, Jewel and Spectrum in Analog, plus Halo, Jewel, Spectrum and Floating Capsule in Digital. Snap Selector is available on the RPM dial only; its speed dial remains independently selectable. Floating Capsule carries the compact part of Core Capsule without duplicating readouts already shown elsewhere in GT7.
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

Halo 6A/6D share a corona of sixteen progressive RPM dots and a fixed top chevron. Halo 6A keeps the analog RPM numbers, selectable needle and upper speed; Halo 6D has larger central speed, exact RPM above and a circular gear badge below. Thin interior tracks show turbo/AERO or battery charge on the left, fuel on the right, brake/throttle just inside those tracks, and optional clutch below. Electric power remains a numeric readout beside the battery icon. Both use symbol-only states and preserve redline, shift, fuel, race flag and handbrake alerts; the digital steering marker follows the gear ring, while analog steering uses the needle hub ring.

Jewel 1A/1D use a crown of alternating large and small dots confined to the RPM sweep, leaving the lower alert area open. RPM illuminates the sweep progressively; broad strokes connect the large dots in the shift and redline zone. Jewel 1A keeps upper speed and a longer analog needle; Jewel 1D uses central speed, a lower gear badge and exact RPM below, with a graduated horizontal steering line.

Spectrum 2A/2D use a broad green/amber/red band close to the bezel. Spectrum 2A retains the numbered RPM scale and analog needle without an extra outer pointer. Spectrum 2D makes the outer band a speedometer without exterior numbers, using a face-colored notch and the car's existing speed scale in the selected km/h or mph units; it reports RPM independently on the lower arc and numeric readout. Both auxiliary tracks use icons without numeric values. Digital steering follows the gear ring.

Floating 4D frames speed with a tapered contour toward the left of an inclined gear capsule, with symbol states above, thin pedals below the speed and RPM on the lower arc. Wide turbo/AERO/battery and fuel tracks follow the upper bezel to a central notch, with unobstructed icons below their lower ends and no numeric auxiliary values. The entire gear capsule flashes amber at the shift warning and red at redline, respecting the animation settings. Steering uses the upper graduated line. All five faces preserve the original bezel lamps, theme illumination, fuel thresholds and existing visibility settings.

Reference comparisons can be regenerated with `python tools/preview-inspired-dials.py --family final --size 320`; add `--theme light`, `--aux electric`, or `--aux fuel --alerts --rpm 1` for alternate states. Images are written to `output/dial-inspirations`.

Analog 3A Track uses a clean circular RPM scale with a distinct redline sector, a large upper speed readout, a raised lower gear badge and a compact auxiliary screen. It omits numeric RPM; its four status symbols sit in two columns spaced away from the inner steering ring, without level numbers, and its flag/warning indicators sit at the bottom. Digital 5D Core Capsule emphasizes the central speed and groups gear and exact RPM in a lower capsule; turbo/AERO/battery and fuel share a 230-degree upper bezel sweep, rising from their lower ends toward a triangular top divider, with icons below their arcs and no auxiliary units. Its pedal strips use colors without letters, its status cards use icons without level numbers, and flag/warning indicators sit beneath those cards. Both keep the shared bezel and the standalone dial's pedal, steering, clutch and status readouts.

Digital 2 and 4 use turbo/AERO/battery and fuel semicircular tracks along the inner bezel. Digital 2 raises the brake/throttle bars to clear the RPM display; Digital 4 omits the RPM scale numbers. Digital 6 fills both upper perimeter bars upward, omits units, and follows the outer circumference with the brake and throttle tracks.

Standalone faces omit descriptive captions while retaining measurements and TC/ABS/PIT status abbreviations. Digital 6 uses a larger speed/gear circle with a steering sphere traveling around its outer ring; the steering visibility setting controls this sphere.

Digital 3 uses a steering sphere around the central speed/gear circle, with auxiliary dots beneath the RPM arc and the auxiliary reading above the RPM value.

Digital 1 uses a graduated steering line above the speed readout. Digital 2 and 4 omit auxiliary units and place channel icons below their perimeter bars. Digital 6 raises its central circle and uses a graduated steering ring. Standalone fuel readouts turn red below 15% and flash below 10%.

Analog pedal tracks fill upward in Classic Shelf, Fan, Track and Concentric; Spoke fills both tracks outward from the centre and uses an illuminated steering marker on its hub ring. Concentric has a smaller opaque central readout, a 10% background in its opening, and opposing lower auxiliary and upper fuel arcs with icons and no units.


Concentric omits numeric RPM and auxiliary readings; its auxiliary icons sit to the right of their arcs. Its steering track and lower auxiliary arc are raised. The needle draws above pedal tracks and beneath the opaque central readout.

## Battle Panel

Open **Retro UI Battle Panel** from the CSP sidebar. It shows the drivers directly ahead and behind in your class, ordered by race position, even when other classes or lapped traffic are nearby. Default placement is at the middle left. Global theme and opacity apply.

**Basics:** scale and gap history. **Personalization:** auto-placement, stay visible and an eight-second preview. Right-click to anchor the panel.

The right number shows seconds gained (+, green) or lost (-, red) per lap, replacing the interval to the rival. The enlarged history graphs rise when you gain and fall when you lose against either rival. Trends require one full lap of continuous data and compare the gap at the same track position over up to three laps; `--` is shown while collecting data. `~` marks estimated rates. Rival changes, pit stops, restarts and replay seeks clear history. Unavailable rivals retain their PIT/OFF/RET status; a missing trend stays neutral. Class detection follows Leaderboard settings. Outside a race the panel displays its availability message.
