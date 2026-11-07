# CONTEXT.md — heerr (Music Request App, "Seerr but for music")

Project brief for resuming the build in Claude Code. Read this first.

## Name
**heerr** — phonetic blend of "hear" and "Seerr" (the Sonarr/Radarr request-app pattern this mirrors). Use this name in all conversation, file headings, and the working directory (`~/Documents/Personal/Android/heerr`).

## Frontend aesthetic (FYI for Flutter phase)
Target look: Spotify-influenced black + green. Material 3 with a custom seed colour ≈ `#1DB954` on a dark surface.

## Goal
A native mobile app where I search for songs (via YouTube Music) and, if found, the song is downloaded to my home server's music library. Navidrome auto-indexes new files, so a downloaded track shows up for streaming within ~1 minute.

## Architecture (decided)
- **Frontend:** native Flutter app (Android-first). Thin client — it only talks to my backend's REST API. No download logic on the device.
- **Backend:** FastAPI service that wraps spotDL. Runs as a Docker container in my existing arr-stack. Exposes `search`, `download`, `status`/`queue`, and `preview`.
- **Search:** YouTube Music via `ytmusicapi` (no API key — unofficial API). Returns `music.youtube.com` URLs for songs, browse URLs for albums/playlists.
- **Download:** backend shells out to spotDL, passing the YouTube Music URL directly. Files named `{title}-{artist}.mp3`. spotDL is isolated in its own venv due to FastAPI version conflicts.
- **Preview (Phase K, v3.2.0):** `GET /preview/stream` resolves a YouTube Music URL to its audio via **yt-dlp** and **proxies the bytes** to the device over Tailscale, so a search result can be streamed (heard) before it is downloaded. Read-only and ephemeral — no file is written, no job/download row is created. yt-dlp lives in the app venv (separate from spotDL's). just_audio can't set auth headers, so the bearer rides in `?token=` (already unloggable). `PREVIEW_ENABLED=false` disables it. Android consumer is Phase T (`android/docs/ROADMAP.md`).
- **Podcasts (Phase P, v5.0.0, issue #53):** discovery via **Apple's iTunes Search API** (no auth/signup — swapped 2026-07-20 from the original Podcast Index client after their signup form began rejecting free-email-provider addresses; see DECISIONLOG) + **RSS** (`feedparser`), own tables (`podcast_channel`/`podcast_episode`/`podcast_subscription`/`podcast_progress` — channel/episode metadata shared, subscription/progress per-user). Navidrome does **not** support podcasts server-side ([navidrome#793](https://github.com/navidrome/navidrome/issues/793) still open), so the backend owns storage and playback end to end: episodes download via a plain streamed HTTP GET of the enclosure (no spotDL/yt-dlp) into a **new `PODCAST_OUTPUT_DIR`, never `MUSIC_OUTPUT_DIR`** (Navidrome must never index an episode as a song); downloads reuse the existing `jobs` queue (`source_type='episode'` + nullable `episode_id` FK) and show up in the same `/queue`/Sync Center UI as songs; `GET /podcasts/episodes/{id}/audio` serves downloaded episodes with real HTTP Range support (seek/resume); not-yet-downloaded episodes are never proxied — the client streams `EpisodeItem.enclosure_url` (already public) directly. Per-user resume position via `PUT /podcasts/episodes/{id}/progress`. Full design: `backend/docs/PODCASTS.md`. Android consumer is Phase PC (`android/docs/ROADMAP.md`, not yet built).
- **Jam / remote control (Phase JM, v5.6.0):** `jam_session` + `jam_command` (migration `0015`) relay a guest's playback commands to the host phone. Host keeps a `POST /api/v1/jam/{id}/sync` long-poll open (`wait_s`; returns as soon as a command after its bigserial cursor exists) and pushes its now-playing snapshot via `PUT /jam/{id}/state` on every player change; guest sends `POST /jam/{id}/commands` and long-polls `GET /jam/{id}/state?since=`. Long-polls re-check Postgres every 100ms, committing between checks (no held pool connection, no in-process pub/sub) — still plain REST, per the no-push contract (v5.6.2). Pairing by a 6-char code, 12h TTL; authz = any `read` token that knows a live code. Guests reach the server through a Tailscale node share and log in with their own Navidrome account. Design: `/PLAN.md` §5.
- **Recommendations (Phase I, reworked Phase RX, v5.7.x):** `POST /api/v1/recommend` takes client seeds:
  - song seeds `{title, artist}`, or artist seeds `{artist}` with no title
  - each seed may carry a `weight` (0–1)

  The engine is chosen by `RECOMMENDATION_ENGINE`; the home server runs the default `ytmusic`. The YTMusic engine expands every seed concurrently (semaphore 4): song seeds use the watch-playlist radio plus only the "You might also like" related shelf, and artist seeds use `get_artist` top songs. It scores tracks by consensus, `Σ weight/(1+0.1·rank)`. The route over-fetches `limit*2`, then `rerank()` (shared by every engine):
  - excludes the user's non-failed jobs and anything they dismissed
  - drops covers and alternate versions by title
  - demotes songs shown in the last 7 days (×0.3)
  - caps each artist at 2 songs

  Per-user shown/dismissed state lives in `rec_feedback` (migration `0016`). `POST /recommend/dismiss` hides a song for good. "Owned" filtering happens client-side, because the backend can't query Navidrome as the user. The Android client requests 40 and shows 20 on the For You screen, and the first 6 in the Home For You grid. Design: `/PLAN.md` (phase RX).
- **Vibe mixes (Phase MX, v5.7.5 backend / v5.8.0 app):** `GET /api/v1/recommend/mixes` lists 8 fixed vibes (chill, feel-good, party, romance, heartbreak = YTM "Sad", workout, focus, sleep). `POST /recommend/mixes/{id}` with `{seeds, limit ≤ 50, variant}` builds one:
  1. Take the first 24 YouTube Music "Moods & moments" playlists for the mood.
  2. Score each by affinity to the user's seed artists, and pick 4 of the best 8 (rotated by `variant`, i.e. regenerate).
  3. Rank their tracks by position, playlist consensus and taste bonus.
  4. Pass them through the shared `rerank()` (exclusions, cover filter, 3 per artist; no "shown" demotion).

  It returns `personalized: false` when nothing overlaps. There's a 24-hour in-process cache (`app/services/recommenders/mixes.py`). The app shows a "Your Mixes" row on Home and a mix screen with Play all as previews, row downloads, and "Save as playlist" (downloads every song, waits for each to be indexed, then fills a new Navidrome playlist in mix order). Downloads are capped at `DOWNLOAD_CONCURRENCY` (default 2). Design: `/PLAN.md` (phase MX).
- **Connectivity:** app reaches the backend over Tailscale (MagicDNS), no public exposure.

## Build order
1. Backend API first (my wheelhouse — containerized REST service + job queue).
   Test with curl/Postman against a real running service.
2. Flutter frontend second, against the working API. This is the part I need
   the most hand-holding on — I have no mobile/app-dev experience.

## Hard constraints / learnings (don't re-litigate)
- spotDL **cannot run on the phone**: fails on iOS entirely; on Android via Termux it dies on a `libpthread.so.0` / tls-client dependency. Backend-only.
- Spotify search was replaced by YouTube Music (2026-06-10): spotDL's Spotify→YouTube matching produced wrong songs for regional/non-English tracks. Passing `music.youtube.com/watch?v=` URLs directly to spotDL bypasses all matching.
- Small multi-user, single-tailnet (Phase J, v3.0.0): one heerr instance per family. Authentication is delegated to Navidrome via `POST /auth/login` (Subsonic ping handshake) — heerr stores **no passwords**. Per-user isolation on `/queue`, `/status`, `/search` dedup hints, and `/download` idempotency. Files in `MUSIC_OUTPUT_DIR` are shared (one Navidrome library). **No Redis/Celery needed** — FastAPI BackgroundTasks + Postgres job table remain the queue substrate. Add a real queue only if outgrown.
- spotDL invoked via subprocess (not library import) — isolation + cancellability + no version-coupling. Installed in `/opt/spotdl-venv` in the Docker image.

## Server environment (already running)
- Ubuntu 26.04, user `aashish`, LAN IP `192.168.1.43`, Tailscale `100.106.120.121`.
- arr-stack at `~/docker/arr-stack/docker-compose.yml`, Docker subnet `172.39.0.0/24` with fixed IPs.
- Navidrome watches `/data/media/music` (scan interval 1m). Download target.
- spotDL 4.5.0 + ffmpeg installed in the Docker image.
- Shared filesystem root at `/data`.

## heerr deployment shape
- `/.env.example` — env template; populate as `.env` next to the arr-stack compose file (Postgres creds, `DATABASE_URL`, `MUSIC_OUTPUT_DIR`, `NAVIDROME_URL` — required for the Phase J multi-user login flow; optional `PREVIEW_ENABLED` / `PREVIEW_CACHE_TTL_S` for the Phase K preview proxy; optional `DOWNLOAD_CONCURRENCY` (default 2) caps simultaneous downloads, Phase MX1; optional `PODCAST_OUTPUT_DIR` for Phase P podcasts — discovery itself needs no key, see 2026-07-20 "Podcast discovery: Podcast Index -> iTunes Search" ADR). No Spotify credentials needed.
- `/docker-compose.snippet.yml` — six services merged into arr-stack:
  - `heerr-postgres-init` (one-shot: chowns `/data/postgres` to UID 999).
  - `heerr-podcasts-init` (one-shot: chowns `/data/media/podcasts` to UID/GID 1000, the backend image's non-root user — added 2026-07-20 after a "Permission denied" bug report; unlike `/data/media/music`, nothing else on the host chowns this newer path).
  - `heerr-postgres` (`pgvector/pgvector:pg17`, bind-mounted `/data/postgres`, fixed IP `172.39.0.50`).
  - `heerr-migrate` (one-shot: `alembic upgrade head`).
  - `heerr-backend` (uvicorn, mounts `/data/media/music` and `/data/media/podcasts`, fixed IP `172.39.0.51`).
- Backend also published on host port 8000 (added manually to arr-stack compose) so the phone can reach it over Tailscale.
- No Spotify API credentials required anywhere in heerr.

## Dev environment (set up + smoke-tested)
- Flutter 3.44.0 stable, on Mac (Apple Silicon / arm64), at `~/develop/flutter`.
- Dart 3.12.0 (bundled).
- Android SDK 36.1.0 via Android Studio; cmdline-tools installed; licenses accepted.
- `adb` on PATH (`~/Library/Android/sdk/platform-tools`).
- Test device: Pixel 7, Android 16 (API 36), connected over **wireless adb** (`adb pair` then `adb connect` — note pairing port ≠ connect port).
- iOS path intentionally skipped (no Xcode/CocoaPods).

## My background
DevOps + data engineering. Strong on backend/containers/infra. **No app-dev experience** — need step-by-step hand-holding on the Flutter/frontend side specifically. Prefer decisions backed by sources/docs. Prefer blunt, concise answers; check shell config with grep before adding entries (no duplicates).
