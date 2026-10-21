# Reveal persistence run log (2026-10-21)

Ask: save reveals and reveal counts locally (R2, R6, R11) so they survive an app restart. Phase 1 step 1.

## Step 0 · done

- base `2c1df65`, tree clean, remote `ahmadjz/grey-mushaf`.

## Step 1 · done

- **Problem:** `_black`, `_counts`, `_visited` live only in `_ReaderState` memory (`app/lib/main.dart:80-83`);
  reveal (`:208-213`), drag (`:224-235`) and re-grey tap (`:296-300`) mutate them, nothing saves. No
  SQLite dependency in `app/pubspec.yaml`.
- **Rulings needed:** behaviour when a save fails.
- **Surfaces:** `app/lib/main.dart` gestures and startup, new local repository, `app/pubspec.yaml`
  (`sqflite`, `uuid`, cached offline), tests.
- **Design:** sqflite; tables `local_metadata` (device UUID, identity version), `word_actions`
  (action UUID, device id, word key, target state), `reveal_events` (one per grey→black),
  `word_state` (projection: is_black, reveal_count). Word key `qul-v4-hafs:surah:ayah:word`, not
  the integer id. Write per crossed word during a drag, in order, one transaction each. Load the
  projection once at startup before gestures are enabled.
- **Proof:** (1) real-SQLite tests: close/reopen keeps black state and count, re-grey survives,
  replayed action UUID does not double count; (2) whole flow on the emulator: reveal, drag with a
  revisit, re-grey, force-stop the app, relaunch, words and counts unchanged; (3) force-stop with the
  finger still down keeps the words committed so far; (4) offline dependency resolution and Android
  build; (5) gates `flutter analyze`, `flutter test`.
- **Sessions:** writer `01a16006-8320-7173-b2b6-125620f55876`.

Deferred to phase 2 (not asked now): what happens to local history on first sign-in, account switch,
Android backup restore duplicating the device id.

## Step 2 · done

- R24 (owner): word shows black only once saved; failed save keeps last saved colour plus "Couldn't
  save" with retry. Committed `8c896e9`.

## Step 3 · done

- Writer: nothing open.

## Step 4 · done

- Range `8c896e9..afe671b` (`6c295a8` store, `afe671b` gestures + R24). First attempt stopped
  uncommitted after the retry integration test tapped Retry mid-animation twice; test timing fixed,
  then:
- red first: restart test failed grey/count 0 before implementation
- `flutter pub get --offline`: pass, no online fallback
- `flutter analyze`: pass
- `flutter test`: 32 passed
- integration_test on Medium_Phone (real SQLite): 2 passed (reopen, counts, UUID dedup, rollback,
  retry)
- live Medium_Phone: reveal black/count 1; drag with revisit counted once; re-grey kept count;
  force-stop + relaunch kept colours and counts; force-stop mid-drag kept committed words
  (`docs/runs/shots/persistence-*.png`)
- offline debug APK (android-x64): pass
- not run: Boox, release/ARM build, 604-page performance

## Step 5 · done

- Reviewer `01a16014-11cb-7573-884e-06a44da4c398` (high). r1: 0/0/3 (C/H/M).
  1. MEDIUM `main.dart:94`: after a failed save mid-drag, later crossed words dropped and not retried.
  2. MEDIUM `reveal_store.dart:107`: no-op action UUID not recorded, replay after re-grey counts again.
  3. MEDIUM `reveal_store.dart:31`: newer DB version silently rewritten to 1.
- Reviewer also verified live: force-stop before finger-up keeps committed words, line-break drag,
  spread 1|2, headings inert. PocketBase checks not applicable (no responses read).

## Step 6 · done

- F1 kept: `_enqueue` early return confirmed, words already in `_visited`.
- F2 dropped: no code path replays a UUID before sync. **Phase-2 note:** record no-op actions'
  UUIDs (or dedup server-side) before sync replays actions.
- F3 kept: `version: 1`, no `onDowngrade`; cheap guard.
- Screenshot `persistence-after-restart.png`: بسم/الرحمن/الرحيم black after restart, الله re-greyed.

## Step 7 · done

- Fixes `afe671b..1f16246`: `8a41329` queue behind failure, `1f16246` refuse downgrade.
- analyze pass; `flutter test` 33 passed; integration 3 passed on Medium_Phone; offline APK pass.
- r2 (review thread): no new findings, F1 and F3 verified fixed (fault injection with completion
  gates; downgrade refused live, error screen shown, version/rows/bytes unchanged).

## Step 8 · done

- Proofs: (1) real-SQLite tests pass; (2) whole flow force-stop/relaunch pass; (3) mid-drag
  force-stop pass; (4) offline resolution and APK build pass; (5) gates pass.
- Not observed: physical Boox, phone (owner devices), 604-page performance (only 5 pages bundled).

**Next action:** none. Owner tries on phone and Boox.
