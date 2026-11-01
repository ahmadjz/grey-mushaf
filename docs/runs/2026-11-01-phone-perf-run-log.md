# Run log: reader performance on the owner's phone (2026-11-01)

base a90f672 · dirty at start (not ours): .claude/codex-worker-rules.md, .claude/skills/quran-quick/SKILL.md
policy v3 · mode low-claude · route routine (rendering perf, no persistence/sync change) · single writer (cause decided by on-device measurement, not ambiguous design)

## Step 1 block

**Problem:** Redmi Note 9 Pro (arm64, Adreno 618, Impeller GLES, 60 Hz), profile: portrait 20 swipes raster
avg/p90/worst 12.2/22.0/151.9 ms, 152/989 janky; landscape 10.0/14.8/82.7, 92/1048; blank-page floor
3.2/3.8 ms. Settle after release 600–700 ms. Release cold start 1.18 s, PSS after 20 turns 169 MiB.

**Causes (writer's evidence, docs/runs/2026-11-01-phone-perf/report.md):** Impeller GLES keeps no raster cache, so
every swipe frame replays all page glyphs + filter layers (Dart paint() itself is retained); layout spikes
35–65 ms on page change; Flutter spring settle longer than Android ViewPager's quintic ≤600 ms.

**Design:** per-page final-colour ui.Image cache (page_ink.dart:241), bounded (2 portrait / 4 landscape
half-pages, ≤24 MiB), invalidated on saved reveal, sliders, theme, DPR, orientation; live hit-testing and
semantics kept. Quicker native-like settle (loaded_page_controller.dart:74), R41. Check the layout spikes.

**Rulings:** R41 Claude's default (settle speed). R40 parity applies.

**Proof:** R40 parity 84 images; phone before/after numbers same harness; release PSS <300 MiB after 604 pages
(R39); gates; R2/R3/R24 gesture + reveal tests.

**Sessions:** writer gpt-6.1-sol medium 01a195d0-f241-76a0-8416-e5dabc1c7aae · reviewer sonnet high (tbd)

## Steps
- 0 baseline: done · 1 investigate: done · 2 rulings: R41 default
- next action: Step 4 implement
