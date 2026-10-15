"""Run CSP regression suites in isolated Lua 5.2 runtimes (requires Lupa)."""
from pathlib import Path
import os
import argparse

from lupa.lua52 import LuaRuntime


def main():
    root = Path(__file__).resolve().parent.parent
    os.chdir(root)
    parser = argparse.ArgumentParser()
    parser.add_argument("--suite", action="append")
    args = parser.parse_args()
    syntax = LuaRuntime()
    for folder in ("modules", "src", "ui"):
        for path in (root / folder).rglob("*.lua"):
            syntax.execute("assert(load(...))", path.read_text(encoding="utf-8-sig"))
    print("Lua syntax passed", flush=True)
    if args.suite:
        for suite in args.suite:
            print(f"Running {suite}", flush=True)
            runtime = LuaRuntime()
            runtime.execute((root / suite).read_text(encoding="utf-8-sig"))
        return
    suites = [
        "tests/notices.lua",
        "tests/overtake.lua",
        "tests/leaderboard.lua",
        "tests/leaderboard_data.lua",
        "tests/leaderboard_sectors.lua",
        "tests/leaderboard_intervals.lua",
        "tests/map.lua",
        "tests/window_anchor.lua",
        "tests/runtime_smoke.lua",
        "tests/relative.lua",
        "tests/car_condition.lua",
        "tests/tyre_readouts.lua",
        "tests/tyre_condition_data.lua",
        "tests/tyre_stint.lua",
        "tests/tyre_temperature.lua",
        "tests/tyre_grip.lua",
        "tests/timer_final_lap.lua",
        "tests/dial_electronics.lua",
        "tests/dial_variants.lua",
        "tests/digital_variants.lua",
        "tests/gear_selector.lua",
        "tests/halo_dials.lua",
        "tests/instrument_illumination.lua",
        "tests/gt7_dial_styles.lua",
        "tests/gt7_auxiliary_styles.lua",
        "tests/hybrid_instruments.lua",
        "tests/hybrid_regeneration.lua",
    ]
    for suite in suites:
        print(f"Running {suite}", flush=True)
        LuaRuntime().execute((root / suite).read_text(encoding="utf-8-sig"))
    for suite in ("tests/timing_apps.lua", "tests/settings.lua"):
        print(f"Running {suite}", flush=True)
        LuaRuntime().execute((root / suite).read_text(encoding="utf-8-sig"))



if __name__ == "__main__":
    main()
