# Dark mode run log (2026-10-22)

base 16a559d · tree clean at start · remote ahmadjz/grey-mushaf

## Step 1 block

- **Problem:** add dark mode per R33–R35. Black page, unrevealed words dim, revealed words white,
  headings white. Own dimness slider, per device. Settings switch only; never follows the phone.
- **Rulings needed:** startup (every launch light vs remembered switch), dark slider range/default,
  slider presentation, colours of bars/Settings/page number/save message, ayah-marker field colour.
- **Surfaces:** `app/lib/flat_ink.dart` (field→white, ink→colour matrix; white ink hides numerals),
  `app/lib/main.dart` (`_word` 856, headings 774, page/number 514/732, app bar 579, Settings 172,
  save SnackBar 279, word semantics "black"/"grey" 869), `app/lib/reader_settings.dart`,
  `app/lib/reveal_store.dart` (`reader_grey_level` 128–224, default 176), `MainActivity.kt` bars,
  `res/values-night` (native theme follows OS).
- **Proof:** R33 pixel tests for white/dim ink on black incl. markers and the three heading forms;
  page-1 basmallah still revealable; R24 failure/Retry in dark. R34 separate levels survive reopen,
  fallback for bad values, word tables untouched. R35 startup under both phone themes, phone theme
  change ignored, chosen restart semantics. Live: emulator screenshots of pages 1, 2, 48, 50 in dark,
  cold launch with phone in dark mode.
- **Sessions:** writer 01a16370-7489-79d0-a7a3-34632d9c6541 · reviewer (pending)

## Steps

- 0 baseline: done
- 1 investigate: done (Claude verified flat_ink matrix, reader_settings, grey key range, semantics label)
- 2 rulings: done. Owner: 1a 2a 3 fine → R36–R38, committed 6d1df44 (code base from here)
- 3 one check: done, "nothing open"
- 4 implement: done, 6d1df44..26eca12 (5b5c381, 2727891, 26eca12)
  - analyze: no issues
  - flutter test: 45 passed
  - integration reader_settings, sqlite, persistence: passed
  - debug APK build: passed
  - live Medium_Phone: dark pages 1/2/48/50, Settings, resume, bar icons, cold launch light with OS
    dark and after leaving dark on (docs/runs/shots/dark-*.png). Claude viewed page-1, page-50,
    settings and cold-system-dark shots: match R33/R36/R38
  - not run: physical phone/Boox, ARM release, 604-page performance, live landscape, live dark
    save failure (widget-tested only)
- 5 review: BLOCKED. Reviewer thread 01a16388-82f1-78c2-9ce5-39c8e602160f hit the Codex usage limit
  (resets 2026-10-28 22:22). Nothing reviewed. Brief is in this session's history; resend as-is.

**Next action:** after the Codex limit resets, start a new Astra high review thread on
6d1df44..26eca12 (Step 5), then Steps 6–8. Do not push before review.
