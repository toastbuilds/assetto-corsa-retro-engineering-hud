"""Additional conditional branches found during the full audit, using real Lua."""
import importlib.util, json, os, math
from pathlib import Path
from PIL import Image
spec=importlib.util.spec_from_file_location('promo_generate',Path(__file__).with_name('generate.py'))
g=importlib.util.module_from_spec(spec); spec.loader.exec_module(g)

def main():
    os.chdir(g.ROOT)
    records=json.loads((g.OUT/'stills-manifest.json').read_text()); h=g.Harness()
    h.options.speedUnit='km/h'; h.options.gt7RpmNeedleMode=h.options.gt7SpeedNeedleMode='analog'
    def capture(path,kind='gt7',**meta):
        im=g.padded(h.draw(kind,factor=4),1080 if kind in ('rpm','speed','dial','condition') else 800)
        g.save(im,Path(path),records,**meta); return im
    for mode in ('analog','digital'):
        h.options.gt7RpmNeedleMode=mode
        for speed,label in [(0,'minimum'),(160,'mid'),(300,'high')]:
            g.fixture(h,turboCount=0,speedKmh=speed)
            capture(f'instruments/{mode}/aero_visual_{label}.png','rpm',instrument='AERO',source='speed² visual fallback')
        g.fixture(h,turboCount=0,aeroLiftFront=.7,aeroLiftRear=1.1,speedKmh=220)
        capture(f'instruments/{mode}/aero_coefficient.png','rpm',instrument='AERO',source='CL')
        g.fixture(h,turboCount=0,mass=1300,wheelSlip=.1,wheelLoad=3187,speedKmh=0)
        g.fixture(h,turboCount=0,mass=1300,wheelSlip=.1,wheelLoad=3900,speedKmh=220)
        capture(f'instruments/{mode}/aero_downforce.png','rpm',instrument='AERO',source='wheel loads minus static mass')
    h.options.instrumentMode='analog'; h.options.analogAuxiliaryMode='turbo'; g.fixture(h,turboCount=0,aeroLiftFront=.7,aeroLiftRear=1.1)
    capture('instruments/analog/dial_aero_coefficient.png','dial',instrument='Dial AERO')
    g.fixture(h,turboCount=0,mass=1300,wheelSlip=.1,wheelLoad=3187,speedKmh=0)
    g.fixture(h,turboCount=0,mass=1300,wheelSlip=.1,wheelLoad=3900,speedKmh=220)
    capture('instruments/analog/dial_aero_downforce.png','dial',instrument='Dial AERO kN')
    h.options.analogAuxiliaryMode='auto'; h.options.gt7RpmNeedleMode='analog'
    for slip,label in [(.1,'low'),(.5,'mid'),(.75,'warning'),(.96,'high')]:
        h.options.gt7LowerPanelMode='limit'; g.fixture(h,wheelSlip=slip)
        capture(f'instruments/variants/lower_limit_{label}.png',instrument='Grip limit',state=label)
    for force,label in [(0,'minimum'),(.5,'mid'),(1,'clipping')]:
        h.options.gt7LowerPanelMode='ffb'; g.fixture(h,ffbFinal=force)
        capture(f'instruments/variants/lower_ffb_{label}.png',instrument='FFB',state=label)
    h.options.gt7LowerPanelMode='pedal_history'
    for i in range(480): h.step(g.motion_values(i/60,'drive'))
    capture('instruments/variants/lower_pedal_history_active.png',instrument='Pedal history')
    # Warm up with a visible traffic episode. Freeze the actual blink phase ON.
    for style in ('arcs','classic_lights','modern_bars','column_3','column_9'):
        h.options.gt7RadarPresentation=style
        for side,x in [('left',-2.8),('right',2.8)]:
            g.fixture(h,radarX=x)
            for _ in range(30):
                if math.floor(h.state.clock/.24)%2==0: break
                h.step(dict(radarX=x))
            capture(f'instruments/variants/radar_{style}_{side}.png',instrument='Radar',variant=style,side=side)
    for on,name in [(False,'off'),(True,'on')]:
        h.options.showLights=False; g.fixture(h,headlightsActive=on)
        capture(f'lighting/hidden_lights_indicator/lights_{name}.png',instrument='GT7',showLights=False,lights=on)
    h.options.showLights=True; g.fixture(h,headlightsActive=False,flashingLightsActive=True)
    capture('lighting/headlight_flasher.png',instrument='GT7 headlight flash')
    h.options.numericMetric='life'; h.options.legendMode='temperature'; h.options.temperatureDisplay='general'; h.options.lifeTextSize=24; h.options.lifeTextWeight='Regular'
    for wear,label in [(0,'new'),(.25,'used'),(.6,'worn'),(.9,'critical')]:
        g.fixture(h,tyreWear=wear)
        capture(f'instruments/digital/condition_wear_{label}.png','condition',instrument='Tyre wear')
    g.fixture(h,engineLifeLeft=450,gearboxDamage=.7,damage=dict(front=60,rear=10,left=35,right=80))
    capture('instruments/digital/condition_damage.png','condition',instrument='Condition damage')
    # Two themes on identical instrument state, preserving real palette differences.
    for mode in ('analog','digital'):
        h.options.gt7SpeedNeedleMode=h.options.gt7RpmNeedleMode=mode; g.fixture(h)
        for theme in ('dark','light'):
            h.options.theme=theme; capture(f'instruments/{mode}/tachometer_{theme}.png','rpm',instrument='Tachometer',theme=theme)
    # Update overview with selectable needles and a separate, authored mini-hand panel.
    mini=Image.open(g.OUT/'needles/individual/subNeedle.png')
    g.sheet([('Fixed fuel/boost subNeedle',mini)],g.OUT/'needles/fixed_auxiliary_needle.png',1,1920)
    rows=[]
    for mode in ('analog','digital'):
        for name in ('dial_'+mode,'gt7_classic','tachometer_mid','speedometer_mid','hybrid_regeneration','aero_visual_high'):
            rows.append((f'{mode} / {name}',Image.open(g.OUT/f'instruments/{mode}/{name}.png')))
    g.sheet(rows,g.OUT/'overview/driving_instruments.png',3,3840)
    records={r['path']:r for r in records}
    (g.OUT/'stills-manifest.json').write_text(json.dumps(list(records.values()),indent=2),encoding='utf8')
    inventory=g.OUT/'INVENTORY.md'; text=inventory.read_text(encoding='utf8')
    if '| AERO |' not in text:
        text=text.replace('| [ ] | Hybrid |','| [ ] | AERO | GT7 sin turbo/híbrido; dial forzado Turbo sin turbo | analog / digital GT7; analog dial | velocidad² estimada, coeficiente CL, fuerza kN inferida de cargas de ruedas | Sí | aero_*; dial_aero_* |\n| [ ] | Hybrid |')
    inventory.write_text(text,encoding='utf8')

if __name__=='__main__': main()
