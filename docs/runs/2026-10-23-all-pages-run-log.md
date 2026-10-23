# All 604 pages — run log (2026-10-23)

base: c98b18a. Dirty files not mine, left alone: `.claude/codex-worker-rules.md`,
`.claude/skills/quran-quick/SKILL.md`.

## Step 1 block

- **Problem:** the app bundles pages 1, 2, 47, 48, 50 only. Bundle all 604 with one text size,
  printed line breaks, R19–R23 layout and the real headings, then measure startup, memory and APK
  size. `scripts/bundle_mushaf.py --all` exists; `app/lib/main.dart:37` loads every font and page
  eagerly and `main.dart:420` measures every word before the first page.
- **Rulings needed:** none from the owner (R19–R23 cover it). R39 is Claude's default: start ≤2 s,
  PSS ≤300 MB on Medium_Phone, else lazy loading with no visible change.
- **Wrong premises:** heading placeholders are already replaced (traced basmallah, surah font);
  `app/README.md:39` is stale.
- **Surfaces:** `scripts/bundle_mushaf.py`, `app/lib/main.dart`, `app/test/line_bounds_test.dart`,
  `app/README.md`.
- **Proof:** all-pages bounds test incl. heading lines (pages 1, 2, 187, 604 and every page);
  cold start median of 5 to first rendered page; PSS after start and after paging; arm64 release
  APK bytes; screenshots of a few late pages; `git ls-files` shows no fonts/data.
- **Sessions:** writer (investigation) 01a16370-7489-79d0-a7a3-34632d9c6541, now FULL; new writer
  thread for implementation below.

## Steps

- 0 baseline: done
- 1 investigate: done
- 2 rulings: done (R39 Claude's default, no owner questions; unit tightened to MiB in 9894043)
- 3 check: done, writer said nothing open
- 4 implement: done (writer 01a16833-5047-7f21-acc8-c4f52c4f2e8e)
- 5 review r1: done (reviewer 01a16850-947f-7df1-a310-339e958db0c4; registry reviewer thread was
  locked by another session)
- 6 Claude checks: done, all findings kept
- 7 fix + review r2: done
- 8 push: done

## Evidence (full lines in docs/runs/2026-10-23-all-pages-evidence.txt)

- eager baseline (rejected): first frame median 4,469 ms, PSS ~370 MB → R39 failed, lazy loading built
- bounds: all 604 pages incl. heading lines pass at four viewport sizes (portrait + spread)
- parity: Android integration compares every word's width/left/right and the global metrics to
  device shaping: passed
- cold start, release, Medium_Phone ×5: median 322 ms (314–363); reviewer r2 single run 349 ms
- PSS at launch 67–69 MB; full 1→604 read in one session: peak 300,845 KiB = 293.8 MiB (r2), meets R39
- arm64 release APK: 88,076,897 bytes, copied to grey-mushaf.apk (gitignored)
- gates: flutter analyze clean; flutter test 58 passed; pytest not run (no Python changed)
- Gradle guard rejects partial, stale or other-engine bundles (negative test seen)
- R2/R24: reveal → restart → lazily reloaded page shows black; cross-line drag reveal works (r1, live)
- screenshots: docs/runs/shots/2026-10-23-all-pages-{187,300,604}-portrait, landscape, fast-paging
- asset audit: `git ls-files` shows no fonts, data or assets/mushaf
- not observed: owner's phone and Boox (arm64 device run)

## Findings

r1: HIGH full-read memory 331 MB → fixed (uncached JSON etc.); HIGH rotation during far jump evicts
visible spread → fixed; MEDIUM pending-font entry dropped → fixed; MEDIUM silent load errors → fixed
("Couldn't load page" + Retry); LOW Gradle guard missing engine identity → fixed.
r2: MEDIUM rotation cancels prefetch, reader stuck at 3|4 → fixed e7325ae with Completer test.
No third review round, as the skill specifies.

base..head: c98b18a..e7325ae

**Next action:** owner installs grey-mushaf.apk on phone and Boox and pages through late surahs.
