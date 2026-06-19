# heerr-backend

[![backend CI](https://github.com/aashish900/heerr/actions/workflows/backend-ci.yml/badge.svg)](https://github.com/aashish900/heerr/actions/workflows/backend-ci.yml)
[![Docker publish](https://github.com/aashish900/heerr/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/aashish900/heerr/actions/workflows/docker-publish.yml)
[![Docker Image Version](https://img.shields.io/docker/v/aashish010/heerr-backend?sort=semver&label=docker%20hub)](https://hub.docker.com/r/aashish010/heerr-backend/tags)

FastAPI service that wraps **spotDL** to download songs found via YouTube Music into a music library that **Navidrome** indexes. Single-user by default; per-user opaque tokens with scopes make sharing possible later. Runs in Docker against a shared Postgres in the existing arr-stack. See `docs/CONTEXT.md` for the why.

---

## Table of contents

1. [Quick start (local dev)](#quick-start-local-dev)
2. [Environment variables](#environment-variables)
3. [CLI — `python -m app.cli`](#cli--python--m-appcli)
4. [API reference](#api-reference)
5. [Testing](#testing)
6. [Project layout](#project-layout)
7. [Deployment to the arr-stack](#deployment-to-the-arr-stack)
8. [Further reading](#further-reading)

---

## Quick start (local dev)

### Prerequisites

| Tool | Version | Why |
|---|---|---|
| Python | 3.13.x | runtime |
| Poetry | 2.4.x | dep + venv manager (install via `pipx install poetry`) |
| Docker | any 24+ | needed for the integration tests (`testcontainers-postgres`) and for the prod Dockerfile |
| ffmpeg | any recent | spotDL/yt-dlp uses it for muxing |
| spotdl | 4.5.x | only required for **real** downloads (smoke + H1). Tests fake it. Install via a separate venv: `python3 -m venv ~/.local/spotdl-venv && ~/.local/spotdl-venv/bin/pip install spotdl==4.5.0` and put the binary on `PATH` (or set `SPOTDL_EXECUTABLE`). See `docs/DECISIONLOG.md` 2026-06-08 "spotdl install isolated" for the rationale. |

### Setup

```bash
# from repo root
cd backend
poetry install              # creates an in-project .venv, installs runtime + dev deps
```

### Configure a `.env`

The app reads two env vars at startup. The cleanest path is to start from the template at the repo root:

```bash
cp ../.env.example ../.env  # repo root
# edit ../.env  → fill in POSTGRES_PASSWORD and DATABASE_URL for your local Postgres
```

For local dev outside Docker, `DATABASE_URL` is typically `postgresql+asyncpg://<user>:<pw>@127.0.0.1:5432/<db>` against a local Postgres you run yourself (`docker run -p 5432:5432 -e POSTGRES_PASSWORD=… pgvector/pgvector:pg17`). `MUSIC_OUTPUT_DIR` can be any writable path while developing (e.g. `./tmp-music`).

### Apply migrations

```bash
poetry run alembic upgrade head
```

### Run the API server

```bash
poetry run uvicorn app.main:app --reload --port 8000
# OpenAPI docs at:    http://localhost:8000/api/v1/docs
# OpenAPI JSON at:    http://localhost:8000/api/v1/openapi.json
# Health probe:       curl http://localhost:8000/api/v1/health
```

### Mint your first admin token

```bash
poetry run python -m app.cli create-token \
    --scopes=read,download \
    --admin
# prints the raw token ONCE — save it somewhere. The DB stores only sha256(raw).
```

Use that token in the `Authorization: Bearer <raw>` header on every request.

---

## Environment variables

Source: `app/config.py`.

| Var | Required | Example | Purpose |
|---|:-:|---|---|
| `DATABASE_URL` | ✓ | `postgresql+asyncpg://music_request_app:…@postgres:5432/music_request` | SQLAlchemy async URL. Driver must be `asyncpg`. |
| `MUSIC_OUTPUT_DIR` | ✓ | `/data/media/music` | where spotDL writes; Navidrome indexes this dir |
| `SPOTDL_EXECUTABLE` | optional | `/opt/spotdl-venv/bin/spotdl` | overrides the spotdl binary path (default `"spotdl"` — looked up on `PATH`) |

In the Docker image, `SPOTDL_EXECUTABLE` defaults to `/opt/spotdl-venv/bin/spotdl` (set by the Dockerfile).

No Spotify credentials required. Search is powered by `ytmusicapi` (unofficial YouTube Music API, no credentials).

---

## CLI — `python -m app.cli`

Source: `app/cli.py` (Typer-based). All commands read `DATABASE_URL` from env.

### `create-token`

Generate a token. Raw value is printed once on stdout; only its `sha256` is persisted.

```bash
python -m app.cli create-token \
    --scopes=read,download \
    --admin
```

Flags:
- `--user <navidrome_username>` — owning user. Defaults to `system-admin` (the operator account seeded by migration 0005). Must already exist.
- `--scopes <csv>` — comma-separated subset of `{read, download}`. Default `read,download`.
- `--admin` — flag. Sets `is_admin=true`, which gates `/admin/*`.

Exit codes: `0` on success; `1` if DB CHECK rejects (e.g. invalid scope name).

### `list-tokens`

```bash
python -m app.cli list-tokens
# 7f1d… user=system-admin scopes=['read', 'download'] admin=True state=active created_at=2026-06-08T17:42:09+00:00
```

Never prints the raw token or its hash.

### `revoke-token`

```bash
python -m app.cli revoke-token <uuid>
# revoked
```

Exit codes:
- `0` — revoked
- `1` — unknown id, or already revoked
- `2` — `<uuid>` is not a valid UUID

A revoked token immediately fails `bearer_token()` (returns 401) on every subsequent request — there's no token cache.

---

## API reference

All endpoints live under `/api/v1`. JSON in/out. UUIDv4 ids. ISO-8601 UTC timestamps.

The summary below is enough to drive the client; consult `docs/DECISIONLOG.md` for the locked decisions and `/api/v1/openapi.json` for the source-of-truth schema.

### Request ID & access log

Every response carries an `X-Request-ID` header. If the client supplies one
on the request, the server echoes it; otherwise the server generates a
UUIDv4 hex. The same id is included in the structured JSON access-log line
the server emits for that request:

```
{"ts":"…","level":"INFO","logger":"heerr.access","msg":"request",
 "request_id":"…","username":"aashish","method":"POST",
 "path":"/api/v1/download","status_code":202,"duration_ms":12.34,"client":"…"}
```

`username` is `users.navidrome_username` for the authenticated request's
token, or `"-"` for `/health` (no auth) and 401 responses (auth failed
before the dependency could resolve a token).

### Authentication

Every endpoint **except `GET /health`** requires `Authorization: Bearer <raw-token>`. Failure modes:

| Condition | Status | Header |
|---|---|---|
| missing header | 401 | `WWW-Authenticate: Bearer` |
| wrong scheme (e.g. `Basic …`) | 401 | `WWW-Authenticate: Bearer` |
| unknown token (no row matches `sha256`) | 401 | `WWW-Authenticate: Bearer` |
| revoked token (`tokens.revoked_at IS NOT NULL`) | 401 | `WWW-Authenticate: Bearer` |
| token lacks the route's required scope | 403 | — |
| route is admin-only and `tok.is_admin = false` | 403 | — |

### Endpoints

#### `GET /api/v1/health`

```bash
curl http://localhost:8000/api/v1/health
# {"status":"ok"}
```

No auth.

#### `POST /api/v1/search` (scope: `read`)

```bash
curl -X POST http://localhost:8000/api/v1/search \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query": "blinding lights", "type": "song", "limit": 10}'
```

Request schema (`app/schemas/search.py`):
```json
{
  "query": "blinding lights",
  "type": "song",        // strict: "song" | "album" | "playlist"
  "limit": 20            // 1..50, default 20
}
```
Unknown fields → `422`. `extra="forbid"`.

Response 200:
```json
{
  "results": [
    {
      "source_url":         "https://music.youtube.com/watch?v=0VjIjW4GlU",
      "source_type":        "song",
      "title":              "Blinding Lights",
      "artist":             "The Weeknd",
      "album":              "After Hours",     // null for albums/playlists
      "duration_ms":        200040,            // null for albums/playlists
      "cover_url":          "https://lh3.googleusercontent.com/…",
      "already_downloaded": true,              // hint from DB; song-level only
      "active_job_id":      null               // populated when a queued/running job exists for this URL
    }
  ]
}
```

YouTube Music errors → backend returns `502`.

#### `POST /api/v1/download` (scope: `download`)

```bash
curl -X POST http://localhost:8000/api/v1/download \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"source_url": "https://music.youtube.com/watch?v=0VjIjW4GlU", "source_type": "song"}'
```

Request:
```json
{
  "source_url":  "https://music.youtube.com/watch?v=0VjIjW4GlU",
  "source_type": "song"
}
```
`source_url` must start with `https://music.youtube.com/watch?v=` (song) or `https://music.youtube.com/browse/` (album/playlist). Bad URLs → `422`.

Response 202 — three idempotency outcomes:

| Outcome | `state` | `deduped` | When |
|---|---|:-:|---|
| New job enqueued | `"queued"` | `false` | first-ever request for this URL |
| Active duplicate | `"queued"` *(unchanged)* | `true` | another `queued`/`running` job exists for the same URL |
| Already on disk *(song only)* | `"done"` | `true` | a `downloads` row exists for this `source_url` |

```json
{ "job_id": "f3a…", "state": "queued", "deduped": false }
```

#### `GET /api/v1/status/{job_id}` (scope: `read`)

```bash
curl http://localhost:8000/api/v1/status/<job_id> \
  -H "Authorization: Bearer $TOKEN"
```

Response 200:
```json
{
  "job_id":      "f3a…",
  "source_url":  "https://music.youtube.com/watch?v=0VjIjW…",
  "source_type": "song",
  "state":       "running",   // queued | running | done | failed
  "progress":    null,         // v1: always null
  "error":       null,         // populated when state="failed"
  "output_path": null,         // populated when state="done" AND source_type="song"
  "created_at":  "2026-06-08T17:42:01Z",
  "started_at":  "2026-06-08T17:42:03Z",
  "finished_at": null
}
```

404 on unknown id; 422 on non-UUID path arg.

**Album/playlist jobs**: `output_path` is always `null`. Files exist on disk (Navidrome will see them) but the `downloads` table only tracks per-song jobs. See `docs/DECISIONLOG.md` 2026-06-08 "downloads rows: track jobs only in v1".

#### `GET /api/v1/queue` (scope: `read`)

```bash
curl http://localhost:8000/api/v1/queue \
  -H "Authorization: Bearer $TOKEN"
```

```json
{
  "active": [ { "job_id": "…", "state": "queued", "created_at": "…", … } ],
  "recent": [ { "job_id": "…", "state": "done",   "finished_at": "…", … } ]
}
```

- `active`: every job where `state IN ('queued','running')`, oldest-first by `created_at`.
- `recent`: last 20 jobs where `state IN ('done','failed')`, newest-first by `finished_at`.

No query params in v1.

#### `GET` / `PATCH /api/v1/settings` (any valid token)

Per-user recommendation config (DEBT M5). Each token manages **its own** user's
settings; there is no cross-user access. Operator-global config
(`RECOMMENDATION_ENGINE`, `LASTFM_API_KEY`) is not exposed here — it stays in `.env`.

```bash
# read
curl http://localhost:8000/api/v1/settings -H "Authorization: Bearer $TOKEN"
# → { "lastfm_username": null, "listenbrainz_token_set": false }

# set (partial — only the keys you send are changed)
curl -X PATCH http://localhost:8000/api/v1/settings \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"lastfm_username":"alice","listenbrainz_token":"lb-xxxx"}'
# → { "lastfm_username": "alice", "listenbrainz_token_set": true }

# clear a key — send explicit null
curl -X PATCH http://localhost:8000/api/v1/settings \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"lastfm_username":null}'
```

- Managed keys: `lastfm_username`, `listenbrainz_token`. The per-user value
  overrides the matching global env var (`LASTFM_USERNAME` / `LISTENBRAINZ_USER_TOKEN`);
  the env var is the fallback when a user has set nothing.
- The ListenBrainz token is a **secret** — never echoed back. The read shape
  surfaces only `listenbrainz_token_set: bool`.
- `extra` fields → `422`.

#### Admin endpoints (require `is_admin=true`)

| Method | Path | Body / args | Returns |
|---|---|---|---|
| `POST` | `/api/v1/admin/tokens` | `{scopes, navidrome_username, is_admin?}` | `201` with `raw_token` (shown once) |
| `GET` | `/api/v1/admin/tokens` | — | `200` array of `TokenView` (no raw, no hash) |
| `POST` | `/api/v1/admin/tokens/{id}/revoke` | — | `204` (or `404` / `409` already-revoked) |
| `POST` | `/api/v1/admin/jobs/{id}/retry` | — | `200` `JobView`; `404` unknown; `409` if `state != "failed"` OR another active job for the same URI exists |

Examples:

```bash
# create a non-admin user (the user must already exist — pre-create it with
# POST /api/v1/admin/users if needed)
curl -X POST http://localhost:8000/api/v1/admin/tokens \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"navidrome_username":"sister","scopes":["read","download"],"is_admin":false}'
# → 201 { "id":"…", "raw_token":"…", "navidrome_username":"sister", … }

# retry a failed job
curl -X POST http://localhost:8000/api/v1/admin/jobs/<job_id>/retry \
  -H "Authorization: Bearer $ADMIN_TOKEN"
# → 200 JobView (state reset to "queued", attempt_count++)
```

### Error format

FastAPI default `{"detail": "…"}` for now. A structured `{"error","code"}` envelope is deferred until there's a UI consumer that needs machine-readable codes.

---

## Testing & lint

```bash
poetry run pytest                       # full suite (~7s on Apple Silicon)
poetry run pytest tests/test_auth.py -v # one file
poetry run pytest -k "scope and admin"  # by name

poetry run ruff check .                 # lint
poetry run ruff format .                # auto-format (or `--check` for CI dry-run)
poetry run mypy app/                    # type-check (excludes tests/, alembic/versions/)
```

Lint + type-check configs live in `pyproject.toml` (`[tool.ruff]`, `[tool.mypy]`).
The same four gates (ruff lint, ruff format, `mypy app/`, `pytest`) run in
CI on every PR via [`.github/workflows/backend-ci.yml`](../.github/workflows/backend-ci.yml)
— keep them green locally before pushing.

### Pre-commit hook (one-time per clone)

Ruff lint + format is wired through [pre-commit](https://pre-commit.com).
Install once and `git commit` will auto-fix formatting before the commit
lands, so you never push a ruff-format failure:

```bash
pipx install pre-commit       # or `pip install --user pre-commit`
pre-commit install            # writes .git/hooks/pre-commit
pre-commit run --all-files    # one-time sweep over the whole tree
```

The hook config is at `../.pre-commit-config.yaml` (repo root). Ruff is
pinned there to match `poetry.lock` exactly — if you bump ruff in
`pyproject.toml`, bump `rev:` there in the same commit. CI runs the same
hooks read-only, so a `--no-verify` commit still gets caught at PR time.

**Architecture:**
- Real Postgres via [`testcontainers-postgres`](https://testcontainers-python.readthedocs.io/) — session-scoped `pgvector/pgvector:pg17` container; the image is cached locally after the first run (~1.9s spin-up).
- YouTube Music is faked at the service boundary via FastAPI `dependency_overrides[get_ytmusic_client]` (see `tests/test_search.py::FakeYTMusic`).
- spotDL is faked at the subprocess boundary via `monkeypatch.setattr("app.services.spotdl_runner._spawn", …)` (see `tests/test_spotdl_runner.py`). No real spotDL or network needed for tests.
- Job worker tested directly through `run_job(...)` with an injected `runner`/`sm` — no FastAPI test-app machinery needed.

**Docker dependency:** the test suite needs a live Docker daemon (for testcontainers). On macOS with colima: `colima start`.

---

## Project layout

```
backend/
├── README.md                  ← you are here
├── pyproject.toml             poetry config (runtime + dev deps; pytest config)
├── poetry.lock
├── alembic.ini                URL sourced from DATABASE_URL env in env.py
├── alembic/
│   ├── env.py                 reads DATABASE_URL; sqlite memory default for offline smoke
│   └── versions/0001_init.py  schema v1: tokens, jobs, downloads + partial unique index
├── app/
│   ├── main.py                FastAPI app + OpenAPI at /api/v1/{openapi.json,docs}
│   ├── config.py              pydantic-settings Settings (4 required env vars)
│   ├── db.py                  async engine + session factory + get_session FastAPI dep
│   ├── cli.py                 Typer app: create-token / list-tokens / revoke-token
│   ├── api/
│   │   ├── deps.py            bearer_token, require_scope(*), require_admin
│   │   └── v1/
│   │       ├── router.py      mounts /api/v1
│   │       ├── health.py      GET /health
│   │       ├── search.py      POST /search
│   │       ├── download.py    POST /download
│   │       ├── status.py      GET /status/{id}
│   │       ├── queue.py       GET /queue
│   │       ├── settings.py    GET/PATCH /settings (per-user recommendation config)
│   │       └── admin.py       /admin/tokens + /admin/jobs/{id}/retry
│   ├── models/                SQLAlchemy 2.x ORM (Token / Job / Download / Base)
│   ├── schemas/               pydantic-v2 request/response models
│   └── services/
│       ├── ytmusic.py         async YTMusicClient (ytmusicapi wrapper, no credentials)
│       ├── spotdl_runner.py   `run_spotdl(url, dir)` subprocess wrapper
│       ├── jobs.py            state-machine + idempotent create
│       └── workers.py         `run_job(...)` + `JobEnqueuer` BackgroundTasks shim
├── tests/                     pytest + pytest-asyncio (auto mode) + testcontainers
├── Dockerfile                 multi-stage; python:3.13-slim + ffmpeg + isolated spotdl venv
├── .dockerignore
└── docs/
    ├── CONTEXT.md             standing facts (env, constraints, server, deps)
    ├── DECISIONLOG.md         ADRs (newest at bottom)
    ├── CHANGELOG.md           per-task append-only log
    ├── DEBT.md                outstanding tech debt (post v3.0.0)
    └── ROADMAP.md             milestone build sequence (A1 → J12)
```

---

## Deployment to the arr-stack

The deployable artifacts are at the **repo root**, not under `backend/`:

- `../.env.example` — env template; copy to `../.env` and fill in real values.
- `../docker-compose.snippet.yml` — four services (`heerr-postgres-init`, `heerr-postgres`, `heerr-migrate`, `heerr-backend`) that merge into the existing arr-stack compose file.
- `../.github/workflows/docker-publish.yml` — GitHub Actions workflow that builds + publishes `aashish010/heerr-backend` (multi-arch: amd64 + arm64) to Docker Hub on every `v*` tag push.

### Bring it up — pull pre-built image from Docker Hub (typical)

```bash
docker compose -f ../docker-compose.snippet.yml --env-file ../.env pull heerr-backend heerr-migrate
docker compose -f ../docker-compose.snippet.yml --env-file ../.env up -d \
    heerr-postgres-init heerr-postgres heerr-migrate heerr-backend
```

### Bring it up — build from source (dev iteration)

```bash
docker compose -f ../docker-compose.snippet.yml --env-file ../.env build heerr-backend
docker compose -f ../docker-compose.snippet.yml --env-file ../.env up -d \
    heerr-postgres-init heerr-postgres heerr-migrate heerr-backend
```

Connectivity is **Tailscale only** — no host ports are published. Backend listens at `172.39.0.51:8000` on the `arr-stack_default` docker network; reach it from any tailnet client via the host's subnet route. See `docs/CONTEXT.md` "heerr deployment shape" and `/CLAUDE.md` for the hard rules.

### Releasing a new image to Docker Hub

```bash
git tag v0.2.0 && git push --tags
# GitHub Actions builds linux/amd64 + linux/arm64 manifests,
# tags 0.2.0, 0.2, latest, sha-<short>, and pushes them.
```

Required GitHub repo secrets (Settings → Secrets and variables → Actions):
- `DOCKERHUB_USERNAME` — your Docker Hub username (e.g. `aashish010`)
- `DOCKERHUB_TOKEN` — Docker Hub access token (Hub → Account Settings → Security → New Access Token; scope: Read & Write). **Do not use your password.**

PRs targeting `main` that touch `backend/**` or the workflow file build the image (multi-arch) without pushing — early signal if a change breaks the Docker build.

---

## Further reading

| File | What's in it |
|---|---|
| `../CLAUDE.md` | Project-wide rules (session discipline, hard architectural rules) — read this first if you're a future Claude session. |
| `docs/CONTEXT.md` | Standing facts: server env, architecture, hard learnings. |
| `docs/DECISIONLOG.md` | ADRs — every "we chose X over Y because Z" decision with alternatives considered. |
| `docs/ROADMAP.md` | Milestone build sequence with per-milestone commit messages. |
| `docs/CHANGELOG.md` | Append-only log of every task's changes. |
| `docs/DEBT.md` | Outstanding tech debt tracked post v3.0.0. |
