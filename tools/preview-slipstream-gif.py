"""Animate the real GT7 speed-dial Lua renderer to preview slipstream pulses.

From the repo root: python tools/preview-slipstream-gif.py
Output: output/slipstream/slipstream-pulse.gif

The slipstream strength follows a sample ramp. The phase update matches
src/slipstream.lua; the glow and dial are drawn by the actual Lua UI modules.
"""
import argparse
import importlib.util
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('slipstream_preview', ROOT / 'tools/preview-slipstream.py')
slipstream_preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(slipstream_preview)


def strength_at(seconds):
    keyframes = ((0, .12), (1.6, .28), (3.5, .60), (5.4, 1), (7.5, 1), (9, .12))
    for (start, before), (end, after) in zip(keyframes, keyframes[1:]):
        if seconds <= end:
            fraction = min(1, max(0, (seconds - start) / (end - start)))
            eased = fraction * fraction * (3 - 2 * fraction)
            return before + (after - before) * eased
    return keyframes[-1][1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=('analog', 'digital'), default='analog')
    parser.add_argument('--theme', choices=('dark', 'light'), default='dark')
    parser.add_argument('--fps', type=int, default=15)
    args = parser.parse_args()
    if args.fps <= 0 or args.fps > 60:
        parser.error('--fps must be in the range 1..60')

    os.chdir(ROOT)
    out = ROOT / 'output/slipstream'
    out.mkdir(parents=True, exist_ok=True)
    lua, harness, state, renderer = slipstream_preview.create_slipstream_harness()
    settings = lua.table_from(dict(
        theme=args.theme, speedUnit='km/h',
        gt7SpeedNeedleMode=args.mode, gt7SpeedDialStyle='original',
        gt7SpeedNeedleStyle='b01', gt7SpeedAuxiliaryStyle='original',
        gt7SlipstreamBackground=True, animateIndicators=False,
    ))
    background = '#121416' if args.theme == 'dark' else '#e9e4d9'
    text_color = '#f2dbae' if args.theme == 'dark' else '#383027'
    muted_color = '#b7a280' if args.theme == 'dark' else '#807365'
    font = ImageFont.truetype('C:/Windows/Fonts/consola.ttf', 17)
    small_font = ImageFont.truetype('C:/Windows/Fonts/consola.ttf', 13)
    frames = []
    phase = .5
    size = 360
    duration = 9
    total = duration * args.fps
    # Add a short low-strength tail so the pulse also loops without a jump.
    for index in range(total + 2 * args.fps):
        seconds = index / args.fps
        strength = strength_at(seconds)
        frequency = .55 + 1.05 * strength
        phase = (phase + frequency / args.fps) % 1
        state.clock = seconds
        state.slipstream.intensity = strength
        state.slipstream.pulsePhase = phase
        calls = harness['drawRenderer'](renderer, state, settings, lua.table_from([size, size]))
        dial = slipstream_preview.preview.raster(calls, size, size, background)
        canvas = Image.new('RGB', (420, 440), background)
        canvas.paste(dial, (30, 32))
        draw = ImageDraw.Draw(canvas)
        draw.text((30, 12), 'SLIPSTREAM  /  PULSE PREVIEW', font=font, fill=text_color)
        draw.text((30, 398), f'Strength {strength:3.0%}    Pulse {frequency:.2f} Hz',
                  font=small_font, fill=text_color)
        draw.rounded_rectangle((30, 423, 390, 429), radius=3, fill=muted_color)
        if strength > 0:
            draw.rounded_rectangle((30, 423, 30 + round(strength * 360), 429), radius=3,
                                   fill='#e8ad57')
        frames.append(canvas)
        if index + 1 >= total:
            distance_to_start = abs((phase - 0.5 + 0.5) % 1 - 0.5)
            if distance_to_start <= frequency / (2 * args.fps):
                break

    destination = out / 'slipstream-pulse.gif'
    frames[0].save(destination, save_all=True, append_images=frames[1:],
                   duration=round(1000 / args.fps), loop=0, optimize=False)
    print(f'{destination} ({len(frames)} frames, {args.fps} fps, {len(frames)/args.fps:.2f}s)')
    print('Rendered with the actual Lua UI; sample slipstream values, no game capture.')


if __name__ == '__main__':
    main()
