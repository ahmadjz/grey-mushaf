# Run log: phase 0 feasibility spike (2026-10-21)

## Step 0: baseline (done)

- base `fdef29b`, tree clean, remote `ahmadjz/grey-mushaf`.

## Step 1: investigate (done)

Writer thread `01a15dfc-a310-7542-9ea2-457897c8fb58` (Astra medium). Inspection files in
`/tmp/grey-phase0-inspect/` (outside the repo).

**Problem.** Pick the 1441 word source, prove tapping and colouring on pages 1, 2 and 48 (2:282, the
densest page), and clear the licences (R15).

**Findings verified by Claude**

- QUL resource 19 (V4/1441 layout) line starts and ends match the owner's .ai pages 1, 2 and 48.
  Page 48 render checked: 15 lines, 2:282, line 1 ends مسمى.
- QUL layout gives each line's first and last word id, not word rectangles. Hit areas must come from
  the renderer.
- A word can be more than one font character (page 2).
- The QUL V4 fonts checked are the **tajweed colour** set (resource 240, COLR/CPAL, six palettes).
  Their name table says: "NOT FOR SALE, ONLY CHARITIABLE (SADAQA) PURPOSE ONLY. PRINTING AND
  PUBLISHING NOT PERMITTED WITHOUT PRIOR PERMISSION FROM KING FAHAD GLORIOUS QURAN PRINTING COMPLEX"
  (p1, p48 checked with `strings`).
- QUL bulk layout and word downloads need a QUL sign-in. No licence grant is shown on resources 19 or
  47; the QUL FAQ says terms are per resource.
- The .ai pages hold Quran text as compound outline fills (302 / 457 / 1,335 contours on pages
  1 / 2 / 48), with no word grouping. Segmenting them would take weeks plus proofreading.
- KFGQPC's own copyright pages could not be reached. An older reproduced EULA allows use, copying and
  distribution, but forbids modifying or altering.
- No Android device is connected. Emulators `Medium_Phone_API_37.0` and `Tablet_API_37` exist.

**Rulings needed:** licence route, which source, delivery, revealed-word colour.

**Surfaces:** new `app/` (Flutter spike), gitignored asset fetch script.

**Proof:** pages 1, 2 and 48 render with lines matching the .ai renders; long-press reveal, drag
reveal with swipe off, tap re-grey (R3); portrait and landscape spread (R4); emulator screenshots;
licence status written down.

**Sessions:** writer `01a15dfc-a310-7542-9ea2-457897c8fb58`.

## Step 2: rulings (done)

R16 personal use only (replaces R13, R15 public clause), R17 plain black/grey, R18 assets inside the
APK. Committed `5237e79`.

## Step 3: one check (done)

Writer says nothing open. QUL has no plain (non-tajweed) V4 font; route for R17 is rendering each word
then `ColorFiltered` with `BlendMode.srcIn` (unproved, spike checks it).

**Blocker:** the owner must download QUL resources 19 (layout SQLite), 47 (words SQLite), 240 (fonts
TTF) with a QUL sign-in into `assets-src/qul-v4/` (gitignored). Owner asked for plain steps.

Owner downloaded the files; unpacked to `assets-src/qul-v4/` (604 fonts, 83,668 words, 9,046 lines).

## Step 4: implement (done)

`5237e79..3d53f88` (`2604b1a`, `109d6f1`, `3d53f88`).

- gate: pytest 4 passed · flutter analyze ok · flutter test 5 passed
- live: Tablet_API_37 screenshots `docs/runs/shots/phase0-{page1-grey,page48-revealed,spread1-2,spread47-48}.png`;
  Claude viewed page 48 (2:282:1–12 black across line 1→2) and spread 1|2 (page 1 right)
- colour: zero unequal-RGB pixels in the four screenshots (writer)
- .ai p48 vs app: 15/15 line starts and ends match (writer)
- not run: phone emulator (segfault at boot), physical phone/Boox
- placeholders: surah name and basmallah lines in a system font

## Step 5: review (done)

Reviewer thread `01a15e2c-83cf-7050-acb7-c28bda594a7d` (Astra high).

1. bundler `--output` unconfined, cleanup deletes numbered files there (`scripts/bundle_mushaf.py:41-51`).
   Rated HIGH, **kept as MEDIUM**: a script only the owner runs, but it can delete files.
2. MEDIUM, seen live: hit boxes are advance width × fixed 38 px (`app/lib/main.dart:369-372`), so
   visible overhanging ink of 2:282:7 does not reveal. **Kept.**

## Step 6: owner input mid-run

R19 (`296493f`): the page fills the screen; on the phone screenshots the text block is a small box
with wide margins.

## Checkpoint (paused 2026-10-21, machine out of memory)

Fix round not sent. head `296493f` + this log, local only, **not pushed**: two kept MEDIUMs are
open, and the skill's rule is that an open MEDIUM blocks the push.

## Next action

Step 7: on writer thread `01a15dfc-a310-7542-9ea2-457897c8fb58` (or a new medium thread if it has
expired), send: finding 1 (confine bundler output, delete only its own files, refuse symlinks), finding 2
(line-band nearest-word hit testing, regression at 2:282:7 overhang), and R19 (page fills the screen,
minimal chrome, ≥90% of the limiting dimension on phone and tablet). Retry Medium_Phone_API_37.0
for the phone proof. Then round-2 review on `01a15e2c-83cf-7050-acb7-c28bda594a7d` (gestures +
layout changed), Step 8.
