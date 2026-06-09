# ROADMAP.md — heerr Android client implementation milestones

Track progress through the Android client build. Same cadence as the backend roadmap: each milestone = one git commit, with the test gate green where applicable. Tick the box when committed.

See `PLAN.md` for the *what*; this file is the *how* / *when*.

**Status (2026-06-09):** planning round complete (this file + CONTEXT.md + PLAN.md + DECISIONLOG.md + CHANGELOG.md + CLAUDE.md + README.md all written). **No Dart code exists yet.** Execution begins at A1.

**Conventions:**
- TDD by default (CLAUDE.md §2) — widget tests / unit tests written first, land in the same commit as code.
- Out-of-TDD-scope: `flutter create` scaffold, `pubspec.yaml`, `android/` config, manual smoke. These have other verification gates noted per-milestone.
- Commit messages: Conventional Commits with the `flutter` scope (`feat(flutter): …`, `chore(flutter): …`).
- One milestone = one commit. Follow-up cleanup within a milestone = separate commit under the same milestone.
- **Halt and confirm at each milestone boundary** (same cadence as backend A1→H1).

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

### [ ] D3. Job detail screen + polling provider
**Files:** `android/app/lib/providers/job_status.dart`, `android/app/lib/screens/job_detail_screen.dart`, `android/app/test/screens/job_detail_screen_test.dart`, `android/app/test/providers/job_status_test.dart`.
**Deliverable:** `jobStatusProvider(jobId)` polls `/status/{id}` every 2s while non-terminal. Screen shows id (short), state, timestamps (relative + full), output_path (tap to copy), error_msg.
**Test gate:** widget test + provider test (stops polling on terminal state).
**Done when:** tap a queue tile → detail screen polls until done/failed → polling stops.
**Commit:** `feat(flutter): job detail screen with polling`

---

## Phase E — Polish

### [ ] E1. Error UX wiring across all screens
**Files modified:** all screens; new `android/app/lib/widgets/error_snackbar.dart`.
**Deliverable:** Every screen's error case routes through the typed `ApiError` → the right snackbar / banner / redirect per PLAN §9.
**Test gate:** widget tests for each screen's error branches.
**Done when:** every PLAN §9 row is exercised in a test.
**Commit:** `feat(flutter): error ux per plan §9`

### [ ] E2. Empty + loading polish
**Files modified:** all screens; new `android/app/lib/widgets/empty_state.dart`, `android/app/lib/widgets/skeleton.dart`.
**Deliverable:** Pretty empty + loading states across Search / Queue / Job detail. M3-spec'd, dark-themed, low-contrast skeletons.
**Test gate:** widget tests for each empty + loading state.
**Done when:** every empty / loading state is visually distinguishable from error.
**Commit:** `feat(flutter): empty + loading states`

---

## Phase F — Ship

### [ ] F1. Android signing + release build
**Files:** `android/app/android/app/build.gradle` (signingConfig), `android/app/android/key.properties` (gitignored), `android/app/android/keystore.jks` (gitignored), `android/README.md` (release build instructions).
**Deliverable:** Keystore generated; `key.properties` configured locally; `flutter build apk --release` produces a signed APK at `android/app/build/app/outputs/flutter-apk/app-release.apk`.
**Test gate:** none (out of TDD scope).
**Done when:** signed APK exists; installs on the Pixel via `adb install`.
**Commit:** `infra(flutter): android signing + release build`

---

## Phase G — Smoke

### [ ] G1. End-to-end smoke against the home server
**Files:** optional `android/docs/smoke.md` capturing the verification log.
**Deliverable:** Real APK on the Pixel reaches the backend on the home server (via Tailscale), searches Spotify, dispatches a download, watches the queue, and confirms the file lands in Navidrome.
**Test gate:** manual; the 7-step verification block in PLAN §12.
**Done when:** all 7 PLAN §12 steps pass.
**Commit:** `chore(flutter): e2e smoke verified` (optional — only if recording output).

---

## Cross-cutting reminders

- **`flutter analyze` green before declaring any milestone done** — same role as `ruff check` on backend.
- **`flutter test` green before AND after each milestone.**
- **No `print` in production code** — use `debugPrint`. (Lints enforce this from A1.)
- **No `package:logger`** for now — `dart:developer log()` is enough. Defer real logging until / if needed.
- **DECISIONLOG drift:** any contract / stack change → update `DECISIONLOG.md` + `PLAN.md` in the same commit (CLAUDE.md staleness rule).
- **No `.env` files for the app** — the URL + token live in `flutter_secure_storage`, not in source.

---

## Out of scope for this roadmap

- iOS port.
- Light theme.
- Push notifications / FCM.
- Spotify SDK / OAuth on device.
- Admin endpoints (CLI-only on backend).
- Tablet / foldable layouts.
- Internationalisation.

---

## Roadmap complete when

1. All 13 milestone boxes checked (A1–G1).
2. Every test gate green at its milestone.
3. G1 smoke succeeds against the real home stack (after backend H1 is done).
4. CHANGELOG entries exist for each milestone group.
5. `git log --oneline android/` reads as a clean A→G progression.
