# CONTEXT.md — heerr Android client

Project brief for resuming the Android client build in Claude Code. Read this after `/CLAUDE.md` and `android/CLAUDE.md`.

## Name

**heerr** (same as the repo / backend). Android app id will be `com.aashish.heerr` (lowercase reverse-DNS).

## Goal

A native Android app where the user (single-user, single-device) searches YouTube Music, dispatches downloads to the home-server backend, and watches the queue / job-status as files are written into the Navidrome library on the home server.

## What the app does NOT do

- **No download logic on-device.** The backend invokes spotDL; the device only POSTs `/download` and polls `/status`.
- **No Spotify SDK / OAuth.** Search is via YouTube Music (backend `ytmusicapi`); the device speaks only to the backend.
- **No real-time channel.** No WebSocket / SSE / FCM. Status updates come from polling `/queue` and `/status/{id}`.
- **No iOS.** Out of scope (no Xcode / Apple Developer account). Don't propose iOS-aware code.
- **No public ingress.** App reaches the backend via Tailscale. No "internet" path.

## Backend dependency

REST endpoints under `/api/v1` (see `backend/docs/PLAN.md` for the frozen contract):

| Method | Path | Scope | Use |
|---|---|---|---|
| GET | `/health` | none | Settings-screen "Test connection" button |
| POST | `/search` | `read` | Search screen |
| POST | `/download` | `download` | Dispatch from a search result |
| GET | `/status/{job_id}` | `read` | Job-detail polling |
| GET | `/queue` | `read` | Queue-screen polling |

Auth: `Authorization: Bearer <raw-token>`. The token is minted on the backend via `python -m app.cli create-token --owner=<label> --scopes=read,download`; the user pastes it into the app's Settings screen once.

## Stack (locked v1)

| Concern | Choice | Rationale (see DECISIONLOG) |
|---|---|---|
| State management | Riverpod | Modern, type-safe, less boilerplate than Bloc. Best docs for someone new to Flutter. |
| HTTP | dio | Interceptors for the auth header + retry-on-503 + logging. |
| JSON | freezed + json_serializable | Immutable models, codegen `fromJson`/`toJson`/`copyWith`. |
| Token storage | flutter_secure_storage | Android EncryptedSharedPreferences. Token authorises downloads — won't sit in plaintext prefs. |
| Navigation | go_router | Declarative, Flutter-team-supported. |
| Theme | Material 3, dark, gradient brand palette | Magenta→purple→violet gradient identity on near-black. No light mode in v1. |

## Aesthetic

heerr brand gradient: magenta `#F533C8` → purple `#A93CF2` → violet `#6F4BF5` on near-black `#0A0A0A`. Material 3 with a hand-built raw `ColorScheme` (not `fromSeed`) in `lib/theme.dart` — primary magenta, explicit neutral `surfaceContainer*` grey ladder, black text on the bright accents. The gradient itself (`heerrGradient`) appears only on hero accents (play button, selected nav icon, scrubber active track, primary CTA, avatar rings); everything else uses solid magenta. Replaced the original Spotify-green seed (`#1DB954`) in the 2026-07 gradient redesign. Single dark theme — no light variant in v1.

Since the 2026-07-11 Home redesign the Now Playing chrome (Home hero card + MiniPlayer) also tints per-song: the cover's dominant colour (cached per URI via `artPaletteProvider`) is blended 18% toward brand magenta (`brandBlend`) and applied to waveforms/glows, cross-faded 400 ms on track change. Artwork is never recolored (DECISIONLOG 2026-07-11). The Home screen itself is: branded header, search pill, greeting block, Continue Listening hero card, Quick Access shortcut row, Recently Added list — plus Favorites (`/library/favorites`) and Recently Added (`/library/recently-added`) screens.

## Screens (MVP set)

1. **Settings** — paste backend URL + bearer token; "Test connection" button hits `/health`.
2. **Search** — query box; type toggle (track / album / playlist); results list; tap-to-download.
3. **Queue** — active + recent jobs, polled every 3s. Tap-through to detail.
4. **Job detail** — single job's status (state, started_at, finished_at, output_path, error_msg). Polled every 2s while state is `queued` or `running`; stops polling once `done`/`failed`.

Polling cadences and error semantics are locked in `PLAN.md`.

## Polling cadence (locked)

- **Queue screen:** `GET /queue` every **3000 ms**. Pauses when the screen is off-foreground (uses `WidgetsBindingObserver` lifecycle).
- **Job detail:** `GET /status/{id}` every **2000 ms** while state ∈ {`queued`, `running`}. Stops once `done` / `failed`.
- **Search:** no polling — fire-and-display on Submit / debounce.

## Error UX (locked)

| Status | UX |
|---|---|
| 401 | Snackbar "auth failed" + push the user back to Settings (token expired / revoked). |
| 403 | Snackbar "insufficient scope" — token doesn't have `download`. Don't redirect. |
| 422 | Inline form error if it was a user-entered field; snackbar otherwise. |
| 502 | "YouTube Music error: …" — ytmusicapi failure. |
| network failure | "can't reach backend — check Tailscale" snackbar. |
| other 4xx/5xx | Snackbar with the `detail` field from the backend's error envelope. |

## Dev environment (already set up + smoke-tested)

From the root `CONTEXT.md`:
- **Flutter:** 3.44.0 stable, at `~/develop/flutter`, on macOS Apple Silicon.
- **Dart:** 3.12.0 (bundled with Flutter).
- **Android SDK:** 36.1.0 via Android Studio; cmdline-tools installed; licenses accepted.
- **adb:** on PATH at `~/Library/Android/sdk/platform-tools`.
- **Test device:** Pixel 7, Android 16 (API 36), connected over **wireless adb** (`adb pair` then `adb connect` — pairing port ≠ connect port).
- **Smoke test:** `flutter create` starter app builds and runs on the Pixel — confirmed before this planning round.

## Home-server target (for end-to-end smoke G1)

- Backend deployed via the arr-stack compose snippet (`docker-compose.snippet.yml`).
- Reachable at `http://<tailscale-host>:8000/api/v1` from any tailnet-joined device.
- Bearer token minted via the backend CLI; pasted into the app's Settings on first launch.

## User background (mobile-side reminder)

Zero Flutter / Dart / mobile-app experience. Hand-hold every file path, every command, every IDE step. The user *is* fluent on: REST APIs, JSON, async/await, containers, Linux, the backend in this repo. No need to re-explain those.

## Out of scope for v1

- Push notifications / FCM.
- Background downloads (the backend does the download; the device just dispatches).
- Biometric token unlock.
- iOS / Cupertino.
- Light theme.
- Internationalisation / locales.
- Tablet-optimised layouts.
- Per-user accounts (this is single-user).
- Spotify login on device.
- Admin endpoints (`/api/v1/admin/*`) — token management is CLI-only.

## Next action

Execute `android/docs/ROADMAP.md` milestone A1 (scaffold `flutter create` into `android/app/` with pinned deps + Dart lint config).
