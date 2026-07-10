# ROADMAP.md — heerr Backend Implementation Milestones

Track progress through the backend build. Each milestone = one git commit with a green test gate (where applicable). Tick the box when committed.

See `DECISIONLOG.md` 2026-06-08 entries for the *what*; this file is the *how* / *when*.

**Status (2026-07-10):** Phases A–O complete. Phase O (song metadata edit, issue #44) shipped 2026-07-06 at `4.6.2`; `4.7.0` (2026-07-10) is the app-wide gradient redesign; `4.7.1`/`4.7.2` (2026-07-10) are widget/tab visual polish passes (Android-side only — no backend changes; version bumped for sync).

**Conventions:**
- TDD per CLAUDE.md §2 — tests written first, land in same commit as code.
- Out-of-TDD-scope (CLAUDE.md §2): scaffold, migrations, Dockerfile, compose, smoke. These have other verification gates noted per-milestone.
- Commit messages: Conventional Commits (`feat(scope): …`, `chore: …`, `infra: …`).
- One milestone = one commit. Follow-up cleanup within a milestone = separate commit under the same milestone.

---

## Phase A — Foundation

### [x] A1. Scaffold: Poetry + Alembic skeleton
**Files:** `backend/pyproject.toml`, `backend/alembic.ini`, `backend/alembic/env.py`, `backend/alembic/script.py.mako`, `backend/alembic/versions/`
**Deliverable:** `cd backend && poetry install` succeeds; `poetry run alembic current` runs.
**Test gate:** none (out of TDD scope).
**Done when:** `poetry install` + `alembic current` both exit 0.
**Commit:** `chore(backend): scaffold poetry + alembic skeleton`

### [x] A2. Migration 0001 — schema v1
**Files:** `backend/alembic/versions/0001_init.py`, `backend/tests/__init__.py`, `backend/tests/conftest.py`, `backend/tests/test_migration_0001.py`
**Deliverable:** Schema enforced at DB level (tokens, jobs, downloads + partial unique index + CHECK constraints + pgcrypto/vector extensions).
**Test gate:** migration round-trip + constraint violations asserted; `pytest backend/tests/test_migration_0001.py` green.
**Done when:** Partial-unique-index invariant ("no duplicate active job") proven by a test that catches the unique-violation.
**Commit:** `feat(db): schema v1 — tokens, jobs, downloads`

### [x] A3. SQLAlchemy ORM models
**Files:** `backend/app/__init__.py`, `backend/app/models/{__init__,base,token,job,download}.py`, `backend/tests/test_models_match_schema.py`
**Deliverable:** ORM mirrors schema; drift caught by Alembic `compare_metadata`.
**Test gate:** model/schema diff returns no differences.
**Done when:** `compare_metadata` clean against the migrated container.
**Commit:** `feat(models): sqlalchemy orm for tokens, jobs, downloads`

---

## Phase B — Plumbing

### [x] B1. App config + async DB session
**Files:** `backend/app/config.py`, `backend/app/db.py`, `backend/tests/test_config.py`, `backend/tests/test_db_session.py`
**Deliverable:** `pydantic-settings`-based config (DATABASE_URL, SPOTIFY_*, MUSIC_OUTPUT_DIR); async engine + session dependency.
**Test gate:** config env-load + required-field errors; session round-trips `SELECT 1`.
**Done when:** Session yields/commits/closes cleanly against the testcontainer.
**Commit:** `feat: app config + async db session`

### [x] B2. Auth dependency
**Files:** `backend/app/api/__init__.py`, `backend/app/api/deps.py`, `backend/tests/test_auth.py`
**Deliverable:** `bearer_token()`, `require_scope(...)`, `require_admin()` FastAPI dependencies.
**Test gate:** table-driven coverage of every branch (missing/invalid/revoked/wrong-scope/admin-required).
**Done when:** All auth state-machine branches green.
**Commit:** `feat(auth): bearer token dependency + scope checks`

### [x] B3. Token CLI
**Files:** `backend/app/cli.py`, `backend/tests/test_cli.py`; add `typer` to deps.
**Deliverable:** `python -m app.cli create-token | list-tokens | revoke-token` — raw token printed once; hash persisted.
**Test gate:** Typer `CliRunner` against test DB.
**Done when:** `poetry run python -m app.cli create-token --owner=test --scopes=read,download` prints a token, row in DB.
**Commit:** `feat(cli): token management commands`

---

## Phase C — Read path

### [x] C1. FastAPI app skeleton + `/health`
**Files:** `backend/app/main.py`, `backend/app/api/v1/{__init__,router,health}.py`, `backend/tests/test_health.py`; add `fastapi`, `uvicorn[standard]` to deps.
**Deliverable:** Boot-able FastAPI app, `/api/v1` mounted, `/health` returns `{"status":"ok"}` (no auth).
**Test gate:** httpx `ASGITransport` test → 200.
**Done when:** `poetry run uvicorn app.main:app` boots; `curl localhost:8000/api/v1/health` returns 200.
**Commit:** `feat(api): app skeleton + GET /health`

### [x] C2. Spotify client-credentials service
**Files:** `backend/app/services/{__init__,spotify}.py`, `backend/tests/test_spotify_service.py`; add `spotipy` to deps.
**Deliverable:** `services.spotify` exposes `search_tracks/albums/playlists` returning typed results. Token caching handled by spotipy.
**Test gate:** HTTP stubbed via `respx`/`httpx.MockTransport`; no network in tests.
**Done when:** All three search types return typed results in tests.
**Commit:** `feat(spotify): client-credentials search wrapper`

### [x] C3. `POST /search`
**Files:** `backend/app/schemas/{__init__,search}.py`, `backend/app/api/v1/search.py`, `backend/tests/test_search.py`
**Deliverable:** Contract-shaped `POST /search` with `read` scope; `already_downloaded` + `active_job_id` hydrated from DB.
**Test gate:** auth/scope failures; mocked Spotify; dedup hints correct against seeded DB rows.
**Done when:** All contract fields populated correctly for track/album/playlist queries.
**Commit:** `feat(search): POST /search with dedup hints`

---

## Phase D — Write path

### [x] D1. Job state machine service
**Files:** `backend/app/services/jobs.py`, `backend/tests/test_jobs_service.py`
**Deliverable:** Pure async functions — `create_job_idempotent`, `mark_running/done/failed`, `bump_attempt`, `find_active_for_uri`, `find_download_for_track`.
**Test gate:** every transition + concurrency test proves the partial-unique-index catches duplicate creates.
**Done when:** Idempotency + all state transitions covered.
**Commit:** `feat(jobs): state machine service`

### [x] D2. `POST /download`
**Files:** `backend/app/schemas/download.py`, `backend/app/api/v1/download.py`, `backend/tests/test_download.py`
**Deliverable:** Idempotent dispatch; worker stub (sleep then mark done — real spotDL in F2); URI prefix dispatch.
**Test gate:** new-URI / active-dedupe / on-disk-dedupe / scope=read→403 / bad URI→422.
**Done when:** Every idempotency branch tested.
**Commit:** `feat(download): POST /download with idempotent dispatch`

### [x] D3. `GET /status/{job_id}` + `GET /queue`
**Files:** `backend/app/schemas/job.py`, `backend/app/api/v1/{status,queue}.py`, `backend/tests/test_status.py`, `backend/tests/test_queue.py`
**Deliverable:** Status read + queue (active + recent 20).
**Test gate:** shape/ordering/404/auth covered.
**Done when:** Contract fields match exactly.
**Commit:** `feat(jobs): GET /status/{id} + GET /queue`

---

## Phase E — Admin

### [x] E1. Admin endpoints
**Files:** `backend/app/schemas/token.py`, `backend/app/api/v1/admin.py`, `backend/tests/test_admin.py`
**Deliverable:** `POST/GET /admin/tokens`, `POST /admin/tokens/{id}/revoke`, `POST /admin/jobs/{id}/retry`. Retry only allowed on `failed`; bumps `attempt_count`; resets to `queued`.
**Test gate:** CRUD round-trip, raw token only in create response, retry 409 on non-failed, non-admin → 403.
**Done when:** Full admin surface exercised.
**Commit:** `feat(admin): token management + job retry`

---

## Phase F — Real worker

### [x] F1. spotDL subprocess wrapper
**Files:** `backend/app/services/spotdl_runner.py`, `backend/tests/test_spotdl_runner.py`
**Deliverable:** `async run_spotdl(uri, output_dir) -> list[DownloadedFile]` via `asyncio.create_subprocess_exec`; typed `SpotdlError`.
**Test gate:** `create_subprocess_exec` faked; happy + non-zero-exit paths.
**Done when:** Both paths tested without invoking real spotDL.
**Commit:** `feat(spotdl): subprocess runner`

### [x] F2. Worker integration
**Files modified:** `backend/app/services/jobs.py`, `backend/app/api/v1/download.py`; new `backend/tests/test_worker.py`
**Deliverable:** `run_job(job_id)` loads job → mark running → invoke spotDL → write `downloads` rows → mark done; on exception → mark failed.
**Test gate:** happy path (downloads row written, state done) + failure path (state failed, error_msg set, no download row).
**Done when:** Faked-spotDL e2e succeeds in tests.
**Commit:** `feat(worker): integrate spotDL runner with /download`

---

## Phase G — Ship it

### [x] G1. Backend Dockerfile
**Files:** `backend/Dockerfile`, `backend/.dockerignore`
**Deliverable:** Multi-stage build; runtime = `python:3.13-slim` + `ffmpeg` + `spotdl` pinned + venv. Runs as non-root. CMD = uvicorn.
**Test gate:** none.
**Done when:** `docker build -t music-search-backend backend/` succeeds; `docker run --rm music-search-backend python -m app.cli --help` works.
**Commit:** `infra(backend): dockerfile`

### [x] G2. docker-compose snippet + `.env.example`
**Files:** `docker-compose.snippet.yml`, `.env.example`, README/CONTEXT update.
**Deliverable:** Compose stack — `backend`, `postgres` (pgvector/pg17), `postgres-init` (chown). Healthchecks + dependency order. On existing `172.39.0.0/24` arr-stack network as external. No manual host steps.
**Test gate:** none.
**Done when:** `docker compose up` from a copy with real `.env` starts all three services; Alembic auto-applies; `/health` returns 200 from a sibling container.
**Commit:** `infra: compose snippet for arr-stack integration`

---

## Phase H — End-to-end smoke

### [x] H1. Smoke on the home server
**Files:** optional `docs/smoke.md` capturing commands + output.
**Deliverable:** Real Navidrome lists a track downloaded via the API.
**Test gate:** manual; run `/health`, mint a token, `POST /search`, `POST /download`, poll `/status`, confirm the file lands under `/data/media/music/` and Navidrome indexes it.
**Done when:** Step 5 (file under `/data/media/music/...`) + step 6 (Navidrome lists it) both confirmed.
**Commit:** `chore: e2e smoke verified` (optional — only if recording output).
**Status (2026-06-18):** ✅ Smoke passed on home server against v3.1.0-rc1. All 21 checks in SMOKE-TEST.md green. Two bugs found and fixed during smoke: (1) lifespan used `async for session in get_session()` which never committed the orphan-recovery UPDATE (C2); (2) `get_settings()` was not called eagerly so a bad `NAVIDROME_URL` didn't kill the container at boot (N13). Both fixed, 321/321 tests green, re-tagged and pushed.

---

## Phase I — Recommendations engine

Pluggable recommendation engine with a swappable `RecommendationEngine` Protocol. Each engine is
selected via `RECOMMENDATION_ENGINE` env var; a comma-separated value enables a fallback chain
(`"lastfm,ytmusic"`). See `DECISIONLOG.md` 2026-06-13 entry for the full rationale.

Depends on: H1 smoke green. Android N1 (scrobble) should be live before I3/I5 are useful in
practice — Last.fm and ListenBrainz need listening history to personalise.

### [x] I1. Protocol + skeleton endpoint
**Files:** `backend/app/services/recommenders/__init__.py`, `backend/app/services/recommenders/base.py`, `backend/app/services/recommenders/factory.py`, `backend/app/schemas/recommend.py`, `backend/app/api/v1/recommend.py`; router wired in `backend/app/api/v1/router.py`; `.env.example` gains `RECOMMENDATION_ENGINE=ytmusic`.
**Deliverable:**
- `RecommendationEngine` Protocol + `SeedTrack(title, artist, source_url: str | None)` + `RecommendedTrack(title, artist, source_url, score: float | None)` dataclasses in `base.py`.
- `factory.py` reads `RECOMMENDATION_ENGINE`; validates required credentials at startup; raises `RuntimeError` with a clear message on missing creds.
- `POST /api/v1/recommend` (scope: `read`): accepts `RecommendRequest(seeds, limit: 1–50)`, calls `engine.recommend(seeds, limit)`, returns `RecommendResponse`. Engine is a stub returning `[]` at this milestone.
**Test gate:** 401 missing auth; 403 wrong scope; 422 on bad limit / extra fields; 200 stub returns empty list.
**Done when:** All test branches green; `mypy app/` clean on new files.
**Commit:** `feat(backend): I1 — RecommendationEngine protocol + POST /recommend skeleton`

### [x] I2. ytmusicapi engine (zero-credential default)
**Files:** `backend/app/services/recommenders/ytmusic_engine.py`; updated `factory.py`.
**Deliverable:**
- `YTMusicEngine` implements `RecommendationEngine`.
- Seeds with `source_url` matching `music.youtube.com/watch?v=<id>`: extracts `videoId`, calls `ytmusic.get_watch_playlist(videoId=<id>)`.
- Seeds without `source_url` (title + artist only): calls `ytmusic.search(f"{artist} {title}", filter="songs", limit=1)` first to resolve a `videoId`.
- Deduplicates results by `videoId` across seeds. Caps at `limit`.
- Factory: `"ytmusic"` is default when `RECOMMENDATION_ENGINE` not set; no credentials required.
**Test gate:** mock `ytmusicapi.YTMusic`; assert deduplication; assert limit cap; assert seed-with-no-url resolves before recommending; assert missing-url seed that yields no search result is skipped gracefully.
**Done when:** All test branches green; engine wired as default in factory.
**Commit:** `feat(backend): I2 — ytmusicapi recommendation engine`

### [x] I3. Last.fm engine
**Files:** `backend/app/services/recommenders/lastfm_engine.py`; updated `factory.py`; `.env.example` gains `LASTFM_API_KEY` and `LASTFM_USERNAME`.
**Deliverable:**
- `LastFMEngine` implements `RecommendationEngine`.
- Required env var: `LASTFM_API_KEY` (free — register at last.fm/api). Factory validates presence at startup with a clear error.
- Optional env var: `LASTFM_USERNAME`. When set, supplements client seeds with `user.getTopTracks?period=1month&limit=10` — makes recommendations autonomous (Android need not send seeds if Last.fm history exists).
- Per seed: `track.getSimilar(artist, track, limit=n)` for title-bearing seeds; `artist.getSimilar(artist)` + `artist.getTopTracks` for artist-level broadening.
- Merges by Last.fm `match` weight; deduplicates by `artist+title`; caps at `limit`.
- Resolves each result to a `music.youtube.com` URL via ytmusicapi search (same pattern as I2) so results are immediately downloadable.
**Test gate:** mock Last.fm HTTP calls; assert ranking by match weight; assert `LASTFM_USERNAME` path augments seeds; assert factory raises `RuntimeError` on missing `LASTFM_API_KEY`; assert ytmusicapi resolution step is called per result.
**Done when:** All test branches green; `mypy app/` clean.
**Commit:** `feat(backend): I3 — Last.fm recommendation engine`

### [x] I4. Fallback chain + engine health endpoint
**Files:** `backend/app/services/recommenders/factory.py` (updated); `backend/app/services/recommenders/fallback_engine.py`; `backend/app/api/v1/recommend.py` (add health route).
**Deliverable:**
- `FallbackEngine` wrapper: tries engines left-to-right; on any exception falls back to the next; logs at `WARNING` with engine name + error.
- Factory: `RECOMMENDATION_ENGINE=lastfm,ytmusic` instantiates `FallbackEngine([LastFMEngine, YTMusicEngine])`.
- `GET /api/v1/recommend/health` (scope: `read`): returns `{"engine": "<name>", "status": "ok" | "degraded", "fallback_active": bool}`. Calls a lightweight probe on each engine (Last.fm: one cheap API call; ytmusicapi: no network needed).
**Test gate:** `FallbackEngine` falls back when first engine raises; second engine result returned; health returns `degraded` + `fallback_active: true` when primary fails probe; health returns `ok` when all engines healthy.
**Done when:** All branches green.
**Commit:** `feat(backend): I4 — fallback chain + GET /recommend/health`

### [x] I5. ListenBrainz engine
**Files:** `backend/app/services/recommenders/listenbrainz_engine.py`; updated `factory.py`; `.env.example` gains `LISTENBRAINZ_USER_TOKEN`.
**Deliverable:**
- `ListenBrainzEngine` implements `RecommendationEngine`.
- Required env var: `LISTENBRAINZ_USER_TOKEN` (free — register at listenbrainz.org). Factory validates at startup.
- Calls ListenBrainz recommendation API: `GET /1/cf/recommendation/user/<username>/recording?count=<limit>`. Username derived from token via `GET /1/validate-token`.
- Resolves each result to a `music.youtube.com` URL via ytmusicapi search.
- Client-provided seeds are passed as feedback hints if the ListenBrainz API supports it; otherwise seeds are ignored (ListenBrainz history drives the result independently).
**Test gate:** mock ListenBrainz HTTP calls; assert token validation on startup; assert ytmusicapi URL resolution; assert factory raises on missing token.
**Done when:** All branches green. Ship after Android N1 has been live ≥ 1 week so there is scrobble history to recommend against.
**Commit:** `feat(backend): I5 — ListenBrainz recommendation engine`

---

## Phase J — Multi-user via Navidrome IdP

**Architecture note:** Heerr delegates identity to Navidrome (Jellyseerr pattern). No password column on the backend — Subsonic `ping.view` is the credential check. New `users` table; existing `tokens` and `jobs` gain `user_id` FKs; per-user filtering on `/queue`, `/status`, `/search`, `/download`. CLI-minted tokens attach to a fixed `system-admin` user. **Tailscale-only posture is preserved** — no public ingress, no TLS, no rate limiting added. Overturns the "Single-user" framing in `backend/docs/CONTEXT.md` line 30 via the J11 ADR. Depends on H1 only in the sense that the home-server smoke for Phase J (J12, manual) requires a real Navidrome to point at; Phase J code itself does not require H1 to land.

### [x] J1. Schema migration — `users` table + FK columns (nullable)
**Files:** `backend/alembic/versions/0002_users.py`, `backend/tests/test_migration_0002.py`.
**Deliverable:** New `users` table (`id uuid pk default gen_random_uuid()`, `navidrome_username text unique not null`, `created_at timestamptz default now()`, `last_login_at timestamptz null`). New nullable `user_id uuid references users(id) on delete restrict` columns on `tokens` and `jobs`. No backfill yet (J2 owns that). Migration is idempotent up/down.
**Test gate:** migration up + down round-trips clean; unique-constraint on `navidrome_username` enforced; FK reject on bogus `user_id`.
**Done when:** `alembic upgrade head` clean on a fresh DB and on a DB with v0.1.x rows; `alembic downgrade -1` clean.
**Commit:** `feat(db): J1 — users table + nullable user_id FKs on tokens and jobs`

### [x] J2. Backfill migration — synthetic `legacy-admin` + `system-admin` users; `NOT NULL` FKs
**Files:** `backend/alembic/versions/0003_backfill_users.py`, `backend/tests/test_migration_0003.py`.
**Deliverable:** Inserts two seed users (`legacy-admin`, `system-admin`). Backfills `tokens.user_id` → `system-admin` (CLI-minted assumption) and `jobs.user_id` → `legacy-admin` for every pre-J1 row. After backfill, `ALTER COLUMN user_id SET NOT NULL` on both tables.
**Test gate:** seeds a v0.1.x DB with rows, runs migration, asserts every pre-existing row has the right user_id; new `NOT NULL` constraint enforced.
**Done when:** every pre-existing token / job row carries a user_id; `INSERT` without `user_id` fails.
**Commit:** `feat(db): J2 — backfill users + lock user_id NOT NULL`

### [x] J3. ORM models — `User` + relationship wiring
**Files:** `backend/app/models/user.py`, `backend/app/models/{token,job}.py` (add relationship), `backend/app/models/__init__.py`, `backend/tests/test_models_match_schema.py` (update).
**Deliverable:** `User` SQLAlchemy model mirroring J1 schema; `Token.user`, `Job.user` back-refs. `compare_metadata` clean against the J2-migrated container.
**Test gate:** model/schema diff returns no differences; relationship navigation in a sample query.
**Done when:** `compare_metadata` clean.
**Commit:** `feat(models): J3 — User ORM + token/job relationships`

### [x] J4. `NAVIDROME_URL` config + `.env.example`
**Files:** `backend/app/config.py`, `backend/.env.example`, `backend/tests/test_config.py`.
**Deliverable:** New required `NAVIDROME_URL` field on `Settings` (string, no default in prod; test fixtures supply a stub). `.env.example` gains `NAVIDROME_URL=http://navidrome.example.tailnet:4533`. Missing-value error message names the variable.
**Test gate:** missing env var → clear startup error; valid URL parses.
**Done when:** boot fails fast with a named error when `NAVIDROME_URL` is unset; sets correctly when present.
**Commit:** `feat(config): J4 — NAVIDROME_URL required setting`

### [x] J5. Navidrome auth service — Subsonic ping verify
**Files:** `backend/app/services/navidrome_auth.py`, `backend/tests/test_navidrome_auth.py`.
**Deliverable:** Pure async `verify_credentials(username, password) -> bool` that calls `GET <NAVIDROME_URL>/rest/ping.view?u=<u>&t=<md5(p+salt)>&s=<salt>&v=1.16.1&c=heerr&f=json`. Parses `subsonic-response.status`; returns True on `"ok"`, False on `"failed"`. Network errors raise `NavidromeUnreachable` (typed). HTTP via `httpx.AsyncClient`; no `dio`-style retry.
**Test gate:** stubbed httpx for ok / wrong-password / unreachable paths; salt is deterministic in tests (injected).
**Done when:** all three branches green; no real network traffic in tests.
**Commit:** `feat(auth): J5 — Navidrome Subsonic credential verify`

### [x] J6. `POST /api/v1/auth/login`
**Files:** `backend/app/schemas/auth.py`, `backend/app/api/v1/auth.py`, `backend/app/api/v1/router.py`, `backend/tests/test_auth_login.py`.
**Deliverable:** `LoginRequest(username, password)` → `LoginResponse(token, scopes, navidrome_url, navidrome_username)`. Calls J5 to verify; on success upserts a `users` row (insert-if-missing keyed on `navidrome_username`), mints a heerr opaque token via existing token-mint path with scopes `[read, download]`, returns the raw token once. Updates `last_login_at`. 401 on bad creds; 503 on `NavidromeUnreachable`.
**Test gate:** new-user happy path (inserts row + mints token); existing-user happy path (no row insert, new token row, last_login bumped); bad creds → 401; Navidrome unreachable → 503.
**Done when:** all four branches green; token rows correctly FK to the user.
**Commit:** `feat(api): J6 — POST /auth/login via Navidrome IdP`

### [x] J7. `bearer_token()` dep resolves `token → user`
**Files modified:** `backend/app/api/deps.py`, `backend/tests/test_auth.py`. New helper `current_user()`.
**Deliverable:** `bearer_token()` now eager-loads the joined `User` and exposes both. `current_user()` is a thin extractor. CLI-minted tokens always resolve to `system-admin`.
**Test gate:** existing auth tests stay green; new tests assert token → user resolution; missing-FK row (shouldn't exist post-J2) raises an internal error not a silent None.
**Done when:** every endpoint that depends on `bearer_token()` can `Depends(current_user)`.
**Commit:** `feat(auth): J7 — bearer token resolves to User`

### [x] J8. Per-user scoping — `/queue`, `/status/{id}`
**Files modified:** `backend/app/api/v1/{queue,status}.py`, `backend/app/services/jobs.py` (add `user_id` filter helpers), `backend/tests/test_{queue,status}.py`.
**Deliverable:** `/queue` returns only jobs where `jobs.user_id = current_user.id`. `/status/{id}` 404s if the job belongs to a different user (no leaking that the id exists). Admin tokens (`is_admin=true`) bypass the filter.
**Test gate:** two-user seed; user-A's queue does not contain user-B's jobs; user-A `/status/{job_of_B}` → 404; admin sees both.
**Done when:** cross-user isolation verified end-to-end.
**Commit:** `feat(api): J8 — per-user filtering on /queue and /status`

### [x] J9. Per-user scoping — `/search` dedupe + `/download` idempotency
**Files modified:** `backend/app/api/v1/{search,download}.py`, `backend/app/services/jobs.py` (`create_job_idempotent` + `find_active_for_uri` take a `user_id`), `backend/tests/test_{search,download}.py`.
**Deliverable:** `/search` dedupe hints (`already_downloaded`, `active_job_id`) are computed against the requesting user's jobs only — not globally. `/download` idempotency: re-POSTing the same URI for the same user returns the existing job (`deduped: true`); a different user POSTing the same URI gets their own new job. The partial-unique-index from A2 stays as a defence in depth but is no longer the primary dedupe path.
**Test gate:** user-A downloads X → user-B `/search` for X sees `already_downloaded=false`; user-B `/download` X creates a fresh job; user-A re-downloading X gets `deduped=true`.
**Done when:** dedupe is user-scoped at the service layer.
**Commit:** `feat(api): J9 — per-user search dedupe + download idempotency`

### [x] J10. CLI updates + Admin endpoints — token ↔ user wiring
**Files modified:** `backend/app/cli.py`, `backend/app/api/v1/admin.py`, `backend/tests/test_{cli,admin}.py`.
**Deliverable:** `create-token` gains required `--user=<navidrome_username>` flag (defaults to `system-admin`); errors clearly if the user does not exist. `list-tokens` shows `user.navidrome_username` per row. New `POST /admin/users` (admin-only) lets the operator pre-create a heerr `users` row without first logging in (rarely needed; documented for ops).
**Test gate:** CLI happy + bad-user paths; admin user-create idempotent; non-admin → 403.
**Done when:** ops can mint a token for a specific user from the CLI.
**Commit:** `feat(cli+admin): J10 — token ↔ user wiring`

### [x] J11. DECISIONLOG ADR + CONTEXT.md + CHANGELOG + version bump
**Files modified:** `backend/docs/DECISIONLOG.md` (new ADR "Multi-user via Navidrome IdP — heerr backend v3.0.0"), `backend/docs/CONTEXT.md` (replace "single-user" line with multi-user / per-tailnet shape), `backend/docs/CHANGELOG.md` (J1–J10 entries), `backend/pyproject.toml` → `3.0.0`.
**Deliverable:** ADR explains why Navidrome-as-IdP, why no password column, why Tailscale-only is preserved. CONTEXT.md staleness rule satisfied. CHANGELOG bullets per milestone.
**Test gate:** none (documentation).
**Done when:** docs reflect implementation; version bumped.
**Commit:** `chore(backend): J11 — multi-user ADR + CONTEXT/CHANGELOG + v3.0.0`

### [x] J12. End-to-end multi-user smoke on the home server
**Deliverable:** Two real Navidrome accounts on the home Navidrome (`alice`, `bob`). From the backend container or a sibling, log in as each via `/auth/login`; download a different track each; assert `/queue` for alice's token excludes bob's job and vice-versa. Admin token (CLI-minted) sees both.
**Test gate:** manual; 6-step verification block recorded in `backend/docs/CHANGELOG.md`.
**Done when:** all six steps pass.
**Commit:** `chore(backend): J12 — multi-user e2e smoke verified`

---

## Phase K — YouTube Music preview stream proxy

**Architecture note:** Adds a server-side audio proxy so the Android client can **preview** (stream) a YouTube Music search result *before* committing to a full spotDL download into the Navidrome library. The backend resolves the `music.youtube.com/watch?v=<id>` URL to a direct `googlevideo` audio URL via **yt-dlp** (added to the app venv — distinct from spotDL's isolated venv), then **proxies the bytes** to the device over Tailscale with Range-request passthrough for seeking. The device plays the backend URL via just_audio.

Resolving server-side is the whole point: `googlevideo` URLs are signed to the **resolver's egress IP**, so a bare `yt-dlp -g` redirect handed to the phone would 403 from a different IP — proxying means the device IP never touches `googlevideo`, and **all device traffic stays on the tailnet** (CLAUDE.md connectivity rule). **No persistence** — previews are ephemeral; nothing is written to `/data/media/music`. Scope: `read` (non-destructive, mirrors `/search`). Because just_audio cannot attach auth headers to an `AudioSource`, the bearer token is accepted as a `?token=` query param (same shape Subsonic stream URLs already use); the request logger redacts it. Full rationale incl. the IP-binding tradeoff in the K4 ADR.

**Depends on:** nothing in Phase J; the home Navidrome is needed only for the K5 smoke. **Android Phase T consumes `/preview/stream` and must not land before K2.**

### [x] K1. yt-dlp dependency + preview resolver service
**Files:** `backend/pyproject.toml` (add `yt-dlp`), `backend/app/services/preview_resolver.py`, `backend/tests/test_preview_resolver.py`.
**Deliverable:** `async resolve_preview(source_url) -> ResolvedPreview(stream_url, headers, content_type, expires_at)`. Validates the URL is a `music.youtube.com/watch?v=<id>` (reject `browse/`/album/playlist URLs → typed `PreviewUnsupported`). Uses `YoutubeDL({'format': 'bestaudio', 'quiet': True}).extract_info(url, download=False)` under `asyncio.to_thread` — selects the best audio-only format URL + the `http_headers` yt-dlp returns (User-Agent etc.). In-memory TTL cache keyed by `videoId` (default 300 s) so repeated previews / retries don't re-resolve. Typed errors: `PreviewUnsupported`, `PreviewUnavailable` (gone / region / age-gated), `PreviewResolveError`.
**Test gate:** yt-dlp faked (monkeypatch the extract call); assert bestaudio selection, header passthrough, cache-hit avoids a second extract, each error class maps correctly. No network.
**Done when:** all branches green; `mypy app/` clean on new files.
**Commit:** `feat(preview): K1 — yt-dlp preview resolver service`

### [x] K2. Query/header bearer auth dep + `GET /preview/stream` proxy
**Files:** `backend/app/api/deps.py` (new `bearer_token_query_or_header()`), `backend/app/api/v1/preview.py`, `backend/app/api/v1/router.py` (wire), `backend/tests/test_preview.py`, `backend/tests/test_auth.py` (query-or-header dep).
**Deliverable:** `bearer_token_query_or_header()` accepts the raw token via `Authorization: Bearer …` **or** `?token=…`, then runs the same hash-lookup + `current_user` resolution + `read`-scope check as the header dep. `GET /api/v1/preview/stream?source_url=<url>&token=<raw>` calls the K1 resolver, opens `httpx.AsyncClient.stream("GET", stream_url, headers=resolver_headers + forwarded Range)`, and returns a `StreamingResponse` propagating upstream status (200/206) + `Content-Type`, `Content-Length`, `Content-Range`, `Accept-Ranges: bytes`. The client `Range` header is forwarded so ExoPlayer can seek. `PreviewUnsupported` → 422, `PreviewUnavailable` → 404, resolve/upstream failure → 502.
**Test gate:** auth via header AND via query param both 200; missing / non-`read` → 401/403; a `Range` request forwards the header and returns 206 + `Content-Range`; 422/404/502 branches; httpx faked via `MockTransport`, no network.
**Done when:** all branches green; `mypy app/` clean.
**Commit:** `feat(preview): K2 — GET /preview/stream proxy + query-param auth`

### [x] K3. Config + kill switch (Dockerfile dep & token redaction already covered)
**Files:** `backend/app/config.py` (`preview_enabled` + `preview_cache_ttl_s`), `backend/app/api/v1/preview.py` (kill-switch dep + TTL wiring), `.env.example` (root — Preview section), `backend/tests/test_config.py` + `backend/tests/test_preview.py`.
**Deliverable:** `PREVIEW_ENABLED=false` makes `/preview/stream` return 404 (operator kill switch); `PREVIEW_CACHE_TTL_S` tunes the K1 resolver cache via `get_preview_resolver`.
**Findings that reduced scope (CLAUDE.md staleness rule — corrected from the original plan):**
- **No Dockerfile change needed.** yt-dlp was added to `[tool.poetry.dependencies]` (main group) in K1, so the existing `poetry install --no-root --only main` already pulls it into `/app/.venv`. ffmpeg is already present.
- **No log-redaction code needed.** `?token=` is already unloggable: `logging_config.setup_logging` disables `uvicorn.access` (so uvicorn never logs the request line), `RequestLoggingMiddleware` logs only `scope["path"]` (no query string), and `JsonFormatter` strips `token`/`authorization`/`credentials` from any payload. Locked by the existing `test_logging.py::test_json_formatter_strips_forbidden_keys`.
**Test gate:** config defaults + env override; disabled-flag → 404 without resolving. Full suite 423 passed.
**Done when:** `poetry run pytest` green; `ruff`/`mypy` clean.
**Commit:** `feat(preview): K3 — preview kill switch + config (yt-dlp dep & token redaction already covered)`

### [x] K4. DECISIONLOG ADR + CONTEXT.md + CHANGELOG + version bump
**Files modified:** `backend/docs/DECISIONLOG.md` (new ADR "YouTube Music preview via server-side proxy — heerr backend v3.2.0"), `backend/docs/CONTEXT.md` (document the new preview surface), `backend/docs/CHANGELOG.md` (K1–K3), `backend/pyproject.toml` → `3.2.0`.
**Deliverable:** ADR explains: why proxy over a bare `-g` redirect (googlevideo egress-IP binding), why yt-dlp in the app venv vs spotDL's isolated venv, why query-param token (just_audio header limitation) + log redaction, the ephemerality guarantee (no Navidrome write), the kill switch, and the raw-token-in-URL tradeoff (consistent with Subsonic; HMAC-signed ephemeral URL noted as a future hardening).
**Test gate:** none (documentation).
**Done when:** docs reflect implementation; version bumped.
**Commit:** `chore(backend): K4 — preview ADR + CONTEXT/CHANGELOG + v3.2.0`

### [x] K5. End-to-end preview smoke on the home server
**Deliverable:** From a tailnet device against the deployed backend: `GET /preview/stream?source_url=<real ytm watch url>&token=<read token>` streams audio; a `Range: bytes=…` request returns 206; an album/`browse` URL → 422; `PREVIEW_ENABLED=false` → 404.
**Test gate:** manual; record the commands + outcomes in `backend/docs/CHANGELOG.md`.
**Done when:** all four checks pass.
**Commit:** `chore(backend): K5 — preview e2e smoke verified`

---

## Phase L — Lyrics embedding via spotDL

### [x] L1. `SPOTDL_EMBED_LYRICS` env toggle
Passes `--lyrics` to spotDL when enabled so downloaded MP3s carry embedded lyrics from spotDL's default providers (Genius, AZLyrics, etc.).

**Files:**
- `backend/app/config.py` — add `spotdl_embed_lyrics: bool = False` field to `Settings` after the `preview_*` fields. pydantic-settings maps this to `SPOTDL_EMBED_LYRICS`.
- `backend/app/services/spotdl_runner.py` — add `embed_lyrics: bool = False` keyword-only arg to `run_spotdl`. Append `"--lyrics"` to `cmd` when `embed_lyrics=True`. No other changes to the function.
- `backend/app/services/workers.py` — in `get_enqueuer()`, wrap `run_spotdl` in `functools.partial(run_spotdl, embed_lyrics=settings.spotdl_embed_lyrics)` before passing to `JobEnqueuer`. This preserves the `SpotdlRunner = Callable[[str, str], Awaitable[...]]` positional contract.
- `.env.example` (repo root) — add commented `SPOTDL_EMBED_LYRICS=false` block after the `PREVIEW_CACHE_TTL_S` section.
- `backend/tests/test_spotdl_runner.py` — add two async tests reusing the existing `monkeypatch + FakeProc` pattern:
  - `test_embed_lyrics_flag_added_when_true`: `run_spotdl(..., embed_lyrics=True)` → `"--lyrics"` in captured `cmd`.
  - `test_embed_lyrics_flag_absent_by_default`: `run_spotdl(...)` (no kwarg) → `"--lyrics"` absent.

**Test gate:** both new tests green; `poetry run pytest` full suite green; `ruff check app/ && mypy app/` clean.

**Smoke:** ✅ Passed on the home server 2026-06-24. Default-off path confirmed no `USLT` ID3 frame; with `SPOTDL_EMBED_LYRICS=true` (container recreated) a re-downloaded track carried an embedded `USLT` lyrics frame. Also re-verified the wider backend surface (health, login, search, download→done, dedupe, preview Range/206, recommend health) green.

**Commit:** `feat(backend): L1 — SPOTDL_EMBED_LYRICS toggle — embed lyrics in downloaded MP3s`

---

## Phase N — Library delete

**Architecture note:** Closes the server half of issue #41 (the Android "delete from device" half shipped in `64c8e47`). The device identifies a track by its Navidrome-relative path (Subsonic `song.path`); the backend resolves it under `music_output_dir`, deletes the file, and clears every user's `downloads` row for that file so already-downloaded dedupe resets. Delete-by-path (not by `downloads` row) is deliberate: album/playlist jobs write files with **no** `downloads` rows (`workers.py` only records song jobs), so path is the only identifier that covers the whole library. Guarded by the existing `download` scope — no new scope, no migration, no re-login. ("M" milestone numbers were already consumed by the 2026-06-18/19 DEBT band, hence N.)

### [x] N1. `DELETE /api/v1/library/song`
**Files:**
- New: `backend/app/api/v1/library.py`, `backend/app/schemas/library.py`, `backend/tests/test_library_delete.py`.
- Modified: `backend/app/api/v1/router.py` (register `library.router`).

**Deliverable:** `DELETE /api/v1/library/song` with body `{path: <subsonic-relative-path>}` → deletes the file under `music_output_dir`, removes all `downloads` rows with that `output_path`, prunes now-empty parent dirs up to (not including) the library root, returns `{deleted: true, path}`. Navidrome's watcher drops the track on its next scan.

**Validation:** 422 on absolute paths, traversal (resolved path must stay under `music_output_dir`), and non-audio suffixes (allowlist `.mp3/.m4a/.flac/.ogg/.opus/.wav` — cover art and sidecar files are untouchable). 404 when the file doesn't exist. 401/403 per the standard bearer + `require_scope("download")` deps.

**Test gate:** `backend/tests/test_library_delete.py` — auth (401/403), traversal/absolute/empty path 422s, non-audio 422, missing-file 404, happy path (file gone + both `downloads` rows for the same `output_path` gone), empty-dir pruning + non-empty-dir preservation. Full suite green.

**Smoke:** ✅ Passed on the home server 2026-07-05 (with N2 deployed): curl with a Navidrome-reported `/music/<file>` path → `{"deleted": true}`, file gone on disk; app delete works after enabling "Report Real Path" on the app's `heerr [Dart]` player records (see N2).

**Commit:** `feat(backend): N1 — DELETE /library/song — remove file from music library (#41)`

### [x] N2. Navidrome real-path handling — prefix stripping + operator requirement

**Discovery (2026-07-05 smoke):** Navidrome (post-Big-File-Refactor) reports a **virtual path** built from tags (`AlbumArtist/Album/NN - Title.ext`) in the Subsonic `path` field — for spotDL's flat file layout this never matches disk, so N1 404'd. Setting `Subsonic.DefaultReportRealPath=true` (env `ND_SUBSONIC_DEFAULTREPORTREALPATH`) makes it report real paths, but (a) it only applies to **newly created player records** — existing clients keep `reportRealPath=false` until toggled in the web UI (Settings → Players) or their player row is deleted; and (b) the real path is reported **absolute inside Navidrome's container** (e.g. `/music/<file>`).

**Files:** `backend/app/config.py` (new `navidrome_music_folder: str = "/music"`), `backend/app/api/v1/library.py` (strip the prefix before resolving; all other absolute paths still 422), `/.env.example` (documented block), `backend/tests/test_library_delete.py` (+7 tests).

**Operator requirement (home server):** `ND_SUBSONIC_DEFAULTREPORTREALPATH=true` on the navidrome container **and** "Report Real Path" enabled for the heerr app's player record. Without these, deletes 404 against virtual paths.

**Test gate:** prefixed absolute path stripped + deleted; relative path still works; absolute outside the prefix 422; traversal through the prefix (`/music/../…`) 422; bare prefix 422. Full suite green.

**Commit:** `fix(backend): N2 — strip Navidrome music-folder prefix in DELETE /library/song (#41)`

---

## Phase O — Song metadata edit (#44)

**Architecture note:** Server half of issue #44 (mis-tagged YT Music downloads). Rewrites tags (title / album / artist) and embeds per-song cover art **in place** in the file under `music_output_dir` — the file is never renamed, so `Song.path`, offline manifests, and `downloads` dedupe rows stay stable; no DB writes at all. Navidrome re-reads the file on its next scan (mtime bump from `save()`). Reuses the Phase N path plumbing (`_resolve_under_root` + `/music` prefix strip) and `require_scope("download")`. `.wav` excluded — RIFF tagging is nonstandard; spotDL's default output is `.mp3`. Single multipart `PATCH` (tags + optional cover in one request) so the client's one Save can't half-succeed across two endpoints.

### [x] O1. Tag-editor service — mutagen tag write + cover embed
**Files:**
- New: `backend/app/services/tag_editor.py`, `backend/tests/test_tag_editor.py`, `backend/tests/fixtures/silence.{mp3,m4a,flac,ogg,opus,wav}`.
- Modified: `backend/pyproject.toml` (add `mutagen ^1.47`, `python-multipart`).

**Deliverable:** `EDITABLE_SUFFIXES = {".mp3", ".m4a", ".flac", ".ogg", ".opus"}`; `sniff_image(bytes)` (magic-byte JPEG/PNG detection, never trusts declared content-type); `write_tags(path, *, title, album, artist)` via `mutagen.File(easy=True)` (only non-None fields written, returns the written field names); `embed_cover(path, data, mime)` per-format (ID3 APIC / MP4 `covr` / FLAC picture / Ogg-Vorbis+Opus base64 `metadata_block_picture`), replacing any existing cover with exactly one. Pure-sync module — endpoint callers offload via `anyio.to_thread.run_sync`. Fixtures are ~0.1 s ffmpeg-generated silence per format (`ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 0.1 …`; ogg needs `cl=stereo` + `-c:a vorbis -strict experimental` — the builtin encoder is stereo-only).

**Test gate:** per-format tag round-trip; partial write leaves other fields untouched; per-format cover round-trip + replace-leaves-exactly-one + tags preserved across embed; `sniff_image` accepts jpeg/png, rejects gif/webp/garbage/truncated-magic. Full suite green; ruff + mypy clean.

**Commit:** `feat(backend): O1 — tag-editor service — mutagen tag write + cover embed (#44)`

### [x] O2. `PATCH /api/v1/library/song` — edit tags + upload cover
**Files:**
- New: `backend/tests/test_library_edit.py`.
- Modified: `backend/app/api/v1/library.py` (PATCH handler; extract shared prefix-strip helper), `backend/app/schemas/library.py` (`LibraryEditResponse`), `backend/pyproject.toml` + `backend/app/main.py` → `3.3.0`.

**Deliverable:** Multipart `PATCH /api/v1/library/song` — `path` + optional `title`/`album`/`artist` as form fields, optional `cover` file; `require_scope("download")`. Flow: Navidrome prefix strip → `_resolve_under_root` → suffix ∈ `EDITABLE_SUFFIXES` (422, explicit `.wav` detail) → 404 missing → 422 when no field and no cover → cover ≤ 5 MB + `sniff_image` (422 on bad type) → thread-offloaded `write_tags` / `embed_cover` → `{updated: true, path, fields}`. Logged with the `username` key.

**Test gate:** 401/403; parametrized 422s (traversal, absolute-outside-prefix, empty path, `.wav`, non-audio suffix, no-fields, bad image bytes, oversize cover); 404 missing file; multipart happy path per format asserting tags via mutagen re-read **and file path unchanged on disk**; Navidrome-prefixed path works; tags-only and cover-only requests work independently. Full suite green; ruff + mypy clean.

**Smoke (home server):** curl multipart against a real track → tags + cover visible in Navidrome after rescan; file path unchanged; dedupe row untouched.

**Commit:** `feat(backend): O2 — PATCH /library/song — edit tags + upload cover art (#44)`

---

## Cross-cutting reminders

- **`.env` never committed.** Only `.env.example`.
- **Logging at every request:** include the authenticated user's `navidrome_username` (log key: `username`); never log raw tokens or hashes.
- **DECISIONLOG drift:** any contract/schema change → append a new ADR to `DECISIONLOG.md` and update `CONTEXT.md` in the same commit (CLAUDE.md staleness rule).
- **Green-before, green-after:** run `poetry run pytest` before starting each milestone and before declaring done.

---

## Out of scope for this roadmap

- Flutter client (see `android/docs/ROADMAP_RECOMMEND.md`).
- Vault migration for credentials.
- Progress percentage parsing.
- Library-cache use of pgvector.

---

## Roadmap complete when

1. All milestone boxes checked (A1–H1, I1–I5, J1–J12, K1–K5, L1, N1).
2. Every test gate green at its milestone.
3. H1 smoke succeeds against the real home stack.
4. J12 multi-user smoke succeeds against the real home stack.
5. CHANGELOG entries exist for each milestone group.
6. `git log --oneline backend/` reads as a clean A→H→I→J→K progression.
