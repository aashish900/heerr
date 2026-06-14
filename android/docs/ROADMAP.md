# ROADMAP.md — heerr Android client implementation milestones

Track progress through the Android client build. Each milestone = one git commit with the test gate green where applicable. Tick the box when committed.

See `PLAN.md` for the *what*; this file is the *how* / *when*.

**Status (2026-06-13):** Phases A–M complete (34 milestones). **N1–N5 pending** — recommendations engine + scrobble integration. Execution begins at N1.

**Conventions:**
- TDD by default (CLAUDE.md §2) — widget tests / unit tests written first, land in the same commit as code.
- Out-of-TDD-scope: `flutter create` scaffold, `pubspec.yaml`, `android/` config, manual smoke. These have other verification gates noted per-milestone.
- Commit messages: Conventional Commits with the `flutter` scope (`feat(flutter): …`, `chore(flutter): …`).
- One milestone = one commit. Follow-up cleanup within a milestone = separate commit under the same milestone.
- **Halt and confirm at each milestone boundary.**

---

## Phase A — Foundation

### [x] A1. Scaffold: `flutter create` + pinned deps + lint
**Files:** `android/app/pubspec.yaml`, `android/app/analysis_options.yaml`, `android/app/lib/main.dart`, `android/app/.gitignore`, `android/app/android/app/build.gradle` (applicationId).
**Deliverable:** `cd android/app && flutter pub get && flutter analyze` exit 0; default counter app removed; bare `main.dart` boots a black `MaterialApp` saying "heerr".
**Test gate:** none (out of TDD scope).
**Done when:** `flutter run -d <pixel>` shows the hello-world screen on the device.
**Commit:** `chore(flutter): scaffold flutter create + pinned deps`

### [x] A2. Theme + app shell (router + bottom nav)
**Files:** `android/app/lib/theme.dart`, `android/app/lib/router.dart`, `android/app/lib/main.dart` (wire ProviderScope + MaterialApp.router), `android/app/test/router_test.dart`.
**Deliverable:** M3 dark theme; go_router with three empty screens (Search / Queue / Settings) and a bottom nav switching between them.
**Test gate:** widget test asserts each bottom-nav tap renders the corresponding scaffold title.
**Done when:** can switch tabs on the device; theme is dark with green accent.
**Commit:** `feat(flutter): m3 dark theme + bottom-nav shell`

### [x] A3. Freezed models + JSON codegen
**Files:** `android/app/lib/models/*.dart`, `android/app/test/models_test.dart`.
**Deliverable:** Every model in PLAN §3 implemented with freezed + json_serializable. `build_runner build` clean. Round-trip `fromJson(toJson(x)) == x` for representative payloads.
**Test gate:** unit tests for serialization of each model.
**Done when:** `flutter pub run build_runner build --delete-conflicting-outputs` clean; all model round-trip tests pass.
**Commit:** `feat(flutter): freezed models for backend contract`

---

## Phase B — Plumbing

### [x] B1. Secure storage + settings provider
**Files:** `android/app/lib/providers/settings.dart`, `android/app/test/providers/settings_test.dart`.
**Deliverable:** `settingsProvider` reads/writes `backend_base_url` and `bearer_token` from `flutter_secure_storage`. Exposes `update(...)` mutators that invalidate dependents.
**Test gate:** unit test against `flutter_secure_storage`'s test backend; assert read-after-write parity.
**Done when:** write a value in test, reload the provider, get the same value back.
**Commit:** `feat(flutter): settings provider backed by secure storage`

### [x] B2. Dio client + Bearer interceptor + ApiError mapping
**Files:** `android/app/lib/api/client.dart`, `android/app/lib/api/api_error.dart`, `android/app/lib/api/endpoints.dart`, `android/app/test/api/client_test.dart`.
**Deliverable:** `dioClientProvider` builds a `Dio` with base URL from settings + interceptor that injects `Authorization: Bearer <token>`. Response/error interceptor maps statuses to a typed `ApiError` (PLAN §9 table).
**Test gate:** unit tests using `DioAdapter` cover happy path + every error-class branch (401/403/422/503/network).
**Done when:** typed `ApiError` for each status; happy path returns the expected payload.
**Commit:** `feat(flutter): dio client + bearer interceptor + typed errors`

### [x] B3. Settings screen UI
**Files:** `android/app/lib/screens/settings_screen.dart`, `android/app/test/screens/settings_screen_test.dart`.
**Deliverable:** Form with two fields (URL, Token) + Save + "Test connection". Save calls `settingsProvider.update`; Test connection calls `GET /health` via dio and shows a snackbar.
**Test gate:** widget test for Save happy path + "Test connection" success/failure.
**Done when:** can paste URL + token, save, run "Test connection" against a local stub backend → "ok" snackbar.
**Commit:** `feat(flutter): settings screen`

---

## Phase C — Read path

### [x] C1. Search providers
**Files:** `android/app/lib/providers/search.dart`, `android/app/test/providers/search_test.dart`.
**Deliverable:** `searchQueryProvider` (query + type state); `searchResultsProvider` (FutureProvider keyed off the query, debounced 300ms, calls dio).
**Test gate:** unit test: provider emits results after the debounce; cancels in-flight on rapid retype.
**Done when:** typing into the query state and waiting > 300ms emits results from a mocked dio.
**Commit:** `feat(flutter): search providers`

### [x] C2. Search screen UI
**Files:** `android/app/lib/screens/search_screen.dart`, `android/app/lib/widgets/result_tile.dart`, `android/app/test/screens/search_screen_test.dart`.
**Deliverable:** Query bar at top; type toggle (track / album / playlist) below; results list of ResultTile (thumbnail, name, artist, dim if `alreadyDownloaded`).
**Test gate:** widget test renders loading / empty / results / error states; tapping the type toggle re-fires the query.
**Done when:** searching against a stubbed backend renders typed results with thumbnails.
**Commit:** `feat(flutter): search screen`

---

## Phase D — Write path

### [x] D1. Download dispatch from result tile
**Files modified:** `android/app/lib/screens/search_screen.dart`, `android/app/lib/widgets/result_tile.dart`. New: `android/app/lib/providers/download.dart`, `android/app/test/providers/download_test.dart`.
**Deliverable:** Tap on result → POST `/download` → snackbar "queued" or "already downloaded" if `deduped`. ResultTile shows a small spinner while in-flight.
**Test gate:** widget test: tap fires the provider; deduped vs new-job both render the right snackbar.
**Done when:** tapping a result against stubbed backend dispatches `/download` and shows the expected snackbar.
**Commit:** `feat(flutter): dispatch download from search result`

### [x] D2. Queue screen + polling provider
**Files:** `android/app/lib/providers/queue.dart`, `android/app/lib/screens/queue_screen.dart`, `android/app/lib/widgets/status_pill.dart`, `android/app/test/screens/queue_screen_test.dart`, `android/app/test/providers/queue_test.dart`.
**Deliverable:** `queueProvider` ticks `/queue` every 3s. Screen shows two sections (Active / Recent) of JobView tiles with status pills (queued = blue, running = amber, done = green, failed = red).
**Test gate:** widget test (loading / both sections / empty); provider test using `fake_async` to verify the 3s cadence + lifecycle pause/resume.
**Done when:** queue against stubbed backend shows both sections, polls correctly, and pauses when off-screen.
**Commit:** `feat(flutter): queue screen with polling`

### [x] D3. Job detail screen + polling provider
**Files:** `android/app/lib/providers/job_status.dart`, `android/app/lib/screens/job_detail_screen.dart`, `android/app/test/screens/job_detail_screen_test.dart`, `android/app/test/providers/job_status_test.dart`.
**Deliverable:** `jobStatusProvider(jobId)` polls `/status/{id}` every 2s while non-terminal. Screen shows id (short), state, timestamps (relative + full), output_path (tap to copy), error_msg.
**Test gate:** widget test + provider test (stops polling on terminal state).
**Done when:** tap a queue tile → detail screen polls until done/failed → polling stops.
**Commit:** `feat(flutter): job detail screen with polling`

---

## Phase E — Polish

### [x] E1. Error UX wiring across all screens
**Files modified:** all screens; new `android/app/lib/widgets/error_snackbar.dart`.
**Deliverable:** Every screen's error case routes through the typed `ApiError` → the right snackbar / banner / redirect per PLAN §9.
**Test gate:** widget tests for each screen's error branches.
**Done when:** every PLAN §9 row is exercised in a test.
**Commit:** `feat(flutter): error ux per plan §9`

### [x] E2. Empty + loading polish
**Files modified:** all screens; new `android/app/lib/widgets/empty_state.dart`, `android/app/lib/widgets/skeleton.dart`.
**Deliverable:** Pretty empty + loading states across Search / Queue / Job detail. M3-spec'd, dark-themed, low-contrast skeletons.
**Test gate:** widget tests for each empty + loading state.
**Done when:** every empty / loading state is visually distinguishable from error.
**Commit:** `feat(flutter): empty + loading states`

---

## Phase F — Ship

### [x] F1. Android signing + release build
**Files:** `android/app/android/app/build.gradle` (signingConfig), `android/app/android/key.properties` (gitignored), `android/app/android/keystore.jks` (gitignored), `android/README.md` (release build instructions).
**Deliverable:** Keystore generated; `key.properties` configured locally; `flutter build apk --release` produces a signed APK at `android/app/build/app/outputs/flutter-apk/app-release.apk`.
**Test gate:** none (out of TDD scope).
**Done when:** signed APK exists; installs on the Pixel via `adb install`.
**Commit:** `infra(flutter): android signing + release build`

---

## Phase G — Smoke

### [x] G1. End-to-end smoke against the home server
**Files:** optional `android/docs/smoke.md` capturing the verification log.
**Deliverable:** Real APK on the Pixel reaches the backend on the home server (via Tailscale), searches Spotify, dispatches a download, watches the queue, and confirms the file lands in Navidrome.
**Test gate:** manual; the 7-step verification block in PLAN §12.
**Done when:** all 7 PLAN §12 steps pass.
**Commit:** `chore(flutter): e2e smoke verified` (optional — only if recording output).

---

## Phase H — Subsonic foundation

**Architecture note:** heerr backend stays unchanged. The Android app gains a second backend connection (Navidrome's Subsonic API) for library browse + streaming + cover art. The existing standalone "Search" bottom-nav tab is removed at I1; its YouTube-Music search functionality folds into the new Library tab as a fallback source (library-first; YT only when library is empty or the user taps "Search more"). Bottom nav goes from `Search · Queue · Settings` → `Library · Queue · Settings`.

### [x] H1. Subsonic auth client + Settings extension + "Test Navidrome"
**Files:**
- New: `android/app/lib/api/subsonic_client.dart`, `android/app/lib/api/subsonic_endpoints.dart`, `android/app/test/api/subsonic_client_test.dart`.
- Modified: `android/app/pubspec.yaml` (add `crypto: ^3.0`), `android/app/lib/providers/settings.dart` (three new fields: `navidromeBaseUrl`, `navidromeUsername`, `navidromePassword`), `android/app/lib/screens/servers_screen.dart` (three new form fields + "Test Navidrome" button), `android/app/test/providers/settings_test.dart`.

**Deliverable:** Second dio instance (`subsonicDioProvider`) with `SubsonicAuthInterceptor` injecting `u/s/t/v/c/f` query params. `apiCall<T>` extended for Subsonic JSON-envelope errors. Settings screen accepts three Navidrome fields. "Test Navidrome" button hits `GET /rest/ping.view`.

**Test gate:** unit tests for `SubsonicAuthInterceptor` (all five params injected, deterministic salt, md5 token correct). Tests for `ApiError` mapping of Subsonic error envelopes (codes 40/50/70). Widget test: "Test Navidrome" against a stubbed adapter shows "Connection OK".

**Done when:** `flutter analyze` clean. `flutter test` green. Against the live home server: "Test Navidrome" returns "Connection OK".
**Commit:** `feat(flutter): subsonic client + auth interceptor + test connection button`

### [x] H2. Subsonic models + read-only library providers
**Files:**
- New: `android/app/lib/models/subsonic/*.dart` — freezed models for `artist`, `artist_index`, `album`, `song`, `playlist`, `search_result3`.
- New: `android/app/lib/providers/library/library_artists.dart`, `library_artist.dart`, `library_album.dart`, `library_playlists.dart`, `library_playlist.dart`, `library_search.dart`.
- New: `android/app/test/fixtures/subsonic/*.json` — captured payloads from the live Navidrome.

**Deliverable:** Six Riverpod providers wrapping `getArtists`, `getArtist(id)`, `getAlbum(id)`, `getPlaylists`, `getPlaylist(id)`, `search3(query)`. All read-only, all routed through `apiCall + ApiError`. `library_search` debounces 300ms.

**Test gate:** `dart run build_runner build --delete-conflicting-outputs` clean. Round-trip every model from the captured fixtures. Provider tests assert correct path + query-param shape on each call and correct response parsing.

**Done when:** `flutter analyze` + `flutter test` green; fixture round-trips all pass.
**Commit:** `feat(flutter): subsonic models + read-only library providers`

---

## Phase I — Library tab + combined search

### [x] I1. Library tab + Artists / Albums / Playlists screens (+ drop Search tab)
**Files:**
- Modified: `android/app/lib/router.dart` (drop `/search`; add `/library`, `/library/artist/:id`, `/library/album/:id`, `/library/playlist/:id`), `android/app/lib/screens/_shell_scaffold.dart` (3 tabs: Library / Queue / Settings).
- Removed: `android/app/lib/screens/search_screen.dart`, `android/app/test/screens/search_screen_test.dart`.
- New: `android/app/lib/screens/library/library_screen.dart`, `library/artist_detail_screen.dart`, `library/album_detail_screen.dart`, `library/playlist_detail_screen.dart`, `android/app/lib/widgets/library_result_tile.dart`.

**Deliverable:** Bottom nav becomes `Library · Queue · Settings`. Library tab renders three sub-tabs. All screens use existing `SkeletonList` / `EmptyState`.

**Test gate:** widget tests for each new screen (loading / empty / data / error). Router test asserts 3 tabs, default boot to Library, nested routes navigable.

**Done when:** `flutter analyze` clean; no dangling references to the deleted Search screen; all four library routes navigable on stubbed providers.
**Commit:** `feat(flutter): library tab + drop standalone search tab`

### [x] I2. Combined search inside Library tab (library-first + YT fallback + reactive promotion)
**Files:**
- New: `android/app/lib/providers/library/combined_search.dart`, `android/app/lib/screens/library/library_search_results.dart`.
- Modified: `android/app/lib/providers/search.dart` (rename `searchResultsProvider` → `ytmSearchProvider`), `android/app/lib/screens/library/library_screen.dart` (search field in AppBar).

**Deliverable:** `combinedSearchProvider(query)` — library fires on every debounced keystroke; YouTube Music fires only when library result is empty (auto-fire) or user taps "Search more on YouTube Music". Reactive promotion: `queueProvider` watches for `done` transitions on YT URIs in the results → after 60s grace calls `ref.invalidate(librarySearchProvider)`.

**Test gate:** provider unit tests for all firing rules, cancellation, and reactive promotion. Widget tests for library-only / auto-YT / manual-YT / both-empty renders.

**Done when:** all provider + widget tests green; `grep -r searchResultsProvider android/app/lib` empty.
**Commit:** `feat(flutter): combined library + youtube music search with reactive promotion`

---

## Phase J — Audio playback

### [x] J1. Audio playback skeleton — just_audio + audio_service
**Files:**
- Modified: `android/app/pubspec.yaml` (add `just_audio: ^0.10`, `audio_service: ^0.18`, `audio_session: ^0.2`), `android/app/android/app/src/main/AndroidManifest.xml`, `android/app/lib/main.dart`.
- New: `android/app/lib/player/heerr_audio_handler.dart` (`HeerrAudioHandler extends BaseAudioHandler`), `android/app/lib/player/player_provider.dart`.

**Deliverable:** Audio playback works on the device with a foreground notification + lock-screen controls. Temporary debug FAB on the Library screen to verify on the Pixel. No UI integration yet.

**ADR:** `MainActivity` extends `AudioServiceFragmentActivity` (not `FlutterActivity`). The `audio_service` plugin's `onAttachedToActivity` checks `FlutterEngineCache` for `"audio_service_engine"` and throws `wrongEngineDetected` if the cached engine doesn't match the host Activity's. `AudioServiceFragmentActivity` overrides `provideFlutterEngine` / `getCachedEngineId` so the wiring is correct — see `DECISIONLOG.md` 2026-06-11.

**Test gate:** unit tests for handler logic (queue management, skip behaviour at boundaries, terminal-state cleanup) with `just_audio.AudioPlayer` mocked.

**Done when:** tap the debug FAB → song plays; foreground notification shows; lock-screen controls work.
**Commit:** `feat(flutter): audio playback skeleton (just_audio + audio_service)`

### [x] J2. Now Playing screen + persistent mini-player + wire library taps
**Files:**
- New: `android/app/lib/screens/player/now_playing_screen.dart`, `android/app/lib/widgets/mini_player.dart`.
- Modified: `android/app/lib/screens/_shell_scaffold.dart` (mount mini-player above bottom nav), `android/app/lib/router.dart` (add `/player` route), album/artist/playlist detail screens (wire play-all), `library_search_results.dart` (wire library song tap), `queue_screen.dart` (play-icon on `done` tiles), `android/app/lib/main.dart` (remove J1 debug FAB).

**Deliverable:** Full Now Playing UI — cover art, title/artist, scrubber, play/pause/skip, shuffle, queue list. Persistent mini-player above bottom nav. All library and queue surfaces can launch playback.

**Test gate:** widget tests for Now Playing (all fields, scrubber emits seek, controls fire handler) and mini-player (hidden when empty, visible when playing, tap pushes `/player`). Uses `_StubPlayer` provider override.

**Done when:** end-to-end on the Pixel — library song plays + mini-player appears across all tabs + Now Playing opens + lock-screen controls work + scrubber moves in real time.
**Commit:** `feat(flutter): now playing + mini-player + library playback wiring`

---

## Phase K — Polish + streaming smoke

### [x] K1. Polish + Subsonic error UX + lifecycle + Now Playing tint
**Files:**
- Modified: `android/app/pubspec.yaml` (add `palette_generator: ^0.3`), `android/app/lib/widgets/error_snackbar.dart` (Subsonic error copy), `android/app/lib/screens/player/now_playing_screen.dart` (dominant-colour tint via `palette_generator`), queue/job-status providers (lifecycle rules).
- New: `android/app/lib/utils/palette.dart`.

**Deliverable:** Subsonic `ApiError`s flow through `reactToApiError` with readable copy. Now Playing tints its surface based on cover art. Background pollers pause during Now Playing foreground.

**Test gate:** widget tests for new error snackbar copy. Lifecycle test asserts `pause()` called when Now Playing transitions to foreground.

**Done when:** bad Navidrome password → readable snackbar; Now Playing on colour album → tinted; backgrounding Now Playing → queue polls resume.
**Commit:** `feat(flutter): subsonic error ux + now playing palette + lifecycle polish`

### [x] K2. End-to-end streaming smoke against the home server
**Files:** optional `android/docs/smoke_streamer.md`.
**Deliverable:** Real APK on the Pixel 7 reaches both heerr backend AND Navidrome over Tailscale. Settings smoke, library browse, playback, combined search (library hit + miss + manual YT), and reactive promotion all verified.
**Test gate:** manual — 7 steps. `flutter analyze` clean; full `flutter test` suite green.
**Done when:** all 7 steps pass. CHANGELOG entry written; `pubspec.yaml` bumped to `1.0.0`.
**Commit:** `chore(flutter): streaming e2e smoke verified`

---

## Phase L — Offline downloads

**Architecture note:** Prefer-local, fallback-to-stream. App-private storage scoped per server (`sha256(baseUrl + "|" + username).hex[0..16]`). Manifest JSON at `<appDocs>/offline/<server-key>/manifest.json`. Sync triggers: manual "Sync now" + periodic foreground tick + auto-on-launch. No WorkManager / true background sync in v1. Pure-Android slice; no backend change. See `DECISIONLOG.md` 2026-06-12 entry for full rationale.

### [x] L1. Foundation — settings extension + paths + manifest
**Files (new):** `android/app/lib/offline/offline_paths.dart`, `offline_manifest.dart`, `offline_settings.dart`.
**Files (modify):** `android/app/pubspec.yaml` (add `path_provider`, `connectivity_plus`), `android/app/lib/providers/settings.dart` (four new keys: `offline_enabled`, `offline_sync_all`, `offline_wifi_only`, `offline_poll_interval_min`).
**Deliverable:** New `offline/` module compiles. Settings round-trip works for the four new keys. Manifest reads/writes to disk and survives a load/save round-trip. Nothing wires into playback or sync yet.
**Test gate:** settings round-trip for 4 new keys; `serverKey` determinism; manifest round-trip; atomic-write safety; corrupt JSON falls back to empty manifest.
**Done when:** `dart run build_runner build` clean; `flutter analyze` clean; `flutter test` green.
**Commit:** `feat(flutter): offline foundation — settings keys + paths + manifest store`

### [x] L2. Downloader + Sync + Playback integration
**Files (new):** `android/app/lib/offline/offline_downloader.dart`, `local_uri.dart`, `offline_marker.dart`, `offline_sync.dart`.
**Files (modify):** `android/app/lib/player/song_to_media_item.dart` (add `localFilePath` param), `android/app/lib/player/playback_actions.dart` (`_toMediaItem` queries `localUriForProvider` — single change covers all five play surfaces).
**Deliverable:** `OfflineSync.syncNow()` works end-to-end against a fake `Dio`. Marking an album → next tick writes files + updates manifest. Song with `ready` manifest entry plays from `file://` URI. No UI yet.
**Test gate:** downloader happy/error/size-mismatch/IO-error paths; local URI chokepoint logic; marker add/unmark idempotency; sync concurrency (N=3), WiFi gate, lifecycle pause/resume, no-creds no-op; `MediaItem.id` shape.
**Done when:** `build_runner` / `analyze` / `test` all green.
**Commit:** `feat(flutter): offline downloader + sync provider + playback wiring`

### [x] L3. UI — markers + Settings section + lifecycle wiring
**Files (modify):** `android/app/lib/widgets/library_result_tile.dart` (marker icon + progress bar slot), `album_detail_screen.dart` (AppBar download icon + row progress), `playlist_detail_screen.dart` (same), `library_screen.dart` (albums/playlists browse + search), `settings_screen.dart` (new "Offline downloads" section), `android/app/lib/router.dart` (`_ShellScaffold` → `WidgetsBindingObserver` driving `offlineSyncProvider.pause/resume`).
**Deliverable:** Marker icons flip in album/playlist detail, Settings section round-trips all four controls, "Sync now" shows progress snackbar, "Clear all downloads" has confirmation dialog, storage line shows human-readable size.
**Test gate:** tile marker-icon variants; album/playlist detail AppBar toggle; Settings section round-trips; router lifecycle → `pause()` / `resume()` on `offlineSyncProvider`.
**Done when:** analyze / test green.
**Commit:** `feat(flutter): offline UI — markers + settings section + lifecycle`

### [x] L4. Sync-all + estimated-size preflight
**Files (modify):** `android/app/lib/offline/offline_sync.dart` (sync-all branch), `android/app/lib/screens/settings_screen.dart` (sync-all toggle + confirmation dialog).
**Files (new):** `android/app/lib/offline/offline_size_estimator.dart` (walks library, caches result 1 hour on manifest, invalidated on marker changes).
**Deliverable:** "Sync entire library" toggle with `"≈ <size>"` subtitle, "Calculating…" while loading, confirmation on OFF→ON. Sync-all walks all albums+playlists and dedupes against markers.
**Test gate:** sync-all enumeration; union-dedup with markers; size estimator caching + invalidation; confirmation dialog guards the toggle.
**Done when:** analyze / test green.
**Commit:** `feat(flutter): offline sync-all toggle + estimated-size preflight`

### [x] L5. Offline library metadata cache
**Files (new):** `android/app/lib/offline/library_cache.dart`, `library_cache_helpers.dart`.
**Files (modify):** all six library providers (wrap `subsonicCall` body in `cacheAware` — write cache on success, serve cache on failure), `android/app/lib/widgets/library_cover_art.dart` (persist cover bytes on success; `Image.file` on re-render offline).
**Deliverable:** Turn WiFi off → Library tabs serve cached data from prior online session. Cover art loads from disk. Downloaded songs remain navigable and playable offline. No TTL in v1 — next successful online render overwrites.
**Test gate:** library cache round-trip; cache served on network failure; no-cache + failure rethrows; per-server key isolation; cover-art cache miss/hit.
**Done when:** `flutter analyze` clean; `flutter test` green.
**Commit:** `feat(flutter): offline library metadata cache + cache-aware providers`

### [x] L6. End-to-end smoke + docs
**Files (new):** `android/docs/smoke_offline.md`, ADR in `DECISIONLOG.md`, entry in `CHANGELOG.md`.
**Files (modify):** `android/app/pubspec.yaml` → `1.1.0`.
**Test gate:** manual 7-step smoke (settings baseline, mark album, offline playback, offline navigation, fallback-to-stream, unmark+sweep, sync-all).
**Done when:** all 7 steps pass. `pubspec.yaml` at `1.1.0`. Tagged `v1.1.0`.
**Commit:** `chore(flutter): offline e2e smoke verified`

**Roadmap closed: 2026-06-12.** Offline feature live at `1.1.0` / `v1.1.0`. Doc debt noted at closing (DECISIONLOG ADR, CHANGELOG L1–L6 entries, smoke_offline.md — not written; smoke verified informally on-device).

---

## Phase M — Playlist mutations

**Architecture note:** Full CRUD against Subsonic 1.16.1 endpoints (`createPlaylist.view`, `updatePlaylist.view`, `deletePlaylist.view`) via the existing `subsonicDioClientProvider`. Single `PlaylistMutations` `@Riverpod(keepAlive: true)` stateless notifier; every method invalidates `libraryPlaylistsProvider` and (where applicable) `libraryPlaylistProvider(id)` on success. Owner-only edits — mutation UI hidden when `playlist.owner != settings.navidromeUsername`. No offline mutation queue in v1. Reorder via delete-all-and-re-add (Subsonic has no native reorder primitive). `addSongs` dedupes client-side. Favourites is a lazy-created regular playlist (`kFavouritesPlaylistName = 'Favourites'`). See `DECISIONLOG.md` 2026-06-13 entry for full rationale.

### [x] M1. Endpoints + mutation notifier (no UI)
**Files (new):** `android/app/lib/providers/library/playlist_mutations.dart` — `PlaylistMutations` notifier with six methods: `createPlaylist`, `renamePlaylist`, `deletePlaylist`, `addSongs`, `removeSongsAtIndices`, `reorder`.
**Files (modify):** `android/app/lib/api/subsonic_endpoints.dart` (add `createPlaylist`, `updatePlaylist`, `deletePlaylist` constants), `android/app/pubspec.yaml` → `1.2.0-pre+11`.
**Deliverable:** Module compiles. Mutations issue the expected query strings against a fake `Dio`. Providers invalidated on success; `ApiError` rethrown on failure.
**Test gate:** happy + error paths for all six methods; `createPlaylist` with `songIds` multi-param encoding; `removeSongsAtIndices` descending ordering; `reorder` diff produces a single batched call.
**Done when:** `build_runner` / `analyze` / `test` green.
**Commit:** `feat(flutter): subsonic playlist mutations — endpoints + notifier`

### [x] M2. Create + rename + delete UI
**Files (modify):** `android/app/lib/screens/library/library_screen.dart` (FAB "New playlist" on Playlists tab), `android/app/lib/screens/library/playlist_detail_screen.dart` (overflow menu: Rename / Delete; hidden for non-owners).
**Files (new):** `android/app/lib/widgets/playlist_dialogs.dart` (`_CreatePlaylistDialog` + `_RenamePlaylistDialog`).
**Deliverable:** Create from Library Playlists tab; rename / delete from detail overflow. Failure via `showApiError`.
**Test gate:** empty name disables confirm; overflow hidden for non-owner; rename calls notifier with name + public flag; delete requires confirmation then calls notifier.
**Done when:** analyze / test green. Manual: create → rename → delete verified on home server.
**Commit:** `feat(flutter): create / rename / delete playlists from the app`

### [x] M3. Add-to-playlist UX
**Files (modify):** `android/app/lib/widgets/library_result_tile.dart` (add `onLongPress`), `album_detail_screen.dart` (row long-press + AppBar "Add album to playlist…"), `playlist_detail_screen.dart` (row long-press), `library_screen.dart` (search-section rows long-press).
**Files (new):** `android/app/lib/widgets/add_to_playlist_sheet.dart` — modal bottom sheet: "Create new playlist…" row + list of owned playlists from `libraryPlaylistsProvider`.
**Deliverable:** Long-press any song in album detail / playlist detail / library search → add-to-playlist sheet. "Add album to playlist…" passes all song IDs.
**Test gate:** `onLongPress` fires correctly; sheet renders create-new + owned playlists; non-owned playlists filtered; `addSongs` / `createPlaylist` called with correct args.
**Done when:** analyze / test green. Manual: long-press song → pick playlist → row count updates.
**Commit:** `feat(flutter): add-to-playlist sheet — song row long-press + album-level entry`

### [x] M4. Edit mode — remove songs + reorder
**Files (modify):** `android/app/lib/screens/library/playlist_detail_screen.dart` — "Edit" toggle (hidden for non-owners); edit mode switches list to `ReorderableListView`; pending removes struck-through; commit computes diff and calls `removeSongsAtIndices` (pure removes) or `reorder` (any reorder); `WillPopScope` confirmation for unsaved edits.
**Deliverable:** In-app playlist editing complete — songs can be added (M3), removed (M4), reordered (M4), whole playlist renamed / deleted (M2).
**Test gate:** edit hidden for non-owner; pure-remove calls `removeSongsAtIndices` not `reorder`; reorder calls `reorder` once with new id order; cancel shows discard dialog.
**Done when:** analyze / test green. Manual: drag row, mark remove, tap Done, verify canonical state in Navidrome web UI.
**Commit:** `feat(flutter): playlist edit mode — remove + reorder`

### [x] M5. End-to-end smoke + docs
**Files (new):** `android/docs/smoke_playlists.md`, ADR in `DECISIONLOG.md`, entry in `CHANGELOG.md`.
**Files (modify):** `android/app/pubspec.yaml` → `1.2.1`. Tagged `v1.2.1`.
**Test gate:** manual 6-step smoke (create, add via long-press, add via album, rename + publish, edit reorder + remove, delete + offline failure).
**Done when:** all 6 steps pass. `flutter analyze` clean. `flutter test` green.
**Commit:** `chore(flutter): playlists e2e smoke verified`

**Roadmap closed: 2026-06-13.** M1–M4 shipped (`d6635be` → `4f1a74f`); polish (Favourites + heart toggle + `addSongs` client-side dedupe + visible add-to-playlist icon) shipped at `82b2654`. Tagged `v1.2.1`.

---

## Phase N — Recommendations

**Architecture note:** Pluggable `RecommendationEngine` on the backend (see `backend/docs/ROADMAP.md` Phase R). Android sends seeds from Navidrome play history; backend returns `[{title, artist, source_url}]`. Engine is swapped via `RECOMMENDATION_ENGINE` env var — the Android client never knows which engine is active. Dependency order: I1+I2 must land before N3; I4 before N5. N1 should be live for at least a week before I3/I5 are useful (Last.fm / ListenBrainz need scrobble history).

### [x] N1. Scrobble integration
**Files (modify):** playback provider (`audio_service` + `just_audio` integration from K-era) — hook position stream: on track start → `GET /rest/scrobble.view?id=<navidrome-song-id>&submission=false`; at ≥ 50% of track duration (once per play) → `GET /rest/scrobble.view?id=<id>&submission=true`. Both calls via existing `subsonicDioClientProvider`.
**Deliverable:** `scrobble.view` fires at the right thresholds. Navidrome forwards scrobbles to Last.fm if Last.fm is configured in Navidrome settings (one-time server-side config — set Last.fm API key + user credentials in Navidrome web UI / `navidrome.toml`; no heerr backend change required).
**Test gate:** 50% threshold fires; 49% does not; double-fire guard (once per play regardless of seeks); `submission=false` on track start; `submission=true` at threshold; correct `id` in both calls.
**Done when:** `flutter analyze` clean. `flutter test` green. Manual: play a song end-to-end, confirm Navidrome play count increments and (if Last.fm configured) Last.fm scrobble appears.
**Commit:** `feat(flutter): N1 — Subsonic scrobble.view integration at 50% playback`

### [x] N2. Seed collection provider
**Files (new):** `android/app/lib/models/seed_track.dart` (`freezed`: `title`, `artist`, `sourceUrl` — nullable), `android/app/lib/providers/recommendations.dart` (`seedCollectionProvider` `AsyncNotifier`).
**Deliverable:** `seedCollectionProvider` calls `getStarred2.view` + `getAlbumList2.view?type=frequent&size=30`, merges and deduplicates by `title+artist` (max 20, starred ranked first). Falls back to Favourites playlist entries (`libraryPlaylistsProvider`) if both calls return empty.
**Test gate:** mock Subsonic client returning starred + frequent results; assert merge order; assert dedup; assert Favourites fallback fires when both calls return empty.
**Done when:** `build_runner` / `analyze` / `test` green.
**Commit:** `feat(flutter): N2 — seed collection provider (starred + frequent + favourites fallback)`

### [x] N3. Recommendations provider + screen
**Files (new):** `android/app/lib/models/recommended_track.dart` (`freezed`: `title`, `artist`, `sourceUrl`), `android/app/lib/screens/recommendations_screen.dart`.
**Files (modify):** `android/app/lib/providers/recommendations.dart` (add `recommendationsProvider` `AsyncNotifier` — reads seeds from N2, calls `POST /api/v1/recommend` with seed list + `limit: 20`), `android/app/lib/router.dart` (add `/library/recommendations`), `android/app/lib/screens/library/library_screen.dart` (add "For You →" entry point below playlists section).
**Deliverable:** Recommendations screen showing title + artist per track, **Download** button (fires existing `downloadDispatcherProvider`), pull-to-refresh, loading/error states.
**Test gate:** `recommendationsProvider`: mock backend + mock seed provider; assert tracks returned. Widget test: Download triggers `downloadDispatcherProvider`; loading renders; error renders.
**Done when:** `build_runner` / `analyze` / `test` green. Manual: "For You" entry point visible, recommendations load from the backend.
**Commit:** `feat(flutter): N3 — recommendations screen + POST /recommend integration`

### [ ] N4. Library cross-reference + "Find similar" affordance
**Files (modify):** `android/app/lib/providers/recommendations.dart` (`recommendationsProvider` cross-references each result via `search3.view?query=<title+artist>&songCount=1`; match → `inLibrary: true`), `android/app/lib/models/recommended_track.dart` (add `inLibrary: bool`), `android/app/lib/screens/recommendations_screen.dart` (`inLibrary: true` rows show **Play** instead of **Download`).
**Files (new):** `manualSeedProvider` (`StateProvider<SeedTrack?>`).
**Deliverable:** "Find similar" long-press affordance on any song row in Library screens — sets `manualSeedProvider`, navigates to `/library/recommendations`. `recommendationsProvider` reads manual seed first; falls back to `seedCollectionProvider` if null.
**Test gate:** `inLibrary: true` row shows Play not Download; `inLibrary: false` shows Download; manual seed → `recommendationsProvider` uses it as sole seed; cross-reference mock match/no-match.
**Done when:** `analyze` / `test` green. Manual: long-press a library song → recommendations screen opens seeded with that song.
**Commit:** `feat(flutter): N4 — library cross-reference + Find Similar long-press`

### [ ] N5. Engine health indicator in Settings
**Files (modify):** `android/app/lib/screens/settings_screen.dart` (new "Recommendations" section below server profiles — shows engine name chip, `ok`→green / `degraded`→amber, `fallback_active` badge; tappable when degraded for inline help text), `android/app/lib/providers/recommendations.dart` (add `recommendHealthProvider` `AsyncNotifier` with 60s TTL — calls `GET /api/v1/recommend/health` on app resume and Settings screen open).
**Deliverable:** Settings shows which engine is active and whether it's healthy. Degraded state is actionable (user knows to check their API key or Tailscale).
**Test gate:** mock health `ok` → green chip renders; mock `degraded` + `fallback_active: true` → amber chip + badge visible.
**Done when:** `analyze` / `test` green.
**Commit:** `feat(flutter): N5 — engine health indicator in Settings`

---

## Cross-cutting reminders

- **`flutter analyze` green before declaring any milestone done.**
- **`flutter test` green before AND after each milestone.**
- **`dart run build_runner build --delete-conflicting-outputs` clean after every milestone touching `@freezed` / `@riverpod` annotations.**
- **No `print` in production code** — `debugPrint` only.
- **No `.env` files for the app** — all credentials live in `flutter_secure_storage`.
- **No backend change from Android phases** — each Android phase is a pure-client slice; any required backend endpoints ship in the corresponding backend roadmap first.
- **DECISIONLOG drift:** any contract / stack change → update `DECISIONLOG.md` + `PLAN.md` in the same commit (CLAUDE.md staleness rule).
- **Owner-only edits** — any new playlist mutation affordance added later must honour the `canEdit(Playlist, SettingsValue)` gate.
- **`MediaItem.id` is the playback URI** — keep it the `file://` URI when local, Subsonic stream URL when remote. Any deviation breaks offline playback.

---

## Out of scope

- iOS port.
- Light theme.
- Push notifications / FCM.
- Spotify SDK / OAuth on device.
- Admin endpoints (CLI-only on backend).
- Tablet / foldable layouts.
- Internationalisation.
- Offline mutation queue (mutations require online connectivity in v1).
- WorkManager / true background sync (foreground-only sync window in v1).
- Crossfade / gapless playback.
- Sleep timer, Cast, Lyrics, Equaliser.
- Persistence of "Now Playing" across app cold starts.
- Cover-art upload for playlists.
- Concurrent sync across multiple servers.

---

## Roadmap complete when

1. All milestone boxes checked (A1–G1, H1–K2, L1–L6, M1–M5, N1–N5).
2. Every test gate green at its milestone.
3. G1, K2, L6, M5 smokes succeeded; N-phase smoke verified after N5.
4. CHANGELOG entries exist for each milestone group.
5. `git log --oneline android/` reads as a clean A→N progression under the `feat(flutter):` / `chore(flutter):` Conventional-Commits cadence.
