"""Run CSP regression suites in isolated Lua 5.2 runtimes (requires Lupa)."""
from pathlib import Path
import os

from lupa.lua52 import LuaRuntime


def main():
    root = Path(__file__).resolve().parent.parent
    os.chdir(root)
    suites = [
        "tests/runtime_smoke.lua",
        "tests/relative.lua",
        "tests/car_condition.lua",
        "tests/tyre_temperature.lua",
        "tests/instrument_illumination.lua",
    ]
    for suite in suites:
        print(f"Running {suite}", flush=True)
        LuaRuntime().execute((root / suite).read_text(encoding="utf-8-sig"))
    for edition in ("premium", "free"):
        print(f"Running tests/timing_apps.lua ({edition})", flush=True)
        timing_runtime = LuaRuntime()
        timing_runtime.globals().TEST_EDITION = edition
        timing_runtime.execute((root / "tests/timing_apps.lua").read_text(encoding="utf-8-sig"))
        runtime = LuaRuntime()
        runtime.globals().TEST_EDITION = edition
        runtime.execute((root / "tests/settings.lua").read_text(encoding="utf-8-sig"))


if __name__ == "__main__":
    main()
