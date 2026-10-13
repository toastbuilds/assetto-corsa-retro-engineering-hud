"""Render the live Lua analog Snap Selector face and motion states."""
from pathlib import Path
import argparse
import importlib.util
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('instrument_preview', ROOT / 'tools/preview-instruments.py')
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--reference', type=Path, default=ROOT / 'output/snap-selector/analog-concept.png')
    args = parser.parse_args()
    os.chdir(ROOT)
    out = ROOT / 'output/snap-selector'
    out.mkdir(parents=True, exist_ok=True)
    lua, h = preview.create_harness()
    state = h['state']
    for key, value in dict(available=True, speedText='139', speedUnit='km/h', gear=4, gearText='4', gearCount=6,
            rpmText='5200', rpm=5200, rpmDisplayLimiter=8000, rpmGaugeLimiter=8000,
            analogNeedleNormalized=0.65, rpmGaugeNormalized=0.65, rpmWarningFraction=0.86,
            rpmRedlineFraction=0.96, turboAvailable=True, turboBoost=0.7, turboDisplayMax=1.5,
            fuel=30, maxFuel=50, fuelNormalized=0.6, brake=0.32, throttle=0.72, clutch=0.2,
            steeringInput=-0.2, tcSupported=True, absSupported=True, tcActive=True, absActive=True,
            lightsAvailable=True, headlights=True, highBeams=False, pitLimiter=False, pitLane=False,
            clock=0, raceFlagType=0, handbrake=0, rpmWarning=False, rpmRedline=False,
            hazardLights=False, leftIndicator=False, rightIndicator=False).items():
        state[key] = value
    state['gt7Instruments'] = None
    font = ImageFont.truetype('C:/Windows/Fonts/consola.ttf', 20)

    def render(size=620, theme='dark', animate=False):
        options = lua.table_from(dict(instrumentMode='analog', analogVariant='snap', hudScale=1,
                                      theme=theme, animateGearSelector=animate, analogAuxiliaryMode='auto',
                                      analogNeedleStyle='a01'))
        calls = h['drawDial'](options, state, lua.table_from((size, size)))
        bg = '#24282c' if theme == 'dark' else '#dcdedc'
        return preview.raster(calls, size, size, bg)

    dark = render()
    dark.save(out / 'snap-analog-dark-620.png')
    render(340).save(out / 'snap-analog-dark-340.png')
    render(theme='light').save(out / 'snap-analog-light-620.png')

    if args.reference.is_file():
        concept = Image.open(args.reference).convert('RGB').resize((620, 620), Image.Resampling.LANCZOS)
        board = Image.new('RGB', (1240, 660), '#24282c')
        board.paste(concept, (0, 40))
        board.paste(dark, (620, 40))
        draw = ImageDraw.Draw(board)
        draw.text((16, 10), 'CONCEPTO', font=font, fill='#f2dbae')
        draw.text((636, 10), 'RENDER LUA REAL', font=font, fill='#f2dbae')
        board.save(out / 'snap-analog-comparison.png')

    states = Image.new('RGB', (1240, 360), '#24282c')
    draw = ImageDraw.Draw(states)
    for i, (label, gear, count, fraction) in enumerate((('NEUTRAL', 'N', 6, .65), ('REVERSE', 'R', 6, .65),
            ('SIXTH', '6', 6, .78), ('REDLINE / LOW FUEL', '4', 6, 1))):
        state['gearText'], state['gearCount'] = gear, count
        state['rpmGaugeNormalized'], state['analogNeedleNormalized'] = fraction, fraction
        state['rpmText'] = str(round(fraction * 8000))
        state['rpmRedline'], state['rpmWarning'] = fraction == 1, fraction == 1
        state['fuel'], state['fuelNormalized'], state['handbrake'] = (4, .08, 1) if fraction == 1 else (30, .6, 0)
        state['raceFlagType'], state['clock'] = (2 if fraction == 1 else 0), 2+i
        states.paste(render(300), (i * 310, 40))
        draw.text((i * 310 + 10, 10), label, font=font, fill='#f2dbae')
    states.save(out / 'snap-analog-states.png')
    print(out)


if __name__ == '__main__':
    main()
