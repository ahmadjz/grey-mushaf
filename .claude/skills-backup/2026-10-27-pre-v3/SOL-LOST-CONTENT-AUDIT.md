# Lost-content audit

Baseline: exact file contents read before these edits. Backup files were not accessed because the session prohibits touching skills-backup/.

All removed lines are listed, including every command, backtick path, never/must/stop/only guard and step heading. Retained means its operative content remains in the cited current line; obsolete means only the conflicting routing/effort wording was replaced under v3.

## .claude/skills/quran-quick/SKILL.md

Original .claude/skills/quran-quick/SKILL.md:3:
> description: Deliver one feature or fix for the grey mushaf app (Flutter app, PocketBase sync on the VPS, PDF export). Claude asks the owner's rulings and checks the work. Codex Astra (medium, reusing its threads across asks) investigates, writes, commits locally and reviews. Claude commits the docs and pushes. Use for "build X", "fix Y", "next phase", or /quran-quick.
Obsolete model routing under v3; all product scope and trigger phrases retained. Current .claude/skills/quran-quick/SKILL.md:3.

Original .claude/skills/quran-quick/SKILL.md:11:
> judgement. Codex spends its tokens on reading code, writing it, running it and reviewing it.
Obsolete same-vendor review; hands-on writer work retained. Current .claude/skills/quran-quick/SKILL.md:11.

Original .claude/skills/quran-quick/SKILL.md:15:
> - Every Codex call goes through `mcp__codex-bridge__codex` with `model: "gpt-6-astra"`,
Obsolete model name under v3; exact bridge call retained. Current .claude/skills/quran-quick/SKILL.md:28.

Original .claude/skills/quran-quick/SKILL.md:17:
>   Every thread runs at `config: {"model_reasoning_effort": "medium"}`, except `reviewer-high` below.
Obsolete reviewer-high exception; writer high and reviewer medium now explicit. Current .claude/skills/quran-quick/SKILL.md:30.

Original .claude/skills/quran-quick/SKILL.md:18:
> - The first call of every thread sets `developer-instructions` to the contents of
Retained, with NEW-thread scope explicit. Current .claude/skills/quran-quick/SKILL.md:32.

Original .claude/skills/quran-quick/SKILL.md:19:
>   `.claude/codex-worker-rules.md`. Replies go through `mcp__codex-bridge__codex-reply`.
Retained exact worker path and reply tool; instructions supplied once. Current .claude/skills/quran-quick/SKILL.md:33.

Original .claude/skills/quran-quick/SKILL.md:20:
> - If codex-bridge is not connected, stop and tell the owner. Never substitute `codex exec` or a
Retained stop and codex exec ban; unselected fallback remains prohibited. Current .claude/skills/quran-quick/SKILL.md:37.

Original .claude/skills/quran-quick/SKILL.md:21:
>   Claude writer.
Obsolete absolute Claude-writer ban under explicit --writer sonnet. Current .claude/skills/quran-quick/SKILL.md:38.

Original .claude/skills/quran-quick/SKILL.md:24:
> (`| role | model · effort | threadId | opened | last used |`). Before a NEW call, read it. If the role
Retained registry schema and read-before-new rule. Current .claude/skills/quran-quick/SKILL.md:42.

Original .claude/skills/quran-quick/SKILL.md:25:
> already has a thread, `codex-reply` on it, starting the prompt with "New ask:", across asks and
Retained reply reuse and New ask prefix. Current .claude/skills/quran-quick/SKILL.md:43.

Original .claude/skills/quran-quick/SKILL.md:26:
> sessions (the bridge resumes old threads). Open a NEW thread only when: the role has none yet, the
Retained cross-session reuse and missing-role exception. Current .claude/skills/quran-quick/SKILL.md:44.

Original .claude/skills/quran-quick/SKILL.md:27:
> model or effort changes, independence requires it (a reviewer never runs in the writer's thread), or
Retained model/effort change and independence exceptions. Current .claude/skills/quran-quick/SKILL.md:45.

Original .claude/skills/quran-quick/SKILL.md:28:
> `codex-usage <threadId>` prints `FULL` (context over 160k). A NEW thread after `FULL` gets a short
Obsolete generic helper command; replaced with local helper and >= thresholds. Current .claude/skills/quran-quick/SKILL.md:47.

Original .claude/skills/quran-quick/SKILL.md:29:
> summary of what it needs, and replaces that role's row. Update `last used` on every call. A
Retained registry replacement/last-used updates; handoff made concrete. Current .claude/skills/quran-quick/SKILL.md:51.

Original .claude/skills/quran-quick/SKILL.md:30:
> reviewer's brief scopes it to the diff hunks first.
Retained diff-first reviewer scope. Current .claude/skills/quran-quick/SKILL.md:52.

Original .claude/skills/quran-quick/SKILL.md:31:
> Effort is medium for every role. High is only for a separate `reviewer-high` thread, used when the
Obsolete reviewer-high route; replaced with sensitive writer high and Opus full check. Current .claude/skills/quran-quick/SKILL.md:15.

Original .claude/skills/quran-quick/SKILL.md:32:
> change touches sync, auth, a migration or reveal persistence.
Retained project risks in sensitivity classification and dual/re-review triggers. Current .claude/skills/quran-quick/SKILL.md:24.

Original .claude/skills/quran-quick/SKILL.md:38:
> asked, both thread ids, the evidence lines, the findings with their outcomes, and the pushed sha. Mark
Retained run-log memory fields, broadened to Sonnet sessions. Current .claude/skills/quran-quick/SKILL.md:59.

Original .claude/skills/quran-quick/SKILL.md:45:
> or sync, auth, a migration or reveal persistence. Routine localized work with an established pattern and decisive proof uses only the writer (Astra).
Retained dual triggers and routine single-writer route; obsolete model removed. Current .claude/skills/quran-quick/SKILL.md:66.

Original .claude/skills/quran-quick/SKILL.md:46:
> Sonnet replaces Opus's broad reading; Opus does targeted evidence checks only.
Retained targeted reconciliation; only-targeted Opus scope obsolete for sensitive review. Current .claude/skills/quran-quick/SKILL.md:68.

Original .claude/skills/quran-quick/SKILL.md:48:
> 1. Give the writer (Astra) and Sonnet one shared neutral brief: requirements, settled constraints, entry points,
Retained neutral shared brief; models replaced with Sol + Sonnet. Current .claude/skills/quran-quick/SKILL.md:71.

Original .claude/skills/quran-quick/SKILL.md:49:
>    dirty files and questions, bounded in scope, with no proposed diagnosis. Reply on the registered
Retained bounded scope, dirty files and no proposed diagnosis. Current .claude/skills/quran-quick/SKILL.md:72.

Original .claude/skills/quran-quick/SKILL.md:50:
>    writer (Astra) thread using this project's registry and worker rules (including **Keep the context
Retained registry/worker context budget; Sonnet-writer explorer separated. Current .claude/skills/quran-quick/SKILL.md:73.

Original .claude/skills/quran-quick/SKILL.md:51:
>    small**). Open a thread only under the existing missing/model-change/FULL rules, never just for
Retained no-new-thread-for-trial rule; v3 rotation/independence exceptions added. Current .claude/skills/quran-quick/SKILL.md:74.

Original .claude/skills/quran-quick/SKILL.md:53:
> 2. In the same message, call the writer (Astra, `gpt-6-astra`, medium) and `Agent` with `model: sonnet`,
Obsolete model name; retained parallel Sol/Sonnet calls. Current .claude/skills/quran-quick/SKILL.md:76.

Original .claude/skills/quran-quick/SKILL.md:54:
>    `subagent_type: Explore` (`general-purpose` if commands are needed), so they run in parallel.
Retained Explore/general-purpose choice and parallelism; Sonnet writer uses general-purpose. Current .claude/skills/quran-quick/SKILL.md:77.

Original .claude/skills/quran-quick/SKILL.md:55:
>    Sonnet inherits the session's medium effort. Cap Sonnet at about 40 tool calls, then return
Obsolete Sonnet medium effort; retained 40-call cap and findings return. Current .claude/skills/quran-quick/SKILL.md:79.

Original .claude/skills/quran-quick/SKILL.md:65:
>    them to the SAME writer (Astra) thread before plan writing or implementation. The reviewer stays
Retained same-writer reconciliation before implementation. Current .claude/skills/quran-quick/SKILL.md:89.

Original .claude/skills/quran-quick/SKILL.md:66:
>    a separate Astra thread that never explores; independence is by thread. Preserve the skill's implementation route after exploration.
Obsolete same-vendor independent-thread review; retained no-exploration reviewer independence. Current .claude/skills/quran-quick/SKILL.md:90.

Original .claude/skills/quran-quick/SKILL.md:67:
> 5. Record dual/single selection and why in the phase report. At close compare comparable asks using only the writer (Astra)
Retained selection reason and quota/interventions/defect comparison. Current .claude/skills/quran-quick/SKILL.md:92.

Original .claude/skills/quran-quick/SKILL.md:76:
> 1. **Investigate (the registry's writer (Astra) thread, else NEW).** Apply **Dual exploration trial**
Retained investigate step and dual trigger; obsolete model replaced. Current .claude/skills/quran-quick/SKILL.md:120.

Original .claude/skills/quran-quick/SKILL.md:77:
>    when its triggers hold. After reconciliation (dual) or directly (single), ask the SAME writer (Astra) for the
Retained dual reconciliation and same-writer continuation. Current .claude/skills/quran-quick/SKILL.md:121.

Original .claude/skills/quran-quick/SKILL.md:78:
>    following block. Give Codex the ask and the relevant rulings. Ask it for the cause or
Retained ask, rulings and cause/design request for either writer. Current .claude/skills/quran-quick/SKILL.md:122.

Original .claude/skills/quran-quick/SKILL.md:87:
>    as "Claude's default" only when it changes behaviour the owner could notice. If Codex returns
Retained noticeable-behaviour default and NEEDS_DECISION handling for either writer. Current .claude/skills/quran-quick/SKILL.md:131.

Original .claude/skills/quran-quick/SKILL.md:89:
> 3. **One check.** `codex-reply` on the writer thread with the rulings, asking only whether anything is
Retained one-check limit and reply tool for Sol; Sonnet context supported. Current .claude/skills/quran-quick/SKILL.md:133.

Original .claude/skills/quran-quick/SKILL.md:92:
> 4. **Implement (writer thread).** Codex follows `.claude/codex-worker-rules.md`: failing test first,
Retained worker-rule path and red-first implementation for either writer. Current .claude/skills/quran-quick/SKILL.md:136.

Original .claude/skills/quran-quick/SKILL.md:97:
>    into the run log and never fills a `not run` from Codex's prose.
Retained run-log copy and never-fill-not-run guard. Current .claude/skills/quran-quick/SKILL.md:141.

Original .claude/skills/quran-quick/SKILL.md:98:
> 5. **Review (the registry's reviewer thread, or `reviewer-high` for sync, auth, a migration or reveal
Obsolete reviewer-high route; other-vendor review replaces it. Current .claude/skills/quran-quick/SKILL.md:142.

Original .claude/skills/quran-quick/SKILL.md:99:
>    persistence; else NEW).** Never the writer's thread. The brief is `base..head`, the
Retained independent reviewer and base..head brief. Current .claude/skills/quran-quick/SKILL.md:143.

Original .claude/skills/quran-quick/SKILL.md:114:
>    no checks run as unreviewed and send it back once. Look at the screenshot Codex produced.
Retained send-back-once and screenshot proof inspection, now bounded. Current .claude/skills/quran-quick/SKILL.md:158.

Original .claude/skills/quran-quick/SKILL.md:115:
> 7. **Fix (writer thread).** Send the kept CRITICAL, HIGH and MEDIUM findings. Codex fixes them test
Retained fix step and severity list; fixes return to original writer context first. Current .claude/skills/quran-quick/SKILL.md:161.

Original .claude/skills/quran-quick/SKILL.md:117:
>    diff. Run a second review with `codex-reply` on the review thread when round 1 confirmed a
Retained second-review trigger and Sol codex-reply; Sonnet reviewer supported. Current .claude/skills/quran-quick/SKILL.md:164.

Original .claude/skills/quran-quick/SKILL.md:119:
>    when more than four findings were fixed. There is no third round. A confirmed CRITICAL, HIGH or
Retained more-than-four trigger, no third round and severity blockers; Opus added. Current .claude/skills/quran-quick/SKILL.md:166.

Original .claude/skills/quran-quick/SKILL.md:130:
>   codex     writer {thread} · reviewer {thread}
Retained writer/reviewer identifiers; models/efforts and Sonnet sessions added. Current .claude/skills/quran-quick/SKILL.md:178.

## .claude/codex-worker-rules.md

Original .claude/codex-worker-rules.md:62:
> The owner pays for every token you re-read, and this thread may be reused for the next ask. Stay in the
Retained token-cost and thread-reuse rationale. Current .claude/codex-worker-rules.md:62.

Original .claude/codex-worker-rules.md:63:
> scope your prompt gives (a reviewer: the diff hunks and the enclosing methods first, a whole file or
Retained diff/enclosing-method review scope. Current .claude/codex-worker-rules.md:63.

Original .claude/codex-worker-rules.md:64:
> a caller only when a finding needs it). `tail -50` test and build logs. Take screenshots or snapshots
Retained caller-on-need, tail -50 and proof-only images; bounded log rules added. Current .claude/codex-worker-rules.md:72.

Original .claude/codex-worker-rules.md:65:
> only when a check needs one. Never re-read a file you already have open unless it changed since. If
Retained proof-only captures and unchanged-file reread ban. Current .claude/codex-worker-rules.md:64.

Original .claude/codex-worker-rules.md:66:
> one turn passes 60 tool calls, stop and report what you have.
Retained stop/report at >60 calls, now including polls and captures. Current .claude/codex-worker-rules.md:96.

