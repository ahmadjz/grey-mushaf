# Run 3 of R57: surah list, bookmarks, quick jump, search (2026-11-20)

mode default · route sensitive (local SQLite schema v2→v3 next to durable reveals and marks; bookmark actions shaped for later sync) · base dad695b

Dirty files not mine (left alone): .claude/codex-worker-rules.md, .claude/skills/quran-quick/SKILL.md,
app/integration_test/perf_baseline_test.dart, .claude/skills-backup/, quran-quick references/ + scripts/,
docs/runs/2026-10-24-* evidence folders.

## Step 0 baseline — done

## Step 1 investigate — done

Problem: R27/R52–R55 need navigation the reader lacks: the app always opens on page 1
(app/lib/main.dart:155-157), the top bar has only title + ⋮ (Dark mode, Show toolbar, Settings)
(main.dart:1149-1241), pages load lazily so a page's surah/juz is only known once loaded
(mushaf_bundle.dart:13-16, mushaf_index.dart:30-45), and no surah/ayah→page table exists.

- Data: QUL Imlaei simple word text is on the machine (repo-root imlaei-simple.db.zip, gitignored by
  `*.zip`; same file in ~/Downloads). One table `words(id, location, surah, ayah, word, text)`, 83,668
  rows, no diacritics. Goes to assets-src/qul-v4/words/imlaei-simple.db (gitignored by `assets-src/`).
- Nav index: generate from the QUL layout + words DBs (scripts/bundle_mushaf.py:267 opens the same
  DBs) into a new gitignored app/assets/index/ (index.json: surah start pages, per-ayah first page,
  ayah counts, juz start pages; search.json: per-ayah Imlaei text + page). Kept out of
  app/assets/mushaf so the bundle ownership check (bundle_mushaf.py:214-256) and the metrics
  sha256 guard (prepare_metrics.dart:34-48, build.gradle verifyMushafBundle) stay untouched.
- Jump: LoadedPageController.jumpToPage prepares the destination first (loaded_page_controller.dart:20-41);
  group index = spread ? (page-1)~/2 : page-1 (main.dart:978-981 already does this).
- Store: SqliteRevealStore.open version 2 (reveal_store.dart:148-196); onUpgrade adds mark tables only.
  v3 adds bookmark_actions + bookmarks (tombstone rows, like word_marks). Run 2 upgrade proof is
  app/integration_test/marks_store_test.dart:106 (exact v1 DDL); v3 needs the same from exact v2 DDL
  and from v1.
- Run 2 open item: mark box is a showDialog route (main.dart:802) so the reader's SnackBar
  (main.dart:518-534) sits under the dialog barrier; Retry can't be tapped. Fix inside this run
  (the box gets its own failure row). Cutout snackbar inset (main.dart:134-139) gets a widget test.

Rulings needed: start screen / last page; where the bookmarks screen lives; search result highlight.

Surfaces: main.dart (top bar, jump, mark box), new nav index loader, surah list / bookmarks / search
screens, quick jump dialog, reveal_store.dart (v3), scripts (index generator + pytest).

Proof:
- widget: surah list juz headers + tap opens page; bookmark toggle + bookmarks screen; quick jump by
  page and by surah+ayah; search by name, page, juz, text; mark-box failure Retry tappable; snackbar
  inset with a cutout.
- integration (emulator): exact v2 DB (with reveals + marks) and v1 DB upgrade to v3 keep every row;
  bookmarks survive reopen; downgrade refused at v4.
- live: emulator screenshots of surah list and search.
- gates: flutter analyze, flutter test, pytest.

Sessions: writer Opus medium (the session); pre-check Sol medium fresh thread; reviewers Fable medium
+ Sol medium fresh thread, then the Opus medium full check (sensitive).

## Step 2 rulings — done

Owner: 1 (opens on the last page), 1 (bookmarks tab on the surah list), search like the reference app
(screenshots: suggestions + full results with count, ayah shaded on its page) → R63–R65 (owner),
R66 Claude defaults. Committed 8ec0a30.

## Step 3 pre-check — done

Sol medium fresh thread 01a1f81b: 13 items. Kept: load the destination before the first frame;
publish highlight only with its navigation; page first-ayah exported directly (`pages` in index.json);
shade compositing; even-page spreads; same-page results; atomic spread bookmark change; monotonic
timestamps; offset map for highlights; mark-box failure state reset; fresh-v3 + failed upgrade tests.
Dropped: prepare-readiness propagation (an unloaded destination already recovers via the page-change
prefetch, existing behaviour).

## Step 4 implement — done

Commits: 919e7ba generator, 5cc8cd0 schema v3, 7a98b20 index/search lib, 6dee024 reader + screens,
58cf9b2 + 88d0a94 + 513a08a review fixes.
Red first: pytest (module missing; ۞ inside words), quran_index tests, navigation widget tests,
mark-box Retry (row absent), overlap jump (timed out on a stale load), stale/rapid snackbar (red on
previous main.dart). Store integration tests were written after the store code (not red-first);
the cross-page clock test was added with its fix.

Evidence:
- pytest: 32 passed (docs/runs/shots/nav-pytest.log).
- flutter analyze: no issues. flutter test: 143 passed (nav-full2.log), then marks/save/dark 35 passed after 513a08a (nav-save2.log).
- emulator Medium_Phone, store: bookmarks_store_test + marks_store_test + downgrade_test 16 passed
  (nav-store-it.log); after fixes bookmarks_store_test 8 passed (nav-store-it2.log): exact v2 DDL
  with reveals + marks → v3 keeps all six tables row for row; v1 → v3 keeps reveals; failed v2→v3
  and v1→v3 roll back; spread change atomic under an injected trigger; clock floor across pages;
  page CHECKs; bad last page → 1; fresh/up-from-1/up-from-2 schemas identical; downgrade refused at v4.
- emulator live: surah list with juz rows (nav-surah-list-preview.png); navigation_live_test passed:
  suggestions, full results, 2:178 shaded on page 27 behind grey words (nav-suggestions-preview.png,
  nav-shade-preview.png), bookmark + last page 27 survive reopening SQLite.
- Not observed: owner's phone/Boox; real v2-APK-over-install; release APK.

## Step 5 review — r1 done

Fable medium: 1H/5M/3L. Sol medium fresh thread 01a1f82d: 3 P2.
- H Imlaei file is a phonetic spelling (هاذا, ذالك, الرحمان): kept, not code-fixable → owner
  needs the standard Imlaei text; matcher now maps offsets through vowels so either form works.
- M stale/queued "Couldn't save" after in-box Retry: fixed (58cf9b2, 513a08a).
- M failed remove left the tab button disabled; Retry outlived the screen: fixed (own messenger).
- M _goTo set the page before it loaded; same-page jump didn't cancel a far one: fixed
  (_requestedPage; cancel navigation + bundle load).
- M quick jump light in dark mode: fixed.
- M cold start loaded pages 1–6 then threw them away, and decoded search: fixed (open(near:), lazy).
- L ۞/۩ in result text: fixed. L silent last-page save failure: not fixed (next settle retries).
  L R66 wording: ruling text corrected to the reference form.
- Sol P2 shade tinted grey words: fixed (shade behind, normal blend). P2 clock per page: fixed.
  P2 same-page jump: fixed (above).

## Step 7 review — r2

Sol r2: r1 items fixed; new P2 rapid retries could close the wrong message → fixed 513a08a (red first).
Fable r2 (on 88d0a94): fixes hold, no caller broken; 0C/0M; H carried (phonetic Imlaei, waits on
the owner's file); 4 L: queued-snackbar close (addressed by 513a08a: hideCurrentSnackBar, one message
kept); offset map memory (fixed, built only for voweled text); ayah-marker field shows as a light disc
on the shade (not fixed, owner to judge on device); highlight/requested page linger after a failed far
load until the next tap or turn (not fixed). No third round.

## Step 6 Claude check — done

Full Opus check of reveal_store.dart (sensitive): additive DDL only, reveal and mark tables untouched,
projection updated after commit, duplicate uuid / no-op skipped, tombstones kept, global created_at
floor. Callers of changed shared pieces: MushafBundle.open (main, tests; near defaults to 1),
LoadedPageController jump/cancel (_goTo), SearchIndex (SearchScreen only), _savePending (enqueue,
Retry, box). Main ruling proof re-run: navigation_test 14 passed, full suite 143 passed (nav-full3.log).

## Step 8 exit

Proofs: R27/R52/R53/R54/R55/R63–R66 widget tests + emulator live; v1/v2→v3 upgrade emulator.
Not done: text search with standard spellings (هذا, ذلك, الرحمن) waits on a standard Imlaei file —
the downloaded imlaei-simple.db is phonetic. Not observed: phone/Boox, release APK, real APK upgrade.

Next action: owner puts the standard Imlaei word file at assets-src/qul-v4/words/imlaei.db, then
`python3 scripts/bundle_index.py` and rebuild; owner checks run 3 on the phone.
