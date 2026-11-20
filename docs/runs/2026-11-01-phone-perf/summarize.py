import json,math,statistics,collections
from pathlib import Path
p=Path(__file__).parent
label='Redmi Note 9 Pro / arm64 profile / 60Hz'
lines=[f'# Phone measurements — {label}', '', 'Jank: duration > 1000/60.000004 ms; p90 nearest rank. Synthetic 250 ms drags; idle/settle/prefetch included.']
f=p/'frame_samples_ms.json'
if f.exists():
 for name,rows in json.loads(f.read_text()).items():
  parts=[]
  for col in (0,1):
   v=sorted(x[col] for x in rows);parts.append(f'{statistics.mean(v):.3f}/{v[math.ceil(len(v)*.9)-1]:.3f}/{max(v):.3f} ms; {sum(x>1000/60.000004 for x in v)}/{len(v)} over budget')
  lines.append(f'{label} {name}: UI {parts[0]}; raster {parts[1]}')
for mode in ('profile','release'):
 f=p/mode/'numbers.json'
 if f.exists():
  d=json.loads(f.read_text());c=d['cold'];lines.append(f'Redmi Note 9 Pro / arm64 {mode}: cold reader median {statistics.median(x["reader_ms"] for x in c if x["reader_ms"] is not None)} ms; Android display median {statistics.median(x["display_ms"] for x in c if x["display_ms"] is not None)} ms; PSS after 20 turns {d["after20_pss_kib"]/1024:.2f} MiB; changes {len(d["page_changes"])}')
for f in p.glob('*_trace.json'):
 d=json.loads(f.read_text());events=d.get('traceEvents',[]);counts=collections.Counter(e.get('name') for e in events if e.get('ph') in ('B','X'))
 focus={k:v for k,v in counts.items() if any(x in str(k).lower() for x in ('raster','paint','cache','glyph','shader','page','frame'))}
 lines.append(f'{label} {f.name}: {len(events)} events; relevant counts {focus}')
f=p/'motion.json'
if f.exists():
 groups=collections.defaultdict(list)
 for s in json.loads(f.read_text())['swipes']:
  offsets=s['offsets'];groups[(s['blank'],s['landscape'])].append((offsets[-1][0]-s['release_us'])/1000)
 for key,values in groups.items():lines.append(f'{label} blank/landscape={key}: last controller offset after release median {statistics.median(values):.1f} ms (not photon latency)')
(p/'numbers.md').write_text('\n'.join(lines)+'\n');print('\n'.join(lines))
