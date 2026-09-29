# Retro Engineering HUD

The HUD broadcasts its selected theme and opacity settings to compatible CSP Lua apps once per second, allowing companion instruments to stay visually synchronized.

A compact retro motorsport HUD for Assetto Corsa, built as a native Custom Shaders Patch Lua app.

![Retro Engineering HUD in Assetto Corsa](assets/retro-engineering-hud.png)

## Features

- Digital, analog and panoramic GT7 Retro instrument modes.
- Central speed/gear readout, RPM arc, redline and shift alerts.
- Digital race-flag alerts and GT7 Retro dial bezels that share the active flag color and blink.
- Embedded, blinking bezel indicators.
- Brake/throttle bars, TC, ABS, lights, pit status and clutch display.
- Optional turbo or fuel lower gauge in analog mode.
- Primitive-drawn panoramic cluster with independently selectable digital bars or inertial speed/RPM needles, inertial boost, fuel, a grip-limit meter and a live analog FFB magnitude meter.
- Optional GT7 Retro lower panel cycles between the default LIMIT gauge, FFB and a compact brake/throttle usage history graph.
- Optional GT7 Retro invisible lower metrics panel reserves a transparent space for a radar or another overlay.
- GT7 Retro side proximity radar reuses the arrow and two-dot indicators: arrow for near, upper dot for closer, and all three lights for side-by-side traffic.
- Per-car GT7 Retro RPM and speed ranges with dense, readable scale labels; speed falls back explicitly when car metadata is unavailable.
- Independent car-condition mini app with primitive-drawn body damage, tyre temperatures, wear and puncture state.
- Light and dark dial themes.
- Persistent visual, RPM and display settings.

## Requirements

- Assetto Corsa (PC).
- Custom Shaders Patch with Lua apps enabled.
- Content Manager is recommended.

## Install

1. Download `RetroEngineeringHUD-v1.3.2.zip` from [Releases](../../releases).
2. Drag the ZIP into Content Manager and accept the install prompt.
3. Enable **Retro Engineering HUD** in the in-game Lua app sidebar.

For a manual install, extract the archive into the Assetto Corsa root. It contains `apps/lua/RetroEngineeringHUD/`.

Use the app settings window to cycle through the three layouts, choose the light or dark theme, set the RPM thresholds, and tune scale and transparency. GT7 Retro preserves a wide aspect ratio inside the existing app window; widen the window for its largest presentation.

**Retro Engineering Car Condition** appears as a separate entry in CSP's in-game app sidebar. It can be moved and resized independently while sharing the HUD theme and opacity settings.

The default GT7 Retro LIMIT gauge shows the highest loaded axle's tyre-slip utilization, with a short worst-wheel peak hold. TC and ABS retain their own visual warnings without changing the indicated grip value. It parks and reports `NO GRIP DATA` when CSP does not provide valid wheel-slip and load telemetry. The FFB gauge remains selectable and reads CSP's `ac.getCar(0).ffbFinal`, moving its inertial needle from the absolute 0–100% magnitude. The panoramic window starts rectangular and widens an older square layout once when GT7 Retro is selected.

## License

[MIT](LICENSE)
