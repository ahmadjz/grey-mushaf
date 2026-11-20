import json, sys
from pathlib import Path

def pct(xs, p):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, max(0, -(-len(xs) * p // 100) - 1))] if xs else 0

for d in sys.argv[1:]:
    d = Path(d)
    samples = json.loads((d / 'frame_samples_ms.json').read_text())
    arrows = json.loads((d / 'motion.json').read_text()).get('arrows', [])
    print(d.name)
    for name, frames in samples.items():
        if 'arrow' not in name and '20_swipes' not in name:
            continue
        b = [f[0] for f in frames]; r = [f[1] for f in frames]
        over = sum(1 for x, y in zip(b, r) if max(x, y) > 16.7)
        print(f'  {name:26} frames {len(frames):4}  build p90 {pct(b,90):5.1f} max {max(b):5.1f}  raster p90 {pct(r,90):5.1f} max {max(r):5.1f}  >16.7ms {over}')
    for orient in (False, True):
        rows = [a for a in arrows if a['landscape'] == orient]
        if rows:
            print(f"  {'landscape' if orient else 'portrait':9} arrow turns {len(rows)}  sliding updates {sum(a['sliding_updates'] for a in rows)}")
