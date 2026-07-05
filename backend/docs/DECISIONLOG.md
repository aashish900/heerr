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

## 2026-06-10 — Search: replace Spotify with YouTube Music

**Context:** The backend used Spotify client-credentials to power `POST /search`, and passed the resulting `spotify:track:xxx` URIs to spotDL. spotDL then fuzzy-matched the URI to a YouTube video. For regional/non-English songs (e.g. Tamil indie), this matching was systematically wrong — spotDL would download an unrelated song.

**Decision:** Replace `SpotifyClient` with `YTMusicClient` (ytmusicapi, unofficial YouTube Music API, no credentials required). `POST /search` now queries YouTube Music and returns `music.youtube.com` URLs. `POST /download` passes the URL directly to spotDL — bypassing spotDL's Spotify→YouTube matching entirely.

**Why:** When the download URL is already a YouTube Music URL, spotDL downloads exactly that video. No matching step, no wrong songs. ytmusicapi's search also gives better regional coverage than Spotify's catalog.

**Alternatives considered:**
- `--audio youtube-music,youtube,soundcloud` comma list: spotDL 4.5.0 doesn't accept comma-separated `--audio`. Rejected.
- `--audio youtube` or `--audio youtube-music` as single flag: changes the search source but not the matching algorithm — still wrong songs for regional tracks.
- Upgrade spotDL: spotDL 4.5.0 is already recent; newer versions' matching is still fundamentally the same.

## 2026-06-10 — spotDL output template + stdout capture

**Context:** Files were being stored with default spotDL naming (`Artist - Title.mp3`). User wanted `Title-Artist.mp3`. Also, when spotDL failed, `stderr_tail` was empty because spotDL writes to stdout, not stderr.

**Decision:** Pass `--output {out_path}/{title}-{artist}.{output-ext}` to spotDL. Merge stderr into stdout (`stderr=STDOUT`) so all spotDL output is captured in `SpotdlError.stderr_tail`. Use `music.youtube.com/watch?v=` URLs (not `youtube.com/watch?v=`) — spotDL has explicit YouTube Music support and handles these more reliably.

**Why:** Flat `Title-Artist.mp3` files are easier to browse on the server and match user expectations. Capturing stdout surfaces real error messages for debugging.

---

## 2026-06-13 — Phase I architecture: pluggable RecommendationEngine + env-var selection + YT-URL universal output

**Context:** Phase I adds a recommendations feature on top of the existing search/download pipeline. The space has at least three reasonable upstream sources — YouTube Music's "watch playlist" related-tracks (zero-credential), Last.fm's `track.getSimilar` (needs an API key, recommends well with scrobble history), and ListenBrainz's collaborative-filter recommendations (needs a user token, needs ≥ 1 week of scrobble history to be useful). They have different credential requirements, different request shapes, and different result fidelity (some return artist+title strings, some return MusicBrainz IDs, some return YouTube videoIds). Decisions captured here apply across I1–I5 so subsequent commits don't re-litigate the shape.

**Decision:**

1. **Pluggable `RecommendationEngine` Protocol** in `app/services/recommenders/base.py` — exposes `recommend(seeds, limit) -> list[RecommendedTrack]`, `probe() -> bool`, `health_chain() -> list[(name, ok)]`, plus a `name: str` attribute. Each upstream becomes a separate class implementing the Protocol. The `POST /recommend` route depends on the Protocol, not a concrete class.
2. **Env-var selection via `RECOMMENDATION_ENGINE`**, parsed at request time by `factory.py`. Default is `ytmusic` (zero-credential). A comma-separated value (e.g. `lastfm,ytmusic`) is wrapped in a `FallbackEngine` that tries engines left-to-right; any exception from an engine's `recommend()` falls back to the next (logged at WARNING); an empty result *without* exception is the final answer (not a fallback trigger).
3. **YT URL is the universal output.** Every engine returns `RecommendedTrack.source_url` as a `music.youtube.com/watch?v=…` URL — even Last.fm (which returns artist+title) and ListenBrainz (which returns MusicBrainz IDs). A shared `YTMusicResolver` (in `yt_resolver.py`) handles the `(artist, title) → URL` resolution via `ytmusic.search(filter='songs', limit=1)`. Unresolvable candidates are dropped.
4. **`GET /recommend/health` reports a structured envelope** — `{engine, status, fallback_active}`. `engine` is the configured primary's name; `status` is `"ok"` when the primary probes healthy, `"degraded"` otherwise; `fallback_active` is true when the primary probes failed *and* some downstream engine in the chain probes OK. `health_chain` is computed via `asyncio.gather` so a slow probe on one engine doesn't serialise the others.
5. **Required credentials validated at factory time, not request time.** Selecting `lastfm` without `LASTFM_API_KEY` raises `RuntimeError` on the first `Depends(get_recommendation_engine)` call (effectively on the first `/recommend` request after deploy). Same for `listenbrainz` + `LISTENBRAINZ_USER_TOKEN`. The error message names the specific env var that's missing.
6. **`POST /recommend` accepts client seeds** as a `list[SeedTrack]` regardless of engine. Engines that consume seeds (ytmusic, lastfm) use them; engines that don't (listenbrainz, which is driven entirely by the user's listen history) accept the field for forward compatibility and ignore the value. This keeps the wire contract uniform; the Android client doesn't need engine-aware code.
7. **`LASTFM_USERNAME` is optional**; when set, the Last.fm engine augments client seeds with `user.getTopTracks?period=1month&limit=10` so recommendations work even when the client sends an empty seeds list. ListenBrainz doesn't need a parallel knob because it derives the username from the token.

**Why:**
- **Pluggable Protocol** lets each engine's quirks live in one file (request format, credential handling, response parsing, weighting) rather than leaking into the route or the schema. The route stays generic; adding a fourth engine later is a single new file + one factory branch.
- **Env-var selection** keeps engine choice an ops decision, not a code decision. The user can switch from `ytmusic` to `lastfm,ytmusic` by editing `.env` and restarting the container — no rebuild, no client change, no schema migration. The comma-separated chain syntax handles the realistic deployment shape ("Last.fm when it's up, fall back to ytmusic otherwise") without a config-file format.
- **YT URL as universal output** preserves the existing download path. The downloader (spotDL) is fed YouTube Music URLs by `POST /download`; recommendation results are downloaded via the *same* endpoint with no special-casing. If the recommended track can't be resolved to a YT URL, it can't be downloaded, so dropping unresolvable candidates is the only correct behaviour.
- **Structured health envelope** lets the Android client (N5 milestone) show an actionable indicator: "primary engine degraded, fallback active" is a different UX than "all engines down" — the user knows whether recommendations are working at reduced quality or not at all.
- **Factory-time validation** fails fast and visibly. Catching the credential gap at the first request rather than the first user-visible empty-result is the same trade-off we apply for `DATABASE_URL` (validated by `pydantic-settings` at boot). The cost is a single 500 on the first deploy where someone forgot to set the env var, which is preferable to silent zero-result responses.
- **Seeds field accepted but engine-ignored** keeps the Protocol contract stable across engines. The Android client builds its seed list the same way regardless of `RECOMMENDATION_ENGINE`, and the backend can swap engines without coordinating a client release.
- **Optional `LASTFM_USERNAME`** matches the real-world Last.fm shape — a user can have a scrobble history without exposing it as the source of recommendations. When opt-in, it makes seeds optional from the client side; when not, the client must supply seeds. ListenBrainz doesn't have this asymmetry because its user-token *is* the username derivation.

**Alternatives considered:**

- **Hard-code one engine.** Rejected: the user has working Last.fm + ListenBrainz scrobbling history elsewhere and wanted both as options. Hard-coding one would also block A/B comparison without a backend-side rewrite when the user wants to compare result quality.
- **Per-engine endpoints** (`POST /recommend/lastfm`, `POST /recommend/ytmusic`). Rejected: the Android client would need to know which engine is in use and call the right URL — coupling that's avoided by env-var-side routing. Also: composing a fallback chain server-side via the existing `FallbackEngine` is cleaner than asking the client to retry against a different URL on failure.
- **Per-engine API request shape** (different request body per engine). Rejected: the seed shape (title, artist, optional source_url) is generic enough to cover every engine that consumes seeds. The cost of always accepting seeds — even when an engine ignores them — is a few unused bytes on the wire, which is cheaper than two divergent schemas.
- **JSON config file for engine selection** instead of `RECOMMENDATION_ENGINE` env var. Rejected: the deployment story is single-file `.env` + docker-compose, and an extra config file means an extra volume mount + an extra place where the production state can drift. Comma-separated env var covers the chain case without a new file.
- **Return raw upstream identifiers** (Spotify URI, MusicBrainz ID, YT videoId, …) from `/recommend` and resolve them inside the Android client. Rejected: the resolution logic is identical across recommend / download — `(artist, title) → YT URL` — and centralising it in the backend means one bug fix instead of two. The Android client gets a flat list of YT URLs it can dispatch via the existing `/download` flow.
- **Use a real-time push channel** (WebSocket / SSE) to stream results as engines respond. Rejected: the existing REST surface is sufficient, and the recommend flow is request-response not subscribe — the user opens the screen, sees the list, taps a result. A push channel would add complexity without changing the perceived latency.

**Trade-off:** The `FallbackEngine` collapses the chain to a single result set — the user can't see which engine produced which recommendation. If quality comparison becomes interesting, the response shape could be extended with a per-result `source_engine` field; that's a non-breaking addition. The Android client (N5) currently treats the chain as one logical engine, which is the right v1 default.

**Reference:** Implementation lives across `backend/app/services/recommenders/{base.py, factory.py, ytmusic_engine.py, lastfm_engine.py, listenbrainz_engine.py, fallback_engine.py, yt_resolver.py}` and `backend/app/api/v1/recommend.py`. Roadmap milestones I1–I5 (in `backend/docs/ROADMAP.md`) and CHANGELOG entries 2026-06-14 enumerate the per-milestone deltas.

## 2026-06-16 — Phase J: multi-user via Navidrome IdP — heerr backend v3.0.0

**Context:** Pre-J the heerr backend was a single-user request app: one operator, one bearer token paste, one Navidrome account, one queue/history. Adding multi-user surfaced two questions: where do credentials live, and what is "isolation"? Storing passwords on the backend means inventing reset/recovery flows, bcrypt/argon2 hashing, and an admin user-mgmt surface — all out of proportion for a single-tailnet family app. Sharing one Navidrome instance per heerr instance is already the deployment shape (the operator runs Navidrome too), and Navidrome already authenticates users via Subsonic auth.

**Decision:** Adopt the **Jellyseerr-style "trust the upstream" pattern**: heerr stores no passwords. Authentication is delegated to Navidrome via Subsonic `ping.view`; success upserts a `users` row keyed by `navidrome_username` and mints a heerr opaque token tied to that user. Per-user isolation is applied at every read/write surface (`/queue`, `/status`, `/search`, `/download`). The backend ships as `v3.0.0` since the auth flow, the schema, and the deployment env vars all changed in semver-major-incompatible ways.

Sub-decisions locked across J1–J10:

1. **Schema (`users` table; FK on `tokens` and `jobs`).** `users.id UUID PK`, `users.navidrome_username TEXT UNIQUE NOT NULL`, plus `created_at` / `last_login_at`. `tokens.user_id` and `jobs.user_id` are `NOT NULL` post-J2 with `ON DELETE RESTRICT`. (Migrations 0004 + 0005.)
2. **Transitional server default.** Migration 0005 creates a `system_admin_user_id() RETURNS uuid STABLE` function and applies it as `DEFAULT` on both `user_id` columns. Existing INSERT sites that don't yet pass `user_id` (test fixtures, CLI before J10, legacy callers) keep working — the default routes them to the synthetic `system-admin` user. Explicit `NULL` still fails (`NOT NULL` is enforced). Tracked for removal as a J9 follow-up: once every INSERT site sets `user_id` explicitly the DEFAULT can be dropped. The bridge is the "green before, green after" pattern in plain SQL form.
3. **Per-user partial unique index** (migration 0006). Replaces the global `jobs_active_source_url_idx (source_url) WHERE active` with `jobs_active_user_source_url_idx (user_id, source_url) WHERE active`. Concurrent active jobs for the same URL by *different* users are allowed; same user still can't queue twice.
4. **Identity flow: `POST /api/v1/auth/login`.** `{username, password}` → Subsonic `ping.view` handshake (`u`, `t = md5(password+salt)`, `s = salt`, `v=1.16.1`, `c=heerr`, `f=json`). On success: upsert user, bump `last_login_at`, mint opaque token, return `{token, scopes, navidrome_url, navidrome_username}`. 401 on bad creds, 503 when Navidrome is unreachable.
5. **`bearer_token` resolves to a User.** `selectinload(Token.user)` is eager. `tok.user is None` raises 500 — post-J2 every token must have a `user_id`; None means data corruption, not an anonymous request.
6. **Read filtering.** `/queue` and `/status/{id}` scope to `tok.user_id` unless `tok.is_admin`. `/status` returns 404 (not 403) for cross-user job ids — does not leak that the id exists.
7. **Write idempotency.** `/search` dedup hints (`already_downloaded`, `active_job_id`) reflect *this user's* history only. `/download` is idempotent per-user; re-POSTing the same URL by the same user returns `deduped=true`; a different user POSTing the same URL gets a fresh job.
8. **File sharing.** Files written by the worker land in the single shared `MUSIC_OUTPUT_DIR` (one Navidrome library). The `downloads` table is global (one row per `source_url`); the worker uses `INSERT … ON CONFLICT (source_url) DO NOTHING` so a second user's worker doesn't fail when the file already exists on disk.
9. **Operator surface.** `python -m app.cli create-token --user=<navidrome_username>` FK-links a token to any existing user (defaults to `system-admin`). `list-tokens` shows the `user=` column. `POST /api/v1/admin/users` (admin-only, idempotent) lets the operator pre-create a heerr `users` row before that user logs in for the first time.

**Why this is small not large:**
- No password column. No password hashing, no reset flow, no email integration, no recovery — all of that lives in Navidrome already.
- Tailscale-only posture is preserved. No public ingress, no TLS, no rate limiting, no abuse handling were added — the threat model is unchanged (`/CLAUDE.md` §3).
- One new env var (`NAVIDROME_URL`). One new endpoint (`POST /auth/login`). One new admin endpoint (`POST /admin/users`). Two new migrations (0004 + 0005) plus one structural index swap (0006). The bulk of the work is per-user filtering on existing endpoints.

**Why v3.0.0 and not v0.2.0:**
- Required new env var: `NAVIDROME_URL` (boot fails fast without it) — backwards-incompatible at deploy time.
- Token wire-format unchanged but issuance flow new: paste-from-CLI → POST /auth/login on the Android client (Phase S). Existing tokens keep working through the `system-admin` backfill, but new tokens are minted differently.
- `jobs.user_id` is now part of dedup semantics; existing scripts that POST `/download` will see deduped semantics shift from "global URI" to "per-user URI". That's user-observable behavior changing.
- The single-user → multi-user posture is a load-bearing architectural decision overturn; semver-major is the honest signal. `rc1` because Phase S (Android) and J12 (home-server smoke) are pending — the multi-user story isn't fully proven end-to-end yet.

**Alternatives considered:**
- **Store passwords on heerr (bcrypt + reset flow + email).** Rejected — far out of proportion for a single-tailnet family app; duplicates capabilities Navidrome already provides.
- **OAuth/OIDC against an external IdP** (Google / GitHub / Authentik). Rejected — adds a public-internet dependency that contradicts the Tailscale-only posture. Also leaks user identity to a third party for an app that is otherwise zero-third-party.
- **Continue with one-bearer-token-per-operator; defer multi-user to v3.** Rejected after explicit user ask. The cost of the schema migration is small enough that delaying it would only mean a larger migration later.
- **Public-internet exposure with self-serve signup.** Rejected — would have required TLS, rate limiting, abuse handling, terms-of-service. None of that is in scope, and the user's intent (per the planning round) is family multi-user inside one tailnet, not SaaS.

**Trade-off:** The `system_admin_user_id()` server default is a transitional bridge. While it exists, an app bug that forgets to pass `user_id` on a `tokens` / `jobs` INSERT will silently route to `system-admin` instead of erroring. Mitigated by per-user-isolation tests (J8 + J9) that would catch any cross-user leakage produced by such a bug. Dropping the default is a J9 follow-up tracked in DEBT after Phase S smoke proves the app side wires `user_id` on every code path.

**Reference:** Implementation across `backend/alembic/versions/{0004_users.py,0005_backfill_users.py,0006_per_user_jobs_index.py}`, `backend/app/{models/user.py,services/navidrome_auth.py,api/v1/auth.py,schemas/{auth,user}.py}`, plus the per-user filter additions in `backend/app/{api/v1/{queue,status,search,download,admin}.py,services/jobs.py,services/workers.py,api/deps.py,cli.py}`. CHANGELOG entries `2026-06-16 — J1` through `J10` enumerate the per-milestone deltas. Phase J on the Android side ("Phase S") is the next slice (`android/docs/ROADMAP.md`).

## 2026-06-18 — Drop `tokens.owner_label` (DEBT M2)

**Context:** Pre-J6, `tokens.owner_label` was a free-text operator label attached to each token. J6 introduced the `users` table and the `tokens.user_id` FK; from that point on, both `POST /auth/login` and `POST /admin/tokens` set `owner_label = req.username` / `owner_label = req.owner_label` while *also* FK-linking the row to a `users` row carrying the canonical `navidrome_username`. The audit (DEBT.md, 2026-06-16) flagged the duplication: two columns will drift the moment any code path forgets to set one of them.

**Decision:** Drop the column outright (migration 0009). The structured access-log key `owner_label` is renamed to `username` and sourced from `tok.user.navidrome_username`. `POST /admin/tokens` request body drops `owner_label`; the response and `TokenView` expose `navidrome_username` instead. The CLI's `create-token --owner` flag is removed; `list-tokens` output replaces `owner=<label>` with `user=<navidrome_username>`.

**Why:**
- After J6, `owner_label` carries no information `users.navidrome_username` does not. Keeping it would be a forever-correctness trap (Two Sources of Truth) for negligible reward.
- The repo rule is "no backwards-compat shims when you can just change the code". Dropping the column is the smaller diff than carrying a parallel field whose only purpose is to outlive its semantics.
- Operator-visible log shape changes (`owner_label` → `username`) and admin-API request-body changes (`owner_label` removed) are acceptable now — there is no Android client in production yet, and the heerr operator is the only consumer of the admin API.

**Alternatives considered:**
- **Repurpose `owner_label` as a device label** (`"alice-pixel-7"`) to unlock a future "log out my other sessions" UX. Rejected: (a) C5 (`/auth/logout`) is already done, (b) the future endpoint that would consume a device label (`GET/DELETE /auth/sessions`) does not exist and is not on the roadmap, (c) populating the field would require the Flutter client to send a `device_label` field on `POST /auth/login` — a contract change blocked on Phase S which has not started, (d) the access log would still need a separate `username` field to keep per-user identity, so we'd be doing the rename work anyway, and (e) a proper "sessions" model belongs in its own table (`token_id`, `device_id`, `user_agent`, `last_seen_at`) when that need actually surfaces.
- **Keep the log key `owner_label`, source it silently from `tok.user.navidrome_username`.** Rejected: a field name that says "owner label" but holds a username lies to the operator reading the log line.

**Reference:** Migration `backend/alembic/versions/0009_drop_tokens_owner_label.py`; model `backend/app/models/token.py`; schemas `backend/app/schemas/token.py`; admin endpoint `backend/app/api/v1/admin.py`; login endpoint `backend/app/api/v1/auth.py`; CLI `backend/app/cli.py`; access-log plumbing `backend/app/api/{context.py,deps.py,middleware.py}` + `backend/app/logging_config.py`. CHANGELOG entry `2026-06-18 — M2: drop tokens.owner_label`.

## 2026-06-19 — Per-user `downloads` rows: denormalize `user_id`, drop global `source_url` UNIQUE (DEBT M3)

**Context:** Post-Phase-J the `downloads` table was still global — one row per `source_url`, `UNIQUE` on `source_url`, and the worker inserting `ON CONFLICT (source_url) DO NOTHING`. Per-user dedupe hints were derived indirectly by joining `Download → Job` and filtering `Job.user_id`. That worked for the *first* downloader of a track but silently broke for everyone after: the 2nd user's `Download` insert hit the global unique and was swallowed, so they never got a row of their own, and their `/search` `already_downloaded` + `/download` on-disk-dedupe hints were permanently `false` even for tracks they themselves had pulled through heerr. The J-phase ADR had flagged the global constraint as "fix when per-user download metadata lands" (DEBT M3); the live hint bug made it worth doing now rather than later.

**Decision:** Migration 0010 — add `downloads.user_id` (FK → `users`, `ON DELETE RESTRICT`, backfilled from the owning job), drop the global `UNIQUE (source_url)`, add composite `UNIQUE (user_id, source_url)`. The worker stamps `user_id` on each row and conflicts on `(user_id, source_url)`. Both readers (`search._hydrate_hints`, `jobs.find_download_for_song`) now filter `Download.user_id` directly instead of joining through `Job`.

**Why:**
- **Denormalize `user_id` onto `downloads` rather than keep deriving it via the `job_id → jobs.user_id` join.** A per-user uniqueness *constraint* cannot span a join — enforcing "one download row per (user, URL)" at the DB level requires the column to live on `downloads`. This matches the project's standing preference for DB-enforced invariants over service-level checks (see 2026-06-08 "Schema v1" ADR: the partial unique index is "bulletproof" vs race-prone service code). The denormalization is safe: `jobs.user_id` is `NOT NULL` and immutable, so the two never drift.
- **Composite `(user_id, source_url)` not just dropping the unique entirely.** Without it, a user could accumulate duplicate download rows for the same URL on every re-run, and `ON CONFLICT` would have no arbiter. The composite preserves per-user idempotency while allowing different users to each own the shared on-disk file.
- **File sharing posture is unchanged.** The physical file still lands once in the shared `MUSIC_OUTPUT_DIR`; only the bookkeeping row is now per-user. `ON CONFLICT (user_id, source_url) DO NOTHING` still absorbs a same-user re-run cleanly.

**Alternatives considered:**
- **Keep the global table; fix the hint by querying `jobs` (done jobs) instead of `downloads`.** Rejected: a `done` job with no download row is exactly the broken state; and album/playlist jobs write no download rows at all, so `downloads` (not `jobs`) must stay the dedupe source of truth for songs. Adding `user_id` to `downloads` fixes the root cause instead of papering over it.
- **Drop the unique constraint entirely, no composite.** Rejected: loses per-user idempotency and leaves `ON CONFLICT` without a target column.
- **Derive `user_id` via the existing join and add a per-user *partial index* expression.** Rejected: Postgres unique constraints/indexes can't reference another table; the column has to be local.

**Trade-off:** `downloads` now carries a denormalized `user_id` that is always equal to its job's `user_id`. Accepted for the DB-level constraint it unlocks. The 0010 downgrade re-adds the global unique and will fail if two users already share a URL — acceptable for a break-glass revert, documented in the migration file.

**Reference:** `backend/alembic/versions/0010_downloads_user_id.py`; `backend/app/models/download.py`; `backend/app/services/workers.py`; `backend/app/api/v1/search.py`; `backend/app/services/jobs.py`; `backend/app/api/v1/status.py`. Tests: `backend/tests/test_migration_0010.py`, `test_worker.py::test_run_job_per_user_download_rows_for_shared_url`. CHANGELOG entry `2026-06-19 — M3`.

## 2026-06-19 — Per-user recommendation config: `users.settings` JSONB + per-user/global credential fallback (DEBT M5)

**Context:** Post-Phase-J the backend is multi-user, but the recommendation engine was still configured entirely through global env vars: `RECOMMENDATION_ENGINE`, `LASTFM_API_KEY`, `LASTFM_USERNAME`, `LISTENBRAINZ_USER_TOKEN`. `LASTFM_USERNAME` and `LISTENBRAINZ_USER_TOKEN` are *personal* — they identify whose scrobble history drives the recommendations. With one global value, every user shared one person's Last.fm/ListenBrainz identity (DEBT M5: "multi-user backend = single-user recommendations"). The `factory.get_recommendation_engine()` dependency read env only and took no user context.

**Decision:** Store per-user recommendation settings in a `users.settings JSONB NOT NULL DEFAULT '{}'` column (migration 0011). Two managed keys: `lastfm_username`, `listenbrainz_token`. Expose them via `GET /settings` + `PATCH /settings`, scoped to the requesting user (`current_user`). Split the factory: a pure `build_recommendation_engine(*, lastfm_username, listenbrainz_token)` builder, plus an async `get_recommendation_engine(user = Depends(current_user))` that reads `user.settings` and threads the values in. Per-user value wins; when unset it falls back to the matching global env var. `RECOMMENDATION_ENGINE` (which engine) and `LASTFM_API_KEY` (operator service key) stay global env vars.

**Why:**
- **JSONB column on `users`, not a `user_settings` table.** At family scale the data is a handful of keys per user, never queried across users — a side table buys nothing and costs a join + a second migration surface. JSONB keeps the settings local to the row they belong to and schema-flexible for the next per-user knob (the DEBT note itself listed JSONB as the cheaper option). This is the one place we *don't* reach for a DB-enforced constraint, because there is no cross-row invariant to enforce — contrast M3, where a uniqueness constraint forced a real column.
- **Operator-global vs per-user split.** `LASTFM_API_KEY` is the operator's API credential for the Last.fm *service*, identical for everyone — global. `RECOMMENDATION_ENGINE` is an ops/deployment choice (which upstream, and the fallback chain), not a per-user preference — global, matching the 2026-06-13 "env-var selection keeps engine choice an ops decision" ADR. Only the two identity-bearing values are per-user.
- **Global fallback preserved.** A single-user deploy that already sets `LASTFM_USERNAME` / `LISTENBRAINZ_USER_TOKEN` in `.env` keeps working with no settings writes — the per-user value simply overrides when present. No forced migration of existing operator config.
- **Token never echoed.** `GET /settings` returns `listenbrainz_token_set: bool`, not the token. It is a secret; reflecting it back (even to its owner, even over the tailnet) would put it in response bodies and potentially logs for no functional gain. The read shape and write shape diverge by exactly this one field.
- **Pure builder + thin dependency.** Keeping `build_recommendation_engine` free of FastAPI/DB lets the env-parsing + credential-resolution logic stay unit-testable without a container; the user wiring lives in the one-line dependency. The existing factory unit tests moved to the builder unchanged in intent.

**Alternatives considered:**
- **`user_settings` side table.** Rejected: no cross-user query need, extra join + migration for a few keys. Revisit only if settings grow into something queried/aggregated across users.
- **Per-user `RECOMMENDATION_ENGINE` / `LASTFM_API_KEY`.** Rejected: engine selection is an ops decision and the API key is the operator's, not a user identity. No evidence family users want to each pick an engine; the seed shape is already engine-agnostic (2026-06-13 ADR).
- **Echo the ListenBrainz token on read (symmetric read/write schema).** Rejected: needless exposure of a secret; `_set: bool` conveys everything the client UI needs ("is one configured?").
- **`MutableDict`-tracked JSONB so in-place mutation persists.** Rejected: reassigning a fresh dict in the PATCH handler is explicit and avoids the SQLAlchemy mutable-extension footgun for a single write site.

**Trade-off:** When a user selects `listenbrainz` but has set no per-user token and no global env fallback exists, `build_recommendation_engine` raises `RuntimeError` → a 500 on that user's first `/recommend` call. This matches the existing factory-time-validation posture (2026-06-13 ADR) — fail fast and visibly rather than silently return empty results. The per-user surface widens the chance of hitting it (each user must set their own token), accepted because the alternative (silent empty list) is worse UX to debug.

## 2026-06-23 — Phase K: YouTube Music preview via server-side proxy — heerr backend v3.2.0

**Context:** Until now a YouTube Music search result could only be *heard* after a full round trip: `POST /download` → spotDL fetches the track into `MUSIC_OUTPUT_DIR` → Navidrome re-indexes (~1 min) → the device streams it over Subsonic. There was no way to preview a result before paying that download + index latency, and every "preview by downloading" permanently wrote a file. The Android client wanted a stream-first affordance: tap a search result and hear it immediately. (Planning round Option C; A = on-device extraction, B = bare `-g` redirect — both rejected below.)

**Decision:** Add `GET /api/v1/preview/stream` (`read` scope). The backend resolves the `music.youtube.com/watch?v=<id>` URL to a direct googlevideo audio URL via **yt-dlp** (added to the *app* venv, not spotDL's isolated venv), then **proxies the bytes** to the device. Range is forwarded both ways (206 seek), the upstream client follows googlevideo's 302 redirects, and yt-dlp's `http_headers` are attached to the upstream request. The bearer token rides in a `?token=` query param (the audio player cannot set headers); nothing is persisted. Resolution is cached per `videoId` for `PREVIEW_CACHE_TTL_S` (default 300 s); `PREVIEW_ENABLED=false` is an operator kill switch (→ 404).

**Why:**
- **Proxy, not redirect (rejects Option B).** googlevideo URLs are signed to the *resolver's* egress IP. A bare `yt-dlp -g` URL handed to the phone 403s from a different IP (confirmed in the planning spike). Proxying makes the backend the only client of googlevideo so the signed IP matches, and the device only ever talks to the backend — preserving the Tailscale-only posture (no new public egress from the phone).
- **yt-dlp server-side (rejects Option A — on-device `youtube_explode_dart`).** YouTube's signature-cipher + `n`-param throttling transforms break every few weeks; a break in a shipped APK needs an app release, and a stale `n`-transform degrades *silently* to throttled streaming. yt-dlp is the most-maintained extractor and a backend fix is a `docker pull` + restart, invisible to the client.
- **yt-dlp in the app venv, not spotDL's isolated venv.** spotDL is isolated because its closure pins `fastapi==0.103` (2026-06-08 "spotdl install isolated" ADR). yt-dlp standalone has no such conflict, so it installs via the normal Poetry lock — and `extract_info(download=False)` needs no ffmpeg (resolution only, no transcode), so no Dockerfile change was required.
- **Ephemeral, `read` scope.** Preview writes nothing to `MUSIC_OUTPUT_DIR` and creates no `jobs`/`downloads` rows — it is a pure read of a public resource, so it mirrors `/search`'s `read` scope rather than `download`. The find → *hear* → download loop is preserved: the client still dispatches `/download` to actually keep a track.
- **Token in `?token=`, accepted because it can't leak in logs.** just_audio cannot attach an `Authorization` header to an `AudioSource` URL (the same constraint Subsonic stream URLs already work around). The raw token in the query is safe here because the existing logging hardening already makes it unloggable: `uvicorn.access` is disabled, the access middleware logs only `scope["path"]` (no query string), and `JsonFormatter` strips `token`/`authorization`/`credentials` (locked by `test_logging.py::test_json_formatter_strips_forbidden_keys`).

**Alternatives considered:**
- **Option A — on-device extraction (`youtube_explode_dart`).** Rejected: fragile, breaks land in the shipped binary, silent throttling on a stale `n`-transform.
- **Option B — backend resolve + bare googlevideo redirect (`-g`).** Rejected: egress-IP binding → 403 on the device.
- **Transcode the proxied stream through ffmpeg to a uniform codec.** Rejected for v1: pass-through preserves seekability (Range), adds no CPU, and webm/opus + m4a decode natively on ExoPlayer. Revisit only if a format the client can't decode surfaces.
- **HMAC-signed ephemeral preview URL instead of the raw bearer in the query.** Deferred: cleaner (no standing token in the URL) but adds a signing endpoint + key management for a single-tailnet app where the token is already unloggable. Noted as future hardening.
- **30 s official preview clips.** Not viable — the ytmusicapi/YouTube stack doesn't expose them for the catalogue.

**Trade-off:** Every preview is a double hop (googlevideo → backend → phone), so the home server pays the preview's bandwidth + a little CPU instead of the phone fetching directly. Accepted: it is the price of dodging the IP-binding 403 and staying on the tailnet, and at family/home scale the bandwidth is invisible. Resolution depends on yt-dlp tracking YouTube's player changes; if a break lands, previews fail with a clean 502/404 until a `yt-dlp` bump — but that is a redeploy, never an app release.

**Reference:** `backend/app/services/preview_resolver.py` (K1), `backend/app/api/v1/preview.py` + `backend/app/api/deps.py::bearer_token_query_or_header` (K2), `backend/app/config.py` preview fields (K3). Tests: `backend/tests/test_preview_resolver.py`, `test_preview.py`, `test_config.py`. Planning spike (2026-06-23): yt-dlp resolves a watch URL → single https googlevideo audio URL + headers; a Range request returns 206; googlevideo 302-redirects (proxy uses `follow_redirects=True`). Roadmap Phase K (K1–K5); CHANGELOG `2026-06-23 — Phase K`. Android consumer: `android/docs/ROADMAP.md` Phase T.

**Reference:** `backend/alembic/versions/0011_users_settings.py`; `backend/app/models/user.py`; `backend/app/schemas/settings.py`; `backend/app/api/v1/settings.py`; `backend/app/api/v1/router.py`; `backend/app/services/recommenders/factory.py`. Tests: `backend/tests/test_migration_0011.py`, `test_recommend_factory.py`, `test_settings.py`. CHANGELOG entry `2026-06-19 — M5`.

## 2026-07-05 — Phase N: DELETE /library/song — delete-by-Subsonic-path, download scope

**Context:** Issue #41 asks for deleting downloaded songs from the device, the server, or both. The device half shipped on the Android side (`64c8e47`). The backend had no way to remove a file from the music library — the only cleanup path was SSH + `rm` + waiting for Navidrome's watcher.

**Decision:** New `DELETE /api/v1/library/song` (body `{path}`) guarded by the existing `download` scope. `path` is the Navidrome-relative path the client already has from the Subsonic API (`song.path`); the backend resolves it under `music_output_dir`, validates containment + an audio-suffix allowlist, unlinks the file, deletes **all** `downloads` rows whose `output_path` matches (regardless of user), and prunes now-empty parent directories up to the library root.

**Why:**
- **Delete by path, not by `downloads` row.** `workers.py` records `downloads` rows only for `song`-type jobs; files landed by album/playlist jobs have no row at all. The Subsonic path is the only identifier that covers every file in the library, including tracks heerr never downloaded.
- **Reuse the `download` scope.** The tokens table check-constraint only allows `['read','download']`; a new `delete` scope would need an Alembic migration, a login-shim change, and a re-login on every device profile. Semantically "may add/remove library content" is one capability for a household app on a tailnet. (User decision 2026-07-05.)
- **Cross-user `downloads` cleanup.** The file is shared — once it's gone, *every* user's already-downloaded dim/dedupe state is stale, so all matching rows go, not just the caller's.
- **Suffix allowlist.** Containment alone would still allow deleting `cover.jpg` or Navidrome sidecar files; restricting to audio suffixes makes the endpoint incapable of touching anything but tracks.
- **No Navidrome API call.** The watcher already handles removal the same way it handles ingest (~1 min); triggering a scan via the Subsonic API would add a second credential path the backend doesn't otherwise have.

**Alternatives considered:**
- **New `delete` scope** — cleaner semantics; rejected for migration + forced re-login cost (revisit if tokens are ever handed to less-trusted parties).
- **Delete by `downloads.id` / `source_url`** — rejected: misses album/playlist-job files and library content heerr didn't download.
- **Admin-only (`is_admin`)** — rejected: deletion is a first-class app feature for every household user, not an operator action.

**Trade-off:** Any authenticated user can delete any track in the shared library (deletes are inherently cross-user because the file is). Accepted at household scale on a Tailscale-only network. Assumption to verify at smoke: Navidrome's music folder and the backend's `music_output_dir` mount the same directory (`/data/media/music`), so Subsonic-relative paths resolve 1:1.

**Reference:** `backend/app/api/v1/library.py`, `backend/app/schemas/library.py`, `backend/tests/test_library_delete.py`. Roadmap Phase N. Android consumer: `android/docs/ROADMAP.md` Phase W.

## 2026-07-05 — N2 addendum: Navidrome virtual paths — real-path requirement + prefix stripping

**Context:** The N1 ADR assumed Subsonic `song.path` is the real library-relative file path. The v4.2.0-rc3 smoke disproved this: Navidrome (post-Big-File-Refactor) reports a **virtual path** derived from tags (`AlbumArtist/Album/NN - Title.ext`). With spotDL's flat output (`Artist - Title.mp3`) the virtual path never exists on disk → every delete 404'd. (Observed live: Subsonic returned `Taylor Swift/Lover/01-08 - Paper Rings.mp3` while the file on disk is `Taylor Swift - Paper Rings.mp3`; `ls` of the virtual folder → "No such file or directory".)

**Decision:** Keep delete-by-Subsonic-path, but (1) require Navidrome to run with `Subsonic.DefaultReportRealPath=true` (cited: https://www.navidrome.org/docs/usage/configuration/options/), and (2) strip the Navidrome-container mount prefix (new `NAVIDROME_MUSIC_FOLDER` setting, default `/music`) from reported paths before resolving under `music_output_dir`, since real paths are reported absolute inside Navidrome's container (observed: `/music/Taylor Swift - Paper Rings.mp3`).

**Operational caveats (observed on the home server):**
- `DefaultReportRealPath` seeds the default for **new player records only**. Clients that connected before the flag keep `reportRealPath=false` — toggle "Report Real Path" per player in the Navidrome web UI (Settings → Players) or delete the player row.
- The Android L5 library cache holds pre-flag virtual paths until refreshed.

**Alternatives considered:**
- **Resolve the real path server-side via Navidrome's native API** — rejected: needs a native-API session per user (heerr stores no passwords; the IdP shim only pings Subsonic).
- **Fuzzy-match `title + artist` against files on disk** — rejected: guessy deletes are worse than a 404.
- **Match against `downloads.output_path`** — rejected in N1 already (album/playlist files have no rows).

**Trade-off:** The feature now depends on a non-default Navidrome config knob plus a per-player toggle. Accepted: it's a one-time operator step on a single home server, documented in `.env.example` and ROADMAP N2. Prefix stripping is narrowly scoped — only the exact configured prefix is stripped; every other absolute path still 422s, and traversal through the prefix is caught by the existing containment check.

**Reference:** `backend/app/config.py` (`navidrome_music_folder`), `backend/app/api/v1/library.py`, `backend/tests/test_library_delete.py` (N2 group). CHANGELOG `2026-07-05 — N2`.
