# Run log: reader performance (2026-10-24)

base 52e1e11 · dirty at start (not ours): .claude/codex-worker-rules.md, .claude/skills/quran-quick/SKILL.md

## Step 1 block

**Problem:** reader lags on the owner's phone while loading and swiping. Medium_Phone profile baseline
(x86_64 emulator, not the phone): portrait raster p90 43.6 ms, 424/778 janky; landscape raster p90
60.6 ms, 386/860 janky; UI thread mostly idle → raster-bound. Cold start 449 ms; PSS after all 604 pages
336 MiB (profile build, over R39's 300).

**Causes (verified):** per-word double ColorFiltered (app/lib/flat_ink.dart:23, main.dart:1031–1052);
per-word widget + GlobalKey (main.dart:406, 1018); reader-wide setState on page change (main.dart:531,765)
and save (378); no glyph warming (mushaf_bundle.dart:71 preloads fonts already).

**Wrong premises:** fonts are already preloaded for neighbouring spreads; _measureBundle reuses prepared
metrics (bookkeeping only); dropping COLR/CPAL is unsafe: marker glyphs are layered (cyan/magenta/pale
field/ink), 8 marker bases differ from their ink layer.

**Design (Claude):** keep the colour fonts. Both filters are per-pixel colour maps, so apply them once per
page per word-colour group (grey words in one filtered layer, black words in another) instead of per word:
~300 saveLayers → 2–4 per page, same maths. Then one painter per page with rect hit-testing and page-scoped
repaint on saved reveals, then bounded glyph warming. Font flattening only if still janky after that.

**Rulings needed:** none. Owner asked for pixel-identical; Claude's default (technical): exact pixels
required, any diff comes back to the owner with images.

**Surfaces:** app/lib/main.dart, app/lib/flat_ink.dart, app/lib/mushaf_bundle.dart, tests, perf harness.

**Proof:** (1) parity diffs pages 1, 2, 50, 187, 604 + spread, light 128/176/224, dark 32/80/128,
unrevealed + revealed; (2) R2/R3/R24 gesture + reveal persistence tests green; (3) after-numbers on the
same harness side by side with baseline; (4) cold start ≤2 s; (5) R39 PSS in release; (6) owner phone
arm64 run; (7) arm64 release APK rebuilt.

**Sessions:** writer 01a16cd7-6851-7362-a310-25c5ee641e74 (new; old writer FULL) · reviewer tbd

## Steps

- 0 baseline: done
- 1 investigate: done (docs/runs/2026-10-24-perf-baseline/)
- 2 rulings: none needed
- 4 implement: in progress
  - dda9f8a parity capture/diff + perf harness (84 reference captures, repeat diff 0)
  - stage 1 full grouping: 84 px changed / 44 of 84 images (≤3 px per 2.59M-px image, max delta 50),
    cause: per-word filter layer trims ink overhang; raster p90 portrait 41.9→16.9 ms, landscape
    54.4→16.9 ms, cold swipe 17.3→5.5 ms (Medium_Phone profile). Contact sheet
    docs/runs/shots/2026-10-24-full-grouping-six-worst.png
  - a7c50bc hybrid (exact by construction) ineffective: 99.95% of words fall back → to be replaced
  - release Medium_Phone: cold 299 ms, PSS after 604 pages 296.72 MiB (R39 met, tight)
- 2b ruling R40 (owner, 7fda5da): speed over invisible edge-pixel parity
  - 0ab66b1 full grouping under R40 gate (84 px / 84 images, max 3/image, edges only, geometry same)
  - 735a8f7 one painter per page, rect hit-testing, page-scoped repaint after save
  - 23f6826 glyph warming tried and rejected (regressed frames)
  - c48ddd9 after-numbers (docs/runs/2026-10-24-perf-after/numbers.md)
- 5 review (reviewer-high 01a16db7-c7fe-7c00-8123-5585173c814a): r1 0/0/2/1 (C/H/M/L)
  - M tests read painter state, not rendered semantics/pixels → fixed 3c10daf (mutation shown to fail)
  - M spread 1|2, 49|50, disposed-page save, .08em, between-word tap untested → fixed a129f2c
  - L hybrid leftovers → fixed 585e085, 4e648bd
  - r2: both M closed, no new findings
- 8 exit:
  - parity: R40 84/84 images pass, fresh rerun identical to accepted build
  - gates: flutter analyze clean · flutter test 69 passed · pytest 26 passed
  - gestures/persistence: R2/R3/R6/R24 tests green; separate-process reveal persistence passed
  - after vs before (Medium_Phone profile, raster avg/p90/worst, jank):
    portrait 23.8/41.9/100.4 (444/796) → 16.9/17.0/101.6 (313/1044);
    landscape 22.7/54.4/108.8 (361/926) → 9.1/16.8/47.1 (165/1216);
    first cold swipe 14.8/17.3/20.2 (18) → 2.7/4.8/7.0 (0); page-450 jump 85.4 → 23.6 avg
  - cold start release median 296 → 316 ms (≤2 s met); PSS release after 604 pages 295.5 → 279.7 MiB (R39 met)
  - not observed: owner's arm64 phone (not connected); "no janky frames" not met on the emulator
    (portrait still 30% over 16.7 ms; the no-filter upper bound was similar, so it's the emulator's floor)
  - APK: grey-mushaf.apk arm64 release 84.0 MiB sha256 c3c03254…b4ac (head 4e648bd)
- next action: owner runs the APK on the phone; if still laggy, connect over adb and run
  scripts/reader_perf.sh on the device
