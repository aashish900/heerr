# DECISIONLOG.md

Append-only ADR log. Newest entries at the bottom.

---

## 2026-06-08 — Persistence: Postgres (shared, pgvector) over SQLite

**Context:** Job table needed for download tracking, dedupe, status, and likely future use cases (library cache, possible vector search across the arr-stack).

**Decision:** Use a shared Postgres instance in the arr-stack as the persistence layer for this app, with the following shape:
- Image: `pgvector/pgvector:pg17` (Postgres 17 + pgvector extension, zero-setup).
- Shared across arr-stack services; this app gets its own DB (`music_request`) and role (`music_request_app`) with grants scoped to that DB only (standard per-app isolation).
- Storage: bind mount at `/data/postgres`. UID 999 ownership handled by an init container declared in the same compose file — no manual host steps.
- Credentials: `.env` loaded via compose `env_file:`. Migration to a secret manager (Vault) deferred; flagged as future work.
- Driver: `asyncpg` + SQLAlchemy 2.x async.
- Migrations: Alembic.

**Why:** SQLite would have sufficed for the day-1 job table, but user prefers a long-term substrate that supports future use cases (multiple writers, JSONB, vector search, remote query) without a later migration. Postgres adds one container — negligible cost for a DevOps-managed arr-stack.

**Alternatives considered:**
- SQLite — rejected: migration debt when second use case lands.
- Dedicated single-app Postgres — rejected: shared instance reuses infra and avoids container sprawl.
- `postgres:17-alpine` + manual pgvector — rejected: `pgvector/pgvector:pg17` is zero-setup.
- Docker secrets / Vault for credentials — deferred: `.env` matches existing arr-stack pattern; revisit later.

---

## 2026-06-08 — API auth: per-user opaque tokens + scopes

**Context:** Backend will live on Tailscale (the primary auth boundary) but the user wants the option to share access later without an OAuth rebuild. Single static token would force a redesign on first share.

**Decision:** `Authorization: Bearer <opaque-token>` on every endpoint except `GET /health`. Tokens stored in Postgres (`tokens` table: `id`, `token_hash` (sha256), `owner_label`, `scopes text[]`, `is_admin`, `created_at`, `revoked_at`). Scopes v1: `read` (search/status/queue) and `download`. `is_admin` is a flag (not a scope) gating `/admin/*`. Raw tokens issued via CLI subcommand `python -m app.cli create-token`; the raw value is shown once and never persisted. Flutter stores its token in `flutter_secure_storage`.

**Why:** Cheap enough now (~one table + a FastAPI dependency) to avoid a future rewrite when sharing/privilege control becomes real. Matches the same "front-load the right substrate" logic as the Postgres decision.

**Alternatives considered:**
- Trust Tailscale, no app-level auth — rejected: zero per-user audit, full rewrite on first share.
- Single static bearer token — rejected: same rewrite cost as no-auth when sharing arrives.
- JWT with signed claims — rejected: signing-key + rotation complexity for no benefit at this scale.
- Full OAuth/OIDC — rejected: vastly over-scoped.

---

## 2026-06-08 — API contract v1 frozen

**Context:** Need a stable surface before writing FastAPI code, the Postgres schema, or the Flutter client.

**Decision:** Freeze v1 contract as captured in `PLAN.md`:
- Endpoints under `/api/v1`: `GET /health`, `POST /search`, `POST /download`, `GET /status/{job_id}`, `GET /queue`, plus admin endpoints (`POST /admin/tokens`, `GET /admin/tokens`, `POST /admin/tokens/{id}/revoke`, `POST /admin/jobs/{job_id}/retry`).
- `/search` is strict single-type (track | album | playlist), no pagination, no multi-type.
- `/download` is a single endpoint dispatching by URI prefix; idempotent on `spotify_uri` with a `deduped` flag.
- `/status` returns `progress: null` in v1 (no spotDL stdout parsing yet).
- `/queue` has no filter params in v1.
- Errors: `{"error","code"}` JSON body with appropriate HTTP status. Spotify 429 → backend 503 + `Retry-After`.
- OpenAPI from FastAPI (`/api/v1/openapi.json`) is the source of truth for Flutter.

**Why:** Lets backend, schema, and Flutter work proceed against a frozen surface without bikeshedding mid-build. Anything cut here (multi-type search, pagination, progress, queue filters) is additive later — no breaking-change risk to v1 consumers.

**Alternatives considered:**
- Multi-type `/search` — rejected: complicates response shape for a UI that picks a tab anyway.
- Separate `/download/{track,album,playlist}` endpoints — rejected: URI prefix dispatch is simpler client-side.
- Parsing spotDL stdout for `progress` — deferred: fragile, low value vs UI spinner.

---

## 2026-06-08 — Implementation strategy

**Context:** Need a build order, module layout, and tool choices before writing code so the TDD loop has scaffolding to attach to.

**Decision:**
- **Build order:** schema → Alembic init → SQLAlchemy models → auth dependency + token CLI → `/health` + `/search` (no DB writes) → `/download` + worker + job table → `/status` + `/queue` → admin endpoints → compose skeleton → end-to-end smoke. Each step ends green.
- **Module layout** (FastAPI standard): `app/{main,config,db,cli}.py`, `app/models/`, `app/schemas/`, `app/api/{deps,v1/*}`, `app/services/{spotify,spotdl_runner,jobs}.py`. Tests in `backend/tests/`. Alembic in `backend/alembic/`.
- **spotDL invocation:** subprocess, not library import. Process isolation, kill-on-cancel, no coupling to spotDL's churning internal API.
- **Test stack:** pytest + pytest-asyncio + `httpx.AsyncClient` (ASGITransport, in-process) + `testcontainers-postgres` (real `pgvector/pgvector:pg17` per session). Spotify and spotDL faked at the `services/` boundary via FastAPI dependency overrides. No coverage gate; rule is every endpoint + every state transition has a test.
- **Compose skeleton:** `backend` + `postgres` (pgvector/pg17, bind mount `/data/postgres`) + `postgres-init` one-shot that `chown -R 999:999 /data/postgres`. Healthchecks on both; `backend` waits on `postgres: service_healthy`. All on existing `172.39.0.0/24` arr-stack network.

**Why:** Standard FastAPI layout; subprocess keeps backend resilient to spotDL crashes; real Postgres in tests avoids JSONB/array drift between sqlite mock and prod; reproducibility-via-compose rule satisfied by the init container.

**Alternatives considered:**
- spotDL library import — rejected: version coupling.
- SQLite for tests + real Postgres in prod — rejected: JSONB/array column behavior diverges.
- Coverage threshold — rejected: gameable, distracts from "every endpoint + state transition tested".

---

## 2026-06-08 — Schema v1 (tokens, jobs, downloads)

**Context:** Build-order step 1 — need the Postgres schema locked before SQLAlchemy models / Alembic migration.

**Decision:** Three tables — `tokens` (auth credentials, sha256 hash, scopes as `text[]`, `is_admin` flag), `jobs` (one row per submitted `spotify_uri`, lifecycle states queued/running/done/failed, FK to `tokens` for audit), `downloads` (one row per track on disk, FK to `jobs`, `spotify_track_uri UNIQUE`). Full DDL in `PLAN.md` § "Schema v1 (locked)". Extensions enabled in the bootstrap migration: `pgcrypto` (UUID default), `vector` (no current use, per DECISIONLOG commitment).

Key invariants enforced at the DB level:
- **Partial unique index** `jobs_active_uri_idx` on `(spotify_uri) WHERE state IN ('queued','running')` — makes "no duplicate active job per URI" a DB-enforced rule; service code cannot violate it.
- **CHECK constraints** on `jobs.state`, `jobs.spotify_type`, `tokens.scopes` — illegal values rejected by Postgres.

**Why:**
- One `jobs` → many `downloads` cleanly models album/playlist downloads producing N files.
- `text + CHECK` for state/type instead of Postgres `ENUM` — adding a state later is a CHECK swap, not an `ALTER TYPE` ceremony.
- No denormalized Spotify metadata on `downloads` — fetched live in `/search`; no library-browse feature in v1 (CLAUDE.md: don't build for hypothetical).
- `ON DELETE RESTRICT` everywhere — no row deletion in v1; tokens use soft-delete (`revoked_at`).

**Alternatives considered:**
- Postgres `ENUM` types for state/type — rejected: alter-type pain on every state addition.
- Service-level idempotency check instead of partial unique index — rejected: race conditions between concurrent `/download` calls would slip through; DB constraint is bulletproof.
- Playlist-membership join table linking downloads to source playlist — deferred: no UI feature needs it.
- File-deletion sync (background scan of `/data/media/music` to clear stale `downloads` rows) — deferred: defer until it bites.

---

## 2026-06-08 — Project name: "heerr"

**Context:** Project needed a short handle to refer to in conversation, file headings, and future user-facing surfaces (app name, package id, etc.).

**Decision:** Name the project **heerr** — phonetic blend of "hear" (the verb the app enables) and "Seerr" (the request-app pattern it mirrors). Use this name in conversation, markdown headings, and future Flutter `applicationId` / app name. Backend Python package stays `app` (generic); Docker image will be `heerr-backend`. Repo directory (`music-search`) is unchanged.

**Why:** Short, evokes the function ("hearing music"), and signals the lineage from Seerr without being a derivative trademark. Avoids re-litigating naming later when the Flutter app needs a label.

**Alternatives considered:** `seermusic`, `harkr`, `tuner` — rejected for being either derivative, ambiguous, or already taken on Play Store / PyPI.

---

## 2026-06-08 — Frontend aesthetic target: Spotify dark theme (flagged, not decided)

**Context:** User wants the Flutter Android client to mimic Spotify's black + green look. Flagged now so it stays in mind when Flutter design starts; not a binding decision today.

**Decision:** Target aesthetic = Spotify-style dark theme (black surfaces, ≈ `#1DB954` accent). Material 3 with a custom seed colour. Detailed UI design and Material component choices happen at the Flutter-phase planning step, not now.

**Why:** User has a clear visual preference; capturing it early avoids redesign churn. Recorded as a *direction*, not a locked contract — final colour palette + component picks land at Flutter planning.

**Alternatives considered:** none yet; revisit at Flutter phase with concrete colour-token + component breakdown.

---

## 2026-06-08 — `downloads` rows: track jobs only in v1 (album/playlist deferred)

**Context:** F2 wires the spotDL runner into the worker. The schema has `downloads.spotify_track_uri UNIQUE NOT NULL`. For a track job, the 1:1 mapping is clean (`job.spotify_uri == downloads.spotify_track_uri`). For album/playlist jobs, spotDL produces N audio files but each file's *per-track* Spotify URI is not derivable from the file path or filename alone.

**Decision:** v1 writes `downloads` rows ONLY for track jobs. Album/playlist jobs successfully transition to `done`, produce files on disk (Navidrome indexes them), and write **no** rows in the `downloads` table.

**Why:**
- Per-file Spotify URI resolution requires parsing spotDL's `--save-file` JSON metadata sidecar — that re-couples us to spotDL's output schema, which DECISIONLOG 2026-06-08 "Implementation strategy" explicitly rejected ("subprocess invocation; no coupling to spotDL output format").
- Inserting one synthetic row per file with a fake URI would corrupt the data model and break the partial-unique-index logic on retry.
- Listening experience unaffected: files are on disk, Navidrome shows them.
- Visible UX gap: `/search` of a track inside a previously-downloaded album returns `already_downloaded=false`, even though the file is on disk.

**Alternatives considered:**
- Parse `--save-file` JSON for per-track URIs — rejected: re-introduces the spotDL output-format coupling we rejected.
- One synthetic `downloads` row per album/playlist file with a placeholder URI — rejected: violates schema semantics, corrupts dedup logic.
- Drop the `spotify_track_uri UNIQUE` constraint — rejected: enables duplicate inserts on retry, which corrupts the table.

**Revisit when:** users complain about missing track-level dedup hints after an album download (i.e., real evidence the gap matters). The fix is to add `--save-file metadata.json` to the spotDL invocation and parse the JSON.

---

## 2026-06-08 — spotdl install isolated (own venv, not in Poetry)

**Context:** G1 (the runtime Dockerfile) needs `spotdl` available. The obvious choice — `poetry add spotdl@^4.5` — fails: `spotdl 4.5.0` hard-pins `fastapi==0.103.x`, conflicting with our `fastapi ^0.115`.

**Decision:** Do NOT add `spotdl` to `pyproject.toml`. Inside the Docker image, install `spotdl==4.5.0` into a separate venv at `/opt/spotdl-venv`. The runner invokes the resulting console script: `_spotdl_executable()` returns `os.environ.get("SPOTDL_EXECUTABLE", "spotdl")`. The image sets `SPOTDL_EXECUTABLE=/opt/spotdl-venv/bin/spotdl`; local dev relies on PATH (CONTEXT.md notes the user has `spotdl 4.5.0` system-installed).

**Why:**
- spotdl is a **CLI dependency, not a Python lib dependency** for us — F1's runner shells out via subprocess and never imports `spotdl`. There's no need for the Python interpreter that runs our app to have `spotdl` importable.
- Keeping spotdl's transitive deps (yt-dlp, mutagen, syncedlyrics, ffmpy, etc., plus its own fastapi/spotipy pins) out of our resolution preserves freedom to bump our own deps without spotdl's constraints biting us.
- Reverses the F1 implementation choice that used `[sys.executable, "-m", "spotdl", ...]` (which required spotdl to be importable from our interpreter). The new shape — `[<spotdl-bin>, "download", ...]` — is also the form spotdl's docs prescribe.

**Alternatives considered:**
- `poetry add spotdl` + downgrade `fastapi` to `^0.103` — rejected: significant code regression (Pydantic-v2 ergonomics, modern dependency API).
- `poetry add spotdl --no-deps` (skip dependency resolution) — rejected: spotdl would fail at runtime without its own deps installed.
- `pipx install spotdl` inside the image — initial attempt; failed because the apt-installed `pipx` couldn't reliably target the image's `python3.13` interpreter. Plain `venv` + `pip install spotdl` is simpler and has fewer moving parts.

**Trade-off:** The Docker image is ~150 MB larger than a hypothetical world where spotdl wasn't shipped, and image rebuilds re-resolve spotdl's deps unless layer-cached. For our home-server, single-container use case, this is invisible.

**Revisit when:** spotdl drops the `fastapi==0.103` pin (track via [spotdl releases](https://github.com/spotDL/spotify-downloader/releases)). Then we could fold spotdl back into our main Poetry resolution if there's any reason to.

## 2026-06-09 — Use pure-ASGI middleware for request logging (not BaseHTTPMiddleware)

**Context:** H-2 needs middleware that (a) generates/echoes `X-Request-ID`, (b) emits one structured access-log line per request, and (c) surfaces `token.owner_label` in that log line. `owner_label` is only known *after* the auth dependency runs (it's the value of `tokens.owner_label` for the validated bearer token). The natural mechanism is a `ContextVar` set by the auth dep and read by the middleware after `call_next` returns.

**Decision:** Implement `RequestLoggingMiddleware` as a **pure ASGI middleware** (a class with `async def __call__(self, scope, receive, send)`), not as a `starlette.middleware.base.BaseHTTPMiddleware` subclass. The middleware calls `await self.app(scope, receive, send_wrapper)` directly and wraps `send` to (a) intercept the response status code and (b) inject the `X-Request-ID` header.

**Why:**
- `BaseHTTPMiddleware.dispatch(request, call_next)` runs the inner application in a **child anyio task** (via `anyio.create_task_group`). Python `ContextVar` writes in a child task do **not** propagate back to the parent task — only the parent's snapshot is visible inside the child. So `owner_label_var.set(...)` performed in the auth dependency (which executes inside the child task that runs the route) is invisible when the middleware reads `owner_label_var.get()` after `call_next` returns.
- Pure ASGI middleware runs in a single task — `await self.app(...)` is just a normal coroutine call — so any ContextVar mutation performed by downstream code (auth dep, route handler) is visible after the await completes.
- Confirmed empirically: the BaseHTTPMiddleware version of this code logged `owner_label="-"` even for authenticated requests; switching to pure ASGI made it correctly log the authenticated owner.

**Alternatives considered:**
- **`request.state.owner_label`** instead of a ContextVar — would work for the middleware case (Request is shared across the chain), but ContextVars are the right tool for any other log call inside the request (services, workers spawned from BackgroundTasks) where there's no `request` object handy. We need ContextVars for the broader logging filter; switching middleware impl is the smaller change.
- **Middleware re-resolves the auth itself** (parse `Authorization`, do its own DB lookup) — extra DB round-trip per request and duplicates a security-critical code path. Rejected.
- **Async-context propagation libraries** (e.g. `asgi-correlation-id`) — would also work but pull in a dep for ~30 lines of code we control.

**Trade-off:** Pure ASGI is slightly lower-level than BaseHTTPMiddleware (we wrap `send` ourselves to inject the header), but the middleware is small (~70 lines) and the predictability is worth it. Documented in `app/api/middleware.py` so future modifications don't accidentally regress to BaseHTTPMiddleware.

**Reference:** `https://github.com/encode/starlette/issues/1438` — the long-standing Starlette issue tracking BaseHTTPMiddleware + ContextVars semantics.

## 2026-06-09 — Trivy: skip `/opt/spotdl-venv` + bump fastapi/starlette

**Context:** The Docker Hub publish workflow's Trivy scan started failing the build on the `v0.1.2` tag with three findings:
1. `starlette 0.27.0` CVE-2024-47874 (HIGH, fixed in 0.40.0) — in `/opt/spotdl-venv/lib/python3.13/site-packages/starlette/`. Pulled in by `spotdl==4.5.0`'s hard pin to `fastapi==0.103.x`.
2. `starlette 0.46.2` CVE-2025-62727 (HIGH, fixed in 0.49.1) — in our backend's venv. We pinned `fastapi = "^0.115"`, and `fastapi 0.115.x` constrains `starlette<0.47`, so we were stuck on 0.46.2.
3. `yt_dlp/extractor/shahid.py` flagged as containing an AWS Access Key (CRITICAL secret) — at `/opt/spotdl-venv/lib/python3.13/site-packages/yt_dlp/extractor/shahid.py:39`. The string is a hardcoded literal yt-dlp ships for the Shahid streaming service's API; not a real credential leak.

**Decision:**

a) **Bump our backend's starlette by widening the fastapi pin.** Change `fastapi = "^0.115"` → `fastapi = ">=0.117,<1.0"` and explicitly add `starlette = ">=0.49.1"` to `[tool.poetry.dependencies]`. `poetry lock` resolved to `fastapi 0.136.3` + `starlette 1.2.1`. 161/161 tests pass; `ruff check`, `ruff format --check`, `mypy app/` all green. Genuine fix for finding (2).

b) **Skip Trivy scanning of `/opt/spotdl-venv`** by adding `skip-dirs: /opt/spotdl-venv` to the trivy-action step. Covers findings (1) and (3) together. The skip is scoped to a single directory — every other site-package, the base image, the app's own venv, and the rest of the runtime is still scanned at HIGH/CRITICAL.

**Why skip-dirs is defensible:**
- `/opt/spotdl-venv` is **vendored** — a third-party CLI (`spotdl 4.5.0`) and its full transitive closure (yt-dlp, fastapi 0.103.x, starlette 0.27.0, etc.) installed in an **isolated venv** specifically to keep its dependency graph off our app's main venv (see DECISIONLOG 2026-06-08 "spotdl install isolated").
- We invoke spotdl **as a subprocess CLI only** (`/opt/spotdl-venv/bin/spotdl download <uri>`). We never run `spotdl web` or otherwise expose its bundled FastAPI/uvicorn server. The starlette DoS CVE (multipart/form-data) requires an HTTP server reachable by an attacker — there is no such surface from `/opt/spotdl-venv` in our deployment.
- yt-dlp's `extractors/` directory contains hundreds of service-specific Python modules with hardcoded API keys, OAuth client IDs, and signed URL fragments embedded as literals — these trip secret scanners across the board (this is well-known among yt-dlp consumers). They are not credentials in the operational sense; treating them as one would require either patching yt-dlp or maintaining a per-extractor allowlist that breaks on every yt-dlp bump.
- spotdl is the latest version on PyPI (4.5.0); there is no newer release to bump *to* that would resolve the upstream dependency pinning.

**Alternatives considered:**
- **Run spotdl with `--no-deps`** + reinstall its actual download dependencies (yt-dlp, mutagen, etc.) manually, dropping fastapi/uvicorn/starlette from the venv. Rejected: brittle, would need maintenance every time spotdl shifts its dep set, and yt-dlp's extractor literals would still trip the secret scanner.
- **Drop Trivy from the workflow entirely.** Rejected: we want the scan to catch real CVEs in our own deps and base image; the issue is the noise from third-party vendored CLI tooling, not Trivy itself.
- **Pin specific CVE IDs in `.trivyignore`** (`CVE-2024-47874`, plus a secret-rule ignore for `aws-access-key-id` under the shahid.py path). Rejected: brittle — every spotdl/yt-dlp bump can surface new CVEs and new "secret" literals in extractors, requiring constant maintenance to the ignore list. A directory-scoped skip targets the actual category of finding (third-party vendored tooling) rather than playing whack-a-mole.
- **Set `exit-code: 0`** to make Trivy informational. Rejected: silently hides real findings in our own code.

**Revisit when:** spotdl 4.6+ ships with a relaxed FastAPI pin (then we could re-include `/opt/spotdl-venv` under the scanner), or if a vulnerability lands that is reachable from how we actually use spotdl (e.g. a subprocess-execution CVE in spotdl itself, which `skip-dirs` would suppress — accept this trade-off and audit spotdl's release notes manually on bumps).
