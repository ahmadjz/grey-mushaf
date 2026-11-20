# Web build run log (R56, R85–R88)

mode default · route sensitive (PocketBase auth routes, gated asset serving) · writer Opus medium ·
reviewers Fable medium + Sol medium (fresh), then Opus full check · base 3c6ee6d

## Steps

- 1 investigate — done. Plan: docs/runs/2026-11-20-web-plan.md (Caddy forward_auth version, since replaced).
- 2 rulings — done: R85–R87 owner, R88 Claude defaults (commit 3c6ee6d).
- 3 pre-check — done, Sol thread 01a1fab7. Kept: Flutter web serves assets at /assets/assets/*; the
  caddy container has no mount for this site, so PocketBase serves the web build
  (server/pb_hooks/web.pb.js) and Caddy stays untouched; the sign-in root needs its own lifecycle; the
  cookie must follow refresh and sign-out; no-store on gated files.
- 4 implement — done locally, NOT pushed, NOT deployed.
  - 323cbd7 server gate: public shell from /pb/web/public, /assets/assets/* from /pb/web/private behind
    the HttpOnly Secure SameSite=Strict `mushaf_session` cookie; POST/DELETE /api/mushaf/session.
  - 64d0e99 wheel and arrow keys turn pages (left / wheel down = next).
  - 7506ede web build: WebShell (sign-in first), sqflite_common_ffi_web, openWebSession/closeWebSession,
    scripts/deploy_web.sh.
  - Uncommitted in ~/Documents/vps-infra: pocketbase-mushaf/compose.yml mounts
    /srv/mushaf.ahmadjz.tech/web:/pb/web:ro.
- 5 review — r1 done (Fable agent; Sol thread 01a1fad0).
- 6–8 — not started.

## Evidence

- pytest tests/test_pocketbase_rules.py (PB_BIN=~/Documents/tariq_lib/.pb-bin/pocketbase): 21 passed.
- flutter analyze ok · flutter test 194 passed (docs/runs/shots/web-full2.log).
- Local live (Chrome, local PocketBase on :8099 serving the staged build; test users webproof-a/-b in
  scratch data only): signed out → sign-in screen, gated file 401; sign-in → session cookie (hidden
  from JS), page 1 rendered (docs/runs/shots/web-2-page1.png); ArrowLeft → page 2, ArrowRight → 1,
  wheel down → 2; a mouse hold revealed 2:2:1 and it reached the server for A only (B sees none);
  Settings sign-out → gated 401 and the sign-in screen; reload + sign-in → opens on page 2 with 2:2:1
  still black.
- Not run: VPS deploy, prod checks, Android release build with the new dependency.

## Review r1 findings to fix (verify each at its line first)

1. HIGH web_shell.dart:72 — an openReader() failure (not a SyncProblem) leaves a spinner forever; the
   failed _readerLoad and rootBundle's cached failed load block recovery. Catch all errors, show Retry,
   reset _readerLoad, evict the rootBundle cache (or reload the page).
2. HIGH deploy_web.sh:9 — `--exclude` keeps a stale public/assets/assets, and then
   `/assets%2Fassets/...` serves private files signed out (seen live by Sol). Use `--delete-excluded`;
   make the public route refuse any path under assets/assets; ship web.pb.js from the script; check $1.
3. MEDIUM web_shell.dart:58/66 — cookie races: a late POST after DELETE restores the cookie; a late
   DELETE after the next sign-in clears the new cookie; a failed DELETE leaves the cookie
   (closeWebSession's catchError on a record future throws ArgumentError). Serialise session calls in
   one queue; always DELETE on sign-out and on a signed-out start; consider Max-Age from token expiry.
   Add fault-injection tests.
4. MEDIUM main.dart:467 — keys and wheel turn pages while a long-press is held (bypasses the drag lock).
5. MEDIUM web.pb.js:4 — the SPA catch-all turns unknown /api/* GETs into 200 HTML; return 404 there.
6. MEDIUM reveal_store.dart:668 — two tabs: tab B's refresh writes the token back after tab A signed out.
7. LOW — create /srv/mushaf.ahmadjz.tech/web before `up`; horizontal-only wheel events are claimed;
   continuous scrolling gives one turn until a pause.

## Next action

Fix 1–6 test first (writer = the Opus session), rerun the gates and the local Chrome proof, r2 with
the same reviewers (Sol: codex-reply 01a1fad0), Opus full check. Then deploy: mkdir the web dir,
`scripts/deploy_web.sh <stage> vps`, copy web.pb.js to /srv/mushaf.ahmadjz.tech/pb_hooks, commit
vps-infra, `docker compose up -d` for pocketbase-mushaf only, prod curl probes (shell 200, gated
401/200, superusers 404, other sites unchanged), owner signs in at https://mushaf.ahmadjz.tech. Then
push main.

Separate: install grey-mushaf.apk on the phone and Boox when attached (rebuild first: the new web
dependency must still build for Android).
