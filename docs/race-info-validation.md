# Race instruments validation

## Author-confirmed game testing

The author confirmed on 2026-10-07 that Retro UI had been validated while driving throughout the release week and that updates had been tested with each previous release. This report accepts that validation as completed; it is not a claim that the agent drove the game.

## Automated verification

`npm run check:lua` checks runtime Lua, tests, require paths, 11 windows and 14 CSP callbacks. `python tools/test-lua.py` runs isolated Lua 5.2 regression suites for the single complete app.

Coverage includes independent ABS/TC levels, zero and unavailable channels; leaderboard crossings, silent SDK fallback, continuous position history, estimated gaps, online finish crossings with a zero lap counter, pit/jump/reconnect resets and replay epochs; tyres, condition, map, hybrid power/recovery, illumination, layout geometry, settings migration and all instrument windows.

`python tools/check-package.py dist/RetroUI-v2.5.1.zip` checks the exact runtime allowlist, required assets and modules, manifest/source fidelity, version, archive integrity and checksum. Concept art and stock footage do not ship.

## Limits

Regression renderers use CSP test doubles and do not replace the real game's antialiasing or telemetry. Promotional UI clips use simulated inputs. Data availability remains car- and session-dependent; speed-based leaderboard estimates are marked `~`.
