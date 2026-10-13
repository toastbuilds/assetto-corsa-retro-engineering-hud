"""Render the recommended standalone dial concepts beside their references."""
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
    parser.add_argument('--theme', choices=('dark', 'light'), default='dark')
    parser.add_argument('--size', type=int, default=620)
    parser.add_argument('--aux', choices=('turbo', 'fuel', 'electric'), default='turbo')
    args = parser.parse_args()
    os.chdir(ROOT)

    out = ROOT / 'output/dial-inspirations'
    out.mkdir(parents=True, exist_ok=True)
    lua, harness = preview.create_harness()
    lua.globals().__dirname = str(ROOT.resolve())
    lua.globals().io.fileExists = lambda name: Path(name).is_file()
    state = harness['state']
    sample = dict(
        available=True, speedText='139', speedUnit='km/h', gearText='2', rpmText='5200',
        rpm=5200, rpmDisplayLimiter=8000, rpmGaugeLimiter=8000,
        analogNeedleNormalized=0.65, rpmGaugeNormalized=0.65, rpmWarningFraction=0.86,
        rpmRedlineFraction=0.96, turboAvailable=True, turboBoost=0.7, turboDisplayMax=1.5,
        fuel=30, maxFuel=50, fuelNormalized=0.6, brake=0.32, throttle=0.72, clutch=0.2,
        steeringInput=-0.2, steeringAngle=-18, tcLevel=2, absLevel=3,
        tcSupported=True, absSupported=True, lightsAvailable=True, headlights=True,
        highBeams=False, tcActive=True, absActive=True, pitLimiter=False, pitLane=False,
        clock=0.05, leftIndicator=False, rightIndicator=False, hazardLights=False,
        raceFlagType=0, handbrake=0, rpmWarning=False, rpmRedline=False,
    )
    for key, value in sample.items():
        state[key] = value
    if args.aux == 'fuel':
        state['fuel'] = 4
        state['fuelNormalized'] = 0.08
    elif args.aux == 'electric':
        state['turboAvailable'] = False
        state['hybrid'] = lua.table_from(dict(
            charge=0.84, powerKw=-38, needle=-0.55, recoveryKw=100, maximumKw=150,
        ))

    ref = Image.open(ROOT / 'assets/Twelve Retro Car Dashboard Gauge Concepts.png').convert('RGB')
    def reference_dial(bounds, center, radius):
        crop = ref.crop(bounds).convert('RGBA')
        mask = Image.new('L', crop.size, 0)
        ImageDraw.Draw(mask).ellipse((center[0] - radius, center[1] - radius,
                                      center[0] + radius, center[1] + radius), fill=255)
        crop.putalpha(mask)
        return crop

    references = {
        'track': reference_dial((420, 343, 755, 678), (165, 165), 155),
        'capsule': reference_dial((46, 671, 371, 996), (161, 162), 155),
    }
    render_specs = {
        'analog_original': dict(instrumentMode='analog', analogVariant='original'),
        'track': dict(instrumentMode='analog', analogVariant='track'),
        'digital_original': dict(instrumentMode='digital', digitalVariant='original'),
        'core_capsule': dict(instrumentMode='digital', digitalVariant='core_capsule'),
    }
    rendered = {}
    for name, selection in render_specs.items():
        options = lua.table_from(dict(
            **selection, analogAuxiliaryMode=args.aux, analogNeedleStyle='a01',
            hudScale=1, theme=args.theme, backgroundOpacity=0.72,
        ))
        calls = harness['drawDial'](options, state, lua.table_from((args.size, args.size)))
        image = preview.raster(calls, args.size, args.size, background='#e8e8e4')
        rendered[name] = image
        suffix = '' if args.aux == 'turbo' else f'-{args.aux}'
        size_suffix = '' if args.size == 620 else f'-{args.size}'
        image.save(out / f'{name}-{args.theme}{size_suffix}{suffix}.png')

    if args.theme == 'dark' and args.aux == 'turbo':
        cell, margin, label_h = 340, 22, 36
        sheet = Image.new('RGB', (cell * 3 + margin * 4, (cell + label_h) * 2 + margin * 3), '#e8e8e4')
        draw = ImageDraw.Draw(sheet)
        font = ImageFont.truetype('C:/Windows/Fonts/consola.ttf', 16)
        rows = (
            ('ANALÓGICO · 3A', references['track'], rendered['analog_original'], rendered['track'],
             ('Referencia 3A', 'Dial actual · Original', 'Nuevo · Track')),
            ('DIGITAL · 5D', references['capsule'], rendered['digital_original'], rendered['core_capsule'],
             ('Referencia 5D', 'Dial actual · Original', 'Nuevo · Core Capsule')),
        )
        for row, (title, reference, original, proposal, labels) in enumerate(rows):
            y = margin + row * (cell + label_h + margin)
            draw.text((margin, y), title, font=font, fill='#343434')
            for column, (image, label) in enumerate(zip((reference, original, proposal), labels)):
                x = margin + column * (cell + margin)
                draw.text((x, y + 24), label, font=font, fill='#343434')
                image = image.resize((cell, cell), Image.Resampling.LANCZOS)
                if image.mode == 'RGBA':
                    sheet.paste(image, (x, y + label_h), image.getchannel('A'))
                else:
                    sheet.paste(image, (x, y + label_h))
        comparison_name = 'comparison-dark.png' if args.size == 620 else f'comparison-in-game-{args.theme}-{args.size}.png'
        sheet.save(out / comparison_name)

    suffix = '' if args.aux == 'turbo' else f'-{args.aux}'
    size_suffix = '' if args.size == 620 else f'-{args.size}'
    target = out / (('comparison-dark.png' if args.size == 620 else f'comparison-in-game-{args.theme}-{args.size}.png')
                    if args.theme == 'dark' and args.aux == 'turbo'
                    else f'core_capsule-{args.theme}{size_suffix}{suffix}.png')
    print(target)


if __name__ == '__main__':
    main()
