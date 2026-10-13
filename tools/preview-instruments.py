"""Export actual Lua drawing calls with the CSP mock (requires lupa and Pillow).

Run from the repository root: python tools/preview-instruments.py
This is a geometry/font preview, not a replacement for CSP antialiasing.
"""
from pathlib import Path
import argparse
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
glyphs = {}
images = {}


def font(size, bold=False):
    pixels = max(1, round(size * FACTOR))
    key = (pixels,bold)
    if key not in fonts:
        fonts[key] = ImageFont.truetype(str(FONT.with_name('consolab.ttf') if bold else FONT), pixels)
    return fonts[key]


def raster(calls, width=1440, height=500, background="#121416"):
    canvas = Image.new("RGB", (width * FACTOR, height * FACTOR), background)
    draw = ImageDraw.Draw(canvas, "RGBA")
    clips = []
    for _, call in calls.items():
        if call["kind"] == "clip_push":
            bounds = tuple(round(call[key][axis] * FACTOR) for key in ("a", "b") for axis in ("x", "y"))
            clips.append((canvas.copy(), bounds))
            continue
        if call["kind"] == "clip_pop":
            base, bounds = clips.pop()
            base.paste(canvas.crop(bounds), bounds[:2])
            canvas = base
            draw = ImageDraw.Draw(canvas, "RGBA")
            continue
        color = call["color"]
        rgba = tuple(max(0, min(255, round(color[k] * 255))) for k in ("r", "g", "b")) + (
            max(0, min(255, round((color["mult"] or 1) * 255))),
        )
        kind = call["kind"]
        thickness = max(1, round((call["thickness"] or 1) * FACTOR))

        def xy(p):
            return (round(p["x"] * FACTOR), round(p["y"] * FACTOR))

        if kind == "image":
            name = call["image"]
            if name not in images:
                images[name] = Image.open(ROOT / name).convert('RGBA')
            a, b = xy(call['a']), xy(call['b'])
            tile = images[name].resize((max(1,b[0]-a[0]),max(1,b[1]-a[1])),Image.Resampling.LANCZOS)
            tile.putalpha(tile.getchannel('A').point(lambda value: round(value*rgba[3]/255)))
            canvas.paste(tile,a,tile)
        elif kind == "text":
            # Pillow's RGB ImageDraw.text ignores fill alpha even in RGBA mode.
            # Composite a glyph tile explicitly so low-opacity emission stays
            # subtle, rather than making the review falsely look bold.
            bold = 'Bold' in str(call['font'] or '')
            key = (str(call["text"]), call["size"], rgba, bold)
            if key not in glyphs:
                face = font(call["size"],bold)
                # DWrite positions the font line box, not the visible glyph top.
                # Preserve the ascender bearing so previews do not encourage
                # offsets that move numerals below their centers in-game.
                left, top, right, bottom = face.getbbox(key[0], anchor="la")
                tile = Image.new("RGBA", (max(1, right-left), max(1, bottom-top)))
                ImageDraw.Draw(tile).text((-left, -top), key[0], font=face, fill=rgba, anchor="la")
                glyphs[key] = tile, left, top
            tile, left, top = glyphs[key]
            x, y = xy(call["a"])
            canvas.paste(tile, (x+left, y+top), tile)
        elif kind in ("circle", "circle_fill", "arc"):
            x, y = xy(call["a"])
            r = call["radius"] * FACTOR
            # CSP centers strokes on the path; Pillow strokes inside the box.
            if kind != "circle_fill":
                r += thickness / 2
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


def without_outer_ring(calls, layout):
    """Remove only bezel circles and the backlight arc, in the design-size review.

    This is a preview filter, never an option or geometry change in the HUD.
    """
    keep = {}
    for _, call in calls.items():
        p = call["a"]
        at_dial = p and abs(p["y"] - layout["dialCenterY"]) < 0.001 and any(
            abs(p["x"] - layout[key]) < 0.001 for key in ("leftCenterX", "rightCenterX"))
        rim = at_dial and ((call["kind"] == "circle" and call["radius"] >= layout["dialRadius"] - 16)
                          or (call["kind"] == "arc" and abs(call["radius"] - 154) < 0.001))
        if not rim:
            keep[len(keep) + 1] = call
    return keep


def create_harness():
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
      local fontStack = {}
      local pushFont,popFont = ui.pushDWriteFont,ui.popDWriteFont
      ui.pushDWriteFont = function(desc)
        fontStack[#fontStack+1] = desc; previewFont = desc; pushFont(desc)
      end
      ui.popDWriteFont = function()
        table.remove(fontStack); previewFont = fontStack[#fontStack]; popFont()
      end
      for name, index in pairs({drawLine=3, drawCircle=3, drawCircleFilled=3,
          drawRect=3, drawRectFilled=3, pathFillConvex=1, pathStroke=1, dwriteDrawText=4, drawImage=4}) do
        local original = ui[name]
        ui[name] = function(...)
          local args = {...}; local c = args[index]
          args[index] = rgbm(c.r, c.g, c.b, c.mult * alpha)
          original(table.unpack(args))
        end
      end
    """)

    def measure(value, size):
        face = font(size,'Bold' in str(lua.globals().previewFont or ''))
        return lua.globals().vec2(face.getlength(str(value)) / FACTOR, size)

    lua.globals().ui.measureDWriteText = measure
    return lua, harness


def main(hybrid=False, styles_only=False, auxiliary_only=False):
    OUTPUT.mkdir(parents=True, exist_ok=True)
    lua, harness = create_harness()
    state = harness["state"]
    state["available"], state["maxFuel"], state["rpmText"] = True, 50, "5200"
    state["lightsAvailable"], state["fuelNormalized"] = True, 0.6
    state["rpm"], state["gt7RpmNeedleNormalized"] = 5200, 0.65
    state["rpmGaugeNormalized"] = 0.65
    state["speedValue"], state["speedText"], state["gt7SpeedNeedleNormalized"] = 139, "139", 139 / 320
    state["fuel"], state["turboBoost"], state["turboAvailable"] = 30, 0.7, True
    state["rpmWarning"], state["rpmRedline"] = False, False
    state["gt7Instruments"] = None
    presentation = lua.eval("require('src/instrument_state')")
    if isinstance(presentation, tuple):
        presentation = presentation[0]
    renders = {}

    def render(name, mode="analog", style="b01", lights=False, theme="dark", frame="classic", window=None, dial_scale=1, spacing=0, indicator_scale=1, no_ring=False,
               speed_dial_style="original", rpm_dial_style="original", auxiliary_style="original"):
        options = lua.table_from(dict(gt7SpeedNeedleMode=mode, gt7RpmNeedleMode=mode,
            gt7SpeedNeedleStyle=style, gt7RpmNeedleStyle=style,
            gt7SpeedDialStyle=speed_dial_style, gt7RpmDialStyle=rpm_dial_style,
            gt7SpeedAuxiliaryStyle=auxiliary_style, gt7RpmAuxiliaryStyle=auxiliary_style,
            theme=theme, speedUnit="km/h",
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
        if no_ring:
            calls = without_outer_ring(calls, layout)
        picture = raster(calls, *(window or (int(layout["width"]), int(layout["height"]))))
        picture.save(OUTPUT / (name + ".png"))
        renders[name] = picture
        print(f"{name}: {len(calls)} draw calls")
        return picture

    if auxiliary_only:
        caption = ImageFont.truetype(str(FONT), 15)
        for theme in ("dark", "light"):
            for mode in ("analog", "digital"):
                for geometry in ("mini", "rim"):
                    main_style = "original" if geometry == "mini" else (
                        "track_analog" if mode == "analog" else "orbit")
                    sheet = Image.new("RGB", (1200, 1280), "#121416")
                    for row, channel in enumerate(("Fuel", "Turbo", "Aero", "Hybrid")):
                        state["turboAvailable"] = channel != "Aero"
                        state["aeroLoadNormalized"] = 0.68
                        state["hybrid"] = lua.table_from(dict(powerKw=120, needle=0.8, charge=0.84)) if channel == "Hybrid" else None
                        for col, auxiliary in enumerate(("original", "halo", "jewel", "spectrum")):
                            picture = render("auxiliary-review", mode=mode, lights=True, theme=theme,
                                speed_dial_style=main_style, rpm_dial_style=main_style, auxiliary_style=auxiliary)
                            bounds = (0, 78, 350, 433) if channel == "Fuel" else (1090, 78, 1440, 433)
                            crop = picture.crop(bounds).resize((280, 280), Image.Resampling.LANCZOS)
                            sheet.paste(crop, (col * 300 + 10, row * 320))
                            ImageDraw.Draw(sheet).text((col * 300 + 12, row * 320 + 284),
                                f"{channel} / {auxiliary.title()}", font=caption, fill="#f2dbae")
                    suffix = "-light" if theme == "light" else ""
                    sheet.save(OUTPUT / f"gt7-auxiliary-{geometry}-{mode}{suffix}.png")
        state["hybrid"], state["turboAvailable"] = None, True
        matching = Image.new("RGB", (1800, 660), "#121416")
        for row, mode in enumerate(("analog", "digital")):
            for col, motif in enumerate(("halo", "jewel", "spectrum")):
                picture = render(f"gt7-auxiliary-match-{motif}-{mode}", mode=mode, lights=True,
                    speed_dial_style=f"{motif}_{mode}", rpm_dial_style=f"{motif}_{mode}", auxiliary_style="match")
                for role, bounds in enumerate(((0, 78, 350, 433), (1090, 78, 1440, 433))):
                    matching.paste(picture.crop(bounds).resize((280, 280), Image.Resampling.LANCZOS),
                                   (col * 600 + role * 300 + 10, row * 330))
                ImageDraw.Draw(matching).text((col * 600 + 12, row * 330 + 284),
                    f"{motif.title()} {mode} / Match main dial", font=caption, fill="#f2dbae")
        matching.save(OUTPUT / "gt7-auxiliary-matching.png")
        alerts = Image.new("RGB", (1200, 1280), "#121416")
        scenarios = ("Fuel 8% / ON", "Fuel 8% / OFF", "Battery 8%", "Fuel unavailable")
        for row, label in enumerate(scenarios):
            state["clock"] = 0.3 if row == 1 else 0
            state["fuel"], state["maxFuel"] = (None, None) if row == 3 else (4, 50)
            state["fuelNormalized"] = 0.08
            state["hybrid"] = lua.table_from(dict(powerKw=120, needle=0.8, charge=0.08)) if row == 2 else None
            for col, auxiliary in enumerate(("original", "halo", "jewel", "spectrum")):
                picture = render("auxiliary-alert-review", mode="digital", lights=True, auxiliary_style=auxiliary)
                bounds = (1090, 78, 1440, 433) if row == 2 else (0, 78, 350, 433)
                alerts.paste(picture.crop(bounds).resize((280, 280), Image.Resampling.LANCZOS),
                             (col * 300 + 10, row * 320))
                ImageDraw.Draw(alerts).text((col * 300 + 12, row * 320 + 284),
                    f"{label} / {auxiliary.title()}", font=caption, fill="#f2dbae")
        alerts.save(OUTPUT / "gt7-auxiliary-alerts.png")
        return

    if hybrid:
        state["turboAvailable"] = False
        state["analogNeedleNormalized"] = 0.65
        state["hybrid"] = lua.table_from(dict(powerKw=120, needle=0.8, charge=0.84))
        sheet = Image.new("RGB", (1320, 650), "#121416")
        for row, theme in enumerate(("dark", "light")):
            state["headlights"] = True
            options = lua.table_from(dict(analogNeedleStyle="a02", theme=theme, hudScale=1))
            calls = harness["drawDial"](options, state, lua.table_from((620, 620)))
            picture = raster(calls, 620, 620)
            picture.save(OUTPUT / f"hybrid-standalone-{theme}.png")
            sheet.paste(picture.resize((320,320),Image.Resampling.LANCZOS), (0,row*325))
            for column, mode in enumerate(("analog", "digital")):
                picture = render(f"hybrid-gt7-{mode}-{theme}", mode=mode, lights=True, theme=theme)
                sheet.paste(picture.crop((1090,78,1440,433)).resize((320,320),Image.Resampling.LANCZOS),
                            (330+column*330,row*325))
            state["hybrid"]["powerKw"], state["hybrid"]["needle"] = -80,-0.8
            picture = render(f"hybrid-gt7-recovery-{theme}", lights=True, theme=theme)
            sheet.paste(picture.crop((1090,78,1440,433)).resize((320,320),Image.Resampling.LANCZOS),
                        (990,row*325))
            state["hybrid"]["powerKw"], state["hybrid"]["needle"] = 120,0.8
        sheet.save(OUTPUT / "hybrid-comparison.png")
        return

    dial_style_module = lua.eval("require('src/gt7_dial_styles')")
    for mode, theme in ((mode, theme) for mode in ("analog", "digital") for theme in ("dark", "light")):
        label_face = ImageFont.truetype(str(FONT), 15)
        for role in ("speed", "rpm"):
            choices = dial_style_module.choices(mode, role)
            choices = [choices[i] for i in range(1, len(choices) + 1)]
            columns, cell_w, cell_h = 4, 300, 310
            rows = math.ceil(len(choices) / columns)
            sheet = Image.new("RGB", (columns * cell_w, rows * cell_h), "#121416")
            for index, item in enumerate(choices):
                style_id = item["value"]
                x, y = (index % columns) * cell_w, (index // columns) * cell_h
                if role == "speed":
                    picture = render("style-review", mode=mode, lights=True, theme=theme,
                        speed_dial_style=style_id, rpm_dial_style="original")
                    crop = picture.crop((0, 78, 350, 433))
                else:
                    picture = render("style-review", mode=mode, lights=True, theme=theme,
                        speed_dial_style="original", rpm_dial_style=style_id)
                    crop = picture.crop((1090, 78, 1440, 433))
                sheet.paste(crop.resize((280, 280), Image.Resampling.LANCZOS), (x+10, y))
                ImageDraw.Draw(sheet).text((x+12, y+282), item["label"], font=label_face, fill="#f2dbae")
            suffix = "-light" if theme == "light" else ""
            sheet.save(OUTPUT / f"gt7-{role}-style-{mode}{suffix}.png")
    if styles_only:
        render("gt7-mixed-analog", speed_dial_style="shelf", rpm_dial_style="spoke", lights=True)
        render("gt7-mixed-digital", mode="digital", speed_dial_style="offset", rpm_dial_style="orbit", lights=True)
        state["fuelNormalized"], state["fuel"], state["clock"] = 0.08, 4, 0
        render("gt7-orbit-low-fuel", mode="digital", speed_dial_style="orbit", lights=True)
        state["clock"] = 0.3
        render("gt7-orbit-low-fuel-blink", mode="digital", speed_dial_style="orbit", lights=True)
        state["fuelNormalized"], state["fuel"] = 0.6, 30
        state["hybrid"] = lua.table_from(dict(powerKw=120, needle=0.8, charge=0.84))
        render("gt7-orbit-hybrid", mode="digital", speed_dial_style="orbit", rpm_dial_style="orbit", lights=True)
        state["hybrid"] = None
        state["rpmText"], state["rpm"], state["rpmGaugeNormalized"] = "7800", 7800, 0.98
        state["gt7RpmNeedleNormalized"], state["rpmRedline"], state["rpmWarning"] = 0.98, True, True
        warning_sheet = Image.new("RGB", (1200, 1280), "#121416")
        warning_font = ImageFont.truetype(str(FONT), 15)
        for row, (mode, phase) in enumerate((("analog", 0), ("analog", 0.13),
                                            ("digital", 0), ("digital", 0.13))):
            state["clock"] = phase
            for column, motif in enumerate(("halo", "jewel", "spectrum", "snap")):
                picture = render(f"gt7-{motif}-{mode}-redline-{row % 2}", mode=mode,
                                 rpm_dial_style=f"{motif}_{mode}", lights=True)
                crop = picture.crop((1090, 78, 1440, 433))
                warning_sheet.paste(crop.resize((280, 280), Image.Resampling.LANCZOS),
                                    (column * 300 + 10, row * 320))
                ImageDraw.Draw(warning_sheet).text((column * 300 + 12, row * 320 + 284),
                    f"{motif.title()} {mode} / {phase:.2f}s", font=warning_font, fill="#f2dbae")
        warning_sheet.save(OUTPUT / "gt7-inspired-redline-comparison.png")
        return

    for theme in ("dark", "light"):
        for mode in ("analog", "digital"):
            for lights in (False, True):
                render(f"{mode}-{theme}-{'on' if lights else 'off'}", mode=mode, theme=theme, lights=lights)
                render(f"{mode}-{theme}-{'on' if lights else 'off'}-no-ring",
                       mode=mode, theme=theme, lights=lights, no_ring=True)
    render("large-spaced-dials", dial_scale=1.25, spacing=80)
    render("small-dials", dial_scale=0.75)
    render("outer-large-spaced", frame="outer_pedals", dial_scale=1.25, spacing=160)
    render("large-lower-indicators", indicator_scale=1.5)
    # Full-size dials in a separate sheet avoid confusing overview scale.
    styles = lua.eval("require('src/instrument_config').needleOrder")
    names = lua.eval("require('src/instrument_config').needleNames")
    style_ids = [styles[i] for i in range(1, len(styles) + 1)]
    columns, cell_w, cell_h = 6, 350, 405
    sheet = Image.new("RGB", (columns * cell_w, math.ceil(len(style_ids) / columns) * cell_h), "#121416")
    lit_sheet = Image.new("RGB", sheet.size, "#121416")
    standalone = Image.new("RGB", (columns * cell_w, math.ceil(len(style_ids) / columns) * cell_h), "#121416")
    details = Image.new("RGB", (columns * 480, math.ceil(len(style_ids) / columns) * 250), "#121416")
    label_font = ImageFont.truetype(str(FONT), 15)
    for i, style in enumerate(style_ids):
        picture = render("needle-" + style, style=style)
        dial = picture.crop((0, 78, 350, 433))
        x, y = (i % columns) * cell_w, (i // columns) * cell_h
        sheet.paste(dial, (x, y))
        ImageDraw.Draw(sheet).text((x+8, y+361), names[style], font=label_font, fill="#f2dbae")
        lit_picture = render("needle-" + style + "-on", style=style, lights=True)
        lit_sheet.paste(lit_picture.crop((0, 78, 350, 433)), (x, y))
        ImageDraw.Draw(lit_sheet).text((x+8, y+361), names[style], font=label_font, fill="#f2dbae")
        state["headlights"] = False  # Standalone previews keep their original OFF fixture.
        state["analogNeedleNormalized"] = 0.65
        options = lua.table_from(dict(analogNeedleStyle=style, theme="dark", hudScale=1))
        calls = harness["drawDial"](options, state, lua.table_from((620, 620)))
        picture = raster(calls, 620, 620)
        picture.save(OUTPUT / ("standalone-" + style + ".png"))
        standalone.paste(picture.resize((350, 350), Image.Resampling.LANCZOS), (x, y))
        ImageDraw.Draw(standalone).text((x+8, y+361), names[style], font=label_font, fill="#f2dbae")
        preset = lua.eval("require('src/instrument_config').needles")[style]
        palette = lua.eval("require('src/theme').get('dark')")
        center = lua.globals().vec2(140, 115)
        calls = harness["drawNeedle"](center, 2.7, -0.25, preset, palette, 0, None)
        detail = raster(calls, 480, 225)
        dx, dy = (i % columns) * 480, (i // columns) * 250
        details.paste(detail, (dx, dy))
        ImageDraw.Draw(details).text((dx+8, dy+225), names[style], font=label_font, fill="#f2dbae")
    sheet.save(OUTPUT / "needle-styles.png")
    lit_sheet.save(OUTPUT / "needle-styles-on.png")
    standalone.save(OUTPUT / "standalone-needle-styles.png")
    details.save(OUTPUT / "needle-details.png")
    for theme in ("dark", "light"):
        for lights in (False, True):
            state["headlights"] = lights
            options = lua.table_from(dict(analogNeedleStyle="c03", theme=theme, hudScale=1))
            calls = harness["drawDial"](options, state, lua.table_from((620, 620)))
            raster(calls, 620, 620).save(OUTPUT / f"standalone-{theme}-{'on' if lights else 'off'}.png")
    # Four lighting/mode combinations, pair of dials at actual design size.
    for theme in ("dark", "light"):
        for suffix in ("", "-no-ring"):
            pairs = Image.new("RGB", (1440, 760), "#121416")
            draw = ImageDraw.Draw(pairs)
            for i, name in enumerate((f"analog-{theme}-off", f"analog-{theme}-on",
                                      f"digital-{theme}-off", f"digital-{theme}-on")):
                name += suffix
                x, y = (i % 2) * 720, (i // 2) * 380
                pairs.paste(renders[name].crop((0, 78, 350, 433)), (x, y+25))
                pairs.paste(renders[name].crop((1090, 78, 1440, 433)), (x+360, y+25))
                draw.text((x+14, y+3), name.upper(), font=ImageFont.truetype(str(FONT), 17), fill="#f2dbae")
            filename = "modes-and-lights" + ("-light" if theme == "light" else "") + suffix + ".png"
            pairs.save(OUTPUT / filename)
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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--hybrid", action="store_true", help="Preview the Triptych electric instruments only")
    parser.add_argument("--styles-only", action="store_true", help="Preview GT7 speed and RPM face compositions only")
    parser.add_argument("--auxiliary-only", action="store_true", help="Compare GT7 auxiliary styles, channels, geometries and themes")
    args = parser.parse_args()
    OUTPUT = args.output
    main(hybrid=args.hybrid, styles_only=args.styles_only, auxiliary_only=args.auxiliary_only)
