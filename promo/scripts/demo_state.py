"""Deterministic, fictional trailer inputs; never footage-derived telemetry.

Schedule v1 JSON (times in seconds on the new composition's central clock)::

    {"duration": 38, "fps": 30,
     "keyframes": [{"t": 0, "speedKmh": 155}, {"t": 3, "speedKmh": 210}],
     "shots": [{"id": "braking", "start": 3, "duration": 4,
                "state": {"position": 12},
                "keyframes": [{"t": 0, "gas": 0, "brake": 0},
                              {"t": 1, "brake": 0.9, "speedKmh": 120},
                              {"t": 4, "brake": 0, "gas": 0.8}]}]}

Global keyframe t is absolute; shot keyframe t is relative to shot start.
Each field interpolates independently; gear, lap, position, flags, booleans,
result and lapHistory change only at their explicit keyframe. Controlled fields
hold their last scheduled value; unspecified fields keep the continuous demo.
Shot state/from/to are optional. A list of shots is also accepted. `demo` is an
alias for shot `state`; `states` is an alias for top-level `keyframes`.
`nearbyCars` contains {index, lateral, longitudinal, connected} in metres,
relative to the player (positive lateral is the native radar's right side).
Set nearbyCars=[] when footage shows no nearby car. Default position stays P12,
lap stays 8, timer starts at 70 seconds; no invented pass or best-lap trigger.
Timer result/lapHistory/transitionStartedAt must be explicitly scheduled.
Headlights are owned exclusively by the exporter's --lights-on argument.
"""

from bisect import bisect_right
import json
import math
from pathlib import Path

FPS = 30
DISCRETE = {"gear", "position", "lap", "currentSector", "raceFlagType",
            "result", "lapHistory", "nearbyCars", "transitionStartedAt"}
RESERVED = {"t", "time", "state", "demo"}
FORBIDDEN = {"headlights", "headlightsActive", "lightsOn", "lights_on"}
ALIASES = {"speed": "speedKmh", "throttle": "gas", "steering": "steer",
           "currentLapTime": "currentLapTimeMs", "lapTimeMs": "currentLapTimeMs"}


def blend(before, after, fraction):
    if isinstance(before, bool) or isinstance(after, bool):
        return before
    if isinstance(before, (float, int)) and isinstance(after, (float, int)):
        return before + (after - before) * fraction
    if isinstance(before, dict) and isinstance(after, dict):
        return {key: blend(value, after.get(key, value), fraction)
                for key, value in before.items()}
    return before


def baseline(t):
    """An ongoing demo drive, with no end hold inherited from the old teaser."""
    t = max(0.0, t)
    phase = (t + 2.0) % 11.8
    # Acceleration, a brake application, turn-in, then a progressive exit.
    if phase < 5.8:
        gas, brake, speed = 0.92, 0.0, 116 + phase * 19
    elif phase < 8.1:
        p = (phase - 5.8) / 2.3
        gas, brake, speed = 0.0, math.sin(p * math.pi) * 0.94, 226 - 119 * p
    else:
        p = (phase - 8.1) / 3.7
        gas, brake, speed = 0.2 + p * 0.72, 0.0, 107 + p * 9
    steer = 142 * math.sin((phase - 6.8) / 5 * math.pi) if phase > 6.8 else 0
    if int(t / 11.8) % 2:
        steer = -steer
    gear = 2 if speed < 135 else 3 if speed < 181 else 4
    ratio = {2: 47, 3: 35.5, 4: 29.2}[gear]
    return dict(t=t, speedKmh=speed, rpm=min(7860, speed * ratio + 260),
                gear=gear, gas=gas, brake=brake, clutch=1, steer=steer,
                position=12, lap=8, gap=0.74 + 0.12 * math.sin(t * 0.33),
                delta=0.18 * math.sin(t * 0.26) - 0.035,
                currentLapTimeMs=70000 + t * 1000,
                lapProgress=(70000 + t * 1000) / 132645,
                referenceLapTimeMs=132645, previousLapTimeMs=133210,
                bestLapTimeMs=132645, sessionTimeLeft=820 - t,
                fuel=31.4 - t * 0.018, tyreTemperature=80 + 2.8 * math.sin(t * 0.21),
                tyreWear=0.035 + t * 0.00035,
                rivalX=2.3 + 0.3 * math.sin(t * 0.4),
                rivalZ=-8 + 9 * math.sin(t * 0.29),
                ambientTemperature=23, roadTemperature=29, rainIntensity=0,
                raceFlagType=0, damage={"front": 0, "rear": 0, "left": 0, "right": 0},
                gearboxDamage=0, engineLifeLeft=1000)


def finite_number(value, label):
    if isinstance(value, bool) or not isinstance(value, (float, int)) or not math.isfinite(value):
        raise ValueError(f"{label} must be a finite number")
    return float(value)


class DemoState:
    def __init__(self, duration=36.0, lights_on=26.4, schedule=None):
        self.duration = finite_number(duration, "duration")
        self.lights_on = finite_number(lights_on, "lights-on")
        if self.duration <= 0 or self.lights_on < 0:
            raise ValueError("duration must be positive; lights-on must be nonnegative")
        self.path = Path(schedule).resolve() if schedule else None
        self.document = json.loads(self.path.read_text(encoding="utf-8-sig")) if self.path else {}
        if isinstance(self.document, list):
            self.document = {"shots": self.document}
        if not isinstance(self.document, dict):
            raise ValueError("schedule must be a JSON object or shot list")
        if "duration" in self.document and abs(finite_number(self.document["duration"], "schedule duration") - self.duration) > 1e-6:
            raise ValueError("schedule duration differs from --duration; pass the final duration explicitly")
        if self.document.get("fps", FPS) != FPS:
            raise ValueError("native export requires a 30 fps schedule")
        self.tracks, self.shots = {}, []
        for point in self.document.get("keyframes", self.document.get("states", [])):
            self.add_point(point, 0)
        for index, shot in enumerate(self.document.get("shots", [])):
            start = finite_number(shot.get("start", 0), "shot start")
            length = shot.get("duration")
            if length is None:
                length = finite_number(shot["end"], "shot end") - start
            length = finite_number(length, "shot duration")
            if start < 0 or length <= 0 or start + length > self.duration + 1e-6:
                raise ValueError(f"shot {index} is outside the export duration")
            self.shots.append(dict(id=str(shot.get("id", shot.get("name", index))),
                                   start=start, duration=length))
            state = shot.get("state", shot.get("demo", shot.get("from", {})))
            if state:
                self.add_values(start, state)
            for point in shot.get("keyframes", []):
                local = finite_number(point.get("t", point.get("time", 0)), "shot keyframe t")
                if local < 0 or local > length + 1e-6:
                    raise ValueError("shot keyframe is outside its shot")
                self.add_point(point, start)
            if shot.get("to"):
                self.add_values(start + length, shot["to"])
        # Equal-time anchors are resolved by schedule order (shot overrides global).
        for key, points in self.tracks.items():
            merged = dict(points)
            self.tracks[key] = sorted(merged.items())
        self.times = {key: [t for t, _ in points] for key, points in self.tracks.items()}

    def add_point(self, point, origin):
        if not isinstance(point, dict):
            raise ValueError("keyframes must be objects")
        moment = origin + finite_number(point.get("t", point.get("time", 0)), "keyframe t")
        values = point.get("state", point.get("demo"))
        if values is None:
            values = {key: value for key, value in point.items() if key not in RESERVED}
        self.add_values(moment, values)

    def add_values(self, moment, values):
        if moment < 0 or moment > self.duration + 1e-6:
            raise ValueError("keyframe is outside the export duration")
        if not isinstance(values, dict):
            raise ValueError("scheduled state must be an object")
        for key, value in values.items():
            if key in FORBIDDEN:
                raise ValueError("headlights must be set with --lights-on, not a shot override")
            key = ALIASES.get(key, key)
            if key not in baseline(0) and key not in {
                "nearbyCars", "result", "lapHistory", "transitionStartedAt", "currentSector",
                "ffbFinal", "turboBoost", "tyreTemperatures", "tyreWears", "tyreDirty",
                "speedDelta", "absInAction", "tractionControlInAction", "steerLock",
                "isLapValid", "isInPit", "finalLap", "splits", "personalSectorTimeMs",
                "sessionSectorTimeMs", "turningLeftLights", "turningRightLights", "hazardLights"}:
                raise ValueError(f"unknown demo state field: {key}")
            if isinstance(value, (float, int)) and not isinstance(value, bool):
                finite_number(value, key)
            self.tracks.setdefault(key, []).append((moment, value))

    def sample(self, moment):
        t = finite_number(moment, "sample time")
        state = baseline(t)
        for key, points in self.tracks.items():
            cursor = bisect_right(self.times[key], t) - 1
            if cursor < 0:
                continue
            before_t, value = points[cursor]
            if cursor + 1 < len(points) and key not in DISCRETE:
                after_t, after = points[cursor + 1]
                value = blend(value, after, (t - before_t) / (after_t - before_t))
            state[key] = value
        for key in ("gas", "brake", "clutch"):
            state[key] = max(0, min(1, finite_number(state[key], key)))
        for key in ("speedKmh", "rpm", "fuel", "currentLapTimeMs"):
            state[key] = max(0, finite_number(state[key], key))
        for key in ("gear", "position", "lap"):
            state[key] = int(finite_number(state[key], key))
        if not 1 <= state["position"] <= 16 or state["lap"] < 1:
            raise ValueError("demo position must be 1..16 and lap must be positive")
        if "currentLapTimeMs" in self.tracks and "lapProgress" not in self.tracks:
            state["lapProgress"] = state["currentLapTimeMs"] / state["referenceLapTimeMs"]
        state["lapProgress"] = max(0, min(0.999, state["lapProgress"]))
        nearby = state.get("nearbyCars")
        if nearby is None:
            nearby = [dict(index=1, lateral=state["rivalX"], longitudinal=state["rivalZ"], connected=True)]
        if not isinstance(nearby, list):
            raise ValueError("nearbyCars must be an array")
        for car in nearby:
            finite_number(car["lateral"], "nearby lateral")
            finite_number(car["longitudinal"], "nearby longitudinal")
        state["nearbyCars"] = nearby
        state.update(rpmLimiter=8000, steerLock=state.get("steerLock", 450), maxFuel=50,
                     turboCount=1, turboBoost=state.get("turboBoost", max(0, state["gas"] * 0.86 - state["brake"] * 0.42)),
                     ffbFinal=state.get("ffbFinal", max(-1, min(1, state["steer"] / 180))),
                     tractionControlModes=6, tractionControlMode=2,
                     tractionControlInAction=state.get("tractionControlInAction", state["gas"] > 0.75 and abs(state["steer"]) > 90),
                     absModes=6, absMode=3, absInAction=state.get("absInAction", state["brake"] > 0.8),
                     headlightsActive=t >= self.lights_on, lowBeams=True,
                     turningLeftLights=state.get("turningLeftLights", False),
                     turningRightLights=state.get("turningRightLights", False),
                     hazardLights=state.get("hazardLights", False),
                     physicsAvailable=True, isInPit=state.get("isInPit", False),
                     isLapValid=state.get("isLapValid", True), manualPitsSpeedLimiterEnabled=False)
        state["currentSector"] = state.get("currentSector", min(2, int(state["lapProgress"] * 3)))
        state["t"] = max(0, t)
        state["shot"] = next((s["id"] for s in reversed(self.shots)
                              if s["start"] <= t < s["start"] + s["duration"]), None)
        return state
