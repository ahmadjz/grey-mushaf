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

## Next action

Step 3 check and Step 4 implement on the writer thread.
