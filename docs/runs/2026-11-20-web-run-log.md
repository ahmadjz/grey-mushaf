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
- 6 Claude checks + 7 fixes — done 2026-11-21.
  - r1 fixes in dce65eb (cookie queue, Retry on load failure, public route 404 for api/ and
    assets/assets, cookie Max-Age = token lifetime, drag guard, deploy script hardening).
    Two-tab sign-out (Fable M3) downgraded to LOW: needs two open tabs, same account stays signed in,
    no data crosses accounts; Fable agreed LOW in r2.
  - r2 (Fable: 0 C/H, 1 M, 5 L; Sol: 3 H, 1 M) fixed in 1027bfb: path normalised before the check
    (encoded `.`/`..`/`//` spellings, seen live by both), session calls have no client timeout so the
    queue really waits, failed DELETE retried every 30 s, late 401 of an old token ignored, failed
    sign-out save shows "Sign in again", `_problem` cleared on sign-out, `_cookieCleared` reset before
    POST, queue errors caught, wheel claims only mostly-vertical scrolls, stage dir checked.
  - dce65eb: B/W search test now ignores vowel marks (new Imlaei text, QUL 54, installed 2026-11-21).
  - Gates: flutter analyze ok · flutter test 204 passed · pytest PocketBase 26 passed.
  - No third review round (skill rule); Opus full check of web_shell.dart and web.pb.js done.

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

## Deploy (2026-11-21) — done

- Uploaded build to /srv/mushaf.ahmadjz.tech/web/{public 42M, private 150M}; web.pb.js to pb_hooks;
  compose backed up (compose.yml.bak-2026-11-21) and pocketbase-mushaf recreated with /pb/web:ro
  (vps-infra 4970b89, local, not pushed). Caddy untouched.
- Prod probes: / 200 (Grey mushaf), /surah/2 200, /api/health 200, /_/ 200, superusers by name and id
  404, gated page/font signed out 401, garbage cookie 401, `/assets%2Fassets/...` and
  `/assets/%2e/assets/...` 404, /api/not-a-route 404.
- Signed in (temp verified user mypfcp5d6n4qxkb, deleted after, 204): session 204, page 50 and
  p604.ttf 200 with cookie, DELETE 204, then 401.
- Other sites ahmadjz/office/tariq/sohba/visa 200 before and after.
- Release APK rebuilt (new Imlaei index + web package builds for Android), copied to grey-mushaf.apk,
  installed over the app on the phone 2be3110f and the Boox 655E999A (data kept, both open: READER_FIRST_FRAME; the Boox app was user-disabled again, pm enable fixed it).

## Exit check

- R85 same address: done (prod probes). R86/R87 gate: done. R88 sign-in first, keeps words after
  reload: seen locally in Chrome; on prod not observed (needs the owner's account).
- R56 mouse/keys: tests + local Chrome; prod not observed.
- Not observed: owner sign-in on the web, phone and Boox agreeing after sign-in, Boox install.

## Next action

Owner signs in at https://mushaf.ahmadjz.tech and on the phone; check both show the same words.
Two-tab sign-out stays LOW (open).
Export stays on hold (R84).
