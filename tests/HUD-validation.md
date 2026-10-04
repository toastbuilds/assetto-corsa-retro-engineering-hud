# HUD validation

Baseline (2026-10-03): all suites before timing passed. Timing failed in Timer display because the vector test double lacks unary negation; correction deferred to Timer commit.

Leaderboard: leader/session reference, countdown milliseconds including zero/negative, fixed distance, fuel reset and missing references passed. Eight drawing traces cover both themes, flag modes and scale limits. Lua syntax checked. These are CSP drawing doubles; live gameplay has not been observed.

Relatives: 96 panel drawing cases, 32 measured-column cases, long UTF-8 names, indicators, option combinations and measured vertical centers passed. Seven rows retained at the default window size. Record values use 24 units in 52-unit panels.

Car Condition: per-axle percent WEAR_CURVE evaluation at tyreVirtualKM * 10 verified against the installed CMRT source. Cache, compound/car changes, replacement tyres, four-wheel mean, missing data, telemetry clearing and preference migration passed. Grip bar drawings cover below/above endpoints, both themes and three window sizes; selector persists and ignores locked input.

Additional baseline failure: settings.lua rejects Timer's existing local Background opacity control as a duplicate global control. This assertion predates these changes; its Timer-scoped correction is deferred to the Timer commit.
