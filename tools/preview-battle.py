"""Export the actual Battle Lua panel and an animation with simulated telemetry."""
import importlib.util
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('instrument_preview', ROOT / 'tools/preview-instruments.py')
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)


def main():
    output = ROOT / 'output'
    output.mkdir(exist_ok=True)
    lua, harness = preview.create_harness()
    lua.globals().ac.SessionType = lua.table_from({'Race': 2})
    renderer = lua.eval("require('modules/battle/src/display')")
    model = lua.eval("require('modules/battle/src/state')")
    general = lua.eval("require('src/general_settings')")
    general['values']['opacity'], general['values']['backgroundOpacity'] = 1, 0.72
    options = lua.table_from({'showGraphs': True})
    size = lua.table_from([630, 540])

    def render(snapshot, theme='dark'):
        general['values']['theme'] = theme
        calls = harness['drawRenderer'](renderer, snapshot, options, size)
        return preview.raster(calls, 630, 540, '#121416' if theme == 'dark' else '#e9e4d9')

    for theme in ('dark', 'light'):
        render(model.preview(), theme).save(output / f'battle-panel-{theme}.png')

    state = model.new()
    frames = []
    for i in range(81):
        progress = i / 16
        ahead_gap = (2.3 - 0.3 * progress if progress <= 3 else 1.4 + 0.7 * (progress - 3))
        behind_gap = (1.4 - 0.2 * progress if progress <= 3 else 0.8 + 0.35 * (progress - 3))
        ahead_gap += 0.035 * math.sin(progress * math.pi * 2)
        behind_gap += 0.025 * math.sin(progress * math.pi * 2)

        def row(index, driver, gap):
            return lua.table_from(dict(index=index, driver=driver, carID='gt3-demo', classID='GT3',
                active=True, connected=True, status='LIVE', intervalSeconds=gap, intervalSource='history'))

        player = row(0, 'YOU', 0)
        player['progress'] = progress
        rows = [row(10, 'LEE', 8), row(11, 'ROSSI', 5), row(12, 'SMITH', 3),
                row(2, 'MARTIN', ahead_gap), player, row(3, 'COSTA', -behind_gap)]
        snapshot = lua.table_from(dict(localRow=player, rows=lua.table_from(rows),
            session=lua.table_from({'type': 2}), timeline=lua.table_from({'time': i * 0.5}),
            historyReset=i == 0, final=False))
        state.update(state, snapshot)
        if i == 48:
            assert abs(state['snapshot']['ahead']['rate'] - 0.3) < 0.0001
            assert abs(state['snapshot']['behind']['rate'] + 0.2) < 0.0001
        frames.append(render(state['snapshot']))

    assert state['snapshot']['ahead']['rate'] < 0 and state['snapshot']['behind']['rate'] > 0
    frames[0].save(output / 'battle-panel.gif', save_all=True, append_images=frames[1:],
                   duration=120, loop=0, optimize=True, disposal=2)
    print('Saved output/battle-panel-dark.png, battle-panel-light.png and battle-panel.gif')


if __name__ == '__main__':
    main()
