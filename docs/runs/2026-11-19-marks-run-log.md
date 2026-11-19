# 2026-11-19 marks (R57 run 2) run log

mode default · route sensitive (local SQLite schema v1→v2 next to durable reveals; mark actions shaped for later sync) · base aa086a4

Dirty files not mine, left alone: .claude/codex-worker-rules.md, .claude/skills/quran-quick/SKILL.md, .claude/skills-backup/, .claude/skills/quran-quick/{references,scripts}/, docs/runs/2026-10-24-* untracked logs.

## Step 1 — done

**Problem.** Words carry only visible/grey (reveal_store.dart:9-23, word_state table). No line/shape marks, no tools, no floating toolbar. Long-press always reveals (main.dart:675-679); tap re-greys a black word (main.dart:853-862). Run 1 leftovers: load-error snackbar covers the bottom arrows (main.dart:591-603); arrow spot save failure has no Retry (main.dart:175-181).

**Rulings needed.** None open; R62 Claude's defaults (tool exclusivity, first-launch state, tap box behaviour, ball placement/tuck, persistence, snackbar placement).

**Surfaces.**
- reveal_store.dart: schema (onCreate :110-142, version 1 :102), save (:221-269). New: version 2, onUpgrade adds `mark_actions` + `word_marks`; reveal tables untouched.
- RevealStore interface + test fakes (test/memory_reveal_store.dart, ControlledStore in save_feedback_test).
- ReaderSettings (reader_settings.dart) + SqliteRevealStore local_metadata: toolbar prefs.
- page_ink.dart: PageInkController.color/label (:142-147), _PageRender.paint (:471-516) — marks drawn after the ink filters, captured into the page image (invalidated by changed()).
- main.dart: _pending queue (:431-475) generalised to word + mark actions; long-press (:675); tap (:853); Stack (:821-939) gets the ball + strip; ⋮ menu (:997-1024) gets "Show toolbar"; theme snackbars floating between arrows.
- integration_test/downgrade_test.dart hard-codes "version 2 is newer" → 3.

**Plan.**
1. Store: `enum LineMark {single, double}`, `enum ShapeMark {rectangle, circle}`, `enum MarkColor {red, blue, green, orange, purple, black}`; `WordMarks` record (line, lineColor, shape, shapeColor). `MarkAction(key, kind line|shape, value?, color?)` with uuid; value null = remove. RevealStore gains `marks(key)` + `saveMark(MarkAction)`.
2. Schema v2: `mark_actions(local_seq AUTOINCREMENT, action_uuid UNIQUE, device_id, word_key, kind CHECK, value CHECK nullable, color CHECK nullable, CHECK value/colour both null or both set)`; `word_marks(word_key, kind, value, color, last_action_uuid FK, PK(word_key, kind))`. onCreate = v1 DDL + v2 DDL; onUpgrade(1→2) = v2 DDL only. saveMark in a transaction: duplicate uuid or no change → no-op; else insert action, upsert/delete projection. reveal_count never touched by marks.
3. Reader: one queue of actions (WordAction | MarkAction) saved in order; R24 (word shows a mark only after save; failure → "Couldn't save" + Retry).
4. Long-press applies every active tool (R47): visible → reveal if grey; line → set if none, replace if other line type, leave if same type (any colour); shape likewise.
5. Tap (R48): no line/shape and black → grey at once; any line/shape → dialog with a checkbox per present mark (visible, line, shape) + "Clear all".
6. Painting: line(s) under ink, rect/oval around ink, stroke in mark colour; black → foreground (white in dark). Semantics label adds marks.
7. Floating ball + strip (R51/R62): Stack overlay above viewport; pan drag, tuck at left/right edge, pin; tap opens strip (5 tools, 6 colours, top bar toggle, pin, hide). Hidden → ⋮ menu "Show toolbar". Prefs in local_metadata.
8. Run 1 leftovers: floating snackbars with side insets clearing the corner arrows; arrow spot failure Retry.

**Proof.**
- widget tests per ruling: R46 three marks + count, R47 apply/keep/replace/no tools, R48 tap grey vs box/untick/Clear all, R49 dark black→white, R51 drag/tuck/pin/strip/hide/menu restore, R24 mark save failure + Retry, leftovers.
- integration (emulator): v1 DB with reveals (exact v1 DDL) upgraded → reveals + counts + actions unchanged, marks save and survive reopen; downgrade refusal at v3; toolbar prefs survive reopen.
- live: emulator screenshot with marks + strip open, light and dark.
- gates: flutter analyze, flutter test.

**Sessions.** writer Opus medium (session) · pre-check Sol medium fresh · reviewers Fable medium + Sol medium fresh, then Opus full check (sensitive).

## Step 2 — done
No owner questions; R62 Claude's defaults committed 7af6bfc (strip-outside-tap line added 86a6242).

## Step 3 — done
Pre-check Sol thread 01a1f58d. Kept all 9: tombstones + deterministic order (created_at, device_id), stop-at-first-failure queue, intent from committed + pending, retick in box, rollback test + shared DDL, strict CHECKs, cached-pixel tests, overlay gesture ownership, ordered tool list persisted.

## Step 4 — done (7a49fcb)
- red: store tests written after the store code (red not observed); snackbar-clear test red with floating removed (docs/runs/shots/marks-snack-red.log); ball drag red (touch slop lost) → DragStartBehavior.down.
- emulator Medium_Phone: marks_store_test + downgrade_test 5 passed (docs/runs/shots/marks-store-it.log): v1 DB built with the exact v1 DDL + 6 reveal actions → upgrade keeps all four reveal tables row-for-row, counts intact; failed upgrade rolls back to v1; bad mark rows refused; downgrade refused at v3.
- gate: flutter analyze ok · flutter test 114 passed (marks-full.log).
- live (emulator, landscape spread): red single line, blue double line, green box, purple circle, black circle+line → white in dark (docs/runs/shots/marks-closed-zoom.png); strip light + dark (marks-light-preview.png, marks-dark-preview.png).

## Step 5 — done
r1 Fable (agent) 0C/1H/4M/4L; Sol thread 01a1f59f 3 P2.
- kept+fixed (86a6242): H no pixel proof → pixel tests portrait + spread (add/replace/remove/dark); M box auto-close could pop the reader (red); M created_at could sort a removal before its add (clamped); M tap on a grey word whose reveal failed queued a re-grey (red); P2 checkbox ignored retick during a slow save (red); M whole-flow tests → Reader→SQLite→restart, tombstone reopen, failed write rollback, schema parity (emulator 10 passed, marks-store-it2.log); L cutout in snackbar inset; L Retry uuids/order asserted; L notifier disposed.
- kept as Claude default: P2 strip-open outside tap only closes it (R62).
- skipped: L snackbar under the open box (dismiss then Retry).
r2 (required: r1 HIGH + store change): Fable approve 0C/0H/0M/4L; Sol 2 P2 (Clear all missed a pending-failed mark; save after reader closed hit disposed notifier) — both red then fixed 7c54ddb; L vacuous black pixel check fixed. Not fixed: L no cutout snackbar test.

## Step 6 — done
Read every finding at its lines. Opus full check: reveal_store diff only adds (class header + version line changed, reveal save untouched); callers of _enqueue/_tapWord/_openMarkBox/saveMark walked. Full suite 121 passed (marks-full3.log).

## Step 8 — exit
- R46/R47/R48/R49/R51/R62: widget tests + pixel tests; seen live on emulator (marks, strip, dark).
- Existing reveals survive the upgrade: emulator integration test (exact v1 DDL). Not observed: upgrading a real installed v1 APK.
- Run-1 leftovers: snackbars clear the arrows, arrow spot Retry — tests.
- Boox / owner phone: not observed. No release APK built.

Next action: owner checks on phone (build release APK); then run 3 of R57.
