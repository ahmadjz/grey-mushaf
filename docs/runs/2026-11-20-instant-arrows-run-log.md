# Instant arrow turns run log (2026-11-20)

mode default · route routine (one reader UI branch, nothing on the sensitive list)

## Step 0 baseline — done
base 977d4e8 · remote ahmadjz/grey-mushaf. Dirty files not mine, left alone:
`.claude/codex-worker-rules.md`, `.claude/skills/quran-quick/SKILL.md`,
`app/integration_test/perf_baseline_test.dart` (blank line), untracked `.claude/skills-backup/`,
`.claude/skills/quran-quick/{references,scripts}/`, older `docs/runs/*` folders.

## Step 1 investigate — done
- Problem: `_turn` in app/lib/main.dart:416 jumps only in B/W; in colour it calls
  `LoadedPageController.animateToPage` (250 ms easeOut). Swipes go through `LoadedPagePhysics`, not `_turn`.
- Rulings needed: none open; owner set R74 in the ask (swipe stays finger-following).
- Surfaces: app/lib/main.dart `_turn`; tests app/test/black_white_test.dart (colour arrow "still slides"
  flips), app/test/top_bar_test.dart:267 landscape spread; harness app/integration_test/phone_perf_test.dart
  gains arrow captures.
- Proof: unit tests (colour arrow instant, landscape spread instant, rapid colour taps land right);
  phone 2be3110f portrait + landscape arrow landing, rapid taps, arrow frame cost before vs after.
- Sessions: writer Opus medium (session) · pre-check skipped (bug-sized, 1 file, routine) ·
  reviewers Fable medium + Sol medium (fresh).

## Step 2 rulings — done
R74 owner (from the ask).

## Step 3 pre-check — skipped (1-file routine change, cause known at main.dart:416)

## Step 4 implement — done
- 2298324 harness arrow captures (portrait/landscape 20 arrows, 5 rapid taps, landing on group g =
  pages g+1 / 2g+1,2g+2) · 67f51ee arrows always jump · red: red.log 3 expected failures · green.log 30 passed
- gate: flutter analyze ok (analyze.log) · flutter test 159 passed (tests.log)

## Step 5 review — done
- Sol medium fresh thread 01a1f953-b7ab-7663-9592-b8a0b18a73b7: no findings; gaps noted (B/W swipe test, out-of-order rapid requests).
- Fable medium code-reviewer: 1 MEDIUM, 3 LOW, all from code.

## Step 6 Claude check — done
- MEDIUM kept: `prepare` (main.dart ~1234) awaited `loadNear`'s whole 10-page window even for a loaded
  target; onPageChanged → `_afterScroll` → `_prefetch` already moves the window after a jump.
- LOW kept: dead `LoadedPageController.animateToPage`; harness didn't record sliding frames.
- LOW kept as covered: rapid taps over a held load (rewritten swipe-during-held-load test taps 5 times over a held 7.json).
- LOW left open: no B/W swipe-follows-finger test (R73 clause, code has no B/W branch in physics/drag).

## Step 7 fix — done
- a57d558 loaded target jumps without loadNear (red2.log: stayed on page 2; green3.log 15 passed). Two
  old tests held a loaded neighbour behind page 7; rewritten to hold a truly unloaded target.
- fde9221 harness counts sliding updates per arrow turn (recorded, not asserted, so the before build runs).
- gate: flutter analyze ok (analyze2.log) · flutter test 160 passed (tests2.log)
- r2 not needed (no C/H, 3 fixes, no sync/export).

## Step 8 exit check — pushed, not done
- unit proof: colour + B/W arrow instant (black_white_test), landscape spread instant (top_bar_test),
  rapid colour/B/W taps land right on a real bundle, loaded target ignores a held far page.
- emulator after-run (emu-after/, before the a57d558 fix): harness passed, arrows landed right in
  portrait + landscape incl. 5 rapid taps. Emulator before/after comparison stopped at the owner's word.
- not observed: phone 2be3110f (not attached all run): arrow landing portrait/landscape, rapid taps,
  arrow frame cost before vs after. Owed.

next action: with the phone attached and awake (stay_on_while_plugged_in 7, wm dismiss-keyguard),
run phone_perf_test with -d 2be3110f at HEAD (after) and with lib/main.dart +
lib/loaded_page_controller.dart from 977d4e8 (before), then
`python3 docs/runs/2026-11-20-instant-arrows/frames.py <before> <after>`.
