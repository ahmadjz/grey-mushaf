# Modes: who does each step

Policy v4 2026-11-16, the project version of the Cellusys `cellusys-run/references/modes.md`. This
project uses no Astra: every Astra cell there is a fresh Sol medium thread here. Assume Claude Max
whatever account is logged in. The ChatGPT bucket is shared, so Codex use is deliberate. The owner
picks the mode; the skill never measures quota or switches mode. If `codex-bridge` is not connected or
a Codex call fails on quota, stop and tell the owner.

## Picking the mode

| Flag | Mode | Spirit |
|---|---|---|
| none (also `--default`, legacy `--normal`) | **default** | Claude leads and writes; Codex is the independent second opinion |
| `--balanced` | **balanced** | Claude leads; Codex writes routine work |
| `--low-claude` | **low-claude** | Codex does the heavy work; Claude keeps rulings, gates and the finish |

A resumed run log keeps its recorded mode unless a flag overrides it. Every report header starts with
`mode <default|balanced|low-claude> · route <routine|sensitive> (<why>) · writer <model effort> · reviewers <model effort, ...>`.

## Effort caps (every mode, every role)

- Opus: low or medium only. Fable: medium only, and only as a review finder.
- Sol: medium only. Sonnet: medium or high.
- Never `xhigh` or `max` on any model.

## Roles by mode and route

The **Sensitive** list in `SKILL.md` Setup decides the route in every mode.

| Step | default | balanced | low-claude |
|---|---|---|---|
| Investigate, plan, rule | Opus medium (the session) | Opus medium (the session) | Sol on the writer thread (+ Sonnet high dual exploration when its triggers hold); Opus medium rules and reconciles |
| Blind pre-check before code | Sol medium, fresh thread | sensitive: Sol medium, fresh thread; routine: skipped | open-items reply on the writer thread only |
| Writer, routine | Opus medium (the session) | Sol medium | Sol medium |
| Writer, sensitive | Opus medium (the session) | Opus medium (the session) | Sol medium |
| Review, routine | Fable medium + Sol medium (fresh) | Sonnet high | Sonnet high |
| Review, sensitive | Fable medium + Sol medium (fresh), then the Opus medium full check | Sol medium (fresh) + Sonnet high, then the Opus medium full check | Sonnet high, then the Opus medium full check |
| Review fixes | the writer | the writer | the writer (Sol thread first) |
| Live proof (emulator, device, VPS) | the writer | the writer | the writer |
| Docs, commit docs, push, report | Claude | Claude | Claude |

`--writer sonnet` (any mode) makes Sonnet high the writer; any Sonnet reviewer is then replaced by a fresh
Sol medium reviewer. `--writer sol` (default or balanced) makes Sol the writer at medium; any Sol reviewer is then replaced by Sonnet high. Opus never writes in low-claude except
a trivial patch of five lines or fewer, logged as `Claude patched: <file:line> - <reason>`.

## Rules that hold in every mode

- **Pre-check skips.** A skill may keep its own documented skip rule for a small, clear, low-risk fix (known cause at `file:line`, nothing on the sensitive list); every other default pre-check runs.
- **Local commits** follow each skill's steps (a Codex writer may commit locally); push, MR and the report stay with Claude.
- **Other vendor reviews.** At least one reviewer is from the other vendor than the writer, and no
  reviewer runs in the writer's thread or context. Fable reviewing Opus is a different model, never the
  cross-vendor reviewer.
- **Every finding is verified** against the code by Claude before it counts. Never act on a Fable
  finding unread.
- **Reviews read the affected code, not only the diff.** Start from the diff, then read the callers and
  callees of every changed symbol, the module's existing patterns and invariants the change must
  follow, and the tests covering it. Stop at unrelated modules.
- Codex calls follow the thread registry, rotation and worker-rules setup in `SKILL.md`.

## How to launch each model

- Opus writer, investigator or full check: the skill session itself (start it on Opus at medium).
- Fable finder: `Agent` with `subagent_type: code-reviewer`, `model: fable`, `run_in_background: true`,
  report only, the review brief plus "think hard".
- Sonnet reviewer or writer: `Agent` with `model: sonnet` and "think hard" for high.
- Sol: `mcp__codex-bridge__codex` / `codex-reply`, effort in `config.model_reasoning_effort`.
