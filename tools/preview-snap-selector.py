"""Render the live Lua Snap Selector face and its mechanical shift sequence."""
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
    parser.add_argument('--reference', type=Path, default=ROOT / 'output/snap-selector/reference.png')
    args = parser.parse_args()
    os.chdir(ROOT)
    out = ROOT / 'output/snap-selector'
    out.mkdir(parents=True, exist_ok=True)
    lua, h = preview.create_harness()
    state = h['state']
    sample = dict(available=True, speedText='139', speedUnit='km/h', gear=4, gearText='4', gearCount=6,
                  rpmText='5200', rpm=5200, rpmDisplayLimiter=8000, rpmGaugeLimiter=8000,
                  rpmGaugeNormalized=0.65, rpmWarningFraction=0.86, rpmRedlineFraction=0.96,
                  turboAvailable=True, turboBoost=0.7, turboDisplayMax=1.5,
                  fuel=30, maxFuel=50, fuelNormalized=0.6, brake=0.32, throttle=0.72, clutch=0.2,
                  steeringInput=-0.2, tcSupported=True, absSupported=True, tcActive=True, absActive=True,
                  lightsAvailable=True, headlights=True, highBeams=False, pitLimiter=False, pitLane=False,
                  clock=0, raceFlagType=0, handbrake=0, rpmWarning=False, rpmRedline=False,
                  hazardLights=False, leftIndicator=False, rightIndicator=False)
    for key, value in sample.items():
        state[key] = value
    state['gt7Instruments'] = None
    font = ImageFont.truetype('C:/Windows/Fonts/consola.ttf', 20)

    def render(size=620, theme='dark', lights=True, animate=False):
        state['headlights'] = lights
        options = lua.table_from(dict(instrumentMode='digital', digitalVariant='snap', hudScale=1,
                                      theme=theme, animateGearSelector=animate, analogAuxiliaryMode='auto'))
        calls = h['drawDial'](options, state, lua.table_from((size, size)))
        return preview.raster(calls, size, size, '#24282c' if theme == 'dark' else '#dcdedc')

    dark = render()
    dark.save(out / 'snap-dark-620.png')
    render(320).save(out / 'snap-dark-320.png')
    render(620, 'light').save(out / 'snap-light-620.png')
    render(lights=False).save(out / 'snap-lights-off-620.png')
    if args.reference.is_file():
        reference = Image.open(args.reference).convert('RGBA')
        reference = reference.crop(reference.getbbox()).resize((620, 620), Image.Resampling.LANCZOS)
        board = Image.new('RGB', (1240, 660), '#24282c')
        board.paste(reference, ((620-reference.width)//2, 40), reference)
        board.paste(dark.crop((16, 0, 604, 588)).resize((620, 620), Image.Resampling.LANCZOS), (620, 40))
        draw = ImageDraw.Draw(board)
        draw.text((20, 10), 'CONCEPTO APROBADO', font=font, fill='#f2dbae')
        draw.text((640, 10), 'RENDER LUA REAL', font=font, fill='#f2dbae')
        board.save(out / 'comparison.png')

    # Begin settled in third, then retarget the same live state to fourth.
    state['gear'], state['gearText'], state['clock'] = 3, '3', 1
    render(320, animate=True)
    state['gear'], state['gearText'], state['clock'] = 4, '4', 1.01
    strip = Image.new('RGB', (320 * 5, 360), '#24282c')
    draw = ImageDraw.Draw(strip)
    for i, milliseconds in enumerate((0, 30, 60, 100, 120)):
        state['clock'] = 1.01 + milliseconds / 1000
        strip.paste(render(320, animate=True), (i * 320, 40))
        draw.text((i * 320 + 16, 10), f'{milliseconds} ms', font=font, fill='#f2dbae')
    strip.save(out / 'shift-3-to-4.png')
    frames = []
    state['gear'], state['gearText'], state['clock'] = 3, '3', 3
    for i in range(75):
        time = i / 50
        state['clock'] = 3 + time
        state['gear'] = 3 if time < 0.4 else 4 if time < 1.0 else 3
        state['gearText'] = str(state['gear'])
        frames.append(render(320, animate=True))
    frames[0].save(out / 'snap-motion.gif', save_all=True, append_images=frames[1:], duration=20, loop=0)
    states = Image.new('RGB', (320 * 4, 360), '#24282c')
    for i, (label, gear, count, fraction) in enumerate((('NEUTRAL', 'N', 6, .65), ('REVERSE', 'R', 5, .65),
                                                      ('8 SPEED', '8', 8, .65), ('REDLINE / LOW FUEL', '4', 6, 1))):
        state['gearText'], state['gearCount'] = gear, count
        state['rpmGaugeNormalized'], state['rpmText'] = fraction, str(round(fraction*8000))
        state['rpmRedline'], state['rpmWarning'] = fraction == 1, fraction == 1
        state['fuel'], state['fuelNormalized'], state['handbrake'] = (4, .08, 1) if fraction == 1 else (30, .6, 0)
        state['raceFlagType'], state['clock'] = (2 if fraction == 1 else 0), 5
        states.paste(render(320), (i*320, 40))
        ImageDraw.Draw(states).text((i*320+10, 10), label, font=font, fill='#f2dbae')
    states.save(out / 'states.png')
    print(out)


if __name__ == '__main__':
    main()
