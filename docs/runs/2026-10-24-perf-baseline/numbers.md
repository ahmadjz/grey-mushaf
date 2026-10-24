# Performance baseline — 52e1e11

Device for EVERY measurement below: **Medium_Phone emulator, 4096 MB guest RAM, Android 17/API 37, x86_64, Impeller OpenGLES; not the owner’s arm64 phone.** Physical adb devices were absent. Profile builds; production code unchanged.

FrameTiming buildDuration = UI; rasterDuration = raster. All times milliseconds. p90 uses nearest rank; janky means strictly >16.7 ms on the indicated thread. Counts are frames, not vsync intervals or GPU-completion timings. Capture includes gesture, settle/prefetch and timing flush; no artificial 60fps cap. Portrait first swipe 1→2, then 20 swipes 2→22; landscape 449–450 through 489–490 (20 spread turns). Swipes move 75% viewport width in 250 ms, followed by settling and 500 ms delay. Assertions verified each turn. Trace overhead is included. IMPORTANT: these are the successful PILOT measurements, not an isolated final baseline. Analyzer/full tests overlapped part of portrait and landscape capture; host contention may inflate timings. Independent cold/PSS measurements have no concurrent test/build jobs.

| Medium_Phone workload | Frames | UI avg / p90 / worst | UI >16.7 | Raster avg / p90 / worst | Raster >16.7 | Either >16.7 |
|---|---:|---|---:|---|---:|---:|
| Medium_Phone portrait_first_glyph_cold_swipe | 59 | 0.282 / 0.306 / 3.898 | 0 | 15.147 / 18.471 / 26.749 | 19 | 19 |
| Medium_Phone portrait_20_swipes | 778 | 0.831 / 0.457 / 29.095 | 9 | 24.544 / 43.567 / 114.080 | 424 | 424 |
| Medium_Phone unloaded_page_450_jump | 2 | 6.820 / 13.579 / 13.579 | 0 | 68.754 / 131.765 / 131.765 | 1 | 1 |
| Medium_Phone landscape_20_swipes | 860 | 2.106 / 0.713 / 58.847 | 40 | 24.615 / 60.579 / 115.373 | 386 | 405 |

An ordinary swipe into a JSON/font-unloaded page is **not available in this implementation**: LoadedPagePhysics clamps it to the ready window. The first swipe measures first destination painting with preloaded fonts. The page-450 sample is a separate unloaded programmatic jump, not a swipe.

Cold launch: ordinary lib/main.dart profile APK, force-stop then device-epoch timestamp + am start -W. Five trials, warm filesystem cache. Reader time is READER_FIRST_FRAME post-frame callback, not raster completion; Android TotalTime is reported separately. PSS is dumpsys meminfo TOTAL PSS, sampled after two seconds; KiB / 1024 = MiB.

| Medium_Phone trial | Reader callback ms | Android TotalTime ms | PSS MiB |
|---|---:|---:|---:|
| Medium_Phone 1 | 629 | 704 | 108.57 |
| Medium_Phone 2 | 435 | 501 | 107.79 |
| Medium_Phone 3 | 439 | 519 | 107.03 |
| Medium_Phone 4 | 449 | 530 | 107.27 |
| Medium_Phone 5 | 455 | 526 | 106.98 |

Medium_Phone median reader callback: 449 ms; median Android display: 526 ms.

Normal profile full-read PSS (no trace buffer or integration test):
- Medium_Phone read-start: 109.54 MiB.
- Medium_Phone read-20: 170.89 MiB.
- Medium_Phone read-80: 186.82 MiB.
- Medium_Phone read-160: 213.37 MiB.
- Medium_Phone read-240: 237.94 MiB.
- Medium_Phone read-320: 264.09 MiB.
- Medium_Phone read-400: 288.36 MiB.
- Medium_Phone read-480: 315.07 MiB.
- Medium_Phone read-560: 337.54 MiB.
- Medium_Phone page coverage: {'unique_pages': 604, 'missing': []}.
- Medium_Phone after-604-immediate: 335.97 MiB.
- Medium_Phone after-604-settled: 334.42 MiB.

R39 on Medium_Phone profile: startup passes; full-session PSS fails the 300 MiB limit. No release/arm64 inference.

Checks: flutter analyze clean; 58 Flutter tests passed; full flutter test result in tests.log; successful profile assertions/result in profile-retry.log. Pilot DDS connection failure corrected with --no-dds. Bounded trace ring truncated; FrameTiming lists cover the complete successful workload but event traces retain only tails. Two isolated endless-buffer attempts (full and focused tracing) exhausted emulator memory/service connection. No further profiling retry under the two-attempt rule. Successful bounded pilot numbers retained with contention caveat; these are provisional, not a clean comparison baseline. Harness restored to bounded configuration. Timeline JSON and raw frame samples retained.

Rerun: bash run-profile.sh; build/install normal profile lib/main.dart APK (heavy env GRADLE_OPTS=-Dorg.gradle.daemon=false flutter build apk --profile --target=lib/main.dart --target-platform android-x64 from app/), then bash cold-start.sh; bash read-all.sh > read-all-summary.jsonl; bash summarize.sh (scripts resolve repository paths; redirect full-read output into this directory). Run without competing heavy jobs. See investigation.md for code evidence, design, parity proposal and four requested lists.

Created accounts/tokens/reveal records: none. No reveal gestures or sign-in used; existing SQLite settings/device identity may be opened by app startup and were not cleared. No server access. Commits: none. Production changes: none. Real phone/arm64, conversion and pixel-diff proof: not run (phone unavailable; implementation deferred).
