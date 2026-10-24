# Staged performance evidence

Every number below is Medium_Phone, 4096 MB RAM, x86_64, API 37, Impeller OpenGLES. No physical arm64 device. Frame samples are profile builds; cold/PSS tables explicitly distinguish profile and release. Runs are sequential, without overlapping heavy jobs.

Frame capture uses engine FrameTiming, not the unbounded VM trace buffer. Timeline JSON contains actual UI/raster phase timestamps and durations. Jank is >16.7 ms; p90 is nearest rank. Capture includes settling and prefetch. Cold starts are process-cold with warm filesystem cache. Reader callback precedes raster/display; Android TotalTime is separate.

| Stage / Medium_Phone workload | Frames | UI avg/p90/worst ms | UI jank | Raster avg/p90/worst ms | Raster jank |
|---|---:|---|---:|---|---:|
| stage0 Medium_Phone portrait_first_glyph_cold_swipe | 59 | 0.222/0.236/3.538 | 0 | 14.777/17.308/20.211 | 18 |
| stage0 Medium_Phone portrait_20_swipes | 796 | 0.777/0.395/23.239 | 10 | 23.800/41.859/100.429 | 444 |
| stage0 Medium_Phone unloaded_page_450_jump | 2 | 6.825/13.593/13.593 | 0 | 85.397/155.923/155.923 | 1 |
| stage0 Medium_Phone landscape_20_swipes | 926 | 1.684/0.539/50.718 | 40 | 22.734/54.415/108.777 | 361 |
| stage1-hybrid Medium_Phone portrait_first_glyph_cold_swipe | 59 | 0.229/0.236/3.852 | 0 | 14.881/19.125/23.049 | 22 |
| stage1-hybrid Medium_Phone portrait_20_swipes | 797 | 0.845/0.390/43.352 | 10 | 24.255/42.506/104.369 | 447 |
| stage1-hybrid Medium_Phone unloaded_page_450_jump | 2 | 6.913/13.739/13.739 | 0 | 88.026/167.703/167.703 | 1 |
| stage1-hybrid Medium_Phone landscape_20_swipes | 925 | 1.720/0.523/47.218 | 39 | 22.813/54.353/132.242 | 419 |

| Stage / Medium_Phone build | Cold reader median ms | Android display median ms | PSS after 20 MiB | After 604 MiB | Settled MiB | Pages verified |
|---|---:|---:|---:|---:|---:|---:|
| stage0 Medium_Phone profile | 450 | 521 | 171.36 | 336.64 | 334.90 | 604 |
| stage0 Medium_Phone release | 296 | 358 | 127.96 | 295.54 | 294.03 | 604 |
| stage1-hybrid Medium_Phone profile | 432 | 502 | 171.58 | 337.00 | 336.03 | 604 |
| stage1-hybrid Medium_Phone release | 299 | 370 | 127.28 | 296.72 | 295.34 | 604 |

Stage 0 is the clean 52e1e11 production baseline. Compare later rows directly with Stage 0; the earlier investigation measurements were provisional and overlapped host jobs, so they are not used as performance acceptance evidence. Normal swipes cannot enter unloaded page data: first swipe measures preloaded-but-unpainted destination, and page-450 jump separately measures a cold load.

Parity references: ../2026-10-24-perf-baseline/parity/images/ (ignored private glyph images); 84 combinations: pages 1,2,50,187,604,63 and spread49–50 × six mode/level settings × unrevealed/mixed persisted reveals. Repeat captures must also match exactly. Raw RGBA, zero tolerance, no registration or masks. Capture metadata lists every proof action/word/device identifier; dedicated perf-parity-proof.db is deleted at teardown. No accounts or tokens.

Stage 1 hybrid: exact parity 0 pixels / 84 captures; repeat 0. All 61 tests and analyzer passed. Conservative fallback fractions on Medium_Phone: portrait 99.9534%, landscape 99.9857%; every requested parity-page word remains per-word. No frame-time speedup established. See hybrid/evidence.md and hybrid/fractions.json. Stages 2–3 not started (worker tool-call limit); physical arm64 and Android-process-restart persistence proof not run.
