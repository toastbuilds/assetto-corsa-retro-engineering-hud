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
    lua, harness = preview.create_harness()
    renderer = lua.eval("require('modules/notices/src/display')")
    general = lua.eval("require('src/general_settings')")
    battle = lua.eval("require('modules/notices/src/battle')")
    def rear_notice(rate, gap):
        return battle.notice(lua.table_from({'behind': lua.table_from(dict(
            driver='COSTA', position=6, rate=rate, gapSeconds=gap, physicallyBehind=True))}))
    attack_notice = battle.notice(lua.table_from({'ahead': lua.table_from(dict(
        driver='MARTIN', position=4, rate=0.6, gapSeconds=2.1, physicallyBehind=False))}),
        lua.table_from({'attackEnabled': True}))
    battle_notices = [rear_notice(-1.2, 6), rear_notice(-0.6, 0.8), attack_notice]
    notices = [
        dict(kind='blue', title='BLUE FLAG', detail='LMP2 APPROACHING', value='1.8 s', label='BEHIND'),
        dict(kind='repair', title='REPAIR REQUIRED', detail='FRONT SUSPENSION DAMAGE', value='BOX', label='REPAIR'),
        dict(kind='pit', title='BOX THIS LAP', detail='~1 FULL LAP OF FUEL / FRONT SUSPENSION DAMAGE', value='~32 s', label='EST. REPAIR'),
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
        battle_output = ROOT / 'output'
        battle_output.mkdir(exist_ok=True)
        canvas = Image.new('RGB', (990, 472), background)
        for index, notice in enumerate(battle_notices):
            calls = harness['drawRenderer'](renderer, notice, lua.table_from({'scale': 1}),
                lua.table_from([990, 144]))
            canvas.paste(preview.raster(calls, 990, 144, background), (0, index * 164))
        path = battle_output / f'rear-battle-alert-{theme}.png'
        canvas.save(path)
        print(path)


if __name__ == '__main__':
    main()
