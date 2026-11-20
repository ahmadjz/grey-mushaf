# Export run log (phase 2 part 2, R57 order)

mode default · route sensitive (VPS job reading user data; per-user access) · base f2f2ac0

## Step 0 baseline — done

Clean tree at f2f2ac0, remote ahmadjz/grey-mushaf.

## Step 1 investigate — done

**Problem.** Server-side PDF (R7) of all 604 pages, grey with the user's revealed words black and
every mark (R50), each user only their own (R11/R83). Before that: arm64 release APK with sync on
phone 2be3110f and Boox 655E999A, data kept.

**Findings.**
- `ai-pages/` holds 74 of 604 .ai pages (`ls ai-pages | wc -l`), and `1441-AI-hafs.zip` is a
  partial archive (no central directory). `make_grey_mushaf.py` greys whole text layers and has no
  word boxes, so it cannot colour single words or reach 604 pages.
- The app draws QUL V4 per-page fonts (`assets-src/qul-v4/fonts/p1..p604.ttf`) with the page JSON
  in `app/assets/mushaf/NNN.json` (`page`, `font`, `lines` with words and headings) and flattens the
  tajweed colours with `FlatInk.thresholdFilter` (`app/lib/flat_ink.dart:46`). Rendering from the
  same fonts and JSON gives the app's line breaks by construction.
- Synced data: collections in `server/pb_migrations/1763650000_sync_collections.js` (reveal state
  `black`, marks `kind/style/color`, bookmarks), owned by `user`.
- VPS: 2 CPUs, 7 GB, container `pocketbase-mushaf` only; `/srv/mushaf.ahmadjz.tech/{pb_hooks,pb_migrations}`.
- Release builds are debug-signed (`app/android/app/build.gradle.kts:39`), same as the installed
  apps, so `adb install -r` keeps data.
- Neither 2be3110f nor 655E999A attached at start (only two emulators).

**Rulings needed.** Start/delivery, page size, mark colours, range, render source and how assets
reach the VPS.

**Proof.** 604 pages; pages 1, 2, 50 and a dense page with line breaks matching the app; owner's
revealed words and marks in the PDF; another user refused.

**Sessions.** Writer Opus medium (session). Pre-check Sol medium fresh. Reviewers Fable medium +
Sol medium fresh, then Opus full check.

## Pre-export APK

- build: arm64 release with sync ok (90.3 MB), copied to repo-root grey-mushaf.apk 2026-11-20 23:39.
- install on 2be3110f / 655E999A: not run (devices not attached).
- both devices agree after owner sign-in: not observed yet.

## Step 2 rulings — done: R84, export on hold

The owner put the whole export on hold before answering. Steps 3–7 not run. Nothing pushed except
docs.

Next action: install grey-mushaf.apk on 2be3110f and 655E999A when attached (adb install -r), owner
signs in, check both agree. Export resumes from the six open questions in this log's chat.
