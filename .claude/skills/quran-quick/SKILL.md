---
name: quran-quick
description: "Deliver one feature or fix for the grey mushaf app (Flutter app, PocketBase sync on the VPS, PDF export). Claude investigates, asks the owner's rulings and checks the work. Three modes per references/modes.md: default (Opus writes, Fable + Sol review), --balanced (Sol writes routine), --low-claude (Sol investigates and writes, Claude rules). --writer sonnet selects Sonnet high. Claude commits the docs and pushes. Use for \"build X\", \"fix Y\", \"next phase\", or /quran-quick."
user-invocable: true
argument-hint: "[what to build or fix | path to a docs/runs/*-run-log.md to resume] [--balanced] [--low-claude] [--writer sonnet|sol]"
---

# /quran-quick: Claude rules and checks, the mode picks who writes

`references/modes.md` is the source of truth for who does each step and at what effort. Three modes
share one policy (Setup), gates and report.

- **Default (no flag).** The Opus medium session investigates, plans, writes and proves; a fresh Sol
  medium thread pre-checks the plan; Fable medium + a fresh Sol medium thread review.
- **`--balanced`.** Claude investigates and plans with targeted reads. Sol writes routine work; the
  Opus session writes sensitive work. Claude checks the diff in full.
- **`--low-claude`.** "I don't have many Claude tokens" or "let codex do it" means this mode. The
  selected writer does the reading, planning, code, test runs and build output; Claude keeps the owner's
  rulings, a light check and the finish. Dual exploration applies here, never in the other modes.

Steps below say where the modes differ. Claude applies the routing and review gates in every mode,
never Codex. A check the writer reports `not run` stays `not run`.

## Setup

- Writer, pre-check and reviewers resolve per mode and route from the roles table in
  `references/modes.md`; record them in the run log at Step 1. Opus is never above medium; Fable is
  medium and a review finder only; never xhigh or max.
- Sol writer (balanced routine, low-claude, `--writer sol`): Codex `gpt-6.1-sol`, medium on every route.
  `--writer sonnet` selects Claude Sonnet high as writer, using `Agent` with `model: sonnet`
  and a prompt to think hard, or the session itself when it runs on Sonnet at high effort.
  In low-claude Opus writes no feature code; it may make a trivial patch of 5 lines or fewer.
- At least one reviewer is always the other vendor. Sonnet high uses `Agent` with `model: sonnet`
  and a prompt to "think hard". Fable medium uses `Agent` with `subagent_type: code-reviewer`,
  `model: fable`, `run_in_background: true`. A Sol reviewer or pre-check is Codex Sol medium in a
  fresh thread for this ask, never the writer's or an exploration thread. Reuse that reviewer
  thread for the same ask's second review. Sensitive work then gets the full Opus medium check
  (the session itself) in every mode.
- Sensitive: PocketBase auth/login/accounts or access rules, deleting or migrating synced user data
  or local SQLite storage schemas, durable reveal persistence, release signing/keystores/store
  publishing, secrets/API keys. Sync work that can lose or overwrite reveals is sensitive.
  When in doubt, sensitive. Record the route and why before choosing effort.
- Every Codex call goes through `mcp__codex-bridge__codex` with `model: "gpt-6.1-sol"`,
  `sandbox: "danger-full-access"`, `approval-policy: "never"` and `cwd: /home/ahmadjz/Documents/Quran`.
  Use `config: {"model_reasoning_effort": "medium"}` for every Sol call, including sensitive routes.
  Never use high or xhigh.
- The first call of every NEW thread sets `developer-instructions` to the contents of
  `.claude/codex-worker-rules.md`, passed once, not an instruction to read the file. Replies use
  `mcp__codex-bridge__codex-reply` and never repeat those rules. Pass the relevant step text or
  line range; Codex never reads a whole Claude orchestrator SKILL.md. Project repo skills it is
  told to follow stay readable.
- If codex-bridge is not connected or a Codex call fails on quota, stop and tell the owner. Never
  substitute `codex exec`, an unselected Claude writer or another mode. Every mode's Codex review
  or pre-check still requires the bridge.
- **Reuse threads, never re-explore** (2026-10-22: fresh high-effort threads used up the ChatGPT Pro
weekly limit in a day). `~/.codex-threads/quran.md` is the registry
(`| role | model · effort | threadId | opened | last used |`). Before a NEW call, read it. For the
same role/model/effort, `codex-reply` on the existing thread, starting the prompt with "New ask:",
across asks and sessions (the bridge resumes old threads). Open a NEW thread only when the role
has none, the model or effort changes, independence requires it (a reviewer never runs in the
writer's thread; a Sol reviewer or pre-check starts fresh for each ask), or rotation requires it.
Before EVERY reply run `python3 .claude/skills/quran-quick/scripts/codex_usage.py <threadId>`.
`SOFT` (context >= 120k) means rotate at the next phase boundary; `FULL` (context >= 160k,
compacted or not found) means rotate now. At SOFT do not start the next phase on the old thread.
A replacement gets a short handoff: rulings, branch + HEAD SHA, files touched, evidence paths and
results, open items, next action. Replace that role's registry row. Update `last used` on every
call. A reviewer reads the affected code, not only the diff: the callers and callees of every
changed symbol, the module's patterns and invariants, and the covering tests, stopping at unrelated
modules. Reuse the selected Sonnet writer's session/Agent context for implementation and fixes.
- `docs/rulings.md` is the home of every decision. Only Claude writes it.

## The run log

`docs/runs/{date}-{slug}-run-log.md` is the session's memory. It holds the mode, the Step 1 block, the rulings
asked, writer/reviewer session or thread ids, the evidence lines, the findings with their outcomes, and the pushed sha. Mark
each step `done`, and write the **next action** after each step. To resume, run the skill with the log
path and reconcile it with `git status` and `git log` before doing anything; the logged mode holds
unless a flag overrides it.

## Dual exploration trial (`--low-claude` only)

Use dual exploration only for consequential uncertainty: ambiguous cause, unfamiliar architecture,
or sync, auth, a migration or reveal persistence. Routine localized work with an established
pattern and decisive proof uses only the selected writer.
Dual exploration uses Sol + Sonnet. Opus medium checks disagreements and the highest-impact shared
assumption; sensitive routes also require the full Opus medium check after cross-vendor review.

1. Give Sol and Sonnet one shared neutral brief: requirements, settled constraints, entry points,
   dirty files and questions, bounded in scope, with no proposed diagnosis. For Sol, reply on the
   registered writer thread (or explorer thread when Sonnet writes) using this project's registry
   and worker rules (including **Keep the context small**). Open a thread only under the existing missing/model-change/independence/rotation rules, never just for
   this trial. Existing writer context stays; neither sees the other's current output until both finish.
2. In the same message, call Sol (`gpt-6.1-sol`, medium) and
   `Agent` with `model: sonnet`, `subagent_type: Explore` (`general-purpose` if commands are
   needed or Sonnet is the selected writer), so they run in parallel.
   Sonnet uses high effort with a prompt to think hard. Cap Sonnet at about 40 tool calls, then return
   findings and uncertainties. Neither spawns more agents, implements or writes the plan yet.
3. Both return `Question | Finding | file:line + decisive evidence | uncertainty | disconfirming check`,
   then short lists: affected boundaries, unresolved decisions, proposed verification.
   Save separate `{date}-{slug}-writer-exploration.md`, `{date}-{slug}-sonnet-exploration.md`
   and `{date}-{slug}-reconciliation.md` reports beside the run log in `docs/runs/`; keep reports short.
   Claude saves Sonnet's returned report; Explore need not write files.
4. Opus checks every disagreement AND the single highest-impact shared assumption with targeted
   reads only, never re-exploration. Unresolved claims go to a targeted check or test, never a vote.
   Save evidence, rulings and remaining uncertainties in the separate reconciliation report; send
   them to the SAME selected writer context before plan writing or implementation. The reviewer stays
   in a separate context that never explores: Sonnet high for Sol writing, or a fresh Sol medium
   thread for Sonnet writing; never reuse the Sonnet explorer as the reviewer. Preserve the skill's implementation route after exploration.
5. Record dual/single selection and why in the phase report. At close compare comparable asks using only the selected writer
   on Claude + ChatGPT quota used, user interventions and escaped defects. Mark unavailable
   measurements unknown and defects not yet observed when follow-up is pending.

## Proof and output budgets

Apply the worker rules' **Keep the context small** to every writer, explorer, reviewer and Claude
check. Before diff hunks use `git diff --stat base..head`, then request only relevant file hunks.
Keep build/test/ADB/SSH logs and proof JSON on disk; return result lines, bounded failures and paths.
Poll long Flutter/Gradle builds every 10-30 seconds with bounded output, never dump progress logs.
For state checks prefer integration assertions/semantics and JSON from `app/test_driver/proof_driver.dart`
(`PROOF_OUT`); for Android state prefer filtered `adb logcat` or a targeted `uiautomator dump`.
Screenshots, browser/device captures and `view_image` are only for a proof or failure diagnosis,
at most 2 per check. Downscale display copies to <=720px wide when supported; keep original pixels
on disk for `app/tool/parity_diff.dart` and `app/tool/rgba_diff.dart`. Parity batches may save all
required originals locally via `app/test_driver/parity_driver.dart` (`PARITY_OUT`), but return only
counts/diff results and paths, never PNG bytes or the full `capture.json`. Inspect at most two
representative image proofs per check. Export proof keeps the page-count and sample line-break
checks; inspect at most two downscaled sample-page renders per check. If a check needs more output,
give a one-line reason before a bounded expansion and say when output is truncated; the image cap
still applies. Stop and report what you have if this turn passes 60 tool calls. Include completed
proofs, not run items and next action; resume in another turn under the thread rotation rules.

## Steps

0. **Baseline.** Run `git status --short` and `git log -1 --format=%h`, and record the sha as `base`.
   Leave dirty files you did not make alone, and name them in the log. Check that `git remote -v`
   shows `ahmadjz/grey-mushaf`.
1. **Investigate.**
   **Default and `--balanced`:** Claude traces the code itself (`rg -l`, then line ranges, never whole large files), writes
   the block below with `file:line`, and sends only the open decisions on to Step 2.
   **`--low-claude`:** apply **Dual exploration trial** when its triggers hold. After reconciliation (dual) or
   directly (single), ask the SAME selected writer (registry thread for Sol, else NEW) for the
   following block. Give the writer the ask and the relevant rulings. Ask it for the cause or
   design with `file:line`, plus four lists: open decisions, wrong premises, gaps, and risks. Ask for no
   code yet. Claude verifies each item at its cited line and creates the run log with this block:
   `Problem / Rulings needed / Surfaces / Proof / Sessions`. In every mode, record the mode, route
   and why, writer, pre-check and reviewers from `references/modes.md` in Sessions.
2. **Rulings.** Ask the open decisions in the chat reply, never AskUserQuestion (the owner rejects the
   pop-up and answers with screenshots): short numbered questions headed "Ruling N of M", recommended option first. Use plain words: what the owner sees on the phone or Boox under each
   option. No jargon (the owner asks again when a question is abstract). The owner's free-text answer is
   the ruling. Write each ruling into `docs/rulings.md` and commit it (`git add docs/rulings.md`)
   before any code. A technical default the owner would not care about can be Claude's own. Record it
   as "Claude's default" only when it changes behaviour the owner could notice. If the writer returns
   `NEEDS_DECISION` later, ask it the same way and reply on the same thread.
3. **One check.** **Default and `--balanced`:** blind pre-check of Claude's plan per the modes table
   (fresh Sol medium thread, "report only"; Sonnet high instead when Sol is the writer). Default runs
   it always for features, for bugs only when the fix is sensitive or touches more than ~3 files;
   balanced runs it on sensitive routes only. Claude verifies each item at its line, folds in what
   holds and sends the plan and rulings to the writer (or keeps them, when the session writes).
   **`--low-claude`:** reply on the selected writer context
   (`codex-reply` for Sol) with the rulings, asking only whether anything is still open. Handle the answer as in Step 2. There is no third pass: anything still open after this
   goes to the owner as a blocker.
4. **Implement (writer context).** The selected writer (the Opus session itself when it writes) follows `.claude/codex-worker-rules.md`: failing test first,
   then the gates and the live proof that rule file names, then one local commit per coherent change.
   Sync work also proves going offline, restarting the app, reconnecting and seeing both devices
   agree. Export work also checks page count and line breaks on sample pages.
   It returns one evidence line per check, `base..head`, and anything `not run`. Claude copies them
   into the run log and never fills a `not run` from the writer's prose.
5. **Review (reviewers per the modes table; default runs Fable medium + fresh Sol medium in parallel).**
   Never the writer's thread/context or an exploration context. The brief is `base..head`, the
   rulings touched, the must-check list from Step 1, the affected-code reading rule from Setup, and
   "report only". Ask for severity, `file:line`,
   the ruling it breaks, and a concrete failure. For a UI change, the reviewer runs the app itself where
   it can and marks each finding `seen live` or `from code`. Every brief also demands the following.
   The reviewer reports a demand that does not apply as `not applicable: <why>`.
   - Map every ruling the change touches to the test that proves it. Flag a ruling with no test, or a
     test that asserts the opposite.
   - For every PocketBase response the app reads, test nullable fields as `null` and optional fields
     omitted.
   - Test the whole flow through the real callers, not only the changed function. Examples: a reveal
     surviving an app restart and then a sync, a drag across a line break, a spread with pages 1|2.
   - Prove a claimed race or sync-conflict fix with fault injection that pauses the other side at
     the bad moment, never with sleeps or a single passing run.
6. **Claude checks.** Default and balanced walk every caller of each changed shared piece and re-runs the one test
   that proves the main ruling; `--low-claude` spot-checks one evidence line that matters. Read `git diff --stat base..head`, then the diff. For each finding, read the cited
   lines and about 15 around them, then keep it or drop it with one line why. Treat "no findings" with
   no checks run as unreviewed and send it back once. Look at the bounded proof screenshot(s)
   the writer produced. Never act on a Fable finding unread. For sensitive work, Opus medium then does a full check of the change, rulings,
   callers, tests and live evidence, beyond the cross-vendor findings.
7. **Fix (writer context).** Send the kept CRITICAL, HIGH and MEDIUM findings back to the
   original writer context first (`codex-reply` for Sol, the session itself for Opus). The selected writer fixes them test
   first, re-runs the gates and the live proof they touched, and adds new commits. Claude reads the fix
   diff. Run a second review with the same reviewers (`codex-reply` on the Sol review thread) when round 1 confirmed a
   CRITICAL or HIGH, when a fix touched sync, auth, a migration, reveal persistence or the export, or
   when more than four findings were fixed. Sensitive fixes receive a full Opus medium check after that review. There is no third round. A confirmed CRITICAL, HIGH or
   MEDIUM still open blocks the push.
8. **Exit check, push, close.** Give every proof listed in the Step 1 block its evidence line, or
   write `not observed` and why. An unmet proof means the feature is pushed but **not done**, and the
   report says so. Close the run log (next action, findings), commit it with `git add <log>`, then
   `git push` on the current branch (`main` is fine for this solo repo). Never force. Update the
   project memory and report:

```
mode <default|balanced|low-claude> · route <routine|sensitive> (<why>) · writer <model effort> · reviewers <model effort, ...> · escalated <no|why>
{slug} · {one line}
  rulings   N new (R12–R14), M Claude defaults
  sessions  writer {model effort, thread/session} · reviewer {model effort, thread/session}
  gate      flutter analyze ok · flutter test 42 passed · pytest 6 passed
  live      emulator Pixel 7: long-press reveal seen (docs/runs/shots/…png); not observed: Boox
  review    r1 0/1/2 (C/H/M) → 3 fixed · r2 not needed
  pushed    main a1b2c3d
```

## Guardrails

- Never commit source assets (zip, PDFs, `ai-pages/`, fonts, QUL data). The repo is public.
- Never touch VPS containers that are not this project's.
- Never mention Claude, Codex or AI in commits.
- Never fabricate a gate result or a device observation.
