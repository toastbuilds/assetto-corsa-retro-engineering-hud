"""Render the actual Race Notices Lua UI in dark/light and normal/compact sizes."""
import importlib.util
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('instrument_preview', ROOT / 'tools/preview-instruments.py')
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)


def main():
    output = ROOT / 'outputs'
    output.mkdir(exist_ok=True)
    lua = preview.LuaRuntime(unpack_returned_tuples=True)
    harness = lua.execute((ROOT / 'tests/gt7_layouts.lua').read_text(encoding='utf-8-sig'))
    lua.globals().ui.measureDWriteText = lambda text, size: lua.globals().vec2(
        preview.font(size).getlength(str(text)) / preview.FACTOR, size)
    renderer = lua.eval("require('modules/notices/src/display')")
    general = lua.eval("require('src/general_settings')")
    notices = [
        dict(kind='blue', title='BLUE FLAG', detail='LMP2 APPROACHING', value='1.8 s', label='BEHIND'),
        dict(kind='repair', title='REPAIR REQUIRED', detail='FRONT SUSPENSION DAMAGE', value='BOX', label='REPAIR'),
        dict(kind='pit', title='BOX NEXT LAP', detail='LAP 12 / FRONT SUSPENSION DAMAGE', value='~32 s', label='EST. REPAIR'),
    ]
    for theme in ('dark', 'light'):
        general['values']['theme'] = theme
        general['values']['opacity'], general['values']['backgroundOpacity'] = 1, 0.72
        background = '#121416' if theme == 'dark' else '#e9e4d9'
        foreground = '#f2dbae' if theme == 'dark' else '#2e2b26'
        canvas = Image.new('RGB', (1140, 410), background)
        draw = ImageDraw.Draw(canvas)
        draw.text((18, 14), 'RETRO UI / RACE NOTICES', fill=foreground)
        draw.text((20, 42), '660 x 96', fill=foreground)
        draw.text((704, 42), '420 x 62', fill=foreground)
        for index, notice in enumerate(notices):
            for x, width, height in ((16, 660, 96), (700, 420, 62)):
                calls = harness['drawRenderer'](renderer, lua.table_from(notice), lua.table_from({'scale': 1}),
                    lua.table_from([width, height]))
                canvas.paste(preview.raster(calls, width, height, background), (x, 66 + index * 110))
        path = output / f'race-notices-{theme}.png'
        canvas.save(path)
        print(path)


if __name__ == '__main__':
    main()
