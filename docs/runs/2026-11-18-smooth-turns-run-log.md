# Run log: ready neighbours, fewer recaptures, single-word long-press (2026-11-18)

base 29c752b · dirty at start (not ours): .claude/codex-worker-rules.md, .claude/skills/quran-quick/SKILL.md
mode default · route routine (reader rendering + gesture; no persistence, sync or schema change) · writer Opus medium (session) · pre-check fresh Sol medium · reviewers Fable medium + fresh Sol medium

## Step 1 block

**Problem (Fable perf review, phone traces):** every swipe onto a page not yet opened this session freezes
55–70 ms at its start: the incoming page's word paragraphs are shaped in _LineRender.performLayout
(page_ink.dart:505) when PageView builds it (main.dart:726), plus first use of its font. The cached page
image is dropped on every Reader rebuild (_PageRender.update always invalidates, page_ink.dart:286-302;
_LineRender.update always relayouts, :455; _LoadedReaderPage.didUpdateWidget rebuilds content, main.dart:1056),
so bars, long-press start/end and slider ticks each repaint live + recapture. _prefetch runs from
onPageChanged mid-swipe (main.dart:743) and registers fonts during the animation.

**Rulings:** R43 (owner) long-press reveals one word only, no drag/multi-select; swipe stays locked until
lift (Claude's default). R44 (owner) previous/next screen prepared while reading (portrait ±1 page,
landscape ±1 spread), further pages load after a swipe finishes, rebuilds redraw only what changed.

**Plan:**
1. R43: drop _move/_visited/_previous and onLongPressMoveUpdate (main.dart:603-627, :711); _start reveals the
   word under the finger once; _dragging lock unchanged. Rewrite drag-reveal tests to assert drag reveals nothing more.
2. Keep the cached image across no-op rebuilds:
   - _LineRender.update marks layout only when words/metrics identity, fontSize, height, inkHeight,
     baseline, centered or style differ.
   - _PageRender.update: layout only on controller/DPR/orientation change; paint when dim/fg/bg differ from
     the colours recorded with the cached image.
   - _PageRender.markNeedsPaint override drops the image (generation++, cache remove) unless the call is
     the capture-ready repaint; any descendant repaint/relayout reaches it, so child changes can't show stale ink.
   - paint() uses the image only if its recorded colours equal the controller's.
3. Paragraph pool (page_ink.dart): process-wide acquire/release pool keyed by (text, merged style, width);
   _LineRender acquires instead of creating, releases on replacement/removal/dispose; idle painters are an
   LRU capped at 1200 and disposed on eviction; painters in use are never evicted.
4. Prewarm: Reader records the merged base text style and word size from its LayoutBuilder; after scroll end
   (and first load) it schedules one Priority.idle SchedulerBinding task per ayah line of the R44 neighbours
   (portrait current±1, landscape the spreads before/after) to shape into the pool; a scroll start bumps a
   generation that cancels queued tasks.
5. Defer _prefetch from onPageChanged to ScrollEndNotification (jumpTo also ends a scroll); LoadedPagePhysics
   still clamps at the loaded edge.

**Proof:** tests red first (bars toggle keeps cached image; long-press drag reveals one word; swipe to a
prewarmed page creates zero paragraphs; prefetch not called until scroll end); analyze + full test; R40 parity
84 images on the phone (existing harness); phone 20-swipe profile run, frame-2/3 UI spike before/after.

**Sessions:** writer Opus medium (session)

## Steps
- 0 baseline: done · 1 investigate: done · 2 rulings: R43, R44 (29c752b)
- 3 pre-check (Sol gpt-6.1-sol medium, thread 01a1eeb4-4116-7880-96b0-4332d44a6111): done, folded in:
  - store swap invalidates: painted inputs record (store, dim, fg, bg); update() repaints when they differ
  - override recursion: markNeedsPaint drops image then super; capture's own replacement disposes without onEvict
  - colours snapshotted when capture is scheduled; paint uses the image only if they match
  - pool: one painter per acquisition (duplicates get separate painters), release parks, eviction only of idle
  - prewarm checks scroll state + generation on every step; waits for frames while animations run (no spin); restarts after prefetch publishes
  - fast second swipe vs deferred load: load window widened odd-4..odd+5 (Claude's default, no owner question)
  - ScrollEnd not the only hook: LoadedPageController.prepare and rotation prefetch kept
  - nested repaint boundaries: none inside a page (rg), so descendant changes reach _PageRender
- 4 implement: done 4b2b24a · gate: flutter analyze ok · flutter test 79 passed (heavy, --concurrency=2)
  - Flutter's scheduleTask(Priority.idle) re-posts itself in a tight loop while animations run and never fired under the test clock → replaced by a zero-timer chain, cancelled on dispose
- 5 review: done · r1 0/0/3 (C/H/M) Fable + 2 P2 Sol, 4 LOW
  - M Fable: finger landing mid-settle fires ScrollEnd (hold) → loading/prewarm inside the next swipe → fixed e85874b: act only when the page offset is integral; mutant without it fails smooth_turns "mid-settle"
  - M Fable + P2 Sol: prewarm not redone after style/size change (dark toggle, insets, resize) → fixed: re-warm whenever base style or word size differs; test "a resize that changes the text size"
  - M Fable: swipe lock sticks after a system pointer cancel → dropped: long_press.dart:670 calls onLongPressCancel on PointerCancel; new test "a system cancel after a long-press unlocks swiping" passes without code change
  - P2 Sol: bars test passed on recapture → fixed: asserts the identical cached image
  - L Fable: R24 queue coverage lost in the R43 rewrite → fixed: later long-presses queue behind the failure and commit in order after Retry (word 4 on page 1 resolves to word 3 on long-press — pre-existing hit-testing, test uses words 2-3)
  - L Fable: pool not trimmed on memory pressure → fixed: clearIdle() on didHaveMemoryPressure
  - L Fable: metrics identity check always true (one mutated map) → kept: metrics change only with a new words list
  - L Fable: prewarm stalls while a perpetual animation runs → kept: no CPU spin, resumes after
  - r2 not needed (no C/H, routine, 3 code fixes)
- 6 check: done (each finding read at its lines; Flutter long_press.dart checked for the cancel claim)
- 7 fix: done e85874b · gate: flutter analyze ok · flutter test 82 passed (heavy, --concurrency=2)
- phone run 1 (e85874b): first parity attempt hung 15 min because the phone was asleep and locked (mWakefulness=Asleep, keyguard); reran with stay_on_while_plugged_in=7 (restored to 0 after)
  - R40 parity 84 images: 0 pixels, geometry match; repeat exact (docs/runs/shots/turns-{r40,repeat}.json)
  - perf: landscape frames 403→957 in one continuous burst: every landing re-laid out the page number when new page fonts registered, dropping and recapturing the visible page images
  - fixed 8e9b580: page number gets a fixed 12 px box and its own repaint boundary; test "loading pages after a turn keeps the visible page image" (red without the fix on the identity assert); flutter test 83 passed
- phone run 2 (8e9b580), Redmi Note 9 Pro arm64 profile, same harness:
  - R40 parity 84 images: 0 pixels, geometry match; repeat exact (docs/runs/shots/turns2-{r40,repeat}.json)
  - swipe-start UI freeze, median of 20 (before → after): portrait 33 → 16 ms, landscape 63 → 21 ms
  - worst UI frame: portrait 68.9 → 34.7 ms, landscape 72.4 → 50.1 ms; UI frames over 16.7 ms: 30 → 12 portrait, 30 → 17 landscape
  - raster over 16.7 ms: portrait 30 → 21, landscape 4 → 2; portrait swipe-start raster median 24 → 34 ms (glyph atlas for a newly drawn page font, not addressed)
  - evidence: docs/runs/shots/phone-turns2-perf/frame_samples_ms.json vs phone-settle-perf/
- 8 exit:
  - release arm64 APK grey-mushaf.apk (sha256 9f818a92…) installed on 2be3110f; not observed on screen (phone locked after install)
  - R42 memory growth not re-measured: the 10-page window and paragraph pool add at most a few fonts early and ≤1200 idle paragraphs; not observed
  - not done: glyph-atlas raster spike at swipe start (Fable A3: pre-capture neighbours, 1.5–2 days, R24/R40 risk)
- next action: owner tries the release build; then new UI/UX rulings
