# ROADMAP_STREAMER.md — heerr Android streaming feature milestones

Track progress through the post-G1 Android streaming feature. Same cadence as the original Android roadmap (`ROADMAP.md`): each milestone = one git commit, with the test gate green where applicable. Tick the box when committed.

This roadmap continues the alphabet from `ROADMAP.md`: A1–G1 covered the ingestion client (search YouTube Music → dispatch download → watch queue). H–K cover the streaming client (browse the Navidrome library → play music in-app → unified search across library + YT).

See `PLAN.md` for the locked v1 contract on the existing ingestion client. See the plan file at `/Users/E1621/.claude-personal/plans/the-current-setup-curious-honey.md` for the streaming-feature design (architecture, settings shape, file inventory, risks).

**Status (2026-06-10):** planning round complete (the plan file). **No streaming Dart code exists yet.** Execution begins at H1.

**Architecture summary:** heerr backend stays unchanged. The Android app gains a second backend connection (Navidrome's Subsonic API) for library browse + streaming + cover art. The existing standalone "Search" bottom-nav tab is removed at I1; its YouTube-Music search functionality is folded into the new Library tab as a fall-back search (library-first; YT only when library is empty or the user taps "Search more"). The bottom nav goes from `Search · Queue · Settings` → `Library · Queue · Settings`.

**Conventions:**
- TDD by default (`/CLAUDE.md` §2) — widget tests / unit tests written first, land in the same commit as code.
- Out-of-TDD-scope: `pubspec.yaml` deps, `AndroidManifest.xml` config, manual smoke. These have other verification gates noted per-milestone.
- Commit messages: Conventional Commits with the `flutter` scope (`feat(flutter): …`, `chore(flutter): …`, `infra(flutter): …`).
- One milestone = one commit. Follow-up cleanup within a milestone = separate commit under the same milestone.
- **Halt and confirm at each milestone boundary** (same cadence as A1→G1).
- Each milestone bumps `pubspec.yaml` version per the existing scheme (`0.3.x` for H/I, `0.4.x` once playback lands at J, `1.0.0` at K2 smoke).

---

## Phase H — Subsonic foundation

### [x] H1. Subsonic auth client + Settings extension + "Test Navidrome"
**Files:**
- New: `android/app/lib/api/subsonic_client.dart`, `android/app/lib/api/subsonic_endpoints.dart`, `android/app/test/api/subsonic_client_test.dart`.
- Modified: `android/app/pubspec.yaml` (add `crypto: ^3.0`), `android/app/lib/providers/settings.dart` (three new fields: `navidromeBaseUrl`, `navidromeUsername`, `navidromePassword`; three new storage keys), `android/app/lib/screens/servers_screen.dart` (three new form fields + "Test Navidrome" button), `android/app/test/providers/settings_test.dart` (extend for the new fields).

**Deliverable:**
- Second dio instance (`subsonicDioProvider`) with `SubsonicAuthInterceptor` injecting `u=<user>`, `s=<6-byte hex salt>`, `t=md5(password+salt)`, `v=1.16.1`, `c=heerr`, `f=json` query params on every request. Salt source is injectable for deterministic tests.
- `apiCall<T>` + `ApiError` mapping (from `lib/api/client.dart`) extended to handle Subsonic's JSON-envelope errors (`status: "failed"` + numeric `code` + `message`). Subsonic code 40 → `UnauthorizedError`; 70 → `NotFoundError` (or fall back through `HttpStatusError`).
- Settings screen accepts the three Navidrome fields and persists them via existing `SecureStorage`. A second "Test Navidrome" button (next to the existing "Test heerr backend" button) hits `GET /rest/ping.view` and shows success/failure snackbar.

**Test gate:** unit tests for `SubsonicAuthInterceptor` (all five params injected, deterministic salt via injected randomness, md5 token correct against a known fixture). Tests for `ApiError` mapping of Subsonic error envelopes (codes 40/50/70). Widget test: pasting valid creds + tapping "Test Navidrome" against a stubbed adapter shows "Connection OK".

**Done when:** `flutter analyze` clean. `flutter test` green. Against the live home server: "Test Navidrome" returns "Connection OK"; mismatched password → "wrong Navidrome username or password" snackbar.

**Commit:** `feat(flutter): subsonic client + auth interceptor + test connection button`

---

### [x] H2. Subsonic models + read-only library providers
**Files:**
- New: `android/app/lib/models/subsonic/*.dart` — freezed models (`subsonic_response_wrapper.dart`, `artist.dart`, `artist_index.dart`, `album.dart`, `song.dart`, `playlist.dart`, `search_result3.dart`). Each annotated for `json_serializable`; reuse the snake-case rename from `android/app/build.yaml`.
- New: `android/app/lib/providers/library/library_artists.dart`, `library_artist.dart`, `library_album.dart`, `library_playlists.dart`, `library_playlist.dart`, `library_search.dart`.
- New: `android/app/test/fixtures/subsonic/*.json` — captured payloads from the live Navidrome (one per endpoint) used as test fixtures.
- New: `android/app/test/models/subsonic_models_test.dart`, `android/app/test/providers/library/*_test.dart`.

**Deliverable:** Six Riverpod providers wrapping `getArtists`, `getArtist(id)`, `getAlbum(id)`, `getPlaylists`, `getPlaylist(id)`, `search3(query)`. All read-only, all routed through `apiCall + ApiError`. `library_search` debounces 300ms like the existing `searchResultsProvider`. Single-vs-array Subsonic JSON quirk handled at the model boundary (custom `fromJson` that accepts both shapes for `artist`/`album`/`song`).

**Test gate:** `dart run build_runner build --delete-conflicting-outputs` clean. Round-trip every model from the captured fixtures (`fromJson(toJson(x)) == x`). Provider tests use the hand-rolled `_FakeAdapter` from `test/api/client_test.dart` to assert correct path + query-param shape on each call and correct response parsing.

**Done when:** `flutter analyze` + `flutter test` green; fixture round-trips all pass.

**Commit:** `feat(flutter): subsonic models + read-only library providers`

---

## Phase I — Library tab + combined search

### [ ] I1. Library tab + Artists / Albums / Playlists screens (+ drop Search tab)
**Files:**
- Modified: `android/app/lib/router.dart` (drop `/search`; add `/library`, `/library/artist/:id`, `/library/album/:id`, `/library/playlist/:id`; keep `/queue`, `/settings`, `/servers`), `android/app/lib/screens/_shell_scaffold.dart` (3 tabs: Library / Queue / Settings; Library icon `library_music`), `android/app/test/router_test.dart` (update assertions to 3 tabs + Library boots by default).
- Removed: `android/app/lib/screens/search_screen.dart`, `android/app/test/screens/search_screen_test.dart`.
- New: `android/app/lib/screens/library/library_screen.dart` (TabBar: Artists / Albums / Playlists), `library/artist_detail_screen.dart`, `library/album_detail_screen.dart`, `library/playlist_detail_screen.dart`.
- New: `android/app/lib/widgets/library_result_tile.dart` (variant of `ResultTile` for library entries — tap = navigate to detail, trailing play icon = queue all + play; playback is wired at J2 — at this milestone the play icon is a no-op placeholder).
- New: `android/app/test/screens/library/*_test.dart` (one per screen, `_StubXxx` provider override pattern from `queue_screen_test.dart`).

**Deliverable:** Bottom nav becomes `Library · Queue · Settings`. Library tab renders three sub-tabs. Tap an artist → artist detail (list of albums). Tap an album → album detail (cover art + track list). Playlist detail mirrors album. All screens use existing `SkeletonList` / `EmptyState`.

**Test gate:** widget tests for each new screen (loading / empty / data / error). Router test asserts 3 tabs, default boot to Library, nested route navigation works. Pre-existing tests that referenced `searchScreen` are updated or deleted.

**Done when:** `flutter analyze` clean; no dangling references to the deleted Search screen; all four library routes navigable on stubbed providers.

**Commit:** `feat(flutter): library tab + drop standalone search tab`

---

### [ ] I2. Combined search inside Library tab (library-first + YT fallback + reactive promotion)
**Files:**
- New: `android/app/lib/providers/library/combined_search.dart` (orchestrates library + YT), `android/app/lib/screens/library/library_search_results.dart` (the results widget rendered below the search field).
- Modified: `android/app/lib/providers/search.dart` (rename `searchResultsProvider` → `ytmSearchProvider`; update all call sites — the rename is a deliberate clarification since YT is no longer the *only* search), `android/app/lib/screens/library/library_screen.dart` (search field in AppBar that swaps the body between the TabBar browse view and the search-results view).
- New: `android/app/test/providers/library/combined_search_test.dart`, `android/app/test/screens/library/library_search_test.dart`.

**Deliverable:** A `combinedSearchProvider(query)` orchestrating two sources:
- **Library** (`librarySearchProvider`) — fires on every debounced keystroke. Renders three subsections under "In your library": Artists / Albums / Songs (matches Subsonic `search3`'s shape — flat-grouped, can re-tune later).
- **YouTube Music** (`ytmSearchProvider`) — fires only when:
  1. The library result is empty (auto-fire), OR
  2. The user taps the "Search more on YouTube Music" `FilledButton.tonal` rendered below the library section when library is non-empty.

Cancellation: query change mid-flight cancels in-flight YT via the existing `CancelToken` pattern; library re-fires.

Tap semantics:
- Library Song tile → `playerProvider.notifier.playSong(song)` (player wiring lands at J2; here the call is stubbed).
- Library Album/Artist tile → navigate to detail; trailing play icon = queue all (stub at this milestone).
- YT result tile → existing `downloadDispatcherProvider.dispatch(...)` (already implemented).

**Reactive promotion:** the combined-search provider subscribes to `queueProvider` and watches for `JobView.state == done` transitions on URIs currently rendered in its YT section. On a match, after a 60s grace, calls `ref.invalidate(librarySearchProvider)` so the song moves from "On YouTube Music" → "In your library" on the next render. If Navidrome hasn't re-indexed yet at invalidate-time, the next user keystroke re-runs the search and picks it up.

**Test gate:** provider unit tests:
- non-empty library → no auto YT call; tapping "Search more" fires YT.
- empty library → YT auto-fires immediately.
- query change mid-YT-flight → in-flight cancelled; library re-fires.
- fake `done` transition on a URI in YT section → after a fake-async tick, `librarySearchProvider` invalidated.

Widget tests:
- library-only render (non-empty + button visible).
- library + auto YT (empty library state).
- library + manual YT (tap button → YT renders).
- both-empty render → single `EmptyState`.
- reactive promotion (assert library section re-fetches after fake done transition).

**Done when:** all provider + widget tests green. The renamed `ytmSearchProvider` references are consistent across the tree (`grep -r searchResultsProvider android/app/lib` empty).

**Commit:** `feat(flutter): combined library + youtube music search with reactive promotion`

---

## Phase J — Audio playback

### [ ] J1. Audio playback skeleton — just_audio + audio_service
**Files:**
- Modified: `android/app/pubspec.yaml` (add `just_audio: ^0.10`, `audio_service: ^0.18`, `audio_session: ^0.2`).
- Modified: `android/app/android/app/src/main/AndroidManifest.xml` — add `<service>` entry for `audio_service`'s `MediaButtonReceiver`, `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` + `POST_NOTIFICATIONS` permissions. Source of truth: the `audio_service` package's current README; **expect manifest iteration** — the test gate doesn't catch manifest mistakes.
- New: `android/app/lib/player/heerr_audio_handler.dart` — `class HeerrAudioHandler extends BaseAudioHandler` backed by a `just_audio.AudioPlayer`. Implements `play / pause / stop / seek / skipToNext / skipToPrevious / updateQueue / setShuffleMode`.
- New: `android/app/lib/player/player_provider.dart` — `@Riverpod(keepAlive: true)` returning the handler. Exposes a `PlayerState` snapshot stream (current `Song`, position, duration, playing flag, queue position, shuffle on/off).
- Modified: `android/app/lib/main.dart` — call `AudioService.init` before `runApp` with the handler config (notification channel id, foreground notification ongoing flag, Android stop-foreground-on-pause = false).
- New: `android/app/test/player/heerr_audio_handler_test.dart`, `android/app/test/player/player_provider_test.dart`.

**Deliverable:** Audio playback works on the device with a foreground notification + lock-screen controls; no UI integration yet (no Now Playing screen, no mini-player). Add a temporary debug FAB on the Library screen to call `playerProvider.notifier.playSong(stubSong)` against a real Subsonic stream URL so the milestone can be verified on the Pixel.

**Test gate:** unit tests for handler logic (queue management, skip behaviour at queue boundaries, terminal-state cleanup) with `just_audio.AudioPlayer` mocked via `audio_service`'s test harness. Manifest changes are out of TDD scope.

**Done when:** tap the debug FAB on the Pixel → song plays through speakers; foreground notification shows title/artist/play-pause; lock the phone → playback continues + lock-screen controls work; tap pause from notification → audio pauses + state stream emits `playing: false`. The debug FAB is removed in J2.

**Commit:** `feat(flutter): audio playback skeleton (just_audio + audio_service)`

---

### [ ] J2. Now Playing screen + persistent mini-player + wire library taps
**Files:**
- New: `android/app/lib/screens/player/now_playing_screen.dart`, `android/app/lib/widgets/mini_player.dart`.
- Modified: `android/app/lib/screens/_shell_scaffold.dart` — mount mini-player above the bottom nav; hidden when player queue is empty.
- Modified: `android/app/lib/router.dart` — add `/player` route (outside `ShellRoute` so it pushes full-screen).
- Modified: `android/app/lib/screens/library/album_detail_screen.dart`, `library/artist_detail_screen.dart`, `library/playlist_detail_screen.dart` — wire the "play all" icon to `playerProvider.notifier.playAll(songs)`.
- Modified: `android/app/lib/screens/library/library_search_results.dart` — wire library Song tap to `playSong(song)`.
- Modified: `android/app/lib/screens/queue_screen.dart` — add a play-icon action on `state == done` job tiles. Action: Subsonic `search3` by `JobView.outputPath` basename → if exactly one Song match → `playSong`; else snackbar "Not in library yet, try again in a minute".
- Modified: `android/app/lib/main.dart` — remove the J1 debug FAB.
- New: `android/app/test/screens/player/now_playing_screen_test.dart`, `android/app/test/widgets/mini_player_test.dart`.

**Deliverable:** Full Now Playing UI: cover art, title/artist, scrubber bound to position stream, play/pause/skip-prev/skip-next, shuffle toggle, queue list at the bottom. Persistent mini-player above bottom nav with current track + play/pause + tap-to-expand. Hidden when player has no current song. Library and Queue tabs both can launch playback.

**Test gate:** widget tests for Now Playing (renders all fields for a queued state; scrubber emits seek on drag; controls fire handler methods) and mini-player (hidden when queue empty, visible when playing, tap pushes `/player`). Uses a `_StubPlayer` provider override (same pattern as `_StubQueue` from D2).

**Done when:** end-to-end on the Pixel: tap a library song → audio plays + mini-player appears across all three tabs + tap mini-player → Now Playing opens + back → mini-player still present + lock-screen controls work + scrubber moves in real time + skip-next plays the next song in the queue.

**Commit:** `feat(flutter): now playing + mini-player + library playback wiring`

---

## Phase K — Polish + smoke

### [ ] K1. Polish + Subsonic error UX + lifecycle + Now Playing tint
**Files:**
- Modified: `android/app/pubspec.yaml` (add `palette_generator: ^0.3`).
- Modified: `android/app/lib/widgets/error_snackbar.dart` — Subsonic auth-error copy ("wrong Navidrome username or password — check Settings"); Subsonic generic-server-error copy ("Navidrome server error: <code> <message>").
- Modified: `android/app/lib/screens/player/now_playing_screen.dart` — dominant-colour tint from the current cover art via `palette_generator`. Fail-soft: extraction error → fall back to default M3 dark surface; no exception bubbled.
- Modified: `android/app/lib/screens/player/now_playing_screen.dart` + `android/app/lib/providers/queue.dart` + `android/app/lib/providers/job_status.dart` — lifecycle rules: queue / job-status polls keep running on Library and Queue tabs (so reactive promotion fires) but pause when Now Playing is foreground (`WidgetsBindingObserver` like `queue_screen.dart` already uses).
- New: `android/app/lib/utils/palette.dart` (cover-art dominant-colour extraction; pure function).
- Modified: `android/app/test/widgets/error_snackbar_test.dart` — two new test cases for the Subsonic error copy strings.

**Deliverable:** Subsonic-side `ApiError`s flow through the existing `reactToApiError` helper with readable copy. Now Playing screen tints its surface based on the current cover. Background pollers run during library/queue use and pause during Now Playing.

**Test gate:** widget tests for the new error snackbar copy. Palette extraction unit test against an asset image (or skip and verify manually if the asset path is awkward). Lifecycle test asserts that pause() is called on the queue provider when Now Playing transitions to foreground.

**Done when:** manual smoke shows the three behaviours: bad Navidrome password → readable snackbar; Now Playing on a colour album → tinted surface; backgrounding Now Playing → queue polls resume.

**Commit:** `feat(flutter): subsonic error ux + now playing palette + lifecycle polish`

---

### [ ] K2. End-to-end smoke against the home server
**Files:** optional `android/docs/smoke_streamer.md` capturing the verification log.

**Deliverable:** Real APK on the Pixel 7 reaches both heerr backend AND Navidrome over Tailscale. The full Spotify-style journey works end-to-end.

**Test gate:** manual — seven steps:
1. **Settings smoke:** "Test heerr" ✓; "Test Navidrome" ✓; both creds persisted across app restarts (kill app, reopen, fields still populated).
2. **Library browse:** Library tab → Artists list loads <1s; tap an artist → albums load; tap an album → songs load with cover art rendered.
3. **Playback:** tap a song → audio plays; scrubber moves; skip-next moves to the next song; pause + resume from notification works; lock the phone → audio continues + lock-screen controls visible and functional.
4. **Combined search (library hit):** type a term known to be in library → library results render; no YT call fires (verify by Network inspector or noting that "Search more" button is present); tap library song → plays.
5. **Combined search (library miss → YT fallback):** type a term known to NOT be in library → library section empty + YT section auto-fires + results render; tap YT result → snackbar "queued".
6. **Combined search (manual YT):** type a library-hit term → tap "Search more on YouTube Music" → YT results render below library.
7. **Reactive promotion:** complete step 5's download (wait for `done` in Queue tab) → return to Library search with the same query → without typing again, song appears in "In your library" within ~60s and is playable.

`flutter analyze` clean; full `flutter test` suite green (expect ~70–110 new tests across H1–K1).

**Done when:** all seven steps pass on the Pixel against the live home server. CHANGELOG entry written; `pubspec.yaml` bumped to `1.0.0`.

**Commit:** `chore(flutter): streaming e2e smoke verified`

---

## Cross-cutting reminders

- **`flutter analyze` green before declaring any milestone done** — same gate as A1–G1.
- **`flutter test` green before AND after each milestone.**
- **`build_runner build --delete-conflicting-outputs` clean after every code-gen-affecting milestone** (H2, I1, I2, J1, J2 all touch freezed/Riverpod codegen).
- **No `print` in production code** — `debugPrint` only. Lints already enforce this.
- **DECISIONLOG drift:** any contract/stack change → update `DECISIONLOG.md` + `PLAN.md` in the same commit (`/CLAUDE.md` staleness rule). Two ADRs expected during this roadmap:
  - "Stream via Navidrome Subsonic API, not via heerr backend" (write at H1).
  - "Combined library + YouTube Music search; standalone Search tab removed" (write at I1).
- **No new env vars or `.env`** — Navidrome creds go into `flutter_secure_storage` like the existing bearer token.
- **Cleartext over Tailscale is fine** — Navidrome served as `http://`. Existing `usesCleartextTraffic="true"` in the manifest covers it.

---

## Out of scope for this roadmap

- Offline cache / download-for-offline.
- ListenBrainz / Last.fm scrobbling.
- Playlist editing from the phone (read-only is in scope; create/delete/reorder is not).
- Crossfade / gapless playback.
- Sleep timer.
- Cast (ChromeCast / Google Cast).
- Lyrics.
- Equaliser.
- Persistence of "Now Playing" across app cold starts.
- Tablet / foldable layouts.
- iOS (out of scope project-wide per `/CLAUDE.md` §3).

---

## Roadmap complete when

1. All 8 milestone boxes checked (H1–K2).
2. Every test gate green at its milestone.
3. K2 smoke succeeds against the real home stack.
4. CHANGELOG entries exist for each milestone group.
5. Two new ADRs in `DECISIONLOG.md` (Subsonic streaming + combined search).
6. `git log --oneline android/` reads as a clean H→K progression with the same Conventional-Commits cadence as A1–G1.
