# B/W mode (R8) run log

mode default · route routine (theme/colour work, no sync/auth/schema) · writer Opus medium (session) · pre-check Sol medium fresh · reviewers Fable medium + Sol medium fresh

## Step 0 baseline — done
base f0267f9 on main, remote ahmadjz/grey-mushaf. Dirty files not mine, left alone:
.claude/codex-worker-rules.md, .claude/skills/quran-quick/SKILL.md, app/integration_test/perf_baseline_test.dart,
untracked .claude/skills-backup/, quran-quick references/ and scripts/, docs/runs/2026-10-24-* logs.
Devices: phone 2be3110f (Redmi Note 9 Pro), emulator-5554. No Boox.

## Step 1 investigate — done
Problem: R8 B/W e-ink mode, auto on when Build.MANUFACTURER == ONYX, toggleable. Nothing exists yet:
no ONYX check in MainActivity.kt, no B/W flag in lib/.
Surfaces:
- app/lib/main.dart:133-147 mode colours (_darkMode, _background/_foreground, snackbars)
- app/lib/main.dart:1836 chrome colour (border + header line), already black in light mode
- app/lib/word_marks.dart:19-23 five mark colours (+ black)
- app/lib/main.dart:2225 search ayah shade #D3E6F2 (light blue)
- app/lib/page_ink.dart:555-575 words already flattened to flat ink: no tajweed colours are drawn anywhere
- app/lib/main.dart:388 page-turn animation 250 ms
- android/.../MainActivity.kt method channel (add manufacturer query)
Rulings needed: grey words, mark colours, borders/header/shade/chrome, dark mode interplay, toggle home + memory, page-turn animation.
Proof: emulator with faked ONYX shows B/W on first launch and toggles; phone 2be3110f keeps natural colours; Boox if plugged in.
Imlaei: assets-src/qul-v4/words/ still holds only imlaei-simple.db (phonetic: هذا 0, هاذا 227, الرحمن 0), no new file → search text not rebuilt.

## Step 2 rulings — done
Owner: 1a 2a 3a 4a 5a 6a → R67–R72, committed 46a4eea before code. Claude defaults R73 (search
matches bold+underline in B/W, swatches/tool icons/errors colourless, swipes still follow the finger,
debug-only ONYX fake via `setprop debug.greymushaf.manufacturer ONYX`).

## Step 3 pre-check — not run
Skipped by mistake (default mode runs it for features). Round 1 review caught what it would have.

## Step 4 implement — done (session, Opus medium)
base..head f0267f9..3c1f1e9: fa3095c, 823fbeb, 3c1f1e9.
- red: test/black_white_test.dart compile-red (red.log); leak tests red on pre-fix main.dart (red2.log, red2b.log)
- gate: flutter analyze no issues · flutter test 158 passed (docs/runs/2026-11-20-bw-mode/tests3.log)
- integration on emulator, faked ONYX: isEInk=true, B/W choice survives reopen, junk reads unset — 2 passed (device-emulator.log)
- live emulator (debug, faked ONYX): first launch B/W on — black ball, black/grey switches and slider, grey slider kept (docs/runs/shots/bw-emu-strip-preview.png, bw-emu-settings-preview.png); switched off + restart → stays off; switched back on; fake prop cleared
- live phone 2be3110f (release over the owner's install, same key, data kept): B/W off, teal accents, red ball (docs/runs/shots/bw-phone-settings-preview.png); stay_on restored to 0
- Boox: not observed (not plugged in)
- Imlaei: no new file; imlaei-simple.db still phonetic (هذا 0, هاذا 227, الرحمن 0); search text not rebuilt

## Step 5/7 review
Sessions: Sol reviewer thread 01a1f91b-32eb-79f1-a99a-1c63fbd2592e; Fable code-reviewer agent.
r1: Fable 0C/2H/3M/2L, Sol 0C/0H/3M (overlapping): strip tool icons and tap-box swatches coloured
(fixed 823fbeb), red error roles (fixed 823fbeb), B/W search matches invisible (fixed 3c1f1e9, R73),
bundle-backed arrow path untested (test added 3c1f1e9).
Kept LOW, not fixed: B/W save failure snackbar sits under the Settings sheet (same as arrows switch);
no R67 slider-in-B/W widget test (seen live instead); rapid-arrow test uses wall-clock waits.
r2 (required, H confirmed): Fable APPROVE, Sol no new findings.

## Step 8 close — done
Release arm64 APK copied to repo-root grey-mushaf.apk (gitignored), installed on the phone.
next action: owner tries B/W on the Boox (sideload grey-mushaf.apk; it should start in B/W).
