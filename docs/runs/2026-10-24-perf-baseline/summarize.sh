#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
python3 - <<'PY'
import json,math,re,statistics,collections
from pathlib import Path
p=Path('docs/runs/2026-10-24-perf-baseline')
d=json.loads((p/'timeline.json').read_text())
if 'frame_samples_ms' in d:
 samples=d.pop('frame_samples_ms')
 (p/'frame-samples.json').write_text(json.dumps(samples))
 all_events=[]; counts={}
 for name,trace in d.items():
  events=trace['traceEvents']; all_events.extend(events)
  counts[name]=dict(collections.Counter(e.get('name') for e in events if e.get('ph') in ('B','X')))
 (p/'trace-counts.json').write_text(json.dumps(counts,indent=2))
 (p/'timeline.json').write_text(json.dumps({'traceEvents':all_events}))
else:
 samples=json.loads((p/'frame-samples.json').read_text())
lines=['# Performance baseline — 52e1e11', '',
'Device for EVERY measurement below: **Medium_Phone emulator, 4096 MB guest RAM, Android 17/API 37, x86_64, Impeller OpenGLES; not the owner’s arm64 phone.** Physical adb devices were absent. Profile builds; production code unchanged.', '',
'FrameTiming buildDuration = UI; rasterDuration = raster. All times milliseconds. p90 uses nearest rank; janky means strictly >16.7 ms on the indicated thread. Counts are frames, not vsync intervals or GPU-completion timings. Capture includes gesture, settle/prefetch and timing flush; no artificial 60fps cap. Portrait first swipe 1→2, then 20 swipes 2→22; landscape 449–450 through 489–490 (20 spread turns). Swipes move 75% viewport width in 250 ms, followed by settling and 500 ms delay. Assertions verified each turn. Trace overhead is included. IMPORTANT: these are the successful PILOT measurements, not an isolated final baseline. Analyzer/full tests overlapped part of portrait and landscape capture; host contention may inflate timings. Independent cold/PSS measurements have no concurrent test/build jobs.', '',
'| Medium_Phone workload | Frames | UI avg / p90 / worst | UI >16.7 | Raster avg / p90 / worst | Raster >16.7 | Either >16.7 |',
'|---|---:|---|---:|---|---:|---:|']
for name,frames in samples.items():
 vals=[]
 for a in zip(*frames):
  a=sorted(a); vals.append((sum(a)/len(a),a[math.ceil(.9*len(a))-1],max(a),sum(x>16.7 for x in a)))
 u,r=vals
 lines.append(f'| Medium_Phone {name} | {len(frames)} | {u[0]:.3f} / {u[1]:.3f} / {u[2]:.3f} | {u[3]} | {r[0]:.3f} / {r[1]:.3f} / {r[2]:.3f} | {r[3]} | {sum(max(f)>16.7 for f in frames)} |')
lines += ['', 'An ordinary swipe into a JSON/font-unloaded page is **not available in this implementation**: LoadedPagePhysics clamps it to the ready window. The first swipe measures first destination painting with preloaded fonts. The page-450 sample is a separate unloaded programmatic jump, not a swipe.', '',
'Cold launch: ordinary lib/main.dart profile APK, force-stop then device-epoch timestamp + am start -W. Five trials, warm filesystem cache. Reader time is READER_FIRST_FRAME post-frame callback, not raster completion; Android TotalTime is reported separately. PSS is dumpsys meminfo TOTAL PSS, sampled after two seconds; KiB / 1024 = MiB.', '',
'| Medium_Phone trial | Reader callback ms | Android TotalTime ms | PSS MiB |','|---|---:|---:|---:|']
readers=[]; displays=[]
for i in range(1,6):
 s=(p/f'cold-{i}.txt').read_text(); start=int(s.splitlines()[0]); end=int(re.search(r'READER_FIRST_FRAME (\d+)',s)[1]); total=int(re.search(r'TotalTime: (\d+)',s)[1]); mem=(p/f'pss-cold-{i}.txt').read_text(); kb=int(re.search(r'TOTAL PSS:\s+(\d+)',mem)[1]); readers.append(end-start);displays.append(total)
 lines.append(f'| Medium_Phone {i} | {end-start} | {total} | {kb/1024:.2f} |')
lines += ['',f'Medium_Phone median reader callback: {statistics.median(readers)} ms; median Android display: {statistics.median(displays)} ms.', '', 'Normal profile full-read PSS (no trace buffer or integration test):']
for row in (p/'read-all-summary.jsonl').read_text().splitlines():
 try: value=json.loads(row)
 except ValueError: continue
 if 'pss_kib' in value: lines.append(f'- Medium_Phone {value["phase"]}: {value["pss_kib"]/1024:.2f} MiB.')
 else: lines.append(f'- Medium_Phone page coverage: {value}.')
lines += ['', 'Checks: flutter analyze clean; full flutter test result in tests.log; successful profile assertions/result in profile-retry.log. Pilot DDS connection failure corrected with --no-dds. Bounded trace ring truncated; FrameTiming lists cover the complete successful workload but event traces retain only tails. Two isolated endless-buffer attempts (full and focused tracing) exhausted emulator memory/service connection. No further profiling retry under the two-attempt rule. Successful bounded pilot numbers retained with contention caveat; these are provisional, not a clean comparison baseline. Harness restored to bounded configuration. Timeline JSON and raw frame samples retained.', '',
'Rerun: bash run-profile.sh; build/install normal profile lib/main.dart APK (heavy env GRADLE_OPTS=-Dorg.gradle.daemon=false flutter build apk --profile --target=lib/main.dart --target-platform android-x64 from app/), then bash cold-start.sh; bash read-all.sh > read-all-summary.jsonl; bash summarize.sh (scripts resolve repository paths; redirect full-read output into this directory). Run without competing heavy jobs. See investigation.md for code evidence, design, parity proposal and four requested lists.', '',
'Created accounts/tokens/reveal records: none. No reveal gestures or sign-in used; existing SQLite settings/device identity may be opened by app startup and were not cleared. No server access. Commits: none. Production changes: none. Real phone/arm64, conversion and pixel-diff proof: not run (phone unavailable; implementation deferred).']
(p/'numbers.md').write_text('\n'.join(lines)+'\n')
print('\n'.join(lines))
PY
