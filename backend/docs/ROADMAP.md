# ROADMAP.md — heerr Backend Implementation Milestones

Track progress through the backend build. Each milestone = one git commit with a green test gate (where applicable). Tick the box when committed.

See `PLAN.md` and `DECISIONLOG.md` 2026-06-08 entries for the *what*; this file is the *how* / *when*.

**Conventions:**
- TDD per CLAUDE.md §2 — tests written first, land in same commit as code.
- Out-of-TDD-scope (CLAUDE.md §2): scaffold, migrations, Dockerfile, compose, smoke. These have other verification gates noted per-milestone.
- Commit messages: Conventional Commits (`feat(scope): …`, `chore: …`, `infra: …`).
- One milestone = one commit. Follow-up cleanup within a milestone = separate commit under the same milestone.

---

## Phase A — Foundation

### [ ] A1. Scaffold: Poetry + Alembic skeleton
**Files:** `backend/pyproject.toml`, `backend/alembic.ini`, `backend/alembic/env.py`, `backend/alembic/script.py.mako`, `backend/alembic/versions/`
**Deliverable:** `cd backend && poetry install` succeeds; `poetry run alembic current` runs.
**Test gate:** none (out of TDD scope).
**Done when:** `poetry install` + `alembic current` both exit 0.
**Commit:** `chore(backend): scaffold poetry + alembic skeleton`

### [ ] A2. Migration 0001 — schema v1
**Files:** `backend/alembic/versions/0001_init.py`, `backend/tests/__init__.py`, `backend/tests/conftest.py`, `backend/tests/test_migration_0001.py`
**Deliverable:** Schema enforced at DB level (tokens, jobs, downloads + partial unique index + CHECK constraints + pgcrypto/vector extensions).
**Test gate:** migration round-trip + constraint violations asserted; `pytest backend/tests/test_migration_0001.py` green.
**Done when:** Partial-unique-index invariant ("no duplicate active job") proven by a test that catches the unique-violation.
**Commit:** `feat(db): schema v1 — tokens, jobs, downloads`

### [ ] A3. SQLAlchemy ORM models
**Files:** `backend/app/__init__.py`, `backend/app/models/{__init__,base,token,job,download}.py`, `backend/tests/test_models_match_schema.py`
**Deliverable:** ORM mirrors schema; drift caught by Alembic `compare_metadata`.
**Test gate:** model/schema diff returns no differences.
**Done when:** `compare_metadata` clean against the migrated container.
**Commit:** `feat(models): sqlalchemy orm for tokens, jobs, downloads`

---

## Phase B — Plumbing

### [ ] B1. App config + async DB session
**Files:** `backend/app/config.py`, `backend/app/db.py`, `backend/tests/test_config.py`, `backend/tests/test_db_session.py`
**Deliverable:** `pydantic-settings`-based config (DATABASE_URL, SPOTIFY_*, MUSIC_OUTPUT_DIR); async engine + session dependency.
**Test gate:** config env-load + required-field errors; session round-trips `SELECT 1`.
**Done when:** Session yields/commits/closes cleanly against the testcontainer.
**Commit:** `feat: app config + async db session`

### [ ] B2. Auth dependency
**Files:** `backend/app/api/__init__.py`, `backend/app/api/deps.py`, `backend/tests/test_auth.py`
**Deliverable:** `bearer_token()`, `require_scope(...)`, `require_admin()` FastAPI dependencies.
**Test gate:** table-driven coverage of every branch (missing/invalid/revoked/wrong-scope/admin-required).
**Done when:** All auth state-machine branches green.
**Commit:** `feat(auth): bearer token dependency + scope checks`

### [ ] B3. Token CLI
**Files:** `backend/app/cli.py`, `backend/tests/test_cli.py`; add `typer` to deps.
**Deliverable:** `python -m app.cli create-token | list-tokens | revoke-token` — raw token printed once; hash persisted.
**Test gate:** Typer `CliRunner` against test DB.
**Done when:** `poetry run python -m app.cli create-token --owner=test --scopes=read,download` prints a token, row in DB.
**Commit:** `feat(cli): token management commands`

---

## Phase C — Read path

### [ ] C1. FastAPI app skeleton + `/health`
**Files:** `backend/app/main.py`, `backend/app/api/v1/{__init__,router,health}.py`, `backend/tests/test_health.py`; add `fastapi`, `uvicorn[standard]` to deps.
**Deliverable:** Boot-able FastAPI app, `/api/v1` mounted, `/health` returns `{"status":"ok"}` (no auth).
**Test gate:** httpx `ASGITransport` test → 200.
**Done when:** `poetry run uvicorn app.main:app` boots; `curl localhost:8000/api/v1/health` returns 200.
**Commit:** `feat(api): app skeleton + GET /health`

### [ ] C2. Spotify client-credentials service
**Files:** `backend/app/services/{__init__,spotify}.py`, `backend/tests/test_spotify_service.py`; add `spotipy` to deps.
**Deliverable:** `services.spotify` exposes `search_tracks/albums/playlists` returning typed results. Token caching handled by spotipy.
**Test gate:** HTTP stubbed via `respx`/`httpx.MockTransport`; no network in tests.
**Done when:** All three search types return typed results in tests.
**Commit:** `feat(spotify): client-credentials search wrapper`

### [ ] C3. `POST /search`
**Files:** `backend/app/schemas/{__init__,search}.py`, `backend/app/api/v1/search.py`, `backend/tests/test_search.py`
**Deliverable:** Contract-shaped `POST /search` with `read` scope; `already_downloaded` + `active_job_id` hydrated from DB.
**Test gate:** auth/scope failures; mocked Spotify; dedup hints correct against seeded DB rows.
**Done when:** All contract fields populated correctly for track/album/playlist queries.
**Commit:** `feat(search): POST /search with dedup hints`

---

## Phase D — Write path

### [ ] D1. Job state machine service
**Files:** `backend/app/services/jobs.py`, `backend/tests/test_jobs_service.py`
**Deliverable:** Pure async functions — `create_job_idempotent`, `mark_running/done/failed`, `bump_attempt`, `find_active_for_uri`, `find_download_for_track`.
**Test gate:** every transition + concurrency test proves the partial-unique-index catches duplicate creates.
**Done when:** Idempotency + all state transitions covered.
**Commit:** `feat(jobs): state machine service`

### [ ] D2. `POST /download`
**Files:** `backend/app/schemas/download.py`, `backend/app/api/v1/download.py`, `backend/tests/test_download.py`
**Deliverable:** Idempotent dispatch; worker stub (sleep then mark done — real spotDL in F2); URI prefix dispatch.
**Test gate:** new-URI / active-dedupe / on-disk-dedupe / scope=read→403 / bad URI→422.
**Done when:** Every idempotency branch tested.
**Commit:** `feat(download): POST /download with idempotent dispatch`

### [ ] D3. `GET /status/{job_id}` + `GET /queue`
**Files:** `backend/app/schemas/job.py`, `backend/app/api/v1/{status,queue}.py`, `backend/tests/test_status.py`, `backend/tests/test_queue.py`
**Deliverable:** Status read + queue (active + recent 20).
**Test gate:** shape/ordering/404/auth covered.
**Done when:** Contract fields match exactly.
**Commit:** `feat(jobs): GET /status/{id} + GET /queue`

---

## Phase E — Admin

### [ ] E1. Admin endpoints
**Files:** `backend/app/schemas/token.py`, `backend/app/api/v1/admin.py`, `backend/tests/test_admin.py`
**Deliverable:** `POST/GET /admin/tokens`, `POST /admin/tokens/{id}/revoke`, `POST /admin/jobs/{id}/retry`. Retry only allowed on `failed`; bumps `attempt_count`; resets to `queued`.
**Test gate:** CRUD round-trip, raw token only in create response, retry 409 on non-failed, non-admin → 403.
**Done when:** Full admin surface exercised.
**Commit:** `feat(admin): token management + job retry`

---

## Phase F — Real worker

### [ ] F1. spotDL subprocess wrapper
**Files:** `backend/app/services/spotdl_runner.py`, `backend/tests/test_spotdl_runner.py`
**Deliverable:** `async run_spotdl(uri, output_dir) -> list[DownloadedFile]` via `asyncio.create_subprocess_exec`; typed `SpotdlError`.
**Test gate:** `create_subprocess_exec` faked; happy + non-zero-exit paths.
**Done when:** Both paths tested without invoking real spotDL.
**Commit:** `feat(spotdl): subprocess runner`

### [ ] F2. Worker integration
**Files modified:** `backend/app/services/jobs.py`, `backend/app/api/v1/download.py`; new `backend/tests/test_worker.py`
**Deliverable:** `run_job(job_id)` loads job → mark running → invoke spotDL → write `downloads` rows → mark done; on exception → mark failed.
**Test gate:** happy path (downloads row written, state done) + failure path (state failed, error_msg set, no download row).
**Done when:** Faked-spotDL e2e succeeds in tests.
**Commit:** `feat(worker): integrate spotDL runner with /download`

---

## Phase G — Ship it

### [ ] G1. Backend Dockerfile
**Files:** `backend/Dockerfile`, `backend/.dockerignore`
**Deliverable:** Multi-stage build; runtime = `python:3.13-slim` + `ffmpeg` + `spotdl` pinned + venv. Runs as non-root. CMD = uvicorn.
**Test gate:** none.
**Done when:** `docker build -t music-search-backend backend/` succeeds; `docker run --rm music-search-backend python -m app.cli --help` works.
**Commit:** `infra(backend): dockerfile`

### [ ] G2. docker-compose snippet + `.env.example`
**Files:** `docker-compose.snippet.yml`, `.env.example`, README/CONTEXT update.
**Deliverable:** Compose stack — `backend`, `postgres` (pgvector/pg17), `postgres-init` (chown). Healthchecks + dependency order. On existing `172.39.0.0/24` arr-stack network as external. No manual host steps.
**Test gate:** none.
**Done when:** `docker compose up` from a copy with real `.env` starts all three services; Alembic auto-applies; `/health` returns 200 from a sibling container.
**Commit:** `infra: compose snippet for arr-stack integration`

---

## Phase H — End-to-end smoke

### [ ] H1. Smoke on the home server
**Files:** optional `docs/smoke.md` capturing commands + output.
**Deliverable:** Real Navidrome lists a track downloaded via the API.
**Test gate:** manual; the 8 verification steps in project `PLAN.md`.
**Done when:** Step 5 (file under `/data/media/music/...`) + step 6 (Navidrome lists it) both confirmed.
**Commit:** `chore: e2e smoke verified` (optional — only if recording output).

---

## Cross-cutting reminders

- **`.env` never committed.** Only `.env.example`.
- **Logging at every request:** include `token.owner_label`; never log raw tokens or hashes.
- **DECISIONLOG drift:** any contract/schema change → update `DECISIONLOG.md` + `PLAN.md` in the same commit (CLAUDE.md staleness rule).
- **Green-before, green-after:** run `poetry run pytest` before starting each milestone and before declaring done.

---

## Out of scope for this roadmap

- Flutter client (separate roadmap once H1 is green).
- Vault migration for credentials.
- Progress percentage parsing.
- Library-cache use of pgvector.

---

## Roadmap complete when

1. All 17 milestone boxes checked (A1–H1).
2. Every test gate green at its milestone.
3. H1 smoke succeeds against the real home stack.
4. CHANGELOG entries exist for each milestone group.
5. `git log --oneline backend/` reads as a clean A→H progression.
