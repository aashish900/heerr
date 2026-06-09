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
