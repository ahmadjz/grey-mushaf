# Full grouping diagnostic performance

All measurements: Medium_Phone emulator, 4096 MB RAM, x86_64, Android API 37, DPR 2.625, profile build, Impeller OpenGLES. No connected physical arm64 phone. Same existing FrameTiming harness, run sequentially with no other heavy job overlapping measurement. No production commits or accepted visual changes.

Stage 0 is the saved isolated 52e1e11 baseline. Full grouping reinstates the original page/colour-group renderer; all 84 new screenshots equal the archived original full-grouping candidate exactly. No-filter removes word filters and grouping wrappers, setting TextStyle colour directly. COLR/CPAL fonts can retain their palette: this is intentionally incorrect rendering, including markers, and is only a diagnostic estimate of filter overhead. Headings remain unchanged. Fonts were not modified.

UI/raster values are avg / nearest-rank p90 / worst in milliseconds. Jank is a frame above 16.7 ms in that phase. Frame counts differ because scheduling and missed frames differ; jank count and rate are both shown. Samples include settling/prefetch. Single runs, not confidence intervals.

| Medium_Phone profile workload | Variant | Frames | UI avg / p90 / worst ms | UI jank count (%) | Raster avg / p90 / worst ms | Raster jank count (%) |
|---|---|---:|---|---:|---|---:|
| Medium_Phone portrait_first_glyph_cold_swipe | stage0 | 59 | 0.222 / 0.236 / 3.538 | 0 (0.00%) | 14.777 / 17.308 / 20.211 | 18 (30.51%) |
| Medium_Phone portrait_first_glyph_cold_swipe | full-grouping | 60 | 0.239 / 0.226 / 4.141 | 0 (0.00%) | 2.721 / 5.463 / 6.892 | 0 (0.00%) |
| Medium_Phone portrait_first_glyph_cold_swipe | no-filters | 60 | 0.235 / 0.219 / 4.316 | 0 (0.00%) | 1.588 / 3.181 / 4.580 | 0 (0.00%) |
| Medium_Phone portrait_20_swipes | stage0 | 796 | 0.777 / 0.395 / 23.239 | 10 (1.26%) | 23.800 / 41.859 / 100.429 | 444 (55.78%) |
| Medium_Phone portrait_20_swipes | full-grouping | 1047 | 0.590 / 0.260 / 24.661 | 9 (0.86%) | 16.824 / 16.905 / 127.653 | 307 (29.32%) |
| Medium_Phone portrait_20_swipes | no-filters | 1103 | 0.527 / 0.259 / 23.334 | 8 (0.73%) | 12.949 / 16.815 / 69.984 | 230 (20.85%) |
| Medium_Phone unloaded_page_450_jump | stage0 | 2 | 6.825 / 13.593 / 13.593 | 0 (0.00%) | 85.397 / 155.923 / 155.923 | 1 (50.00%) |
| Medium_Phone unloaded_page_450_jump | full-grouping | 2 | 6.378 / 12.650 / 12.650 | 0 (0.00%) | 27.674 / 40.368 / 40.368 | 1 (50.00%) |
| Medium_Phone unloaded_page_450_jump | no-filters | 2 | 6.092 / 12.094 / 12.094 | 0 (0.00%) | 27.893 / 40.305 / 40.305 | 1 (50.00%) |
| Medium_Phone landscape_20_swipes | stage0 | 926 | 1.684 / 0.539 / 50.718 | 40 (4.32%) | 22.734 / 54.415 / 108.777 | 361 (38.98%) |
| Medium_Phone landscape_20_swipes | full-grouping | 1155 | 1.301 / 0.244 / 50.908 | 40 (3.46%) | 15.628 / 16.890 / 62.657 | 330 (28.57%) |
| Medium_Phone landscape_20_swipes | no-filters | 1167 | 1.175 / 0.255 / 44.045 | 39 (3.34%) | 14.816 / 16.866 / 67.867 | 293 (25.11%) |

The first swipe is onto a preloaded-but-unpainted neighbour: the existing loaded-page gate prevents a swipe into unloaded page data. The page-450 jump separately measures the first transition into an unloaded page. No cold-launch/PSS sweeps were requested or run for these diagnostic variants.

Full grouping improves typical raster times substantially on this emulator, but does not remove every slow frame. The 20-swipe portrait worst raster frame is higher than baseline. These runs establish a performance reason to evaluate grouping; they do not establish arm64 performance or permission to accept pixel changes.

Artifacts: each variant has frames.json, timeline.json, frames.log and production.patch beside this report or under ../no-filters/. The full-grouping production snapshot is also grouped_ink.dart.txt. Reproduction/repeat screenshot comparisons both pass (reproduction-diff.log, repeat-diff.log). The private screenshots remain ignored under ../parity/full-grouping-confirm/.

Contact sheet: ../../shots/2026-10-24-full-grouping-six-worst.png (gitignored). Six distinct physical-pixel positions ranked by maximum channel delta, with duplicate modes/reveal states collapsed. Each 40x40 crop is upscaled 8x nearest-neighbour; absolute RGB difference is unamplified. The six rows use three images: spread49–50 dark128 unrevealed 2/2,592,000 pixels; page187 dark128 unrevealed 1/2,592,000; page63 dark128 unrevealed 3/2,592,000. Each row labels its own count. All 84 per-image counts are in pixel-counts.md, and selection/crop coordinates in contact-sheet.json. Across all captures there are 84 changed pixels in 44 images, maximum channel delta 50. The 12 page-2 overlap differences have maximum delta 1 and are below the six worst distinct spots.

Tree: production files restored byte-for-byte to a7c50bc. No commits this turn. New diagnostic scripts, reports, patches and logs remain untracked; private screenshots are ignored. Pre-existing owner changes are untouched. Full-grouping parity used perf-parity-proof.db and deleted it at teardown; all record/device/word identifiers are in ../parity/full-grouping-confirm/capture.json records. No accounts/tokens were created.

Checks after restoration: flutter analyze passed; flutter test --concurrency=2 passed (61 tests); Python suite passed (26 tests); normal profile APK rebuilt and reinstalled. All 18 contact-sheet panels verified pixel-for-pixel against source crops/differences at 8x nearest-neighbour. git diff -- app is empty and HEAD remains a7c50bc. No commits were made. Physical arm64, cold-launch/PSS sweeps and Android-process-restart reveal proof were not run for these diagnostic variants.
