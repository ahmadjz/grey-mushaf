# Reader review fixes

Base: `5402698`.

- `86c6e86`: short taps use a word's measured horizontal ink extent and its line's painted ink-height box, with small tolerance. Long-press and drag retain the full-height bands.
- `fb89f3b`: a failed grey-level save displays its error and Retry inside the open Settings sheet. A failure arriving after the sheet closes still uses the reader SnackBar.
- Bar visibility across rotation, resume and Settings was not changed.
- The pre-existing untracked `2026-10-22-reader-chrome-run-log.md` was left untouched.

## Red first and gates

- Before implementation, `flutter test --no-pub test/blank_tap_test.dart test/settings_failure_test.dart` failed twice for the intended reasons: the gap tap changed `(black: true, count: 3)` to `(black: false, count: 3)`; the Settings sheet contained no hit-testable save error or Retry.
- After implementation, both targeted regression tests passed. The blank-tap test also verifies actual word taps still re-grey and gap long-presses still reveal; the failure test exercises successful Retry both inside Settings and after a late failure following dismissal.
- `flutter pub get --offline`: passed. Subsequent tests and builds used `--no-pub`.
- `heavy env GRADLE_OPTS=-Dorg.gradle.daemon=false flutter analyze --no-pub`: no issues.
- `heavy env GRADLE_OPTS=-Dorg.gradle.daemon=false flutter test --no-pub`: all 39 tests passed.
- `heavy env GRADLE_OPTS=-Dorg.gradle.daemon=false flutter test --no-pub integration_test -d emulator-5554`: all 4 Android integration tests passed.
- Debug APK build with the same heavy prefix: passed.
- `git diff 5402698..HEAD --check`: passed.

## Live check

Medium_Phone, 4096 MB, Android API 37, 1080 × 2400, density 420 (2.625 logical scale).
`flutter devices` listed the emulator before the Android checks.

Page 48: long-press at physical `(864,799)` revealed `2:282:48` using the existing generous band.
SQLite read back black with count 1. A short tap at exactly `(864,799)` then showed the bars and
Settings while SQLite still read black with count 1. Accessibility also reported
`2:282:48; black; reveals 1`. The word's full band was `[838,797][892,955]`.
A subsequent tap at the word centre re-greyed it, keeping count 1.

Local screenshots, visually inspected and gitignored:

- `docs/runs/shots/review-blank-tap-before.png`
- `docs/runs/shots/review-blank-tap-bars-word-black.png`
- `docs/runs/shots/review-word-tap-regrey.png`

## Proof records and cleanup

No accounts or tokens created. All integration fixtures were removed by their existing
`deleteDatabase` cleanup, including their metadata, word states, actions and reveal events.
Metadata keys were `device_id`, `identity_version`, and (preference tests only) `reader_grey_level`.

- Startup fixture: device `97263202-4a52-407d-8f3c-6a74c2c1048a`; action/event `88daeb0d-d93e-41d0-958d-e71a608337e5`; word-state `qul-v4-hafs:1:1:1`; database `reveals.db` deleted.
- SQLite fixture: device `2977f230-3f22-4474-a521-19e38da01663`; action IDs `c77338b2-ca35-4eff-a558-047e03f99061`, `d9967311-a380-4f5d-9810-b0d4feb82c60`, `2ccb5b40-cdd9-4918-b646-596b2c1c2343`, `1f5a7d97-d13d-4930-b411-447ea7017de5`, `828b6e4d-d7c9-4b65-9ab8-6a0094ad22a8`. Reveal events share their reveal-action IDs; word-state keys `qul-v4-hafs:1:1:1` and `qul-v4-hafs:1:1:2`; database `persistence-test.db` deleted.
- Downgrade fixture: device `f2658c17-607c-4526-a47b-da5672979cde`; action/event `6dda877e-721a-438c-aad8-341bc9b26eb6`; word-state `qul-v4-hafs:1:1:1`; database `downgrade-test.db` deleted.
- Preference fixtures: devices `201bc3db-572e-440e-9818-1edf06d5832a`, `f46752f7-6b84-46d0-92f9-eb348a64360b`; only metadata; databases `reader-settings-proof.db` and `reader-settings-other-proof.db` deleted.
- Manual live proof: device `2b073cea-e67e-4f37-88bc-54dda2e65a75`; reveal action/event `d2c65d4c-f202-4fd3-bdbc-bce53f70a4a7`, re-grey action `9ac9352e-8493-42a9-a787-92e8e64c2c12`; word-state `qul-v4-hafs:2:282:48`. The package was absent before installation; uninstalling the proof app removed these records. The temporary database copy and UI hierarchy dump were deleted. The emulator started for this run was stopped.

## Release build

The first arm64 release build failed because the ignored generated Java plugin registrant still
referenced the debug-only integration-test plugin. This Flutter SDK skips regenerating the
registrant when `--no-pub` is used, even when switching from debug to release.

Regenerated only the Android registrant offline using the installed Flutter tooling's
`injectPlugins(FlutterProject.current(), releaseMode: true, androidPlatform: true)` inside
`runInContext`, with `TemplateRenderer` provided by `MustacheTemplateRenderer`. The first helper
invocation lacked that renderer; the corrected invocation succeeded. No tracked source, SDK files,
dependency declarations or target SDK were changed for this build preparation.

Second build attempt passed (19.9 seconds):

```text
heavy env GRADLE_OPTS=-Dorg.gradle.daemon=false flutter build apk --release --split-per-abi --target-platform android-arm64 --no-pub
```

Output: `app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (16.7 MB).
ZIP inspection confirmed only `arm64-v8a` native libraries and the existing five bundled pages.
SHA-256: `bb51d08bbcab8198f8d1001b44e5768583c9e12ec64a6dce260528f4bb65b301`.

## Limits

Not run: physical ARM device execution of the release APK (no connected ARM device), physical Boox,
and full 604-page rendering (the local bundle still contains pages 1, 2, 47, 48 and 50).
