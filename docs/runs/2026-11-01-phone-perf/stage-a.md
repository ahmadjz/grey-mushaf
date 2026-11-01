# Stage A — bounded final-colour page images

Redmi Note 9 Pro (2be3110f), arm64 profile, Impeller OpenGLES, 60 Hz. Same 250 ms drag harness and workload as Step 1. Frame budget 16.666666 ms; p90 nearest rank. Counts are over-budget raster durations, not measured missed presentations.

| Workload | Baseline raster avg/p90/worst ms | Cache raster avg/p90/worst ms | Baseline over budget | Cache over budget |
|---|---|---|---:|---:|
| portrait_first_glyph_cold_swipe | 6.837/11.882/18.033 | 5.567/16.186/20.0 | 1/55 | 4/50 |
| portrait_20_swipes | 12.177/22.038/151.935 | 5.237/7.78/49.406 | 152/989 | 28/792 |
| landscape_20_swipes | 10.04/14.809/82.676 | 6.764/10.169/68.937 | 92/1048 | 55/753 |
| blank_portrait_20_swipes | 3.218/3.806/19.235 | 4.624/6.223/34.895 | 1/1096 | 1/1081 |
| blank_landscape_20_swipes | 3.189/3.752/9.441 | 4.752/6.395/15.084 | 0/1171 | 0/1168 |

Controller last-offset-after-release medians (reader portrait/landscape): {'(False, False)': 630.7, '(False, True)': 713.3, '(True, False)': 595.7, '(True, True)': 679.1} ms. Stage A retains the original spring. These are injected gesture/controller proxies, not hardware input latency.

Analysis and all 72 tests pass. Capture-slot regression failed before serialized waiting; fractional-drag regression failed with an image origin at -0.75 physical pixels before scroll translation was removed. Both now pass. Saved notification invalidates immediately; live hit-testing/semantics remain. Cache retains at most 2 portrait or 4 landscape pages and 24 MiB including one pending capture.

Phone R40 matrix includes page 50 reached by a fractional drag. 84 images pass R40 with identical geometry; repeat capture passes exact comparison. Numeric results: `../shots/cache-fixed-r40.json` and `../shots/cache-fixed-repeat.json`. Captures/record identifiers: `../shots/phone-cache-fixed-parity/capture.json`; temporary perf-parity-proof.db and its records deleted by harness finally. No accounts/tokens.

Raw phone results: `../shots/phone-cache-fixed-perf/`; actual exit codes and bounded command logs: `../shots/stage-a-stable.log`. Bounded selected timeline spans and layout diagnostics: `../shots/phone-cache-fixed-perf/bounded-timeline.json` (maximum 6000 spans per orientation). Layout instrumentation is enabled only in separate trace windows after headline samples.

The initial no-retry prototype and its measurements are superseded. An earlier matrix had one transient page-187 first capture with different line positions; the immediate repeat was exact and glyph colour counts were identical. The final harness requires stable native viewport metrics and live geometry plus ready visible page images across repeated probes before capture, and asserts geometry stability across both screenshots. The failed numeric proof is retained as cache-fixed-r40-transient.json; the R40 threshold remains unchanged. The first existing-app trace run failed due DDS; existing-app proofs use --no-dds. Each revised parity/performance APK was built once and installed once successfully. Temporary builds before the pixel-phase fix were not installed.

Release cold median-of-five and full-604 phone PSS remain pending; Stage A profile results do not establish the final R39 memory gate. Stage B and C are separate.
