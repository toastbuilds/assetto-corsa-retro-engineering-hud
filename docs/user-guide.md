# Retro UI user guide

Retro UI is a free, complete HUD suite for Assetto Corsa on PC. All layouts, customization controls and animations are included in one app.

## Requirements

- Assetto Corsa for Windows.
- Custom Shaders Patch with Lua apps enabled. CSP 0.2.8 or newer is recommended for all window anchoring features, including mouse pass-through.
- Content Manager is recommended for ZIP installation and app activation.
- Some car condition, tyre, aero and hybrid readings require telemetry supplied by the car or CSP. Missing data is hidden or identified as unavailable.

## Install with Content Manager

1. Download `RetroUI-vX.Y.Z.zip` from the project's GitHub Releases page.
2. Drag the ZIP into Content Manager and confirm installation.
3. Enable Retro UI in your app settings.
4. Start a driving session and use the CSP app sidebar to open Retro UI windows.
5. Open **Retro UI Settings** to configure the instruments.

## Manual installation

Close Assetto Corsa. Extract the ZIP into the game directory so the entry script is located at:

```text
assettocorsa/apps/lua/RetroUI/RetroUI.lua
```

Avoid nesting another `assettocorsa` or `RetroUI` folder inside the destination. Enable the app and open its windows from the CSP sidebar.

## Update

Close the game and install the new ZIP over the existing app. The installation folder remains `apps/lua/RetroUI`; stored settings use their existing keys. Downloads from before 2.5.1 had different package names, but used the same installation folder.

If you edited either `modules/relative/classes.ini` or `modules/leaderboard/classes.ini`, back it up before updating and restore your mappings afterward. ZIP installation can overwrite these files. The repository's optional PowerShell installer preserves them and creates a backup automatically.

No purchase or activation key is needed. There is one complete package.

## Open and arrange windows

The suite provides Dial, GT7, Car Condition, Multiclass Relative, Delta Bar, Timer, Laps, Leaderboard, Telemetry, Map, Race Notices, plus Settings.

- Open or close instruments independently through the CSP app sidebar.
- Resize a window to adjust its displayed size; keep its own scale setting at a comfortable value.
- Right-click a HUD window to anchor it. The brief **FIXED** indicator confirms the change.
- Right-click again to release it; **MOVE** confirms that it can be repositioned.
- Anchored windows keep their position between sessions and allow mouse pass-through where supported by CSP. Settings remains interactive.

## Configure the HUD

**General** contains shared theme, speed/temperature/pressure units, content opacity, background opacity, RPM thresholds and the **Suggested corner gear** switch. When enabled, GT7 shows the suggested gear to the right of the current gear. Dial shows the cue only in Digital Original, Concentric, Shelf, Spoke, Snap Selector, Bridge, Column, Radial, Offset, Core Capsule, Floating and Orbit faces; Analog Original hides it. Instrument tabs contain **Basics**, **Personalization** and **Advanced** sections.

GT7 includes Classic, Modern, Outer Pedals and Steering Dial presets. Presets are starting points: speed, gear, steering, RPM bar, pedals, radar, flags and lower panel can be configured independently. Analog and digital side dials can be mixed.

Under **GT7 → Personalization → Side dials**, **Fuel gauge style** and **Turbo / AERO / battery gauge style** each include 16 mini dial families, with descriptive names such as **Twin Rim**, **Spoke Wheel** and **Segment Arch**. Use the independent sliders to browse each side; the current name and position appear above each slider. Each family follows its main dial's analog/digital mode: analog uses the concept's own needle; digital uses segments on the same scale. Hybrid cars retain a CHG/PWR dial and a thin outer battery band with its percentage. Mini faces fit the auxiliary area. Expanded lower arcs use their fixed design and hide the corresponding style selector; the saved mini style returns when a compact layout is selected. Existing styles and saved selections remain available.

Matching speed and RPM designs use the same auxiliary position and size in each mode. Fuel, turbo and AERO change the readings and markings. Fan and Bridge use expanded lower arcs on both sides.

**Sweep Band is analog only** and is omitted from digital selectors; a previously saved digital Sweep Band selection falls back to Original. Fuel indications turn amber below 30% and red below 15%; below 10%, the red warning fades in sync with the lower fuel status icon and never disappears when animations are enabled. Accent Rim uses the same pulse on its right accent throughout the red warning range. Digital cells align with the face divisions. The wider final cell in Offset Blocks represents the same value increment as each narrow cell, so its needle and live analog fill cover more angle per value unit.

The final 15% of every digital mini scale uses the theme's red warning ink (dim while inactive). Wide cells change color at exactly 85% without changing their value step. Twin Rim, Accent Rim and Open Ring leave gaps for bezel graduations; Shelf Scale replaces minor graduations on its outer scale, while Open Ticks keeps them visible beside the digital track. E/F and numeric scale limits sit beside the face with a foreground backing. Fuel, boost and aero use centered icons without channel captions. Dashed Ring uses a rotating semicircular needle counterweight.

Crown Blocks, Offset Blocks and Segment Arch dim consumed cells and progressively fill the remaining range in Analog. Sweep Band does the same with its continuous band. Inward Ticks lights its analog ticks up to the needle while keeping its Digital graduations fixed. Radial Cells prints its last fuel background cell red; Dashed Ring prints the terminal 15% of its fuel background red.

Full circular mini dials are 45.2% larger than their initial size, including their graduations, needles and labels. Semicircular faces are 15.5% larger. Twin Rim uses its full circular double rim. Both shapes include the latest 10% enlargement; compact compositions leave clearance for the larger faces. Icons and readouts sit inside the lower face to keep them clear of the main bezel.

**Reset appearance** restores the instrument's presentation. **Reset all** asks for confirmation and restores its local settings. In Relative and Leaderboard it also restores the class map and saves a copy of the previous file under `Documents/Assetto Corsa/RetroUI/Class Backups`.

See the [settings reference](https://github.com/yukkine0704/assetto-corsa-retro-engineering-hud/blob/main/docs/settings.md) or `docs/settings.md` inside the installed app for more details.

## Reading timing and condition data

Leaderboard race gaps are relative to you: positive means ahead in race progress, negative means behind. A whole-lap separation uses `L +N` or `L -N`. An interval prefixed with `~` is a distance/speed estimate while position history is unavailable. Precise CSP crossings take priority when available.

Relative shows physical nearby traffic around the circuit; its sign convention is negative ahead and positive behind. Lap markers identify lapping relationships separately. The two windows answer different questions.

Unknown sector validity is neutral. Invalid laps do not improve sector records. Relative session and track records are your own valid laps, stored locally per car, track and layout.

Car Condition can display tyre life, pressure, pressure delta or temperature. Its detail panel includes compound and stint information. `~` identifies estimated references; **FROM OBSERVATION** means the app cannot reconstruct usage before monitoring began.

Replay seeks and session restarts clear incompatible timing history. Some replay channels are unavailable. Turbo vacuum simulation and some aero/hybrid references are estimates rather than direct sensor values.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| App is absent | Correct install folder, CSP Lua apps enabled, Retro UI activated |
| HUD cannot be moved | Right-click to release its anchor; check the FIXED/MOVE feedback |
| A reading is missing | The car or replay may not provide that telemetry; try an official car in a live session |
| A gap has `~` | It is a temporary distance/speed estimate; position history is still being collected |
| Windows overlap old HUDs | Close or disable the older separate apps |
| Customized class maps changed after an update | Restore your saved `classes.ini` files |

For support, open a GitHub issue with CSP version, car, track/layout, session type, steps and a screenshot or clip. Never include passwords or account tokens in logs.

## Migration from older separate apps

The repository includes `tools/install-retro-ui.ps1` for migration. It backs up the old apps, preserves class maps and installs the unified app. It does not carry over every old app's settings because CSP stores preferences per app identity.

Delta records from the previous Delta Bar remain under `Documents/Assetto Corsa/CMRTRetroDeltaBar`. Validate the unified app before retiring old folders. For script usage and backup restoration, see the repository's development guide.

## Uninstall

Close the game, disable Retro UI and remove `apps/lua/RetroUI`. Saved CSP preferences and historical records may remain. Keep them if you plan to reinstall; removing the app folder does not intentionally erase personal timing history.

## Support development

All features remain free. You can optionally support development through [Ko-fi](https://ko-fi.com/R6R0MLVVS) or [PayPal](https://paypal.me/WendyGalvezSanchez). Donations will not unlock layouts, settings or animations.

## License

MIT. See `LICENSE` and `THIRD_PARTY_NOTICES.md` included in the ZIP.
