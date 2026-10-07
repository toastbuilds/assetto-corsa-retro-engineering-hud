"""Refresh the preset views and publication sheets from the actual renderers."""
import importlib.util,json,os
from pathlib import Path
from PIL import Image,ImageDraw
spec=importlib.util.spec_from_file_location('promo_sheets',Path(__file__).with_name('generate.py'))
g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
os.chdir(g.ROOT)
records=json.loads((g.OUT/'stills-manifest.json').read_text());h=g.Harness()
for preset in ('classic','modern','outer_pedals','steering_dial'):
    for mode in ('analog','digital'):
        h.options.gt7SpeedNeedleMode=h.options.gt7RpmNeedleMode=mode;g.fixture(h)
        g.save(g.padded(h.draw(preset=preset,factor=4),900),Path(f'instruments/{mode}/gt7_{preset}.png'),records,instrument='GT7',preset=preset,mode=mode)
overview=[(f'Dial {m}',Image.open(g.OUT/f'instruments/{m}/dial_{m}.png')) for m in ('analog','digital')]
overview += [(f'GT7 {m}',Image.open(g.OUT/f'instruments/{m}/gt7_classic.png')) for m in ('analog','digital')]
overview += [('Condition',Image.open(g.OUT/'instruments/digital/condition_life_remaining_dark.png'))]
overview += [(name,Image.open(g.OUT/f'instruments/digital/{name}_default.png')) for name in ('relative','leaderboard','map','delta','timer','laps','telemetry')]
g.sheet(overview,g.OUT/'overview/all_instruments.png',3,3840)
analog=[('Dial Analog',Image.open(g.OUT/'instruments/analog/dial_analog.png'))]
analog += [(preset,Image.open(g.OUT/f'instruments/analog/gt7_{preset}.png')) for preset in ('classic','modern','outer_pedals','steering_dial')]
analog += [(name,Image.open(g.OUT/f'instruments/analog/{name}.png')) for name in ('speedometer_mid','tachometer_mid','turbo_partial','hybrid_regeneration','aero_visual_high')]
g.sheet(analog,g.OUT/'overview/analog_instruments.png',2,3840)
digital=[('Dial Digital',Image.open(g.OUT/'instruments/digital/dial_digital.png'))]
digital += [(preset,Image.open(g.OUT/f'instruments/digital/gt7_{preset}.png')) for preset in ('classic','modern','outer_pedals','steering_dial')]
digital += [(name,Image.open(g.OUT/f'instruments/digital/{name}.png')) for name in ('speedometer_mid','tachometer_mid','turbo_partial','hybrid_regeneration','aero_visual_high')]
digital += overview[4:]
g.sheet(digital,g.OUT/'overview/digital_instruments.png',3,3840)
config=h.lua.eval("require('src/instrument_config')")
g.sheet([(config.needleNames[key],Image.open(g.OUT/f'needles/individual/{key}.png')) for _,key in config.needleOrder.items()],g.OUT/'needles/needles_overview.png',4,3840)
# The fixed auxiliary hand cannot be mounted on the main dial without changing
# product geometry. Preserve the fair 24-way comparison and show its native
# mini-dial separately in the footer, explicitly labelled as non-selectable.
needle_path=g.OUT/'needles/needles_overview.png'
main=Image.open(needle_path).convert('RGB')
complete=Image.new('RGB',(main.width,main.height+360),g.BG);complete.paste(main,(0,0))
mini=Image.open(g.OUT/'needles/individual/subNeedle.png').convert('RGB');mini.thumbnail((300,300),Image.Resampling.LANCZOS)
complete.paste(mini,(90,main.height+30))
ImageDraw.Draw(complete).text((450,main.height+155),'subNeedle — fixed fuel/boost auxiliary (not selectable)',font=g.font(32),fill='#dfcc9c')
complete.save(needle_path)
g.sheet([(f'{which} {mode} {lamp}',Image.open(g.OUT/f'lighting/{which}_{mode}_dark/lights_{lamp}.png')) for which in ('speedometer','tachometer') for mode in ('analog','digital') for lamp in ('off','on')],g.OUT/'overview/lighting_comparison.png',4,3840)
records={r['path']:r for r in records}
(g.OUT/'stills-manifest.json').write_text(json.dumps(list(records.values()),indent=2),encoding='utf8')
