# DECISIONLOG.md — heerr Android client

Append-only ADR log for the Android app. Newest at the bottom. One entry per *decision* — see `/CLAUDE.md` §2 for the format.

---

## 2026-06-09 — Stack: Riverpod + dio + freezed + json_serializable + flutter_secure_storage + go_router

**Context:** New Android client (built in Flutter). Need to choose state management, HTTP client, JSON layer, secret storage, and navigation. User has zero Flutter experience and wants reasonable defaults with good docs.

**Decision:** Lock the stack as named in the title.

**Why:**
- **Riverpod** over Bloc / Provider / setState: less boilerplate than Bloc (no Event/State stream ceremony for our small surface); type-safe compile-time DI; first-class codegen (`@riverpod`); strong docs in 2026. Plain `setState` doesn't scale across an API-driven multi-screen app.
- **dio** over `package:http`: interceptors are the cleanest place to inject the bearer header, classify errors into a typed `ApiError`, and add retry logic for 503. Same vendor ergonomics across all endpoints.
- **freezed + json_serializable**: codegen for immutable models + `copyWith` + `fromJson`/`toJson` from one annotated declaration. The standard production combo; no manual JSON glue per model.
- **flutter_secure_storage**: the bearer token authorises downloads from the backend. Storing it in plaintext `shared_preferences` (readable via `adb backup`) is wrong on principle. `flutter_secure_storage` wraps Android EncryptedSharedPreferences.
- **go_router**: declarative, Flutter-team-supported, supports `redirect:` callbacks (used for the "no-token → /settings" flow). Removes Navigator-2.0 boilerplate.

**Alternatives considered:**
- **Bloc**: solid choice, especially for users coming from event-driven backends. Rejected because the boilerplate-to-feature ratio is higher and Riverpod gives us the same testability with less code.
- **`package:http` + manual JSON**: lower dep footprint, but ~6 endpoints × 6 models = 36+ hand-written JSON snippets we'd have to maintain. Dio + freezed pays for itself by the second model.
- **`built_value` + chopper**: heavier codegen, less common in 2026. Freezed has effectively replaced it for new projects.
- **`shared_preferences` for the token**: cheaper to debug; rejected as above.
- **Navigator 2.0 (manual)**: too much state-machine code for our handful of routes.

**Trade-off:** Codegen via `build_runner` adds a step (`flutter pub run build_runner build --delete-conflicting-outputs` after model edits). This is the standard Flutter workflow in 2026 and the user already runs codegen-heavy tooling on the backend (Alembic, Pydantic schema generators); the cognitive load is small.

---

## 2026-06-09 — Theme: Material 3, dark only, seed colour `#1DB954`

**Context:** Visual aesthetic per the root `CONTEXT.md` ("Spotify's black + green theme"). Need to pick the colour-derivation strategy.

**Decision:** `ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF1DB954), brightness: Brightness.dark))`. Dark-only — no light-mode variant in v1.

**Why:**
- M3's `ColorScheme.fromSeed` derives the full 12-role palette from one seed colour algorithmically. We get consistent surface/onSurface/primary/onPrimary contrast without hand-tuning a palette.
- Spotify's `#1DB954` (the Spotify green) is the seed — produces a recognisably Spotify-like green-on-black with M3-correct contrast ratios.
- Light theme is deferred to v2 (if ever). The user always uses the app on a phone at home in the evening — dark-only is intentional, not unfinished.

**Alternatives considered:**
- Hand-rolled `ColorScheme(primary: ..., surface: ...)` — more control, more bikeshed. M3 seed-derived palette is good enough out of the box.
- Material 2 + custom theming — rejected; M3 is the default and the future.
- `dynamic_color` (Android system colour) — rejected: this is a dedicated music-request app, not a system-tinted utility. We want the Spotify aesthetic specifically.

**Trade-off:** Locked to one accent colour. If the user later wants to A/B test "Apple-Music-coral" or similar, it's a one-line change in `theme.dart`.

---

## 2026-06-09 — Status polling, not WebSocket

**Context:** Queue + job-detail screens need to reflect backend state changes. The backend exposes REST only — no WebSocket / SSE / FCM.

**Decision:** Riverpod `StreamProvider` + `Stream.periodic` polls `/queue` every 3s and `/status/{id}` every 2s while non-terminal. Lifecycle-aware: polling pauses when the screen is off-foreground.

**Why:**
- Backend has no real-time push channel. Adding one (WebSocket or FCM) is significant complexity for a single-user app where the user is actively watching the screen during a download.
- Polling at 2-3s feels real-time to a human; downloads typically take 10-60s so the user sees ~5-30 ticks per job.
- Lifecycle-aware pause avoids needless backend traffic when the user backgrounds the app.
- `StreamProvider` over raw `Timer` because the latter is easy to leak from a `StatefulWidget` and harder to test (`fake_async` works cleanly with streams).

**Alternatives considered:**
- **WebSocket / SSE**: would be lovely but doesn't exist on the backend. Adding it is a backend-side decision (DECISIONLOG-worthy), deferred.
- **Aggressive polling (sub-second)**: wastes battery + backend cycles without a perceptible UX gain.
- **One-shot pull-to-refresh only**: the user has to actively pull every few seconds — annoying for a 30-second download.

**Trade-off:** ~20-30 extra HTTP requests per download. The backend is on the user's home server over Tailscale; this is invisible cost.

---

## 2026-06-09 — Configuration: in-app Settings screen, not `--dart-define`

**Context:** The Android client needs to know the backend's base URL + bearer token. Choices: bake at build time via `--dart-define`, supply at runtime via a config file shipped in the APK, or accept from the user via a Settings screen.

**Decision:** Settings screen. Both values entered by the user once on first launch, persisted to `flutter_secure_storage`. No build-time defines.

**Why:**
- The backend URL is the user's Tailscale-IP / MagicDNS name. It is per-installation, not per-release. Baking into the APK would require a custom build per device or hardcoding the user's home IP into the binary.
- The bearer token is minted by the backend CLI at deploy time; the user reads it off the server console once. Build-time injection would expose the token in CI logs / artifacts.
- A Settings screen is the natural pattern users expect for self-hosted apps (Jellyfin, Navidrome, Komga, etc. all do this).

**Alternatives considered:**
- **`--dart-define`** at build: per-binary per-device. Rejected — releases become per-user.
- **`flutter_dotenv` + bundled `.env`**: token committed to git, no thanks.
- **QR-code provisioning** from the backend admin UI: there's no admin web UI yet. Defer to v2 if it ever matters.

**Trade-off:** First-launch UX has an extra step (paste URL + token). Acceptable for a single-user app whose user is also the operator.

---

## 2026-06-09 — Project layout: `android/app/` for the `flutter create` project

**Context:** `flutter create .` would dump pubspec.yaml + lib/ + android/ + test/ etc. directly into the `android/` directory, which already holds `CLAUDE.md`, `README.md`, and `docs/`. The convention from `/CLAUDE.md` §1 expects per-app docs to live at `<app>/CLAUDE.md` + `<app>/docs/`.

**Decision:** Run `flutter create android/app` so the Flutter scaffold lives at `android/app/`. `android/` itself holds only the convention docs.

**Why:**
- Keeps `android/CLAUDE.md`, `android/README.md`, and `android/docs/` clean — they aren't intermixed with `pubspec.yaml`, `android/`, `ios/` (which we'll delete), `web/`, `linux/`, `macos/`, `windows/`, generated `.dart_tool/`, etc.
- Matches the backend's split (`backend/` has both the project and the docs, but Python projects don't have the same scaffold-noise problem as Flutter's multi-platform scaffold).
- All `flutter` CLI commands run from `android/app/`. README documents this.

**Alternatives considered:**
- **`flutter create .` in `android/`**: simpler one-liner; rejected because the docs and the scaffold compete for the same directory.
- **Move docs to `flutter-docs/` at repo root**: breaks the per-app convention in `/CLAUDE.md` §1.

**Trade-off:** One extra `cd android/app` for any Flutter CLI command. The README front-loads this so it isn't surprising.

---

## 2026-06-09 — Queue polling: `AsyncNotifier` + internal `Timer`, not `StreamProvider`

**Context:** PLAN.md §8 originally specified "Polling is implemented via Riverpod's `StreamProvider` + `Stream.periodic`. **Not** via raw `Timer`s leaked from `StatefulWidget`s." That was written before milestone D2 (queue polling) and was correct on the "no `Timer`s leaked from `StatefulWidget`" point but underestimated the awkwardness of `StreamProvider` for the **pause/resume on app lifecycle** half of the same PLAN §8 contract.

**Decision:** Implement `queueProvider` as an `@Riverpod(keepAlive: true) class Queue extends _$Queue { Future<QueueResponse> build() … }` (`AsyncNotifier`) that owns a `Timer` internally. Expose `pause()` and `resume()` methods on the notifier; the `QueueScreen` (a `ConsumerStatefulWidget` with `WidgetsBindingObserver`) calls them from `didChangeAppLifecycleState`.

**Why:**
- `StreamProvider` exposes no imperative control surface to consumers — there's no way for the UI to tell the underlying stream "pause now, resume now". You'd have to put the lifecycle observer in the provider itself (couples the provider to `WidgetsBindingObserver`, hard to test) or wrap with a control stream + merge, which adds plumbing without changing semantics.
- `AsyncNotifier` cleanly separates the polling mechanism from the lifecycle binding. The notifier owns the `Timer` (cancelled in `ref.onDispose`), and the screen owns the lifecycle observer.
- The PLAN §8 "**Not** via raw `Timer`s leaked from `StatefulWidget`s" rule is still honoured — the `Timer` is owned by the provider, not by a `StatefulWidget`. The intent of that rule was "don't leak `Timer`s from screen widgets"; that's unchanged.
- The same shape will be reused at D3 (`jobStatusProvider(jobId)`) — family `AsyncNotifier` polling every 2s while non-terminal, stopping on terminal state. `StreamProvider` would have the same lifecycle-control problem there.

**Alternatives considered:**
- **`StreamProvider` + internal control flag**: implementable but the consumer can't reach the flag. Would require a sibling `queueControlProvider` for pause/resume, adding indirection for no gain.
- **`StreamProvider` + lifecycle observer inside the provider**: forces a `WidgetsBinding.instance.addObserver` call in provider code, which fights testability (now every provider test needs a `WidgetsBinding` ambient).
- **Raw `Timer.periodic` in `QueueScreen`**: explicitly forbidden by PLAN §8.

**Trade-off:** PLAN.md §6 + §8 wording was updated in the same task to match the implementation (CLAUDE.md staleness rule). The line "ticks every 3s + emits `QueueResponse`" still holds — the visible behaviour is the same; only the mechanism changed.

---

## 2026-06-11 — Stream via Navidrome Subsonic API, not via heerr backend

**Context:** Roadmap `ROADMAP_STREAMER.md` adds a streaming feature to the Android app so the user can play music in-app instead of falling back to Navidrome's web UI or a third-party Subsonic client. The library + audio data already exist on the home server — Navidrome scans `/data/media/music`, indexes everything, and exposes the standard Subsonic REST API (`/rest/*.view`). The question is whether the streaming/library endpoints belong on the heerr backend or whether the Android client should talk to Navidrome directly.

**Decision:** Android client speaks Subsonic to Navidrome directly. The heerr backend stays ingestion-only — its existing endpoints (`/search`, `/download`, `/queue`, `/status`) and scopes (`read`, `download`) are untouched. The Android app gains a second HTTP client (`subsonic_client.dart`) parallel to the existing heerr-backend dio, configured from a new set of Navidrome credentials persisted alongside the existing bearer-token settings.

**Why:**
- **Navidrome already implements the entire surface area we need** (auth, library browse, range-request streaming, transcoding, cover art, search). Re-implementing or proxying any of it in the heerr backend would duplicate working code for no gain.
- **No backend change → no new tests, migrations, or deploy.** The streaming feature ships as a pure-Android change, which is the smallest possible blast radius (and matches the "backend first, Android second" sequencing in `/CLAUDE.md` §3 — backend is *done* for this feature, no work blocked on it).
- **Subsonic is a stable, widely-implemented protocol.** Navidrome's implementation is well-tested by third-party clients (Symfonium, DSub, play:Sub). Talking to it directly inherits that maturity.
- **Single-user / Tailscale-only posture is preserved.** The phone reaches Navidrome over the tailnet exactly the way it reaches the heerr backend today — `http://<tailscale-host>:4533`. No new public surface, no new auth model.
- **Symmetric credential UX.** A second "Test Navidrome" button alongside the existing "Test heerr" button keeps the Settings flow intuitive — both backends are visible, both are testable, both are persisted via the same `flutter_secure_storage` abstraction.

**Alternatives considered:**
- **Proxy Subsonic through heerr.** Would let us put a single bearer token in front of both ingestion and streaming. Rejected: re-implements protocol semantics (range requests, error envelope, transcoding), adds Navidrome as a soft dependency the heerr backend would need to monitor, and gives the phone no new capability — the latency added by a second hop is real-time-perceptible during seek.
- **Implement streaming endpoints natively in heerr.** Same downsides as proxying, plus we'd be reinventing Navidrome's library scanner / metadata extraction. Rejected on principle (don't rebuild what works).
- **Use a third-party Subsonic client (Symfonium, DSub) for playback; keep heerr ingestion-only.** Rejected per the original scoping conversation: the user explicitly wants find → download → play in one app. Context-switching to another app on a "just downloaded a song, want to play it" flow is the exact friction this work removes.

**Trade-off:** The phone now needs two sets of credentials (bearer token for heerr, username/password for Navidrome) and two sets of `flutter_secure_storage` keys. Mitigated by the per-server `ServerProfile` record (added at the existing servers screen) carrying both — the user fills both in once per server. Existing profiles written before H1 are read back with `null` navidrome fields (the JSON parsing is tolerant), so the upgrade is silent for users that only have a heerr backend configured.

---

## 2026-06-11 — Combined library + YouTube Music search; standalone Search tab removed

**Context:** Pre-streaming, the bottom nav was `Search · Queue · Settings` and the Search tab hit `POST /search` on the heerr backend (YouTube Music via `ytmusicapi`). The streaming feature adds a Library tab driven by Subsonic (artists / albums / playlists browse + Subsonic `search3` for library-scoped search). That leaves the app with two parallel search surfaces — library search inside Library, and YouTube-Music search in its own tab — for the same noun ("find a song"). The question is whether both surfaces should coexist or collapse.

**Decision:** Drop the standalone `Search` tab at I1. Bottom nav becomes `Library · Queue · Settings`. The YouTube-Music search functionality folds into the Library tab's search affordance at I2 as a fall-back source: library results render first; YouTube Music auto-fires only when the library result is empty, or on an explicit "Search more on YouTube Music" tap when the library result is non-empty. A `combinedSearchProvider` orchestrates the two sources, surfacing both result sections plus a reactive-promotion mechanism that moves a downloaded YT result into the library section once Navidrome has re-indexed.

**Why:**
- **One search box, one mental model.** The pre-change layout forced the user to pick the right tab before typing: "is this in my library or do I need to download?" The combined flow lets the user just type — library hits surface immediately, YT shows up only when the library can't satisfy the query (auto-fire) or the user explicitly asks for it (the "Search more" button keeps IO opt-in for the common library-hit case).
- **No redundant IO.** Library `search3` is local-network / fast; YouTube Music's `ytmusicapi` is slower and rate-limited. Firing both on every keystroke would waste both. The auto-fire-on-empty-library + manual "Search more" rule means most queries hit Library only.
- **Reactive promotion glues the two flows together.** Tapping a YT result still dispatches to the existing `downloadDispatcherProvider`. When the queue's job-status transitions to `done`, the combined search invalidates `librarySearchProvider` so the song promotes from "On YouTube Music" → "In your library" on the next render — closing the find → download → play loop in one screen without re-typing.
- **Tab budget reclaimed.** Bottom nav with two tabs (Library, Settings) felt thin once Queue was the only "active state" tab. Library + Queue + Settings is the right balance now — Queue stays as the "what's happening server-side" surface, Library is the "what's in my world" surface, Settings is configuration.

**Alternatives considered:**
- **Keep both tabs.** Status quo plus a Library tab → four tabs, two search boxes. Rejected: cognitive overhead per the "one mental model" argument above; the user already approved the simplification ("kill the search tab") during the planning round.
- **Combined search, but fire YT in parallel on every keystroke.** Library + YT both render simultaneously, no opt-in. Rejected for the IO-cost reason. Easy to switch on later if the auto-fire-on-empty rule turns out to feel slow in practice — `combinedSearchProvider` is the single chokepoint.
- **Combined search, but YT only on manual tap (no auto-fire).** Slower UX when the library is empty — the user has to type, see "nothing in your library", then tap a button to discover what YT has. Rejected after the user explicitly preferred the auto-fire-on-empty rule.

**Trade-off:** `lib/screens/search_screen.dart` + its widget test are deleted at I1. `lib/providers/search.dart`, `lib/providers/download.dart`, and `lib/widgets/result_tile.dart` survive — they're consumed by `combinedSearchProvider` at I2 (with `searchResultsProvider` renamed to `ytmSearchProvider` for naming clarity once it's no longer the *only* search). Between I1 and I2 the YT-search providers are technically unused by any screen; the lint suite doesn't flag this, and the gap is one milestone wide. (`/CLAUDE.md` staleness rule: this ADR will be revisited at I2 if the combined-search behaviour materially diverges from this description.)

---

## 2026-06-11 — Host Activity must extend `AudioServiceFragmentActivity`

**Context:** J1 wired `just_audio` + `audio_service` and the unit-test gate passed, but the first on-device launch threw `PlatformException(The Activity class declared in your AndroidManifest.xml is wrong or has not provided the correct FlutterEngine...)` from `AudioService.init`. `MainActivity` was the default `FlutterActivity` subclass that `flutter create` ships, and intermediate fixes (switching to `FlutterFragmentActivity`; manually caching the engine in `configureFlutterEngine`) failed to silence the error.

**Decision:** `MainActivity` extends `com.ryanheise.audioservice.AudioServiceFragmentActivity` (provided by the `audio_service` package) rather than any flavour of `FlutterActivity` / `FlutterFragmentActivity`.

**Why:**
- The `audio_service` Android plugin's `onAttachedToActivity` calls `getFlutterEngine(activity)`, which reads `FlutterEngineCache.getInstance().get("audio_service_engine")` (`~/.pub-cache/hosted/pub.dev/audio_service-0.18.18/android/src/main/java/com/ryanheise/audioservice/AudioServicePlugin.java:315`). If the engine cached under that id is not the same instance attached to the host Activity, the plugin sets `wrongEngineDetected = true` and throws — because the plugin's MediaSession / foreground-service code path must communicate over the Activity's `BinaryMessenger`, not a parallel one.
- `AudioServiceFragmentActivity` overrides `provideFlutterEngine`, `getCachedEngineId`, and `shouldDestroyEngineWithHost` so the Activity *is* the plugin's cached engine. Self-rolling those overrides is feasible but every audio_service upgrade becomes a manifest review.
- Extending the package-provided base class is the upstream-recommended path (`audio_service` README "Android setup") and tracks future audio_service changes for free.

**Alternatives considered:**
- **Stay on `FlutterActivity` with a manual `configureFlutterEngine` override** that puts the activity's engine into `FlutterEngineCache` under id `"audio_service_engine"`. Rejected: the plugin checks the cache *before* `configureFlutterEngine` runs in some lifecycle paths (verified by re-hitting the same exception with the override in place), and the override is missing the `provideFlutterEngine` / `getCachedEngineId` / `shouldDestroyEngineWithHost` hooks the plugin actually depends on. Effectively a re-implementation of `AudioServiceFragmentActivity`, with maintenance cost.
- **Switch to plain `FlutterFragmentActivity`.** Required for some audio plugins (Fragment-based dialogs), but not sufficient on its own — the engine-cache wiring is the failure, not the Activity subclass tree. Verified by direct test.
- **Pin to an older audio_service major that didn't enforce the engine-cache check.** Rejected: the check exists because shipping with two engines silently breaks MediaSession on certain Android versions. Down-versioning to avoid a check is hiding a real bug.

**Trade-off:** `MainActivity` is now bound to `audio_service`'s base class. If we ever swap `audio_service` for a different platform-channel media stack, `MainActivity.kt` needs editing. Acceptable — the file is two lines and the swap is unlikely while audio_service remains the de-facto Flutter media-session library.

**Related:** `androidStopForegroundOnPause` was flipped `false` → `true` in the same fix. `audio_service` asserts the two booleans satisfy `notificationOngoing ⇒ stopForegroundOnPause`; otherwise the foreground service can leak past pause. Not a separate decision — a contract enforced by the package.

---

## 2026-06-13 — Playlist mutations: Subsonic 1.16.1, owner-only edits, no offline queue, reorder via delete-all-re-add, client-side dedupe

**Context:** With the streaming MVP shipped (K2) and the offline-download feature in (L6), the Android client could read playlists but couldn't change them — every CRUD op had to go through Navidrome's web UI on a desktop. Phase M (M1–M5) wires in-app playlist editing against Subsonic. The contract decisions below are common across M1–M4 and were validated by user feedback after M4 (which produced the Favourites + dedupe polish work).

**Decision:** Implement playlist mutations directly against the Subsonic 1.16.1 endpoints (`createPlaylist.view`, `updatePlaylist.view`, `deletePlaylist.view`) exposed by Navidrome. Lock the following sub-decisions:

1. **No new backend coupling.** The feature is pure-Android. The heerr FastAPI service (ingestion) is untouched — playlist edits go straight to Navidrome over Tailscale, same wire path as the K-era browse / playback calls.
2. **Auth + envelope parsing reuses `SubsonicAuthInterceptor` + `subsonicCall`.** Every mutation goes through `subsonicDioClientProvider`, so the standard `u/s/t/v/c/f` injection and the `subsonic-response` envelope → `ApiError` mapping work identically for read and write paths.
3. **`PlaylistMutations` is a single `@Riverpod(keepAlive: true)` stateless notifier.** Six methods (`createPlaylist`, `renamePlaylist`, `deletePlaylist`, `addSongs`, `removeSongsAtIndices`, `reorder`) + a derived `toggleFavourite(Song)`. Each method invalidates `libraryPlaylistsProvider` and (where applicable) `libraryPlaylistProvider(id)` on success so the L5 cache-aware wrapper re-fetches fresh data without bespoke listening code at the call site.
4. **Owner-only edits.** Every mutating affordance (rename, delete, add-to-playlist target list, edit mode, heart toggle's eventual remove path) is gated on `playlist.owner == settings.navidromeUsername`. Shared / read-only playlists never expose destructive UI.
5. **No offline mutation queue in v1.** Mutations require live connectivity to Navidrome. Failures surface via the existing `reactToApiError` snackbars ("cannot reach backend — check tailscale"). The library cache is invalidated on every successful mutation so the next online read reflects the change.
6. **Reorder via delete-all-and-re-add.** Subsonic 1.16.1's `updatePlaylist` only exposes append (`songIdToAdd`) and remove-at-index (`songIndexToRemove`) — no native reorder primitive. The notifier's `reorder()` issues a single `updatePlaylist` call that removes every index (descending) and re-adds the surviving songs via `songIdToAdd` in the new order. Navidrome processes removes before adds within one request. The UI's M4 commit path picks the smallest mutation: pure-removes → `removeSongsAtIndices`; any reorder (with or without removes) → `reorder()`.
7. **`addSongs` dedupes client-side, returns `Future<int>`.** Subsonic itself doesn't dedupe `songIdToAdd` — it'll append the same song twice if asked. The notifier fetches the playlist's current entry list via raw dio (`getPlaylist.view`, not via the provider so the cache isn't perturbed at the call site) and filters duplicates before calling `updatePlaylist`. Returns the count actually added so the UI snackbar can read "Already in '<name>'" / "Added N (M already there)" / "Added N".
8. **Favourites is a lazy-created regular playlist.** `kFavouritesPlaylistName = 'Favourites'` (UK spelling, per user). The first heart-tap calls `createPlaylist(name, [songId])`; subsequent toggles add or remove based on the song's current membership (via `libraryPlaylistProvider(favId).entry`). No special Favourites table, no Subsonic "star" primitive — just a playlist that happens to be named `Favourites`. `favouritesPlaylistProvider` finds it by `name + owner` match, `favouriteSongIdsProvider` derives the membership set for the heart icon's filled-vs-outlined state.

**Why:**
- **Backend purity matches scope.** The streaming and ingestion paths converge on Subsonic for library state already (K-era decisions); adding mutations elsewhere would split the read / write surfaces for no reason.
- **Owner gate is the safest default.** The user explicitly didn't want to delete or rename playlists they don't own (e.g. shared mixes); hiding the affordance is one less footgun than disabling it.
- **No offline queue keeps the failure mode obvious.** Queued offline writes would need a replay protocol, conflict detection, and per-mutation idempotency keys — all out of scope for a single-user home-server app. Online-only failures surface immediately via the existing snackbar copy.
- **Delete-all-re-add for reorder is the cheapest correct implementation.** Synthesising "move index i to j" client-side would require the same understanding of Subsonic's processing order plus extra round-trips for partial reorders. One call covers every case.
- **Dedupe in `addSongs` is necessary regardless of UI.** Without it, repeated long-press / heart-tap → "already there" → silent duplicate row in Navidrome. Easier to enforce at the notifier than to ask every UI surface to remember.
- **Favourites as a regular playlist** preserves "Subsonic is the source of truth" — the user can edit / delete / rename the Favourites playlist from Navidrome's web UI without breaking heart-toggle (the provider re-derives membership from the entries on the next read).

**Alternatives considered:**
- **Wrap the mutations behind a heerr-backend endpoint** for a single auth domain. Rejected: doubles the round-trip and complects the backend with a feature that already has a direct Subsonic path. Also: the backend's bearer-token scopes don't model edit/read of *Navidrome* state — they're for the ingestion pipeline.
- **Subsonic "star" primitive for Favourites.** The Subsonic API has `star.view` / `unstar.view` for marking songs / albums / artists as "starred". Considered as the Favourites store. Rejected: starred items don't render as a playlist in Navidrome's UI, so the user couldn't open or play their favourites as a list without extra plumbing. A regular playlist named "Favourites" surfaces in every other Subsonic client too.
- **Background offline-mutation queue.** Worth it if the user explicitly reports the foreground-online-only window is insufficient. Easier to add later than to remove later; deferred.
- **Server-side reorder via a custom Navidrome plugin.** Out of scope; we control the client, not the server.
- **Subsonic-side dedupe via a custom Navidrome build.** Same reason.
- **Optimistic UI for mutations** (write to the provider cache instantly, then network-flush). Considered for the heart-toggle in particular. Rejected for v1 because the provider invalidation chain re-fetches fresh data on the next read (~250ms perceptible) — acceptable cost for a feature where the user mostly sees the icon change immediately on tap. If the round-trip latency feels slow on Tailscale at home, optimistic updates can be layered in via a per-method `state` override later.

**Trade-off:** The notifier owns enough behaviour now (auto-dedupe, lazy-Favourites, diff-aware reorder) that it's no longer a thin Subsonic wrapper. Worth it because the alternative (push that logic into every UI surface that touches mutations) wouldn't have survived the M3 / M4 / polish iterations the user drove. The notifier stays the single chokepoint; UI stays declarative.

---

## 2026-06-14 — Phase N (recommendations + scrobble) — heerr v1.3.0

**Context:** The Android client had the find → download → play loop end-to-end (search → /download → Navidrome stream / offline). What it lacked was *suggestion*: nothing on-device proposed what to play next. Phase N adds the recommendations feature, which depends on a backend recommendations engine (backend Phase I — `RecommendationEngine` Protocol + ytmusic / Last.fm / ListenBrainz / fallback-chain implementations, shipped at `cc0abd7`). The Phase I ADR (`backend/docs/DECISIONLOG.md` 2026-06-13) locks the backend wire shape and engine selection model; this entry captures the client-side decisions that span N1–N5.

**Decision:**

1. **Scrobble at the Subsonic edge, not the heerr backend (N1).** The Android client emits standard `GET /rest/scrobble.view?id=<sid>&submission=<bool>` calls directly against Navidrome (`SubsonicEndpoints.scrobble`, auth via the existing `SubsonicAuthInterceptor`). Navidrome forwards to Last.fm / ListenBrainz when those server-side integrations are configured in `navidrome.toml`. heerr's FastAPI backend is **not** in the scrobble path.

2. **Plain-Dart `ScrobbleController` driven by streams (N1).** The controller listens to `audio_service.mediaItem.stream` (track changes) + `just_audio.positionStream` (playback progress). State machine: on a new `extras['subsonicId']` → fire `submission=false` once (now-playing notification); when `position >= 0.5 * duration` and not yet submitted → fire `submission=true` once. The "once per play" guard resets only on track change — seeks back-and-forth across the 50 % threshold do **not** re-fire. `scrobbleProvider` (keep-alive) instantiates the controller against `subsonicDioClientProvider`; the controller is plain Dart so tests drive it with `StreamController`s and a recording function callback.

3. **Seed collection is starred-first → frequent-broadening → Favourites-fallback (N2).** `seedCollectionProvider` calls `getStarred2.view` (starred songs — strongest signal) then `getAlbumList2.view?type=frequent&size=30` (broadening — frequently played albums become `(album.name, album.artist)` quasi-track seeds). Merge dedupes case-insensitively on `(title, artist)`, caps at 20. Favourites playlist entries fire **only** when both primary sources came back empty — avoids stacking on every fetch. The merge function is a pure Dart `buildSeedCollection(...)` so the rules are testable without standing up a Riverpod container.

4. **Recommendations provider sends seeds-or-empty, parses the engine-agnostic response (N3).** `recommendationsProvider` (AsyncNotifier) POSTs `{seeds, limit: 20}` to `Endpoints.recommend`. Empty seeds are still POSTed — the ListenBrainz engine produces results entirely from its own history. The response shape (`results: [RecommendedTrack(title, artist, source_url, score?)]`) is identical across engines: every engine resolves results to `music.youtube.com/watch?v=…` via the backend's shared `YTMusicResolver`, so the client tap-Download path goes through the existing `/download` flow with **no per-engine special-casing**.

5. **Library cross-reference resolves `inLibrary` + `subsonicSongId` per result (N4).** After the base `/recommend` response lands, the provider fires parallel `search3.view?query=<artist> <title>&songCount=1` calls (one per result) against the Subsonic dio. On match → `copyWith(inLibrary: true, subsonicSongId: <id>)`. Per-result failures are isolated (one bad search3 doesn't kill the list); missing Subsonic config no-ops gracefully (everything stays `inLibrary=false`). The screen's Play branch builds a synthetic `Song(id, title, artist)` and routes through `playSongFromSubsonic` — avoids a round-trip through `getSong` for one play.

6. **`manualSeedProvider` + Find Similar long-press (N4).** A `StateProvider<SeedTrack?>` sits alongside the seed collection. When non-null, `recommendationsProvider.build()` uses it as the **sole** seed and ignores `seedCollectionProvider`. `AddToPlaylistSheet` accepts an optional `findSimilarSeed` parameter — when present, renders a "Find similar →" tile that sets the manual seed and pushes `/library/recommendations`. The `RecommendationsScreen` clears the manual seed in `dispose` so the next entry returns to the general "For You" feed.

7. **Engine health is a typed indicator, not a free-form string (N5).** `recommendHealthNotifierProvider` (keep-alive) hits `GET /recommend/health` and parses a `RecommendHealth(engine, status, fallbackActive)` payload. The Settings section renders:
   - Green `OK` chip when `status == 'ok'`.
   - Amber `Degraded` chip otherwise, with a tappable help icon revealing inline diagnostic copy.
   - Optional `Fallback active` badge when the primary failed but a downstream engine in the chain is healthy.
   Refresh hooks: `SettingsScreen.initState` (post-frame) and `_ShellScaffoldState.unawaitedResume` (app resume) both call `refreshIfStale(maxAge: 60s)` — the notifier no-ops while the cached payload is fresh so rapid lifecycle events don't thrash the backend.

**Why:**

- **Scrobble at Subsonic** keeps the backend ingestion-only. Routing scrobbles through heerr would add a new endpoint, a new scope, and a server-side persistence layer that already exists in Navidrome. It also locks the user out of using existing Subsonic/Last.fm tooling (web UIs, third-party clients) against the same scrobble history.
- **Plain-Dart controller** makes the state machine testable without `audio_service` / `just_audio` / Flutter bindings. The "once per play, resets on track change, swallows scrobble exceptions" rules are exactly the parts that are easy to subtly break — they get exhaustive unit-test coverage at the controller level instead of being entangled with platform-channel concerns.
- **Starred-first seeding** matches the user's strongest signal (they actively starred this track) before falling back to inferred signals (frequent plays, then anything in Favourites). Pure-function merge logic also means the "what if both primary sources are empty" case has obvious semantics — fallback is opt-in to that specific state, not stacked on every fetch.
- **Engine-agnostic response shape** is the single most important wire-level decision. It means the Android client never knows which engine produced a row, so swapping `RECOMMENDATION_ENGINE` on the backend is invisible to the app. The `inLibrary` + `subsonicSongId` cross-reference happens client-side because only the client knows what's in *its* Navidrome library — the backend recommends globally.
- **Find Similar via long-press** reuses the existing `AddToPlaylistSheet` entry point. Users who already know about long-press for "Add to playlist" get the "Find similar" option in the same gesture without learning a new affordance; users who don't long-press never see either. Cheap to add, cheap to remove.
- **Engine health is typed + cached.** A raw `GET /recommend/health` call on every screen open is wasteful (the result rarely changes minute-to-minute); a manual cache is the right place to encode "this is an at-most-once-per-minute polling concern" instead of asking every consumer to remember.

**Alternatives considered:**

- **Scrobble through a heerr-backend endpoint.** Would let us put one bearer token in front of all writes. Rejected: same logic as the M-phase playlist-mutations ADR — backend purity, no new auth model, no new persistence concern, and the Subsonic path is already battle-tested.
- **Real-time scrobble channel (WebSocket) instead of HTTP.** Standard Subsonic clients use HTTP; matching the standard is the right default.
- **Server-side seed collection** (the backend reads the user's Navidrome state and builds seeds). Rejected: the user might run multiple Subsonic-compatible servers (Navidrome, Airsonic, Gonic) and the backend would need to know which to query. Client-side keeps the seed-source decision local.
- **Per-engine response shapes.** Rejected at backend Phase I; the client benefits identically — no engine-aware UI branches.
- **Include `inLibrary` in the backend response by sending the user's library state along with the request.** Rejected: ships the whole library (or a hash of it) on every request; the per-result `search3` call is bounded, parallelisable, and short-circuits if Subsonic isn't configured. Worst case 20 round-trips to a same-LAN service the app is already talking to.
- **`star.view` / `unstar.view` for the Find Similar bookmark.** Different concept entirely — Subsonic stars are user-curated favourites, not "things to find similar tracks to". The manual seed lives in app state because it's a single-shot operation, not a persistent label.
- **Always-on health probe (every screen render).** Rejected for the same reason the offline-sync provider has a TTL: the user opens Settings repeatedly, the backend should not see N × open calls.
- **Push notifications when the engine degrades.** Out of scope; would need an FCM project the rest of the app explicitly avoids. The Settings chip is reactive and accurate enough.

**Trade-off:** The recommendations feature now spans backend Phase I + Android Phase N, with the wire contract owned by the backend ADR (2026-06-13) and the UX + lifecycle owned by this ADR. Any breaking change to the response shape (e.g. adding `source_engine: String` per result so the UI can chip-tag rows) would need both ADRs revisited and a client/server release coordinated. That's the only fragility we accept — every other engine swap (ytmusic ↔ lastfm ↔ listenbrainz, single vs chain) is server-side only.

**Reference:** Implementation across `android/app/lib/{models/{seed_track,recommended_track,recommend_health}.dart, providers/recommendations.dart, screens/{recommendations_screen,settings_screen,library/library_screen}.dart, player/{scrobble_controller,scrobble_provider}.dart, widgets/add_to_playlist_sheet.dart, router.dart}`. Backend side: `backend/app/services/recommenders/*` + `backend/app/api/v1/recommend.py`. Roadmap milestones N1–N5 in `android/docs/ROADMAP.md` and CHANGELOG entries `2026-06-14 — N1` through `2026-06-14 — N5` enumerate the per-milestone deltas.

---

## 2026-06-12 — Offline downloads: prefer-local/fallback-to-stream, foreground-only sync, per-server manifest — heerr v1.1.0

**Context:** After K2 (streaming MVP), songs could only be played via Navidrome's HTTP stream. The Pixel 7 test device is on Tailscale; if the tailnet is unreachable (travel, VPN off) the library is entirely inaccessible. The ask: cache downloaded songs locally so they play from `file://` when the stream URL isn't reachable. This is a pure-Android slice — no heerr backend or Navidrome change is needed because the download source is the same Subsonic stream URL already used for playback.

**Decision:** Implement offline downloads as a prefer-local/fallback-to-stream layer across L1–L5, shipping as v1.1.0. Five sub-decisions locked for v1:

1. **Prefer-local, fallback-to-stream.** Not a full offline-first mode. `localUriForProvider` is the single chokepoint: if a `ready` manifest entry exists for the song, `song_to_media_item.dart` returns a `file://` URI; otherwise the Subsonic stream URL. All five play surfaces (album, artist, playlist, search, queue) route through the same chokepoint — no per-surface logic.

2. **App-private storage, per-server key.** Files land in `<appDocumentsDir>/offline/<serverKey>/`, where `serverKey = sha256(baseUrl + "|" + username).hex[0..16]`. App-private keeps the files off the shared media store (no `READ_EXTERNAL_STORAGE` permission, no media scanner interference). Per-server keying prevents manifest collisions when the user points at a different Navidrome instance.

3. **Single manifest JSON per server, atomic writes.** Manifest at `<appDocs>/offline/<serverKey>/manifest.json` tracks every song entry (`songId`, `state`, `filePath`, `sizeBytes`, `downloadedAt`). Writes are atomic (write to `.tmp`, then `rename`) so a crash mid-write leaves the prior manifest intact, not a half-written file. No TTL in v1 — the manifest is invalidated only by explicit unmark or "Clear all".

4. **Foreground-only sync, N=3 concurrency, WiFi gate.** `offlineSyncProvider` (`AsyncNotifier`, keep-alive) owns a periodic `Timer` that fires when the app is foregrounded. `WidgetsBindingObserver` in `_ShellScaffoldState` calls `pause()`/`resume()` on lifecycle transitions — no background wakeup, no `WorkManager`. Concurrency is capped at 3 parallel downloads (avoids saturating the home-server NIC). WiFi gate: `connectivity_plus` checks `ConnectivityResult.wifi` before each batch — WiFi-only mode skips downloads on mobile data.

5. **Metadata cache (L5): write-on-success, serve-on-failure, no TTL.** All six library providers (`libraryArtistsProvider`, `libraryArtistProvider`, `libraryAlbumProvider`, `libraryPlaylistsProvider`, `libraryPlaylistProvider`, `librarySearchProvider`) are wrapped in `cacheAware(...)`: success → write to `<serverKey>/cache/<provider-key>.json`; failure → serve prior cache if it exists, rethrow if not. Cover art bytes are persisted to `<serverKey>/covers/<artId>` on first load; `LibraryCoverArt` widget falls back to `Image.file` when offline.

**Why:**

- **Prefer-local/fallback is safer than offline-first.** A full offline-first design would require the app to detect which songs it doesn't have and either block playback or handle a missing-file error mid-stream. Prefer-local is simpler: the playback path is unchanged; local files just intercept it when they exist.
- **Single chokepoint in `song_to_media_item.dart`.** Centralising the local-vs-stream decision in one function means the five play surfaces need zero offline awareness — they produce `Song` objects the same way they always did.
- **App-private storage** avoids the `READ_EXTERNAL_STORAGE` permission and media-scanner indexing side effects. The user never needs to interact with these files in a file manager.
- **Atomic manifest writes.** The manifest is the source of truth for "what's downloaded". A corrupt manifest would break all offline playback — the atomic write + fallback-to-empty-on-corrupt-JSON guards against this.
- **Foreground-only sync** is the right default for a single-user home-server app. Downloads are fast (LAN speeds over Tailscale), and the user is typically watching the screen when they mark something. `WorkManager` would add significant complexity (wake locks, battery optimisation exemptions, retry policies) for a marginal benefit.
- **N=3 concurrency** is empirical — 1 is too slow for a 300-song album, unbounded hammers the home server's disk IO. 3 keeps the server comfortable and the UI responsive.
- **Metadata cache with no TTL.** The library doesn't change while the user is offline; a stale-but-correct cache is the right tradeoff. The next successful online render overwrites, which is the only meaningful "TTL" in this use case.

**Alternatives considered:**

- **Download via heerr backend (`/download` endpoint).** The backend already invokes spotDL and writes files to the Navidrome library. Rejected: spotDL files are already in the library; re-downloading them to the device via the backend would double the network path and require a new backend endpoint. The Subsonic stream URL is the correct source.
- **`WorkManager` for background sync.** Would allow sync while the screen is off. Rejected for v1: complexity far exceeds the benefit for a single-user, always-home-network app. Deferred to v2 if user reports the foreground window is insufficient.
- **SQLite instead of JSON manifest.** More robust at scale, richer query surface. Rejected: the manifest is O(library size) but accessed in bulk at sync time, not queried per-song. JSON + full in-memory parse is simpler and fast enough for libraries under ~10K songs.
- **Per-song sidecar files instead of a central manifest.** Would avoid the manifest-write bottleneck. Rejected: a central manifest is easier to inspect, backup, and clear atomically. The write-bottleneck concern doesn't apply at the sync cadences we're operating at.
- **MediaStore / shared external storage.** Would make downloaded files visible in other apps' file browsers. Rejected: not a requirement, and avoiding `READ_EXTERNAL_STORAGE` is always preferable.

**Trade-off:** The manifest is a single file shared across all sync operations. If the user syncs a 500-song library, the manifest file could grow to ~200 KB — still in the range where the full parse-on-load is fast (<5 ms). Beyond ~50K songs this would warrant an incremental writer; that's outside single-user home-server scope.

**Reference:** Implementation in `android/app/lib/offline/` (`offline_paths.dart`, `offline_manifest.dart`, `offline_settings.dart`, `offline_marker.dart`, `offline_downloader.dart`, `offline_sync.dart`, `local_uri.dart`, `offline_size_estimator.dart`, `library_cache.dart`). Playback integration in `player/song_to_media_item.dart` and `player/playback_actions.dart`. UI in `widgets/library_result_tile.dart`, `screens/library/{album,playlist}_detail_screen.dart`, `screens/settings_screen.dart`.

---

## 2026-06-14 — Phase O: Home screen as default tab; Queue removed from bottom nav — heerr v1.4.0

**Context:** After Phase N, the bottom nav was `Library · Queue · Settings`. The app's value proposition is find → download → play, but the first screen after launch was always the Library — correct for a "browse your collection" app, but not for one that also recommends what to play next. The Queue tab was the third item in the nav, but most of the time it's empty or only interesting during an active download — a poor use of a persistent tab slot.

**Decision:** Add a Home screen as the new default boot destination and replace the Queue tab with it. Bottom nav becomes `Home · Library · Downloads · Settings`. Queue remains navigable from the Home AppBar (`queue_music_outlined` IconButton → `/queue`). Four sub-decisions locked:

1. **Home is the new `initialLocation` (`/`); Library moves to `/library`.** All library nested routes (`/library/artist/:id`, `/library/album/:id`, `/library/playlist/:id`, `/library/recommendations`) keep the same URL shape; only the base segment changed. `Routes.*` helper getters updated so call sites needed no edits.

2. **Home screen layout: Spotify-style greeting + 2-col quick-access grid + horizontal sections.** Time-of-day greeting (`"Good morning"` / `"Good afternoon"` / `"Good evening"`) from pure-Dart `greetingForHour(int)`. Quick-access grid: 2-column `GridView` of up to 6 recently-played albums from `homeRecentProvider`; falls back to `homeRecommendationsProvider` results when recent is empty. Sections: "Jump back in" (recent albums), "Most played" (frequent albums), "Picked for you" / "Discover" (recommendations). All three data sources (`getAlbumList2.view?type=recent`, `getAlbumList2.view?type=frequent`, recommendations) fire in parallel at screen build; pull-to-refresh invalidates all four providers.

3. **`homeRecommendationsProvider` falls back to random songs (`getRandomSongs.view?size=20`) when the backend returns an empty result list.** Returns a `HomeRecommendations(tracks, isFallback)` record; `isFallback=true` changes the section header from "Picked for you" to "Discover". This ensures the section is never empty (a cold-start app with no scrobble history still shows discovery content), while making clear to the user when they're seeing curated vs random content.

4. **Per-card cover art on `HomeRecommendationCard` is deferred.** The card shows a colour-swatch placeholder in v1. Resolving cover art would require a `getSong.view` call per recommendation row (the recommendation response carries only `title`, `artist`, and `source_url` — no Navidrome `coverArtId`). At 20 cards × 1 request this is 20 extra Subsonic round-trips on every Home load. Deferred until the placeholder is reported as a friction point.

**Why:**

- **Home as default tab.** A tab that shows "what to play next" is a better cold-open than a library browser. Library is where you go with intent; Home is where the app sells itself. This matches Spotify, Apple Music, and YouTube Music's home-tab convention.
- **Drop Queue from the nav.** Queue is a transient state — only relevant during and immediately after a download. A persistent bottom-nav slot signals that the content is always worth checking, which Queue is not. Moving it to an AppBar icon on Home makes it discoverable without wasting a nav slot.
- **4 tabs (Home / Library / Downloads / Settings).** Downloads earns its own tab (persistent offline state the user actively manages); Settings is always-available for credential management. 4 tabs is the Material 3 design-system recommended maximum for bottom nav.
- **Fallback to random songs.** Without it, a new install's Home screen would be mostly empty (no recent albums, no recommendations without scrobble history). Random songs from the library are a better cold-start experience than empty sections and preserve the discovery narrative.
- **Defer per-card cover art.** The 20 extra `getSong.view` round-trips per Home load matter on a Tailscale connection (each is ~10–50 ms). The placeholder is visually acceptable in v1; the fix is a targeted optimisation that can land without any architectural change when it becomes a priority.

**Alternatives considered:**

- **Keep Queue in the nav, add Home as a 5th tab.** Five tabs exceeds the Material 3 bottom-nav guideline and makes the bar visually crowded on 5" phones. Rejected.
- **Make Library the default tab but add a Home widget/banner above the library list.** Hybrid approach — keeps Library as the primary surface but inserts discovery content at the top. Rejected: it complicates the Library screen and doesn't give the Home content the visual weight it deserves.
- **Fire both `getAlbumList2.view?type=recent` and `getAlbumList2.view?type=frequent` in a single aggregated provider.** Would simplify pull-to-refresh. Rejected: the two sections have different fallback behaviours; separating them keeps each provider testable in isolation.
- **Resolve cover art for recommendation cards at build time (parallel `getSong.view` calls).** Correct but expensive at 20 parallel round-trips per Home load. Deferred as noted above; could be implemented as a lazy-load (cards render with placeholder, then fill in on scroll).

**Trade-off:** Queue is now one extra tap from the Home screen (AppBar icon) instead of one tap from anywhere (bottom nav). Acceptable because Queue is only relevant when the user is actively downloading, and at that moment they're already on the Home screen watching the recommendations or the grid update.

**Reference:** Implementation in `android/app/lib/screens/home/home_screen.dart`, `providers/home/home_providers.dart`, `widgets/{home_grid_tile,home_section,home_recommendation_card}.dart`, `router.dart`. Tests in `test/screens/home/home_screen_test.dart`, `test/providers/home/home_providers_test.dart`, `test/widgets/home_recommendation_card_test.dart`. CHANGELOG entry `2026-06-14 — Phase O`. Roadmap milestones O1–O5.

---

## 2026-06-15 — v1.5.0 player polish band: re-scope X2 / X3 / X4a in from ROADMAP "out of scope"

**Context:** v1.4.0 (Phase O) closed the main feature roadmap (A–O). Three items in ROADMAP "Out of scope" were called out in `DEBT.md` as user-facing gaps that would meaningfully improve the player surface without architectural risk: persisting Now Playing across cold starts (X2), Subsonic lyrics (X3), and a sleep timer (X4a — the sleep-timer-only subset of the X4 "Sleep timer / Cast / Lyrics / Equaliser" bundle). The user confirmed scope and asked for these to ship as a single polish band before tackling the larger background-sync work.

**Decision:** Re-scope X2, X3, and X4a into the roadmap as Phase P (P1–P4), shipping together as v1.5.0. Update ROADMAP "Out of scope" to remove these items. Each milestone is independently testable; the bundling is a release-shape decision, not a coupling.

**Why:**
- **X2 (persist Now Playing).** Closes the "cold-start Now Playing drops the queue" surprise that breaks the find-→-download-→-play loop. Cheap (one persistence module + one restore hook); reuses the atomic-write pattern from `offline_manifest.dart` (L1) so the safety story is unchanged.
- **X3 (lyrics).** Subsonic 1.16 already exposes `getLyrics.view`; Navidrome implements it. Adding a UI toggle in Now Playing is one endpoint, one model, one provider, one screen change. Skipping a third-party Subsonic client to read lyrics is the same UX argument that motivated the original streaming-in-app decision (2026-06-11 ADR).
- **X4a (sleep timer only).** Sleep timer is a `StateNotifier<Duration?>` + `Timer` — small, contained, well-bounded test surface (`fake_async`). The rest of the X4 bundle (gapless, crossfade) needs deeper `just_audio` integration (`ConcatenatingAudioSource` swap; dual-player infra for crossfade) and is deferred to v3.
- **Why bundle rather than three minor releases.** Each item is small enough that three back-to-back ships would burn smoke effort and release ceremony without giving the user something materially different per ship. One v1.5.0 ship is the right unit of release for a polish band.

**Alternatives considered:**
- **Ship each X-item as its own minor (1.5.0 / 1.6.0 / 1.7.0).** Smaller blast radius per release, more granular CHANGELOG. Rejected for the bundle-vs-ceremony reason — they're related enough that one polish-band ship reads more cleanly in the version history.
- **Roll X4 (full sleep timer + gapless + crossfade) into v1.5.0.** Crossfade requires dual-player infra in `just_audio`; not a v1.5.0-band amount of work.
- **Hold X3 (lyrics) for v3 alongside Cast.** Both are "music-app-feel" features. Rejected: lyrics ships in half a day; coupling it to a multi-month Cast effort would unnecessarily delay it.
- **Skip X2 (persist Now Playing) until users complain.** Rejected: it's a regression vs. every other music app the user has used; the absence is a passive friction point that's invisible until you cold-start the app and lose the queue.

**Trade-off:** v1.5.0 doesn't unblock the "leave the app, sync downloads in the background" use case (X1) — that's Phase Q / v2.0.0. Acceptable: X1 is a multi-milestone effort (WorkManager integration, constraint policies, foreground/background interlock) and shouldn't gate the polish ship.

**Reference:** ROADMAP Phase P (P1–P4) for milestone shape. DEBT.md "v2 candidates" updated to mark X2 / X3 / X4a as scheduled.

---

## 2026-06-15 — v2.0.0 background offline sync via WorkManager (X1)

**Context:** v1.1.0 (Phase L) shipped the prefer-local/fallback-to-stream offline-downloads feature with a foreground-only sync window — the ADR (2026-06-12, "Offline downloads") explicitly flagged WorkManager / background sync as deferred to v2 if foreground-only proved insufficient. The deferral has held but the limitation is now visible: marking an album then backgrounding the app leaves the download in a `pending` state until next foreground. For the travel / offline-prep use case (mark before bed, sync overnight, play on a flight) the foreground window is the wrong shape.

**Decision:** Lift the foreground-only constraint with a `WorkManager`-driven periodic background sync. Ship as Phase Q (Q1–Q4) / v2.0.0. Three sub-decisions locked:

1. **WorkManager calls into the existing `OfflineSync` notifier code path.** The background worker creates a Riverpod container, calls `offlineSyncProvider.syncNow()`, then disposes. No parallel sync implementation. This keeps the manifest write path identical in foreground and background — atomic writes from L1 already protect the invariant under contention; Q1 adds a contention test to verify the assumption.
2. **Constraints derive from existing + one new setting.** `offline_wifi_only` → `Constraints.NetworkType.UNMETERED` (reuses the existing toggle). New `offline_charging_only` → `Constraints.requiresCharging` (opt-in, off by default). Periodic interval is the existing `offline_poll_interval_min` (15 min floor enforced by WorkManager).
3. **Foreground/background interlock: cancel-on-resume + schedule-on-background.** When the app foregrounds, cancel any in-flight background work to avoid double-downloads. When the app backgrounds with pending markers, schedule the worker for the next interval. The manifest stays the single source of truth — a cancelled mid-flight download leaves no orphan state because the manifest entry is only flipped to `ready` after the file is fully written and verified.

**Why:**
- **Single code path** for foreground + background sync means one set of tests, one set of bugs, one set of guarantees. The alternative (separate background implementation) doubles the surface for race conditions against the manifest.
- **Reuse existing settings.** `offline_wifi_only` was designed for the foreground sync but the semantics translate directly to WorkManager constraints. Adding `offline_charging_only` is the only new setting needed.
- **Interlock prevents double-downloads.** Without it, a user who backgrounds the app mid-sync and immediately re-opens would observe two parallel sync attempts. The cancel-on-resume rule keeps the foreground sync authoritative when the app is visible.
- **Major version bump.** WorkManager adds a new permission (`RECEIVE_BOOT_COMPLETED`), a new dep, and a new behaviour (sync runs without the app being open). All three are semver-significant enough to justify `2.0.0` over `1.5.0` even though the user-visible UI delta is small.

**Alternatives considered:**
- **AlarmManager + foreground service** instead of WorkManager. More direct control, no minimum 15-min interval. Rejected: Android's background-execution restrictions on API 26+ make raw `AlarmManager` painful, and the foreground service notification would be intrusive for an app that's already noisy with the audio session.
- **Foreground service that the user explicitly starts** ("Sync now and keep syncing"). Rejected: the whole point of background sync is that the user doesn't have to interact. A persistent notification + manual start is just a worse foreground mode.
- **Server-side push to wake the app** (FCM message → sync). Rejected on the same grounds as every other "use FCM" decision in this repo: requires a Firebase project, conflicts with the no-FCM posture (`/CLAUDE.md` §3), and the polling cadence is fine for a feature with no real-time requirement.
- **Skip background sync entirely; raise the foreground polling interval and assume users will leave the app open longer.** Rejected: the use case (overnight sync of marked albums) cannot be satisfied without the app running in the background. Foreground-only is structurally incompatible with that flow.

**Trade-off:** WorkManager has a 15-minute minimum periodic interval. For a user who marks an album and immediately wants it cached, the foreground sync remains the right path — the existing foreground `OfflineSync` tick continues to run when the app is open. Background sync is the "set and forget" path, not the "right now" path.

**Reference:** ROADMAP Phase Q (Q1–Q4). DEBT.md X1 entry updated to mark as scheduled. Backend remains untouched (pure-Android slice).

## 2026-06-16 — X4b: gapless playback via `useLazyPreparation: false` — heerr v2.1.0

**Context:** After v2.0.0 (background sync) shipped, X4b was the lowest-effort outstanding v3-backlog item. The DEBT.md note hinted at a "`ConcatenatingAudioSource` switch in `just_audio`", but the codebase already uses `setAudioSources(List<AudioSource>)` — the modern just_audio API for a playlist. The audible inter-track gap was coming from elsewhere.

**Decision:** Construct `HeerrAudioHandler`'s `AudioPlayer` with `useLazyPreparation: false`. Ship as Phase R / v2.1.0 (single-milestone phase — one constructor flag, no architectural change).

**Why:**
- `just_audio` 0.10's `AudioPlayer({useLazyPreparation = true, ...})` controls when subsequent items in the playlist are prepared. With the default (`true`), each `AudioSource` is built only when ExoPlayer needs to play it — producing the gap. With `false`, ExoPlayer pre-prepares the next source and performs its native gapless hand-off when the current renderer completes.
- The flag is per-`AudioPlayer`; no per-source override needed.
- For HTTP / streaming sources (Subsonic stream URLs, offline `file://` URIs), "eager preparation" amounts to URI parse + initial-buffer fetch — a negligible cost on the Tailscale-LAN connection the app already uses for playback.
- The handler accepts an `AudioPlayer? player` for tests; the default-constructor path is the only place that needs the flag.
- No effect on the `localUriForProvider` chokepoint or the scrobble-controller "once per play, resets on track change" guard — both depend on `mediaItem.stream` transitions, which still fire identically whether preparation is lazy or eager.

**Alternatives considered:**
- **Switch from `setAudioSources` to the deprecated explicit `ConcatenatingAudioSource`.** Same underlying playlist primitive; gives no extra control. Rejected as a backwards step.
- **Tune `audioLoadConfiguration` (Android `LoadControl`).** Buffer-size / re-buffer thresholds; orthogonal to the gapless transition. Rejected — not the cause of the gap.
- **Switch to a different audio backend (`media_kit`, `audioplayers`).** Architectural rework against a one-flag fix. Rejected.

**Trade-off:** Eager preparation across the entire queue means slightly more memory pressure for very long queues (`getRandomSongs.view?size=500`-class lists). For the single-user / home-server scope this is invisible; if it ever isn't, a custom `audioLoadConfiguration` can cap the prepared window without flipping `useLazyPreparation` back to `true`.

**Reference:** `android/app/lib/player/heerr_audio_handler.dart` constructor. No test changes — existing tests construct the handler with a stub player and don't exercise the live constructor path.

---

## 2026-06-17 — Multi-user profiles via Navidrome IdP — heerr v3.0.0

**Context:** v2.1.0 (gapless) closed the player-polish band. The next slice of demand is multi-user: a single Android device shared by two or more Navidrome users — most concretely the operator and their partner — each expecting their own library, queue, scrobble history, offline downloads, and recommendations. The existing app stored a single `(heerrBaseUrl, bearerToken, navidromeBaseUrl, navidromeUsername, navidromePassword)` tuple in `flutter_secure_storage`; the user-experience story stopped at "log out and re-paste creds". Phase S replaces that with a registry of [Profile]s and an active-profile pointer, with the backend's new `POST /api/v1/auth/login` (backend J6) issuing the bearer token after Navidrome validates the password.

**Decision:** Lock the following sub-decisions, shipping as Phase S (S1–S11) / `v3.0.0`:

1. **Navidrome is the IdP; heerr backend is the issuer.** The Android client posts `{username, password}` to `POST /api/v1/auth/login`; the backend forwards the check to Navidrome and, on success, returns `{token, scopes, navidromeUrl, navidromeUsername}`. The device never speaks directly to Navidrome's `ping.view` for *authentication* — Navidrome's password is checked once, via the backend, on login. Subsonic calls thereafter still use the password client-side (Subsonic salted-md5 over `u/s/t/v/c/f`), so the password has to live on-device until logout.
2. **Hard logout / login, one active profile at a time.** No soft "switch profile in place" — every profile-switch invalidates the dio clients (S7), the settings overlay (S8), and the offline `serverKey` (L1). A single notifier (`profileRegistry`) owns the list + the active-id pointer; `activeProfileProvider` (S6) is the single read-side chokepoint.
3. **`serverKey` keeps per-server state isolated automatically.** L1's `sha256(navidromeBaseUrl + "|" + navidromeUsername).hex[0..16]` predates Phase S and already routes offline manifests, library cache, cover-art cache, and download files through a per-server directory. Because the S8 `settingsProvider` overlay echoes the active profile's `(navidromeBaseUrl, navidromeUsername)`, every existing chokepoint is implicitly per-profile — no byte migration needed when the user switches.
4. **Legacy single-set creds migrate exactly once into a default `Profile`.** `migrateLegacyCreds` (S3) runs in `main.dart` before `runApp`. Detection requires all five legacy keys to be present and non-empty; partial state is left alone (S5 login flow re-collects everything). Migration is idempotent on three axes — already-migrated, no-legacy, partial-legacy all no-op.
5. **First-launch redirect via `GoRouter.redirect`.** When `activeProfileProvider` is null, every navigation outside `/login` rewrites to `/login` (S5). Conversely, when active is non-null, `/login` redirects to `/`. The redirect closure reads `profileRegistryProvider` from the root `ProviderContainer` — wired by passing the container into `buildHeerrRouter(container: ...)`.
6. **Settings overlay over per-rewire.** Instead of rewiring every per-server provider to read `activeProfileProvider` directly (offline_paths, library_cache, manifest, NowPlaying persistence, sleep_timer, scrobble_controller), `settingsProvider.build()` (S8) overlays the active profile's `(heerrBaseUrl, heerrBearerToken, navidromeBaseUrl, navidromeUsername, navidromePassword)` onto the `SettingsValue` tuple. The legacy single-set keys remain the fallback for the brief pre-hydration window and for unmigrated installs. Every existing callsite that hashed `(navidromeBaseUrl, navidromeUsername)` into a `serverKey` continues to compile and now isolates per profile automatically. Defense-in-depth: S7 also wires the heerr + Subsonic dio providers to read `activeProfileProvider` directly so a future rewrite can drop the overlay without leaking creds across profiles in the interim.
7. **Carve-out in `android/CLAUDE.md`.** The existing "Single-user. No multi-user login, no Sign-In-With-X, no biometric token unlock" hard rule is rewritten to (a) permit the Navidrome-IdP login flow specifically and (b) still forbid every other Sign-In-With-X provider (Google, Spotify, Apple). The rule "the bearer token is created on the backend via the CLI" is loosened to "or minted by the backend's `POST /auth/login` IdP shim". The "no biometric token unlock" line stays — biometrics is out of scope for v3.

**Why:**

- **Backend Phase J as IdP shim** keeps heerr ingestion-only on the protocol axis (every read/write to the music library still flows through Navidrome's Subsonic surface) while collapsing the user-visible login UX to a single password field on the device. The user already has Navidrome creds; they don't have to remember a separate heerr password.
- **Hard logout/login** ships a tested invariant (per-profile state isolation by `serverKey`) instead of a hard-to-test invariant (concurrent profiles in memory, mid-session swap). The cost is one extra "Switch?" confirmation dialog every few weeks; the benefit is no leaked queue / offline / scrobble state.
- **Settings overlay** is one ~12-line change versus the alternative — rewiring every per-server provider to take a `Profile` argument. The overlay also keeps the existing tests' `SettingsValue` contract intact, so the Phase S work doesn't have to touch the L1 / L5 / P1 test suites.
- **Idempotent migration** lets the v2.1.0 → v3.0.0 upgrade be silent for everyone who had creds saved before the bump; users in a partial-creds state (rare — they'd never have got past the existing Settings flow) just see the login screen and re-enter.
- **`/login` redirect at the router level** ensures the unauthenticated state can't be navigated *around* — a deep-link from a notification or share-sheet still passes through the gate.
- **CLAUDE.md carve-out, not deletion.** The "no Sign-In-With-X" rule was about avoiding Google / Spotify / Apple-Auth dependencies, not about Navidrome. The new carve-out reflects that distinction: Navidrome is already inside the trust boundary (it's the music library; we already store its password); Google et al. are not.

**Alternatives considered:**

- **Soft profile switch (no logout)** — keep both profile credentials hot, swap the active one in memory. Rejected: every per-server cached state (just_audio's queue, offline_sync's mid-flight downloads, scrobble's submission-pending flag) would need a "discard on switch" hook. Hard switch reuses the existing app-launch teardown for free.
- **Per-rewire instead of settings overlay.** Cleaner final state — `SettingsValue` would only ever hold non-per-server fields. Rejected for v3.0.0 because it touches every per-server callsite (≈ 20 files) for a feature whose v1 spec doesn't require structural change. Can be done as a follow-up cleanup if/when the overlay becomes confusing.
- **OAuth / OIDC through a third-party IdP** (Authelia, Keycloak). Rejected: the user is a single household; the operator runs Navidrome; there's no separate identity domain to federate. Navidrome already authenticates the same people for the same content; adding another auth domain is a net-negative.
- **Per-user Last.fm / ListenBrainz.** Scrobbles currently flow through Navidrome's `scrobble.view` and Navidrome forwards to the user's own configured Last.fm in `navidrome.toml`. Multi-user is implicit: each Navidrome user has their own forwarding config. No client-side change needed; deferred to v3.1.0 only if users report mis-attribution.
- **Biometric unlock for the password.** Out of scope for v3.0.0 — adds `local_auth` dep and a re-auth flow on app resume. Can be slotted in later as a transparent unlock step before the Subsonic dio fires.

**Trade-off:** Two profile-switches per day across a household of two people means two extra app-restart-equivalent navigation events. The teardown work (dio rebuild, settings re-read, profile registry write) totals ~50 ms locally; perceptible as a brief loading spinner on Home but not a friction point. If we later observe users avoiding switches because of the delay, optimistic `setActive` (write pointer first, defer dio rebuild) is a small follow-up.

**Reference:** Implementation across `android/app/lib/{models/profile.dart, providers/profiles/{profile_registry,active_profile,legacy_migration}.dart, api/{auth_login,client,subsonic_client}.dart, screens/auth/login_screen.dart, screens/settings/profiles_section.dart, providers/settings.dart, main.dart, router.dart}`. Tests under `android/app/test/{models/profile_test.dart, providers/profiles/*, api/{auth_login,profile_keyed_clients}_test.dart, screens/auth/login_screen_test.dart, screens/settings/profiles_section_test.dart, offline/profile_isolation_test.dart}`. Backend J6 (`POST /auth/login`) is a hard dependency for S5.

---

## 2026-06-19 — Collapse the dual credential system + relocate offline prefs (debt A1/A4/A5)

**Context:** The 2026-06-18 architectural audit (`docs/DEBT.md` §5) flagged three coupled P0 items. **A1:** after Phase S the app had *three* credential stores coexisting — the Phase-S `ProfileRegistry` (`profiles_index`), the pre-S single-set secure-storage keys (`backend_base_url`, `bearer_token`, `navidrome_*`), and the even-older `ServerProfiles` notifier (`server_profiles` blob, surfaced by the still-routed `ServersScreen`). `Settings.build` overlaid the active profile on top of the single-set keys, and the legacy `ServersScreen` dual-wrote both the blob and the single-set keys. **A4:** `Settings.build` did 10 sequential `await store.read(...)` keystore round-trips on every invalidation. **A5:** five non-secret offline-download prefs lived in EncryptedSharedPreferences alongside the actual secrets. The DEBT note assumed `ServerProfiles` was dead code; inspection showed it was still reachable via `/settings/servers` (and the `_ServersTile`, gated on `!hasActive`), making it live-but-unreachable dual-write code rather than dead code.

**Decision:**
1. **The active `Profile` is the single source of every per-server credential.** Delete `ServerProfile` / `ServerProfiles` / `ServersScreen` / the `/settings/servers` route / `_ServersTile`. `Settings.build` reads creds only from `activeProfileProvider` — no legacy single-set-key fallback. `Settings.save()` no longer accepts credential parameters (logins write via the profile registry).
2. **Both dio providers read creds only from `activeProfileProvider`.** Drop the `active?.x ?? settings.x` dual-read in `client.dart` / `subsonic_client.dart` — it was the literal `android/CLAUDE.md` "don't read creds from settingsProvider AND activeProfileProvider in the same callsite" violation, and the fallback became dead once `settings` creds derive solely from the active profile.
3. **Offline prefs move to plain `shared_preferences`** behind a new `PrefsStorage` abstraction (same interface as `SecureStorage`), with a one-shot idempotent `migrateOfflinePrefs` in `main.dart`. Offline fields stay *in* `SettingsValue` for now — the tuple split (A6) is deferred.
4. **`NavidromeAuthError` redirects to `/login`** (re-auth the active profile) now that the Servers screen is gone.

**Why:**
- **One credential store removes a whole class of drift.** A new screen can no longer pick the "wrong" source; the overlay-and-mirror dance is gone. The `serverKey` chokepoint (L1) still hashes `(navidromeBaseUrl, navidromeUsername)`, which now resolve from the active profile via `SettingsValue` — so every offline/cache/now-playing path stays per-profile with zero per-callsite rewiring.
- **A4 falls out for free:** creds come from the in-memory active profile (no read), and the five offline prefs are fetched in one `Future.wait` batch — 10 sequential keystore reads → one concurrent batch.
- **A5:** the keystore is for secrets (bearer token, Navidrome password — both in the profile registry). User prefs paying the keystore round-trip on every read was misuse; `shared_preferences` is the right backing.
- **DevDefaults wired into `/login`** so the dev-reinstall convenience the deleted `ServersScreen` provided isn't lost (URL + username pre-fill only; never the password).

**Alternatives considered:**
- **Keep `Settings.build`'s overlay (active-over-legacy) and just delete `ServerProfiles`.** Rejected: the legacy single-set keys would linger as a write-target nobody owns; the overlay was the drift surface A1 names. Reading creds *only* from the profile is the clean end-state.
- **Leave offline prefs in secure storage; only fix A1/A4.** Rejected: A4's sequential-read cost is dominated by the keystore; moving the offline prefs to `shared_preferences` is what makes the batch cheap, and A5 is a one-file change once the storage seam exists.
- **Split `SettingsValue` into separate creds / offline records now (A6).** Deferred: it touches ~15 consumers and isn't required to land A1/A4/A5. Tracked as A6.
- **Full stateless-interceptor refactor (A3).** Deferred: this band fixes the dual-*read* hard-rule violation, but the interceptors still capture the token by value at Dio-construction (rebuild-on-profile-change). A3 remains open.

**Trade-off:** `shared_preferences` is a new dependency and a new platform surface. Mitigated: it's the Flutter-team-standard prefs plugin, the migration is idempotent, and `PrefsStorage` mirrors the existing `SecureStorage` seam so tests substitute a fake the same way. Test cost was real — `settings_test` was rewritten and a shared `test/support/cred_test_support.dart` helper now backs the ~10 offline/library/screen tests that previously seeded creds via legacy keys.

**Reference:** `android/app/lib/{providers/{settings,prefs_storage}.dart, api/{client,subsonic_client}.dart, screens/{settings_screen,auth/login_screen}.dart, widgets/error_snackbar.dart, router.dart, main.dart}`. Tests: `android/app/test/{providers/settings_test.dart, api/{client,subsonic_client}_test.dart, support/cred_test_support.dart, offline/*, screens/library/*, widgets/{add_to_playlist_sheet,error_snackbar}_test.dart}`. Debt items A1/A4/A5 in `docs/DEBT.md` §5.

---

## 2026-06-19 — Split `SettingsValue`: creds via `ServerCreds`, offline prefs standalone (debt A6/A7)

**Context:** The 2026-06-18 audit (`docs/DEBT.md` §5, A6) flagged `SettingsValue` as a 12-field tuple mixing per-server credentials with the five offline-download prefs. Riverpod rebuilds every watcher of the whole record on any field change, so credential consumers rebuilt on offline-toggle changes and offline screens rebuilt on token rotation. The A1 band (2026-06-19) had already made the active `Profile` the sole credential source, so `SettingsValue`'s credential fields were a redundant copy — and the heerr-creds fields (`backendBaseUrl`/`bearerToken`) had **zero** `settingsProvider` consumers left (the dio clients read `activeProfileProvider` directly since S7). A pre-existing redundancy (A6 note): `OfflineSettings` existed only to re-slice `SettingsValue` into the offline fields, so offline prefs flowed through two providers.

**Decision:**
1. **Delete `Settings`/`SettingsValue`** (`providers/settings.dart`). Credentials come from a thin synchronous `ServerCreds` re-slice over `activeProfileProvider` (`providers/server_creds.dart`) carrying only the Navidrome `(baseUrl, username, password)` slice — the fields the offline serverKey chokepoints, the streaming/Now-Playing paths, and the owner-check providers actually read.
2. **`OfflineSettings`** (`offline/offline_settings.dart`) becomes the sole owner of the offline prefs — it reads/writes `PrefsStorage` directly (absorbing the key constants, defaults, `Future.wait` batch, and per-key writes from the deleted `Settings`). The re-slice is gone.
3. **No `HeerrCredsValue`.** The literal DEBT proposal (three providers: heerr-creds / navidrome-creds / offline-prefs) predated A1 and was stale — a `HeerrCredsValue` provider would have had no consumers. Code is the source of truth (CLAUDE.md staleness rule), so the DEBT wording was corrected to the as-built shape rather than the reverse.

**Why:**
- **Finishes the consolidation A1 started.** One credential source (the active profile); the `ServerCreds` re-slice is a pure projection of it, not a second store to keep in sync. The literal 3-way split would have re-introduced a copy-and-sync layer A1 deleted.
- **Kills the cascading rebuilds A6 names.** Cred consumers watch `serverCredsProvider` (rebuild only on profile switch); offline-pref consumers watch `offlineSettingsProvider` (rebuild only on a pref change). Neither rebuilds the other.
- **Net −1 provider** (delete `Settings`, fold the re-slice into `OfflineSettings`) vs. the +3 the literal proposal implied. The offline path-layer helpers (`OfflinePaths.*`, `OfflineManifestStore.load/save`, `library_cache`, `offline_downloader`, etc.) change parameter type `SettingsValue` → `ServerCreds`; their bodies are untouched since the field names match.

**Alternatives considered:**
- **Literal 3-way re-slice keeping `settings.dart`.** Rejected: re-introduces a profile-copy layer, ships a consumer-less `heerrCredsProvider`, and adds providers rather than removing them. Matches stale DEBT text, not the A1 model.
- **Pass the whole `Profile` to the offline helpers instead of a `ServerCreds` slice.** Rejected: couples the path layer to the full profile model (display name, timestamps, heerr creds). A narrow 3-field record keeps the layering clean and the test fakes small.
- **Split `SettingsValue` into separate freezed classes now (A19).** Deferred: `ServerCreds` / `OfflineSettingsValue` stay records for now; the freezed migration is tracked as A19.

**Trade-off:** `serverCredsProvider` is synchronous (it re-slices the already-loaded `activeProfileProvider`), so the offline serverKey chokepoints that previously did `await ref.read(settingsProvider.future)` now do a plain `ref.read(serverCredsProvider)`. One behavioral nuance surfaced in `background_sync_test`: a bare (un-overridden) container used to throw at the async creds read and surface as a `false` WorkManager retry; with the synchronous, null-degrading slice it instead no-ops gracefully to "no creds" / `true`. The infra-error → retry contract is still real and is now tested by forcing a downstream provider (`applicationDocumentsDirectoryProvider`) to throw with valid creds present.

**Reference:** `android/app/lib/{providers/{server_creds}.dart (new), offline/{offline_settings,offline_paths,offline_manifest,library_cache,offline_downloader,offline_marker,offline_size_estimator,offline_sync}.dart, player/{playback_actions,now_playing_persistence}.dart, providers/library/favourites.dart, screens/{settings_screen,library/playlist_detail_screen}.dart, widgets/{add_to_playlist_sheet,library_cover_art}.dart}`; `providers/settings.dart` deleted. Tests: `test/support/cred_test_support.dart` (`testCreds()` added), `test/offline/*`, `test/providers/seed_collection_provider_test.dart`, `test/screens/{settings_screen,library/playlist_detail_screen}_test.dart`; `test/providers/settings_test.dart` deleted. Debt A6/A7 in `docs/DEBT.md` §5.

---

## 2026-06-20 — Retry + debug-log dio interceptors (debt A9)

**Context:** `docs/CONTEXT.md` describes the HTTP stack as "Interceptors for the auth header + retry-on-503 + logging", but only the auth header (`BearerAuthInterceptor` / `SubsonicAuthInterceptor`) was ever implemented. 503s from the heerr backend (forwarded Spotify upstream rate-limits) were mapped to `RateLimitedError` with a parsed `Retry-After` and thrown straight to the caller — every transient blip became a user-visible snackbar (DEBT §5 A9).

**Decision:** Add `lib/api/interceptors.dart` with two interceptors, wired into both `dioClient` and `subsonicDioClient` in order **auth → retry → log**:

1. **`RetryInterceptor`** (hand-rolled, no new dependency). Bounded to `maxRetries` (default 2 ⇒ 3 attempts), attempt count stashed in `RequestOptions.extra`. Retries:
   - connection / send / receive timeouts + connection errors — exponential backoff `backoffBase * 2^n` (default base 500ms);
   - HTTP 503 — honours `Retry-After` **only when ≤ `maxRetryAfter`** (default 5s); a longer wait returns `null` (give up) so the `RateLimitedError` reaches the UI with the real countdown instead of the app silently hanging. Absent `Retry-After` falls back to backoff.
   - Everything else (401/403/404/422, other 5xx, Subsonic envelope failures) flows straight through to `mapDioErrorToApiError`.
   Re-issues via `dio.fetch(req)` so the full interceptor chain (auth header) re-runs each attempt; recursion is bounded by the attempt counter.
2. **`DebugLogInterceptor`** — request/response/error tracing gated on `kDebugMode`, written via `debugPrint` (CLAUDE "no `print`" rule), redacting the `Authorization` header to `***`.

**Why:**
- **Hand-rolled over `dio_smart_retry`.** The policy we need (cap on honoured `Retry-After`, give-up-to-surface-`RateLimitedError`) is bespoke; a dep would still need a custom `retryEvaluator`. The repo already prefers minimal deps (see the in-process fake adapter in `client_test.dart` vs `http_mock_adapter`).
- **Cap-then-surface on 503.** Short rate-limits (a few seconds) are best retried silently; long ones (Spotify can say 30–60s) are better shown to the user with the existing `RateLimitedError` countdown than blocking a request for a minute. 5s is the split.
- **Both clients.** Subsonic envelope failures are HTTP 200 (handled by `subsonicCall`), but real transport 5xx / network errors on Navidrome are just as transient as on heerr, so the same retry applies.

**Alternatives considered:**
- **`dio_smart_retry` package.** Rejected — adds a dep for behaviour we'd still have to override; the give-up-to-surface semantics don't map cleanly to its retry-everything default.
- **dio's built-in `LogInterceptor`.** Rejected — defaults to `print` and logs the `Authorization` header verbatim. The custom one uses `debugPrint` and redacts.
- **Retry all 5xx, not just 503.** Rejected — 500/502/504 from the backend are not the documented transient class; only 503 carries the `Retry-After` contract. Network-level errors cover the genuinely-transient transport failures.

**Trade-off:** retrying covers idempotent reads and the dedup-protected `POST /download` safely, but a `POST` that the server processed before a `receiveTimeout` could be re-sent. Accepted: the backend dedupes downloads, and search/recommend are side-effect-free; the alternative (no retry) is the current snackbar-on-every-blip behaviour A9 set out to fix.

**Reference:** `android/app/lib/api/interceptors.dart` (new); `lib/api/client.dart`, `lib/api/subsonic_client.dart` (wiring); `test/api/interceptors_test.dart` (8 cases). DEBT §5 A9.

---

## 2026-06-20 — Reactive lifecycle: router refreshListenable + offline-sync active-profile gate (debt A2/A15)

**Context:** The 2026-06-18 audit (`docs/DEBT.md §5`) flagged two reactive-correctness gaps that share a root cause — state that should react to the active profile didn't:
- **A2:** the GoRouter S5 redirect read `profileRegistryProvider` via `container.read` with no `refreshListenable`, so it only re-evaluated on navigation events. Removing the active profile in Settings left the user on a screen rendered against a torn-down profile until the next tab tap.
- **A15:** `OfflineSync` is `@Riverpod(keepAlive: true)` and starts its Timer inside `build`. On a fresh install the user lingers on `/login` (no creds), but the keep-alive provider had already built and was ticking (each `_runTick` early-returning `'no creds'`) with no foreground lifecycle observer mounted.

**Decision:**
1. **A2 —** `buildHeerrRouter` constructs a `_RouterRefresh extends ChangeNotifier` that subscribes to `profileRegistryProvider` via `container.listen` and `notifyListeners()` on every change, and passes it as `refreshListenable:`. GoRouter re-runs the redirect whenever the registry changes — most importantly when `activeId` goes null → `/login`.
2. **A15 —** `OfflineSync.build` now `ref.watch(activeProfileProvider)` and returns `_kIdle` when null (no `_runTick`, no Timer). It also cancels any leftover Timer at the top of every rebuild, since a watched-dependency change re-runs `build` on the same keep-alive notifier instance and `ref.onDispose` only fires on full disposal, not on rebuild.

**Why:**
- **A2 is the canonical `refreshListenable` use case.** A `ChangeNotifier` bridge is the documented go_router pattern for "re-run redirect when external auth state changes." Lifetime is self-managing: `container.listen`'s subscription auto-closes on container dispose, and GoRouter removes its own listener on `dispose()` (called in `_HeerrAppState.dispose`), so `_RouterRefresh` needs no explicit teardown and the no-arg `buildHeerrRouter()` test path is unaffected (refresh is null without a container).
- **A15 gates the cause, not the symptom.** `_runTick` already no-ops on `'no creds'`, but it still ran and scheduled the next Timer. Watching `activeProfileProvider` makes "logged in" the precondition for ticking, and because it's a watch, login transparently rebuilds the provider and runs the first tick — no separate "kick on login" wiring.

**Alternatives considered:**
- **A2 via a periodic redirect / polling.** Rejected — `refreshListenable` is event-driven and exact; polling is wasteful and laggy.
- **A2 listening to `activeProfileProvider` instead of `profileRegistryProvider`.** Equivalent for the null-active case, but the redirect body already reads the registry (including its loading state), so listening to the same source keeps "what triggers re-eval" and "what the redirect reads" aligned.
- **A15 by moving the lifecycle observer to app level (A8).** That's the broader refactor tracked separately as A8; the build-gate is the minimal fix for the wasted-ticks-on-/login symptom and is independent of where the observer lives.
- **A15 gating inside `_runTick` only.** Already present (`'no creds'`), but it doesn't stop the Timer from being scheduled — the gate has to be in `build`.

**Reference:** `android/app/lib/router.dart` (`_RouterRefresh`, `refreshListenable:`), `android/app/lib/offline/offline_sync.dart` (`build` active-profile gate + Timer cancel). Tests: `test/router_test.dart` (A2 group, `_MapStorage`), `test/offline/offline_sync_test.dart` (A15 guard). Debt A2/A15 in `docs/DEBT.md §5`.

---

## 2026-06-20 — Router god-file split + Repository/Service layer (debt A8/A10)

**Context:** The 2026-06-18 audit (`docs/DEBT.md §5`) flagged two structural items:
- **A8:** `router.dart` was a god file — its `_ShellScaffold` State class owned six unrelated app-lifecycle side-effects on top of the bottom-nav chrome (SRP violation; the shell couldn't be tested without dragging all six in).
- **A10:** no Repository/Service layer — providers called `dio` and parsed JSON envelopes inline, coupling Riverpod state + transport + JSON shape, so transport couldn't be unit-tested without standing up a container.

**Decision:**
1. **A8 —** extracted the lifecycle concern into `lib/app/lifecycle_coordinator.dart` (`LifecycleCoordinator`, a `ConsumerStatefulWidget` with `WidgetsBindingObserver`). The ShellRoute builder wraps the shell: `LifecycleCoordinator(child: _ShellScaffold(...))`. `_ShellScaffold` is now pure nav chrome.
2. **A10 —** introduced four service seams under `lib/services/`: `SubsonicLibraryService` (Subsonic reads), `PlaylistService` (Subsonic mutations), `BackendService` (heerr REST), `LyricsService` (two-stage lyrics). Each is a plain class holding only a `Dio`, with one method per call (issued through the existing `subsonicCall` / `apiCall` helpers) returning typed models. Each is exposed via an async `*ServiceProvider` that awaits the existing dio provider. The 15 inline-dio providers now delegate to a service; Riverpod-bound concerns (debounce, cancel tokens, dedupe, index ordering, invalidation) stay in the providers. Done as A10 **entirely** in one commit (all inline-dio providers, not a single pilot domain).

**Why:**
- **Service providers read the same dio providers**, so the injection point that every existing test already mocks (`subsonicDioClientProvider` / `dioClientProvider` overridden with a fake-adapter Dio) sits *below* the service — the whole pre-existing test suite passes unchanged, and new transport tests can construct a service directly from a Dio with no container (proven by `test/services/subsonic_library_service_test.dart`).
- **Parsing lives in the service, orchestration in the provider.** This is the SRP split the audit asked for without rewriting the cache-aware / debounce / polling machinery that the providers already get right.
- **The offline subsystem was already factored** — `downloadSong` takes an injected `Dio` and `offline_sync` composes existing providers — so A10 needed nothing there. The DEBT evidence line citing `offline_sync` as "transport+filesystem+state in one provider" was stale w.r.t. the current downloader seam.

**Alternatives considered:**
- **A10 as a single pilot domain (search) with the rest deferred.** Recommended in planning to bound risk, but the user chose to do A10 entirely in one commit. Feasible at low risk precisely because the test injection point is below the service layer (see Why), so behaviour is preserved by construction.
- **One mega `SubsonicService` covering reads + mutations.** Rejected — keeping reads (`SubsonicLibraryService`) separate from mutations (`PlaylistService`) matches the query/command split and keeps each surface small.
- **Splitting backend into `BackendJobService` + a separate search/recommend service** (the original planning grouping). Collapsed into one `BackendService` since all those calls share the single bearer-auth `dioClientProvider`; splitting them would be hair-splitting with no test or cohesion benefit.
- **A8 keeping the observer in the shell but extracting helpers.** Rejected — the observer + its side-effects are the concern to isolate; a half-move wouldn't make the shell testable in isolation.

**Reference:** `android/app/lib/app/lifecycle_coordinator.dart`, `android/app/lib/router.dart`, `android/app/lib/services/{subsonic_library_service,playlist_service,backend_service,lyrics_service}.dart`, and the delegating providers under `android/app/lib/providers/**`. Tests: `test/app/lifecycle_coordinator_test.dart`, `test/services/subsonic_library_service_test.dart`. Debt A8/A10 in `docs/DEBT.md §5`.

## 2026-06-20 — Session-stable salt for read-only Subsonic URLs (debt A11)

**Context:** `buildSubsonicCoverArtUrl` / `buildSubsonicStreamUrl` generated a fresh random salt on every call (`api/subsonic_client.dart`). Because the salt is part of the query string, the URL changed on every render — so `Image.network` (URL-keyed cache) cold-fetched every cover-art tile on every Library/Home scroll. The code comment already flagged this as deferred K1+ work.

**Decision:** Introduce a process-lifetime `sessionStableSalt()` (lazily initialised once per process) and make it the default salt for both read-only URL builders. The per-request `SubsonicAuthInterceptor` (every API GET + all state-mutating playlist calls) is left rotating per request.

**Why:**
- Subsonic auth tokens are `md5(password + salt)`; Navidrome validates each request independently and accepts a stable salt within a session, so a fixed salt is just as valid as a rotating one for read-only fetches.
- A stable salt makes the cover-art URL deterministic for a given `coverArtId`+`size`, which is the precondition for Flutter's image cache to hit — the actual fix for the scroll-time cold-fetch.
- The salt is **password-independent**: a profile switch (new password) still yields a valid token from the same salt, so the salt needs no reset on switch and the change is invisible to the multi-profile machinery.
- Keeping per-request rotation on the interceptor preserves the conventional Subsonic posture for the calls that actually mutate state.

**Alternatives considered:**
- **A `saltPolicy` enum param** (as the DEBT note literally suggested). Rejected as over-engineered — every production caller of the read-only builders wants the stable policy, and tests already inject an explicit `saltGenerator`, so a sensible default covers both without a new parameter.
- **Time-bucketed salt (rotate hourly).** Unnecessary complexity; a stable salt is valid for the whole session and the cache benefit is strictly better.
- **A Flutter `ImageCache` / `CachedNetworkImage` layer instead.** Heavier (new dependency / disk-cache lifecycle) and orthogonal — the salt was the root cause of cache misses; fix that first.

**Reference:** `android/app/lib/api/subsonic_client.dart` (`sessionStableSalt`, both builders). Tests: `test/api/subsonic_client_test.dart` (A11 group). Debt A11 in `docs/DEBT.md §5`.

## 2026-06-20 — Flutter CI workflow + dev_defaults leak verification (debt A21/A18)

**Context:** `android/CLAUDE.md §Development workflow` mandates `flutter analyze` + `flutter test` green before and after every task, but enforcement was manual — no CI ran them (A21). The audit also flagged `dev_defaults.dart` as a committed-secrets risk (A18).

**Decision:**
- **A21 —** add `.github/workflows/android-ci.yml` running `flutter analyze` + `flutter test`, triggered on PRs to `main` and pushes to `main`, path-filtered to `android/**`. Reuse the exact toolchain setup from `android-publish.yml` (Java 17, Flutter 3.44.0, `android/app` working dir, dev_defaults seeded from the example, pub get + codegen).
- **A18 —** no change; verified the file is gitignored, untracked, never in history, and token-free. Corrected the stale DEBT entry.

**Why:**
- **Mirror the publish workflow rather than invent a new setup** so the CI Flutter version / codegen steps can't drift from the release build. The CI job diverges only by dropping the keystore/signing steps (not needed to analyze + test) and substituting `analyze`+`test` for `build apk`.
- **Path filtering** keeps backend/docs PRs from spending Android CI minutes, matching the existing `backend-ci.yml` convention.
- **`flutter analyze` info-level lints don't fail the job** (only errors/warnings do), so the pre-existing `main.dart:25` workmanager deprecation won't red the build; a real regression (error/warning) will.

**Alternatives considered:**
- **Fold analyze/test into `android-publish.yml`.** Rejected — publish is tag-triggered (post-merge); the gate has to run on PRs to block bad merges.
- **`--fatal-infos`.** Rejected for now — would fail on the known untouched `main.dart:25` deprecation; not worth gating the whole repo on a third-party plugin's deprecation. Revisit if info-noise grows.

**Reference:** `.github/workflows/android-ci.yml`; `android-publish.yml` (setup mirrored). Debt A21/A18 in `docs/DEBT.md §5`.

## 2026-06-20 — Stateless auth interceptors: resolve credentials per request (debt A3)

**Context:** `BearerAuthInterceptor` (and `SubsonicAuthInterceptor`) captured the bearer token / Navidrome credentials *by value* at `Dio` construction. Because `dioClient`/`subsonicDioClient` watched the whole active `Profile`, any credential change rebuilt the entire `Dio` — discarding its connection pool and re-creating the interceptor chain. In-flight requests on the old instance still sent the stale credential. (A3 was left PARTIAL after the A1 band removed the dual-read violation.)

**Decision:** Make the interceptors stateless w.r.t. credentials. `BearerAuthInterceptor` takes a `String? Function() tokenResolver`; `SubsonicAuthInterceptor` takes `usernameResolver` + `passwordResolver`. Each resolves the current value from `ref.read(activeProfileProvider)` inside `onRequest`. The dio builders now `ref.watch(activeProfileProvider.select((p) => p?.<baseUrl>))`, so the `Dio` rebuilds only when the *base URL* changes.

**Why:**
- **The base URL is the only field baked into `BaseOptions`** at construction — it genuinely requires a new `Dio`. Credentials live in the per-request query/headers, so they can be resolved lazily without a rebuild. Splitting "watch base URL / read credentials" matches what actually needs a rebuild.
- **`ref.read` inside the resolver is safe here:** the resolver only fires while a request is in flight, which means a consumer is actively using the dio (obtained via `ref.watch(...Provider.future)`), keeping the provider — and its `ref` — alive. This mirrors the existing `container.read`-in-callback pattern used by the router redirect.
- **Result:** a token refresh / password change reuses the live `Dio` (pool + chain intact) and the next request transparently uses the new credential; only a server switch (different base URL) pays for a rebuild.

**Alternatives considered:**
- **Override `options.baseUrl` per request too (fully rebuild-free dio).** Rejected — needless; base-URL changes are rare (profile switch to a different server) and a rebuild there is correct and cheap. Per-request base-URL rewriting would complicate the interceptor for no real gain.
- **Keep captured values but add a token-refresh hook.** Rejected — still rebuilds on every profile save and doesn't fix the in-flight-stale-token issue; the resolver is simpler and strictly better.
- **Expose the resolver but keep `username`/`password`/`token` fields for tests.** Rejected — two sources of truth; tests now assert via the resolver (`tokenResolver()` etc.), which is what production uses.

**Reference:** `android/app/lib/api/client.dart` (`BearerAuthInterceptor`, `dioClient` select), `android/app/lib/api/subsonic_client.dart` (`SubsonicAuthInterceptor`, `subsonicDioClient` select). Tests: `test/api/client_test.dart` (A3 group). Debt A3 in `docs/DEBT.md §5`.

## 2026-06-20 — Offline-sync perf + robustness: queue worker pool, bounded fan-out, connectivity-stream trigger (debt A12/A13/A14)

**Context:** The 2026-06-18 audit flagged three offline-sync (`offline/offline_sync.dart`) smells: (A12) the download worker pool shared a mutable `List` via `removeAt(0)` + reassigned `songsState` across workers — race-free only by accident of the single-threaded event loop; (A13) `_resolveTargets` fanned out artist→albums and album/playlist detail fetches fully sequentially, so a sync-all serialized every album request; (A14) the Wi-Fi gate was poll-only, so a reconnect waited out the poll interval (up to 15 min).

**Decision:**
- **A12 —** pull downloads from an explicit `Queue<Song>` (`removeFirst()`), and mutate a single `songsState` map in place instead of rebuilding it via spread per worker.
- **A13 —** add a `_forEachBounded(items, action)` helper (shared `Queue` + `_kResolveConcurrency = 4` workers) and route all three resolution loops through it.
- **A14 —** add `Stream<bool> get onWifiChanged` to `WifiCheck` (default: `Stream.empty()`; production maps `onConnectivityChanged`), subscribe in `build`, and fire `_tick()` on a false→true transition.

**Why:**
- **Type-enforced invariants over reasoning about interleaving (A12).** A `Queue.removeFirst()` makes "each song handed to exactly one worker" structural; the previous `List.removeAt(0)` was correct only as long as nobody inserted an `await` between the `isNotEmpty` check and the removal. In-place map mutation is atomic per assignment on the single isolate, so concurrent workers can't lose updates.
- **Bounded, not unbounded, parallelism (A13).** A naive `Future.wait` over every album would open hundreds of sockets on a large sync-all; capping at 4 keeps the device responsive and the server happy while still removing the serial bottleneck. The same `Queue`-pull pattern as A12 keeps the dedup-by-`song.id` contract intact.
- **Event-driven Wi-Fi (A14).** `connectivity_plus` already exposes the stream; subscribing is strictly better than polling for responsiveness. Guarding on `_paused`/`_running` and letting `_runTick` re-check every gate means the trigger is cheap and idempotent — a spurious or redundant event can't double-download or run while backgrounded. The earlier deliberate avoidance of the stream (to keep fakes simple) is resolved by giving `WifiCheck` a no-op default so existing fakes only opt in when they test A14.

**Alternatives considered:**
- **A `pool`/semaphore package for A12/A13.** Rejected — a hand-rolled `Queue` + N workers is a few lines, dependency-free, and already the established pattern in `_runTick`.
- **Run album + playlist resolution concurrently with each other (A13).** Skipped — within-loop parallelism captures the win; cross-loop concurrency adds little and muddies the (already atomic) `out` writes.
- **Per-request base-URL/Wi-Fi re-check only, no stream (A14).** That's the status quo this item exists to fix; polling can't beat the poll interval for latency.

**Reference:** `android/app/lib/offline/offline_sync.dart` (`_runTick` Queue, `_forEachBounded`, `WifiCheck.onWifiChanged`, `_subscribeWifi`). Tests: `test/offline/offline_sync_test.dart` (A14 + existing bounded-concurrency cases). Debt A12/A13/A14 in `docs/DEBT.md §5`.

## 2026-06-20 — P3 cleanup: split large screen files; triage the rest (debt A16–A22)

**Context:** Final DEBT §5 band (P3 low-hanging cleanup): A16 (screen-folder convention), A17 (split large widget files), A19 (records→freezed), A20 (`clear()` scope), A22 (`app/ios/` baggage). A18/A21 were already done.

**Decision:**
- **A17 — DO.** Split the four large screen files (`now_playing` 756, `library` 615, `playlist_detail` 606, `settings` 562) using Dart `part`/`part of` sibling files, one per cohesive section. Private (`_`) widget classes keep their privacy (same library) and no caller imports change.
- **A20, A22 — STALE.** `Settings.clear()` and the legacy keys it half-wiped were deleted in A6; `app/ios/` doesn't exist. Marked resolved, no code.
- **A16, A19 — WON'T-FIX** (with rationale, below).

**Why:**
- **`part`/`part of` over per-widget public files (A17).** The DEBT note's stated rebuild-scope benefit already holds — these are already separate widget classes, and file location doesn't affect Flutter's rebuild granularity. So A17 is purely a readability/file-size win, and `part` files achieve it with zero behaviour risk: privacy preserved, imports stay centralised in the main library file, no caller churn, analyzer-verified. `playlist_detail` is dominated by a single 515-line `State` class that can't be widget-extracted without a real refactor, so only its header/enum moved.
- **A16 won't-fix.** Moving 5 flat `*_screen.dart` files into per-domain subfolders rewrites ~48 internal relative imports + 5 importer files and churns git blame, for zero behaviour or rebuild benefit — purely cosmetic foldering. Not worth it; revisit only if a domain folder grows enough to need it.
- **A19 won't-fix.** The premise is partly wrong: Dart records **already have value (`==`-by-field) equality**, so the only real gain from `freezed` is `copyWith` — and nothing needs it (these records are rebuilt wholesale every tick/read, never field-patched). Converting 7 record typedefs to freezed is high construction-site churn for marginal benefit. Revisit if a real `copyWith` need appears.

**Alternatives considered:**
- **A17 by making the widgets public in their own files.** Rejected — needlessly widens the API surface; `part` keeps them private.
- **Do A16/A19 anyway for completeness.** Rejected per the project's blunt-engineering preference: closing low-value/high-churn items as documented won't-fix is sounder than churning ~3000 LOC for cosmetics. (Confirmed with the user.)

**Reference:** new `part` files under `android/app/lib/screens/**`; DEBT §5 A16–A22 entries. This closes the DEBT §5 architectural backlog (P0/P1/P2 done earlier; P3 done/triaged here).

## 2026-06-23 — Phase T: stream-first preview via the backend proxy — heerr v3.5.0

**Context:** Before this, hearing a YouTube-Music search result required committing to a full download: tap → `/download` (spotDL) → Navidrome re-index (~1 min) → stream via Subsonic. There was no way to *audition* a result first. Phase T adds a preview affordance that streams the track immediately by consuming the backend's new `GET /api/v1/preview/stream` proxy (backend Phase K — see `backend/docs/DECISIONLOG.md` 2026-06-23). Pure-client slice; the only backend dependency is K2, already shipped.

**Decision:**
1. **Play preview through the backend proxy, not on-device extraction.** The preview `MediaItem.id` is the heerr `/preview/stream?source_url=…&token=…` URL (built by `buildPreviewStreamUrl`, T1); `just_audio` opens it and the backend proxies the googlevideo bytes over Tailscale.
2. **A third `MediaItem.id` kind.** Alongside `file://` (offline) and the Subsonic stream URL, preview items use the proxy URL and are stamped `extras['preview'] == true` (vs `extras['subsonicId']` for library tracks). `isPreviewMediaItem` is the discriminator; `searchResultToMediaItem` (T2) is the builder, deliberately **bypassing** `songToMediaItem`.
3. **Token in the query string.** `just_audio`'s `AudioSource.uri` can't attach an `Authorization` header, so the bearer rides in `?token=` — the same shape Subsonic playback URLs already use. Creds are read from `activeProfileProvider` at the call site (`playPreview`), never baked into the pure builders.
4. **Ephemeral; reuse existing reactive promotion.** A preview writes nothing and creates no queue/download row. The find → *hear* → download loop is preserved: tapping Download on the same row still dispatches `/download`, and the existing combined-search promotion (`combined_search.dart`) upgrades the row from "On YouTube Music" → library once Navidrome re-indexes.
5. **Search-results-only in v1.** The preview button is wired on the Library search YouTube-Music section (`ResultTile.onPreview`). Previewing **recommendations** / **Home cards** is deferred (DEBT F3) — those surfaces model `RecommendedTrack`/`HomeRecommendationCard`, not `SearchResultItem`, so they need a small `sourceUrl → playPreview` adapter.

**Why:**
- **Backend proxy over on-device extraction** inherits the Phase K rationale: googlevideo URLs are egress-IP-bound (a device-side `youtube_explode_dart` URL or a bare `-g` redirect 403s), and on-device extraction breaks on YouTube player changes that would need an **app release** to fix — whereas the proxy is fixed by a backend `yt-dlp` bump. Keeping the device on the tailnet also matches the connectivity rule.
- **Third id kind, not a parallel player path.** Reusing the existing `HeerrAudioHandler` queue + mini-player + Now Playing means preview gets lock-screen controls, the scrubber, and persistence for free; only the `MediaItem` construction differs. The `extras['preview']` flag drives the one visible difference (the "Preview" badge) without branching the player.
- **Pure builders + call-site creds** keep `buildPreviewStreamUrl` / `searchResultToMediaItem` unit-testable without a container (matching `songToMediaItem`), and avoid a second credential read path (CLAUDE.md hard rule — creds come from `activeProfileProvider` only).
- **Search-results-only** ships the highest-value surface (the "is this the right track?" moment is during search) at the smallest blast radius; the recommendation/home surfaces are a clean fast-follow once asked for.

**Alternatives considered:**
- **On-device extraction (`youtube_explode_dart`).** Rejected (Phase K planning) — fragile, app-release-bound fixes, silent throttling.
- **Reuse `songToMediaItem` with a synthetic `Song`.** Rejected: it would force a fake Subsonic id and route through the offline-local-uri chokepoint that has no meaning for a non-library track; a dedicated builder is clearer and keeps the preview path off the library invariants.
- **A separate "preview player" instance.** Rejected: doubles the audio-session/notification wiring; the single handler with a flagged item is simpler and gives preview the full transport UI.
- **Wire preview everywhere (recommendations + home) now.** Deferred to DEBT F3 — different models, marginal incremental value over the search surface for v1.

**Trade-off:** A preview that the user lets run produces backend bandwidth (the K double-hop) with nothing persisted; if they want to keep it they must still tap Download. Accepted — auditioning is cheap at home scale and the explicit Download keeps "what's in my library" intentional. The reactive-promotion handoff means a previewed-then-downloaded track briefly exists as both a YT row (preview) and, post-reindex, a library row — the promotion collapses this on the next render.

**Reference:** `android/app/lib/player/{preview_url,search_result_to_media_item,playback_actions}.dart`, `android/app/lib/widgets/{result_tile,preview_badge,mini_player}.dart`, `android/app/lib/screens/{library/library_search_results,player/now_playing_screen}.dart`, `android/app/lib/api/endpoints.dart`. Backend side: `backend/app/api/v1/preview.py` + ADR `backend/docs/DECISIONLOG.md` 2026-06-23. Roadmap milestones T1–T5; CHANGELOG `2026-06-23 — Phase T`. Recommendation/home follow-up: DEBT F3.

---

## 2026-06-24 — Back-button: shell PopScope to Home, single handler per route

**Context:** Two reported back-button bugs. (1) From any non-Home screen the system back exited the app instead of walking back to Home — because bottom-nav tab switches use `context.go()`, which replaces the go_router stack, leaving no Home beneath the active tab. (2) With text in the Library search field, system back exited the app because search is an internal mode (not a route) with no back interception.

**Decision:** Handle tab-root back with a single `PopScope` in the shell (`_ShellScaffold`): off-Home → route to Home; on Home → allow the OS pop (exit). Search mode is exited by the *same* shell handler via a new `librarySearchActiveProvider` flag — not a second `PopScope` — so there is exactly one back handler per go_router route. Two detail drill-downs in Downloads were also corrected from `context.go()` to `context.push()`.

**Why:** Pushed detail screens already sit above the `ShellRoute` on the root navigator and pop correctly; only the flat tab roots needed handling, so a shell-level `PopScope` is the minimal fix. A first attempt used a separate `PopScope` inside the search overlay, but a single go_router route hosts both the shell and the overlay — and a system back fires only the outer handler, so the inner search handler never cleared the field. Consolidating to one provider-driven handler removed the conflict.

**Alternatives considered:** `StatefulShellRoute.indexedStack` (per-tab back history + preserved state) — more idiomatic but a larger router refactor; deferred (recorded in ROADMAP Phase V as the alternative). Keeping search as an internal bool with its own `PopScope` — rejected: two `PopScope`s in one route fight over the same pop.

---

## 2026-07-04 — Opt out of Android predictive back (`enableOnBackInvokedCallback="false"`)

**Context:** The V1 back-stack milestone put a `PopScope` on the shell (`router.dart _ShellScaffold`) so system back walks tab roots to Home before exiting. Five fix iterations passed `router_test.dart`'s `handlePopRoute()` tests but kept exiting the app on the Pixel 7. Root cause: the app targets SDK 36 (Flutter default, `FlutterExtension.kt:34`), where Android 16 enables predictive back by default — the OS only delivers back to Flutter when the framework has reported `setFrameworkHandlesBack(true)`. That report is driven by `NavigationNotification`s (`navigator.dart:3753`: `canHandlePop = navigatorCanPop || topRouteBlocksPop`). go_router's nested ShellRoute navigator holds one page per tab with no PopScope in its own routes, so it dispatches `canHandlePop: false` after every tab switch; parent builds before child, so this deterministically clobbers the shell PopScope's `doNotPop` notification dispatched moments earlier. The OS concluded the framework doesn't handle back and finished the Activity itself — `popRoute` never ran on device, while tests (which inject the event framework-side) stayed green.

**Decision:** Set `android:enableOnBackInvokedCallback="false"` on `<application>` in the manifest. This opts the app out of predictive back; Android delivers legacy `KEYCODE_BACK → onBackPressed → "popRoute" channel`, which always reaches the framework — the exact code path the shell PopScope logic and the existing tests already handle.

**Why:**
- One line, zero Dart changes; the tested back-handling logic starts working as-is.
- The framework-side alternative (keeping predictive back delivered) requires a second `PopScope` inside every tab route of the nested navigator purely to fix the notification value, while the *actual* pop still has to be handled by the root-route PopScope — two coupled mechanisms where the notification shim does nothing functional. Fragile against go_router/Flutter changes.
- The predictive-back animation we give up is worthless here: the shell intercepts back to run `context.go(home)`, which the predictive animation cannot preview anyway.

**Alternatives considered:**
- **Per-tab PopScope notification shim** (above) — rejected as fragile/duplicated.
- **`StatefulShellRoute` refactor** — doesn't fix the delivery problem by itself; the nested branch navigators still report `canHandlePop: false` at tab roots.
- **Wait for upstream fix** (flutter/go_router nested-navigator NavigationNotification handling) — unbounded timeline; the manifest opt-out is reversible in one line when upstream lands.

**Trade-off:** No predictive-back system animation on Android 14+. The opt-out flag is deprecated-path (Android intends to remove it in a future release), so this must be revisited when targetSdk moves past the flag's removal — at which point the per-route-PopScope shim or an upstream fix becomes mandatory. Tracked implicitly by this ADR.

**Reference:** `android/app/android/app/src/main/AndroidManifest.xml` (`<application>` comment cites the mechanism), `android/app/lib/router.dart` (shell PopScope), CHANGELOG 2026-07-04.

## 2026-07-05 — Now Playing: always-visible scrollable lyrics, queue bottom sheet, Spotify-style layout

**Context:** User requested a redesigned Now Playing screen: full-width cover art, rounded pill-style shuffle/loop buttons, queue behind a hamburger bottom sheet, 3-dot overflow menu, and lyrics visible by scrolling (not toggled).

**Decision:** Replace the fixed `Column`+`Expanded(_QueueList)` body with a `SingleChildScrollView`+`Column` that always includes `_LyricsSection` at the bottom. Queue moves to `showModalBottomSheet`. `_SyncedLyrics` uses a `Column` (not `ListView`) so `Scrollable.ensureVisible` for auto-scroll targets the parent `SingleChildScrollView`. Shuffle/repeat styled with `StadiumBorder` + `primaryContainer` fill when active.

**Why:** Single scroll axis simplifies the layout; always-visible lyrics require no toggle state; synced lyrics auto-scroll via `Scrollable.ensureVisible` only works when the `Scrollable` ancestor is the page-level one (a nested `ListView` creates a competing `Scrollable` that consumes the scroll event).

**Alternatives considered:** Keep the toggle — rejected, user explicitly requested no toggle. Use a `CustomScrollView` with slivers — rejected, adds complexity without benefit at this screen's size.

## 2026-07-06 — Lyrics UX: preview card + modal full-screen sheet (Spotify reference)

**Context:** User supplied two Spotify screenshots: lyrics as a tinted card on Now Playing, and a fully pulled-up state that is full-screen lyrics with the album cover as a small top-left thumbnail.

**Decision:** Card on the Now Playing scroll page shows a sliding fixed window of synced lines (no inner scrolling); tapping card/expand opens a full-height `showModalBottomSheet` (`isScrollControlled`) that hosts its own `SingleChildScrollView`, ticker, and `playerSnapshotProvider` watch. Auto-scroll (`Scrollable.ensureVisible`) lives only in the expanded sheet.

**Why:** Keeping the full auto-scrolling lyrics list inside a fixed-height card would make `ensureVisible` bubble to the page-level scrollable and yank the whole Now Playing page (the 2026-07-05 design relied on exactly that bubbling). A windowed preview sidesteps nested-scroll conflicts entirely. The modal sheet gives drag-down-to-dismiss for free, matching the "pulled up" gesture.

**Alternatives considered:** `DraggableScrollableSheet` persistently embedded on the screen — rejected: competes with the existing page scroll and complicates the layout for no gain over a modal. Dedicated go_router route — rejected: loses the sheet drag-dismiss gesture and modal barrier semantics.
