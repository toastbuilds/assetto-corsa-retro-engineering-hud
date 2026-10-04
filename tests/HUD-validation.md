# HUD validation

Baseline (2026-10-03): all suites before timing passed. Timing failed in Timer display because the vector test double lacks scalar multiplication; correction deferred to Timer commit.

Leaderboard: leader/session reference, countdown milliseconds including zero/negative, fixed distance, fuel reset and missing references passed. Eight drawing traces cover both themes, flag modes and scale limits. Lua syntax checked. These are CSP drawing doubles; live gameplay has not been observed.

Relatives: 96 panel drawing cases, 32 measured-column cases, long UTF-8 names, indicators, option combinations and measured vertical centers passed. Seven rows retained at the default window size. Record values use 24 units in 52-unit panels.

Car Condition: per-axle percent WEAR_CURVE evaluation at tyreVirtualKM * 10 verified against the installed CMRT source. Cache, compound/car changes, replacement tyres, four-wheel mean, missing data, telemetry clearing and preference migration passed. Grip bar drawings cover below/above endpoints, both themes and three window sizes; selector persists and ignores locked input.

Additional baseline failure: settings.lua rejects Timer's existing local Background opacity control as a duplicate global control. This assertion predates these changes; its Timer-scoped correction is deferred to the Timer commit.

Laps: Premium and Free passed 24 drawing cases each plus full/hidden history, limits 1/2/5/10, and lap transitions. CSP SDK documents endGradientShade(useAlpha=true) as multiplying existing alpha; white RGB endpoints preserve colors, from 100% to 20% on only the final visible historical row.

Timer: fixed/timed races, extra/no-extra lap, official flag priority, missing flag, millisecond countdown through zero, finish, leader changes, restart and replay rewind passed. Staggered counter/spline updates cannot count a pre-expiration crossing twice. Both themes pass 48 Timer drawings per edition, including FINAL LAP, BEST, delta and pit marker; opacity checks pass.

Timer test repairs: scalar vector multiplication for outlined text; count foreground delta labels separately from outline strokes; retain the authored neutral invalid-delta color and measured fit; preview failure double targets playLapCompleted; settings permit Timer's existing local plate opacity and seed telemetry before window checks. Production drawing, audio and opacity behavior are retained.

All Lua syntax and regression suites passed for Premium and Free. Each app is deployed independently with a dated full previous-RetroUI backup and SHA-256 verification of every copied file. No live Assetto Corsa gameplay validation was performed.
