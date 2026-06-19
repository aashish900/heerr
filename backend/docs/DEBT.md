# DEBT.md — heerr backend

Outstanding work as of 2026-06-16 (post `v3.0.0`). Append new items; strike-through + date when resolved.

Sourced from the 2026-06-16 architecture audit after Phase J shipped. Items here are the canonical home for everything the J11 ADR labelled "tracked in DEBT", plus the wider audit findings.

---

## 1. Drift / inconsistency (fix in the next commit)

These will mislead a future Claude session reading the bootstrap docs.

| # | Item | Where | Notes |
|---|------|-------|-------|
| ~~D1~~ | ~~`app.title`/`version` hardcoded `"0.1.0"` in `app/main.py:12`; `pyproject.toml` is `3.0.0`. Misleads OpenAPI clients and Android Phase S.~~ | `app/main.py:12` | Read from `pyproject` or package version (e.g. `importlib.metadata.version("heerr-backend")`). |
| ~~D2~~ | ~~`backend/docs/PLAN.md` referenced from `CLAUDE.md` as the "frozen v1 contract" predates Phase J.~~ Resolved 2026-06-16: PLAN.md was deleted in 47d6575; stale references scrubbed from `/CLAUDE.md`, `backend/CLAUDE.md`, `backend/README.md`, `backend/docs/ROADMAP.md`. DECISIONLOG / CHANGELOG references left intact as frozen-in-time records. | — | — |

---

## 2. Critical — will block the next feature

| # | Item | Triggered by | Effort |
|---|------|--------------|--------|
| ~~C2~~ | ~~No boot-recovery for orphaned `running` jobs.~~ Resolved 2026-06-17: `recover_orphaned_jobs()` runs in the FastAPI lifespan; every `state='running'` row at boot is marked `failed` with `error_msg='orphaned at boot'`. No grace window — if the worker process is gone, the row is by definition orphaned. **Smoke fix 2026-06-18:** lifespan was using `async for session in get_session()` which never triggered the generator's post-yield `commit()`; replaced with `_sessionmaker()()` + explicit `await session.commit()`. | — | — |
| C3 | **Job cancellation is impossible.** No `cancel-job` endpoint; no PID/Task tracking; only way to stop a spotDL subprocess is killing the container. | Track `asyncio.Task` per `job_id` (or process handle once C1 lands). Add `POST /jobs/{id}/cancel`. | M |
| ~~C5~~ | ~~**No `/auth/logout`.**~~ Resolved 2026-06-16: `POST /api/v1/auth/logout` sets `revoked_at = now()` on the current token; returns 204. Subsequent calls with the same token return 401 (already revoked) via the existing `bearer_token` check. | — | — |

> C1, C4, C6 moved to §7 (Deferred).

---

## 3. Major — will force a painful migration when the related feature lands

| # | Item | Notes |
|---|------|-------|
| ~~M1~~ | ~~`system_admin_user_id()` transitional default is silent.~~ Resolved 2026-06-17: migration 0008 drops the `DEFAULT system_admin_user_id()` on both `tokens.user_id` and `jobs.user_id`. The PG function itself stays for operator lookups. `POST /admin/tokens` now requires `navidrome_username` and FK-links to that user (404 if unknown). T4 regression tests in `test_migration_0008.py` assert any INSERT that forgets `user_id` raises `NotNullViolation`. | — |
| ~~M2~~ | ~~`tokens.owner_label` is now redundant~~ — Resolved 2026-06-18: migration 0009 drops the column. Access log key renamed `owner_label` → `username`, sourced from `tok.user.navidrome_username`. `POST /admin/tokens` request body drops `owner_label`; response and `TokenView` surface `navidrome_username` instead. CLI `create-token --owner` flag removed. Repurpose-as-device-label rejected: no consumer (C5 already done, no sessions endpoint), login contract would have to grow a `device_label` field with no Phase S client to send it, and the access log would still need a separate `username` field — doing the rename anyway. | — |
| ~~M3~~ | ~~`downloads.source_url UNIQUE` collides with the multi-user posture.~~ Resolved 2026-06-19: migration 0010 adds `downloads.user_id` (FK→`users`, `ON DELETE RESTRICT`, backfilled from the owning job), drops the global `UNIQUE` on `source_url`, and adds composite `UNIQUE (user_id, source_url)`. Worker now writes a per-user row (`ON CONFLICT (user_id, source_url) DO NOTHING`); `_hydrate_hints` and `find_download_for_song` filter `Download.user_id` directly. **This also fixed a live bug:** the old global unique meant the 2nd+ user to download a track got their `downloads` row swallowed by `ON CONFLICT (source_url)`, so their per-user `already_downloaded` hint was permanently wrong. Pinned by `test_worker.py::test_run_job_per_user_download_rows_for_shared_url` + `test_migration_0010.py`. | — |
| ~~M4~~ | ~~`jobs.created_by_token_id` semantics under multi-user are undocumented.~~ Resolved 2026-06-18: `tests/test_worker.py::test_run_job_completes_after_creating_token_revoked` pins the contract — revoking a token does not cancel or fail in-flight jobs it created; worker holds the job by id and does not recheck token validity. | — |
| M5 | **No per-user recommendation engine config.** `RECOMMENDATION_ENGINE`, `LASTFM_*`, `LISTENBRAINZ_*` are global env vars. Multi-user backend = single-user recommendations. | Needs a `user_settings` table (or JSONB column on `users`) + factory rewrite. |
| M6 | **Album/playlist jobs write zero `Download` rows.** Documented decision; multi-user makes the gap worse because per-user history is the only signal. Fix requires parsing spotDL `--save-file metadata.json`, which DECISIONLOG explicitly rejected. | Revisit only if users actually report missing dedup hints for tracks inside previously-downloaded albums. |

> M7, M8 moved to §7 (Deferred).

---

## 4. Minor — paper cuts and missing observability

| # | Item | Notes |
|---|------|-------|
| ~~N1~~ | ~~No `GET /admin/users` list / `DELETE /admin/users/{id}`.~~ Resolved 2026-06-18: `GET /admin/users` lists every user; `DELETE /admin/users/{id}` removes orphan users only — blocked by 409 if the user has tokens or jobs (FK is `ON DELETE RESTRICT`), and `system-admin` cannot be deleted. | — |
| ~~N2~~ | ~~No `GET /admin/jobs` with filtering.~~ Resolved 2026-06-18: `GET /admin/jobs?state=&user=&limit=` filters by job state, by `navidrome_username` (404 if unknown), and caps at `limit` (1-500, default 100). Sorted newest-first. | — |
| ~~N3~~ | ~~No `tokens.last_used_at`.~~ Resolved 2026-06-17: migration 0007 added the column; `bearer_token` stamps `now()` on every authenticated request. | — |
| ~~N4~~ | ~~CLI `list-tokens` has no `--user` filter.~~ Resolved 2026-06-18: `list-tokens --user=<navidrome_username>` filters to that user's tokens; errors clearly (`unknown user: <name>`, exit 1) on a missing user, prints `(no tokens)` when the user has none. | — |
| ~~N6~~ | ~~No request body size limits.~~ Resolved 2026-06-17: `MaxBodySizeMiddleware` enforces a 1 MiB `Content-Length` cap; returns 413 before FastAPI body parsing. | — |
| ~~N7~~ | ~~`/health` returns `200 {"status":"ok"}` unconditionally — doesn't verify DB.~~ Resolved 2026-06-17: split into `/health` (unconditional 200) + `/ready` (runs `SELECT 1`, returns 503 on failure). | — |
| ~~N8~~ | ~~OpenAPI docs at `/api/v1/docs` are unauthenticated.~~ Resolved 2026-06-18: FastAPI's default `docs_url` / `openapi_url` / `redoc_url` are disabled; replacements mounted at `/api/v1/openapi.json` and `/api/v1/docs` require an admin bearer (`require_admin`). Swagger UI inlines the spec so the gated HTML page doesn't trigger a second unauthenticated fetch. | — |
| ~~N9~~ | ~~`bearer_token` raises 500 on `tok.user is None`.~~ Resolved 2026-06-17: now returns `401 {"detail": "session invalidated"}` with `WWW-Authenticate: Bearer`. | — |
| ~~N10~~ | ~~`spotdl_runner` swallows fine-grained errors — captures 4 KB stdout+stderr tail with no structured categorization.~~ Resolved 2026-06-18: `_classify_error()` pattern-matches the captured output tail and `run_spotdl` raises one of `NetworkError`, `RateLimitedError`, `VideoUnavailableError`, `RegionLockedError`, `AgeGatedError`, `TranscodeError`, or `UnknownSpotdlError` — all subclasses of `SpotdlError`, so existing `except SpotdlError` paths in `workers.py` and tests stay green. Region check runs before generic "video unavailable" so the more specific signal wins. Auto-retry policy (network + rate-limit → backoff; permanent → fail) is the natural follow-up. | — |
| ~~N11~~ | ~~No spotDL version fingerprint logged at job start.~~ Resolved 2026-06-17: `log_spotdl_version()` probes `spotdl --version` once during `create_app()`; result lands in the structured boot log. | — |
| N12 | No structured progress on jobs. Documented decision; multi-user UX makes the gap more visible. | Coupled with C3 — needs cancellable workers anyway. |
| ~~N13~~ | ~~`POST /auth/login` returns 500 instead of 503 when `NAVIDROME_URL` is missing or malformed.~~ Resolved 2026-06-17: `Settings.navidrome_url` rejects non-`http(s)` URLs at boot; `verify_credentials` catches `httpx.InvalidURL` and re-raises as `NavidromeUnreachable` → 503. **Smoke fix 2026-06-18:** validator existed but `get_settings()` was called lazily (first request), so a bad URL didn't kill the container at boot. Fixed by calling `get_settings()` at the top of `lifespan()` before `yield` — uvicorn treats a pre-yield exception as startup failure and exits. | — |
| ~~N14~~ | ~~Backend does not canonicalize YouTube Music URLs before handing to spotDL.~~ Resolved 2026-06-17: `canonicalize_yt_url()` in `spotdl_runner.py` strips all query params except `v=<id>` (and the fragment) for YT / YT-Music hosts before subprocess invoke. | — |

---

## 5. Test-coverage gaps

| # | Item | Notes |
|---|------|-------|
| T1 | **Order-sensitive failure modes.** `test_migration_0005` downgrade/upgrade can leave the DB at the wrong revision for downstream tests (caught + fixed once already). `test_models_match_schema` only runs at session start — a test that downgrades and forgets to upgrade silently passes the schema-match. | Session-scoped autouse fixture that asserts DB is at `head` after every test that runs `command.downgrade`. |
| T2 | No integration test for concurrent worker invocations. Worker concurrency is exercised by a single faked runner; real-world race on the same output template / Download row insert is untested. | |
| ~~T3~~ | ~~No test for stale-job recovery.~~ Resolved 2026-06-17 alongside C2: `tests/test_jobs_service.py` covers the three transitions (running→failed, untouched queued/done, dedup-slot freed after recovery) plus a lifespan-integration test. | — |
| ~~T4~~ | ~~No regression test that "an INSERT into jobs without user_id silently picks up system-admin".~~ Resolved 2026-06-17 alongside M1: tests in `test_migration_0008.py` assert NotNullViolation for both `tokens` and `jobs` INSERTs that omit `user_id`. | |

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
3. ~~**C4** — token expiry. Deferred 2026-06-18; revisit after Phase S is live.~~
4. **C2 + T1 + T3** — boot recovery for orphaned `running` jobs. Small fix, prevents support-by-SQL.
5. **M1 + T4** — add a regression test that catches missing `user_id` on INSERT, then plan the migration to drop the `system_admin_user_id()` default once Phase S ships.
6. ~~**C6 + M8** — login + `/download` rate limiting.~~ Deferred 2026-06-18: tailnet-only family-scale app; revisit if abuse surfaces.
7. ~~**C1 + C3 + N12 + M7** — real queue substrate.~~ C1 + M7 deferred 2026-06-18 (no new components, family-scale). C3 / N12 stay blocked on C1; revisit together.
8. **M5** — per-user recommendation engine config. Unblocks per-user Last.fm/ListenBrainz scrobbling (already a deferred item on the Android side).
9. **Everything else** — opportunistically, as features that need them land.

---

## 7. Deferred — not pursuing at current stage

Rows assessed and explicitly parked. They retain their original ID (from the 2026-06-16 architecture audit) for traceability. The `[DEFERRED]` prefix is a tag, not a status field — every row in this section is deferred. Revisit when the stated trigger actually materialises.

| # | Item | Reason / revisit when | Original section |
|---|------|-----------------------|------------------|
| C1 | No real job queue (`FastAPI BackgroundTasks`). | Not tackling new infra components right now; revisit when multi-user load actually surfaces the issue. | §2 Critical |
| C4 | No token expiry — tokens are revocable-only. | Not critical at current stage; revisit after Phase S (Android multi-user client) is live. N5 / Android may want it then. | §2 Critical |
| C6 | `POST /auth/login` has no rate limit. | Tailnet-only posture + small family user base; not warranted at current stage. | §2 Critical |
| M7 | No per-user download quota. | Tailnet-only family-scale app; revisit if disk pressure or abuse actually surfaces. Couples with C1. | §3 Major |
| M8 | No per-user `/download` rate limit. | Tailnet-only family-scale app; revisit if abuse actually surfaces. Same mechanism as C6 / M7. | §3 Major |
| N5 | No CORS configuration. | No web UI planned; Flutter is a native HTTP client and does not trigger CORS. Revisit only if a browser-based admin UI ever lands. | §4 Minor |

All deferral decisions dated 2026-06-18.

---

## Out of scope

Items the audit explicitly *did not* flag as debt (already decided, not changing):

- spotDL stays a subprocess CLI, not a library import (2026-06-08 ADR).
- spotDL lives in `/opt/spotdl-venv`, not main Poetry deps (2026-06-08 ADR).
- No public-internet exposure; tailnet only (`/CLAUDE.md` §3).
- No FCM / push channel; polling is the contract (2026-06-09 ADR).
- No Spotify search / SDK; YouTube Music only (2026-06-10 ADR).
