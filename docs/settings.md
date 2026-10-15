# Retro UI settings reference

Use **Retro UI Settings** from the CSP app sidebar. Every instrument is included in the free download.

## General

Shared light/dark themes, speed units, Celsius/Fahrenheit, psi/bar/kPa, content/background opacity, RPM warning/redline thresholds, fallback RPM and blinking alerts. Local scale and geometry remain independent per instrument.

**Color palette** appears below **Theme** in General → Basics. Each theme remembers its own selection and applies it to all instruments immediately. **Original** retains the factory colors. The numbered palettes match the color comparison gallery:

- **Dark:** 01, 02, 06, 07, 08, 13, 14, 15, 25, 26, 28, 32.
- **Light:** 04, 05, 09, 10, 11, 12, 19, 27, 22, 30, 31.

Palette 19 (Cyan Night) is included in Light. Headlight illumination follows the selected palette; official flag and race classification colors retain their meanings. General **Reset appearance** restores both palette selections to Original.

With a numbered palette, Classic Shelf, Fan, Concentric and Spoke use native colored shell geometry instead of the factory PNG material textures.

## Dial and GT7

- Switch between analog and digital modes. GT7 speed and RPM dials can use different modes.
- In the standalone analog dial, select **Variant**: Original, Classic Shelf, Fan, Track, Halo, Jewel, Spectrum, Concentric, Spoke or Snap Selector. Original remains the upgrade default.
- Retired analog variants 2 and 4 revert to Original. Analog Concentric has a transparent opening and an opaque central speed face; its center stays opaque when background opacity is reduced.
- In digital mode, **Variant** offers Original plus Bridge, Column, Radial, Offset, Core Capsule, Halo, Jewel, Spectrum, Floating, Orbit and Snap Selector. Analog and digital selections are saved independently. The digital faces are drawn natively, including segmented RPM, pedal bars, indicators and the auxiliary readout. The original digital face remains the default.
- **Snap Selector** puts RPM across the outer upper arc, R and the car's forward gears on a larger upper inner arc around the selector, and speed near the bottom. The next gear lights red when RPM exceeds the configured redline warning threshold by 2%; the previous gear lights blue at or below 55% of the RPM limiter. The center gear container glows red or blue with the active cue. The four status alerts flank the selector just above the brake and throttle pedals, leaving the bottom for the handbrake and flag warnings. The plate and notch snap toward the highlighted gear in 120 ms with a restrained rebound; the central numeral stays upright and updates immediately. N appears only in the centre and holds the last notch position. Unknown gear counts fall back to six, expanding if a higher gear is observed. **Animate gear selector** switches to an immediate notch update. The original bezel lamps, theme/backlighting, fuel warnings, auxiliary tracks, brake/throttle pedals, steering and status symbols remain available.
- Analog **Snap Selector** keeps the needle tachometer, moves the highlighted R/1–6 selector to its center and puts speed below it. It uses the same red upshift and blue downshift cues as Digital Snap. Fuel and turbo/ERS use icon-only side bars; TC, ABS, lights and pit alerts sit above the brake/throttle indicators. This layout omits clutch and steering to preserve the open face.
- Analog variants include brake/throttle tracks, optional clutch and steering, TC/ABS states, flags and a handbrake triangle. Lights can be hidden. Auxiliary screens adapt to turbo, fuel or electric delivery/recovery plus battery charge; Turbo on a car without turbo retains the AERO display.
- Select one of 24 analog needle geometries. The standalone RPM needle and GT7 speed/RPM needles keep separate selections.
- Adjust GT7 side dial scale/spacing and status indicator size.
- Choose GT7 presets or customize central speed, gear, steering, RPM bar, pedal position/style, radar and flags independently.
- GT7 side dials add Track, Halo, Jewel and Spectrum in Analog, plus Halo, Jewel and Spectrum in Digital. In Analog speed mode, Classic Shelf, Fan, Concentric, Spoke and Track retain the live speed readout; other analog faces use the needle and scale alone. Halo uses a dot crown with a top notch; Jewel adds the original inner graduations and leaves the bottom clear, with connecting strokes through the RPM limiter zone. Spectrum uses a continuous theme-colored green/amber/red band spanning 280 degrees, with a face-colored value marker in Digital. The new styles retain a large lower fuel or turbo/AERO/battery dial. Snap Selector is available on the RPM dial only, with its pointer facing the gear labels, red upshift and blue downshift cues, and a restored lower auxiliary gauge; its speed dial remains independently selectable. Removed Floating Capsule selections fall back to Original.
- The Orbit-style lower rim arc balances the short upper sweeps in Analog Track (speed and RPM), Analog Fan (speed), Analog Snap Selector (RPM), and Digital Bridge and Snap Selector (RPM). It replaces the auxiliary mini dial while retaining fuel, turbo/AERO or hybrid telemetry and the shared theme illumination.
- Fuel and turbo/AERO/battery gauges have independent GT7 style selectors: Original (default), Match main dial, Halo, Jewel and Spectrum. Matching follows Halo, Jewel or Spectrum on the parent dial and uses Original for other designs. These styles work on both the compact subdial and the lower rim arc, in either dial mode; Halo uses lit spheres, Jewel alternates sphere sizes with inner graduations, and Spectrum uses a continuous channel-colored band with a value notch in Digital (or the existing hand in Analog). Hybrid power and battery keep separate arcs and readouts. Fuel turns red below 15% and blinks below 10%, respecting the indicator animation setting; battery reserve and turbo warning colors remain functional.
- In Analog, Halo and Jewel omit the compact subdial housing so its dots have room. Analog Spectrum fills only the current value range (or the interval from zero for vacuum and electric power), leaving the consumed portion dim; this applies to the compact gauge and lower rim, including hybrid battery and power. Digital retains its housing and complete Spectrum band with the value notch.
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
- **REAR CAR CLOSING / REAR ATTACK INCOMING** only track the class rival behind. The notice appears while the rival gains more than 1 s/lap, or gains at least 0.5 s/lap with a catch estimate under two laps. The detail shows who is behind and your loss per lap; the right number is estimated **LAPS TO CATCH** (gap divided by closing rate). Amber marks rapid closing from further away; red marks a catch within two laps. A full observed lap is required. Incomplete data, a rival in pits, final results or a rival physically ahead suppress the notice. It disappears when its trigger no longer applies.
- **OVERTAKE SUMMARY** reports an official position swap with a live human or AI rival: the place gained, driver's name, car and class, plus the measured or estimated seconds per lap gained during the approach when enough same-rival history is available. It waits behind repair, blue-flag and pit notices, then appears for four seconds. Up to three summaries wait in order; pending summaries expire after 12 seconds. The setting has its own toggle and preview.
  A yellow accent and **YELLOW / RIVAL FLAG** replace approach pace if CSP identified that rival as a yellow-flag cause within the previous 20 seconds. **OFF TRACK / TRACK EXIT** shows when all four rival wheels were outside the track in that interval. Official yellow attribution takes priority; an unassigned yellow or another car's yellow is ignored. These are observed circumstances, not proof of a collision or responsibility. The rival's pace history is cleared while this context is recent and starts afresh afterwards.
- **EST. REPAIR** is an approximation for full bodywork, suspension and engine repair, using the car's `car.ini` pit rates (seconds per 10% damage), the worst body zone and suspension corner, and reported engine damage. It excludes refuelling, tyre replacement and pitlane travel. Mod-specific procedures may differ. Missing rates, gearbox damage, punctures or unavailable damage data show `--` rather than a fabricated time.

- **ATTACK OPPORTUNITY** tracks the class rival ahead while you gain at least 0.5 s/lap and the predicted catch is under four laps. It shows the driver, time gained per lap and estimated laps to catch in green. Attack and rear notices have independent toggles and previews. Pace uses matching track positions over up to three laps, requires one full observed lap, and resets on rival changes, pit stops and session/history resets.

Priority is new repair warning, official blue flag, pit reminder, overtake summary, rear battle warning, then attack opportunity. Personalization has eight-second previews for all notice types. Each notice type can be disabled independently.

## Resets and persistence

Basics opens by default. Personalization and Advanced expand when needed. Presets modify composition without locking subsequent edits. Reset appearance changes presentation; Reset all restores the local instrument after confirmation. General has separate shared resets.

Stored settings keep their existing keys when upgrading to the single complete package. Feature availability no longer depends on a package edition.

All standalone variants reuse the original bezel turn indicators and lower lamp. Variant faces use the shared theme palette and GT7 instrument illumination, including the headlight transition and flasher response. Digital Orbit has a dedicated upper-left turbo/AERO/battery gauge and upper-right fuel gauge.

Analog and digital Halo share a corona of sixteen progressive RPM dots and a fixed top chevron. Analog Halo keeps the analog RPM numbers, selectable needle and upper speed; Digital Halo has larger central speed, exact RPM above and a circular gear badge below. Thin interior tracks show turbo/AERO or battery charge on the left, fuel on the right, brake/throttle just inside those tracks, and optional clutch below. Electric power remains a numeric readout beside the battery icon. Both use symbol-only states and preserve redline, shift, fuel, race flag and handbrake alerts; the digital steering marker follows the gear ring, while analog steering uses the needle hub ring.

Analog and digital Jewel use a crown of alternating large and small dots confined to the RPM sweep, leaving the lower alert area open. RPM illuminates the sweep progressively; broad strokes connect the large dots in the shift and redline zone. Analog Jewel keeps upper speed and a longer analog needle; Digital Jewel uses central speed, a lower gear badge and exact RPM below, with a graduated horizontal steering line.

Analog and digital Spectrum use a broad green/amber/red band close to the bezel. Analog Spectrum retains the numbered RPM scale and analog needle without an extra outer pointer. Digital Spectrum makes the outer band a speedometer without exterior numbers, using a face-colored notch and the car's existing speed scale in the selected km/h or mph units; it reports RPM independently on the lower arc and numeric readout. Both auxiliary tracks use icons without numeric values. Digital steering follows the gear ring.

Digital Floating frames speed with a tapered contour toward the left of an inclined gear capsule, with symbol states above, thin pedals below the speed and RPM on the lower arc. Wide turbo/AERO/battery and fuel tracks follow the upper bezel to a central notch, with unobstructed icons below their lower ends and no numeric auxiliary values. The entire gear capsule flashes amber at the shift warning and red at redline, respecting the animation settings. Steering uses the upper graduated line. All five faces preserve the original bezel lamps, theme illumination, fuel thresholds and existing visibility settings.

Reference comparisons can be regenerated with `python tools/preview-inspired-dials.py --family final --size 320`; add `--theme light`, `--aux electric`, or `--aux fuel --alerts --rpm 1` for alternate states. Images are written to `output/dial-inspirations`.

Analog Track uses a clean circular RPM scale with a distinct redline sector, a large upper speed readout, a raised lower gear badge and a compact auxiliary screen. It omits numeric RPM; its four status symbols sit in two columns spaced away from the inner steering ring, without level numbers, and its flag/warning indicators sit at the bottom. Digital Core Capsule emphasizes the central speed and groups gear and exact RPM in a lower capsule; turbo/AERO/battery and fuel share a 230-degree upper bezel sweep, rising from their lower ends toward a triangular top divider, with icons below their arcs and no auxiliary units. Its pedal strips use colors without letters, its status cards use icons without level numbers, and flag/warning indicators sit beneath those cards. Both keep the shared bezel and the standalone dial's pedal, steering, clutch and status readouts.

Column and Offset use turbo/AERO/battery and fuel semicircular tracks along the inner bezel. Column raises the brake/throttle bars to clear the RPM display; Offset omits the RPM scale numbers. Orbit fills both upper perimeter bars upward, omits units, and follows the outer circumference with the brake and throttle tracks.

Standalone faces omit descriptive captions while retaining measurements and TC/ABS/PIT status abbreviations. Orbit uses a larger speed/gear circle with a steering sphere traveling around its outer ring; the steering visibility setting controls this sphere.

Radial uses a steering sphere around the central speed/gear circle, with auxiliary dots beneath the RPM arc and the auxiliary reading above the RPM value.

Bridge uses a graduated steering line above the speed readout. Column and Offset omit auxiliary units and place channel icons below their perimeter bars. Orbit raises its central circle and uses a graduated steering ring. Standalone fuel readouts turn red below 15% and flash below 10%.

Analog pedal tracks fill upward in Classic Shelf, Fan, Track and Concentric; Spoke fills both tracks outward from the centre and uses an illuminated steering marker on its hub ring. Concentric has a smaller opaque central readout, a 10% background in its opening, and opposing lower auxiliary and upper fuel arcs with icons and no units.


Concentric omits numeric RPM and auxiliary readings; its auxiliary icons sit to the right of their arcs. Its steering track and lower auxiliary arc are raised. The needle draws above pedal tracks and beneath the opaque central readout.
