# Staged performance evidence

Every number below is Medium_Phone, 4096 MB RAM, x86_64, API 37, Impeller OpenGLES. No physical arm64 device. Frame samples are profile builds; cold/PSS tables explicitly distinguish profile and release. Runs are sequential, without overlapping heavy jobs.

Frame capture uses engine FrameTiming, not the unbounded VM trace buffer. Timeline JSON contains actual UI/raster phase timestamps and durations. Jank is >16.7 ms; p90 is nearest rank. Capture includes settling and prefetch. Cold starts are process-cold with warm filesystem cache. Reader callback precedes raster/display; Android TotalTime is separate.

| Stage / Medium_Phone workload | Frames | UI avg/p90/worst ms | UI jank | Raster avg/p90/worst ms | Raster jank |
|---|---:|---|---:|---|---:|
| stage0 Medium_Phone portrait_first_glyph_cold_swipe | 59 | 0.222/0.236/3.538 | 0 | 14.777/17.308/20.211 | 18 |
| stage0 Medium_Phone portrait_20_swipes | 796 | 0.777/0.395/23.239 | 10 | 23.800/41.859/100.429 | 444 |
| stage0 Medium_Phone unloaded_page_450_jump | 2 | 6.825/13.593/13.593 | 0 | 85.397/155.923/155.923 | 1 |
| stage0 Medium_Phone landscape_20_swipes | 926 | 1.684/0.539/50.718 | 40 | 22.734/54.415/108.777 | 361 |
| stage-final Medium_Phone portrait_first_glyph_cold_swipe | 60 | 0.221/0.236/4.096 | 0 | 2.673/4.794/6.953 | 0 |
| stage-final Medium_Phone portrait_20_swipes | 1044 | 0.443/0.250/12.576 | 0 | 16.853/16.972/101.620 | 313 |
| stage-final Medium_Phone unloaded_page_450_jump | 2 | 5.269/10.484/10.484 | 0 | 23.561/37.263/37.263 | 1 |
| stage-final Medium_Phone landscape_20_swipes | 1216 | 0.566/0.253/27.909 | 23 | 9.070/16.762/47.076 | 165 |

| Stage / Medium_Phone build | Cold reader median ms | Android display median ms | PSS after 20 MiB | After 604 MiB | Settled MiB | Pages verified |
|---|---:|---:|---:|---:|---:|---:|
| stage0 Medium_Phone profile | 450 | 521 | 171.36 | 336.64 | 334.90 | 604 |
| stage0 Medium_Phone release | 296 | 358 | 127.96 | 295.54 | 294.03 | 604 |
| stage-final Medium_Phone profile | 458 | 517 | 145.12 | 323.84 | 322.95 | 604 |
| stage-final Medium_Phone release | 316 | 367 | 102.57 | 279.66 | 278.72 | 604 |

Stage 0 is the clean 52e1e11 production baseline. Compare later rows directly with Stage 0; the earlier investigation measurements were provisional and overlapped host jobs, so they are not used as performance acceptance evidence. Normal swipes cannot enter unloaded page data: first swipe measures preloaded-but-unpainted destination, and page-450 jump separately measures a cold load.

Parity references: ../2026-10-24-perf-baseline/parity/images/ (ignored private glyph images); 84 combinations: pages 1,2,50,187,604,63 and spread49–50 × six mode/level settings × unrevealed/mixed persisted reveals. Repeat captures must also match exactly. Raw RGBA, no registration or masks. R40 accepts at most five changed reference-edge pixels per image, with exact geometry; exact mode remains available. Stage 3 warming was rejected and is not in the final build. Capture metadata lists every proof action/word/device identifier; dedicated perf-parity-proof.db is deleted at teardown. No accounts or tokens.

Final renderer: 735a8f7 (Stage 2); 23f6826 records rejection of the warming experiment and fixes harness app retention. Stage 1: 0ab66b1. Production is unchanged during final capture. Compare 52e1e11..735a8f7 for rendering changes.

R40: 84 images accepted, 84 changed pixels total, maximum 3/image, no non-edge changes, identical word geometry. Exact Stage 1 comparison and exact repeat both pass. Raw evidence: stage2/r40.json and ignored baseline/parity/stage2-final-probe/. Screenshot: ../shots/perf-stage2-page187-dark128.png. Timeline: timeline.json (also stage-final/timeline.json); frame samples: stage-final/frames.json.

Final gates: flutter analyze clean; 64 Flutter tests passed (including R2/R3/R24 gesture and save-order/failure assertions); 26 pytest tests passed. Separate-process durable reveal passed; fixture identifiers and cleanup: stage2/evidence.md and stage2/restart-fixed/{write,read}.json.

R39 release PASS: all 604 pages verified, PSS <300 MiB, five-run cold median <2 seconds. Profile also verified all 604 pages, but its PSS exceeds 300 MiB; the owner's memory gate is against release. Cold measures reader first-frame callback and Android display metric, not camera-measured photon latency.

Warming rejected: stage3/evidence.md. Not run: physical arm64 phone (not connected); warming parity/PSS after its isolated frame regression; legacy integration_test/persistence_test.dart (dedicated restart proof used instead); standalone all_pages_test.dart (full 604-page device sweeps and widget layout coverage used). No claim of real-phone smoothness; portrait raster spikes remain.

Private glyph images, raw logs, timelines and one-off probe patches remain local and uncommitted. No fonts or source assets committed. Owner edits to .claude files and the existing perf-run-log are untouched.

Implementation evidence: app/lib/main.dart:377 (await save before page notification), :611 (drag sampling without reader setState), :751 (page selection without reader setState), :989 (correct inherited text style); app/lib/page_ink.dart:66 (ink-edge hit testing), :114 (word semantics), :199 (fresh paragraph collection). Exact single-word/line probe and corrected full-page evidence are in stage2/evidence.md.
