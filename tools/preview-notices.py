"""Render the actual Race Notices Lua UI in dark/light and normal/compact sizes."""
import importlib.util
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('instrument_preview', ROOT / 'tools/preview-instruments.py')
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)


def overtake_samples(lua):
    """Create notices through the live tracker and formatter using synthetic races."""
    make_notice = lua.execute("""
      ac.SessionType = ac.SessionType or {}
      ac.SessionType.Race = ac.SessionType.Race or 1
      local State = require('modules/notices/src/state')
      return function(source, driver, carName, isAI, samples)
        local state = State.new()
        local sim = {currentSessionIndex=1, isSessionStarted=true}
        local car = {lapCount=0, resetCounter=0}
        local player = {index=0, driver='PLAYER', carID='player', racePosition=5,
          progress=0, active=true, connected=true, status='LIVE'}
        local rival = {index=1, driver=driver, carID='rival', carName=carName,
          classID='GT3', racePosition=4, active=true, connected=not isAI,
          isAI=isAI, status='LIVE', intervalSource=source}
        local settings = {overtakeEnabled=true, engineDamageThreshold=0.2,
          suspensionDamageThreshold=0.05, bodyDamageThreshold=0.2}
        for i=0,samples do
          local passed = i == samples
          local time, progress = i * 0.5, i / 180
          sim.currentSessionTime = time * 1000
          player.progress, player.racePosition = progress, passed and 4 or 5
          rival.progress, rival.racePosition = progress + 0.01, passed and 5 or 4
          rival.intervalSeconds = passed and -0.1 or 2 - 0.8 * progress
          local snapshot = {sim=sim, session={type=ac.SessionType.Race},
            localRow=player, rows={player,rival}, historyReset=i == 0,
            timeline={time=time, measuredClock=true}}
          state:update(0.5,car,sim,nil,nil,settings,{},nil,nil,snapshot)
        end
        assert(state.notice and state.notice.kind == 'overtake')
        return state.notice
      end
    """)
    return [
        ('HUMAN / MEASURED', make_notice('history', 'A. SATO', 'FERRARI 296', False, 361)),
        ('AI / ESTIMATED', make_notice('estimated', 'M. COSTA', 'PORSCHE 911 GT3 R', True, 361)),
        ('INSUFFICIENT HISTORY', make_notice('history', 'J. MARTIN', 'BMW M4 GT3', False, 30)),
        ('LONG DRIVER / CAR NAMES', make_notice('history', 'ALEXANDER VAN DER BERG',
            'MERCEDES-AMG GT3 EVO ENDURANCE', False, 361)),
    ]


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
    overtakes = overtake_samples(lua)
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
        canvas = Image.new('RGB', (1140, 66 + len(overtakes) * 138), background)
        draw = ImageDraw.Draw(canvas)
        draw.text((18, 14), 'RETRO UI / OVERTAKE SUMMARIES / LIVE LUA RENDERER', fill=foreground)
        draw.text((20, 38), '660 x 96', fill=foreground)
        draw.text((704, 38), '420 x 62', fill=foreground)
        for index, (label, notice) in enumerate(overtakes):
            y = 66 + index * 138
            draw.text((20, y), label, fill=foreground)
            for x, width, height in ((16, 660, 96), (700, 420, 62)):
                calls = harness['drawRenderer'](renderer, notice, lua.table_from({'scale': 1}),
                    lua.table_from([width, height]))
                canvas.paste(preview.raster(calls, width, height, background), (x, y + 20))
        path = output / f'overtake-summary-{theme}.png'
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
