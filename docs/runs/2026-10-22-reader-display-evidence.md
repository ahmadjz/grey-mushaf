# Reader display rulings R25–R32

Base: `8f3ad2b`. Implemented full-screen reader, blank-tap overlay bars and Settings,
2% portrait ink margins, inert Arabic-Indic page numbers, and device-local grey lightness.
The pre-existing untracked `2026-10-22-reader-chrome-run-log.md` was left untouched.

## Checks

- Red: `flutter test --no-pub test/reader_chrome_test.dart` failed on the existing page picker and missing Settings entry before reader changes.
- Red: the strengthened `line_bounds_test.dart` failed on portrait ink outside the new 2% margin before layout changes.
- Green: targeted chrome and painted-ink tests passed (6 tests).
- Full widget suite: 37 tests passed. The existing 90% fill threshold is retained and now measures the area remaining after R31's required margins; obsolete picker-enabled assertions now verify page-swipe locking and picker absence.
- Analyzer: no issues found.
- Debug Android APK: built successfully, retaining inherited target SDK 36.
- Offline dependency resolution: `flutter pub get --offline` passed; subsequent Flutter checks/builds used `--no-pub`.
- Full suites and Android builds used `heavy env GRADLE_OPTS=-Dorg.gradle.daemon=false` before the Flutter executable.
- Dedicated real-SQLite preference integration test passed: default, both endpoints, reopen, independent database, failed-write rollback, invalid input and stored-value fallback; no word actions/events/state created.
- Full Android integration suite: all 4 tests passed (startup persistence, SQLite transactions/rollback, downgrade refusal, grey preference).
- `git diff --check`: passed.

## Live proof

`flutter devices` listed `emulator-5554`, Medium_Phone on Android API 37.
Started with `-memory 4096`, software rendering, and no snapshot save.
Phone dimensions: 1080 × 2400; spread dimensions: 2400 × 1080.

Screenshots are local, gitignored files under `docs/runs/shots/`:

- `r25-32-portrait-fullscreen.png`: page 48, default grey, no system bars; solid grey ink spans x=30…1057, within the required side margin.
- `r25-32-bars-shown.png`: blank tap shows both system bars and the in-app Settings bar.
- `r25-32-settings-dark.png`, `r25-32-reader-dark.png`: slider minimum and reader with RGB 128 ink.
- `r25-32-settings-light.png`, `r25-32-reader-light.png`: slider maximum and reader with RGB 224 ink; heading remains black.
- `r25-32-relaunch-light.png`, `r25-32-relaunch-settings-light.png`: force-stop and relaunch retain RGB 224 and the maximum slider position.
- `r25-32-landscape-spread.png`: pages 48 left / 47 right, each with its own bottom-centred number.
- `r25-32-landscape-bars.png`, `r25-32-landscape-hidden-again.png`: blank-tap overlay and hide in landscape.

Android window dumps report both status and navigation bars `visible=false` in full screen and
`visible=true` after a blank tap. Edge swipe temporarily reports `visible=true`; after four seconds
both return to `visible=false` without an app tap.

Pixel comparison outside the overlays is identical in portrait (rows 180…2319) and landscape
(rows 180…989). The settled landscape frame after hiding the bars is identical to the frame before
showing them. Early captures during page-swipe/startup animations were replaced with settled captures.
The reader's RGB 224 frame after relaunch is identical to its pre-relaunch frame.

## Proof records and cleanup

No accounts or tokens were created. Preference fixtures created only metadata keys
`device_id`, `identity_version`, and `reader_grey_level`.

- Dedicated preference run device IDs: `417f5d50-5c2b-4efb-8175-cfc2efde5cba`, `a10cb87e-a2b0-48c3-a318-0d3bd93d566d`. Removed by deleting `reader-settings-proof.db` and `reader-settings-other-proof.db` at test completion.
- Manual screenshot run device ID: `247e5a22-3596-43ff-bcd2-dd72270fdd48`. No word actions. Removed by uninstalling the proof app after screenshots; the package was absent before this installation. Temporary database copy and UI hierarchy dump were removed.

The full integration run additionally created the following records, all removed by each test's
`deleteDatabase` cleanup:

- `reveals.db`: device `d6b05979-5203-4617-95d2-9e0f38a5eade`; action/event `c5db42ce-25c5-4996-b7cf-be3797a473b3`; word-state key `qul-v4-hafs:1:1:1`.
- `persistence-test.db`: device `da43ed51-0751-4669-9440-fc21b98b4440`; action IDs `b4e3e287-481f-4a6d-aa9d-82bbb2d9f99a`, `12ce67d0-84ef-4a68-8657-8fd7bad1dbfc`, `ef6a4ba2-f0cf-47cb-87f3-5ab36344600b`, `a856d5c9-fa55-4a14-89ac-6f5f8b318f85`, `6c2485ea-02bc-4261-a5af-735ad54c1bc7`. Reveal events use the corresponding reveal-action IDs; word-state keys `qul-v4-hafs:1:1:1`, `qul-v4-hafs:1:1:2`.
- Downgrade fixture: device `cf49c5c5-453f-4f29-a7ba-48294c151952`; action/event `c2ae02de-dbc1-42d9-ab3c-d03f038c5043`; word-state key `qul-v4-hafs:1:1:1`.
- Preference fixtures: devices `7e317490-9b82-4399-bbb7-e9dcda3add51`, `36695ea5-6280-4c1a-a172-56e8a5a5928a`; only the three metadata keys listed above.

## Limits

Not run: physical phone/Boox, e-ink mode (out of scope), full 604-page rendering (local bundle has
pages 1, 2, 47, 48, 50), physical camera-cutout proof, release/ARM build. Tablet_API_37 was not
needed: the requested alternative landscape-phone proof was used.
