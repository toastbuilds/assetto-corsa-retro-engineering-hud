"""Re-export the four native Timer result states (all timing deltas in ms)."""
import importlib.util,json,os
from pathlib import Path
spec=importlib.util.spec_from_file_location('promo_timing',Path(__file__).with_name('generate.py'))
g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
os.chdir(g.ROOT)
records=json.loads((g.OUT/'stills-manifest.json').read_text())
p=g.Harness(panels=True)
for status in ('session_best','personal_best','slower','invalid'):
    g.fixture(p,result=dict(time=132110,delta=-535 if 'best' in status else 400,status=status,valid=status!='invalid'))
    g.save(g.padded(p.draw('timer_native',factor=3),700),Path(f'instruments/digital/timer_result_{status}.png'),records,instrument='Timer result',status=status)
records={r['path']:r for r in records}
(g.OUT/'stills-manifest.json').write_text(json.dumps(list(records.values()),indent=2),encoding='utf8')
