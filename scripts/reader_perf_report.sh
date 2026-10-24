#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
import json,math,statistics
root=Path('docs/runs/2026-10-24-perf-after')
lines=['# Staged performance evidence','', 'Every number below is Medium_Phone, 4096 MB RAM, x86_64, API 37, Impeller OpenGLES. No physical arm64 device. Frame samples are profile builds; cold/PSS tables explicitly distinguish profile and release. Runs are sequential, without overlapping heavy jobs.','', 'Frame capture uses engine FrameTiming, not the unbounded VM trace buffer. Timeline JSON contains actual UI/raster phase timestamps and durations. Jank is >16.7 ms; p90 is nearest rank. Capture includes settling and prefetch. Cold starts are process-cold with warm filesystem cache. Reader callback precedes raster/display; Android TotalTime is separate.','', '| Stage / Medium_Phone workload | Frames | UI avg/p90/worst ms | UI jank | Raster avg/p90/worst ms | Raster jank |','|---|---:|---|---:|---|---:|']
for stage in sorted(root.glob('stage*')):
 f=stage/'frames.json'
 if not f.exists(): continue
 for name,frames in json.loads(f.read_text())['frame_samples_ms'].items():
  stats=[]
  for col in range(2):
   a=sorted(row[col] for row in frames);stats.append((sum(a)/len(a),a[math.ceil(.9*len(a))-1],max(a),sum(t>16.7 for t in a)))
  u,r=stats
  lines.append(f'| {stage.name} Medium_Phone {name} | {len(frames)} | {u[0]:.3f}/{u[1]:.3f}/{u[2]:.3f} | {u[3]} | {r[0]:.3f}/{r[1]:.3f}/{r[2]:.3f} | {r[3]} |')
lines += ['', '| Stage / Medium_Phone build | Cold reader median ms | Android display median ms | PSS after 20 MiB | After 604 MiB | Settled MiB | Pages verified |','|---|---:|---:|---:|---:|---:|---:|']
for f in sorted(root.glob('stage*/*/numbers.json')):
 d=json.loads(f.read_text());c=d['cold'];lines.append(f'| {f.parent.parent.name} Medium_Phone {d["build"]} | {statistics.median(x["reader_ms"] for x in c)} | {statistics.median(x["display_ms"] for x in c)} | {d["after20_pss_kib"]/1024:.2f} | {d["after604_pss_kib"]/1024:.2f} | {d["settled_pss_kib"]/1024:.2f} | {d["coverage"]} |')
lines += ['', 'Stage 0 is the clean 52e1e11 production baseline. Compare later rows directly with Stage 0; the earlier investigation measurements were provisional and overlapped host jobs, so they are not used as performance acceptance evidence. Normal swipes cannot enter unloaded page data: first swipe measures preloaded-but-unpainted destination, and page-450 jump separately measures a cold load.', '', 'Parity references: ../2026-10-24-perf-baseline/parity/images/ (ignored private glyph images); 84 combinations: pages 1,2,50,187,604,63 and spread49–50 × six mode/level settings × unrevealed/mixed persisted reveals. Repeat captures must also match exactly. Raw RGBA, zero tolerance, no registration or masks. Capture metadata lists every proof action/word/device identifier; dedicated perf-parity-proof.db is deleted at teardown. No accounts or tokens.']
(root/'numbers.md').write_text('\n'.join(lines)+'\n')
PY
