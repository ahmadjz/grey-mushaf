from pathlib import Path
import json, math
root=Path(__file__).resolve().parent.parent
stages=['stage0','full-grouping','no-filters']
stats={}
lines=['# Full grouping diagnostic performance','',
'All measurements: Medium_Phone emulator, 4096 MB RAM, x86_64, Android API 37, DPR 2.625, profile build, Impeller OpenGLES. No connected physical arm64 phone. Same existing FrameTiming harness, run sequentially with no other heavy job overlapping measurement. No production commits or accepted visual changes.', '',
'Stage 0 is the saved isolated 52e1e11 baseline. Full grouping reinstates the original page/colour-group renderer; all 84 new screenshots equal the archived original full-grouping candidate exactly. No-filter removes word filters and grouping wrappers, setting TextStyle colour directly. COLR/CPAL fonts can retain their palette: this is intentionally incorrect rendering, including markers, and is only a diagnostic estimate of filter overhead. Headings remain unchanged. Fonts were not modified.', '',
'UI/raster values are avg / nearest-rank p90 / worst in milliseconds. Jank is a frame above 16.7 ms in that phase. Frame counts differ because scheduling and missed frames differ; jank count and rate are both shown. Samples include settling/prefetch. Single runs, not confidence intervals.', '',
'| Medium_Phone profile workload | Variant | Frames | UI avg / p90 / worst ms | UI jank count (%) | Raster avg / p90 / worst ms | Raster jank count (%) |',
'|---|---|---:|---|---:|---|---:|']
for stage in stages:
 data=json.loads((root/stage/'frames.json').read_text())['frame_samples_ms']
 stats[stage]={}
 for name, rows in data.items():
  result={'frames':len(rows)}
  for i,phase in enumerate(['ui','raster']):
   a=sorted(r[i] for r in rows)
   count=sum(x>16.7 for x in a)
   result[phase]=dict(avg=sum(a)/len(a),p90=a[math.ceil(.9*len(a))-1],worst=max(a),jank=count,jankPercent=100*count/len(a))
  stats[stage][name]=result
for name in stats['stage0']:
 for stage in stages:
  r=stats[stage][name];u=r['ui'];v=r['raster']
  fmt=lambda a:f'{a["avg"]:.3f} / {a["p90"]:.3f} / {a["worst"]:.3f}'
  lines.append(f'| Medium_Phone {name} | {stage} | {r["frames"]} | {fmt(u)} | {u["jank"]} ({u["jankPercent"]:.2f}%) | {fmt(v)} | {v["jank"]} ({v["jankPercent"]:.2f}%) |')
lines += ['', 'The first swipe is onto a preloaded-but-unpainted neighbour: the existing loaded-page gate prevents a swipe into unloaded page data. The page-450 jump separately measures the first transition into an unloaded page. No cold-launch/PSS sweeps were requested or run for these diagnostic variants.', '',
'Full grouping improves typical raster times substantially on this emulator, but does not remove every slow frame. The 20-swipe portrait worst raster frame is higher than baseline. These runs establish a performance reason to evaluate grouping; they do not establish arm64 performance or permission to accept pixel changes.', '',
'Artifacts: each variant has frames.json, timeline.json, frames.log and production.patch beside this report or under ../no-filters/. The full-grouping production snapshot is also grouped_ink.dart.txt. Reproduction/repeat screenshot comparisons both pass (reproduction-diff.log, repeat-diff.log). The private screenshots remain ignored under ../parity/full-grouping-confirm/.', '',
'Contact sheet: ../../shots/2026-10-24-full-grouping-six-worst.png (gitignored). Six distinct physical-pixel positions ranked by maximum channel delta, with duplicate modes/reveal states collapsed. Each 40x40 crop is upscaled 8x nearest-neighbour; absolute RGB difference is unamplified. The six rows use three images: spread49–50 dark128 unrevealed 2/2,592,000 pixels; page187 dark128 unrevealed 1/2,592,000; page63 dark128 unrevealed 3/2,592,000. Each row labels its own count. All 84 per-image counts are in pixel-counts.md, and selection/crop coordinates in contact-sheet.json. Across all captures there are 84 changed pixels in 44 images, maximum channel delta 50. The 12 page-2 overlap differences have maximum delta 1 and are below the six worst distinct spots.', '',
'Tree: production files restored byte-for-byte to a7c50bc. No commits this turn. New diagnostic scripts, reports, patches and logs remain untracked; private screenshots are ignored. Pre-existing owner changes are untouched. Full-grouping parity used perf-parity-proof.db and deleted it at teardown; all record/device/word identifiers are in ../parity/full-grouping-confirm/capture.json records. No accounts/tokens were created.']
(root/'full-grouping/numbers.md').write_text('\n'.join(lines)+'\n')
(root/'full-grouping/comparison.json').write_text(json.dumps(stats,indent=2)+'\n')
for name in stats['stage0']:
 print(name)
 for stage in stages:print(stage,stats[stage][name])
