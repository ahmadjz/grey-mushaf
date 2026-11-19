# 2026-11-19 top-bar (R57 run 1) run log

mode default · route routine (reader UI + device-local display prefs in the existing local_metadata key/value table; no schema change, no reveal/sync path) · base c22b6c0 (rulings commits 2567352, cc4b69c)

Dirty files not mine, left alone: .claude/codex-worker-rules.md, .claude/skills/quran-quick/SKILL.md, .claude/skills-backup/, .claude/skills/quran-quick/{references,scripts}/, docs/runs/2026-10-24-* untracked logs.

## Step 1 — done

**Problem.** R29 bar (app/lib/main.dart:851-871) is a 40px strip below the status bar holding only "Settings", inset by the cutout, so the status bar area shows page text and the notch gap stays empty. R52 bar, R59 borders, R60 header line and R45 arrows do not exist. Dark mode switch is in Settings (main.dart:262-270).

**Rulings needed.** None open; R61 Claude's defaults recorded (first-ayah surah/juz, header+border on pages 1–2, menu = dark mode + Settings, arrows default bottom corners, switch on).

**Surfaces.**
- main.dart:738-875 Reader build: Stack(page viewport padded by `_cutout`, bar overlay).
- main.dart:883-996 `_page`: page Stack with lines + page number strip; header line and border go here.
- main.dart:750-758 page height/width + `side` margin (portrait 2% R31, landscape 2px) — header takes height, landscape side must fit the border.
- main.dart:221-380 `_openSettings`; reader_settings.dart; reveal_store.dart:24-58,121-143 local_metadata settings.
- MainActivity.kt getInsets/statusTop; loaded_page_controller.dart:44 animateToPage.
- Page JSON: lines carry `surah` on surah_name lines, words carry `location` "s:a:w"; no juz field → juz from the 30 juz-start verse keys.

**Plan.**
1. `lib/mushaf_index.dart`: 114 Arabic surah names, 30 juz-start keys, `pageSurah(page)`, `pageJuz(page)` from the first ayah word, `arabicDigits(int)`.
2. Top bar: full width from y=0, height statusTop+56, opaque; content inset by cutout/status top. RTL: title column (surah name, "صفحة ٢١٦، جزء ١١") on the right, ⋮ PopupMenu on the left with a "Dark mode" switch item and "Settings". Dark mode removed from Settings sheet.
3. Header line (R60): ~14px row at the page top within text width: "الجزء ١١" right, surah name left, thin line under; height comes out of pageHeight (landscape shrinks a few %).
4. Borders (R59): CustomPaint double line in the side margin: portrait odd=right/even=left; landscape odd page draws right edge + spine (its left), even page draws its left edge. Landscape `side` raised so the border clears ink.
5. Arrows (R45): two faint round chevron buttons on top of the viewport (Stack sibling, so taps never reach word/bar gestures). Left = next (`nextPage`), right = previous; landscape moves a spread. Long-press drags; spot saved per orientation as screen fractions in local_metadata; Settings switch "Page-turn arrows".
6. ReaderSettings gains arrowsShown + arrow spots; SqliteRevealStore persists them.

**Proof.**
- widget tests: bar spans full width and covers status top; title text for page 216; menu dark switch works and Settings has no dark switch; header text per page in portrait + landscape; border side per odd/even/landscape; arrow tap turns page (portrait 1 page, landscape 1 spread) without reveal/bar toggle; long-press drag moves + saves per orientation; switch hides arrows; settings persistence in sqlite integration test.
- gates: flutter analyze, flutter test.
- live: emulator portrait + landscape screenshot with bars shown (notch/status covered).

**Sessions.** writer Opus medium (session) · pre-check Sol medium fresh · reviewers Fable medium + Sol medium fresh.

## Step 2 — done
No owner questions; R61 Claude's defaults committed cc4b69c.

## Step 3 — done
Pre-check Sol thread 01a1f56c. Kept: stale bar title after swipe (ValueNotifier fix), header inside cached page image (RepaintBoundary + fixed box, same as page number), arrow bounds/rapid taps, arrow clamping inside cutout, test migration, dark-mode coverage kept. Portrait size: phones unchanged (computed, below); landscape shrink measured.

## Step 4 — done (27c9015)
- red: top_bar_test.dart failed to compile (PageBorder/openMenuItem missing), then 2 behaviour reds for review fixes (title on left: 290 vs >874; title after rotation not found).
- gate: flutter analyze ok · flutter test 93 passed (docs/runs/shots/topbar-full3.log).
- text size (metrics.json calc): 411×914, 411×866, 360×800, 393×851 portrait unchanged; 914×411 landscape −3.55%, 914×363 −4.06% (R60 "a few percent"); 702×936 tablet-shaped portrait −1.53%; 360×640 −2.25% (Sol r1).
- emulator Medium_Phone: integration_test/reader_settings_test.dart passed (SQLite arrow switch + spot survive reopen, out-of-range refused).
- live landscape (docs/runs/shots/topbar-landscape-preview.png): bar covers status bar full width, borders on outer edges + spine, header lines, faint arrows in bottom corners. Seen bug: title on the left → fixed.
- old tests migrated to menu/top-bar key; widget_test R19 fill bound and blank_tap repro shifted by the 14px header; parity_test dark toggle via menu.

## Step 5 — done
r1 Fable (agent, medium) 0C/2H/3M/3L; Sol thread 01a1f57a 0C/0H/2 P2/1 P3.
- kept+fixed (83f3cdc): H stale arrow target after failed load / rotation; H shared drag origin (two fingers, null crash); M title stale after rotation; L NaN spots; live: title on left.
- kept as Claude default (R61 extended): M portrait ~2% shrink on 16:9/Boox screens; M arrows cover corner words (default moved flush to corners).
- skipped LOW: lazy rapid-tap drop, no retry on arrow save, snackbar covers arrows.
r2 (required: r1 had HIGH): Sol all fixes confirmed + P2 same-index token race → fixed with turn counter. Fable 0C/0H/1M/3L: M swipe during held arrow load → stale target, red at test (page 4 vs 2), fixed 820a807. LOW rounded-corner clipping and mid-drag rotation: not fixed, device check open.

## Step 6 — done
Read every finding at its lines; re-ran full suite 97 passed (docs/runs/shots/topbar-full5.log); viewed portrait + landscape emulator shots.

## Step 8 — exit
- R52 bar layout/menu/Settings: tests + seen live (emulator portrait + landscape).
- R59 borders, R60 header: tests + seen live (landscape header lines, borders, spine).
- R45 arrows: tests incl. fault injection; seen live position; drag not exercised live.
- camera notch gap: not observed (Medium_Phone landscape shows no cutout gap); covered by widget test with left cutout 30.
- Boox / owner phone: not observed.
- parity_test references: not run (header/border change every page by ruling; references need regenerating).

Next action: owner checks on phone; run 2 of R57 (marks + floating toolbar).
