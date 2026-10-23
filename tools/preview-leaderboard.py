"""Render the real Lua leaderboard with sample data and Consolas metrics.

python tools/preview-leaderboard.py [--before-ref <git-ref>]
This produces UI previews, without starting Assetto Corsa or running tests.
"""
import argparse
import importlib.util
from pathlib import Path
import subprocess

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("instrument_preview", ROOT / "tools/preview-instruments.py")
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)


def create_drawing_harness():
    lua = preview.LuaRuntime(unpack_returned_tuples=True)
    # Reuse only the drawing doubles, before the fixture loads modules and
    # executes its test scenarios. A preview must never run the test suite.
    fixture = (ROOT / 'tests/gt7_layouts.lua').read_text(encoding='utf-8')
    drawing_doubles = fixture[:fixture.index("local Layouts = require(")]
    harness = lua.execute(drawing_doubles + """
      ui.pushClipRect=function(a,b) record('clip_push',{a=a,b=b}) end
      ui.popClipRect=function() record('clip_pop',{}) end
      local push,pop=ui.pushDWriteFont,ui.popDWriteFont
      ui.pushDWriteFont=function(desc) push(desc); previewFont=desc end
      ui.popDWriteFont=function() pop(); previewFont=fontStack[#fontStack] end
      return {drawRenderer=function(renderer,state,settings,window)
        width,height=window[1],window[2]; calls={}
        renderer.draw(state,settings)
        return calls
      end}
    """)

    def measure(value, size):
        face = preview.font(size, 'Bold' in str(lua.globals().previewFont or ''))
        return lua.globals().vec2(face.getlength(str(value)) / preview.FACTOR, size)

    lua.globals().ui.measureDWriteText = measure
    return lua, harness


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--before-ref")
    args = parser.parse_args()
    output = ROOT / "output/leaderboard"
    output.mkdir(parents=True, exist_ok=True)
    lua, harness = create_drawing_harness()
    lua.execute("""
      ui.time = function() return 100 end
      previewLeaderboard = require('modules/leaderboard/ui/leaderboard')
      previewRenderer = {draw = function(snapshot, settings)
        previewLeaderboard.draw(snapshot, settings, {
          palette = require('modules/leaderboard/src/theme').get(settings.theme), instrumentOpacity = 1})
      end}
      previewSnapshot = {
        header = {typeLabel='RACE',timeText='28:36',currentLapText='12',lapsText='LAPS: ~31',
          isTimed=true},
        enteredAt=0,sessionBest=90325,online=true,shownRows={},
        fuel={available=true,fuel=38.4,maxFuel=100,fuelText='38.4 L',averageText='2.6 L/LAP',
          estimatedLapsText='14 LAPS',finishAvailable=true,fuelNeeded=42.6,finishText='-4.2 L'}
      }
      local names={'ALEX MARTIN','DANIEL ANDERSEN','A PIECE OF TOAST','MARIA ALVAREZ',
        'JEAN-PIERRE DELACROIX','SILVA','AI DRIVER'}
      local pings={45,95,130,215,320,-1,0}
      for i=1,7 do
        previewSnapshot.shownRows[i]={index=i-1,isLocal=i==3,isAI=i==7,connected=true,active=true,
          driver=names[i],carID='gt3',sessionID=i,pingMs=pings[i],position=i,classID='GT3',
          tyreCompound='MEDIUM',status=i==2 and 'PIT' or 'L 12',bestLapTimeMs=90325+(i-1)*250,
          lastLapTimeMs=90625+(i-1)*200,interval=i==3 and '0.0s' or string.format('%+.3f',(i-3)*0.825),
          lapPositionDelta=i-3,positionChangeDelta=i==4 and 12 or i-3,positionChangeUntil=120,
          sectorCount=3,sectors={{role='PURPLE'},{role='GREEN'},{role='AMBER',active=true}}}
      end
      require('modules/leaderboard/src/connection').update({},previewSnapshot.shownRows,true,100)
    """)
    current = lua.globals().previewLeaderboard
    previous = None
    if args.before_ref:
        original = subprocess.run(["git", "show", f"{args.before_ref}:modules/leaderboard/ui/leaderboard.lua"],
            cwd=ROOT, check=True, capture_output=True, text=True, encoding="utf-8").stdout
        previous = lua.execute(original)
    snapshot = lua.globals().previewSnapshot
    renderer = lua.globals().previewRenderer
    for theme, background in (("dark", "#121416"), ("light", "#e9e4d9")):
        # Keep the retired compound flag enabled for before/after comparisons;
        # the current renderer ignores it, including for older saved settings.
        settings = lua.table_from({"theme": theme, "maxRows": 7, "hudScale": 0.84,
            "showFlags": True, "showClass": True, "showCompound": True, "showConnection": True,
            "showFuel": True, "fuelReserve": 2})
        images = []
        for label, module in (("BEFORE", previous), ("AFTER", current)):
            if module is None:
                continue
            lua.globals().previewLeaderboard = module
            calls = harness["drawRenderer"](renderer, snapshot, settings, lua.table_from([1040, 500]))
            images.append((label, preview.raster(calls, 1040, 500, background)))
        sheet = Image.new("RGB", (1040, len(images) * 524), background)
        for index, (label, image) in enumerate(images):
            ImageDraw.Draw(sheet).text((85, index * 524 + 5), label, fill="#a08254" if theme == "dark" else "#655948")
            sheet.paste(image, (0, index * 524 + 24))
        path = output / f"leaderboard-{theme}.png"
        sheet.save(path)
        print(path)

    # Qualifying, no measurements yet, hidden fuel, and disconnected indicators.
    lua.globals().previewLeaderboard = current
    lua.execute("""
      previewSnapshot.header.typeLabel='QUAL'
      previewSnapshot.header.flagLabel='YELLOW'; previewSnapshot.header.flagRole='yellow'
      previewSnapshot.fuel.averageText='--'; previewSnapshot.fuel.estimatedLapsText='--'
      previewSnapshot.fuel.finishAvailable=false
      for _,row in ipairs(previewSnapshot.shownRows) do row.status='LIVE' end
    """)
    settings["theme"], settings["maxRows"] = "dark", 5
    sheet = Image.new("RGB", (1040, 840), "#121416")
    for offset, fuel_visible in ((0, True), (420, False)):
        settings["showFuel"] = fuel_visible
        calls = harness["drawRenderer"](renderer, snapshot, settings, lua.table_from([1040, 420]))
        sheet.paste(preview.raster(calls, 1040, 420), (0, offset))
    path = output / "leaderboard-qualifying.png"
    sheet.save(path)
    print(path)


if __name__ == "__main__":
    main()
