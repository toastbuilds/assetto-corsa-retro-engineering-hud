"""Render the actual Condition Lua renderer using the existing CSP drawing doubles.

This checks geometry and Consolas metrics, not in-game antialiasing or telemetry.
Run from the repository root: python tools/preview-race-info.py
"""
import importlib.util
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("instruments_preview", ROOT / "tools/preview-instruments.py")
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)


def main():
    output = ROOT / "output/race-info"
    output.mkdir(parents=True, exist_ok=True)
    lua = preview.LuaRuntime(unpack_returned_tuples=True)
    # The GT7 fixture checks mirrored GT7 winding. Condition's authored body
    # contains convex paths in either direction; retain the nonzero-area check.
    fixture = (ROOT / 'tests/gt7_layouts.lua').read_text(encoding='utf-8-sig')
    fixture = fixture.replace('assert(area > 0,', 'assert(math.abs(area) > 0,')
    harness = lua.execute(fixture)
    def measure(value, size):
        face = preview.font(size)
        return lua.globals().vec2(face.getlength(str(value)) / preview.FACTOR, size)
    lua.globals().ui.measureDWriteText = measure
    lua.execute("""
      ui.windowPos = function() return vec2(400, 700) end
      ui.drawTriangleFilled = function(a,b,c,color)
        ui.pathClear(); ui.pathLineTo(a); ui.pathLineTo(b); ui.pathLineTo(c); ui.pathFillConvex(color)
      end
      ac.getUI = function() return {windowSize=vec2(1920,1080)} end
      ui.transparentWindow = function(id, position, size, noPadding, inputs, content)
        _detail = {content=content, size=size}
      end
      ui.drawRectFilledMultiColor = function(a,b,left,right)
        for i=0,15 do
          local t=(i+0.5)/16
          ui.drawRectFilled(vec2(a.x+(b.x-a.x)*i/16,a.y),vec2(a.x+(b.x-a.x)*(i+1)/16,b.y),
            rgbm(left.r+(right.r-left.r)*t,left.g+(right.g-left.g)*t,
              left.b+(right.b-left.b)*t,left.mult+(right.mult-left.mult)*t))
        end
      end
      previewState = {clock=0, condition={available=true,body={},engineDamage=0,gearboxDamage=0,
        compound='Medium',isGT3=true,stint={laps=8,km=45.2,approximate=false,observedOnly=false},wheels={},
        gripDetails={average=98,remaining=65,compound='Medium',progressThresholds={HIGH=75,MEDIUM=50,LOW=25,EOL=0},
          details={{name='HIGH',km=20,laps=4},{name='MEDIUM',km=40,laps=8},
            {name='LOW',km=60,laps=12},{name='EOL',km=80,laps=16}}}}}
      for i=1,4 do
        previewState.condition.wheels[i]={available=true,wearAvailable=true,remaining=1-i*0.06,
          pressure=26.4+i*0.2,idealPressure=26.5,temperatureCore=77+i*2,
          temperatureInside=70+i,temperatureMiddle=78+i,temperatureOutside=73+i,
          optimumTemperatureMin=75,optimumTemperatureMax=85}
      end
      detailRenderer={draw=function()
        ui.pushDWriteFont(require('src/theme').fonts.utility)
        _detail.content()
        ui.popDWriteFont()
      end}
    """)
    renderer = lua.eval("require('ui/car_condition')")
    state = lua.globals().previewState
    for theme in ("dark", "light"):
        background = "#121416" if theme == "dark" else "#e9e4d9"
        images = []
        for metric in ("life", "pressure", "temperature"):
            settings = lua.table_from({"theme": theme, "opacity": 1, "backgroundOpacity": 0.72,
                "numericMetric": metric, "pressureUnit": "psi", "temperatureUnit": "C",
                "temperatureReadout": "core", "legendMode": "temperature"})
            calls = harness["drawRenderer"](renderer, state, settings, lua.table_from([320, 280]))
            images.append((metric.upper(), preview.raster(calls, 320, 280, background)))
        settings["keepDetailsOpen"] = True
        harness["drawRenderer"](renderer, state, settings, lua.table_from([320, 280]))
        size = lua.globals()._detail["size"]
        calls = harness["drawRenderer"](lua.globals().detailRenderer, state, settings,
            lua.table_from([size["x"], size["y"]]))
        detail = preview.raster(calls, round(size["x"]), round(size["y"]), background)
        images.append(("DETAIL", detail))
        canvas = Image.new("RGB", (1324, 492), background)
        draw = ImageDraw.Draw(canvas)
        x = 12
        for label, image in images:
            draw.text((x + 8, 8), label, fill="#f2dbae" if theme == "dark" else "#2e2b26")
            canvas.paste(image, (x, 32))
            x += image.width + 12
        path = output / f"condition-{theme}.png"
        canvas.save(path)
        print(path)
    lua.execute("""
      ac.SessionType = {Race=1}
      ui.time = function() return 100 end
      ui.pushClipRect=function() end; ui.popClipRect=function() end
      leaderboardRenderer={draw=function(snapshot,settings)
        require('modules/leaderboard/ui/leaderboard').draw(snapshot,settings,
          {palette=require('modules/leaderboard/src/theme').get(settings.theme),instrumentOpacity=1})
      end}
      leaderboardSnapshot={header={typeLabel='PRAC',timeText='12:34',lapsText='BEST 1:30.000'},
        enteredAt=0,sessionBest=90000,shownRows={},timeline={time=100},
        fuel={available=true,fuelText='30.0 L',averageText='3.0 L/LAP',estimatedLapsText='9 LAPS'}}
      local names={'ALVAREZ','MARTIN','PLAYER','SILVA','ANDERSEN'}
      for i=1,5 do
        leaderboardSnapshot.shownRows[i]={index=i-1,isLocal=i==3,position=i,driver=names[i],classID='GT3',
          tyreCompound='M',status=i==2 and 'PIT' or 'LIVE',bestLapTimeMs=90000+(i-1)*250,
          lastLapTimeMs=90250+(i-1)*200,interval=i==3 and '0.0s' or string.format('%+.1fs',(i-3)*0.8),
          sectorCount=3,sectorReferenceLabel='GENERAL',balanceLabel='START',lapPositionDelta=i-3,
          positionChangeDelta=i-3,positionChangeUntil=120,
          sectors={{role='PURPLE',active=false},{role='GREEN',active=false},{role='AMBER',active=true}}}
      end
    """)
    for theme in ("dark", "light"):
        background = "#121416" if theme == "dark" else "#e9e4d9"
        settings = lua.table_from({"theme": theme, "maxRows": 5, "hudScale": 0.84,
            "showFlags": False, "showClass": True, "showCompound": True})
        snapshot = lua.globals().leaderboardSnapshot
        canvas = Image.new("RGB", (1040, 940), background)
        for y, mode in ((0, "PRAC"), (470, "RACE")):
            snapshot["header"]["typeLabel"] = mode
            snapshot["header"]["lapsText"] = "LAPS: 10" if mode == "RACE" else "BEST 1:30.000"
            calls = harness["drawRenderer"](lua.globals().leaderboardRenderer, snapshot, settings,
                lua.table_from([1040, 470]))
            canvas.paste(preview.raster(calls, 1040, 470, background), (0, y))
        path = output / f"leaderboard-{theme}.png"
        canvas.save(path)
        print(path)


if __name__ == "__main__":
    main()
