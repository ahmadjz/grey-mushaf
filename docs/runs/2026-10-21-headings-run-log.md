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

## Next action

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
