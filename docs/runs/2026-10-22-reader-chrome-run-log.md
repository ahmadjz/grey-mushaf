# Reader chrome run log (2026-10-22)

Ask (owner, from phone screenshots): full screen, a small side margin on the portrait page, the page
number small and not a button, a Settings slider for the grey lightness, bars shown by tapping empty
space like the owner's reference app.

## Step 0 · done

- base `f07e0ef` (pushed). Local commits since: `e7263d7` ignore APKs, `f42fbd5` R25–R28,
  `8f3ad2b` R29–R32. Remote `ahmadjz/grey-mushaf`.

## Step 1 · done

- **Problem:** `SafeArea` around the reader (`app/lib/main.dart:322`), no bar hiding; 2 dp side
  padding (`:457`); 20 dp page-picker footer (`:507`) budgeted in `slotHeight` (`:326`); fixed grey
  `#B0B0B0` (`:657`). Target SDK 36 (inherited, `build.gradle.kts:23`) ignores Dart-side
  `SystemUiMode`, so bar hiding needs native `WindowInsetsControllerCompat` in the empty
  `MainActivity.kt`.
- **Rulings needed:** Settings entry (→ R29), margin, number fallback, slider range (→ R30–R32).
- **Surfaces:** `main.dart` layout/gestures, `MainActivity.kt`, `reveal_store.dart`
  (`local_metadata` key for grey level), new Settings screen, tests.
- **Proof:** (1) ink bounds tests with the 2% portrait inset, landscape spread, exact line breaks and
  one text size kept; (2) page number never overlaps ink, no button semantics; (3) blank tap toggles
  bars, word taps/long-press unchanged, no page turn; (4) slider ends and default, live preview, only
  grey words change, survives restart, save failure retryable; (5) emulator screenshots: portrait,
  landscape spread, bars shown, slider at both ends; (6) gates.
- **Sessions:** writer `01a1633e-6fd2-7463-ac74-48e7e390a575`.

## Step 2 · done

- R25–R28 and R29 (owner, `f42fbd5`, `8f3ad2b`); R30–R32 Claude's defaults. Deferred: e-ink mode
  grey (R8 not built yet).

## Step 3 · done

- Folded into the implement brief (stop with NEEDS_DECISION if anything open): nothing open.

## Step 4 · done

- `8f3ad2b..5402698`. Red first (chrome and margin tests failed before); `flutter analyze` pass;
  `flutter test` 37 passed; integration 4 passed on Medium_Phone; debug APK via `heavy`, offline pub.
- Live Medium_Phone: portrait full screen, landscape spread, bars overlay without reflow (pixel
  compare), both slider ends, grey level survives force-stop (`docs/runs/shots/r25-32-*.png`).

## Step 5 · done

- Reviewer `01a16352-4a81-7882-ace6-30b0093a2041` (high). r1: 0/0/3, all seen live.
  1. `main.dart:506` blank tap between lines re-greys the word below (full-height bands).
  2. `main.dart:154` grey-level save failure hidden under the Settings sheet.
  3. `main.dart:139,167` bars stay shown across rotation/resume/Settings.

## Step 6 · done

- F1 kept: `onTapUp` used band matching; an accidental tap undoes a reveal (R6/R29).
- F2 kept: SnackBar under the modal sheet.
- F3 dropped: bars stay until the next blank tap, as R29 says; resume reapplies current state.
- Screenshots checked: portrait margin and ٤٨ at bottom, bars overlay row 1 without moving text.

## Step 7 · done

- `86c6e86` short taps use ink-height boxes, drag bands unchanged; `fb89f3b` failure + Retry
  inside the sheet; `4aed85f` evidence. analyze pass, `flutter test` 39 passed, integration 4
  passed, live (864,799): bars toggled, word stayed black, count unchanged. r2 not needed.
- Release arm64 APK built, copied to `grey-mushaf.apk` (gitignored).

## Step 8 · done

- Proofs (1)–(6) met on the emulator. Not observed: owner phone, Boox, physical cutouts, 604 pages.

**Next action:** owner tries the APK.
