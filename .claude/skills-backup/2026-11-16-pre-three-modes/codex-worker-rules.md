# Rules for a Codex worker on the grey mushaf app

You are doing the hands-on work for Claude's `/quran-quick` skill. These rules outrank anything in the
task that conflicts with them.

## Where things are

- Repo root: `/home/ahmadjz/Documents/Quran` (GitHub `ahmadjz/grey-mushaf`, public).
- `docs/rulings.md` holds the owner's decisions. Read it first. Never act against it, and never change it.
- `make_grey_mushaf.py` builds the grey PDF from the KFGQPC 1441 `.ai` pages in `ai-pages/`.
- `app/` is the Flutter app. Flutter is at `~/development/flutter/bin`.
- `server/` holds the VPS side: PocketBase config and the export job.
- Source assets (`*.zip`, `*.pdf`, `ai-pages/`, downloaded fonts and data) are **gitignored and never
  committed**: the repo is public and the KFGQPC/QUL licences are not cleared.

## You cannot ask the owner

Nobody answers mid-run. When a behaviour choice is not settled by `docs/rulings.md` or the code, end
your reply with a `NEEDS_DECISION:` section. Give each question as what the owner sees under each
option, with your recommendation, and stop before the choice matters. Claude asks the owner and
replies on the same thread with the ruling, and then you continue.

## Code rules

- Red first: write the failing test, watch it fail for the intended reason, then implement.
- Make the minimal change at the right layer. Follow the existing pattern, and don't refactor
  neighbouring code.
- Never weaken a test or an analyzer rule to get green.
- Gates, run from the repo root:
  - `app/` changed: `cd app && flutter analyze && flutter test`
  - Python changed: `python3 -m pytest -q tests/`, written red-first like the app
  - `server/` changed: the PocketBase rule and migration tests that the change adds (another user
    reading your data must be refused)
- Documentation-only changes need no tests and no device proof.

## Git rules

- Stage with an explicit `git add <file>` only, never `.`, `-A` or a bare directory.
- Never touch uncommitted work you did not make. If `git status` shows it at the start, say so and
  leave it alone.
- Commit only when the task says so, with a short imperative message. Keep the existing git author.
  No `Co-Authored-By`, and no mention of Claude, Codex, Anthropic, OpenAI or AI anywhere.
- Never push, never `--force`, never change the remote.

## Running and proving

- Live proof for a UI change: list targets with `flutter devices`, run on an Android emulator or a
  connected device, and save a screenshot under `docs/runs/shots/` (gitignored). If no target can
  start, run `flutter test integration_test/<file>` and report the device proof as
  `not run: <why>`.
- The VPS (`ssh vps`) is shared with other services. Only read it, unless the task names the exact
  container or directory you may change. Never touch the existing `pocketbase`, `pocketbase-tariq`,
  `caddy` or `hbbs`/`hbbr` containers. Never delete or recreate this project's `pb_data` or any volume
  without the owner's ruling quoted in the task.
- List every test account, token or record you create for a proof by its identifier (never its value),
  with how you removed it.
- Two attempts at the same failing command, then stop and report.
- **Never fabricate a result.** Report a check you did not run as `not run: <why>`.

## Keep the context small

The owner pays for every token you re-read, and this thread may be reused for the next ask.
Stay in the scope your prompt gives. A reviewer starts with diff hunks and enclosing methods;
read a caller or whole file only when a finding needs it. Never re-read an unchanged file.

- Start with narrow `rg -n` on named paths; use `rg -l` to find files and `rg -m 5` to cap matches
  per file while scanning. Use line ranges or enclosing functions rather than whole large files.
- Run `git diff --stat` before hunks (`git diff --stat base..head` for a review), then diff named
  files. Default to <=120 lines per source/diff read and <=50 lines per log excerpt. When more
  output is needed, give a one-line reason before expanding. Say when output was truncated and
  name the saved file and unread range. Never hide failures behind a clipped success excerpt.
- Redirect Flutter analyze/test/build, Gradle, pytest and integration logs to a named file under
  `docs/runs/shots/` (gitignored). Save the command's exit code before `tail -50 <log>` and
  `rg -n -m 10 'FAIL|FAILED|Exception|Error|error:' <log>`. Report the real exit code, final
  result and relevant failure lines; a successful tail/grep is not a successful test.
  Poll long builds every 10-30 seconds, with <=50 new lines per poll. Do not replay earlier logs.
- For UI state prefer Flutter widget/integration assertions and semantics, including
  `app/integration_test/restart_proof_test.dart` for separate-process reveal durability.
  `app/test_driver/proof_driver.dart` writes JSON to `PROOF_OUT`; extract phase, PID, assertions
  and cleanup needed for the check, never dump the entire JSON. Use filtered `adb logcat` or
  a targeted `adb shell uiautomator dump` read for Android state. Bound `ssh vps` logs the same way.
- Screenshots, browser/device captures and `view_image` are only for a proof or failure diagnosis,
  at most 2 per check, including retries. Save Android captures with
  `adb -s <serial> exec-out screencap -p > docs/runs/shots/<check>-raw.png`, then, when available,
  `magick docs/runs/shots/<check>-raw.png -resize '720x>' docs/runs/shots/<check>-preview.png`.
  Inspect the <=720px-wide preview. If resizing is unavailable, report it; keep the two-image cap.
- Keep original pixels on disk for numeric parity proof. `app/test_driver/parity_driver.dart`
  saves PNGs and `capture.json` under `PARITY_OUT` and removes screenshot bytes from response data.
  Let required parity batches save originals locally, but return counts, paths and bounded diff
  summaries from `app/tool/parity_diff.dart` / `app/tool/rgba_diff.dart`, never PNG/base64 payloads,
  full capture JSON, frame arrays or timeline dumps. Visually inspect at most two representative
  proofs per check. For PDF exports return page count and sample line-break results, with at most
  two downscaled page images per check; keep full PDFs/renders on disk.
- Never read a whole Claude orchestrator SKILL.md. The caller supplies the relevant step text or
  line range. Project repo skills you are told to follow stay readable.
- Count tool calls for this turn, including polls and captures. Stop and report what you have if
  this turn passes 60 tool calls. Return completed checks, evidence paths, open items and the next
  action. Do not keep polling or capturing until the build finishes. This is a turn limit, not a
  reason to discard a reusable thread.

## Your final message

Start with this header, using the route and reviewer details supplied by the caller:
`policy v3 2026-10-27 · mode <normal|low-claude> · route <routine|sensitive> (<why>) · writer <model effort> · reviewers <model effort, ...> · escalated <no|why>`.

Keep it short, in plain lines: what you changed (`file:line`), each check with a one-line result, the
commit SHAs, what you did not verify, and any `NEEDS_DECISION:`.
