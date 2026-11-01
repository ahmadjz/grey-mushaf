# Phone performance after page caching and faster settling

Redmi Note 9 Pro (2be3110f), Android 12, arm64, Impeller OpenGLES, 60 Hz. Step 1 is the same-phone baseline in report.md. Profile frame timings use identical 250 ms synthetic drags; p90 is nearest rank. Over-budget durations are not measured missed presentations.

| Workload | Step 1 raster avg/p90/worst ms | Stage A | Stage B | Step 1 / A / B over budget |
|---|---|---|---|---|
| portrait_first_glyph_cold_swipe | 6.837/11.882/18.033 | 5.567/16.186/20.0 | 3.718/5.205/7.888 | 1/55 / 4/50 / 0/28 |
| portrait_20_swipes | 12.177/22.038/151.935 | 5.237/7.78/49.406 | 5.274/10.081/50.278 | 152/989 / 28/792 / 30/404 |
| landscape_20_swipes | 10.04/14.809/82.676 | 6.764/10.169/68.937 | 4.577/7.982/59.842 | 92/1048 / 55/753 / 4/403 |

The first cold swipe did not improve consistently: Stage A raster p90 rose from 11.882 to 16.186 ms. The sustained-swipe improvement does not establish a cold-swipe gain.

| Workload UI avg/p90/worst ms | Stage A | Stage B |
|---|---|---|
| portrait_20_swipes | 3.518/1.847/103.901 | 2.859/1.294/68.909 |
| landscape_20_swipes | 5.098/2.1/150.728 | 4.95/4.832/72.425 |

Step 1 UI avg/p90/worst was 1.511/0.833/78.203 ms portrait and 1.992/0.844/73.902 ms landscape. UI outliers remain and worsened in Stage A; the cache primarily reduces sustained raster cost.

| Reader settle median | Step 1 | Stage A | Stage B |
|---|---:|---:|---:|
| Portrait | 630.0 ms | 630.7 ms | 157.1 ms |
| Landscape | 710.3 ms | 713.3 ms | 176.0 ms |

Settle is the last controller-offset timestamp after injected release, not hardware touch-to-photon latency. Step 1 blank-pager medians were 599.7/682.6 ms.

| Release measure | Step 1 | Final |
|---|---:|---:|
| Reader cold median, five launches | 1176 ms | 1200 ms |
| Android TotalTime median, five launches | 1255 ms | 1286 ms |
| PSS after 20 turns | 168.81 MiB | 184.68 MiB |
| PSS at page 604 | Not measured | 347.93 MiB |
| PSS settled after all 604 | Not measured | 346.91 MiB |
| Maximum sampled PSS | Not measured across 604 | 347.93 MiB |

Cold means force-stopped process with warm disk/font caches. All 604 page identifiers were verified in order in one release process. PSS was sampled at start and pages 21/81/161/241/321/401/481/561/604 and after 30 seconds idle. R39 FAILS: sampled release PSS exceeds 300 MiB; memory acceptance remains open; this is not continuous memory tracing.

Memory follow-up: page JSON already evicts outside the nearby window (mushaf_bundle.dart:104), while registered page fonts accumulate for the process lifetime (mushaf_bundle.dart:72). Retained fonts are a candidate cause, not an isolated measurement. The image allocation budget is 24 MiB; reducing it alone is not demonstrated to recover the roughly 48 MiB excess. No memory fix or full-604 baseline A/B was run.

Stage C: the separate layout-instrumented trace is summarized below. Existing line renderers reuse TextPainter paragraphs keyed by word, width, style and text. New incoming lines create and shape their paragraphs in _LineRender.performLayout. Bundle refresh checks parsed-page identity before rebuilding an existing page. Moving paragraph creation out of layout needs geometry-aware prewarming and bounded lifetime management; no cheap, parity-safe fix was established, so no Stage C production change was made.

| Separate Stage A trace | Largest LAYOUT span | Largest _LineRender span |
|---|---:|---:|
| portrait | 49.091 ms | 10.497 ms |
| landscape | 118.522 ms | 10.002 ms |

The trace localizes inclusive layout cost; paragraph shaping is a source-supported inference, not an isolated shaping benchmark. Instrumented spans must not be added to headline frame samples. bounded-timeline.json retains at most 1000 longest selected spans per orientation plus aggregate diagnostics.

Evidence: stage-a.md and stage-b.md; ../shots/cache-fixed-{r40,repeat}.json and ../shots/settle-{r40,repeat}.json (84 images each, identical geometry); ../shots/phone-cache-fixed-perf/ and ../shots/phone-settle-perf/; ../shots/final-phone-release/numbers.json, cold-*.txt and pss-*.txt. Actual command exits are in ../shots/stage-a-stable.log, ../shots/stage-b.log and ../shots/final-release-run.log.

Temporary parity records are identified in each capture.json; perf-parity-proof.db was deleted in finally. No accounts or tokens were created. The release build remains installed. The original stay-awake setting was restored.

Not measured: physical pointer-to-photon latency, compositor presentation loss, a native/reference-app pager on the phone, and an isolated paragraph-shaping A/B. Synthetic gestures, thermal state, charging and sequential measurement order limit generalization.
