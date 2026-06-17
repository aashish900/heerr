# DEBT.md — heerr backend

Outstanding work as of 2026-06-16 (post `v3.0.0-rc1`). Append new items; strike-through + date when resolved.

Sourced from the 2026-06-16 architecture audit after Phase J shipped. Items here are the canonical home for everything the J11 ADR labelled "tracked in DEBT", plus the wider audit findings.

---

## 1. Drift / inconsistency (fix in the next commit)

These will mislead a future Claude session reading the bootstrap docs.

| # | Item | Where | Notes |
|---|------|-------|-------|
| ~~D1~~ | ~~`app.title`/`version` hardcoded `"0.1.0"` in `app/main.py:12`; `pyproject.toml` is `3.0.0-rc1`. Misleads OpenAPI clients and Android Phase S.~~ | `app/main.py:12` | Read from `pyproject` or package version (e.g. `importlib.metadata.version("heerr-backend")`). |
| ~~D2~~ | ~~`backend/docs/PLAN.md` referenced from `CLAUDE.md` as the "frozen v1 contract" predates Phase J.~~ Resolved 2026-06-16: PLAN.md was deleted in 47d6575; stale references scrubbed from `/CLAUDE.md`, `backend/CLAUDE.md`, `backend/README.md`, `backend/docs/ROADMAP.md`. DECISIONLOG / CHANGELOG references left intact as frozen-in-time records. | — | — |

---

## 2. Critical — will block the next feature

| # | Item | Triggered by | Effort |
|---|------|--------------|--------|
| C1 | **No real job queue.** `FastAPI BackgroundTasks` does not survive container restart, has no concurrency cap, no retry policy, no scheduled work. Two `/download` calls = two concurrent spotDL subprocesses. **First thing to fail under real multi-user load.** | Migration to arq / Celery / RQ. Worker needs DB session, settings, spotDL runner, `request_id` propagation. | L |
| C2 | **No boot-recovery for orphaned `running` jobs.** Container restart mid-download leaves rows in `running` forever until admin manually retries each. | Add a startup hook that marks rows with `state='running' AND started_at < now() - interval 'X minutes'` as `failed` (or re-enqueue once C1 lands). | S |
| C3 | **Job cancellation is impossible.** No `cancel-job` endpoint; no PID/Task tracking; only way to stop a spotDL subprocess is killing the container. | Track `asyncio.Task` per `job_id` (or process handle once C1 lands). Add `POST /jobs/{id}/cancel`. | M |
| C4 | **No token expiry.** Tokens are revocable-only. Once minted they live forever. Multi-user makes a stolen-token incident permanent. Adding `expires_at` now is a 2-column migration; after Phase S Android ships it's a coordinated client/server release. | `tokens.expires_at` + check in `bearer_token`. Optional refresh-token flow. | S |
| ~~C5~~ | ~~**No `/auth/logout`.**~~ Resolved 2026-06-16: `POST /api/v1/auth/logout` sets `revoked_at = now()` on the current token; returns 204. Subsequent calls with the same token return 401 (already revoked) via the existing `bearer_token` check. | — | — |
| C6 | **`POST /auth/login` has no rate limit.** Brute-forcing Navidrome credentials through heerr is unmitigated. Tailscale narrows the threat to tailnet members but does not eliminate it. | Per-IP + per-username sliding-window in Postgres (or fastapi-limiter / slowapi). Lockout after N failures. | M |

---

## 3. Major — will force a painful migration when the related feature lands

| # | Item | Notes |
|---|------|-------|
| M1 | **`system_admin_user_id()` transitional default is silent.** The J2 server-default on `tokens.user_id` / `jobs.user_id` masks any app code path that forgets to set `user_id`. **No test catches "an endpoint INSERTs without passing user_id and silently routes to system-admin."** Drop the default once Phase S Android ships and every INSERT site is verified. | The J11 ADR flagged this. Plan: a new migration after Phase S that ALTERs the columns to remove the DEFAULT. Until then, add at least one regression test that inserts via a real route and asserts `user_id != system-admin`. |
| M2 | **`tokens.owner_label` is now redundant** — equals `user.navidrome_username` after J6. Two columns drift over time. | Either drop the column or repurpose as a device label (`"alice-pixel-7"`). The device-label angle is genuinely useful for the "log out my other sessions" UX that C5 will unlock. |
| M3 | **`downloads.source_url UNIQUE` collides with the multi-user posture.** Worker absorbs collisions via `ON CONFLICT DO NOTHING`. Any future per-user download metadata (e.g. "tagged at", "alice's local copy on device-X") needs this constraint gone. | Migration plan: add `downloads.user_id` FK + drop UNIQUE on `source_url` + add composite UNIQUE `(user_id, source_url)`. |
| M4 | **`jobs.created_by_token_id` semantics under multi-user are undocumented.** When admin revokes a token, in-flight jobs created by it keep running because the worker holds the job by id and doesn't recheck token validity. Probably correct, but no test pins the behaviour. | Add a test asserting "revoke a token → its in-flight job still completes" so future changes don't silently break the contract. |
| M5 | **No per-user recommendation engine config.** `RECOMMENDATION_ENGINE`, `LASTFM_*`, `LISTENBRAINZ_*` are global env vars. Multi-user backend = single-user recommendations. | Needs a `user_settings` table (or JSONB column on `users`) + factory rewrite. |
| M6 | **Album/playlist jobs write zero `Download` rows.** Documented decision; multi-user makes the gap worse because per-user history is the only signal. Fix requires parsing spotDL `--save-file metadata.json`, which DECISIONLOG explicitly rejected. | Revisit only if users actually report missing dedup hints for tracks inside previously-downloaded albums. |
| M7 | **No per-user quota.** Any logged-in user can fill `/data/media/music`. No `MAX_DOWNLOADS_PER_USER`, no `MAX_BYTES_PER_USER`. | Postgres-backed counter + middleware. Couples with C1. |
| M8 | **No per-user `/download` rate limit.** A user can dispatch hundreds of `/download` calls in a tight loop, each spawning a spotDL subprocess. | Same mechanism as C6 / M7. |

---

## 4. Minor — paper cuts and missing observability

| # | Item | Notes |
|---|------|-------|
| N1 | No `GET /admin/users` list / `DELETE /admin/users/{id}`. J10 added create-or-get but no list/remove. Operator inspects via raw SQL. | |
| N2 | No `GET /admin/jobs` with filtering. Same. | |
| N3 | No `tokens.last_used_at`. Can't tell which tokens are stale and safe to revoke. | Bump in `bearer_token` (cheap; once per request). |
| N4 | CLI `list-tokens` has no `--user` filter. Hard to clean up after one user. | |
| N5 | No CORS configuration. Future admin web UI from a tailnet browser will be blocked. | |
| N6 | No request body size limits. FastAPI default is unlimited. `POST /search` with a 10 MB query lands intact in worker memory. | |
| N7 | `/health` returns `200 {"status":"ok"}` unconditionally — doesn't verify DB. Container healthcheck calls this. | Add `/ready` that pings DB; keep `/health` cheap. |
| N8 | OpenAPI docs at `/api/v1/docs` are unauthenticated and expose admin endpoint shapes. | Tailscale-only mitigates; still sloppy. |
| N9 | `bearer_token` raises 500 on `tok.user is None`. Correct semantically (data corruption) but a delete-user-mid-request race surfaces a 500 with no actionable error. | Either return 401 with a "session invalidated" detail or guard the delete-user path. |
| N10 | `spotdl_runner` swallows fine-grained errors — captures 4 KB stdout+stderr tail with no structured categorization (network / region-lock / age-gate / transcode failure). | Classify common spotDL exit patterns; surface as typed `SpotdlError` subclasses. |
| N11 | No spotDL version fingerprint logged at job start. Two containers on different spotDL versions produce different outputs; nothing in the job row records which version ran. | One-line log at job start. |
| N12 | No structured progress on jobs. Documented decision; multi-user UX makes the gap more visible. | Coupled with C3 — needs cancellable workers anyway. |
| N13 | **`POST /auth/login` returns 500 instead of 503 when `NAVIDROME_URL` is missing or malformed.** Surfaced during J12 smoke: with the env var unset, `verify_credentials` lets an httpx URL-parse exception bubble unhandled. Operator misconfig should look like "Navidrome unreachable", not "backend crashed". | Defensive validation in `app/config.py` (fail fast at boot if `NAVIDROME_URL` is not a parseable `http(s)` URL) and/or a broader `except` in `verify_credentials` that wraps non-`NavidromeUnreachable` errors. |
| N14 | **Backend does not canonicalize YouTube Music URLs before handing to spotDL.** Surfaced during J12 smoke: URLs with `&list=...` / `&index=...` query params drive spotDL into a broken `KeyError: 'videoDetails'` code path; stripping to bare `watch?v=<id>` works. Two real user paste-ins failed before this was diagnosed. | Strip non-essential query params (`list`, `index`, `pp`, `feature`, ...) in the `/download` handler or in `spotdl_runner` before subprocess invoke. Independently, the pinned spotDL is upstream-broken on the full URL form — consider bumping. |

---

## 5. Test-coverage gaps

| # | Item | Notes |
|---|------|-------|
| T1 | **Order-sensitive failure modes.** `test_migration_0005` downgrade/upgrade can leave the DB at the wrong revision for downstream tests (caught + fixed once already). `test_models_match_schema` only runs at session start — a test that downgrades and forgets to upgrade silently passes the schema-match. | Session-scoped autouse fixture that asserts DB is at `head` after every test that runs `command.downgrade`. |
| T2 | No integration test for concurrent worker invocations. Worker concurrency is exercised by a single faked runner; real-world race on the same output template / Download row insert is untested. | |
| T3 | No test for stale-job recovery (because no code for it — see C2). | |
| T4 | No regression test that "an INSERT into jobs without user_id silently picks up system-admin" — pairs with M1. | |

---

## 6. Documentation / process

| # | Item | Notes |
|---|------|-------|
| P1 | **No `backend/docs/DEBT.md`** — fixed by this file. | ✅ 2026-06-16. |
| ~~P2~~ | ~~PLAN.md drift (also listed as D2).~~ Resolved 2026-06-16 alongside D2. | |
| ~~P3~~ | ~~`docker-compose.snippet.yml` doesn't explicitly call out `NAVIDROME_URL` as required.~~ Resolved 2026-06-16: header now lists `NAVIDROME_URL` (and the rest of the required vars) explicitly. | |

---

## Priority order (suggested attack sequence)

1. ~~**D1, D2, P3** — paperwork. Mins each.~~ Done.
2. ~~**C5** — `/auth/logout`.~~ Done 2026-06-16.
3. **C4** — token expiry. S effort, unlocks "session timeout" semantics. Coordinate with Android Phase S so the client renews tokens.
4. **C2 + T1 + T3** — boot recovery for orphaned `running` jobs. Small fix, prevents support-by-SQL.
5. **M1 + T4** — add a regression test that catches missing `user_id` on INSERT, then plan the migration to drop the `system_admin_user_id()` default once Phase S ships.
6. **C6 + M8** — login + `/download` rate limiting. Mitigates the biggest credible abuse vectors.
7. **C1 + C3 + N12 + M7** — real queue substrate. Largest single piece of work; everything else gets easier once it's in place.
8. **M5** — per-user recommendation engine config. Unblocks per-user Last.fm/ListenBrainz scrobbling (already a deferred item on the Android side).
9. **Everything else** — opportunistically, as features that need them land.

---

## Out of scope

Items the audit explicitly *did not* flag as debt (already decided, not changing):

- spotDL stays a subprocess CLI, not a library import (2026-06-08 ADR).
- spotDL lives in `/opt/spotdl-venv`, not main Poetry deps (2026-06-08 ADR).
- No public-internet exposure; tailnet only (`/CLAUDE.md` §3).
- No FCM / push channel; polling is the contract (2026-06-09 ADR).
- No Spotify search / SDK; YouTube Music only (2026-06-10 ADR).
