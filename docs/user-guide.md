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

**General** contains shared theme, speed/temperature/pressure units, content opacity, background opacity, RPM thresholds and the **Suggested corner gear** switch. When enabled, GT7 and Dial show the estimated gear for the next corner. Instrument tabs contain **Basics**, **Personalization** and **Advanced** sections.

GT7 includes Classic, Modern, Outer Pedals and Steering Dial presets. Presets are starting points: speed, gear, steering, RPM bar, pedals, radar, flags and lower panel can be configured independently. Analog and digital side dials can be mixed.

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
