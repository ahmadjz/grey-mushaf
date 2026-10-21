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

## Checkpoint (paused 2026-10-21, machine out of memory; resume on another machine)

The owner said to commit and push everything, so this push overrides the rule that an open MEDIUM
blocks a push. **Phase 0 is not done.**

State at pause:
- `57a2da8` Confine asset output and preserve unrelated files (finding 1 fix, by the writer)
- `54b4a50` Resolve touches across complete line bands (finding 2 fix, by the writer)
- `4b56a8a` **WIP** fill the screen (R19). The writer was stopped mid-edit and Claude committed its
  tree as-is. Unverified: gates not run (the Python here has no pytest; Flutter was skipped for
  memory). It may not compile.
- Claude has not read the diffs of these three commits. Round-2 review not run.

## Resume on a new machine

1. Clone `ahmadjz/grey-mushaf` and run `/quran-quick docs/runs/2026-10-21-phase0-spike-run-log.md`.
2. **Assets are not in git (R16).** Copy them from the old machine, or download them again from
   qul.tarteel.ai (free sign-in): resource 19 (SQLite), resource 47 (SQLite) and resource 240 (TTF).
   Unzip them to:
   - `assets-src/qul-v4/layout/qpc-v4-tajweed-15-lines.db`
   - `assets-src/qul-v4/words/qpc-v4.db`
   - `assets-src/qul-v4/fonts/p1.ttf … p604.ttf`

   Then run `python3 scripts/bundle_mushaf.py` to fill the gitignored `app/assets/mushaf/`. The
   owner's `.ai` pages (`1441-AI-hafs.zip` → `ai-pages/`) are only needed for the line comparison.
3. Tooling: Flutter (at `~/development/flutter/bin` on the old machine), Android SDK, an emulator, and
   Python with pytest (`uv run --with pytest` worked for the writer).
4. Codex threads `01a15dfc…` (writer) and `01a15e2c…` (reviewer) do not exist on the new machine.
   Start a new writer thread at medium effort and give it this log.

## Next action

Step 7, continued. The new writer:
- (a) reads `296493f..4b56a8a` and finishes R19: page fills the screen, minimal chrome, text block
  ≥ 90% of the limiting dimension on phone and tablet, pages 1–2 at the same text size;
- (b) gets the gates green: pytest, flutter analyze, flutter test;
- (c) re-takes the screenshots as `docs/runs/shots/phase0-r19-*`: page 48 with 2:282:7 revealed via
  its overhang, page 1, spread 1|2, spread 47|48. Retry `Medium_Phone_API_37.0` for the phone proof;
- (d) squashes or rewrites nothing that is already pushed. It fixes forward.

Then Claude reads the diff. A round-2 review runs on a new high-effort thread (gestures and layout
changed). Then Step 8, the exit check and the report.

## Step 7: R19 finished and proved on the replacement machine (2026-10-21)

Started at `cb5070b`, clean tree; read `296493f..4b56a8a`. Kept the bundler confinement
and full-line-band hit testing. Finished the WIP by constraining justified text to its shared
font scale: height-limited spreads previously stretched word gaps across the whole half-screen,
including page 2's non-centred line. Text now stays centred at its natural scaled block width;
the hit bands still cover the full page width. Fixed the analyzer's missing braces.

Test-first evidence: the new landscape spacing regression failed with a 596 px text span versus
380.83 px expected, then passed after the layout change. Added viewport fill and page 2 font-size
checks at the four emulator SafeArea sizes, and a spread drag across a line break with swipe lock,
once-only counts and swipe restoration. Corrected the overhang test to the right edge: uniFC47's
xMax is 2669, beyond its 2371-unit advance. Existing left/right spread and gesture tests still pass.

Gates (final source):
- `~/.local/bin/uv run --no-project --with pytest python -m pytest -q tests/`: 15 passed.
- From `app/`, `flutter analyze`: zero issues.
- From `app/`, `heavy flutter test`: 13 passed.
- From `app/`, `heavy env GRADLE_OPTS=-Dorg.gradle.daemon=false flutter build apk --debug`: passed.
- `git diff --check`: passed. Assets and screenshots remain gitignored.

Live proof used `flutter devices`, then `Medium_Phone` first and `Tablet_API_37` second, one
emulator at a time. Both API 37, SwiftShader, 4 GB guest RAM. The initial 2 GB phone guest killed
the foreground app twice (Android lowmemorykiller); increasing guest RAM resolved it. Installed
the final debug APK with adb, navigated/pressed with `adb shell input`, rotated with Android's
`user_rotation` setting, and captured each image with `adb exec-out screencap -p`.

All paths below are under `docs/runs/shots/`. Fractions use the limiting dimension of the common
15-line page at the shared font size, divided by the SafeArea dimension **including** the footer.
Phone portrait is width-limited (1080 px); phone landscape is height-limited (954 px). Tablet
portrait and landscape are height-limited (2448 and 1488 px). Android bars are excluded.
The visible-ink column is measured independently from screenshot pixels: bounding box of luminance
<240 within the text area, excluding the footer. For spreads, values are page order (right|left).

| Screenshot | Common page block | Visible ink |
| --- | ---: | ---: |
| `phase0-r19-phone-page48-revealed.png` | 99.03% | 98.52% |
| `phase0-r19-phone-page1.png` | 99.03% | 78.80% |
| `phase0-r19-phone-spread1-2.png` | 93.40% | 46.96% / 46.86% |
| `phase0-r19-phone-spread47-48.png` | 93.40% | 92.14% / 92.03% |
| `phase0-r19-tablet-page48-revealed.png` | 98.04% | 96.69% |
| `phase0-r19-tablet-page1.png` | 98.04% | 49.22% |
| `phase0-r19-tablet-spread1-2.png` | 96.77% | 48.72% / 48.59% |
| `phase0-r19-tablet-spread47-48.png` | 96.77% | 95.43% / 95.36% |

Pages 1–2 deliberately occupy less than 90% with their visible ink: R19 explicitly retains their
short centred layout at the normal-page font size. They share the common scaling above; their
ink is not enlarged independently to reach 90%. All normal-page ink measurements exceed 90%.
The opening measurements include the existing system-font heading/basmallah placeholders.

Overhang proof: only word id `6177` (`2:282:7`) became black, reveal count 1, on each device.
Phone advance rectangle `[235,68][294,216]`, press `(296,177)` for 800 ms; tablet rectangle
`[414,52][489,212]`, press `(491,176)` for 800 ms. Both pressed pixels changed from grey to
RGB `(0,0,0)` outside the advance rectangle. Rotation retained that reveal. The eight final
screenshots have zero unequal-RGB pixels inside the SafeArea (R17). All eight were visually checked.

No test accounts, tokens or server records created. The in-memory reveal of word `6177` was removed
by stopping the app/emulator; `/sdcard/phase0-r19.xml` was removed from both emulators. Both emulators
are stopped. No VPS changes, no push, no rewritten commits.

Not run: physical phone/Boox (none connected), a fresh comparison against the original outline
pages (this run used the existing database line-range test), round-2 independent review (next step).
The existing system-font heading/basmallah placeholders remain a phase-0 limitation.

## Round-2 fixes: ink ownership, empty space and measurement caching

Started at `d0453df`, clean tree. Addressed the three retained MEDIUM findings.

- The bundler emits each character's horizontal TrueType ink bounds, including the union of
  COLR v0 layers and composite-glyph bounds. It leaves shaping/RTL offsets to Flutter's character
  selection boxes. The reader combines these into word ink extents. Direct containment wins over
  tolerance; overlapping extents use the nearest ink edge. This handles the long first-word tail
  and page-48 overhang without using misleading advance-box centres. These are horizontal ink
  projections, not pixel masks; full vertical line bands remain intentional.
- Horizontal tolerance is **0.08 em**. Empty margins/gutters beyond it do nothing on press or tap.
  The viewport rejects off-screen input and bands. Ink may extend into the thin page padding.
  The old gutter test was corrected: start in empty space, then reveal only when dragging into ink.
- One reference-size TextPainter per word computes both width and shaped ink bounds on bundle
  initialization; a new bundle identity invalidates the cache. Font scaling uses cached maxima.
  Reveals, drags and rotation do not re-measure any words. The measurement seam test checks exactly
  **347 initial measurements and zero additional measurements** for the four-page bundle.
  The optional picker-disabled-during-drag assertion is included.

Test-first evidence:
- Tail press selected `1:1:2` instead of `1:1:1`; new test failed before the fix.
- Empty margin/gutter and off-screen input changed word state; new assertions failed before the fix.
- Drag/rotation increased measurement calls from 383 to 1,956; the cache regression failed before
  implementation, then passed with exactly one measurement per word.
- Padding-edge ink of `2:282:70` remained grey; regression failed before removing horizontal
  line-container clipping from ink eligibility.
- New bundler metadata/missing-glyph tests failed first. An all-font check then found seven
  intentionally empty glyphs in multi-character words (including page 249). New Python and Flutter
  tests failed before empty glyphs were represented as null ink bounds and skipped for hit extents.

Final checks:
- `~/.local/bin/uv run --no-project --with pytest python -m pytest -q tests/`: **17 passed**.
- `flutter analyze`: **zero issues**.
- `heavy flutter test`: **19 passed**.
- `heavy env GRADLE_OPTS=-Dorg.gradle.daemon=false flutter build apk --debug`: **passed**.
- Independent comparison against fontTools: **374 glyph bounds matched** across the four sample fonts.
- Read-only source scan: **83,668 words across 604 fonts covered**, seven empty component glyphs,
  no missing glyphs or entirely empty words. No full-bundle outputs were written.
- `git diff --check`: **passed**. Rebuilt sample bundle remains gitignored; fonts copied unchanged.

Final live proof uses the final debug APK: `Medium_Phone` first, then `Tablet_API_37`, one emulator
at a time (API 37, SwiftShader, 4 GB RAM). Inputs use `adb shell input`; captures use
`adb exec-out screencap -p`. Accessibility snapshots beside each PNG record states/counts.

| Check | Phone device pixels | Tablet device pixels | Result |
| --- | --- | --- | --- |
| First-word tail | (671,885) | (966,887) | Only `1:1:1` black, count 1 |
| Empty margin | (15,850) | (15,852) | Initial press reveals nothing; later press + tap leaves black `1:1:5` and all counts unchanged |
| Page-48 overhang | (296,183), advance right 294 | (491,183), advance right 489 | Only `2:282:7` black, count 1 |
| Spread gutter | (1197,98) | (1275,100) | Press changes nothing |
| Gutter drag endpoints | (821,98) ↔ (1573,98) | (998,100) ↔ (1553,100) | Only `2:282:1` and `2:275:9` newly black, each count 1 despite repeated crossings; prior `2:282:7` unchanged |

Screenshots (gitignored) under `docs/runs/shots/`:
- `phase0-r19-fix-phone-page1-tail.png`
- `phase0-r19-fix-phone-page1-margin.png`
- `phase0-r19-fix-phone-page48-overhang.png`
- `phase0-r19-fix-phone-spread47-48-gutter.png`
- `phase0-r19-fix-tablet-page1-tail.png`
- `phase0-r19-fix-tablet-page1-margin.png`
- `phase0-r19-fix-tablet-page48-overhang.png`
- `phase0-r19-fix-tablet-spread47-48-gutter.png`

No accounts, tokens or server records created. Temporary in-memory word states/counts were for
ids `1`, `5`, `6038`, `6171`, `6177`; force-stopping the app removed them. Remote temporary file
`/sdcard/phase0-r19-fix.xml` was removed on each emulator. Both emulators stopped afterward.

Not run: physical phone/Boox (none connected), full 604-page rendering/startup timing (four-page
spike APK used), another independent review (handoff next). No push or rewritten commits.
