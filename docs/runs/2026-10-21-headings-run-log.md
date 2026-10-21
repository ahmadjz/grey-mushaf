# Run log: real surah headings and basmallah (2026-10-21)

## Step 0: baseline (done)

- base `feef9a7`, tree clean, remote `ahmadjz/grey-mushaf`.

## Step 1: investigate (done)

Writer thread `01a15e5b-e21d-7112-b8d0-903f6f8f85e6` (Astra medium), same as phase 0.

**Problem.** Surah-name and basmallah lines render in a system-font placeholder.

**Findings verified by Claude**

- Surah font: QUL resource 457 `surah-name-v4.ttf` (IcoMoon, monochrome, GSUB ligatures
  `surah001`…`surah114`, `surah-icon` = "سورة"; no licence text). In `assets-src/qul-v4/surah-names/`.
- Basmallah: words 1:1:1–4 are U+FC41–FC44 in `p1.ttf`; 1:1:5 (U+FC45) is the ayah marker.
- Layout: 114 `surah_name` and 112 `basmallah` lines. Page 187 (surah 9) has no basmallah;
  page 604 has three heading pairs (lines 1–2, 5–6, 10–11).
- Kerning differs by composition (−0.2464 em between the first two glyphs in one run, none in
  separate runs). p1 has COLR, so black needs `FlatInk`.
- `.ai` pages 1–74 salvaged from a truncated `1441-AI-hafs.zip` into `ai-pages/` (CRC-checked).
  Reference headers: page 2 (surah 2 + basmallah), page 50 (surah 3 + basmallah).

**Rulings needed:** heading colour, heading text, size calibration.

**Surfaces:** `scripts/bundle_mushaf.py`, `app/lib/main.dart`, tests.

**Proof:** pages 1, 2, 50 headings in the mushaf calligraphy, black (R20), sized and spaced like
the .ai renders; heading lines not revealable or counted; p1 font present when page 1 is not
bundled; gates green; phone and tablet screenshots.

**Sessions:** writer `01a15e5b-e21d-7112-b8d0-903f6f8f85e6`.

## Step 2: rulings (done)

R20 headings always black (`b94e57f`). R21 "سورة" + name, sizes matched to the .ai pages (`f7c4914`).

## Step 3: one check (done)

The writer found that p1 glyphs cannot match page 50: the printed regular-page basmallah is the
wide stretched form (307 × 40 px vs page 2's 172 × 40 px at the same scale,
`docs/runs/shots/headings-reference-basmallah-2-vs-50.png`, seen by Claude). Owner ruled R22
(`c8282e2`): compact p1 glyphs on page 2, wide basmallah traced from `ai-pages/050___Hafs39__DM.ai`
on every other page, generated into the gitignored `app/assets/mushaf/`.

## Step 4: implement (in progress)

Old writer `01a15e5b…` locked by the stalled session's bridge; new writer
`01a15fb4-655e-7a20-8c0c-0279652465a8` (Astra medium) took over the uncommitted WIP.

- Round 1: pytest 26 passed; flutter analyze ok; flutter test 26 passed; debug APK ok; phone
  portrait pages 1/2/50 heading long-press/tap inert (word states and counts unchanged). Spread
  failed (emulator stayed portrait). Tablet, calibration, compare crops: not run.
- Claude saw `headings-phone-page{2,50}.png`: wide basmallah on 50, black headings. Page 2 gaps
  larger than print; page 50 body lines clipped at the left edge.
- Clipping pre-exists at `feef9a7` (pixel-identical crops). Owner ruled R23 (`b766c01`): shrink
  the phone page so every line fits.

- Round 2, `feef9a7..572b8b5` (`b127ded` bundler, `bfe5c9e` headings, `6fb4e64` ink fitting,
  `572b8b5` evidence). The large page-50 clipping in the first shot was a mid-swipe frame; the real
  pre-existing ink overflow is fixed and phone body ink sits at x=7…1075/1080.
  - pytest 26 passed; flutter analyze ok; flutter test 31 passed (rendered-ink bounds); bundler
    rerun incl. page 50; debug APK ok via `heavy`.
  - Phone and tablet: pages 1/2/50 portrait and spread 1|2 ok; heading presses changed no states
    or counts.
  - Calibration (w/W, h/H, top/H) .ai → phone: p1 surah .186/.0325/.169 → .186/.0324/.169;
    p2 surah .171/.0348/.168 → .170/.0342/.169; p2 basmallah .317/.0448/.316 → .316/.0450/.316;
    p50 surah .245/.0505/.0079 → .245/.0501/.0084; p50 basmallah .565/.0448/.0818 → .564/.0438/.0818.
  - Not run: Boox, device proof of pages 187/604 (synthetic tests only).
  - Claude saw `headings-compare-page{2,50}.png`, `headings-phone-page50.png`,
    `headings-tablet-spread1-2.png`: match print, every line in full.

## Next action (superseded)

Step 4, implement on the writer thread (reuse `01a15e5b…` if codex-bridge still has it, otherwise a
new Astra medium thread given this log). Brief:
- R20–R22. Separate heading data with no word ids; bundle `surah-name-v4.ttf`, the p1 font as a
  dependency (kept when page 1 is not selected), and the traced wide basmallah as vector data
  (no raster, no network-only dependency). The bundler fails clearly if the .ai source is missing.
- Test first: heading data and font dependencies, heading lines have no hit targets and never
  change reveal state or counts, page 187 / 604 edge cases with synthetic data, black under FlatInk.
- Add page 50 to the default sample bundle and rerun the bundler.
- Calibrate heading and basmallah size and position against the .ai renders of pages 1, 2 and 50
  (ink box relative to the 15-line block); report .ai vs app ratios.
- Gates: pytest, flutter analyze, flutter test, debug APK.
- Live: `Medium_Phone` then `Tablet_API_37`, one at a time: pages 1, 2, 50 portrait, spread 1|2,
  long-press and tap on a heading change nothing. Shots `docs/runs/shots/headings-*`, and
  `headings-compare-*` side-by-side crops of .ai vs app for pages 2 and 50.
- Local commits only. Then Step 5 review on a new Astra high thread, Steps 6–8.

## Step 4 follow-up: clipping scope gate

- Added `app/test/line_bounds_test.dart` before changing layout. It checks shaped
  glyph ink against each page area on phone/tablet portrait and spread, pages
  47/48/50. Current result: phone portrait fails; the other three sizes pass.
  Page 48 right overflow reaches 0.40 dp; page 50 reaches 2.59 dp.
- Ran the same test against an exact temporary copy of `feef9a7:app/lib/main.dart`
  with the current five-page assets: identical failures. With the original
  four-page sample, page 48 still fails (maximum 0.41 dp). Temporary baseline
  source/test files were removed after proof.
- Built the baseline entry point through `heavy`, installed it on Medium_Phone,
  and captured settled pages 48/50. Page 50's body crop `(0,370,1080,2260)` is
  pixel-identical to `headings-phone-page50-after-heading-press.png` (Pillow
  ImageChops difference bounding box is None). Thus the visible body defect
  pre-exists heading rendering. The bounds test detects edge overflow but does
  not explain the full visual extent of the device clipping; further device
  ink/advance investigation is needed before implementing a correction.
- Evidence (gitignored): `docs/runs/shots/headings-baseline-page48-stationary.png`,
  `headings-baseline-page50-stationary.png`, `headings-line-bounds-current.txt`,
  `headings-line-bounds-baseline.txt`, `headings-line-bounds-original-sample.txt`.
- Rebuilt the current main entry point through `heavy` successfully and restored
  its APK. No accounts, tokens, or application records created.
- Stopped before layout changes under the owner's explicit instruction to return
  NEEDS_DECISION if a fix changes existing pages outside the headings scope.
  Recommendation: authorise a shared body-ink fitting correction, allowing the
  existing pages' text size/spacing to change as needed while retaining line
  breaks and a common text scale. Alternative: keep current body layout and
  defer the clipping fix (headings Step 4 remains incomplete).
- Calibration, comparison crops, new spread/tablet proof and final full gates
  are not run pending that scope decision. The new regression remains red.

The follow-up above is superseded by Round 2: after R23 the writer fixed the clipping test-first.

## Step 5: review (blocked)

Reviewer thread `01a15fce-f385-72d0-99ea-6efc4d3d9788` (Astra high) refused at start: Codex usage
limit, resets 2026-10-27 09:32. No review ran. Commits `feef9a7..572b8b5` stay local and unpushed.
Retry on a new thread `01a15fe4-3463-7512-8859-9c4577d403a7` (same day, full brief): same refusal.

## Step 5: review (done)

Reviewer thread `01a15fea-199c-7572-90e7-559c8e21fcb5` (Astra high), range `feef9a7..572b8b5`.

- Rulings to tests: R5, R20, R21, R22 and R23 each mapped to tests; none missing or contrary.
- pytest 26 passed (uv); flutter analyze clean; flutter test 31 passed; scratch APK via `heavy` ok.
- Seen live, Medium_Phone then Tablet_API_37: pages 1/2/50/187/604 and spread 1|2; black
  headings, compact basmallah on page 2 and wide elsewhere, heading presses inert.
- Page-2-only bundle keeps `p1.ttf`; missing `.ai` fails clearly and keeps existing output.
- No source asset in any of the 11 commit trees. All 604 pages pass R23 bounds at four sizes
  (scratch extension). Calibration numbers reproduced.
- Not applicable: PocketBase fields (no responses read), race fault injection (no race claimed).
- Not run: Boox (unavailable); audit of the original calibration script (not available).

## Step 6: Claude checks (done)

- Diff `feef9a7..572b8b5`: 9 files, +1142/−79. Claude saw `headings-review-phone-page604.png`
  (three heading pairs) and `headings-review-tablet-page187.png` (surah name, no basmallah).
- Dropped: HIGH "reveal lost on restart" (`app/lib/main.dart:80`, R2). It pre-exists this
  range; local persistence belongs to the planned local-SQLite/sync work (R10–R12), not headings.
- Dropped as a finding, kept as a note: `app/test/line_bounds_test.dart:29` covers five pages and
  skips heading lines; the reviewer's all-page scratch run passed.

## Step 7: fix (not needed)

r1 0/0/0 kept (C/H/M). No fix round, no second review.

## Step 8: exit check (done)

- Pages 1, 2, 50 headings sized like the .ai: calibration ratios above, compare crops seen.
- Heading lines inert and uncounted: seen live on phone and tablet.
- p1 font kept when page 1 not bundled: proven with a real page-2-only bundle.
- Pages 187 and 604: seen live on both emulators.
- Gates green: yes.
- Boox: **not observed** (no device). The feature is pushed but not done until it is seen on
  the Boox.

## Next action

Check the headings on the owner's Boox. Separately, R2 local persistence (reveals lost on app
restart) is still unbuilt and goes with the local-SQLite/sync phase.
