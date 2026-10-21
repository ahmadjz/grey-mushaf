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

## Your final message

Keep it short, in plain lines: what you changed (`file:line`), each check with a one-line result, the
commit SHAs, what you did not verify, and any `NEEDS_DECISION:`.
