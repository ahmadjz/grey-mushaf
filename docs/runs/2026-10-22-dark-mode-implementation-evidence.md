# Dark mode implementation evidence — 2026-10-22

Base: 6d1df44. Code commits: 5b5c381 (glyph filter), 2727891 (reader, preferences, native bars, tests).
The pre-existing untracked 2026-10-22-dark-mode-run-log.md was left untouched.

## Checks

- Red: filter tests failed to compile because background was absent; then passed with background-aware mapping.
- Red: UI tests failed on absent native mode notification and Settings switch; then passed.
- Red: Android preference integration failed to compile on absent darkLevel/saveDarkLevel; then passed.
- flutter analyze: no issues.
- flutter test: 45 passed, including palette pixels, actual ayah numeral/field pixels, all three white heading forms, page-1 reveal/failure/Retry, inert dark heading, independent sliders, serialized writes and mode-safe retry, both platform brightness values, ignored platform changes, resume, fresh Reader startup and measurement reuse.
- Android reader_settings_test.dart: passed; two independent databases, default/range/reopen, malformed and numeric out-of-range fallback, failed writes, populated word tables unchanged.
- Android sqlite_test.dart and persistence_test.dart: passed after updating semantics assertions to distinguish revealed from unrevealed with a preceding delimiter.
- flutter build apk --debug: passed; production main entry point used for manual screenshots.
- flutter devices: Medium_Phone emulator-5554, Android 17/API 37 x86_64; launched with -memory 4096 -no-snapshot -no-window -no-audio.
- Live: pages 1, 2, 48, 50 dark with revealed words; compact/wide headings white; ayah fields black and numerals readable.
- Live: OS night mode yes plus cold start renders light; force-stop after dark and relaunch also renders light while revealed state remains saved.
- Live: OS changed to light while reader dark, reader remains dark; HOME/resume retains dark.
- Native bars: dark reader + light OS has white icons and no LIGHT_STATUS_BARS/LIGHT_NAVIGATION_BARS flags; light reader + dark OS has dark icons and both flags. Window dumps are under shots/.
- git diff --check: passed.

## Corrections during verification

The first filter-test command was mistakenly run from the repository root (no pubspec); corrected to app/.
An analyzer missing-braces finding was fixed without suppressions.
Adding a second Settings test exposed a repeated font-load hang in that test file. One full run was stopped and a targeted run timed out; moving loadPages to setUpAll resolved it. All assertions remain. The final full suite passed.
Initial screen captures taken before animation completion were replaced with settled captures and visually inspected.

## Screenshots

- docs/runs/shots/dark-bars-system-light.png
- docs/runs/shots/dark-cold-after-dark.png
- docs/runs/shots/dark-cold-system-dark.png
- docs/runs/shots/dark-light-bars-system-dark.png
- docs/runs/shots/dark-page-1.png
- docs/runs/shots/dark-page-2.png
- docs/runs/shots/dark-page-48.png
- docs/runs/shots/dark-page-50.png
- docs/runs/shots/dark-resume.png
- docs/runs/shots/dark-settings.png

## Proof records and cleanup

No accounts or tokens were created. All following identifiers refer to local emulator proof data.

Manual proof device: db2505da-97f4-4c0b-b840-7efe2df6daee. Metadata record keys: device_id, identity_version.
Each following action UUID is also its reveal_events primary key; each word key identifies its word_state record:

- 624cc5c3-c1d5-4ad6-8143-3af774e78d37 — qul-v4-hafs:1:1:1
- a2b596a3-bf47-46a6-baab-e0afb05f3e12 — qul-v4-hafs:1:1:5
- c7482f16-3cbd-40a8-8fea-2af6e654c457 — qul-v4-hafs:2:1:1
- caa37048-b492-4d49-a48b-d28500d14f74 — qul-v4-hafs:2:1:2
- 0b1a846b-093b-4f15-8527-9799d36042f8 — qul-v4-hafs:3:1:1
- 22be2d90-c468-4101-b4f8-17a80d38c171 — qul-v4-hafs:3:1:2
- 03430faf-483d-4b78-89f4-1c7dd6611e2a — qul-v4-hafs:2:282:17
- cfc32dbb-5c1f-4dec-8757-f72c542e984b — qul-v4-hafs:2:282:19

Manual proof cleanup: pm clear tech.ahmadjz.greymushaf returned Success before the final integration runs, removing reveals.db and all above records. The temporary host database copy was deleted.

Integration identifiers below are recorded for every successful run, including reruns. Preference databases are reader-settings-proof.db and reader-settings-other-proof.db; SQLite uses persistence-test.db; startup uses reveals.db. Each test closes and deletes its databases. The preference proof creates word_state for qul-v4-hafs:1:1:1 and a reveal_event keyed by its printed action UUID. SQLite word_state keys and action UUIDs are printed; its reveal_event keys are the first, third and fifth listed actions. Startup creates one word_state and one reveal_event keyed by its printed action UUID. Metadata keys are device_id/identity_version, plus preference keys where listed. Temporary failure triggers are removed, then their databases deleted.

### dark-store-green

- Preference proof device identifiers: 4935a0d3-eba6-4d2a-83e3-40c3f03e8c2a, 55e77f4d-fce4-4e85-80dd-14023a6865c1; metadata keys: device_id, identity_version, reader_grey_level. No accounts or tokens.
- Dark preference proof word: qul-v4-hafs:1:1:1; action: e8cbd0a7-ab4d-4c0b-8580-7f1b054a8b9d
### dark-integrations-final

- Preference proof device identifiers: 0bbf1c10-64fe-4b32-97a5-efe39187dc89, 604e664a-b5cf-4556-b468-d15aad08ead5; metadata keys: device_id, identity_version, reader_grey_level, reader_dark_level. No accounts or tokens.
- Dark preference proof word: qul-v4-hafs:1:1:1; action: 1fcacd0c-c42e-4182-8acc-47a978d2f1c1
- SQLite proof identifiers: [{key: device_id, value: 2c0e8c53-26d1-4e1b-91e6-8bc5afcde6d6}, {key: identity_version, value: qul-v4-hafs:1}]; [{action_uuid: b41e41ff-4911-4799-b072-e1fe0999b92c, word_key: qul-v4-hafs:1:1:1}, {action_uuid: c361fb2d-d45b-402d-b953-e1928f33a16e, word_key: qul-v4-hafs:1:1:1}, {action_uuid: f2c6ff46-9c8d-4530-84e1-cca734a28d72, word_key: qul-v4-hafs:1:1:1}, {action_uuid: cc8ba95d-84e8-48e2-b28f-14c36e31b2e8, word_key: qul-v4-hafs:1:1:1}, {action_uuid: 409815d4-b7bf-479f-b0a7-26575f97e918, word_key: qul-v4-hafs:1:1:2}]
- Startup proof identifiers: [{key: device_id, value: b44f401a-e035-4413-8a5e-20bdf0ec23b2}, {key: identity_version, value: qul-v4-hafs:1}]; [{action_uuid: 0081e01b-071c-4da2-aff6-57fe101a5f69, word_key: qul-v4-hafs:1:1:1}]
### dark-integrations-verified

- Preference proof device identifiers: ac714f14-e3e4-4efb-86af-a24ae0680b44, e708885e-ef5d-4eaa-89b2-ea6356e5f810; metadata keys: device_id, identity_version, reader_grey_level, reader_dark_level. No accounts or tokens.
- Dark preference proof word: qul-v4-hafs:1:1:1; action: 4150ccfa-2336-49e7-987a-3e47e27936db
- SQLite proof identifiers: [{key: device_id, value: 074a2f9a-9fdd-4b43-923a-88a329c8d50b}, {key: identity_version, value: qul-v4-hafs:1}]; [{action_uuid: e1c9d406-a00c-427a-82bf-e29036eb26c8, word_key: qul-v4-hafs:1:1:1}, {action_uuid: 17e659fa-28d4-4bf3-9d06-8b64d0319353, word_key: qul-v4-hafs:1:1:1}, {action_uuid: 88a82ac6-192a-454c-9786-add39506abc5, word_key: qul-v4-hafs:1:1:1}, {action_uuid: 4082b695-1101-4dfc-8947-03ff4534e8b4, word_key: qul-v4-hafs:1:1:1}, {action_uuid: 18cf9344-01db-4d94-9b8a-506b525c25e0, word_key: qul-v4-hafs:1:1:2}]
- Startup proof identifiers: [{key: device_id, value: e02c32f2-d6f5-4115-80ac-2db438d7e463}, {key: identity_version, value: qul-v4-hafs:1}]; [{action_uuid: cae299c9-9009-49ac-afb0-44092f2a8950, word_key: qul-v4-hafs:1:1:1}]

Final package-list check returned no matching package. A redundant adb uninstall reported DELETE_FAILED_INTERNAL_ERROR; the package was already absent at the subsequent package-list check. The dump /sdcard/dark-window.xml was removed and OS night mode set back to no.

## Not run / limits

- Physical phone, Boox, ARM release execution and other Android versions: no such target used.
- Full 604-page rendering/performance: local bundle has only pages 1, 2, 47, 48 and 50; no frame-time benchmark was run.
- Live landscape dark screenshots and live dark storage-failure screenshot: not run; layout/gesture and dark failure/Retry are covered by widget tests.
- Python/server gates: not run; no Python or server source changed.
- No push or deployment. No unresolved owner decisions.
