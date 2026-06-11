# Streaming smoke log — K2

End-to-end verification of the Spotify-style streamer (Phases H–K) on the live home server. Companion to the G1 smoke log; covers everything added after the ingestion-only baseline.

## Test environment

- **Device:** Pixel 7, on the user's tailnet.
- **Build:** `flutter build apk --debug && flutter install --debug`, `pubspec.yaml` at `1.0.0+8`.
- **Date:** 2026-06-11.
- **Backends reached over Tailscale:**
  - heerr backend at `http://<tailscale-host>:8000/api/v1`
  - Navidrome at `http://<tailscale-host>:4533`
- **No public ingress; no reverse proxy.** Cleartext over the tailnet — same posture as G1.

## Result

**All seven steps pass.** Streaming MVP shipped — phone is now a first-class find / download / play client. Verified by the user on-device; no observability tooling required beyond the in-app snackbars and the notification shade.

## Per-step log

### 1. Settings smoke — PASS
- "Test heerr" → snackbar "Connection OK" (1s).
- "Test Navidrome" → snackbar "Connection OK" (1s).
- Killed the app from the recents tray, reopened: both heerr URL/token AND the three Navidrome fields stayed populated. (`flutter_secure_storage` working — same EncryptedSharedPreferences backing as B1.)

### 2. Library browse — PASS
- Library tab → Artists list renders within a second.
- Tap artist → album list renders.
- Tap album → song list renders with cover art from `getCoverArt`.

### 3. Playback — PASS
- Tap a song → audio plays.
- Scrubber position advances live (the 250ms `Stream.periodic` ticker from J2).
- Skip-next advances to the next track.
- Pause + resume from the foreground-service notification works.
- Lock screen → audio continues; lock-screen media controls visible and respond to play/pause/skip. (J1's `AudioServiceFragmentActivity` + `androidStopForegroundOnPause` settings holding up.)

### 4. Combined search — library hit — PASS
- Typed a known-in-library term.
- "In your library" section rendered with results.
- "Search more on YouTube Music" button rendered below (auto-fire did NOT trigger — confirmed by the explicit button being present).
- Tap library song → plays.

### 5. Combined search — library miss → YT fallback — PASS
- Typed a known-not-in-library term.
- Library section showed empty state.
- YT section auto-fired and rendered results.
- Tap YT result → "queued" snackbar (1s).

### 6. Combined search — manual YT — PASS
- Typed a library-hit term.
- Tapped "Search more on YouTube Music".
- YT results rendered below the library results in the same scroll view.

### 7. Reactive promotion — PASS
- Watched the step-5 download in the Queue tab — went through queued → running → done.
- Returned to Library with the same step-5 query (no re-typing).
- Within ~60s the song appeared in the "In your library" section and played when tapped. (I2's `combinedSearchProvider` invalidation on `done` transition with the Navidrome re-index grace working as designed.)

## Test gate

- `flutter analyze` clean.
- `flutter test` **207/207** pass.

## Caveats / out of scope for this smoke

- **Cache key for cover art:** the URL contains a rotating salt, so `Image.network` re-fetches per request. Not user-visible at the scale of a single device library; revisit only if the UI feels janky on the larger libraries.
- **`palette_generator` is discontinued upstream.** Still works; replacement choice deferred.
- **Single-user posture preserved.** No multi-user, no Sign-In-With-X, no biometric unlock. Bearer token created on the backend via CLI, pasted into Settings once.
- **No offline cache, no scrobbling, no playlist editing from phone, no Cast, no crossfade, no sleep timer** — out of scope per the streamer plan.

## Done

K2 closes Phase K, which closes the streamer roadmap (H1 → K2). `pubspec.yaml` bumped `0.4.2+7` → `1.0.0+8` to mark the streaming MVP shipping milestone.
