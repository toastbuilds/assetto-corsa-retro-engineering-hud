"""Render suggested corner gear cues in the real GT7 and Dial Lua renderers."""
import importlib.util
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('instrument_preview', ROOT / 'tools/preview-instruments.py')
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)


def main():
    output = ROOT / 'output/corner-gear-hint'
    output.mkdir(parents=True, exist_ok=True)
    lua, harness = preview.create_harness()
    lua.globals().__dirname = str(ROOT)
    lua.globals().io.fileExists = lambda name: Path(name).is_file()
    state = harness['state']
    for key, value in dict(available=True, speedText='139', speedUnit='km/h', speedValue=139,
            gear=4, gearText='4', speedKmh=139, rpm=5200, rpmText='5200',
            rpmGaugeNormalized=0.65, analogNeedleNormalized=0.65,
            gt7RpmNeedleNormalized=0.65, gt7SpeedNeedleNormalized=0.43,
            rpmDisplayLimiter=8000, rpmGaugeLimiter=8000, gearCount=6,
            headlights=True, lightsAvailable=True, rpmWarning=False, rpmRedline=False,
            tcSupported=True, absSupported=True, tcLevel=2, absLevel=3,
            turboAvailable=True, turboBoost=0.7, turboDisplayMax=1.5,
            fuel=30, maxFuel=50, fuelNormalized=0.6, brake=0.32, throttle=0.72,
            clutch=0.2, steeringInput=-0.2, steeringAngle=-18, tcActive=True,
            absActive=True, pitLimiter=False, pitLane=False, clock=0.05,
            leftIndicator=False, rightIndicator=False, hazardLights=False,
            raceFlagType=0, handbrake=0, cornerGearHint={'gear':2,'direction':'down',
                'overspeed':False,'braking':False,'targetSpeedKmh':108}).items():
        state[key] = value

    foreground = {'dark': '#f2dbae', 'light': '#2e2b26'}
    backgrounds = {'dark': '#121416', 'light': '#e9e4d9'}
    font = ImageFont.truetype('C:/Windows/Fonts/consola.ttf', 16)

    for theme in ('dark', 'light'):
        for braking, tag in ((False, 'approach'), (True, 'braking-point')):
            state.cornerGearHint = lua.table_from(dict(gear=2, direction='down',
                overspeed=braking, braking=braking, targetSpeedKmh=108))
            gt7 = Image.new('RGB', (1440, 590), backgrounds[theme])
            labels = ImageDraw.Draw(gt7)
            for i, frame in enumerate(('classic', 'modern', 'outer_pedals', 'steering_dial')):
                x, y = i % 2 * 720, i // 2 * 295
                labels.text((x + 14, y + 5), frame.upper(), font=font, fill=foreground[theme])
                calls = harness['draw'](frame, lua.table_from(dict(theme=theme,
                    cornerGearHint=True, animateShiftAlert=False, pedalDisplay='estimated')),
                    state, lua.table_from((1440, 500)))
                image = preview.raster(calls, 1440, 500, backgrounds[theme])
                image.save(output / f'gt7-{frame}-{tag}-{theme}.png')
                gt7.paste(image.resize((720, 250), Image.Resampling.LANCZOS), (x, y + 28))
            gt7.save(output / f'gt7-layouts-{tag}-{theme}.png')

            for mode, variant_module in (('analog', 'dial_variants'), ('digital', 'digital_dial_variants')):
                module = lua.eval(f"require('src/{variant_module}')")
                names = sorted(str(name) for name in module['layouts'].keys())
                names.insert(0, 'original')
                sheet = Image.new('RGB', (1080, ((len(names) + 2) // 3) * 388), backgrounds[theme])
                labels = ImageDraw.Draw(sheet)
                for i, name in enumerate(names):
                    options = lua.table_from(dict(theme=theme, instrumentMode=mode, hudScale=1,
                        analogVariant=name, digitalVariant=name, cornerGearHint=True,
                        animateShiftAlert=False, pedalDisplay='estimated'))
                    calls = harness['drawDial'](options, state, lua.table_from((620, 620)))
                    image = preview.raster(calls, 620, 620, backgrounds[theme])
                    image.save(output / f'{mode}-{name}-{tag}-{theme}.png')
                    x, y = i % 3 * 360, i // 3 * 388
                    labels.text((x + 14, y + 6), name.upper(), font=font, fill=foreground[theme])
                    sheet.paste(image.resize((360, 360), Image.Resampling.LANCZOS), (x, y + 28))
                sheet.save(output / f'{mode}-layouts-{tag}-{theme}.png')
        print(f'Generated GT7 and Dial previews for {theme}: {output}')


if __name__ == '__main__':
    main()
