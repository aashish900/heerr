# CONTEXT.md — heerr (Music Request App, "Seerr but for music")

Project brief for resuming the build in Claude Code. Read this first.

## Name
**heerr** — phonetic blend of "hear" and "Seerr" (the Sonarr/Radarr request-app pattern this mirrors). Use this name in all conversation, file headings, and the working directory (`~/Documents/Personal/Android/heerr`).

## Frontend aesthetic (FYI for Flutter phase)
Target look: Spotify's black + green theme. Material 3 with a custom seed colour ≈ `#1DB954` on a dark surface. Detailed UI design happens at the Flutter-phase planning, not now.

## Goal
A native mobile app where I search for songs (via Spotify) and, if found, the
song is downloaded to my home server's music library. Navidrome auto-indexes
new files, so a downloaded track shows up for streaming within ~1 minute.

## Architecture (decided)
- **Frontend:** native Flutter app (Android-first). Thin client — it only talks
  to my backend's REST API. No download logic on the device.
- **Backend:** FastAPI service that wraps spotDL. Runs as a Docker container in
  my existing arr-stack. Exposes `search`, `download`, and `status/queue`.
- **Search auth:** Spotify **client-credentials flow** (client-id + secret,
  server-side only). NOT user-auth OAuth.
- **Download:** backend shells out to / imports spotDL, writes to the music dir.
- **Connectivity:** app reaches the backend over Tailscale (MagicDNS), no public
  exposure.

## Build order
1. Backend API first (my wheelhouse — containerized REST service + job queue).
   Test with curl/Postman against a real running service.
2. Flutter frontend second, against the working API. This is the part I need
   the most hand-holding on — I have no mobile/app-dev experience.

## Hard constraints / learnings (don't re-litigate)
- spotDL **cannot run on the phone**: fails on iOS entirely; on Android via
  Termux it dies on a `libpthread.so.0` / tls-client dependency. Backend-only.
- spotDL `--user-auth` (liked-songs `saved`) does **not** scale to an app —
  per-user OAuth + redirect-URI pain. Design around URL/search downloads only.
- Spotify **removed the top-tracks endpoint** — center the app on track / album
  / playlist search and the user's own playlists. No "my top songs".
- Single-user: **no Redis/Celery needed to start.** FastAPI BackgroundTasks or a
  small SQLite job table is enough. Add a real queue only if outgrown.

## Possible shortcut
- Fork `DavidCroitoru/SpotDL-Complete-Web-Interface` for the backend (Flask
  wrapper around spotDL). Off-the-shelf alternative if the build is abandoned:
  SpotSpot (web UI, port 6544).

## Server environment (already running)
- Ubuntu 26.04, user `aashish`, LAN IP `192.168.1.43`, Tailscale `100.106.120.121`.
- arr-stack at `~/docker/arr-stack/docker-compose.yml`, Docker subnet
  `172.39.0.0/24` with fixed IPs.
- Navidrome watches `/data/media/music` (scan interval 1m). Download target.
- spotDL 4.5.0 + ffmpeg installed. Spotify app is in "Development mode".
- Shared filesystem root at `/data`.

## Spotify credentials
- Client ID and secret already exist (Spotify Developer dashboard, app
  "Spotify for Aashish's Home Assistant").
- **Do NOT hardcode the secret in code or commit it.** Load from an `.env` /
  environment variable in the backend container. (Client-credentials flow needs
  only id + secret server-side.)

## Dev environment (set up + smoke-tested)
- Flutter 3.44.0 stable, on Mac (Apple Silicon / arm64), at `~/develop/flutter`.
- Dart 3.12.0 (bundled).
- Android SDK 36.1.0 via Android Studio; cmdline-tools installed; licenses
  accepted.
- `adb` on PATH (`~/Library/Android/sdk/platform-tools`).
- Test device: Pixel 7, Android 16 (API 36), connected over **wireless adb**
  (`adb pair` then `adb connect` — note pairing port ≠ connect port).
- iOS path intentionally skipped (no Xcode/CocoaPods). Revisit only if iOS is
  wanted later (needs Mac + Xcode + Apple Developer account + an iPhone).
- Smoke test passed: `flutter create` starter app builds and runs on the Pixel.

## My background
DevOps + data engineering. Strong on backend/containers/infra. **No app-dev
experience** — need step-by-step hand-holding on the Flutter/frontend side
specifically. Prefer decisions backed by sources/docs. Prefer blunt, concise
answers; check shell config with grep before adding entries (no duplicates).

## Next action
Design the FastAPI backend: endpoint contract for `search`, `download`,
`status`, then a containerized skeleton that drops into arr-stack.
