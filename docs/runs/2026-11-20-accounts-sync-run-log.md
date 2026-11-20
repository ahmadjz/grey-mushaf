# Accounts and sync (phase 2 part 1) run log

mode default · route sensitive (PocketBase auth + access rules, local SQLite schema change, synced reveals)

## Step 0 baseline — done

base 23132cd, remote ahmadjz/grey-mushaf. Dirty files not mine, left alone:
`.claude/codex-worker-rules.md`, `.claude/skills/quran-quick/SKILL.md`,
`app/integration_test/marks_store_test.dart`, `app/integration_test/perf_baseline_test.dart`,
untracked `.claude/skills-backup/`, `.claude/skills/quran-quick/{references,scripts}/`, many `docs/runs/2026-10-24-*`.

## Step 1 investigate — done

**Problem.** No accounts or sync yet. Local SQLite (`app/lib/reveal_store.dart`, schema v3) is the source of
truth: `word_actions` + `reveal_events` + `word_state`, `mark_actions` + `word_marks`, `bookmark_actions` +
`bookmarks`, `local_metadata` (device_id, last page, prefs).

- Debt: no-op actions skip recording their UUID (`reveal_store.dart:514`, `:462`, `:143`), so a replayed
  action that was a no-op the first time is applied later and can add a reveal count.
- `word_actions` has no `created_at` (`reveal_store.dart:274-277`); marks and bookmarks do, clamped
  (`:466-477`, `:146-153`). Any time-based conflict rule needs a v4 migration adding it to words.
- R12 (Claude default) says server receive order wins; owner's ask reopens that.
- Last page: R10 (owner) says synced, R66 (Claude default) says device only.
- Settings is a sheet in `main.dart:524-580`; no account UI.
- VPS: sibling pattern `/opt/vps-infra/pocketbase-<name>/compose.yml`, PocketBase 0.40.4 on 127.0.0.1:809x,
  shared Caddyfile `/opt/vps-infra/caddy/Caddyfile` (caddy runs net=host). No wildcard DNS: a new
  subdomain needs an A record to 195.35.25.101. Free port: 8093 (8090-8092, 8094 taken).

**Rulings needed.** last page sync; conflict rule; sign-in screen; Google now or later; subdomain + DNS +
Caddy block/reload permission.

**Surfaces.** `reveal_store.dart` (v4 migration, no-op uuids, pending-upload queries, apply remote),
new `sync.dart` (PocketBase client, push/pull, connectivity), new account screen, Settings sheet rows,
`server/pocketbase-mushaf/` (compose, migrations with access rules), Caddyfile block.

**Proof.** Two devices (phone 2be3110f or emulator + Boox 655E999A or second emulator): reveal offline on
A, mark on B, restart both, reconnect, both agree. Second user cannot list/read first user's records
(curl with B's token). No-op replay does not double count (unit test). v3→v4 upgrade keeps data.

**Sessions.** writer Opus medium (session) · pre-check Sol medium fresh · reviewers Fable medium + Sol
medium fresh, then Opus full check.

## Step 2 rulings — done (R76–R81, commit 211e2e6)

## Step 3 pre-check — done (Sol 01a1f9c5, 14 items, folded into the plan file)

## Step 4 implement — in progress (Opus session writes)

Claude defaults (invisible or folded from the pre-check): v4 adds side tables `word_action_times` +
`uploaded_actions` (old rows never rewritten; pre-v4 actions order by local_seq); the clamp only uses this
device's own actions; a server hook assigns a per-user `seq` (the pull cursor) and clamps a future
`created_at`; token refresh at most every 12 h; sync also every 60 s, 3 s after a local change, on resume
and when the connection returns; an account switch merges this device's data into the new account;
per-collection create limit 300/10 s plus a client 429 backoff.

Commits: 211e2e6 rulings · c6380f1 no-op actions + newest-wins merge (debt fix) · 2f2619e server
collections/rules · 0bb75cf sync client + account UI + manifests · b5755f1 two-device integration test.
vps-infra repo (local, not pushed): 24a60a0 pocketbase-mushaf + Caddy block + setup.sh/README.

Evidence:
- red: replayed no-op reveal counted twice (`count: 2`), replayed mark came back (shots/sync-red.log)
- store integration on emulator-5554: sync_store 7/7, sqlite 1/1, bookmarks_store 8/8, marks_store 8/8,
  downgrade 1/1, persistence 1/1 (shots/store-*.log)
- gate: flutter analyze ok · flutter test 174 passed (shots/gate-unit.log)
- pytest PocketBase rules on local 0.40.4: 6 passed; a mutation (open listRule) fails the isolation test
- engine unit: sync_test 10 + account_test 3 passed, incl. a paused create (fault injection) while signing out
- two stores through a local PocketBase on the emulator: sync_two_devices_test 1/1 (offline reveal on A, mark
  and a later re-grey on B, close/reopen both, sync, both agree; a second user pulls nothing); rows checked
- deploy: pocketbase-mushaf up on 127.0.0.1:8093, migrations applied, superuser in
  /opt/pocketbase-mushaf/superuser.txt (root 600), migration restart unit active; Caddyfile backed up to
  Caddyfile.bak-2026-11-20, validated, reloaded; https://mushaf.ahmadjz.tech/api/health 200, `_superusers`
  404, `/_/` 200; ahmadjz/office/tariq/sohba/visa all still 200 after the reload
- production isolation (throwaway accounts): unverified sign-in 403; B lists/filters/expands A → 0; B views
  A's record or user 404; B creating as A 400; anonymous 0; A updating its own record 403 (append only)

Production test accounts (ids): proof-a sz28sym3n7489or and proof-b fzidz88izrybmba kept for the live proof,
delete afterwards; deleted: n3mhmzpb0doe4wo, tb2s7mhjhpjirns, 37yb980aszsjb3e, 9mtg8fz4ojb42uj.

Not run yet: live two-device proof in the real app; verify/reset email delivery `not observed` (owner SMTP).

Next action: live proof on two emulators (Medium_Phone + Tablet_API_37, debug build against production,
proof-a): airplane mode on A, reveal; mark on B; force-stop both; reconnect; check word semantics on both.
Boox waits on the owner (its real data would mix with proof words). Then Step 5 review (Fable medium +
fresh Sol medium), Opus full check, fixes, delete proof accounts, push, memory.
