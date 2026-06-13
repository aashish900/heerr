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
- **Backend:** FastAPI service that wraps spotDL. Runs as a Docker container in my existing arr-stack. Exposes `search`, `download`, and `status/queue`.
- **Search:** YouTube Music via `ytmusicapi` (no API key — unofficial API). Returns `music.youtube.com` URLs for songs, browse URLs for albums/playlists.
- **Download:** backend shells out to spotDL, passing the YouTube Music URL directly. Files named `{title}-{artist}.mp3`. spotDL is isolated in its own venv due to FastAPI version conflicts.
- **Connectivity:** app reaches the backend over Tailscale (MagicDNS), no public exposure.

## Build order
1. Backend API first (my wheelhouse — containerized REST service + job queue).
   Test with curl/Postman against a real running service.
2. Flutter frontend second, against the working API. This is the part I need
   the most hand-holding on — I have no mobile/app-dev experience.

## Hard constraints / learnings (don't re-litigate)
- spotDL **cannot run on the phone**: fails on iOS entirely; on Android via Termux it dies on a `libpthread.so.0` / tls-client dependency. Backend-only.
- Spotify search was replaced by YouTube Music (2026-06-10): spotDL's Spotify→YouTube matching produced wrong songs for regional/non-English tracks. Passing `music.youtube.com/watch?v=` URLs directly to spotDL bypasses all matching.
- Single-user: **no Redis/Celery needed to start.** FastAPI BackgroundTasks + Postgres job table. Add a real queue only if outgrown.
- spotDL invoked via subprocess (not library import) — isolation + cancellability + no version-coupling. Installed in `/opt/spotdl-venv` in the Docker image.

## Server environment (already running)
- Ubuntu 26.04, user `aashish`, LAN IP `192.168.1.43`, Tailscale `100.106.120.121`.
- arr-stack at `~/docker/arr-stack/docker-compose.yml`, Docker subnet `172.39.0.0/24` with fixed IPs.
- Navidrome watches `/data/media/music` (scan interval 1m). Download target.
- spotDL 4.5.0 + ffmpeg installed in the Docker image.
- Shared filesystem root at `/data`.

## heerr deployment shape
- `/.env.example` — env template; populate as `.env` next to the arr-stack compose file (Postgres creds, `DATABASE_URL`, `MUSIC_OUTPUT_DIR`). No Spotify credentials needed.
- `/docker-compose.snippet.yml` — four services merged into arr-stack:
  - `heerr-postgres-init` (one-shot: chowns `/data/postgres` to UID 999).
  - `heerr-postgres` (`pgvector/pgvector:pg17`, bind-mounted `/data/postgres`, fixed IP `172.39.0.50`).
  - `heerr-migrate` (one-shot: `alembic upgrade head`).
  - `heerr-backend` (uvicorn, mounts `/data/media/music`, fixed IP `172.39.0.51`).
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
