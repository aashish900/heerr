# ROADMAP.md — heerr Backend Implementation Milestones

Track progress through the backend build. Each milestone = one git commit with a green test gate (where applicable). Tick the box when committed.

See `PLAN.md` and `DECISIONLOG.md` 2026-06-08 entries for the *what*; this file is the *how* / *when*.

**Status (2026-06-09):** Phases A–G complete (16/17 milestones, A1 through G2). **H1 pending** — requires running the deployed stack on the home server; deferred until next on-site session.

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
**Test gate:** manual; the 8 verification steps in project `PLAN.md`.
**Done when:** Step 5 (file under `/data/media/music/...`) + step 6 (Navidrome lists it) both confirmed.
**Commit:** `chore: e2e smoke verified` (optional — only if recording output).
**Status (2026-06-09):** Cannot run from current location. All prior milestones (A1–G2) merged on `main`; CI Docker Hub workflow live. Run after deploying the image / compose snippet onto the arr-stack host.

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

### [ ] I3. Last.fm engine
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

### [ ] I4. Fallback chain + engine health endpoint
**Files:** `backend/app/services/recommenders/factory.py` (updated); `backend/app/services/recommenders/fallback_engine.py`; `backend/app/api/v1/recommend.py` (add health route).
**Deliverable:**
- `FallbackEngine` wrapper: tries engines left-to-right; on any exception falls back to the next; logs at `WARNING` with engine name + error.
- Factory: `RECOMMENDATION_ENGINE=lastfm,ytmusic` instantiates `FallbackEngine([LastFMEngine, YTMusicEngine])`.
- `GET /api/v1/recommend/health` (scope: `read`): returns `{"engine": "<name>", "status": "ok" | "degraded", "fallback_active": bool}`. Calls a lightweight probe on each engine (Last.fm: one cheap API call; ytmusicapi: no network needed).
**Test gate:** `FallbackEngine` falls back when first engine raises; second engine result returned; health returns `degraded` + `fallback_active: true` when primary fails probe; health returns `ok` when all engines healthy.
**Done when:** All branches green.
**Commit:** `feat(backend): I4 — fallback chain + GET /recommend/health`

### [ ] I5. ListenBrainz engine
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

## Cross-cutting reminders

- **`.env` never committed.** Only `.env.example`.
- **Logging at every request:** include `token.owner_label`; never log raw tokens or hashes.
- **DECISIONLOG drift:** any contract/schema change → update `DECISIONLOG.md` + `PLAN.md` in the same commit (CLAUDE.md staleness rule).
- **Green-before, green-after:** run `poetry run pytest` before starting each milestone and before declaring done.

---

## Out of scope for this roadmap

- Flutter client (see `android/docs/ROADMAP_RECOMMEND.md`).
- Vault migration for credentials.
- Progress percentage parsing.
- Library-cache use of pgvector.

---

## Roadmap complete when

1. All milestone boxes checked (A1–H1, I1–I5).
2. Every test gate green at its milestone.
3. H1 smoke succeeds against the real home stack.
4. CHANGELOG entries exist for each milestone group.
5. `git log --oneline backend/` reads as a clean A→H→I progression.
