# HUD validation

Baseline (2026-10-03): all suites before timing passed. Timing failed in Timer display because the vector test double lacks unary negation; correction deferred to Timer commit.

Leaderboard: leader/session reference, countdown milliseconds including zero/negative, fixed distance, fuel reset and missing references passed. Eight drawing traces cover both themes, flag modes and scale limits. Lua syntax checked. These are CSP drawing doubles; live gameplay has not been observed.

Relatives: 96 panel drawing cases, 32 measured-column cases, long UTF-8 names, indicators, option combinations and measured vertical centers passed. Seven rows retained at the default window size. Record values use 24 units in 52-unit panels.
