---
name: quran-quick
description: Deliver one feature or fix for the grey mushaf app (Flutter app, PocketBase sync on the VPS, PDF export). Claude asks the owner's rulings and checks the work. Codex Astra (medium) investigates, writes, commits locally and reviews. Claude commits the docs and pushes. Use for "build X", "fix Y", "next phase", or /quran-quick.
user-invocable: true
argument-hint: "[what to build or fix | path to a docs/runs/*-run-log.md to resume]"
---

# /quran-quick: Codex builds, Claude rules and checks

A tightened `/um-quick --low-claude`. Claude spends its tokens on the owner's rulings and the final
judgement. Codex spends its tokens on reading code, writing it, running it and reviewing it.

## Setup

- Every Codex call goes through `mcp__codex-bridge__codex` with `model: "gpt-6-astra"`,
  `config: {"model_reasoning_effort": "medium"}`, `sandbox: "danger-full-access"`,
  `approval-policy: "never"` and `cwd: /home/ahmadjz/Documents/Quran`.
- The first call of every thread sets `developer-instructions` to the contents of
  `.claude/codex-worker-rules.md`. Replies go through `mcp__codex-bridge__codex-reply`.
- If codex-bridge is not connected, stop and tell the owner. Never substitute `codex exec` or a
  Claude writer.
- `docs/rulings.md` is the home of every decision. Only Claude writes it.

## The run log

`docs/runs/{date}-{slug}-run-log.md` is the session's memory. It holds the Step 1 block, the rulings
asked, both thread ids, the evidence lines, the findings with their outcomes, and the pushed sha. Mark
each step `done`, and write the **next action** after each step. To resume, run the skill with the log
path and reconcile it with `git status` and `git log` before doing anything.

## Steps

0. **Baseline.** Run `git status --short` and `git log -1 --format=%h`, and record the sha as `base`.
   Leave dirty files you did not make alone, and name them in the log. Check that `git remote -v`
   shows `ahmadjz/grey-mushaf`.
1. **Investigate (writer thread).** Give Codex the ask and the relevant rulings. Ask it for the cause or
   design with `file:line`, plus four lists: open decisions, wrong premises, gaps, and risks. Ask for no
   code yet. Claude verifies each item at its cited line and creates the run log with this block:
   `Problem / Rulings needed / Surfaces / Proof / Sessions`.
2. **Rulings.** Ask the open decisions with AskUserQuestion, one per call, headed "Ruling N of M",
   recommended option first. Use plain words: what the owner sees on the phone or Boox under each
   option. No jargon (the owner asks again when a question is abstract). The owner's free-text answer is
   the ruling. Write each ruling into `docs/rulings.md` and commit it (`git add docs/rulings.md`)
   before any code. A technical default the owner would not care about can be Claude's own. Record it
   as "Claude's default" only when it changes behaviour the owner could notice. If Codex returns
   `NEEDS_DECISION` later, ask it the same way and reply on the same thread.
3. **One check.** `codex-reply` on the writer thread with the rulings, asking only whether anything is
   still open. Handle the answer as in Step 2. There is no third pass: anything still open after this
   goes to the owner as a blocker.
4. **Implement (writer thread).** Codex follows `.claude/codex-worker-rules.md`: failing test first,
   then the gates and the live proof that rule file names, then one local commit per coherent change.
   Sync work also proves going offline, restarting the app, reconnecting and seeing both devices
   agree. Export work also checks page count and line breaks on sample pages.
   It returns one evidence line per check, `base..head`, and anything `not run`. Claude copies them
   into the run log and never fills a `not run` from Codex's prose.
5. **Review (new Astra thread).** Never the writer's thread. The brief is `base..head`, the rulings
   touched, the must-check list from Step 1, and "report only". Ask for severity, `file:line`, the
   ruling it breaks, and a concrete failure. For a UI change, the reviewer runs the app itself where it
   can and marks each finding `seen live` or `from code`.
6. **Claude checks.** Read `git diff --stat base..head`, then the diff. For each finding, read the cited
   lines and about 15 around them, then keep it or drop it with one line why. Treat "no findings" with
   no checks run as unreviewed and send it back once. Look at the screenshot Codex produced.
7. **Fix (writer thread).** Send the kept CRITICAL, HIGH and MEDIUM findings. Codex fixes them test
   first, re-runs the gates and the live proof they touched, and adds new commits. Claude reads the fix
   diff. Run a second review with `codex-reply` on the review thread when round 1 confirmed a
   CRITICAL or HIGH, when a fix touched sync, auth, a migration, reveal persistence or the export, or
   when more than four findings were fixed. There is no third round. A confirmed CRITICAL, HIGH or
   MEDIUM still open blocks the push.
8. **Exit check, push, close.** Give every proof listed in the Step 1 block its evidence line, or
   write `not observed` and why. An unmet proof means the feature is pushed but **not done**, and the
   report says so. Close the run log (next action, findings), commit it with `git add <log>`, then
   `git push` on the current branch (`main` is fine for this solo repo). Never force. Update the
   project memory and report:

```
{slug} · {one line}
  rulings   N new (R12–R14), M Claude defaults
  codex     writer {thread} · reviewer {thread}
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
