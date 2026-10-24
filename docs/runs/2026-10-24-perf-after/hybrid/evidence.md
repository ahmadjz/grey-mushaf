# Stage 1: conservative hybrid filters

Base production 52e1e11; Stage 0 harness dda9f8a. The failed clip probe has been removed from production and capture code; its generated clip-probe.json asset was deleted. No source font changed or converted. Prior failed-run evidence remains for provenance.

Medium_Phone emulator, 4096 MB, x86_64, API 37, DPR 2.625, Impeller OpenGLES, profile. The owner's arm64 phone is not connected.

Prepared horizontal word extents and whole-font yMin/yMax define the conservative ink rectangle. It is expanded by two physical pixels. A word is grouped only if that padded rectangle fits inside its own layout box and does not overlap any other padded word rectangle on the page. All other words paint the unchanged two-filter FlatInk subtree in original order. Headings and layout remain unchanged. Grouped words bypass only those two filters and retain the original render-tree transform. No clipping or native bounds instrumentation is used.

The split is evaluated from actual laid-out rectangles; the reusable app/tool/hybrid_report.dart computes the same rule over prepared metrics for all 604 pages. The report cross-checks its parity-case counts against captured geometry. Fractions depend on viewport/DPR; these numbers describe the named emulator in fullscreen portrait and landscape.

| Medium_Phone view/case | Per-word | Total words | Per-word fraction |
|---|---:|---:|---:|
| All 604 pages portrait | 83629 | 83668 | 99.9534% |
| All 604 pages landscape | 83656 | 83668 | 99.9857% |
| Portrait page 1 | 36 | 36 | 100% |
| Portrait page 2 | 41 | 41 | 100% |
| Portrait page 50 | 144 | 144 | 100% |
| Portrait page 187 | 127 | 127 | 100% |
| Portrait page 604 | 73 | 73 | 100% |
| Portrait marker-exception page 63 | 137 | 137 | 100% |
| Landscape spread 49–50 | 284 | 284 | 100% |

Exact reference diff: **0 differing RGBA pixels in all 84 captures**. Repeat diff: **0**. No alignment, threshold or masks. The requested parity pages all use the fallback path; this result is not proof of real-font grouped rendering on the other pages. The synthetic translated-paint test exercises an eligible group and compares it against original FlatInk. Only 39 portrait and 12 landscape words are eligible across the full bundle, so no material raster improvement is expected from this split alone.

Checks: classifier red-first test failed for missing groupableInk (red.log), then classifier and translated paint tests passed (green.log). Analyzer passed (analyze.log). Full suite passed: all 61 tests (tests.log). Reference/repeat diff logs and fractions.log passed. fractions.json contains all page counts. capture metadata and images are ignored under ../parity/hybrid/; private glyph images and fonts must never be committed.

The dedicated perf-parity-proof.db was deleted at capture teardown. Every temporary record/device/word identifier is listed in ../parity/hybrid/capture.json records; no accounts or tokens were created. Normal reveals.db was untouched. Capture verifies SQLite close/reopen persistence and Reader recreation; Android process-restart persistence was not run.

Performance acceptance is recorded separately after the isolated harness completes. Stage 2 and Stage 3 are not included in this change.

## Isolated measurement result

The profile and release harness completed sequentially after the full test suite, without overlapping heavy jobs. Both normal-app sweeps verified all 604 pages. See ../numbers.md for complete baseline/after tables, ../stage1-hybrid/timeline.json for the FrameTiming timeline, and ../stage1-hybrid/{profile,release}/numbers.json plus dumpsys logs for memory/cold evidence.

Medium_Phone profile portrait raster average: 24.255 ms vs baseline 23.800; landscape: 22.813 vs 22.734. First glyph-cold swipe raster p90: 19.125 vs 17.308 ms. No performance improvement established. Medium_Phone release PSS after all 604 pages: 296.72 MiB (baseline 295.54); settled: 295.34 MiB (baseline 294.03). Release median of five reader-ready starts: 299 ms; Android display median: 370 ms. Emulator release R39 thresholds pass, with a narrow memory margin; physical arm64 acceptance remains unverified.

Stage 2 and Stage 3 were not started before the worker's 60-tool-call limit. They remain authorized continuation work; no new owner decision is needed. Process-restart persistence proof also remains unrun. The launcher's initial direct invocation failed because it lacks an executable bit; invoking the unchanged launcher with bash completed successfully. No performance retry was used to select better numbers.
