# Headings Step 4 evidence

Base: `feef9a7`. Local implementation commits: `6ddc24e` (inherited),
`b127ded` (outline metrics), `bfe5c9e` (heading rendering and calibration),
`6fb4e64` (RTL ink fitting). R23 is recorded in `b766c01`.
The pre-existing edits in `2026-10-21-headings-run-log.md` were left uncommitted.

## Clipping diagnosis and correction

The genuine edge overflow pre-existed at `feef9a7`: the original four-page sample
fails on page 48. With page 50 supplied to that reader, its settled body crop was
pixel-identical to the previous settled headings build. The initially reported
much larger left clipping had a second cause: the first page-50 screenshot was
captured during a swipe. Before replacing those shots, comparison against its
settled counterpart found a 17 px horizontal displacement (mean summed RGB
error 0.64 after alignment, versus 28.02 without alignment). This was a capture
artifact, not a heading-induced enlargement of the body.

`line_bounds_test.dart` now paints the actual constrained RTL paragraphs onto an
oversized transparent surface and scans rendered alpha, including wide words,
right start edges and left ends. It does not equate advance width with ink width.
The red raster test failed on page 50 line 14 with 2.57 dp right overflow. The
fix includes any net outer ink excess in the shared size limit and moves only
lines whose ink crosses the available page edge. It uses spare left bearing
before shrinking unnecessarily. On this sample the edge alignment is sufficient;
the full-page shrink path applies when the ink really exceeds the available
width. The height-limited tablet/spread size calculation and already-contained
body lines remain unchanged. Printed line breaks and a shared font size remain.

All five bundled pages (1, 2, 47, 48, 50) pass raster fitting at phone portrait,
tablet portrait, phone spread and tablet spread. No test threshold was relaxed.
Settled phone page 50 has body ink inside x=7..1075 on the 1080 px screen, with
all 13 body lines individually measured in `headings-phone-body-bounds.json`.

## Calibration

Reference renders are 840 x 1200. The normal printed 15-line coordinate frame
is W=543, H=892, beginning at reference y=157. Ratios below are ink width/W,
ink height/H, ink top offset/H. In the app this frame scales uniformly with the
shared text scale; opening pages centre it vertically. Regular-page headings
anchor it at the first line band. The frame is distinct from the vertically
expanded viewport line bands retained under R19; scaling heading art to those
bands would distort its proportions. Body line spacing on opening pages uses
the measured 47/543 width ratio rather than the padded font-box height.

Phone frame: W=1069.5 px, H=1756.9 px (rounded). Pixel boxes use a black threshold
of 100; antialiasing and conservative vector curve bounds explain subpixel/roughly
one-source-pixel differences. Page 1's ayah basmallah remains ordinary word ink,
not a heading.

| Page / heading | Source width, height, top | Phone width, height, top |
| --- | --- | --- |
| 1 surah | .18600, .03251, .16928 | .18607, .03244, .16945 |
| 2 surah | .17127, .03475, .16816 | .17017, .03415, .16888 |
| 2 compact basmallah | .31676, .04484, .31614 | .31604, .04497, .31573 |
| 50 surah | .24494, .05045, .00785 | .24497, .05009, .00840 |
| 50 wide basmallah | .56538, .04484, .08184 | .56381, .04383, .08182 |

Same-scale comparisons: `docs/runs/shots/headings-compare-page2.png` and
`docs/runs/shots/headings-compare-page50.png`. Each app crop is scaled to a
543 px block width without changing aspect ratio. Full measurements are in
`docs/runs/shots/headings-calibration.json`.

## Final gates

- Requested uv pytest command: 26 passed.
- Flutter analyze: no issues.
- Flutter test: 31 passed, including raster fitting, synthetic pages 187/604,
  heading inertness, page-1 ayah revealability, FlatInk raster colours, printed
  dimensions/offsets/pitch, and existing gesture/layout tests.
- Default bundler rerun: passed; pages `[1,2,47,48,50]`, shared fonts and vector
  artwork generated only under the gitignored asset directory.
- `heavy env GRADLE_OPTS=-Dorg.gradle.daemon=false flutter build apk --debug`:
  passed. APK: `app/build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check`: passed for implementation changes.

Red and final logs are under `docs/runs/shots/headings-*-red.txt` and
`headings-final-{pytest,analyze,tests,build}.txt`. The inherited metrics/rendering
changes also had failing-test evidence in the previous worker's `/tmp` logs.

## Live proof

`flutter devices` listed Medium_Phone first. It was stopped and confirmed absent
before Tablet_API_37 booted. Both AVD configurations specify 4096 MB guest RAM;
the tablet was also launched with `-memory 4096`. Rotation was forced after app
launch using the system user-rotation setting and window-manager rotation lock.
Screenshots wait three seconds after each swipe to avoid transitional captures.

Both devices passed portrait pages 1, 2, 50 and landscape spread 1|2. For each
portrait page, heading long-press then tap left all 36/41/144 word states and
counts unchanged. All three headings in each spread left 77 word states and
counts unchanged. Pages remain even-left and odd-right.

Shots (all under `docs/runs/shots/`, all gitignored):

- `headings-phone-page{1,2,50}.png`
- `headings-tablet-page{1,2,50}.png`
- Corresponding `-after-heading-press.png` files for every portrait page.
- `headings-{phone,tablet}-spread1-2.png`
- Corresponding `-after-heading-press.png` files for both spreads.
- `headings-{phone,tablet}-evidence.json`
- `headings-reference-page{1,2,50}.png`
- `headings-compare-page{2,50}.png`

No test accounts, tokens or application records were created. The temporary
UI hierarchy file `/sdcard/headings.xml` was removed on each emulator. Assets,
source renders and screenshots were not staged. No pushes or VPS changes.

Not run: real pages 187/604 on device (synthetic automated tests cover their
heading structures); physical Boox proof; subsequent independent Step 5 review.
No behaviour decision remains for this implementation.
