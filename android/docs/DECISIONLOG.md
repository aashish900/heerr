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
