"""Render actual pedal layers/model with simulated controls in every pedal layout."""
import importlib.util
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('instrument_preview', ROOT / 'tools/preview-instruments.py')
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)


def main():
    output = ROOT / 'output/pedal-layers'
    output.mkdir(parents=True, exist_ok=True)
    lua, harness = preview.create_harness()
    sample = lua.execute("""
      local Model = require('src/pedal_layers')
      ac.getCarID = function() return 'pedal_preview' end
      ac.getAssists = function() return {autoBlip=false} end
      ac.INIConfig = {carData=function()
        local values={LEVEL=0.8,POINT_0=20,POINT_1=140,POINT_2=60,ELECTRONIC=1}
        return {get=function(_,_,key,fallback) return values[key] or fallback end}
      end}
      return function(kind)
        local state,sim={}, {currentSessionIndex=1,time=0}
        local car={index=0,physicsAvailable=true,gas=0.8,brake=0.65,gear=3,engagedGear=3,
          tractionControlModes=3,absModes=3,tractionControlInAction=false,absInAction=false}
        physics={getCarInputControls=function() return {gas=car.gas,brake=car.brake} end}
        local function step(dt)
          sim.time=sim.time+dt*1000; Model.update(state,car,sim,dt)
        end
        for i=1,120 do
          car.tractionControlInAction=kind=='cuts' and i%2==0
          car.absInAction=kind=='cuts' and i%3==0
          step(1/60)
        end
        if kind=='shift' then car.gear,car.engagedGear=4,0;step(0.01) end
        if kind=='blip' then car.gas,car.gear,car.engagedGear=0,2,0;step(0.01);step(0.04) end
        if kind=='missing' then car.physicsAvailable=false;step(0.01) end
        return {pedalLayers=state.pedalLayers,throttle=car.gas,brake=car.brake,
          tcActive=car.tractionControlInAction,absActive=car.absInAction,gearText=tostring(car.gear)}
      end
    """)
    state = harness['state']
    for key, value in dict(available=True, speedText='139', speedValue=139, rpm=5200, rpmText='5200',
            rpmGaugeNormalized=0.65, analogNeedleNormalized=0.65, gt7RpmNeedleNormalized=0.65,
            gt7SpeedNeedleNormalized=0.43, rpmDisplayLimiter=8000, gearCount=6,
            headlights=True, lightsAvailable=True, rpmWarning=False, rpmRedline=False,
            tcSupported=True, absSupported=True, tcLevel=2, absLevel=3).items():
        state[key] = value

    for theme in ('dark', 'light'):
        background = '#121416' if theme == 'dark' else '#e9e4d9'
        foreground = '#f2dbae' if theme == 'dark' else '#2e2b26'

        def prepare(kind):
            for key, value in sample(kind).items():
                state[key] = value

        def gt7(frame, kind, classic=False):
            prepare(kind)
            calls = harness['draw'](frame, lua.table_from(dict(theme=theme,
                pedalDisplay='classic' if classic else 'estimated')), state, lua.table_from([1440,500]))
            picture = preview.raster(calls, 1440, 500, background)
            picture.save(output / f'gt7-{frame}-{kind}{"-classic" if classic else ""}-{theme}.png')
            return picture.resize((720,250), Image.Resampling.LANCZOS)

        sheet = Image.new('RGB', (1440, 3 * 282 + 28), background)
        labels = ImageDraw.Draw(sheet)
        labels.text((14,8), 'INPUT: RED/CYAN | ESTIMATED OUTPUT: NEUTRAL INNER LAYER', fill=foreground)
        scenarios = [('CLASSIC', 'cuts', True), ('NO INTERVENTION', 'free', False),
            ('TC / ABS', 'cuts', False), ('UPSHIFT CUT', 'shift', False),
            ('AUTO-BLIP', 'blip', False), ('PHYSICS UNAVAILABLE / INPUT ONLY', 'missing', False)]
        for i, (title, kind, classic) in enumerate(scenarios):
            x, y = i % 2 * 720, i // 2 * 282 + 28
            labels.text((x+14,y+6), title, fill=foreground)
            sheet.paste(gt7('classic', kind, classic), (x,y+28))
        path = output / f'comparison-{theme}.png'
        sheet.save(path)
        print(path)

        sheet = Image.new('RGB', (1440, 564), background)
        labels = ImageDraw.Draw(sheet)
        for i, frame in enumerate(('classic','modern','outer_pedals','steering_dial')):
            x, y = i % 2 * 720, i // 2 * 282
            labels.text((x+14,y+6), frame.upper(), fill=foreground)
            sheet.paste(gt7(frame,'cuts'), (x,y+28))
        path = output / f'gt7-layouts-{theme}.png'
        sheet.save(path)
        print(path)

        for mode in ('analog','digital'):
            module = lua.eval(f"require('src/{'dial_variants' if mode == 'analog' else 'digital_dial_variants'}')")
            names = sorted(str(name) for name in module['layouts'].keys())
            if mode == 'digital':
                names.insert(0, 'original')
            sheet = Image.new('RGB', (1080, ((len(names)+2)//3)*388), background)
            labels = ImageDraw.Draw(sheet)
            for i, name in enumerate(names):
                prepare('cuts')
                options = lua.table_from(dict(theme=theme, instrumentMode=mode, hudScale=1,
                    analogVariant=name, digitalVariant=name, pedalDisplay='estimated'))
                calls = harness['drawDial'](options, state, lua.table_from([620,620]))
                picture = preview.raster(calls,620,620,background)
                picture.save(output / f'{mode}-{name}-{theme}.png')
                x, y = i%3*360, i//3*388
                labels.text((x+14,y+6), name.upper(), fill=foreground)
                sheet.paste(picture.resize((360,360),Image.Resampling.LANCZOS),(x,y+28))
            path = output / f'{mode}-layouts-{theme}.png'
            sheet.save(path)
            print(path)


if __name__ == '__main__':
    main()
