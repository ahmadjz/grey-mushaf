# Accounts and sync plan (R2, R6, R10, R11, R24, R46–R48, R53, R58, R62, R66, R76–R81)

## 1. Local store, schema v4 (`app/lib/reveal_store.dart`)
- `word_actions` gains `created_at INTEGER NOT NULL DEFAULT 0` and `counted INTEGER NOT NULL DEFAULT 0`;
  backfill `created_at = local_seq` (keeps device order; any new action beats every old one) and
  `counted = 1` where the uuid is in `reveal_events`.
- All three action tables gain `uploaded INTEGER NOT NULL DEFAULT 0` (remote-applied rows insert 1).
- **Debt fix:** a no-op action (state already equal) is now recorded (word: `counted = 0`), and
  updates `last_action_uuid`, so its uuid dedups any replay. Same for marks (null-style tombstone row
  if none) and bookmarks.
- Local `created_at = max(now, latest for the same word / word+kind / any bookmark + 1)` (words new;
  marks and bookmarks already). The latest local tap therefore always wins locally and remotely.
- State = action with max `(created_at, action_uuid)` per word, per (word, kind), per page (R77).
  `reveal_count` = number of `counted = 1` actions for the word, from every device (R6, R77).
- `applyRemote(words, marks, bookmarks)`: one transaction; skip known uuids; insert with
  `uploaded = 1`; recompute the winner for each touched key; update maps; emit changed word keys and
  a bookmarks flag on a broadcast stream the reader listens to (repaints via `_pageInk[..].changed()`
  and `_wordRevision`).
- `pendingUploads(limit)`, `markUploaded(uuids)`, `pendingCount`, sync metadata in `local_metadata`
  (token, user id, email, per-collection cursor keyed by user id, last sync time). Last page untouched (R76).

## 2. Server (`server/pocketbase-mushaf/`, deployed to `/opt/vps-infra/pocketbase-mushaf`)
- compose like `pocketbase-visa` (PocketBase 0.40.4), `127.0.0.1:8093`, own `pb_data`, `pb_migrations`.
- Caddy: one block `mushaf.ahmadjz.tech { reverse_proxy 127.0.0.1:8093 }`, Caddyfile backed up,
  `caddy validate` then `caddy reload` (no restart). No other container touched.
- Migrations: `users` authRule `verified = true` (R81), password auth only, OAuth2/OTP/MFA off,
  rate limits on, appURL set. SMTP left for the owner in the admin UI.
- Collections `word_actions` (uuid, device, word `^qul-v4-hafs:\d{1,3}:\d{1,3}:\d{1,3}$`, black,
  counted, created_at int ≥ 0), `mark_actions` (kind/style/color selects, style-matches-kind in the
  create rule), `bookmark_actions` (page 1–604 int, saved). Each: `user` relation (required,
  cascade delete), autodate `created`, unique index `(user, uuid)`, index `(user, created)`.
- Rules on each: list/view `user = @request.auth.id`; create `@request.auth.id != "" &&
  @request.body.user = @request.auth.id`; update/delete null (append only).
- Superuser created on the VPS, credentials in a root-only file there.

## 3. Sync client (`app/lib/sync.dart`, `package:http`, `connectivity_plus`)
- `PocketBaseApi`: create user, request verification, auth-with-password (403 unverified → "Verify
  your email" + resend), request password reset, auth-refresh, create record, list records.
- `SyncEngine` (ChangeNotifier status: signed-in email, syncing, last sync, waiting, last error):
  push pending in local order (200 or unique-uuid 400 → uploaded; 401/403 → signed out, local data
  kept); then pull each collection `filter=user=me && created >= cursor - 60s`, `sort=created,id`,
  perPage 500, applyRemote per page, advance cursor. Single-flight with a rerun flag.
- Triggers: launch (after refresh), connectivity back, app resume, 3 s after a local save, sign-in,
  "Sync now" (Claude default: the after-save and resume triggers extend R58 so two online devices
  agree without relaunch).
- Signing out clears token only (R10). Changes made signed out stay `uploaded = 0` (R81).
- Release manifest gains INTERNET; debug-only cleartext for the local test server.

## 4. UI
- Settings sheet: "Account" row → `AccountScreen` (R78: email, password, Sign in, Create account,
  Forgot password; messages for verify/wrong password/offline). Signed in: email, "Sync now", last
  sync time, "N changes waiting", Sign out.

## 5. Proof
- Store integration tests (emulator): v3→v4 keeps data; no-op replay doesn't double count; remote
  apply newest wins for words/marks/bookmarks; counts sum across devices; duplicates ignored.
- Engine unit tests with `MockClient`: push dedup on unique 400, 401 sign-out, pull paging and cursor
  overlap, nullable/omitted PocketBase fields.
- pytest against a local PocketBase 0.40.4 with the migrations: user B can't list/view/create-as A,
  no update/delete, unverified can't auth, invalid mark combos rejected.
- Integration test: two stores (two DB files) against the local server: A offline reveal, B mark,
  restart (reopen) both, sync, both agree.
- Live: Boox 655E999A + emulator against mushaf.ahmadjz.tech: reveal offline on one, mark on the
  other, restart both, reconnect, both agree. curl with a second test account can't read the first.
  Test accounts removed afterwards and listed by id.

## Pre-check (Sol medium, thread 01a1f9c5) folded in
- P1/P2 kept: `WordAction` captures `createdAt` when made (like marks); the store clamps only against
  this device's own earlier actions, so a retried old action never jumps ahead of a newer remote one.
  A pb_hooks create hook clamps `created_at` to server time so a fast clock can't win for long.
  Device clocks are approximate (accepted: R77 says "by when it was made").
- P3 accepted as legacy: pre-v4 actions get `created_at = local_seq`; cross-device order of old data
  is unknowable.
- P4: local data carries `sync_owner`; a different account signing in resets `uploaded` so this
  device's data joins that account (Claude default, R81). Engine drops in-flight results when the
  session generation changed.
- P5: periodic pull every 60 s while foregrounded and signed in (Claude default).
- P6/P7: server hook assigns per-user `seq` (MAX+1, unique index (user, seq); a collision fails one
  create, which stays pending). Pull is keyset: `seq > cursor`, `sort=seq`, page 1, perPage 500;
  cursor saved in the same transaction as the applied rows.
- P8: any 400 on create → GET own record by uuid; acknowledge only if it exists with same payload.
- P9/P10: bools and created_at not required; tombstone = empty style/color; create rule enforces
  `counted ⇒ black` and style/kind/color pairing; users rules self-only, no manage rule.
- P11/P12/P13: update sqlite_test counts; test fresh v4, v1/v2→v4; security tests list per P13.
- P14: SMTP is an owner step; verification/reset email delivery is reported `not observed` until set.
