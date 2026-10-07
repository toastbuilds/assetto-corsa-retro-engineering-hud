"""Merge independent export manifests in numeric worker order (last wins)."""
import json
from pathlib import Path
out=Path(__file__).resolve().parents[1]
files=sorted(out.glob('motion-worker-*.json'),key=lambda p:int(p.stem.rsplit('-',1)[1]))
merged={}
for path in files:
    for record in json.loads(path.read_text()):
        record['loop']='Closed main driving cycle; auxiliary scales/history can retain observed maxima; clocks and timing events restart.'
        merged[record['path']]=record
actual={p.relative_to(out).as_posix() for p in (out/'videos').glob('*.mp4')}
assert set(merged)==actual,(set(merged)^actual)
(out/'motion-manifest.json').write_text(json.dumps(list(merged.values()),indent=2),encoding='utf8')
print(f'Merged {len(merged)} clips')
