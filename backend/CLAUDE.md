# CLAUDE.md — backend

Backend-specific Claude rules. **Project-wide rules live in `/CLAUDE.md` at repo root** — read that first.

---

## Bootstrap (when working on the backend)

In order:
1. `/CLAUDE.md` (project-wide rules)
2. `backend/CLAUDE.md` (this file — backend hard rules)
3. `backend/docs/CONTEXT.md` (server env, architecture, hard learnings)
4. `backend/docs/DECISIONLOG.md` (ADRs — newest at the bottom)
5. `backend/docs/CHANGELOG.md` (per-task history)

For operational lookup: `backend/README.md`.
For the locked v1 contract: `backend/docs/PLAN.md`.
For the build sequence: `backend/docs/ROADMAP.md`.

---

## Architecture (do not re-litigate)

- FastAPI service in Docker, joins the existing arr-stack at `~/docker/arr-stack/docker-compose.yml` (Docker subnet `172.39.0.0/24`).
- Writes downloads to `/data/media/music` — Navidrome watches the dir and indexes new files within ~1 min.
- Flutter (future) is a **thin client**: no download logic, no spotDL, no Spotify SDK on the device.
- Postgres lives in the same arr-stack (shared instance, dedicated DB `music_request` + role `music_request_app`). See `docs/DECISIONLOG.md` 2026-06-08 "Persistence: Postgres".

---

## Search: YouTube Music (not Spotify)

- Search is via `ytmusicapi` (unofficial YouTube Music API, no credentials required). `app/services/ytmusic.py`.
- `POST /search` accepts `type: song | album | playlist`. Returns `source_url` (YouTube Music URL) + `source_type`.
- Songs return `music.youtube.com/watch?v=<videoId>`; albums/playlists return `music.youtube.com/browse/<browseId>`.
- No Spotify credentials anywhere in heerr. The old `SPOTIFY_CLIENT_ID`/`SECRET` env vars are ignored (`extra="ignore"` in Settings).
- Do NOT propose re-adding Spotify search — the switch to YouTube Music was made specifically to fix regional song mismatches (see DECISIONLOG 2026-06-10).

---

## Job processing

- **No Redis / Celery / RabbitMQ to start.** Use FastAPI `BackgroundTasks` for the worker; persist jobs in **Postgres** with the partial-unique-index dedupe pattern (see `docs/DECISIONLOG.md` 2026-06-08 "Schema v1"). Suggest a real queue only with evidence the current setup is outgrown.
- **spotDL runs server-side only.** Phone-side spotDL has been ruled out (iOS broken; Termux broken on `libpthread.so.0` / tls-client). Don't revisit.
- spotDL invocation: **subprocess, not library import.** Process isolation + cancellability + no version-coupling to spotDL's churning internal API (see `docs/DECISIONLOG.md` 2026-06-08 "Implementation strategy" and 2026-06-08 "spotdl install isolated").
- Worker drives jobs through `queued → running → done | failed` via `app/services/workers.py::run_job`.

---

## Development workflow

- **TDD by default.** Write the failing test, then the implementation. No production logic merges without a test that exercises it first.
  - **Scope:** FastAPI app code — endpoints, services, models, CLI.
  - **Out of scope:** `docker-compose.yml`, `Dockerfile`, Alembic migrations, Flutter UI. These have their own verification gates: `docker compose up` clean, `alembic upgrade head` clean, manual smoke.
- **Green before, green after.** Run the test suite (`poetry run pytest`) before starting a task and confirm it's passing. Run it again before declaring done. If tests were red before you started, fix or quarantine them first — don't pile changes onto a broken baseline.
- Real Postgres in tests via `testcontainers-postgres` (no SQLite mocks). YouTube Music mocked at the service boundary via FastAPI `dependency_overrides[get_ytmusic_client]` (see `tests/test_search.py`). spotDL mocked at the subprocess boundary via `monkeypatch.setattr` on `_spawn`.
- Commit per ROADMAP milestone with the Conventional Commits message prescribed by `docs/ROADMAP.md`.
