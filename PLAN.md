# PLAN.md — heerr — Music Search/Download API Contract v1

Snapshot of the in-progress design. Lives in the project for visibility; will be updated as we settle remaining open items (implementation strategy, module layout, spotDL invocation, test stack).

---

## Context

The Music Request App ("Seerr for music") needs a FastAPI backend contract before any code is written. The contract drives the Flutter client shape, the Postgres schema, and the spotDL worker interface. CLAUDE.md §2 mandates backend-first design and reproducibility via compose.

Settled (see DECISIONLOG 2026-06-08 entries):
- **Persistence:** Postgres (shared arr-stack, `pgvector/pgvector:pg17`).
- **Auth:** Per-user opaque tokens with scopes, stored in Postgres.
- **TDD discipline:** Mandatory for Python backend code; out of scope for compose/Dockerfile/migrations/Flutter. Now in CLAUDE.md §2.
- **Contract v1:** Frozen (endpoints, scopes, error shape, no progress parsing).
- **Implementation strategy:** Build order, module layout, subprocess spotDL, pytest + testcontainers-postgres, compose skeleton with chown-init container.
- **Schema v1:** `tokens`, `jobs`, `downloads` — locked. See § "Schema v1 (locked)" below.

---

## Auth model

**Scheme:** `Authorization: Bearer <opaque-token>` on every endpoint except `GET /health`.

**Token storage (Postgres):**

```
tokens (
  id            uuid pk,
  token_hash    text not null unique,     -- sha256 of the raw token; raw never stored
  owner_label   text not null,            -- "aashish", "sister", etc.
  scopes        text[] not null,          -- subset of {'read','download'}
  is_admin      boolean not null default false,
  created_at    timestamptz not null,
  revoked_at    timestamptz                -- null = active
)
```

**Scopes (v1):**
- `read` — `/search`, `/status/{job_id}`, `/queue`.
- `download` — `POST /download`.
- `is_admin` — flag (not scope) gates token management endpoints + retry of failed jobs.

**Bootstrap:** CLI subcommand inside the backend container — `python -m app.cli create-token --owner=<name> --scopes=read,download --admin`. Prints the raw token once; only the hash persists. No env-var-seeded "magic" admin token.

**Flutter storage:** `flutter_secure_storage` (Android Keystore).

---

## Endpoints

All under `/api/v1`. JSON in/out. ISO 8601 UTC timestamps. UUIDv4 ids. Errors: `{"error": "<message>", "code": "<machine_code>"}` with appropriate HTTP status.

### `GET /health`
- No auth. Returns `{"status":"ok"}`. For Tailscale/compose healthchecks.

### `POST /search`  *(scope: `read`)*
```json
// request
{
  "query": "blinding lights",
  "type": "track",          // strict: "track" | "album" | "playlist"
  "limit": 20               // 1..50, default 20
}

// response 200
{
  "results": [
    {
      "spotify_uri":         "spotify:track:0VjIjW4GlUZAMYd2vXMi3b",
      "spotify_url":         "https://open.spotify.com/track/...",
      "title":               "Blinding Lights",
      "artist":              "The Weeknd",
      "album":               "After Hours",          // null for playlists
      "duration_ms":         200040,                  // null for playlists
      "cover_url":           "https://i.scdn.co/...",
      "already_downloaded":  true,                    // hint from Postgres (track-level only)
      "active_job_id":       null                     // populated if a job for this URI is queued/running
    }
  ]
}
```
- Single-type per call. No pagination in v1.
- Spotify 429 → backend returns 503 with `Retry-After`.

### `POST /download`  *(scope: `download`)*
```json
// request
{ "spotify_uri": "spotify:track:0VjIjW4GlUZAMYd2vXMi3b" }   // or album / playlist URI

// response 202
{ "job_id": "uuid-...", "state": "queued", "deduped": false }
```
- Single endpoint dispatches by URI prefix.
- Idempotent on `spotify_uri`: active job → return existing + `deduped=true`. Already on disk → synthetic `state:"done"` + `deduped=true`.

### `GET /status/{job_id}`  *(scope: `read`)*
```json
{
  "job_id":      "uuid-...",
  "spotify_uri": "spotify:track:...",
  "state":       "running",   // queued | running | done | failed
  "progress":    null,         // v1 always null; re-evaluate after spotDL stdout audit
  "error":       null,
  "output_path": null,
  "created_at":  "2026-06-08T14:22:01Z",
  "started_at":  "2026-06-08T14:22:03Z",
  "finished_at": null
}
```

### `GET /queue`  *(scope: `read`)*
```json
{
  "active": [ /* Job objects where state in (queued, running) */ ],
  "recent": [ /* last 20 done/failed, newest first */ ]
}
```
- No query params in v1.

### Admin endpoints  *(require `is_admin`)*
- `POST /admin/tokens` — create new token; returns raw value once.
- `GET  /admin/tokens` — list (without raw values).
- `POST /admin/tokens/{id}/revoke` — sets `revoked_at`.
- `POST /admin/jobs/{job_id}/retry` — re-queue a failed job.

---

## Cross-cutting

- **Spotify rate limit:** propagate `429` → `503 Retry-After`. No silent retry inside the request handler.
- **Logging:** every request logs `token.owner_label` (never the raw token).
- **Validation:** Pydantic models for all request bodies; reject unknown fields.
- **OpenAPI:** FastAPI auto-generates `/api/v1/openapi.json`. Pin as source of truth Flutter consumes.

---

## Out of scope for this contract

- Spotify user-OAuth (ruled out by CLAUDE.md §2).
- Top-tracks (Spotify endpoint removed).
- Progress percentages (deferred until spotDL stdout audit).
- Webhooks / push notifications to Flutter (UI polls).
- Rate limiting per token (add when shared users actually exist).

---

## Implementation strategy (locked)

**Build order:**
1. Schema design (tokens, jobs, downloads). ✅ **Locked — see § "Schema v1 (locked)".**
2. Alembic init + first migration (`backend/alembic/versions/0001_init.py`).
3. SQLAlchemy models.
4. Auth dependency + token CLI (`python -m app.cli create-token`).
5. `/health` + `/search` (no DB writes from Spotify yet).
6. `/download` + worker (BackgroundTasks) + job table writes.
7. `/status` + `/queue`.
8. Admin endpoints (`/admin/tokens`, `/admin/jobs/{id}/retry`).
9. Compose skeleton + `postgres-init` chown container.
10. End-to-end smoke against the real stack.

Each step ends with green tests (per CLAUDE.md §2 Development workflow).

**Module layout:**

```
backend/
  app/
    main.py              # FastAPI app + /api/v1 mount
    config.py            # pydantic-settings, .env
    db.py                # async engine + session
    cli.py               # token bootstrap CLI
    models/              # SQLAlchemy ORM
      token.py, job.py, download.py
    schemas/             # Pydantic request/response
      search.py, download.py, job.py, token.py
    api/
      deps.py            # auth dependency + scope check
      v1/
        router.py, health.py, search.py,
        download.py, status.py, queue.py, admin.py
    services/
      spotify.py         # client-credentials Spotify client
      spotdl_runner.py   # spotDL subprocess wrapper
      jobs.py            # job state transitions
  tests/
    conftest.py, test_auth.py, test_search.py,
    test_download.py, test_status.py, test_admin.py
  alembic/
    env.py, versions/
  alembic.ini
  pyproject.toml
  Dockerfile
```

**spotDL invocation:** subprocess. Process isolation; kill-on-cancel; no version coupling to spotDL internals.

**Test stack:**
- `pytest` + `pytest-asyncio`.
- `httpx.AsyncClient` over `ASGITransport` — in-process, no network.
- `testcontainers-postgres` running `pgvector/pgvector:pg17` per session — JSONB/array behavior matches prod.
- Spotify and spotDL mocked at the `services/` boundary via FastAPI `dependency_overrides`.
- No coverage threshold. Rule: every endpoint + every job state transition has a test.

**Compose skeleton:**
- `backend` — built from `backend/Dockerfile`, mounts `/data/media/music` rw, reads `.env`.
- `postgres` — `pgvector/pgvector:pg17`, bind mount `/data/postgres`. `pg_isready` healthcheck.
- `postgres-init` — one-shot alpine: `chown -R 999:999 /data/postgres` then exits.
- Dependency order: `postgres` waits on `postgres-init: service_completed_successfully`; `backend` waits on `postgres: service_healthy`.
- All on existing `172.39.0.0/24` arr-stack network.

---

## Schema v1 (locked)

DDL is what Alembic migration `0001_init.py` will produce. See DECISIONLOG 2026-06-08 "Schema v1" for the why.

### `tokens`
```sql
CREATE TABLE tokens (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  token_hash    text NOT NULL UNIQUE,        -- sha256(raw_token) hex
  owner_label   text NOT NULL,
  scopes        text[] NOT NULL,             -- subset of {'read','download'}
  is_admin      boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now(),
  revoked_at    timestamptz,
  CONSTRAINT tokens_scopes_valid CHECK (scopes <@ ARRAY['read','download']::text[])
);
```

### `jobs`
```sql
CREATE TABLE jobs (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  spotify_uri          text NOT NULL,
  spotify_type         text NOT NULL,        -- 'track'|'album'|'playlist'
  state                text NOT NULL,        -- 'queued'|'running'|'done'|'failed'
  error_msg            text,
  attempt_count        int NOT NULL DEFAULT 0,
  created_by_token_id  uuid NOT NULL REFERENCES tokens(id) ON DELETE RESTRICT,
  created_at           timestamptz NOT NULL DEFAULT now(),
  started_at           timestamptz,
  finished_at          timestamptz,
  CONSTRAINT jobs_state_valid CHECK (state IN ('queued','running','done','failed')),
  CONSTRAINT jobs_type_valid  CHECK (spotify_type IN ('track','album','playlist'))
);

CREATE UNIQUE INDEX jobs_active_uri_idx ON jobs (spotify_uri)
  WHERE state IN ('queued','running');
CREATE INDEX jobs_state_created_idx ON jobs (state, created_at DESC);
CREATE INDEX jobs_token_idx ON jobs (created_by_token_id);
```

### `downloads`
```sql
CREATE TABLE downloads (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  spotify_track_uri   text NOT NULL UNIQUE,
  job_id              uuid NOT NULL REFERENCES jobs(id) ON DELETE RESTRICT,
  output_path         text NOT NULL,
  file_size_bytes     bigint,
  downloaded_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX downloads_job_idx ON downloads (job_id);
```

### Extensions (in the bootstrap migration)
- `CREATE EXTENSION IF NOT EXISTS pgcrypto;`  (for `gen_random_uuid()`)
- `CREATE EXTENSION IF NOT EXISTS vector;`    (unused in v1; per pgvector commitment)

---

## Verification (after implementation, not now)

1. `python -m app.cli create-token --owner=aashish --scopes=read,download --admin` → save token.
2. `curl -H "Authorization: Bearer $T" http://<tailnet-host>:<port>/api/v1/health` → `200`.
3. `curl ... -X POST .../search -d '{"query":"blinding lights","type":"track"}'` → results.
4. `curl ... -X POST .../download -d '{"spotify_uri":"<from above>"}'` → `202 {job_id, state:"queued"}`.
5. Poll `GET /status/{job_id}` until `state="done"`; file exists under `/data/media/music/...`.
6. Wait ~1 min; Navidrome lists the track.
7. Re-issue same `/download` → `deduped=true`.
8. Missing/revoked token → `401`. `read`-only token hitting `/download` → `403`.
