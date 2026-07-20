# ROADMAP.md — heerr Android client implementation milestones

Track progress through the Android client build. Each milestone = one git commit with the test gate green where applicable. Tick the box when committed.

See `DECISIONLOG.md` for the *what*; this file is the *how* / *when*.

**Status (2026-07-11):** Phases A–Y complete. Phase Y (edit song metadata — title/album/artist + cover art, issue #44) shipped 2026-07-06 at `v4.6.2`; `v4.7.0` (2026-07-10) is the app-wide gradient redesign — magenta→purple→violet theme across every screen + the new 4x2 gradient hero home-screen widget (replaces the classic/bar/pill widgets); `v4.7.1` (2026-07-10) polishes the hero widget (album-art fade, tap-to-seek, redrawn logo/waveform) and adds the gradient Library tab indicator; `v4.7.2` (2026-07-10) fixes the widget idle icon to use the real app-icon mark and corrects the tab indicator's fade extension; `v4.7.3` (2026-07-11) removes a leftover ghost ring from the widget icon, enlarges it 20%, and makes the tab indicator's faint line span the full selected tab; `v4.7.4` (2026-07-11) fixes the idle-state prompt's line break so "Start listening" / "to your music" wrap as in the reference instead of an uneven mid-word split; `v4.8.0` (2026-07-11) is the Home Screen redesign (HOMESCREEN.md) — branded header, Continue Listening hero card, Quick Access row, Recently Added section + see-all screen, Favorites screen, MiniPlayer restyle, and per-song adaptive art theming (Part B); `v4.8.1` (2026-07-11) fixes a layout bug where the hero card's unbounded-height Row killed every section below it while a track was live, squares off the search pill's corner radius, makes the MiniPlayer waveform an animated brand-gradient equalizer (reusing the home-screen widget's look), and softens the MiniPlayer border to a thin grey hairline; `v4.8.2` (2026-07-11) fixes the hero card's progress-bar fill (zero-height bug, always broken), restyles the card to match the mockup (hairline border, no full-card art backdrop, outlined play ring, progress knob, +15% art width), and repoints Favorites from the Subsonic star primitive to the real Favourites playlist; `v4.8.3` (2026-07-11) removes the home-screen App Widget's gradient border and fixes the Flutter waveform (MiniPlayer + hero card) to anchor bars at the baseline, matching the widget's own waveform look; `v4.8.4` (2026-07-11) fades the hero card's album-art edge into the card background (mirroring the widget's own art fade) and makes the hero card's progress bar tap/drag-seekable instead of display-only; `v4.8.5` (2026-07-11) fixes the hero card's progress bar rendering centred instead of left-anchored, and merges `redesign/home-screen` into `main`; `v4.9.0` (2026-07-11) is the Profile screen redesign (Phase Z) — display/edit split (`/profile` display screen, `/profile/edit` form), server-derived Playlists/Songs/Albums/Artists stats row, "My Music" quick-links (Liked Songs, Downloaded, Recently Played, Playlists) with a new recently-played screen, "Settings" section with About/Help dialogs and a log-out flow, and a Settings-tab profile card entry point alongside the existing Home avatar; `v4.10.0` (2026-07-11) is the Library screen redesign (Phase X, LIBRARYSCREEN.md) — shared branded header, "Your Library" headline, Albums/Artists/Playlists segmented tabs, per-tab sort + Downloaded filter chips, albums grid with offline badges, A–Z index scrubber, artist rows with a Most Played rail, and playlist cards with Favorites + Create Playlist tiles; `v4.11.0` (2026-07-11) is the Now Playing screen redesign (Phase NP, NOWPLAYING.md) — blurred-art immersive background, glass header, glowing hero art with on-art download-state button, waveform seek bar replacing the Material `Slider`, transport tap-scale polish, glass action pill (Queue/Lyrics/Timer/Add to playlist), lyrics peek-sheet restyle with a gradient active-line highlight, sectioned queue sheet (Now Playing/Next Up), and a reduced-scope swipe-up-to-lyrics gesture (NP10 — see DECISIONLOG for the scoping rationale); `v4.11.1` (2026-07-12) is a Now Playing + Profile fix pass against the source mockup — Profile Liked Songs/Recently Played rows fixed (go_router duplicated-page-key crash on push from a pushed /profile), lyrics active line always magenta with a leading-words-pink gradient, expanded lyrics sheet rebuilt on the blurred-art glass language, and a lighter scrim + always-on doubled brand glow for the mockup's magenta atmosphere; `v4.11.2` (2026-07-12) fixes the Library/Playlists Favorites tile to show its song count — it was reading the deprecated Subsonic star primitive (`starredSongsProvider`) instead of the real `Favourites` Navidrome playlist that favoriting now writes to; `v4.12.0` (2026-07-12) is the Downloads screen redesign ("Sync Center", Phase DL, DOWNLOADSSCREEN.md) — server-status hero with animated waveform sync progress, Sync Now / Manage Storage quick actions, sync-activity cards (Downloading/Queued/Waiting-for-Wi-Fi or Failed), Songs-first segmented tabs with per-tab filter chips, metadata-rich song rows ("Lossless • Yesterday • 24 MB") with a kebab delete menu, a real on-disk storage breakdown card, and a unified empty state when nothing is downloaded; `v4.12.1` (2026-07-12) is a Downloads hero fix pass — the "Online" status pill now renders in a new status-only green (`heerrOnlineGreen`, an isolated exception to the brand palette) and the placeholder server-rack `CustomPaint` illustration is replaced with the user-supplied artwork (`assets/images/downloads_server.png`); `v4.13.0` (2026-07-12) is the Settings screen redesign ("Control Center", Phase SE, SETTINGSSCREEN.md) — shared branded header (no greeting) + "Settings" headline, a floating restyled ProfileCard, a promoted Server & Sync card (Online status + inline Sync Now, superseding the old inline offline-section button), a reusable `SettingsGroupCard`/`SettingsTile` system replacing every collapsible `ExpansionTile` with flat always-visible cards, and an About footer (version, open-source licenses, GitHub link, tagline). Every mockup row with no real data source (Audio Quality, Equalizer, Appearance, Notifications, Language, Devices, Backup, Import Music) was dropped rather than shipped as a placeholder (D1). `v4.14.0` (2026-07-13) is a Play-compliance hardening pass — recommendation cover art now comes from the backend's new `cover_url` field (client-side source-URL parsing deleted), and the Settings engine name is mapped to a generic display label. `v4.14.1` (2026-07-13) is a backend-only mypy type fix (no Android changes; version bumped for sync). `v4.14.2` (2026-07-13) is a CI-only release — the tag-publish workflow now also builds and attaches the Play Console AAB (no app code changes; version bumped for sync). `v4.14.3` (2026-07-13) fixes an ANR ("heerr isn't responding") triggered by rapid/double taps on a Play button — `HeerrAudioHandler.playSong`/`playAll`/`restoreQueue` now guard against overlapping `setAudioSources` calls on the shared ExoPlayer instance, which previously leaked a MediaCodec whose async callback thread froze the UI thread. `v4.14.4` (2026-07-13) is a Downloads hero fix pass against the source mockup — the server illustration is now a full-bleed hero image (~35-40% of the card width, flush to its left/top/bottom edges) instead of a small 72px circular thumbnail, and `OfflineSync` now publishes a `running: true` status with live target/ready counts while a tick is in flight (previously `running` was always `false`, so the hero's sync-progress bar and "N songs remaining" line never rendered). `v4.14.5` (2026-07-13) is a second Downloads hero fix pass plus a "Clear all downloads" reliability fix — the hero's left-side rounded corners now use an explicit `ClipRRect` (the ambient `Container` clip rounded correctly in a Skia golden render but reportedly missed on-device Impeller/OpenGLES) with a `ShaderMask` edge-fade matching the Home hero card's own art fade, and "Clear all downloads" no longer needs multiple taps — the per-server directory tree is written by several independent concurrent writers (sync downloader, cover art, lyrics, library cache), any of which could race `Directory.delete(recursive: true)` and trip "Directory not empty"; the delete now pauses sync first and retries on `FileSystemException`. `v4.14.6` (2026-07-13) fixes a black screen opening the app from the home-screen widget — `main()` no longer blocks `runApp()` on `Workmanager().initialize()` (safe to defer; its only consumer fires from lifecycle transitions, which can't happen before the tree exists), and the launch splash shows the heerr gradient mark instead of the stock Flutter template's flat black/`colorBackground` drawable, so any remaining native-init delay (`AudioService.init()`, which still blocks `runApp()` and is the likely dominant contributor, especially under Android's background-activity-start throttling on a widget-triggered cold start) reads as "loading" instead of "broken." `v4.14.7` (2026-07-13) is a third Downloads hero fix pass — the server illustration width is bumped 5% (130px → 137px) to match the source mockup's proportions, and the illustration asset itself is replaced with a new higher-resolution render supplied by the user (Android-side only — no backend changes; version bumped for sync). `v4.14.8` (2026-07-14) is a home-screen widget resize pass — the idle/playing Previous/Next buttons are enlarged 20%, the Play/Pause button 30%, and the flat divider next to the heerr logo is replaced with a tapered `heerrGradient`-colored bar that fades out at its end (Android-side only — no backend changes; version bumped for sync). `v4.14.9` (2026-07-14) fixes the widget divider to taper and fade at both the top and bottom (was bottom-only) (Android-side only — no backend changes; version bumped for sync). `v5.0.0` (2026-07-20) is the backend's Phase P — podcasts (#53); the Android client (Phase PC) is not yet built — version bumped for sync per `/CLAUDE.md` §3. Phase PC (PC1–PC5 — podcast models/API client, Discover, Subscriptions + Channel episode list, episode download via the Queue screen, and player integration + resume-position sync) shipped 2026-07-20 against that same `v5.0.0`; no on-device manual smoke was performed (no `adb` device connected). `v5.0.1` (2026-07-20) is a backend-only fix — podcast discovery swapped from Podcast Index to Apple's iTunes Search API after Podcast Index's signup form began rejecting free-email-provider addresses; the client-visible search contract is unchanged, so no Android code changed (version bumped for sync). `v5.0.2` (2026-07-20) adds a "subscribe by feed URL" affordance to the Discover screen — `POST /podcasts/subscribe` has always accepted a raw `feed_url`, so a show that isn't surfaced by search (or whose URL the user already has) can be subscribed directly, without a backend change. `v5.1.0` (2026-07-20) is Phase PR1 (#53) — podcasts move into Library as a first-class content switch (Music/Podcasts, with Shows/Episodes/Downloads sub-tabs; Episodes/Downloads are placeholders pending backend Phase PA), a new `PodcastShowDetailScreen` replaces the plain `ChannelScreen` (hero art, Continue/Following actions, client-derived Continue Listening + Latest Episode mini-sections, Episodes/About tabs), and episode rows gained leading art + a gradient progress bar. Android-only — no backend changes (version bumped for sync). `v5.2.0` (2026-07-20) is Phase PR2 (#53) — the podcast player redesign: `HeerrAudioHandler` gained `setSpeed`/`skipBack30`/`skipForward30`; the Now Playing screen now branches on `isEpisodeMediaItem` to render a podcast layout (plain position/duration scrubber instead of the waveform, skip-back-30/play-pause/skip-forward-30 transport, a tappable show-name link, and a Queue/Speed/Timer action pill — Lyrics and Add to playlist dropped, neither applies to a single episode). Chapters/Transcript/Notes/Bookmark and the show "Related" tab are out of scope (no backing data). Android-only — no backend changes (version bumped for sync).

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
**Deliverable:** Real APK on the Pixel reaches the backend on the home server (via Tailscale), searches the online catalog, dispatches a download, watches the queue, and confirms the file lands in Navidrome.
**Test gate:** manual; the 7-step verification block in PLAN §12.
**Done when:** all 7 PLAN §12 steps pass.
**Commit:** `chore(flutter): e2e smoke verified`

---

## Phase H — Subsonic foundation

**Architecture note:** heerr backend stays unchanged. The Android app gains a second backend connection (Navidrome's Subsonic API) for library browse + streaming + cover art. The existing standalone "Search" bottom-nav tab is removed at I1; its online-search functionality folds into the new Library tab as a fallback source (library-first; online only when library is empty or the user taps "Search more"). Bottom nav goes from `Search · Queue · Settings` → `Library · Queue · Settings`.

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

**Deliverable:** `combinedSearchProvider(query)` — library fires on every debounced keystroke; online search fires only when library result is empty (auto-fire) or user taps "Search online". Reactive promotion: `queueProvider` watches for `done` transitions on online-search URIs in the results → after 60s grace calls `ref.invalidate(librarySearchProvider)`.

**Test gate:** provider unit tests for all firing rules, cancellation, and reactive promotion. Widget tests for library-only / auto-YT / manual-YT / both-empty renders.

**Done when:** all provider + widget tests green; `grep -r searchResultsProvider android/app/lib` empty.
**Commit:** `feat(flutter): combined library + online search with reactive promotion`

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
**Files (modify):** `android/app/pubspec.yaml` → `1.1.0`. ADR in `DECISIONLOG.md`.
**Test gate:** manual 7-step smoke (settings baseline, mark album, offline playback, offline navigation, fallback-to-stream, unmark+sweep, sync-all).
**Done when:** all 7 steps pass. `pubspec.yaml` at `1.1.0`. Tagged `v1.1.0`.
**Commit:** `chore(flutter): offline e2e smoke verified`

**Roadmap closed: 2026-06-12.** Offline feature live at `1.1.0` / `v1.1.0`. Smoke verified informally on-device.

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
**Files (modify):** `android/app/pubspec.yaml` → `1.2.1`. ADR in `DECISIONLOG.md`. Tagged `v1.2.1`.
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

### [x] N4. Library cross-reference + "Find similar" affordance
**Files (modify):** `android/app/lib/providers/recommendations.dart` (`recommendationsProvider` cross-references each result via `search3.view?query=<title+artist>&songCount=1`; match → `inLibrary: true`), `android/app/lib/models/recommended_track.dart` (add `inLibrary: bool`), `android/app/lib/screens/recommendations_screen.dart` (`inLibrary: true` rows show **Play** instead of **Download`).
**Files (new):** `manualSeedProvider` (`StateProvider<SeedTrack?>`).
**Deliverable:** "Find similar" long-press affordance on any song row in Library screens — sets `manualSeedProvider`, navigates to `/library/recommendations`. `recommendationsProvider` reads manual seed first; falls back to `seedCollectionProvider` if null.
**Test gate:** `inLibrary: true` row shows Play not Download; `inLibrary: false` shows Download; manual seed → `recommendationsProvider` uses it as sole seed; cross-reference mock match/no-match.
**Done when:** `analyze` / `test` green. Manual: long-press a library song → recommendations screen opens seeded with that song.
**Commit:** `feat(flutter): N4 — library cross-reference + Find Similar long-press`

### [x] N5. Engine health indicator in Settings
**Files (modify):** `android/app/lib/screens/settings_screen.dart` (new "Recommendations" section below server profiles — shows engine name chip, `ok`→green / `degraded`→amber, `fallback_active` badge; tappable when degraded for inline help text), `android/app/lib/providers/recommendations.dart` (add `recommendHealthProvider` `AsyncNotifier` with 60s TTL — calls `GET /api/v1/recommend/health` on app resume and Settings screen open).
**Deliverable:** Settings shows which engine is active and whether it's healthy. Degraded state is actionable (user knows to check their API key or Tailscale).
**Test gate:** mock health `ok` → green chip renders; mock `degraded` + `fallback_active: true` → amber chip + badge visible.
**Done when:** `analyze` / `test` green.
**Commit:** `feat(flutter): N5 — engine health indicator in Settings`

---

## Phase O — Home screen

**Architecture note:** Pure-Android slice. No heerr backend changes — recommendations reuse the existing `POST /api/v1/recommend` endpoint; recently-played / most-played / random-songs come from Navidrome Subsonic (`getAlbumList2`, `getRandomSongs`). Bottom nav becomes `Home · Library · Downloads · Settings` (Queue tab dropped — Queue is now reachable via a `queue_music_outlined` IconButton in the Home AppBar). Default boot tab changes from Library to Home. Design target: a familiar streaming-app home — time-of-day greeting, 2-column quick-access grid, horizontal-scroll sections, large "Picked for you" cards.

### [x] O1. Nav restructure — add Home tab
**Files (new):** `android/app/lib/screens/home/home_screen.dart` (scaffold + greeting + Queue shortcut).
**Files (modify):** `android/app/lib/router.dart` (`Routes.home = '/'`; `Routes.library` now `/library`; library nested routes lose the `library/` prefix but `Routes.libraryArtist(id)` / `libraryAlbum` / `libraryPlaylist` helpers preserve the public URL shape; tabs become **Home / Library / Downloads / Settings** — Queue dropped from the nav and surfaced as an AppBar IconButton on Home).
**Deliverable:** App boots to Home tab. Bottom nav shows four destinations. Home scaffold renders a time-of-day greeting string (`"Good morning"` / `"Good afternoon"` / `"Good evening"` based on device hour) + a `queue_music_outlined` IconButton in the AppBar that routes to `/queue` — no data yet.
**Test gate:** router test asserts 4 tabs and default boot to `/home`; unit test for greeting-string helper (morning 5–11, afternoon 12–17, evening 18–4).
**Done when:** `flutter analyze` clean; `flutter test` green; device shows 4-tab nav booting to Home with greeting.
**Commit:** `feat(flutter): O1 — home tab + 4-tab nav restructure`

### [x] O2. Home data providers
**Files (new):** `android/app/lib/providers/home/home_providers.dart`.
- `homeRecentProvider` (`FutureProvider`): `getAlbumList2.view?type=recent&size=8` via `subsonicDioClientProvider`. Returns `List<Album>`.
- `homeMostPlayedProvider` (`FutureProvider`): `getAlbumList2.view?type=frequent&size=8`. Returns `List<Album>`.
- `homeRandomSongsProvider` (`FutureProvider`): `getRandomSongs.view?size=20`. Returns `List<Song>`.
- `homeRecommendationsProvider` (`FutureProvider`): thin wrapper — reads `recommendationsProvider`; falls back to `homeRandomSongsProvider` when result list is empty (maps random songs to `RecommendedTrack` shape for uniform rendering).
**Test gate:** mock Subsonic; assert correct endpoint + query params for each provider; assert `homeRandomSongsProvider` is used when `homeRecentProvider` + `homeMostPlayedProvider` both return empty; assert `homeRecommendationsProvider` falls back to random songs when recommendations list is empty.
**Done when:** `build_runner` / `analyze` / `test` green.
**Commit:** `feat(flutter): O2 — home data providers (recent, frequent, random, recommendations)`

### [x] O3. Home screen — quick-access grid + horizontal sections
**Files (new):** `android/app/lib/widgets/home_grid_tile.dart` (compact 2-col tile: 56 px square cover art flush-left + album/playlist name, dark surface, reference-app style), `android/app/lib/widgets/home_section.dart` (section header text + horizontal `ListView.builder` of square cover-art cards with title below).
**Files (modify):** `android/app/lib/screens/home/home_screen.dart`:
- Greeting row at top (time-of-day string).
- **Quick-access grid:** 2-column `GridView` of up to 6 recently-played albums (`homeRecentProvider`). Fallback: when recent is empty, show top-6 `homeRecommendationsProvider` results in the same grid layout.
- **"Jump back in" section:** `HomeSection` horizontal scroll of `homeRecentProvider` albums.
- **"Most played" section:** `HomeSection` horizontal scroll of `homeMostPlayedProvider` albums.
- All sections use `SkeletonList` while loading and `EmptyState` if both the primary and fallback are empty.
**Test gate:** widget tests for `HomeGridTile` (cover art renders, title truncates); `HomeSection` (loading / data / empty / error); home screen grid fallback triggers when recent is empty; Most played section renders.
**Done when:** `analyze` / `test` green; device shows greeting + grid + two horizontal sections with real Navidrome data.
**Commit:** `feat(flutter): O3 — home quick-access grid + jump back in + most played sections`

### [x] O4. Home screen — "Picked for you" recommendations section
**Files (new):** `android/app/lib/widgets/home_recommendation_card.dart` (vertical card ~160 px wide: square cover art top, title, artist, Download/Play action button at bottom; cover art resolved via `search3.view?query=<artist> <title>&songCount=1` — reuse N4 cross-reference pattern; fallback to a placeholder if no match).
**Files (modify):** `android/app/lib/screens/home/home_screen.dart`:
- **"Picked for you" section:** `HomeSection` horizontal scroll of `HomeRecommendationCard`s from `homeRecommendationsProvider`.
- Card action: `inLibrary: true` → **Play** (routes to `playSongFromSubsonic`); `inLibrary: false` → **Download** (fires `downloadDispatcherProvider`).
- Fallback label: when `recommendationsProvider` returned empty and random songs are being shown, section header reads `"Discover"` instead of `"Picked for you"`.
**Test gate:** widget test for `HomeRecommendationCard` (Play renders when `inLibrary: true`, Download when `false`); Download fires `downloadDispatcherProvider`; section header reads `"Discover"` on fallback path; cover-art miss falls back to placeholder gracefully.
**Done when:** `build_runner` / `analyze` / `test` green; device shows recommendations cards with correct action buttons.
**Commit:** `feat(flutter): O4 — picked for you recommendations section + discover fallback`

### [x] O5. Routing + pull-to-refresh + smoke
**Files (modify):** `android/app/lib/screens/home/home_screen.dart`:
- Wrap entire screen in `RefreshIndicator` + `CustomScrollView`; on drag invalidates `homeRecentProvider`, `homeMostPlayedProvider`, `homeRandomSongsProvider`, `homeRecommendationsProvider`.
- Tap on album tile → `/library/album/:id`; tap on artist → `/library/artist/:id`; tap on playlist tile → `/library/playlist/:id`.
- Full-empty state (all four providers empty): `EmptyState("Nothing here yet — play some music to get started")`.
**Files (modify):** `android/app/pubspec.yaml` → `1.4.0`.
**Test gate:** tap-routing widget tests (album/artist/playlist tiles push correct routes); pull-to-refresh triggers all four provider invalidations; full-empty state renders correctly.
**Done when:** `flutter analyze` clean; `flutter test` green; manual smoke on home server — home screen loads with real Navidrome data, taps route correctly, recommendations load, download dispatches from home card, pull-to-refresh refreshes all sections. Tagged `v1.4.0`.
**Commit:** `chore(flutter): O5 — home screen routing + pull-to-refresh + v1.4.0 smoke`

---

## Phase P — Player polish (v1.5.0)

**Architecture note:** Three independent player UX improvements, bundled as the v1.5.0 polish ship: persisted Now Playing across cold starts (X2), Subsonic lyrics (X3), sleep timer (X4a). Pure-Android slice; no backend change. Each milestone is independent — they ship together only because the bundle is the version's marketing story. See `DECISIONLOG.md` 2026-06-15 ("v1.5.0 player polish band") for the re-scoping rationale.

### [x] P1. Persist Now Playing across cold starts
**Files (new):** `android/app/lib/player/queue_persistence.dart`.
**Files (modify):** `android/app/lib/player/heerr_audio_handler.dart` (restore-on-init), `android/app/lib/main.dart` (await restore before `runApp`).
**Storage:** `<appDocs>/now_playing.json`, atomic write (tmp + rename, same pattern as `offline_manifest.dart` from L1).
**Schema:** `{songs: [Song], currentIndex: int, positionMs: int, updatedAt: int}`.
**Save triggers:** debounced 500 ms on play/pause/skip/seek; flush on `AppLifecycleState.paused`.
**Restore behaviour:** cold start parses file → mini-player appears with last-played track at saved position; **does not auto-play** (tap-to-resume keeps user in control).
**Test gate:** unit tests for persistence round-trip + corrupt-file fallback (empty queue, not crash); handler integration test with stub `AudioPlayer` asserts restore reaches `MediaItem` queue without firing `play()`.
**Done when:** `analyze` / `test` green; on-device verification deferred to P4 smoke.
**Commit:** `feat(flutter): P1 — persist Now Playing across cold starts`

### [x] P2. Lyrics
**Files (new):** `android/app/lib/models/subsonic/lyrics.dart`, `android/app/lib/providers/library/lyrics.dart`.
**Files (modify):** `android/app/lib/api/subsonic_endpoints.dart` (new `getLyrics` constant `/rest/getLyrics.view`), `android/app/lib/screens/player/now_playing_screen.dart` (AppBar toggle + lyrics sheet).
**Behaviour:** AppBar toggle flips Now Playing between cover-art view and a scrollable plain-text lyrics view. Empty state ("No lyrics for this track") when Navidrome returns code 70.
**Test gate:** provider tests cover envelope-parse success, missing-lyrics (code 70 → empty state, no error), other Subsonic errors map to `ApiError`. Widget test asserts toggle swaps panes and lyrics scroll.
**Done when:** `build_runner` / `analyze` / `test` green.
**Commit:** `feat(flutter): P2 — Subsonic lyrics in Now Playing`

### [x] P3. Sleep timer
**Files (new):** `android/app/lib/player/sleep_timer.dart` — keep-alive notifier holding `Duration?` remaining + an internal `Timer`, ticking 1 s.
**Files (modify):** `android/app/lib/screens/player/now_playing_screen.dart` (overflow menu → "Sleep timer" → bottom sheet with 15 / 30 / 45 / 60 / Off / Custom options).
**Behaviour:** Setting a duration starts the timer; ticks render in the AppBar as a small countdown chip. On expiry → `playerProvider.notifier.pause()`. Survives app background; does not survive cold start (intentional — sleep timers are session-scoped).
**Test gate:** `fake_async` tests for countdown / cancel / expiry-fires-pause / custom-duration; widget test asserts chip appears when timer active.
**Done when:** `analyze` / `test` green.
**Commit:** `feat(flutter): P3 — sleep timer`

### [x] P4. v1.5.0 smoke + version bump
**Files (modify):** `android/app/pubspec.yaml` → `1.5.0`. DECISIONLOG ADR + CHANGELOG entry.
**Test gate:** manual on-device smoke — P1 (queue restored after cold start, tap-to-resume from saved position); P2 (lyrics toggle works on tracks with + without lyrics in Navidrome); P3 (15-min timer pauses playback at expiry).
**Done when:** all three smokes pass. Tagged `v1.5.0`.
**Commit:** `chore(flutter): v1.5.0 player polish smoke verified`

---

## Phase Q — Background offline sync (v2.0.0)

**Architecture note:** Lifts the L-phase "foreground-only sync window" limitation by adding a `WorkManager`-driven periodic worker that calls into the existing `OfflineSync` notifier code path. Atomic manifest writes from L1 already protect against concurrent foreground / background races — Q1 verifies the invariant under contention. Pure-Android slice; no backend change. See `DECISIONLOG.md` 2026-06-15 ("v2.0.0 — background offline sync") for the full ADR.

### [x] Q1. WorkManager integration + worker entry point
**Files (new):** `android/app/lib/offline/background_sync.dart` — periodic worker that creates a Riverpod container, calls `offlineSyncProvider.syncNow()`, then disposes.
**Files (modify):** `android/app/pubspec.yaml` (add `workmanager: ^0.5`), `android/app/android/app/src/main/AndroidManifest.xml` (add `RECEIVE_BOOT_COMPLETED` permission + WorkManager `Initializer`), `android/app/lib/main.dart` (`Workmanager().initialize(...)` before `runApp`).
**Test gate:** worker entry-point unit test with stub `Dio` + stub manifest — assert the same `OfflineSync.syncNow()` code path runs; assert atomic-write invariant holds when foreground + background both touch the manifest in sequence.
**Done when:** `build_runner` / `analyze` / `test` green.
**Commit:** `feat(flutter): Q1 — workmanager integration + background worker`

### [x] Q2. Constraints + policies
**Files (modify):** `android/app/lib/offline/background_sync.dart` (translate settings → `Constraints`), `android/app/lib/providers/settings.dart` (new `offline_charging_only` key), `android/app/lib/screens/settings_screen.dart` ("Charging only" toggle in Offline section).
**Behaviour:** `offline_wifi_only` → `Constraints.NetworkType.UNMETERED`. `offline_charging_only` → `Constraints.requiresCharging`. Periodic interval matches existing `offline_poll_interval_min` (default 60 min, min 15 enforced by WorkManager).
**Test gate:** constraint-derivation unit tests covering each settings permutation.
**Done when:** `analyze` / `test` green.
**Commit:** `feat(flutter): Q2 — background sync constraints + charging-only`

### [x] Q3. Foreground / background interlock
**Files (modify):** `android/app/lib/router.dart` (`_ShellScaffoldState.didChangeAppLifecycleState`), `android/app/lib/offline/background_sync.dart` (cancel + reschedule helpers).
**Behaviour:** On foreground resume, cancel any in-flight background work to avoid double-downloads. On app background, if any markers are pending sync, schedule the worker for the next interval.
**Test gate:** handoff state-machine tests — verify cancel-on-resume and schedule-on-background fire in the right order; verify the manifest is the single source of truth so a cancelled mid-flight download leaves no orphan state.
**Done when:** `analyze` / `test` green.
**Commit:** `feat(flutter): Q3 — foreground/background sync interlock`

### [x] Q4. v2.0.0 smoke + version bump
**Files (modify):** `android/app/pubspec.yaml` → `2.0.0`. DECISIONLOG ADR + CHANGELOG entry.
**Test gate:** manual smoke — mark an album, background the app, leave for one polling interval, observe completed downloads via the Downloads tab on re-open. Toggle WiFi off → worker skips run; toggle on → worker resumes. Charging-only toggle gates correctly on the device's charger state.
**Done when:** smoke passes. Tagged `v2.0.0`.
**Commit:** `chore(flutter): v2.0.0 background sync smoke verified`

---

## Phase R — Gapless playback (v2.1.0)

**Architecture note:** Single-flag fix. The codebase already uses `setAudioSources(List<AudioSource>)` (just_audio's modern playlist primitive). The audible inter-track gap was caused by `just_audio`'s `AudioPlayer({useLazyPreparation = true, ...})` default — subsequent sources are not prepared until ExoPlayer needs them. Flipping the constructor flag to `false` lets ExoPlayer pre-prepare the next renderer and perform its native gapless hand-off. See `DECISIONLOG.md` 2026-06-16 ("X4b: gapless playback via `useLazyPreparation: false`") for full rationale.

### [x] R1. Gapless via `useLazyPreparation: false`
**Files (modify):** `android/app/lib/player/heerr_audio_handler.dart` (`AudioPlayer(useLazyPreparation: false)` in the default-constructor path), `android/app/pubspec.yaml` → `2.1.0`. ADR + CHANGELOG entry.
**Test gate:** existing handler / persistence / scrobble / sleep-timer suites stay green. No new tests — the flag is a constructor-side toggle that the stub-player tests don't exercise.
**Done when:** `flutter analyze` clean; `flutter test` green; on-device smoke (`v2.1.0` build → play an album with tracks mixed to flow together → no gap between rows; skip-next / pause / resume still behave; lock-screen + notification still update on track change). Tagged `v2.1.0` after smoke.
**Commit:** `feat(flutter): R1 — gapless playback via useLazyPreparation: false`

---

## Phase S — Multi-user profiles via Navidrome IdP (v3.0.0)

**Architecture note:** Multi-user on a single shared device. Identity is delegated to Navidrome through the backend's new `POST /api/v1/auth/login` (backend Phase J). Each "profile" on the device = one `{heerr-base-url, heerr-bearer-token, navidrome-base-url, navidrome-username, navidrome-password}` tuple in `flutter_secure_storage`. **Hard logout / login** model — only one active profile at a time. The existing `serverKey = sha256(baseUrl + "|" + username).hex[0..16]` chokepoint (from L1) already keys offline downloads, library cache, and manifest paths by `(baseUrl, username)`, so profile-switch transparently swaps offline state — no byte migration. Overrides the "Single-user. No multi-user login, no Sign-In-With-X" hard rule in `android/CLAUDE.md`; the new ADR (S10) carves Navidrome out as the one permitted IdP because heerr stores no password. **Depends on backend J6** (`POST /auth/login`) — S5 cannot land before J6 ships.

### [x] S1. `Profile` freezed model + tests
**Files (new):** `android/app/lib/models/profile.dart`, `android/app/test/models/profile_test.dart`.
**Deliverable:** `Profile(id, displayName, heerrBaseUrl, heerrBearerToken, navidromeBaseUrl, navidromeUsername, navidromePassword, createdAt, lastUsedAt)` freezed + json_serializable. Round-trip `fromJson(toJson(x)) == x`.
**Test gate:** unit test for serialization + `copyWith` round-trip.
**Done when:** `build_runner` clean; model round-trip green.
**Commit:** `feat(flutter): S1 — Profile freezed model`

### [x] S2. Profile registry — secure-storage layout + provider
**Files (new):** `android/app/lib/providers/profiles/profile_registry.dart`, `android/app/test/providers/profiles/profile_registry_test.dart`.
**Deliverable:** `profileRegistryProvider` reads/writes `profiles_index.json` (list of `Profile`s) + an `active_profile_id` pointer to `flutter_secure_storage` under fixed keys. Mutators: `addProfile`, `removeProfile(id)`, `setActive(id)`, `bumpLastUsed(id)`. No legacy migration yet (S3 owns that).
**Test gate:** unit tests using `flutter_secure_storage`'s test backend; add → list → remove round-trip; active-pointer survives reload.
**Done when:** read-after-write parity for both keys; remove-active sets active to null.
**Commit:** `feat(flutter): S2 — profile registry backed by secure storage`

### [x] S3. Legacy-creds migration shim → default profile
**Files modified:** `android/app/lib/providers/profiles/profile_registry.dart`, `android/app/lib/main.dart` (call migration before `runApp`).
**Files new:** `android/app/lib/providers/profiles/legacy_migration.dart`, `android/app/test/providers/profiles/legacy_migration_test.dart`.
**Deliverable:** On first launch post-upgrade, detect "no `profiles_index.json` but legacy single-set creds exist in `flutter_secure_storage`" → wrap them as a `Profile(id: <uuid>, displayName: <navidromeUsername || 'default'>, ...)`, write to the registry, set as active, then delete the legacy single-set keys. Idempotent — running twice leaves state unchanged.
**Test gate:** legacy-state seed → migration → assert profile created + active + legacy keys cleared; no-legacy seed → migration no-ops; already-migrated seed → no-ops.
**Done when:** every existing v2.1.0 user can upgrade silently.
**Commit:** `feat(flutter): S3 — migrate legacy single-set creds to default profile`

### [x] S4. Login API client — `POST /auth/login`
**Files new:** `android/app/lib/api/auth_login.dart`, `android/app/test/api/auth_login_test.dart`.
**Files modified:** `android/app/lib/api/endpoints.dart` (add `authLogin` constant).
**Deliverable:** `authLogin(baseUrl, username, password) -> AuthLoginResponse(token, scopes, navidromeUrl, navidromeUsername)` via the existing heerr dio (constructed ad-hoc without an auth interceptor — login has no token yet). Maps backend statuses to `ApiError` (401 bad creds, 503 Navidrome unreachable).
**Test gate:** `DioAdapter` covers happy + 401 + 503 + network failure paths.
**Done when:** typed `ApiError` for each branch; happy path parses the response payload.
**Commit:** `feat(flutter): S4 — auth login API client`

### [x] S5. Login screen UI
**Files new:** `android/app/lib/screens/auth/login_screen.dart`, `android/app/test/screens/auth/login_screen_test.dart`.
**Files modified:** `android/app/lib/router.dart` (add `/login` route; redirect to it when `active_profile_id` is null).
**Deliverable:** Form with three fields (heerr base URL, Navidrome username, Navidrome password) + "Sign in" button. On submit calls S4; on success constructs a `Profile` (uses `navidromeUrl` from the response so the user doesn't paste it), calls `profileRegistry.addProfile` + `setActive`, navigates to `/`. Error UX routes through existing `reactToApiError`.
**Test gate:** widget test for happy / 401 / 503 / network-failure branches; redirect-to-login asserted when no active profile.
**Done when:** fresh-install boots into login; valid creds land the user on Home.
**Commit:** `feat(flutter): S5 — login screen + first-launch redirect`

### [x] S6. Active-profile provider — single source of truth
**Files new:** `android/app/lib/providers/profiles/active_profile.dart`, `android/app/test/providers/profiles/active_profile_test.dart`.
**Deliverable:** `activeProfileProvider` exposes the currently-active `Profile?` derived from the registry. Replaces direct reads of `settingsProvider` for any field that's now per-profile (heerr URL/token + Navidrome URL/user/pass). `settingsProvider` keeps non-profile keys (offline toggles, sleep-timer defaults).
**Test gate:** active-switch invalidates dependents; null-active → dependents see null.
**Done when:** every per-server provider derives from `activeProfileProvider`.
**Commit:** `feat(flutter): S6 — active profile provider`

### [x] S7. Wire dio + Subsonic clients to active profile
**Files modified:** `android/app/lib/api/client.dart` (heerr dio reads `activeProfileProvider`), `android/app/lib/api/subsonic_client.dart` (Subsonic dio reads `activeProfileProvider`), `android/app/lib/api/subsonic_auth_interceptor.dart`, `android/app/test/api/client_test.dart`, `android/app/test/api/subsonic_client_test.dart`.
**Deliverable:** Both dio clients rebuild whenever the active profile changes. Bearer interceptor uses `activeProfile.heerrBearerToken`. Subsonic interceptor uses `activeProfile.navidromeUsername` + `.navidromePassword`. No call site changes.
**Test gate:** existing client tests stay green; new tests assert profile-switch rebuilds the dio with the new credentials.
**Done when:** every API call uses the active profile's creds.
**Commit:** `feat(flutter): S7 — dio + Subsonic clients keyed off active profile`

### [x] S8. Verify per-server isolation chokepoints honour the active profile
**Files modified:** none expected — this milestone is an audit + tests. New tests in `android/app/test/offline/`, `android/app/test/player/queue_persistence_test.dart` covering the profile-switch invariant.
**Deliverable:** Confirms `serverKey` (L1) + library cache (L5) + offline manifest + Now Playing persistence (P1) + sleep timer (P3) + scrobble controller (N1) all derive their per-server state from `activeProfileProvider`, not from a stale captured value. Adds regression tests that switch the active profile and assert offline files for the previous profile remain on disk untouched while the new profile sees its own (empty / different) state.
**Test gate:** profile-A writes offline + plays a track → switch to profile-B → profile-B's offline manifest is empty + Now Playing is empty; switch back to A → A's state intact.
**Done when:** profile isolation is a tested invariant, not just a structural property.
**Commit:** `feat(flutter): S8 — verify profile isolation across offline / player / scrobble chokepoints`

### [x] S9. Profiles tab in Settings — add / switch / remove
**Files new:** `android/app/lib/screens/settings/profiles_section.dart`, `android/app/test/screens/settings/profiles_section_test.dart`.
**Files modified:** `android/app/lib/screens/settings_screen.dart` (mount Profiles section above Offline section).
**Deliverable:** Lists every profile with `displayName + navidromeUsername + lastUsedAt`. Active profile is checked. Tap a non-active profile → confirmation dialog → `setActive(id)` → router re-routes any open screen back to Home (so stale data isn't visible). "Add profile" pushes `/login` with a back-arrow. "Remove" prompts confirmation and warns that offline downloads will become inaccessible until next login. Removing the active profile resets to null → redirect to `/login`.
**Test gate:** widget tests for add / switch / remove flows including the active-removal case.
**Done when:** all three flows green; UI matches `EmptyState` + `SkeletonList` conventions.
**Commit:** `feat(flutter): S9 — profiles section in Settings`

### [x] S10. DECISIONLOG ADR + CLAUDE.md update + DEBT.md updates
**Files modified:** `android/docs/DECISIONLOG.md` (new ADR "Multi-user profiles via Navidrome IdP — heerr v3.0.0"), `android/CLAUDE.md` (rewrite the "Single-user" line under "Architecture (do not re-litigate)" + the matching "Hard don't" — explicitly permit Navidrome login, still forbid other Sign-In-With-X), `android/docs/DEBT.md` (defer per-user Last.fm/ListenBrainz to a new scheduled v3.1.0 entry; defer soft profile switching to v3 backlog).
**Deliverable:** ADR explains: why Navidrome-as-IdP, why no password storage on device, why offline state survives profile-switch via `serverKey`, why hard logout/login over soft switch. CLAUDE.md staleness rule satisfied.
**Test gate:** none (documentation).
**Done when:** docs reflect the implementation and the carved-out hard-don't.
**Commit:** `chore(flutter): S10 — multi-user ADR + CLAUDE.md update + DEBT updates`

### [x] S11. v3.0.0 smoke + version bump
**Files modified:** `android/app/pubspec.yaml` → `3.0.0`, `android/docs/CHANGELOG.md` (S1–S10 entries).
**Test gate:** manual 7-step smoke on the home server with two real Navidrome users (`alice`, `bob`): (1) fresh install → /login → alice logs in → Home loads alice's library; (2) alice downloads a track → appears in alice's `/queue`; (3) Settings → Profiles → add bob; (4) switch active → bob logs in → Home loads bob's library + bob's `/queue` is empty of alice's downloads; (5) toggle WiFi off → bob's offline is empty (correct — bob marked nothing); (6) switch back to alice → alice's offline + Now Playing intact; (7) remove bob → redirect to login when bob was active.
**Done when:** all seven steps pass. Tagged `v3.0.0`.
**Commit:** `chore(flutter): v3.0.0 multi-user smoke verified`

---

## Phase T — Stream-first preview of online search results (v3.5.0)

**Architecture note:** Lets the user **preview** (stream) an online search result *before* downloading it into the library — closing the find → *hear* → download loop. Consumes backend `GET /api/v1/preview/stream` (backend **Phase K**): the device plays a heerr-backend URL via just_audio while the backend proxies the audio from googlevideo over Tailscale. **Pure-client slice on top of K — no other backend change.** The preview `MediaItem.id` is the backend proxy URL with the bearer token as a `?token=` query param (just_audio cannot set auth headers — the same constraint Subsonic playback already works around). Previews are **ephemeral** and added to no library; the existing reactive-promotion path (`combined_search.dart`) still upgrades a row from preview → real Subsonic playback once the user downloads it and Navidrome re-indexes. The `MediaItem.id`-is-the-URI invariant is preserved — this is simply a **third URI kind** alongside `file://` and the Subsonic stream URL. **Depends on backend K2.**

### [x] T1. Preview stream URL builder + endpoint constant
**Files (new):** `android/app/lib/player/preview_url.dart`, `android/app/test/player/preview_url_test.dart`.
**Files (modify):** `android/app/lib/api/endpoints.dart` (add `previewStream`).
**Deliverable:** pure `buildPreviewStreamUrl({required heerrBaseUrl, required sourceUrl, required token})` → `<heerrBaseUrl>/api/v1/preview/stream?source_url=<enc>&token=<enc>`, URL-encoding both params. Creds are read from `activeProfileProvider` at the call site, not inside the pure builder.
**Test gate:** encoding round-trip; correct path + params for representative URLs.
**Done when:** `flutter analyze` clean; `flutter test` green.
**Commit:** `feat(flutter): T1 — preview stream URL builder`

### [x] T2. Preview playback entry point
**Files (new):** `android/app/lib/player/search_result_to_media_item.dart`, `android/app/test/player/search_result_to_media_item_test.dart`.
**Files (modify):** `android/app/lib/player/playback_actions.dart` (add `playPreview(SearchResultItem)`), `android/app/test/player/playback_actions_test.dart`.
**Deliverable:** build a `MediaItem` with `id` = the T1 preview URL, `title`/`artist`/`album`/`artUri` from the `SearchResultItem` (`coverUrl`), `extras: {'preview': true, 'sourceUrl': item.sourceUrl}`. `playPreview` reads the active profile for base URL + token, then routes the single item through the existing `HeerrAudioHandler` queue — **bypassing `songToMediaItem`** (no Subsonic / file path). Reuses the existing handler / mini-player wiring untouched.
**Test gate:** `MediaItem` shape (id = preview URL, `preview: true`, art set); handler receives the item; assert neither the Subsonic-stream nor `file://` builder is invoked.
**Done when:** `flutter analyze` clean; `flutter test` green.
**Commit:** `feat(flutter): T2 — preview playback action for online search results`

### [x] T3. Preview affordance on the search result tile + Now Playing badge
**Files (modify):** `android/app/lib/widgets/result_tile.dart` (a play/preview `IconButton` beside the existing download control; tap → `playPreview`), `android/app/lib/screens/library/library_search_results.dart` (wire it where YT results render), `android/app/lib/widgets/mini_player.dart` + `android/app/lib/screens/player/now_playing_screen.dart` (small "Preview" chip when `extras['preview'] == true`), corresponding widget tests.
**Deliverable:** every not-in-library YT result shows **both** a preview (play) control and the existing download control; preview starts immediately on tap; the download flow is unchanged. A "Preview" badge shows in Now Playing / mini-player while a preview is the current item. Backend errors (404/502 from `/preview/stream`) route through the existing `reactToApiError` snackbars.
**Test gate:** tile renders both controls; tapping preview fires `playPreview` (not the download dispatcher); badge renders for preview items and is absent for library/offline items.
**Done when:** `flutter analyze` clean; `flutter test` green.
**Commit:** `feat(flutter): T3 — preview play button on search results + Now Playing badge`

### [x] T4. DECISIONLOG ADR + CLAUDE.md note + DEBT + CHANGELOG + version bump
**Files modified:** `android/docs/DECISIONLOG.md` (new ADR "Stream-first preview via backend proxy — heerr v3.5.0"), `android/CLAUDE.md` (amend the "`MediaItem.id` is the playback URI" reminder to cover the preview-URL kind), `android/docs/DEBT.md` (backlog item: extend preview to the Recommendations screen + Home cards where `inLibrary == false`), `android/docs/CHANGELOG.md` (T1–T3), `android/app/pubspec.yaml` → `3.5.0`.
**Deliverable:** ADR explains: why the backend proxy (cite backend Phase K ADR — googlevideo IP-binding), preview URL as the third `MediaItem.id` kind, token-in-query for just_audio, ephemerality + reliance on existing reactive promotion, and why v1 is search-results-only (recommendations/home previews deferred to the DEBT backlog item).
**Test gate:** none (documentation).
**Done when:** docs reflect the implementation; version bumped.
**Commit:** `chore(flutter): T4 — preview ADR + CLAUDE.md/DEBT/CHANGELOG + v3.5.0`

### [x] T5. On-device preview smoke + version tag
**Test gate:** manual on the Pixel against the home server (backend Phase K deployed): (1) search a track **not** in the library → tap **Preview** → audio plays through the backend within ~1–2 s; (2) scrubber advances and **seek works** (Range passthrough); (3) lock-screen / notification shows the track with the "Preview" badge in-app; (4) tap **Download** on the same row → after Navidrome re-indexes it promotes into the library section and plays from Subsonic; (5) preview a region-locked / unavailable track → readable error snackbar, no crash.
**Done when:** all five steps pass. Tagged `v3.5.0`.
**Commit:** `chore(flutter): v3.5.0 stream-first preview smoke verified`

---

## Phase U — Download-to-playlist (optional post-download playlist assignment)

**Architecture note:** When a user taps the download icon on an online search result, show a bottom sheet letting them either download directly (current behaviour) or download and automatically add the song to one of their Navidrome playlists once the download job completes and Navidrome indexes the file. **Pure-client slice — no backend changes required.** The async orchestration lives as a top-level function (no persistent Riverpod state), mirroring the pattern of `playPreview` / `playSongFromSubsonic`.

**Depends on:** backend Phase K (for `BackendService.jobStatus`) and existing `SubsonicLibraryService.findLibraryMatch` + `PlaylistMutations.addSongs`.

### [x] U1. Download-to-playlist sheet + async flow

**New file: `android/app/lib/widgets/download_options_sheet.dart`**

`DownloadOptionsSheet` — a `ConsumerWidget` shown via `showModalBottomSheet`. Purely presentational; no async logic. Static `show()` factory:

```dart
static void show({
  required BuildContext context,
  required SearchResultItem item,
  required VoidCallback onDownloadOnly,
  required void Function(String playlistId, String playlistName) onDownloadToPlaylist,
})
```

Sheet layout (top→bottom): song title → "Download" `ListTile` (key `'download-options-download-only'`) → `Divider` → "Add to playlist after download" label → `libraryPlaylistsProvider` filtered by `serverCredsProvider.navidromeUsername` (loading / error / empty-state / one `ListTile` per owned playlist, key `'download-to-playlist-${p.id}'`). Each tap: `Navigator.of(context).pop()` first, then invoke the callback.

**New file: `android/app/lib/providers/download_to_playlist.dart`**

```dart
Future<void> downloadAndAddToPlaylist({
  required WidgetRef ref,
  required BuildContext context,
  required SearchResultItem item,
  required String playlistId,
  required String playlistName,
  @visibleForTesting Duration jobPollInterval = const Duration(seconds: 2),
  @visibleForTesting Duration naviPollInterval = const Duration(seconds: 5),
  @visibleForTesting int maxJobPolls = 150,   // ~5 min ceiling
  @visibleForTesting int maxNaviPolls = 18,   // ~90 s ceiling
}) async
```

Steps (each `await` is guarded by `context.mounted`):
1. `downloadDispatcherProvider.notifier.dispatch(...)` → show "Downloading … will add to [playlist] when ready" snackbar. `ApiError` → `showApiError`, return.
2. If `!response.state.isTerminal`: poll `BackendService.jobStatus` every `jobPollInterval` up to `maxJobPolls`. `failed` → error snackbar, return. Timeout → timeout snackbar, return.
3. Poll `SubsonicLibraryService.findLibraryMatch("$title $artist")` every `naviPollInterval` up to `maxNaviPolls`. Transient `ApiError` → continue polling. Timeout (match still null) → warning snackbar, return.
4. `PlaylistMutations.addSongs(playlistId, [match.id])` → success snackbar "Added [title] to [playlist]".

**Modified: `android/app/lib/screens/library/library_search_results.dart`**

In `_YtmSection`, replace the `onDownload` inline closure on each `ResultTile` with `DownloadOptionsSheet.show(...)`. `onDownloadOnly` keeps the existing dispatch + "Queued" snackbar logic. `onDownloadToPlaylist` calls `downloadAndAddToPlaylist(...)`.

**Modified: `android/app/lib/screens/library/library_screen.dart`**

Add two imports: `download_options_sheet.dart` and `download_to_playlist.dart`.

**Tests:**

`test/widgets/download_options_sheet_test.dart` — 6 widget tests (title visible, owned-playlist filter, empty-state, "Download" fires `onDownloadOnly` + closes, playlist row fires `onDownloadToPlaylist` + closes, loading spinner). Use a `Completer` (never resolved) for the loading-state test and skip `pumpAndSettle`.

`test/providers/download_to_playlist_test.dart` — 3 tests using stubs for all four providers. Override syntax: `downloadDispatcherProvider.overrideWith(() => stub)` (no-arg factory); `backendServiceProvider.overrideWith((_) => Future.value(stub))` (FutureProvider). Tests: (1) happy path — `done` state skips job poll, match found → `addSongs` called, success snackbar visible; (2) job failed → error snackbar, `addSongs` not called; (3) Navidrome timeout — `maxNaviPolls=1`, match always null → warning snackbar, `addSongs` not called.

**Snackbar-queue timing (test 3):** the initial "Downloading…" snackbar renders first. After `pumpAndSettle()` (which settles on the first snackbar), advance fake time past its 4 s display duration before asserting the second snackbar:
```dart
await tester.pumpAndSettle();
await tester.pump(const Duration(seconds: 5));
await tester.pumpAndSettle();
expect(find.textContaining('not indexed yet'), findsOneWidget);
```

**Test gate:** all 9 tests green; `flutter test` full suite green; `flutter analyze` zero issues.

**Commit:** `feat(flutter): U1 — download-to-playlist — optional playlist assignment on YTM download`

---

## Phase V — Back-button navigation fixes (predictable back stack)

**Problem:** Two user-reported back-button bugs.
1. From any non-Home screen the system back button exits the app instead of walking back toward Home. Root cause: bottom-nav tab switches use `context.go()` (`router.dart:278`), which *replaces* the go_router stack rather than pushing — so once a tab is selected, Home is gone from the stack and the next back exits the app. Two detail drill-downs in `downloads_screen.dart` (`:135` album, `:198` playlist) also use `context.go()` where they should `context.push()`, so back from those exits immediately.
2. With text in the Library search field, the **system** back button exits the app instead of clearing the field. Root cause: search is an internal `_searching` bool in `LibraryScreen` (not a route); the in-app AppBar back arrow calls `onExit`, but the hardware back button has no `PopScope` to intercept it (`library_search_results.dart`).

**Decision (locked):** Any tab → Home → exit. Use a shell-level `PopScope` (not a `StatefulShellRoute` refactor) — smaller, lower-risk for v1. Detail screens already push onto the root navigator above the `ShellRoute`, so they pop correctly; only the flat tab roots need handling.

**Pure-client slice — no backend changes.**

### [x] V1. Predictable back stack + search-mode back interception

**Single back handler per route (as built):** a go_router route hosts both the shell *and* the Library search overlay, and a system back fires only the outer (shell) `PopScope` — so a second `PopScope` inside the search overlay never runs. Back handling is therefore consolidated in the shell, keyed off a new search-active provider.

**`android/app/lib/providers/library/library_search_query.dart`** — new `LibrarySearchActive` keepAlive notifier (bool): single source of truth for whether Library is showing its search overlay.

**`android/app/lib/router.dart`** — wrap `_ShellScaffold`'s `Scaffold` in a `PopScope`:
- `canPop:` true only when `widget.location == Routes.home`.
- `onPopInvokedWithResult:` if `!didPop` → when Library is searching (`location == library && librarySearchActiveProvider`), flip `librarySearchActiveProvider` to false (exit search); otherwise `context.go(Routes.home)`.

Fires only when the shell route is the top route (pushed detail screens pop themselves first), so it handles exactly the tab-root case: from any tab/queue → back goes Home; from Home → back exits.

**`android/app/lib/screens/library/library_screen.dart`** — search mode driven by `librarySearchActiveProvider` (not a local `_searching` bool). `initState` seeds it post-frame from the persisted query / auto-focus; `build` registers a `ref.listen` that clears the controller + `librarySearchQueryProvider` on the true→false transition (covers both the in-app back arrow and the system back button). `_enterSearch`/`_exitSearch` just flip the provider.

**`android/app/lib/screens/library/library_search_results.dart`** — `_SearchModeScaffold` stays a plain `Scaffold` (no `PopScope`); back is handled by the shell.

**`android/app/lib/screens/downloads_screen.dart`** — change `context.go(...)` → `context.push(...)` at the album (`:135`) and playlist (`:198`) drill-downs so back returns to Downloads.

**Tests:**
- `test/router_test.dart` — from a tab/detail location, simulate system back → asserts navigation to Home (not app exit); from Home, pop is allowed.
- Library-screen widget test — enter search, type text, trigger system back → asserts text cleared, `_searching == false`, still on Library (not popped).

**Test gate:** new tests green; `flutter test` full suite green; `flutter analyze` zero issues.

**Commit:** `fix(flutter): V1 — predictable back stack — tab-root back to Home, search back clears field`

---

## Phase W — Delete song from server / device / both (#41, v4.2.0)

**Architecture note:** Completes issue #41 (the device half shipped in `64c8e47`). Server delete calls the backend's new `DELETE /api/v1/library/song` (backend Phase N), identifying the file by the Subsonic-relative `Song.path` the client already holds. Navidrome drops the track on its next scan (~1 min), so invalidated library providers may transiently re-serve the song — snackbars say so. **Depends on backend N1.**

### [x] W1. Delete from server — service + notifier + Downloads sheet + library long-press
**Files (new):** `android/app/lib/providers/library/library_delete.dart` (`LibraryDelete` keepAlive notifier — guards `song.path`, calls `BackendService.deleteLibrarySong`, invalidates library/downloads/home read providers), `android/app/test/services/backend_service_test.dart`, `android/app/test/providers/library/library_delete_test.dart`, `android/app/test/screens/downloads_screen_delete_test.dart`, `android/app/test/widgets/add_to_playlist_delete_from_server_test.dart`.
**Files (modify):** `android/app/lib/api/endpoints.dart` (`libraryDeleteSong`), `android/app/lib/services/backend_service.dart` (`deleteLibrarySong(path)`), `android/app/lib/screens/downloads_screen.dart` (long-press → Device / Server / Both sheet; Server/Both disabled when `path == null`; destructive confirm dialogs), `android/app/lib/widgets/add_to_playlist_sheet.dart` (optional `deleteFromServerSong` → destructive "Delete from server…" tile), album/playlist-detail + library-search song rows (pass `deleteFromServerSong`), `android/app/pubspec.yaml` → `4.2.0`.
**Known edge (accepted):** "Both" with the parent album still offline-marked can re-download before Navidrome rescans; after the rescan the song leaves the album listing and sync no longer sees it.
**Test gate:** service transport tests (DELETE shape, 404/403/network → typed `ApiError`); notifier tests (path guard, invalidation-on-success, no-invalidation-on-failure); Downloads sheet widget tests (three options, disabled-without-path, confirm-gated calls, cancel); sheet tile tests (render/hide rules, confirm fires + pops, cancel keeps sheet). Full suite green; `flutter analyze` clean.
**Smoke:** ✅ Passed on the Pixel against the home server 2026-07-05. Operator prerequisites discovered during the smoke (Navidrome reports virtual paths by default): `ND_SUBSONIC_DEFAULTREPORTREALPATH=true` on the navidrome container **and** "Report Real Path" enabled on the app's `heerr [Dart]` player record per user (the flag only defaults new player records); app-side re-search needed once so the L5 cache drops old virtual paths. Backend N2 strips the `/music/` prefix Navidrome reports.
**Commit:** `feat(flutter): W1 — delete song from server / device / both (#41)`

---

## Phase Y — Edit song metadata (#44, v4.3.0)

**Architecture note:** Issue #44 — online-search downloads sometimes carry wrong titles / cover art. The client sends changed tags + an optional cover image to the backend's new multipart `PATCH /api/v1/library/song` (backend Phase O), identifying the file by the Subsonic-relative `Song.path` the client already holds. The backend rewrites tags in place (never renames), so `Song.path` stays stable; Navidrome re-reads the file on its next scan (~1 min). Mirrors the Phase W shape (service method → keepAlive notifier → long-press-sheet tile), plus L5 cover-cache eviction. Phase letter is **Y** (not X) — `DEBT.md` uses item IDs X1–X7. **Depends on backend O2.**

### [x] Y1. Edit-metadata service + notifier + cover-cache eviction
**Files (new):** `android/app/lib/providers/library/library_edit.dart` (`LibraryEdit` keepAlive notifier — guards `song.path` + at-least-one-change, calls `BackendService.editLibrarySong`, invalidates the same 9 library/downloads/home read providers as `LibraryDelete`; when a cover was uploaded also deletes the L5 cached cover JPG for `song.coverArt` and clears the in-memory image cache), `android/app/test/providers/library/library_edit_test.dart`.
**Files (modify):** `android/app/lib/api/endpoints.dart` (`libraryEditSong`), `android/app/lib/services/backend_service.dart` (`editLibrarySong({path, title?, album?, artist?, coverBytes?})` — `FormData` multipart, only-present fields, JPEG cover part via `DioMediaType`), `android/app/test/services/backend_service_test.dart` (PATCH shape, field presence, cover part, 404/403/network → typed `ApiError`).
**Test gate:** service transport tests; notifier tests (path guard, nothing-to-change guard, invalidation-on-success, no-invalidation-on-failure, cover-file eviction only on cover edits). Full suite green; `flutter analyze` clean.
**Commit:** `feat(flutter): Y1 — edit-metadata service + notifier + cover-cache eviction (#44)`

### [x] Y2. Edit screen + sheet tile + wiring
**Files (new):** `android/app/lib/screens/library/edit_song_metadata_screen.dart` (full-screen editor, root-navigator push — no go_router route; cover preview via picked `Image.memory` else `LibraryCoverArt`; "Change cover" through `image_picker`; three prefilled fields; Save sends only changed non-empty fields, disabled when unchanged or pending; success → pop + snackbar; errors via `showApiError`), `android/app/lib/providers/library/song_cover_image_picker.dart` (gallery-pick seam, 1024 px / q85), `android/app/test/screens/library/edit_song_metadata_test.dart`, `android/app/test/widgets/add_to_playlist_edit_metadata_test.dart`.
**Files (modify):** `android/app/lib/widgets/add_to_playlist_sheet.dart` (optional `editMetadataSong` → non-destructive "Edit metadata…" tile above the delete tile, hidden when null or `path == null`; tap pops sheet then pushes the screen), album/playlist-detail + library-search song rows (pass `editMetadataSong: s` alongside the existing `deleteFromServerSong: s`), `android/app/pubspec.yaml` → `4.3.0`.
**Test gate:** screen tests (prefill, Save-disabled-until-change, only-changed-fields, cover pick sends bytes, success pops + snackbar); sheet-tile tests (render/hide rules, tap closes sheet + pushes screen). Full suite green; `flutter analyze` clean; `build_runner` clean.
**Smoke (Pixel + home server, pending backend 3.3.0 deploy):** edit a mis-tagged YTM download → correct after rescan; upload cover → new art renders in app (cache evicted) + Navidrome web; file path unchanged (offline copy still plays; no dedupe re-download offered).
**Commit:** `feat(flutter): Y2 — edit song metadata screen — title/album/artist + cover upload (#44)`

---

## Phase Z — Profile screen redesign (v4.9.0)

**Architecture note:** A mockup (`Profile Screen.png`) redesigns `/profile` from a plain edit form into a display-first page: gradient-ring avatar, name/@handle/bio, a Playlists/Songs/Albums/Artists stats row, "My Music" quick-link cards, a "Settings" section, and Log Out. Pure-Android slice — the one new wire dependency (`POST /auth/logout`) already exists on the backend (`backend/app/api/v1/auth.py`). heerr Radio and Followed Artists rows are deferred per user decision. See `DECISIONLOG.md` 2026-07-11 ("Phase Z") for full rationale.

### [x] Z1. Display/edit split — `/profile` display screen + `/profile/edit` form
**Files:** new `lib/screens/profile/profile_edit_screen.dart` (`ProfileEditScreen`, former `profile_screen.dart` content; post-save `pop()`s instead of routing Home); rewrote `lib/screens/profile/profile_screen.dart` as the display screen (avatar + pencil badge both push `/profile/edit`, name/@handle/bio); `router.dart` (`Routes.profileEdit`, nested route). Tests migrated wholesale to `profile_edit_screen_test.dart`; new `profile_screen_test.dart`; `router_test.dart` coverage.
**Test gate:** `flutter analyze` clean; `flutter test` 823/823 green.
**Commit:** `feat(flutter): profile redesign Z1 — display screen shell + edit form moved to /profile/edit`

### [x] Z2. Stats provider + stats row
**Files:** new `lib/providers/profiles/profile_stats.dart` (`profileStatsProvider`, `formatStatCount`) summing `libraryPlaylistsProvider` / `libraryAlbumsProvider` / `libraryArtistsProvider` — no new endpoints. Profile screen renders the 4-column row.
**Test gate:** provider + widget tests; `flutter test` 828/828 green.
**Commit:** `feat(flutter): profile redesign Z2 — server-derived stats row (playlists/songs/albums/artists)`

### [x] Z3. "My Music" cards + Recently Played screen + Playlists deep link
**Files:** new `recentlyPlayedProvider` (`home_providers.dart`, `type=recent`), `lib/screens/library/recently_played_screen.dart` (clone of `RecentlyAddedScreen`) at `/library/recently-played`; `LibraryScreen.initialTabIndex` + router `_tabIndexFor` for `/library?tab=`; profile screen's "My Music" section (Liked Songs / Downloaded / Recently Played / Playlists).
**Test gate:** card-tap routing, recently-played screen states, router tab-param mapping; `flutter test` 837/837 green.
**Commit:** `feat(flutter): profile redesign Z3 — My Music cards + recently-played screen + library tab deep link`

### [x] Z4. "Settings" cards + About/Help dialogs + Log Out
**Files:** `Endpoints.authLogout` + `BackendService.logout()` (`POST /auth/logout`, best-effort); profile screen's Settings section (Settings / Help & Support / About heerr) + confirm-gated Log Out (`logout()` then `profileRegistryProvider.notifier.setActive(null)` — not `removeProfile`; router redirect handles `/login`).
**Test gate:** `BackendService.logout` transport tests; widget tests for cancel/confirm + dialogs; `flutter test` 846/846 green.
**Commit:** `feat(flutter): profile redesign Z4 — settings cards, about/help dialogs, log out flow`

### [x] Z5. Settings-tab profile card
**Files:** new `lib/widgets/profile_avatar_ring.dart` (`ProfileAvatarRing`, extracted from three near-duplicate ring implementations — Home header, Profile display, new Settings card); new `lib/screens/settings/profile_card.dart` (`ProfileCard`) inserted atop `settings_screen.dart`.
**Test gate:** `flutter test` 849/849 green.
**Commit:** `feat(flutter): profile redesign Z5 — settings-tab profile card entry point`

### [x] Z6. Docs + version bump 4.9.0
**Files:** `DECISIONLOG.md` ADR, `CHANGELOG.md` entries, this ROADMAP section + status line, version bump (`android/app/pubspec.yaml`, `backend/pyproject.toml`, `backend/app/main.py`, both ROADMAP status lines).
**Done when:** `flutter analyze` clean, full `flutter test` suite green, `v4.9.0` tagged.
**Commit:** `docs(flutter): profile redesign Z6 — ADR, changelog, roadmap + version bump to 4.9.0`

---

## Phase X — Library screen redesign (v4.10.0)

**Architecture note:** A three-panel mockup redesigns the Library tab: shared branded header (logo + compact greeting + queue/avatar), "Your Library" headline, icon segmented tabs reordered to Albums / Artists / Playlists, per-tab filter chips (sort + Downloaded), an albums grid with offline badges, an A–Z index scrubber, artist rows with a "Most Played Artists" rail (derived from `type=frequent` albums — Subsonic has no frequent-artists endpoint), and playlist cards with Favorites + Create Playlist tiles. Pure-Android slice — zero new endpoints; all sorting/filtering is client-side over the existing cached fetches. Full plan: `LIBRARYSCREEN.md`; rationale: `DECISIONLOG.md` 2026-07-11 ("Phase X").

### [x] X1. Shared branded header + "Your Library" + segmented tabs + tab reorder
**Files:** new `lib/widgets/branded_header.dart` (`BrandedAppBar`, `GreetingBlock`, `ProfileAvatarButton`, `greetingForHour` — extracted from Home); `heerr_logo.dart` gained `showWordmark`; `home_screen.dart` slimmed to consume the shared header; `library_screen.dart` browse scaffold (compact-greeting AppBar + search action, headline, `_LibrarySegmentedTabs` with `GradientTabIndicator`); `router.dart` `_tabIndexFor` remapped to Albums=0 / Artists=1 / Playlists=2.
**Test gate:** new `branded_header_test.dart`; library header/tab-order/deep-link tests; `flutter test` 856/856 green.
**Commit:** `feat(flutter): library redesign X1 — shared branded header, Your Library headline, segmented tabs, tab reorder`

### [x] X2. Filter chips + per-tab sort/downloaded state
**Files:** new `lib/providers/library/library_filters.dart` (`LibraryTab`, `AlbumSort`/`ArtistSort`/`PlaylistSort` + notifiers, `downloadedOnlyNotifierProvider` family, pure `sortAlbums`/`sortPlaylists` helpers); new `lib/widgets/library_filter_chips.dart` (magenta sort chip → bottom-sheet picker, Downloaded toggle, decorative filter icon).
**Test gate:** provider defaults/transitions + comparator null-handling + chip widget tests; `flutter test` 868/868 green.
**Commit:** `feat(flutter): library redesign X2 — filter chips + per-tab sort/downloaded state`

### [x] X3. Albums tab — grid + full list
**Files:** new `sortedLibraryAlbumsProvider` (`lib/providers/library/library_views.dart`); new `lib/screens/library/album_grid_card.dart`; `_AlbumsTab` rewritten as a `CustomScrollView` — chip row, 9-cap 3-column grid with magenta offline badges, "Albums ›" header, full list with `artist • year • N songs` subtitles.
**Test gate:** provider sort/filter tests + grid-cap and subtitle widget tests; `flutter test` 872/872 green.
**Commit:** `feat(flutter): library redesign X3 — albums grid + full list + downloaded badges`

### [x] X4. Alphabet index scrubber
**Files:** new `lib/widgets/alphabet_scrubber.dart` (`AlphabetScrubber` + pure `letterForDy` / `scrubTargetIndex`); `_AlbumsTab` gained a `ScrollController`, fixed extents (rows 72, chips 56, header 44) and grid-geometry math so scrub jumps land on rows; scrubber overlays only in A–Z sort.
**Test gate:** mapping unit tests, gesture test, visibility + jump widget test; `flutter test` 884/884 green.
**Commit:** `feat(flutter): library redesign X4 — alphabet index scrubber`

### [x] X5. Artists tab — rows, downloaded filter, most played rail
**Files:** new `sortedLibraryArtistsProvider` (flattens `ArtistIndex` buckets; Downloaded = `markedArtists` plus artists of `markedAlbums` joined on `Album.artistId`); new `lib/providers/library/most_played_artists.dart` (`mostPlayedArtistsFrom` dedupe over `type=frequent`, cap 10); `_ArtistsTab` rewritten (circular-avatar rows, "N albums", scrubber, `_MostPlayedArtistsRail` with gradient play badges).
**Test gate:** flatten/sort/join provider tests, rail dedupe tests, row + rail widget tests; `flutter test` 891/891 green.
**Commit:** `feat(flutter): library redesign X5 — artist rows, downloaded filter, most played rail`

### [x] X6. Playlists tab — cards, Favorites, Create Playlist, full list
**Files:** new `sortedLibraryPlaylistsProvider`; new `lib/screens/library/playlist_grid_card.dart` (`PlaylistGridCard`, `FavoritesGridCard`, `CreatePlaylistGridCard`); `_PlaylistsTab` rewritten — 2-column grid (Favorites first with starred count, up to 6 playlist cards, Create card replacing the FAB), "Playlists ›" list (Favorites row, playlist rows with `by owner • N songs`, For You tail entry preserved).
**Test gate:** card order, create flow via card, For You retention; `flutter test` 891/891 green.
**Commit:** `feat(flutter): library redesign X6 — playlist cards, favorites tile, create-playlist card, full list`

### [x] X7. Docs + version bump 4.10.0
**Files:** `DECISIONLOG.md` ADR, `CHANGELOG.md` entries, `DEBT.md` deferrals, this ROADMAP section + status line, `LIBRARYSCREEN.md` status flip, version bump (`android/app/pubspec.yaml`, `backend/pyproject.toml`, `backend/app/main.py`, both ROADMAP status lines).
**Done when:** `flutter analyze` clean, full `flutter test` suite green.
**Commit:** `docs(flutter): library redesign X7 — ADR, changelog, roadmap + version bump to 4.10.0`

---

## Phase PC — Podcasts (discover / subscribe / download / play) (#53)

Design doc: `backend/docs/PODCASTS.md`. Scope locked by owner: **full podcast model** + **Podcast Index / RSS** discovery. Pure-client slices — **all backend endpoints ship first** in `backend/docs/ROADMAP.md` Phase P (P1–P6) and must be curl-testable before the matching PC milestone starts. Reuse the locked stack (dio / riverpod / freezed / go_router); no new auth path, no new download engine on-device.

**Order of execution: PC1 → PC2 → PC3 → PC4 → PC5, strictly in sequence, and only after backend Phase P is deployed.** Backend prerequisite per milestone is noted inline. Suggested version bump `v5.0.0` at PC5 (shared with backend P6 — version-sync rule, `/CLAUDE.md` §3).

### [x] PC1. Models + API client wiring
**Backend prereq:** P2–P4 deployed. **Files:** `android/app/lib/models/{podcast_channel,podcast_episode,podcast_subscription,episode_progress}.dart` (`@freezed`), `android/app/lib/api/endpoints.dart` (+ podcast routes), `android/app/lib/api/podcast_api.dart`, `android/app/test/podcast_api_test.dart`.
**Deliverable:** Freezed models + `fromJson`/`toJson` for channel/episode/subscription/progress; dio-backed API wrapper (search, subscribe, unsubscribe, subscriptions, episodes, refresh, download, progress, audio-url) routed through the existing auth interceptor.
**Test gate:** model round-trip serialization; API wrapper builds requests with the right paths/verbs (dio mocked). `build_runner` clean; `flutter analyze` + `flutter test` green.
**Commit:** `feat(flutter): PC1 — podcast models + API client (#53)`

### [x] PC2. Discover screen — Podcast Index search + subscribe
**Backend prereq:** P2, P3. **Files:** `android/app/lib/screens/podcasts/discover_screen.dart`, provider(s) under `lib/providers/podcasts/`, router entry, `android/app/test/podcast_discover_test.dart`.
**Deliverable:** Search box → Podcast Index results (art, title, author); tap → channel preview → Subscribe/Unsubscribe. Error UX per CONTEXT.md table (502 = "podcast search error").
**Test gate:** widget test — query renders results (provider mocked); subscribe toggles state. Analyze + test green.
**Commit:** `feat(flutter): PC2 — podcast discover + subscribe (#53)`

### [x] PC3. Subscriptions + Channel-detail episode list
**Backend prereq:** P3, P4. **Files:** `android/app/lib/screens/podcasts/{subscriptions_screen,channel_screen}.dart`, providers, router entries, tests.
**Deliverable:** Subscriptions grid/list of subscribed channels; Channel detail = paginated episode list with published date, duration, **played badge + resume position** (from backend progress), pull-to-refresh → `POST …/refresh`. "Podcasts" entry in nav/Profile.
**Test gate:** widget tests — subscriptions render; episode list paginates; played/unplayed + resume indicators reflect progress fields. Analyze + test green.
**Commit:** `feat(flutter): PC3 — subscriptions + channel episode list (#53)`

### [x] PC4. Episode download → Sync Center integration
**Backend prereq:** P5. **Files:** episode-row download action, download/notifier wiring reusing the existing queue/Sync Center providers, `lib/screens/downloads/*` (surface episodes), tests.
**Deliverable:** Per-episode Download action → `POST /podcasts/episodes/{id}/download`; progress shows in the existing Sync Center / queue UI (backend job `kind='episode'`); downloaded episodes get an offline badge; offline (`file://`) vs stream selection resolved per episode.
**Test gate:** widget/unit test — download dispatch hits the endpoint; queue reflects an episode job; offline badge toggles on `downloaded`. Analyze + test green.
**Commit:** `feat(flutter): PC4 — podcast episode download via Sync Center (#53)`

### [x] PC5. Player integration + progress sync + docs/version
**Backend prereq:** P6. **Files:** `lib/audio/*` (episode `MediaItem` builder — 4th URI kind), progress-reporter, `DECISIONLOG.md` ADR, `PLAN.md` update, `CHANGELOG.md`, version files (`/CLAUDE.md` §3), this ROADMAP status line.
**Deliverable:** New `MediaItem` kind for episodes alongside file / subsonic / preview (see Cross-cutting "MediaItem.id is the playback URI"): `file://` when downloaded, else the backend `/podcasts/episodes/{id}/audio?token=` (Range-capable, seek/resume) or public enclosure URL; `extras['episodeId']` to distinguish. Throttled progress `PUT` (~every 15 s + on pause/stop/seek-end) and resume-from-position on open. Docs + `v5.0.0`.
**Test gate:** unit test — episode `MediaItem` builder produces the right id per state; progress reporter throttles + fires on pause/stop. Analyze + full `flutter test` green.
**Smoke (on-device):** subscribe → download an episode → play offline with seek/resume; stream an undownloaded episode; kill + reopen resumes at saved position; progress reflected on the episode row.
**Commit:** `feat(flutter): PC5 — podcast player + progress sync + v5.0.0 (#53)`

---

## Phase PR — Podcast flow redesign (#53)

Design doc: `~/Downloads/ChatGPT Image Jul 20, 2026, 07_29_43 PM.png` ("heerr — Podcast Flow | Design & Implementation Guide"). Promotes the functional-but-buried PC1–PC5 podcast feature (reachable only via Profile → Podcasts → plain grid → plain list → the *music* Now Playing screen) into a first-class experience integrated into Library + Home, with a proper show-detail screen, richer episode rows, and a podcast-flavored player. Plan file: `~/.claude-personal/plans/luminous-singing-pinwheel.md`.

**Owner-confirmed scope decisions (2026-07-20):**
- **Audiobooks: dropped.** The content switcher is **Music / Podcasts only** — no audiobook chip anywhere.
- **Aggregate feeds: build the backend** (PR3 depends on new backend endpoints — see backend Phase PA).
- **Player: functional-only.** New podcast player look + working **speed control** and **sleep timer**. Dropped: Chapters / Transcript / Notes / Bookmark tabs, show "Related" tab, and the animated waveform (feeds/DB carry none of it) — the "waveform" becomes a plain progress scrubber.
- **Delivery: phased** — PR1 → PR2 → PR3, each its own commit(s), version bump, tests, docs.

**Out of scope (this phase):** audiobooks; chapters / transcripts / notes / bookmarks / related; real waveform amplitude data; the design's 5th bottom-nav "Search" item (a music-nav change unrelated to podcasts).

**Order of execution: PR1 → PR2 → PR3.** Suggested version bumps `v5.1.0` / `v5.2.0` / `v5.3.0` (owner to confirm at PR1 start; version-sync rule `/CLAUDE.md` §3 applies at each).

### [x] PR1. Library integration + Show Detail + richer episode rows
**Backend prereq:** none (client-only; reuses existing PC endpoints). **Files:** `android/app/lib/screens/library/library_screen.dart` (+ `library_tabs.dart` part), new `android/app/lib/screens/podcasts/podcast_show_detail_screen.dart` (replaces `channel_screen.dart`), `android/app/lib/screens/podcasts/subscriptions_screen.dart` (extract grid → reusable widget), `android/app/lib/router.dart` (rewire channel route + subscriptions redirect), tests under `test/screens/{podcasts,library}/`.
**Deliverable:**
- **Music / Podcasts** top-level content switch in Library (segmented, styled with the existing `GradientTabIndicator` + `heerrMagenta`). Music = the current Albums/Artists/Playlists body, unchanged. Podcasts = a `_PodcastsSection` with **Shows / Episodes / Downloads** sub-tabs.
- **Shows** sub-tab: subscriptions grid (moved out of `subscriptions_screen.dart` into a reusable widget, driven by `podcastSubscriptionsProvider`) + a Discover affordance. **Episodes / Downloads** render an `EmptyState` placeholder marked `// Phase PR3` (light up when the aggregate endpoints land).
- **Show Detail** (`PodcastShowDetailScreen`, route `/podcasts/channel/:id`): hero art + gradient scrim, `author • N episodes`, description; action row = **Continue** (resume the show's most-recent in-progress episode via `playEpisode`) + **Following** toggle (reuse subscribe/unsubscribe) + download control; client-derived **Continue Listening** + **Latest Episode** mini-sections; **Episodes** + **About** tabs (no Related tab). Reuse `podcastEpisodesNotifierProvider(channelId)` (pagination, pull-to-refresh).
- **Richer episode rows:** leading art, title, `date • duration`, a thin gradient **progress bar** when `positionS > 0 && !played`, the existing download icon state machine (outline → spinner → `download_done`), played → check + muted title. Sort control omitted until PR3 (backend has no sort param yet).
**Test gate:** widget tests for the Library content switch, show-detail hero/actions/tabs, and episode-row states (progress/played/download). `flutter analyze` + `flutter test` green.
**Commit:** `feat(flutter): PR1 — podcasts in Library + show detail + richer episode rows (#53)`

### [x] PR2. Podcast player redesign
**Backend prereq:** none (client-only). **Files:** `android/app/lib/player/heerr_audio_handler.dart` (add `setSpeed` custom action + 30 s skip config), `android/app/lib/player/now_playing_snapshot.dart` (carry speed if not already), `android/app/lib/screens/player/now_playing_screen.dart` (+ new sibling `now_playing_podcast_transport.dart`), reuse `now_playing_sleep_timer.dart`, tests under `test/player/` + `test/screens/player/`.
**Deliverable:** Branch the Now Playing surface on `isEpisodeMediaItem` (`player/episode_to_media_item.dart`). Episode layout = large cover, `episode.title` + tappable show name, a **plain position/duration scrubber** (not a waveform), and podcast transport: **skip-back 30 s / play-pause / skip-forward 30 s** (via `SeekHandler.rewind`/`fastForward` at a 30 s interval, or `seek(position ± 30 s)`). New **speed control** (`setSpeed` on the handler → `_player.setSpeed`; picker 1.0×/1.25×/1.5×/1.75×/2.0×), surfaced only on the podcast layout. **Sleep timer** reused from the music player. Music player transport unchanged (no speed pill). Chapters / Transcript / Notes / Bookmark bar dropped entirely.
**Test gate:** unit test — `setSpeed` calls the player; 30 s skips seek correctly; snapshot carries speed. Widget test — episode item renders the podcast layout with speed + sleep affordances; music item still renders the standard transport. `flutter analyze` + `flutter test` green.
**Commit:** `feat(flutter): PR2 — podcast player redesign (speed + sleep) (#53)`

### [ ] PR3. Home podcast sections + Library Episodes/Downloads tabs
**Backend prereq:** backend **Phase PA** deployed (aggregate episode feeds + per-channel `sort` param) — curl-testable first. **Files:** `android/app/lib/services/backend_service.dart` (+ wrappers), new providers under `lib/providers/podcasts/`, new episode-feed models, `android/app/lib/screens/home/home_screen.dart` (Music/Podcasts content switch), `android/app/lib/screens/library/library_screen.dart` (wire Episodes + Downloads sub-tabs + the now-functional sort control), tests.
**Deliverable:**
- Models + `backend_service` wrappers + providers for the three aggregate feeds (`in_progress` / `latest` / `downloaded`) and the per-channel `sort` param.
- **Home:** a Music / Podcasts content switch atop Home (Music = existing `_HomeBody`; Podcasts = a `_HomePodcastsBody` with a **Continue Listening** horizontal carousel + **Latest Episodes** list).
- **Library:** wire the PR1-stubbed **Episodes** (latest, with the sort control now functional) and **Downloads** sub-tabs to the new providers.
**Test gate:** provider tests for the three feeds + sort param (dio mocked); widget tests for the Home content switch + the two Library sub-tabs (loading/data/empty/error). `flutter analyze` + full `flutter test` green.
**Smoke (on-device):** subscribe → open a show → play an episode → change speed → set a sleep timer → resume from Home "Continue Listening"; confirm Latest Episodes + Downloads tabs populate.
**Commit:** `feat(flutter): PR3 — home podcast sections + Library episodes/downloads tabs (#53)`

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
- **`MediaItem.id` is the playback URI** — one of three kinds: `file://` when local (offline), the Subsonic stream URL when streaming a library track, or the heerr `/preview/stream?...&token=` proxy URL for an online-search preview (Phase T, built by `searchResultToMediaItem`). Any deviation breaks offline playback. Preview items also carry `extras['preview'] == true` (vs `extras['subsonicId']` for library tracks) — use `isPreviewMediaItem` to tell them apart.

---

## Out of scope

Items scheduled into v1.5.0 (Phase P) or v2.0.0 (Phase Q) are no longer here — see those phase sections above.

- iOS port.
- Light theme.
- Push notifications / FCM.
- Third-party music-service SDK / OAuth on device.
- Admin endpoints (CLI-only on backend).
- Internationalisation.
- Offline mutation queue (mutations require online connectivity in v1).
- Crossfade (gapless is the v2.1.0 / Phase R substitute — crossfade overrides the album's intended transitions, which is the opposite of what gapless preserves).
- Android TV version — v3 goal (leanback UI, D-pad nav, separate flavour).
- Cast / Sonos / external player hand-off (v3 backlog).
- Equaliser.
- Cover-art upload for playlists.
- Concurrent sync across multiple servers.

---

## Roadmap complete when

1. All milestone boxes checked (A1–G1, H1–K2, L1–L6, M1–M5, N1–N5, O1–O5, P1–P4, Q1–Q4, R1, S1–S11, T1–T5, U1, V1, W1, X1–X7, Y1–Y2, Z1–Z6, PC1–PC5).
2. Every test gate green at its milestone.
3. G1, K2, L6, M5, N5, O5, P4, Q4, R1, S11, T5, and PC5 manual smokes verified on-device.
4. CHANGELOG entries exist for each milestone group.
5. `git log --oneline android/` reads as a clean A→U progression under the `feat(flutter):` / `chore(flutter):` Conventional-Commits cadence.
