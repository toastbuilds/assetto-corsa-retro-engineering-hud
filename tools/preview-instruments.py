"""Export actual Lua drawing calls with the CSP mock (requires lupa and Pillow).

Run from the repository root: python tools/preview-instruments.py
This is a geometry/font preview, not a replacement for CSP antialiasing.
"""
from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageFont
from lupa.lua52 import LuaRuntime

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "output" / "instruments"
FACTOR = 3
FONT = Path("C:/Windows/Fonts/consola.ttf")
if not FONT.exists():
    raise SystemExit("Consolas is required to match the HUD typography")
fonts = {}


def font(size):
    pixels = max(1, round(size * FACTOR))
    if pixels not in fonts:
        fonts[pixels] = ImageFont.truetype(str(FONT), pixels)
    return fonts[pixels]


def raster(calls, width=1440, height=500):
    canvas = Image.new("RGB", (width * FACTOR, height * FACTOR), "#121416")
    draw = ImageDraw.Draw(canvas, "RGBA")
    for _, call in calls.items():
        color = call["color"]
        rgba = tuple(max(0, min(255, round(color[k] * 255))) for k in ("r", "g", "b")) + (
            max(0, min(255, round((color["mult"] or 1) * 255))),
        )
        kind = call["kind"]
        thickness = max(1, round((call["thickness"] or 1) * FACTOR))

        def xy(p):
            return (round(p["x"] * FACTOR), round(p["y"] * FACTOR))

        if kind == "text":
            draw.text(xy(call["a"]), str(call["text"]), font=font(call["size"]), fill=rgba, anchor="lt")
        elif kind in ("circle", "circle_fill", "arc"):
            x, y = xy(call["a"])
            r = call["radius"] * FACTOR
            box = (round(x-r), round(y-r), round(x+r), round(y+r))
            if kind == "arc":
                draw.arc(box, math.degrees(call["startAngle"]), math.degrees(call["endAngle"]),
                         fill=rgba, width=thickness)
            elif kind == "circle_fill":
                draw.ellipse(box, fill=rgba)
            else:
                draw.ellipse(box, outline=rgba, width=thickness)
        elif kind == "line":
            draw.line([xy(call["a"]), xy(call["b"])], fill=rgba, width=thickness)
        elif kind in ("rect", "rect_fill"):
            box = (*xy(call["a"]), *xy(call["b"]))
            radius = (call["rounding"] or 0) * FACTOR
            draw.rounded_rectangle(box, radius=radius, fill=rgba if kind == "rect_fill" else None,
                                   outline=rgba if kind == "rect" else None, width=thickness)
        elif kind in ("polygon", "path"):
            points = [xy(p) for _, p in call["points"].items()]
            if kind == "polygon":
                draw.polygon(points, fill=rgba)
            elif points:
                if call["closed"]:
                    points.append(points[0])
                draw.line(points, fill=rgba, width=thickness, joint="curve")
    return canvas.resize((width, height), Image.Resampling.LANCZOS)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    lua = LuaRuntime(unpack_returned_tuples=True)
    harness = lua.execute((ROOT / "tests/gt7_layouts.lua").read_text(encoding="utf-8"))
    # Record nested alpha and use real Consolas metrics instead of mock metrics.
    lua.execute("""
      local stack, alpha = {}, 1
      local push, pop = ui.pushStyleVarAlpha, ui.popStyleVar
      ui.pushStyleVarAlpha = function(value) stack[#stack + 1] = alpha; alpha = alpha * value; push(value) end
      ui.popStyleVar = function(n)
        for _ = 1, n do alpha = table.remove(stack) end
        pop(n)
      end
      for name, index in pairs({drawLine=3, drawCircle=3, drawCircleFilled=3,
          drawRect=3, drawRectFilled=3, pathFillConvex=1, pathStroke=1, dwriteDrawText=4}) do
        local original = ui[name]
        ui[name] = function(...)
          local args = {...}; local c = args[index]
          args[index] = rgbm(c.r, c.g, c.b, c.mult * alpha)
          original(table.unpack(args))
        end
      end
    """)

    def measure(value, size):
        face = font(size)
        return lua.globals().vec2(face.getlength(str(value)) / FACTOR, size)

    lua.globals().ui.measureDWriteText = measure
    state = harness["state"]
    state["available"], state["maxFuel"], state["rpmText"] = True, 50, "5200"
    state["lightsAvailable"], state["fuelNormalized"] = True, 0.6
    state["rpm"], state["gt7RpmNeedleNormalized"] = 5200, 0.65
    state["rpmGaugeNormalized"] = 0.65
    state["gt7Instruments"] = None
    presentation = lua.eval("require('src/instrument_state')")
    if isinstance(presentation, tuple):
        presentation = presentation[0]
    renders = {}

    def render(name, mode="analog", style="classic", lights=False, theme="dark", frame="classic", window=None, dial_scale=1, spacing=0, indicator_scale=1):
        options = lua.table_from(dict(gt7SpeedNeedleMode=mode, gt7RpmNeedleMode=mode,
            gt7SpeedNeedleStyle=style, gt7RpmNeedleStyle=style, theme=theme, speedUnit="km/h",
            gt7SimulateVacuum=True, gt7VacuumMinimum=-0.5, showLights=True,
            gt7DialScale=dial_scale, gt7DialSpacing=spacing, gt7IndicatorScale=indicator_scale))
        state["headlights"], state["gt7Instruments"] = lights, None
        # Fixtures are settled values; feed the original boost spring's settled
        # fraction too, rather than leaving a hand from a preceding scenario.
        state["boostNeedleNormalized"] = max(0, state["turboBoost"]) / state["turboDisplayMax"]
        presentation.update(state, options, 0)
        for _ in range(90):
            presentation.update(state, options, 1/60)
        size = lua.table_from(window) if window else None
        calls = harness["draw"](frame, options, state, size)
        layout = lua.eval("require('src/gt7_retro_layout')").get(frame)
        picture = raster(calls, *(window or (int(layout["width"]), int(layout["height"]))))
        picture.save(OUTPUT / (name + ".png"))
        renders[name] = picture
        print(f"{name}: {len(calls)} draw calls")
        return picture

    for theme in ("dark", "light"):
        for mode in ("analog", "digital"):
            for lights in (False, True):
                render(f"{mode}-{theme}-{'on' if lights else 'off'}", mode=mode, theme=theme, lights=lights)
    render("large-spaced-dials", dial_scale=1.25, spacing=80)
    render("small-dials", dial_scale=0.75)
    render("outer-large-spaced", frame="outer_pedals", dial_scale=1.25, spacing=160)
    render("large-lower-indicators", indicator_scale=1.5)
    # Full-size dials in a separate sheet avoid confusing overview scale.
    sheet = Image.new("RGB", (1050, 1180), "#121416")
    styles = lua.eval("require('src/instrument_config').needleOrder")
    for i, (_, style) in enumerate(styles.items()):
        picture = render("needle-" + style, style=style)
        dial = picture.crop((0, 78, 350, 433))
        x, y = (i % 3) * 350, (i // 3) * 390
        sheet.paste(dial, (x, y))
        ImageDraw.Draw(sheet).text((x+12, y+357), style.upper(), font=ImageFont.truetype(str(FONT), 18), fill="#f2dbae")
    sheet.save(OUTPUT / "needle-styles.png")
    # Four lighting/mode combinations, pair of dials at actual design size.
    pairs = Image.new("RGB", (1440, 760), "#121416")
    draw = ImageDraw.Draw(pairs)
    for i, name in enumerate(("analog-dark-off", "analog-dark-on", "digital-dark-off", "digital-dark-on")):
        x, y = (i % 2) * 720, (i // 2) * 380
        pairs.paste(renders[name].crop((0, 78, 350, 433)), (x, y+25))
        pairs.paste(renders[name].crop((1090, 78, 1440, 433)), (x+360, y+25))
        draw.text((x+14, y+3), name.upper(), font=ImageFont.truetype(str(FONT), 17), fill="#f2dbae")
    pairs.save(OUTPUT / "modes-and-lights.png")
    state["turboBoost"], state["throttle"] = 0, 0
    render("vacuum-analog", lights=True)
    render("vacuum-digital", mode="digital", lights=True)
    state["fuelNormalized"] = 0.1
    state["rpmText"], state["rpm"], state["rpmGaugeNormalized"] = "7800", 7800, 0.975
    state["gt7RpmNeedleNormalized"], state["rpmRedline"], state["rpmWarning"] = 0.975, True, True
    render("reserve-redline-analog", lights=True)
    render("reserve-redline", mode="digital", lights=True)
    render("actual-size-720", mode="digital", lights=True, window=(720, 360))


if __name__ == "__main__":
    main()
