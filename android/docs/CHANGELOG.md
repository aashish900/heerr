# CHANGELOG.md — heerr Android client

Per-task change log. Newest at the bottom. Append-only; never edit prior entries.

---

## 2026-06-09 — Android client planning round

- New: `android/CLAUDE.md` — Android-app-specific Claude rules (bootstrap order, locked stack, TDD scope, "don't"s, user-background reminder).
- New: `android/README.md` — operational entry point for the Android app. Stub at this point — points at `docs/` and notes that the scaffold itself lands at milestone A1.
- New: `android/docs/CONTEXT.md` — Android client project brief (backend endpoints consumed, stack, dev env, target device, MVP screens, polling cadence, error UX, out-of-scope list).
- New: `android/docs/PLAN.md` — frozen v1 contract (stack table, project layout, API contract, configuration, routing, state management, theme, polling cadence, error UX, tests, out-of-scope list, definition-of-done).
- New: `android/docs/ROADMAP.md` — 13-milestone build sequence (A1–G1) mirroring the backend's A1–H1 cadence. Halt-and-confirm at each boundary.
- New: `android/docs/DECISIONLOG.md` — 5 seed ADRs locking the stack, theme, polling-not-WebSocket, in-app Settings (not `--dart-define`), and the `android/app/` project layout.
- New: `android/docs/CHANGELOG.md` — this file.
- Rationale: same convention as backend — get the contract locked in writing before any Dart code. Reading the ROADMAP gives the next task; reading PLAN.md tells you what's already decided so you don't re-litigate.
- **Note:** the `android/app/` directory does not exist yet. `flutter create android/app` is the first action of milestone A1.

## 2026-06-09 — Rename: `flutter/` → `android/`

- The directory holding the mobile-client docs (and, later, the `flutter create` scaffold at `app/`) is renamed from `flutter/` to `android/`. The convention `<app>/` from the root `/CLAUDE.md` still applies — `<app>` here is `android`.
- Rationale: `flutter` named the framework, not the role. The pair `backend/` + `flutter/` was inconsistent (backend isn't called `fastapi/`). `android/` names the deployment platform — Flutter is still the framework used to build the app, but iOS is explicitly out of scope (per `/CLAUDE.md` §3), so the dir name reflects the only target the user ships to.
- Trade-off: the inner `flutter create` scaffold (landing at A1) will create its own `android/` subdir for the Android build manifest + Gradle config — so paths like `android/app/android/AndroidManifest.xml` will exist. Annoying-but-harmless path repetition; accepted at rename time after the preview was shown.
- Path refs updated throughout `android/CLAUDE.md`, `android/README.md`, `android/docs/{CONTEXT,PLAN,ROADMAP,DECISIONLOG,CHANGELOG}.md`, root `/CLAUDE.md`, and two stale forward-references in `backend/docs/CHANGELOG.md` (per CLAUDE.md staleness rule).
- Project-noun refs ("the Flutter app", "Flutter client", file titles) updated to "Android client" / "Android app" / similar. Framework refs (Flutter SDK, Flutter 3.44.0, `flutter create`, `flutter analyze`, `flutter_secure_storage`, "the Flutter team") left intact — Flutter is still the framework even though the dir is named for the platform.
- Root `/CLAUDE.md`: app inventory + the "Backend first, Flutter second" rule reworded to "Backend first, Android client second" with a clarifying parenthetical noting the framework/platform split.
- Nothing else moved; no Dart code yet — this is purely a docs rename.

## 2026-06-09 — A1: Flutter scaffold + pinned deps + lint

- Ran `flutter create --project-name=heerr --org=com.aashish --platforms=android --no-pub android/app` → creates a single-platform (Android-only) Flutter scaffold at `android/app/`. No `ios/`, `web/`, `linux/`, `macos/`, `windows/` dirs generated.
- Application id / namespace: `com.aashish.heerr` (`android/app/android/app/build.gradle.kts` lines 8 + 19).
- **Replaced `pubspec.yaml`** with the locked-stack pin set:
  - Runtime: `flutter_riverpod ^2.6`, `riverpod_annotation ^2.6`, `dio ^5.7`, `freezed_annotation ^2.4`, `json_annotation ^4.9`, `flutter_secure_storage ^9.2`, `go_router ^14.6`.
  - Dev (codegen + lint + test): `build_runner ^2.4`, `freezed ^2.5`, `json_serializable ^6.8`, `riverpod_generator ^2.6`, `flutter_lints ^6.0`, `mocktail ^1.0.4`.
  - Removed `cupertino_icons` (iOS-only, out of scope per `/CLAUDE.md` §3).
  - Version line: `0.1.0+1`.
- **Replaced `analysis_options.yaml`** with strict-mode + extras: `strict-casts`, `strict-inference`, `strict-raw-types`; exclude `**/*.g.dart` + `**/*.freezed.dart` (codegen output); enforce `prefer_const_*`, `prefer_final_locals`, `require_trailing_commas`, `avoid_print`, `unawaited_futures`, `cancel_subscriptions`, `close_sinks`. `invalid_annotation_target` set to ignore (freezed false-positive that doesn't apply at lint time).
- **Replaced `lib/main.dart`** with a bare `HeerrApp` (StatelessWidget) — `ProviderScope` root, M3 dark theme via `ColorScheme.fromSeed(0xFF1DB954, dark)`, centred "heerr" text on the dark surface. No router yet — that lands at A2.
- **Replaced `test/widget_test.dart`** with a smoke test that pumps `HeerrApp` and asserts (a) "heerr" text rendered and (b) `Theme.of(context).brightness == Brightness.dark`. Default counter-app test removed (no longer applicable).
- **`.gitignore`** appended four lines for Android signing artefacts (`android/key.properties`, `android/keystore.jks`, `android/app/key.properties`, `**/*.jks`) — F1 will generate these locally; they must never be committed.
- Removed IDE noise the scaffold produced: `android/app/.idea/` and `android/app/heerr.iml` (covered by the default `.gitignore` but cleaner to delete from the working tree).
- Verification: `cd android/app && flutter pub get` → 112 deps resolved (36 packages have newer majors blocked by our caret pins — Dependabot will surface those). `flutter analyze` → "No issues found! (ran in 0.2s)". `flutter test` → 1/1 passed.
- **Manual verification deferred** to when the user is near the Pixel: `cd android/app && flutter run -d <pixel-device-id>` should show "heerr" centred on a dark green-tinted surface. (`flutter devices` lists connected devices.)

## 2026-06-09 — A2: theme + go_router + bottom-nav shell

- New: `android/app/lib/theme.dart` — single `heerrDarkTheme()` builder. M3 dark theme via `ColorScheme.fromSeed(0xFF1DB954, brightness: dark)`. Seed colour defined as a private const so it isn't hardcoded in every consumer.
- New: `android/app/lib/router.dart`:
  - `Routes` class with `search`/`queue`/`settings` constants + a `job(id)` builder. Keeps URL shape DRY between the router, link callers, and tests.
  - `buildHeerrRouter()` returns the configured `GoRouter`. Pulled out of `main.dart` so widget tests reuse the exact production config (no parallel test-only router).
  - `ShellRoute` wraps the three child routes with `_ShellScaffold`, which holds the M3 `NavigationBar` (Search · Queue · Settings). Tab tap calls `context.go(...)`. Selected index derived from the matched location.
- New stub screens (all `StatelessWidget` returning a `Scaffold` with an AppBar + centred body label, populated later):
  - `android/app/lib/screens/search_screen.dart` (filled at C2).
  - `android/app/lib/screens/queue_screen.dart` (filled at D2).
  - `android/app/lib/screens/settings_screen.dart` (filled at B3).
- Updated `android/app/lib/main.dart`: switched from `MaterialApp` + inline `Scaffold` to `MaterialApp.router(routerConfig: ...)`. `ProviderScope` wraps `HeerrApp`.
- Removed `android/app/test/widget_test.dart` (the A1 smoke test asserted the now-removed `heerr` centred text on the root) and replaced with new `android/app/test/router_test.dart` — five tests:
  1. boots on `/` (Search) by default;
  2. tapping the Queue tab renders the Queue screen;
  3. tapping the Settings tab renders the Settings screen;
  4. round-trip Settings → Search returns to Search;
  5. theme: M3 + dark brightness.
- Test helper `_activeTitle(tester)` reads the AppBar title widget directly (instead of `find.text(...)`) — each stub renders the same label twice (in the AppBar and the body), so a text-based finder would be ambiguous.
- `analysis_options.yaml`: removed `avoid_returning_null_for_future` (removed from Dart 3.3+, surfaced as a `removed_lint` warning during the first `flutter analyze` of this milestone).
- Verification: `flutter analyze` → no issues; `flutter test` → 5/5 passed.

## 2026-06-09 — A3: freezed models for the backend contract

- New `android/app/build.yaml` — global `json_serializable` config (`field_rename: snake`, `explicit_to_json: true`, `include_if_null: false`). Single source of truth for the Dart-camelCase ↔ wire-snake_case mapping; no per-field `@JsonKey` annotations needed.
- New `android/app/lib/models/`:
  - `enums.dart` — `SpotifyType` (`track`/`album`/`playlist`) + `JobState` (`queued`/`running`/`done`/`failed`) with `@JsonValue('…')` for each variant. `JobStateX.isTerminal` extension exposes the polling-stop condition for the job-detail screen at D3.
  - `search_request.dart` — `SearchRequest({query, type, limit=20})`.
  - `search_result_item.dart` — `SearchResultItem({spotifyUri, spotifyUrl, title, artist, album?, durationMs?, coverUrl?, alreadyDownloaded, activeJobId?})`.
  - `search_response.dart` — `SearchResponse({results})`.
  - `download_request.dart` — `DownloadRequest({spotifyUri})`.
  - `download_response.dart` — `DownloadResponse({jobId, state, deduped})`.
  - `job_view.dart` — `JobView({jobId, spotifyUri, spotifyType, state, progress?, error?, outputPath?, createdAt, startedAt?, finishedAt?})`. `progress` is reserved by the backend (always `null` in v1).
  - `queue_response.dart` — `QueueResponse({active, recent})`.
- Codegen: `dart run build_runner build --delete-conflicting-outputs` produced 21 outputs (7×`*.freezed.dart` + 7×`*.g.dart` + supporting). Verified by re-running `flutter analyze` (no issues) and `flutter test` (17/17 passing: 12 new model tests + 5 router tests from A2).
- New `android/app/test/models_test.dart` — 12 tests covering:
  - `SearchRequest` snake_case key serialization + JsonValue mapping + round-trip.
  - `SearchResponse` parse from a realistic backend payload + round-trip + `include_if_null: false` behaviour on nullable fields.
  - `DownloadRequest` round-trip.
  - `DownloadResponse` parse + enum mapping + `isTerminal` extension on `JobState.done`.
  - `JobView` parse of every field from a `/status/{id}` payload + UTC `DateTime` preserved across round-trip.
  - `QueueResponse` parse of both empty and populated lists.
  - `JobState.isTerminal` table-driven check (done/failed terminal; queued/running not).
- **Drift correction (per `/CLAUDE.md` staleness rule).** The planning round's `android/docs/PLAN.md` §3 had several drifts vs the actual backend schemas in `backend/app/schemas/`:
  - `SearchResponse` had `{type, items}` — backend returns `{results}` (no envelope type field).
  - `SearchResultItem` had `name`/`thumbnailUrl` — backend uses `title`/`cover_url`, and PLAN missed `spotify_url`.
  - `JobView` had `id`/`error_msg`/`attempt_count`/`owner_label` — backend uses `job_id`/`error`, and `attempt_count`/`owner_label` are NOT in the wire shape (they live in the DB but aren't exposed in `JobView`). PLAN also missed `progress` (reserved, always null in v1).
  - PLAN's §3 is now rewritten to match the implemented Dart models (which match the backend exactly). PLAN §2's model-file list updated to reflect the real `lib/models/` layout (added `enums.dart`, renamed `search_result.dart` → `search_result_item.dart`).
- Verification (green-before + green-after per `CLAUDE.md`): `flutter analyze` → no issues; `flutter test` → 17/17 pass.

## 2026-06-09 — B1: secure storage + settings provider

- New `android/app/lib/providers/secure_storage.dart`:
  - `abstract class SecureStorage { read/write/delete }` — thin two-line interface so tests can substitute an in-memory fake without touching the Android platform channel.
  - `FlutterSecureStorageImpl` — production impl pinned to `AndroidOptions(encryptedSharedPreferences: true)` (modern API ≥23 backend; stated explicitly so a future flutter_secure_storage major can't silently downgrade us).
  - `@riverpod SecureStorage secureStorage(...)` — provider returning the active instance.
- New `android/app/lib/providers/settings.dart`:
  - `typedef SettingsValue = ({String? backendBaseUrl, String? bearerToken})` — Dart 3 record with free `==`/`hashCode`. No freezed boilerplate for two strings.
  - `@riverpod class Settings extends _$Settings` — `AsyncNotifier` that loads both keys in `build()`, exposes `save({backendBaseUrl?, bearerToken?})` and `clear()`. Both mutators write to storage then `ref.invalidateSelf()` so dependents (the dio client at B2) rebuild on change.
  - Storage keys: `backend_base_url`, `bearer_token` (lock the wire-format names so they aren't accidentally renamed later).
  - Save semantics: `null` field = "leave untouched". Use `clear()` to actually wipe. Documented inline because the `update` name was taken — `AsyncNotifierBase.update(...)` already exists, so the mutator is named `save`.
- New `android/app/test/providers/settings_test.dart` — 7 tests covering:
  - Fresh storage → both fields null.
  - Pre-seeded storage → values are loaded.
  - `save(url)` writes only the URL; the token stays absent.
  - `save(token)` preserves an existing URL.
  - `save(both)` persists both keys.
  - `save()` with no args is a no-op (does not delete existing values).
  - `clear()` wipes both keys + re-emits the null-pair state.
- Tests use a private `_FakeSecureStorage` (Map-backed) injected via `secureStorageProvider.overrideWith((ref) => fake)` on a `ProviderContainer`. The fake exposes a `snapshot` getter so tests can assert what actually hit storage (vs cached provider state).
- Codegen: `dart run build_runner build --delete-conflicting-outputs` regenerated `secure_storage.g.dart` + `settings.g.dart`.
- Verification: `flutter analyze` → no issues; `flutter test` → 24/24 pass (12 model + 7 settings + 5 router).

## 2026-06-09 — B2: dio client + bearer interceptor + typed ApiError

- New `android/app/lib/api/api_error.dart`:
  - `sealed class ApiError implements Exception` with six variants: `UnauthorizedError` (401), `ForbiddenError` (403), `UnprocessableError` (422), `RateLimitedError` (503, with parsed `Retry-After`), `NetworkError` (DNS/TCP/timeout), `HttpStatusError` (fallback for other 4xx/5xx). Each carries a `detail` from the backend's `{detail: …}` envelope and a `message` for snackbar copy. `final class` modifiers keep the hierarchy closed → exhaustive switching in the UI at E1.
  - `mapDioErrorToApiError(DioException)` — pure mapping function. Network-level `DioExceptionType`s collapse to `NetworkError`; `badResponse` is bucketed by status code. FastAPI's `{detail: "..."}` and `{detail: [{msg, loc}, ...]}` (Pydantic 422 form) are both handled by `_extractDetail`.
- New `android/app/lib/api/endpoints.dart` — bare path constants (`/health`, `/search`, `/download`, `/queue`, `status(jobId)`). Joined onto the user-supplied `backendBaseUrl` which already includes `/api/v1`.
- New `android/app/lib/api/client.dart`:
  - `BearerAuthInterceptor` — adds `Authorization: Bearer <token>` when the token is non-null and non-empty. No header when missing → keeps the "no token yet" and "token rejected" paths uniform (both end in 401).
  - `@riverpod Future<Dio> dioClient(...)` — awaits `settingsProvider.future`, builds a `Dio` with the configured `baseUrl`, 10s connect/send/receive timeouts, and a single `BearerAuthInterceptor`. Provider rebuilds whenever settings change (token rotation, URL change).
  - `apiCall<T>(request, parse)` — wraps a dio call; catches `DioException`, throws the mapped `ApiError`. Consumers in C1+/D1+/D2+ never touch `DioException` directly.
- New `android/app/test/api/client_test.dart` — 13 tests:
  - `BearerAuthInterceptor`: header injected with token, omitted when null, omitted when empty.
  - `apiCall` happy path: 200 → parsed body returned.
  - `apiCall` error mapping: 401 → `UnauthorizedError(detail)`, 403 → `ForbiddenError(detail)`, 422 → `UnprocessableError` (Pydantic list-form detail extracted), 503 with `Retry-After: 7` → `RateLimitedError(retryAfter=7s)`, 503 without header → defaults to 30s, 500 → `HttpStatusError(500)`, simulated `DioExceptionType.connectionError` → `NetworkError`.
  - `dioClientProvider`: builds a dio with the right `baseUrl` + interceptor token from a seeded `_InMemoryStorage`; rebuilds when settings change (asserts the new token is visible in the new dio's interceptor list).
- Tests use a hand-rolled `_FakeAdapter implements HttpClientAdapter` (~15 lines) — no extra dep on `http_mock_adapter`. Each test installs a `responder` closure that returns a `ResponseBody`.
- Codegen: `dart run build_runner build --delete-conflicting-outputs` regenerated `client.g.dart`.
- Verification: `flutter analyze` → no issues; `flutter test` → 37/37 pass (12 model + 7 settings + 13 api + 5 router).

## 2026-06-09 — B3: Settings screen UI

- `android/app/lib/screens/settings_screen.dart` — replaced the A2 stub with a real `ConsumerStatefulWidget`:
  - Two `TextFormField`s (Backend URL + Bearer token) inside a `Form` with a `GlobalKey<FormState>`. URL validator requires non-empty, parseable, `http`/`https` scheme + non-empty host; token validator requires non-empty.
  - Two action buttons side-by-side: `FilledButton` "Save" and `FilledButton.tonal` "Test connection". While testing, both disable and the Test button shows a 16×16 `CircularProgressIndicator`.
  - Field pre-population on first AsyncValue settle (`_maybePopulateFields` guarded by `_populated`); subsequent provider invalidations (after Save) don't stomp on what the user is typing.
  - URL normalisation strips trailing slashes (`/+$`) per `docs/PLAN.md` §4 so `/health` isn't joined onto `…/api/v1//`.
  - Refactor: extracted `_persist()` which writes silently; `_save()` calls it then shows the "Saved" snackbar; `_testConnection()` calls it then awaits `dioClientProvider.future`, runs `apiCall(/health)`, and shows "Connection OK" or "Connection failed: <ApiError.message>". The split exists because Material snackbars queue serially — having "Saved" fire from inside `_testConnection` prevented the "Connection OK" snackbar from appearing within the test window.
  - Loading + error states from `settingsProvider`'s AsyncValue: spinner during initial storage read; error text on storage failure.
- New `android/app/test/screens/settings_screen_test.dart` — 8 widget tests:
  1. Fresh storage → form renders with both empty fields + both buttons.
  2. Pre-seeded storage → fields are populated.
  3. Save → validates + persists to storage + "Saved" snackbar.
  4. URL with trailing slashes is normalised on Save (`/+$` stripped).
  5. Save with blank fields → both fields show "required" validator text; nothing hits storage.
  6. Save with a scheme-less URL → "must start with http:// or https://" inline error.
  7. Test connection on 200 → "Connection OK" snackbar; adapter received `/health`.
  8. Test connection on 401 → snackbar contains "Connection failed" + backend `detail` (proves the `ApiError` round-trip from `mapDioErrorToApiError`).
- Test infra: same hand-rolled `_FakeAdapter` from B2 tests; `_InMemoryStorage` snapshot getter asserts what actually hit storage. `dioClientProvider` is overridden directly to return a pre-built `Dio` with the fake adapter (riverpod codegen accepts `FutureOr<Dio>` for the override callback).
- **Regression in `test/router_test.dart` repaired in the same milestone.** The A2 router test passed because `SettingsScreen` was a stub. With the real screen reading `settingsProvider`, the test hung in `pumpAndSettle` because `FlutterSecureStorageImpl` calls the Android platform channel (no mock in widget tests). Fix: the router test now overrides `secureStorageProvider` with a no-op `_NoopStorage` (read returns null, write/delete are no-ops). Per `/CLAUDE.md` staleness rule, fixed in the same task.
- Verification: `flutter analyze` → no issues; `flutter test` → 45/45 pass (12 model + 7 settings + 13 api + 8 settings-screen + 5 router).

## 2026-06-09 — C1: search providers

- New `android/app/lib/providers/search.dart`:
  - `typedef SearchQueryState = ({String query, SpotifyType type})` — Dart 3 record for the search-bar state. Free `==`, no codegen.
  - `searchDebounceProvider` (Riverpod, `keepAlive: true`) returns `Duration` — default `300ms`. Exposed as its own provider so tests override to `Duration.zero` for the simple cases and to a short real duration only when verifying cancellation timing.
  - `SearchQuery` (`@Riverpod(keepAlive: true) class … extends _$SearchQuery`) — `Notifier<SearchQueryState>`. `keepAlive: true` because the user's last query should survive a tab switch (Search → Queue → Search). Exposes `setQuery(String)` and `setType(SpotifyType)` mutators that preserve the other field.
  - `searchResults` (`@riverpod Future<SearchResponse>`) — depends on `searchQueryProvider` and `dioClientProvider`. Empty query (incl. whitespace-only) short-circuits to `SearchResponse(results: [])` without touching the network. Non-empty:
    1. Register `CancelToken` via `ref.onDispose(cancelToken.cancel)` — fires when the user retypes (provider invalidates → autoDispose tears down the old ref).
    2. `await Future.delayed(debounce)`.
    3. Bail with `_DebounceCancelled` if the cancelToken fired during the wait — the new query has already started building, this future has no listener.
    4. `dio.post(/search, body: SearchRequest, cancelToken: cancelToken)` via `apiCall<SearchResponse>` from B2 — typed `ApiError` propagation comes for free.
- New `android/app/test/providers/search_test.dart` — 8 unit tests:
  - `SearchQuery state`: initial state (empty + track), `setQuery` preserves type, `setType` preserves query.
  - `searchResults` empty query → empty results, zero adapter requests.
  - `searchResults` whitespace-only query → same short-circuit.
  - `searchResults` non-empty query → adapter sees `POST /search` with body `{query, type: 'track', limit: 20}`; parsed response shape matches.
  - `searchResults` type toggle → second request fires with `type: 'album'`; exactly 2 adapter calls.
  - `searchResults` rapid retype (a → ab → abc within a 100ms debounce window) → exactly 1 adapter request reaches the network and it carries `query: 'abc'` (proves cancellation cascade works).
- Test infra: reuses the hand-rolled fake adapter pattern from B2/B3, parameterised as `_CountingAdapter` to expose `requests`. `_container(...)` helper wires the dio override + a configurable debounce. Crucial detail: tests must `c.listen(searchResultsProvider, …)` before awaiting `.future`, otherwise autoDispose tears down the ref between the `read` and the `await` and the cancelToken fires inside dio's `post`, surfacing as `NetworkError`. Documented in the comment in the "POSTs /search" test.
- Codegen: `dart run build_runner build` regenerated `search.g.dart`.
- Verification: `flutter analyze` → no issues; `flutter test` → 53/53 pass (12 model + 7 settings + 13 api + 8 settings-screen + 8 search + 5 router).

## 2026-06-09 — C2: Search screen UI

- New `android/app/lib/widgets/result_tile.dart` — `ResultTile(SearchResultItem)`:
  - 56×56 cover via private `_Cover` widget: `Image.network` with rounded corners; falls back to a M3-tinted `music_note` placeholder when `coverUrl` is null/empty or the network load errors. Placeholder colours pull from `Theme.of(context).colorScheme.surfaceContainerHighest` / `onSurfaceVariant` so the tile feels at home on the dark surface.
  - `ListTile` body: title (1 line, ellipsis), subtitle (artist • album when present, just artist otherwise), trailing `Icons.download_done` only when `alreadyDownloaded == true`.
  - `Opacity(0.5)` wrapper when `alreadyDownloaded` is true. Tap-to-download dispatch lands at D1; until then the trailing slot is information-only.
- New `android/app/lib/screens/search_screen.dart` — replaces the A2 stub with a real `ConsumerStatefulWidget`:
  - `TextField` with `controller: TextEditingController(text: ref.read(searchQueryProvider).query)` initialised once in `initState` — so the user's last query survives a Search → Queue → Search tab round-trip (paired with `keepAlive: true` on `searchQueryProvider`). `onChanged` forwards every keystroke to `setQuery`; debouncing lives in the provider per C1.
  - `SegmentedButton<SpotifyType>` for the Tracks/Albums/Playlists toggle; `onSelectionChanged` calls `setType`. Single-select (`SegmentedButton.selected` is a `Set<SpotifyType>` of size 1).
  - `Expanded` body driven by `searchResultsProvider.when(loading, error, data)`. Empty query → "Type to search Spotify" hint; empty results → "No results"; `ApiError` → its `message`; populated → `ListView.builder` of `ResultTile`s.
- New `android/app/test/screens/search_screen_test.dart` — 10 widget tests:
  1. Initial state (empty query) shows the "Type to search Spotify" hint and zero `ResultTile`s.
  2. Loading state shows a `CircularProgressIndicator`.
  3. Non-empty query + results renders a `ResultTile` per item, the right title/artist text, the `artist • album` subtitle when album is present, and the `download_done` badge on the `alreadyDownloaded` row.
  4. Non-empty query with empty results shows "No results".
  5. `ApiError` (RateLimitedError) state renders `e.message` ("upstream rate limited").
  6. Tapping the Albums segment then Playlists segment updates `searchQueryProvider.type` in sequence.
  7. Typing in the `TextField` updates `searchQueryProvider.query`.
  8. The `TextField` seeds from existing provider state (proves the keepAlive round-trip works).
  9. + 10. `ResultTile` unit tests: not-downloaded renders title/artist + placeholder icon, no badge; downloaded renders the badge + Opacity(0.5).
- Test infra: `_resultsValue(AsyncValue)` helper installs a controllable `searchResultsProvider` override that returns a synchronous Future for data/error and a never-completing one for loading; widget tests reuse the pattern from earlier milestones. Loading-state test does NOT `pumpAndSettle` because the loading future is intentionally pending.
- Verification: `flutter analyze` → no issues; `flutter test` → 63/63 pass (12 model + 7 settings + 13 api + 8 settings-screen + 8 search + 10 search-screen + 5 router).

## 2026-06-09 — D1: Download dispatch from result tile

- New `android/app/lib/providers/download.dart` — `DownloadDispatcher` (`@Riverpod(keepAlive: true) class … extends _$DownloadDispatcher`). State is `Set<String>` (in-flight `spotify_uri`s). The single mutator `dispatch(String spotifyUri)`:
  1. Adds the URI to `state` (so any widget watching `state.contains(uri)` sees a transition to `true`).
  2. `await ref.read(dioClientProvider.future)` → `apiCall<DownloadResponse>(dio.post(/download, …))` reusing B2's typed-error pipeline.
  3. `finally` removes the URI from `state` — guarantees the tile becomes responsive again whether dispatch succeeded or threw `ApiError`.
  - `keepAlive: true` so the in-flight set survives screen rebuilds (typing in the search box rebuilds the result list; we don't want a tile spinner to flicker off mid-flight).
- Modified `android/app/lib/widgets/result_tile.dart` — `ResultTile` is now a `ConsumerWidget`:
  - Accepts optional `VoidCallback? onTap`.
  - Watches `downloadDispatcherProvider.select(s => s.contains(item.spotifyUri))` so only its own URI's transitions cause a rebuild — not the whole list when any one tile flips.
  - Trailing slot is now a 3-way `_Trailing`: spinner (`SizedBox(24×24, CircularProgressIndicator(strokeWidth: 2))`) when in-flight → `Icons.download_done` when `alreadyDownloaded` → `Icons.download_outlined` otherwise (replaces C2's "no trailing when not downloaded" — the outline icon advertises tap-to-queue affordance).
  - `onTap` is wired to `ListTile.onTap` only when `onTap != null && !inFlight && !item.alreadyDownloaded` — prevents double-firing and matches the dimmed-disabled visual on already-downloaded rows.
- Modified `android/app/lib/screens/search_screen.dart`:
  - `_Body` upgraded from `StatelessWidget` to `ConsumerWidget` so the `ListView.builder` callback has a `WidgetRef`.
  - Each tile gets `onTap: () => _dispatchDownload(context, ref, item)`.
  - New top-level `_dispatchDownload(BuildContext, WidgetRef, SearchResultItem)` captures the `ScaffoldMessenger` before the await, awaits `dispatch(uri)`, then shows one of: `"Queued"` (deduped == false), `"Already downloaded"` (deduped == true), or `ApiError.message` on catch. `hideCurrentSnackBar()` runs before each show so rapid taps don't queue up snackbars.
- New `android/app/test/providers/download_test.dart` — 5 unit tests:
  - Initial state: in-flight set is empty.
  - Happy path: dispatch POSTs `/download` with `{spotify_uri: …}` body; response parsed into `DownloadResponse{jobId, state, deduped}`.
  - Deduped response is surfaced through `DownloadResponse.deduped`.
  - In-flight set membership transitions empty → {uri} → empty across a gated dispatch; observed via `c.listen(downloadDispatcherProvider, …)` history list.
  - 4xx response throws typed `UnauthorizedError`; finally-block still clears the URI from the in-flight set.
  - Concurrent dispatches for two URIs are both tracked simultaneously and clear independently as each completes.
- Search-screen widget tests extended — 5 new tests under `group('D1 — tap dispatches /download')`:
  - non-deduped (HTTP 202, `deduped: false`) → asserts `POST /download` with `spotify_uri` body + "Queued" snackbar text rendered.
  - deduped (`deduped: true`) → "Already downloaded" snackbar.
  - 401 response → snackbar shows the mapped `ApiError.message` ("token revoked").
  - Mid-flight (gated `Completer` response): tapping shows a `CircularProgressIndicator` on the row; completing the gate clears it.
  - `alreadyDownloaded: true` tile is not tappable → tapping fires zero `POST /download` requests.
- Test-infra detail: the snackbar-text assertions are wrapped in `tester.runAsync(() async { tap; await Future.delayed(100ms); })` followed by a `pump()`. `runAsync` escapes the fake-async zone so dio's internal stream-based body decoding actually resolves; without it, `pump()` alone can't drain the chain in time for the snackbar text to appear. (The mid-flight test stays in fake-async because it only cares about the synchronous state set on dispatch start.)
- ResultTile is now a `ConsumerWidget`, so the two existing unit tests at the bottom of `search_screen_test.dart` had to be wrapped in `ProviderScope` to provide the inherited container.
- Codegen: `dart run build_runner build --delete-conflicting-outputs` regenerated `download.g.dart` (no other touch).
- Verification: `flutter analyze` → no issues; `flutter test` → 74/74 pass (was 63; +5 download provider + +5 search-screen tap, +1 reused `_Body→ConsumerWidget` test stayed green).

## 2026-06-09 — D2: Queue screen + polling provider

- New `android/app/lib/widgets/status_pill.dart` — `StatusPill(JobState state)`. Small rounded chip with the PLAN.md §8 colour mapping (queued = blue, running = amber, done = green, failed = red). 0.15 alpha fill + 1px border in the same hue + 12-pt label.
- New `android/app/lib/providers/queue.dart`:
  - `queuePollIntervalProvider` (Riverpod, `keepAlive: true`) — `Duration`, default `3s`. Exposed so tests override to short durations.
  - `Queue` (`@Riverpod(keepAlive: true) class … extends _$Queue`) — `AsyncNotifier<QueueResponse>`. `build()` does the initial fetch then `_scheduleNext()`. Owns a `Timer? _timer` cancelled in `ref.onDispose`. `_tick` re-runs `_fetch` via `AsyncValue.guard`, then `_scheduleNext()` regardless of success — transient errors don't stop the cycle. Mutators: `pause()` cancels the timer + sets a `_paused` flag; `resume()` clears the flag, fires `_tick` immediately, and the schedule resumes.
  - Deviation from PLAN.md "Polling via `StreamProvider`+`Stream.periodic`": `StreamProvider` has no consumer-facing pause/resume. `AsyncNotifier` exposes mutators the screen can call from `WidgetsBindingObserver.didChangeAppLifecycleState`. PLAN §6 + §8 updated to match; DECISIONLOG entry appended this turn. The "no `Timer`s leaked from `StatefulWidget`s" intent is preserved — the `Timer` is owned by the provider, not by a screen widget.
- Modified `android/app/lib/screens/queue_screen.dart` — replaces the A2 stub:
  - `ConsumerStatefulWidget` with `WidgetsBindingObserver`. `addObserver` in `initState`, `removeObserver` in `dispose`.
  - `didChangeAppLifecycleState` maps `paused / inactive / hidden` → `queueProvider.notifier.pause()` and `resumed` → `unawaited(resume())`. `detached` is a no-op.
  - Body via `queueProvider.when(loading, error, data)`:
    - loading → `CircularProgressIndicator`.
    - error → centered `ApiError.message` (or `'Error: $e'`).
    - data + both lists empty → "No jobs yet".
    - data + non-empty → `RefreshIndicator` wrapping a `ListView` with two `_SectionHeader`s ("Active" / "Recent") and one `_JobTile` per `JobView`. Sections are only rendered when non-empty.
  - `_JobTile`: monospace `spotifyUri` title (ellipsis), "job <8-char-id-prefix>" subtitle, trailing `StatusPill`. Tap-to-detail lands at D3.
- New `android/app/test/providers/queue_test.dart` — 6 unit tests (fake_async based):
  - Initial fetch fires `GET /queue` once; response parsed (real `await` outside fake_async).
  - Periodic polling: 3 ticks observed at `t = 0 / 3s / 6s` against a `_CountingAdapter`.
  - Polling respects `queuePollIntervalProvider` override (1s interval → 4 requests over 3s).
  - Transient error doesn't stop the cycle: tick #2 returns 500 (state becomes `AsyncError`), tick #3 still fires and lands as `AsyncData` again.
  - `pause()`: no requests fire even after 30 s of elapsed simulated time.
  - `resume()` after `pause()`: immediate fetch + schedule resumes at the configured interval.
  - Drain detail: `async.elapse(const Duration(microseconds: 1))` is used after each subscription / state change instead of `async.flushMicrotasks()`. dio's body-decoding chain doesn't fully drain through microtasks-only on the fake_async zone; advancing the clock by 1 µs forces a full drain without firing the 3 s periodic timer.
- New `android/app/test/screens/queue_screen_test.dart` — 6 widget tests:
  - Loading → `CircularProgressIndicator`.
  - Empty (both lists empty) → "No jobs yet".
  - Both sections populated → "Active" + "Recent" headers + 3 `StatusPill`s + the right state labels (running/done/failed) + the short-id subtitles.
  - Active-only (recent empty) → "Active" rendered, "Recent" not rendered.
  - Error state → `ApiError.message` ("cannot reach backend — check tailscale") rendered.
  - `StatusPill` unit test: all four `JobState` labels render.
- Test infra: `_StubQueue extends Queue` with `pause()`/`resume()` as no-ops, and a `build()` that returns the override's `AsyncValue` as a Future. Avoids touching dio or any real timer in widget tests.
- `pubspec.yaml`: added `fake_async: ^1.3.0` as a direct dev dep (already transitive via `flutter_test`; listing explicitly silences `depend_on_referenced_packages`).
- Codegen: `dart run build_runner build --delete-conflicting-outputs` regenerated `queue.g.dart`.
- Verification: `flutter analyze` → no issues; `flutter test` → 86/86 pass (was 74; +6 queue provider + +6 queue screen).

## 2026-06-09 — D3: Job detail screen + polling provider

- New `android/app/lib/providers/job_status.dart`:
  - `jobStatusPollIntervalProvider` (Riverpod, `keepAlive: true`) — `Duration`, default `2s` per PLAN.md §8. Overrideable in tests.
  - `JobStatus` (`@riverpod` family — i.e. **auto-dispose**) — `class … extends _$JobStatus { Future<JobView> build(String jobId) … }`. Auto-dispose so navigating away from the detail screen tears the timer down via `ref.onDispose`. Family arg is the `jobId`, so two open detail screens for different jobs get independent provider instances.
  - `build(jobId)` does the initial fetch; if the state is non-terminal it schedules the next tick. `_tick` re-fetches via `AsyncValue.guard`, then reschedules **only if the new state isn't terminal**. Errors keep polling (transient blip shouldn't strand the screen).
  - `JobStateX.isTerminal` (`done` or `failed`) is the gate.
- New `android/app/lib/screens/job_detail_screen.dart`:
  - `ConsumerWidget`. Watches `jobStatusProvider(jobId)`. `.when(loading, error, data)` → spinner / `ApiError.message` / `_JobBody`.
  - `_JobBody` is a scrollable `ListView` containing: header row (`StatusPill` + spotify type), then `_Field` rows for `spotify uri`, `job id`, `_TimestampField`s for `created` (always), `started` (when non-null), `finished` (when non-null), an `_Field` for `output_path` (when present), and an `_ErrorField` (when `error` non-null).
  - `_Field`: label + value, with optional copy-to-clipboard `InkWell` that calls `Clipboard.setData` and shows a `Copied <label>` snackbar.
  - `_TimestampField`: relative ("5m ago") + absolute (`toIso8601String`) lines. `_relative` helper handles seconds/minutes/hours/days; no intl dep needed for the v1 thin client.
  - `_ErrorField`: M3 `errorContainer` background, `error_outline` icon, message text in `onErrorContainer`.
- Modified `android/app/lib/router.dart`:
  - Added `import 'screens/job_detail_screen.dart'`.
  - Registered `GoRoute(path: '/job/:id', …)` **outside** the `ShellRoute` so the detail screen is full-screen with a normal AppBar back button — no bottom nav stealing visual space. Path matches the existing `Routes.job(id)` helper.
- Modified `android/app/lib/screens/queue_screen.dart`:
  - Added `import 'package:go_router/go_router.dart'` + `import '../router.dart'`.
  - `_JobTile.onTap` now calls `context.push(Routes.job(job.jobId))` so the back button returns to the queue with state intact.
- New `android/app/test/providers/job_status_test.dart` — 7 tests (`fake_async`, same `_CountingAdapter` + `elapse(Duration(microseconds: 1))` drain pattern as queue_test):
  - Initial fetch fires `GET /status/<id>` with the right path; response parsed.
  - Non-terminal state polls every 2s for 3 ticks.
  - Override interval (1s) honoured.
  - Transient 500 keeps polling (state becomes error then data again).
  - Initial `done` → no further ticks even after 30 s of elapsed time.
  - `running → running → done` transition → polling stops after the terminal tick.
  - `failed` is also terminal → no further ticks.
- New `android/app/test/screens/job_detail_screen_test.dart` — 6 widget tests:
  - AppBar shows "Job <short-id>"; loading shows `CircularProgressIndicator`.
  - Full body for a running job: `StatusPill`, label, spotify uri, full job id, relative timestamps ("Xm ago").
  - `output_path` rendered + tap → `Clipboard.setData` invoked + "Copied output path" snackbar. Clipboard verified via `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, …)` capturing `Clipboard.setData` calls.
  - Failed job → error container with `error_outline` icon + the error message.
  - Provider error path → renders `ApiError.message` ("cannot reach backend — check tailscale").
  - Queued job (no startedAt / finishedAt) → those field labels are not rendered.
- Test infra: `_StubJobStatus extends JobStatus` with a stubbed `build(jobId)` that returns whatever `AsyncValue` was injected — same pattern as `_StubQueue` from D2. Avoids any real dio or Timer in widget tests.
- `_jobJson` helper uses Dart 3 null-aware **value** elements (`'error': ?error,`) so optional fields are dropped from the wire payload when null. Lint `use_null_aware_elements` enforces this style.
- Codegen: `dart run build_runner build --delete-conflicting-outputs` regenerated `job_status.g.dart`.
- Verification: `flutter analyze` → no issues; `flutter test` → 99/99 pass (was 86; +7 job_status provider + +6 job_detail screen).

## 2026-06-09 — E1: Error UX wiring per PLAN §9

- New `android/app/lib/widgets/error_snackbar.dart`:
  - `buildApiErrorSnackBar(ApiError, {action})` — pure function that returns a `SnackBar` with the **locked PLAN §9 copy** per variant. Sealed-class switch covers all six branches:
    - 401 `UnauthorizedError` → "auth failed — re-paste your token"
    - 403 `ForbiddenError` → "this token cannot {action}" when caller passed an `action` verb; falls back to `detail` or "insufficient scope" otherwise
    - 422 `UnprocessableError` → backend `detail` (or "invalid request" fallback)
    - 503 `RateLimitedError` → "Spotify rate-limited — retry in {Ns}", `SnackBar.duration` clamped to `[2, 10]s` so a long Retry-After doesn't pin the snackbar on screen
    - `NetworkError` → "cannot reach backend — check Tailscale"
    - `HttpStatusError` → "{code}: {detail}" (or "{code}: request failed")
  - `showApiError(BuildContext, ApiError, {action})` — wraps the pure builder with `ScaffoldMessenger` side effects: hides any current snackbar, shows the new one, and for `UnauthorizedError` additionally posts a `Future.microtask` that calls `GoRouter.of(context).go(Routes.settings)`. The redirect is gated on `GoRouter.maybeOf(context) != null` so widget-level tests that mount a single screen without a router don't crash.
  - `reactToApiError<T>(BuildContext, AsyncValue<T>? prev, AsyncValue<T> next, {action})` — `ref.listen` callback wrapper. Fires `showApiError` only when the next state is `AsyncError<T>` carrying an `ApiError`, **and** the previous error's runtime type doesn't match. Prevents polling providers (queue 3s, job status 2s) from spamming the user when the same error class persists across ticks.
- Modified `android/app/lib/screens/search_screen.dart`:
  - `build` now adds `ref.listen<AsyncValue<SearchResponse>>(searchResultsProvider, …)` → `reactToApiError<SearchResponse>(..., action: 'search')`.
  - `_dispatchDownload` catch block: replaced the bespoke `SnackBar(content: Text(e.message))` with `showApiError(context, e, action: 'download')` — same routing as the polling path.
  - Inline body error text is still rendered as a fallback (the screen isn't blank if the snackbar is missed).
- Modified `android/app/lib/screens/queue_screen.dart` — `ref.listen` → `reactToApiError<QueueResponse>(...)` (no `action` since the queue is read-only).
- Modified `android/app/lib/screens/job_detail_screen.dart` — `ref.listen` → `reactToApiError<JobView>(...)`.
- Modified `android/app/lib/screens/settings_screen.dart` — `_testConnection` catch block now calls `showApiError(context, e)` instead of the bespoke "Connection failed: …" copy. Note: the auto-redirect on 401 is a no-op when the user is already on /settings.
- New `android/app/test/widgets/error_snackbar_test.dart` — 10 widget tests:
  - One per PLAN §9 row (8 cases including ForbiddenError-with-action, ForbiddenError-without-action, and the HttpStatusError detail/no-detail variants).
  - `UnauthorizedError` redirects to `/settings` when a `GoRouter` ancestor exists. Verified by mounting a 2-route minimal router and asserting the post-tap location renders the "SETTINGS" placeholder.
  - `UnauthorizedError` is a no-op for the redirect leg (no exception) when no `GoRouter` ancestor exists — the snackbar still fires.
- Updated `android/app/test/screens/settings_screen_test.dart` "Test connection on 401 shows the mapped error" → asserts the locked PLAN copy "auth failed — re-paste your token" (was "Connection failed: bad token").
- Updated `android/app/test/screens/search_screen_test.dart` D1 401 test → renamed to "ApiError on download → showApiError snackbar (E1 copy)"; asserts the same locked PLAN copy.
- Verification: `flutter analyze` → no issues; `flutter test` → 109/109 pass (was 99; +10 error_snackbar).

## 2026-06-09 — E2: Empty + loading polish

- New `android/app/lib/widgets/empty_state.dart` — `EmptyState({icon, title, subtitle?})`. Centered 56-px icon in `onSurfaceVariant` + `titleMedium` title + optional `bodyMedium` subtitle in the muted tint. Dark-theme neutral palette so it's unambiguously *not* an error.
- New `android/app/lib/widgets/skeleton.dart`:
  - `SkeletonBox(width, height, [borderRadius])` — low-contrast `surfaceContainerHighest` rectangle. Building block for every skeleton.
  - `SkeletonTile` — `ListTile` shape: 56×56 leading box + 180×12 title box + 120×10 subtitle box. Used as the loading placeholder for the search-results list and the queue list.
  - `SkeletonList({count})` — `ListView.builder` of `count` `SkeletonTile`s.
- Modified `android/app/lib/screens/search_screen.dart` `_Body`:
  - `loading` branch → `SkeletonList(count: 6)` (was `CircularProgressIndicator`).
  - Empty-query data branch → `EmptyState(icon: search, title: 'Search Spotify', subtitle: 'Tracks, albums, or playlists')` (was the centered text "Type to search Spotify").
  - Empty-results data branch → `EmptyState(icon: search_off, title: 'No results', subtitle: 'Try a different query')`.
- Modified `android/app/lib/screens/queue_screen.dart`:
  - `loading` → `SkeletonList(count: 4)`.
  - Empty data → `EmptyState(icon: queue_music, title: 'No jobs yet', subtitle: 'Search and tap a track to queue a download')`.
- Modified `android/app/lib/screens/job_detail_screen.dart`:
  - `loading` → `_JobDetailSkeleton` — column of `SkeletonBox`es laid out to match the detail body's shape (status-pill placeholder + 3 label/value pairs). Visually telegraphs the structure the user is about to see.
- Updated existing screen tests:
  - `search_screen_test` loading test now asserts `SkeletonList` + `SkeletonTile`s (was `CircularProgressIndicator`).
  - `search_screen_test` "empty query" test now asserts `EmptyState` + the "Search Spotify" text **scoped under the EmptyState** (the TextField's `labelText` also reads "Search Spotify" so the unscoped `find.text` matched twice).
  - `search_screen_test` "no results" test asserts the `EmptyState` widget.
  - `queue_screen_test` loading/empty tests assert `SkeletonList`/`EmptyState`.
  - `job_detail_screen_test` loading test asserts `SkeletonBox`es.
- New `android/app/test/widgets/empty_state_test.dart` — 3 tests: icon + title rendered; subtitle rendered when provided; subtitle widget not in the tree when null.
- New `android/app/test/widgets/skeleton_test.dart` — 3 tests: `SkeletonBox` honours configured width/height via `BoxConstraints`; `SkeletonTile` is a `ListTile` composed of 3 `SkeletonBox`es; `SkeletonList(count: 3)` renders exactly 3 `SkeletonTile`s.
- Verification: `flutter analyze` → no issues; `flutter test` → 115/115 pass (was 109; +3 empty_state + +3 skeleton).

## 2026-06-09 — F1: Android signing + release build

- Modified `android/app/android/app/build.gradle.kts`:
  - Imports `java.util.Properties` + `java.io.FileInputStream` at the top.
  - Reads `rootProject.file("key.properties")` (i.e. `android/app/android/key.properties`) into a `Properties` instance if the file exists.
  - New `signingConfigs { create("release") { … } }` block populated from `key.properties` (`keyAlias`, `keyPassword`, `storeFile`, `storePassword`). `storeFile` is resolved via `rootProject.file(...)` so the path inside `key.properties` is rooted at `android/app/android/` — `storeFile=keystore.jks` puts the keystore next to `key.properties`.
  - `buildTypes.release.signingConfig` is now `signingConfigs.release` when `key.properties` exists, falling back to `signingConfigs.debug` when it doesn't — fresh clones still build a release APK (debug-signed, marked as such in the Gradle log).
  - Stripped the boilerplate "TODO: Specify your own unique Application ID" comments since `applicationId` is already `com.aashish.heerr`.
- New `android/app/android/key.properties.example` — checked-in template with `CHANGE_ME` placeholders for `storePassword` / `keyPassword`, default `keyAlias=heerr` and `storeFile=keystore.jks`. Header comment documents that the real `key.properties` lives in the same directory and is gitignored.
- Updated `android/README.md` "Building a release APK" section:
  - 3-step "one-time setup" — `keytool -genkey -v -keystore android/app/android/keystore.jks -alias heerr -keyalg RSA -keysize 2048 -validity 10000`, prompts walkthrough (dname fields can be junk for personal sideload; press Enter at the key-password prompt to reuse the keystore password), then `cp key.properties.example key.properties` + fill in passwords, then `keytool -list -v` sanity check.
  - "Build + install" steps for `flutter build apk --release` + `adb install`.
  - Explicit warning that a missing `key.properties` silently falls back to the debug key — the resulting APK installs but **is not shippable**.
  - "What's gitignored" recap: `keystore.jks`, `key.properties`, `**/*.jks`.
- `.gitignore` entries were already in place from the planning round (`android/key.properties`, `android/keystore.jks`, `**/*.jks` in `android/app/.gitignore`) — no change needed.
- Verification:
  - `flutter analyze` → no issues; `flutter test` → 115/115 pass (no Dart changes; just Gradle + docs).
  - `flutter build apk --debug` → succeeds (Gradle parses the new signing config without error).
  - `flutter build apk --release` (no `key.properties` present) → succeeds via the debug-key fallback. Output APK at `build/app/outputs/flutter-apk/app-release.apk` (51.9 MB).
  - Generation of the real keystore + `key.properties` is the user's responsibility — they own the secrets per `/CLAUDE.md` §3 "never hardcode or commit secrets". The README documents the exact `keytool` invocation.

## 2026-06-10 — G1: end-to-end smoke on home server

- **`android/app/android/app/src/main/AndroidManifest.xml`** — added `android:usesCleartextTraffic="true"` to `<application>`. Android API 28+ blocks plain HTTP by default, which made every dio request fail as a `NetworkError` ("cannot reach backend — check Tailscale") even though `curl` over Tailscale worked fine. The backend is reached as `http://<tailscale-ip>:8000/api/v1` (no TLS — Tailscale already provides authenticated transport between tailnet peers, see `/CLAUDE.md` §3 "Connectivity is Tailscale only"), so cleartext over the tailnet is the intended posture.
- Manual smoke verified end-to-end on the Pixel 7 (Android 16) against the live home server (Tailscale IP `100.106.120.121`, backend port 8000):
  1. Settings: pasted URL + admin bearer token, "Test connection" → "Connection OK" snackbar.
  2. Search: query returned Spotify results with thumbnails and the type toggle behaved.
  3. Dispatch: tap a result → backend accepted `/download`, snackbar fired.
  4. Queue + Job detail screens polled correctly through `queued → running → done`.
  5. File landed in `/data/media/music/...` on the home server; Navidrome indexed within ~1 min.
- `flutter analyze` clean; `flutter test` 115/115 pass (no Dart changes).
- Backend port 8000 was published on the host (added `ports: ["8000:8000"]` to `heerr-backend` in `~/docker/arr-stack/docker-compose.yml`) so the phone can reach it over Tailscale — the container network `172.39.0.0/24` is host-internal. The bind is on all host interfaces but only `100.x.x.x` is reachable from the tailnet, so the Tailscale-only posture holds.

Android roadmap (A1–G1) complete.

## 2026-06-10 — display_name shown in queue + job detail

Queue and job-detail screens now show human-readable labels ("Imagine — John Lennon", "Currents — Tame Impala", playlist names) instead of the raw `spotify:…:id` URI. Computed client-side from the search result and passed to `POST /download` for backend persistence.

- **`android/app/lib/models/download_request.dart`** — added optional `displayName`. Generated `toJson` omits the key when null, so old-shape requests are still valid wire-compatible bodies.
- **`android/app/lib/models/job_view.dart`** — added optional `displayName` mirroring backend `JobView.display_name`.
- **`android/app/lib/providers/download.dart`** — `dispatch(spotifyUri, {displayName})` named-arg signature.
- **`android/app/lib/screens/search_screen.dart`** — new `_displayNameFor(item)` helper formats `"{title} — {artist}"` for tracks/albums and `"{title}"` for playlists (their `artist` field carries the owner, not a musical artist).
- **`android/app/lib/screens/queue_screen.dart`** — `_JobTile` renders `displayName` in the body font when present; falls back to monospace URI for legacy jobs (display_name is null on rows created before the upgrade).
- **`android/app/lib/screens/job_detail_screen.dart`** — `_JobBody` shows the display name as a `titleLarge` heading above the technical fields when present.
- **Tests:** updated `test/models_test.dart` (DownloadRequest two-case round-trip, JobView payload), `test/providers/download_test.dart` (asserts new dispatch signature + body), `test/screens/search_screen_test.dart` (asserts the formatted display_name in the POST body), `test/screens/settings_screen_test.dart` rewritten to target the new SettingsScreen → ServersScreen navigation (the prior tests targeted the inline URL/token form which moved to ServersScreen earlier today). Suite: 111 passing.

## 2026-06-10 — Post-roadmap: display_name + YTMusic swap

- **display_name in queue/job-detail** (v0.1.x): `DownloadRequest` gained optional `display_name`; `JobView` gained `displayName`. Queue and job-detail screens show "Song — Artist" instead of the raw URI. `_displayNameFor(item)` helper computes the label from search result fields.
- **YTMusic search swap** (v0.2.0): Replaced `SpotifyType` enum with `ContentType` (`song/album/playlist`). `SearchResultItem.spotifyUri/spotifyUrl` → `sourceUrl/sourceType`. `DownloadRequest.spotifyUri` → `sourceUrl + sourceType`. `JobView.spotifyUri/spotifyType` → `sourceUrl/sourceType`. Search screen label updated to "Search YouTube Music". `SegmentedButton` now shows Songs/Albums/Playlists. `_displayNameFor` uses `sourceType` instead of parsing the old URI prefix. All 111 tests updated and passing.
- **AndroidManifest fix** (G1): `android:usesCleartextTraffic="true"` added — Android API 28+ blocks plain HTTP; backend is reached over Tailscale as `http://` so cleartext is required.

## 2026-06-11 — H1: Subsonic auth client + Settings extension + "Test Navidrome"

First milestone of `ROADMAP_STREAMER.md`. Adds the Subsonic auth/transport layer the streaming feature needs, and extends the existing per-server settings + form to carry Navidrome credentials alongside the existing heerr bearer token.

- New: `android/app/lib/api/subsonic_client.dart` — `SubsonicAuthInterceptor` (injects `u`, `s`, `t=md5(password+salt)`, `v=1.16.1`, `c=heerr`, `f=json` on every request; salt generator is injectable for deterministic tests, defaults to 6 cryptographically-random bytes via `Random.secure()`). `subsonicDioClient` Riverpod provider depends on `settingsProvider` so credential changes rebuild the dio. `subsonicCall<T>` wraps a dio call, inspects the standard `{"subsonic-response": {...}}` envelope, and throws the matching `ApiError` on `status: "failed"` (Subsonic always returns HTTP 200 even for semantic errors).
- New: `android/app/lib/api/subsonic_endpoints.dart` — path constants for `ping`, `getArtists`, `getArtist`, `getAlbum`, `getPlaylists`, `getPlaylist`, `search3`, `stream`, `getCoverArt`. Joined onto `navidromeBaseUrl`.
- New: `android/app/test/api/subsonic_client_test.dart` — interceptor injects the six params; uses injected salt deterministically across requests; `t` matches the documented Subsonic fixture `md5("sesame" + "c19b2d") = "26719a1196d2a940705a59634eb18eab"`; omits params when either credential is null/empty; preserves caller-supplied query params. `subsonicCall` returns the parsed envelope on `status: ok`; maps Subsonic codes 40/41 → `UnauthorizedError`, 50 → `ForbiddenError`, 70 → `NotFoundError`, anything else → `HttpStatusError(code)`. Transport-level errors still flow through `mapDioErrorToApiError`. `subsonicDioClient` builds with the right base URL + interceptor from seeded settings.
- New: `android/app/test/screens/servers_screen_test.dart` — three widget tests: ok-envelope ping → "Connection OK"; failed-envelope (code 40) → auth-failed snackbar; missing navidrome fields → guard snackbar without firing the request.
- Modified: `android/app/lib/api/api_error.dart` — new `NotFoundError` variant (404 / Subsonic 70). HTTP-status map gains a `case 404 → NotFoundError`. Exhaustive switch in `lib/widgets/error_snackbar.dart` extended with a `NotFoundError(detail: …)` arm.
- Modified: `android/app/lib/providers/settings.dart` — `SettingsValue` record gains `navidromeBaseUrl`, `navidromeUsername`, `navidromePassword` (all `String?`). New `_kKey*` storage keys (`navidrome_base_url`, `navidrome_username`, `navidrome_password`). `Settings.build/save/clear` plumb the new keys. `ServerProfile` gains the same three optional fields; `toJson`/`fromJson` extended (legacy profile JSON without the new keys still parses — fields come back as `null`). `ServerProfiles.saveProfile/activate` propagate the new fields into the active settings so `subsonicDioClient` picks them up.
- Modified: `android/app/test/providers/settings_test.dart` — extended `fresh-storage`, `pre-seeded`, `clear()` cases for the five fields. New cases: `save(navidrome fields only)` doesn't touch heerr fields; partial-field save updates just the named key; full `ServerProfile` JSON round-trip; legacy heerr-only profile JSON deserialises with `null` navidrome fields.
- Modified: `android/app/lib/screens/servers_screen.dart` — added a divider + "Navidrome (optional)" section with three new `TextFormField`s (URL with `_validateOptionalUrl` that accepts empty, username, password obscured). Test button layout went from `Save | Test connection` (one row) to `Save (full width)` + `Test heerr | Test Navidrome` (split row) so three actions fit without cramming. "Test Navidrome" calls `subsonicCall(ping)` against `subsonicDioClient`; missing navidrome fields trip a guard snackbar before the request fires. Both Test buttons activate the profile first so the dio rebuilds with current creds.
- Modified: `android/app/pubspec.yaml` — added `crypto: ^3.0.0` (dart-lang) for the md5 token. No other dep changes.
- Built: `dart run build_runner build --delete-conflicting-outputs` regenerated `lib/api/subsonic_client.g.dart` (and `lib/providers/settings.g.dart` for the typedef change).
- Verification: `flutter analyze` clean (the 3 pre-existing infos in `queue_screen.dart` predate H1). `flutter test` 135/135 pass (was 115 before H1 — +20 new tests across subsonic_client_test, servers_screen_test, and the extended settings_test).
- **ADR appended:** "Stream via Navidrome Subsonic API, not via heerr backend" (`DECISIONLOG.md`).
- `pubspec.yaml` version bump: `0.1.0+1` → `0.3.0+1` (per ROADMAP_STREAMER conventions: `0.3.x` for H/I milestones; the in-tree version had stayed at 0.1.0 through the prior post-G1 work despite the CHANGELOG references to "v0.2.0", so this jump straight to 0.3 reconciles the pubspec with the roadmap's milestone-letter cadence).

## 2026-06-11 — H2: Subsonic models + read-only library providers

Second milestone of `ROADMAP_STREAMER.md`. Adds the freezed models for every Subsonic response shape the streaming feature consumes plus six Riverpod providers wrapping the read endpoints. Nothing is wired to UI yet — that lands at I1 (Library tab).

- **Subsonic models** (`android/app/lib/models/subsonic/`):
  - `song.dart` — `id`, `title`, `artist?`, `artistId?`, `album?`, `albumId?`, `coverArt?`, `duration?`, `track?`, `year?`, `genre?`, `suffix?`, `contentType?`, `bitRate?`, `path?`, `isVideo?`, `size?`.
  - `artist.dart` — `id`, `name`, `coverArt?`, `albumCount?`, `artistImageUrl?`, plus a `@Default(<Album>[]) album` field populated only by `getArtist(id)` (empty when the artist comes from a `getArtists` index entry).
  - `artist_index.dart` — alphabetical bucket from `getArtists` (`name` + `@Default(<Artist>[]) artist`).
  - `album.dart` — album metadata (`id`, `name`, `artist?`, `artistId?`, `coverArt?`, `songCount?`, `duration?`, `year?`, `genre?`, `created?`) plus `@Default(<Song>[]) song` populated only by `getAlbum(id)`.
  - `playlist.dart` — playlist metadata (`id`, `name`, `comment?`, `owner?`, `public?`, `songCount?`, `duration?`, `created?`, `changed?`, `coverArt?`) plus `@Default(<Song>[]) entry` populated only by `getPlaylist(id)`. `created` / `changed` kept as `String` rather than `DateTime` so a malformed value from a non-Navidrome Subsonic server doesn't break parsing.
  - `search_result3.dart` — `@Default(<Artist>[]) artist`, `@Default(<Album>[]) album`, `@Default(<Song>[]) song`. Empty sections that Subsonic omits get the defaults automatically.
- **Wire-format opt-out:** project-global `build.yaml` applies `field_rename: snake` to every json_serializable model (FastAPI backend uses snake_case). Subsonic is natively camelCase, so every multi-word field in `models/subsonic/*` carries an explicit `@JsonKey(name: 'camelCase')` annotation. A dedicated test in `subsonic_models_test.dart` guards against a future contributor dropping these annotations: it builds a `Song` from a camelCase JSON map and asserts the round-trip preserves `artistId` / `albumId` / `coverArt` / `contentType` / `bitRate` / `isVideo` verbatim.
- **Library providers** (`android/app/lib/providers/library/`):
  - `library_artists.dart` — `libraryArtistsProvider` → `Future<List<ArtistIndex>>` via `getArtists.view`. Tolerates an empty library (no `artists` key) by returning `<ArtistIndex>[]`.
  - `library_artist.dart` — `libraryArtistProvider(id)` family → `Future<Artist>` via `getArtist.view?id=…`.
  - `library_album.dart` — `libraryAlbumProvider(id)` family → `Future<Album>` via `getAlbum.view?id=…`.
  - `library_playlists.dart` — `libraryPlaylistsProvider` → `Future<List<Playlist>>` via `getPlaylists.view`. Empty-library tolerant.
  - `library_playlist.dart` — `libraryPlaylistProvider(id)` family → `Future<Playlist>` via `getPlaylist.view?id=…`.
  - `library_search.dart` — `librarySearchProvider(query)` family → `Future<SearchResult3>` via `search3.view?query=…`. Debounced 300ms via the existing `searchDebounceProvider`. Empty / whitespace-only queries short-circuit to `const SearchResult3()` without firing a request. In-flight requests are cancelled when the query changes via a `CancelToken` tied to `ref.onDispose` (mirrors the existing YouTube-Music `searchResultsProvider`).
- **Test fixtures** (`android/app/test/fixtures/subsonic/`): six synthetic-but-realistic JSON payloads (`get_artists.json`, `get_artist.json`, `get_album.json`, `get_playlists.json`, `get_playlist.json`, `search3.json`) modelled after the Subsonic API docs and Navidrome's response shape. Fixtures were hand-written rather than captured from the live Navidrome — a real-server capture pass can be added once the implementation is end-to-end smoke-tested at K2, replacing or augmenting these.
- **Tests:**
  - `android/app/test/models/subsonic_models_test.dart` — 9 cases. Round-trip `fromJson(toJson(x)) == x` for `Song`, `ArtistIndex`, `Album` (3 songs), `Artist` (2 albums), `Playlist` (2 entries), `SearchResult3` (all three sections); empty-list-default cases for `album.song`, `artist.album`, `search.{artist,album,song}`; explicit camelCase-survival test for `Song`'s 6 annotated fields.
  - `android/app/test/providers/library/library_providers_test.dart` — 13 cases across 6 providers. Each provider: asserts the correct request path + query params; parses fixture payloads to the expected model. `libraryArtistsProvider` + `libraryPlaylistsProvider` empty-library tolerance. `libraryArtistProvider` Subsonic-70 → `NotFoundError`. `librarySearchProvider`: empty query short-circuits without a request; whitespace-only short-circuits; non-empty hits `/rest/search3.view` with `query=…`; missing `searchResult3` key → empty result. The two query-firing librarySearch cases add an explicit `c.listen` to keep the auto-dispose provider alive across the debounce-await (caught a `NetworkError` from the onDispose-bound `CancelToken` firing mid-request when no listener was attached — same trap the existing `searchResultsProvider` tests document).
- **Test gate:** `dart run build_runner build --delete-conflicting-outputs` clean (12 new `.freezed.dart` + `.g.dart` outputs). `flutter analyze` clean (the 3 pre-existing `queue_screen.dart` infos predate H1). `flutter test` 159/159 pass (was 135 after H1 → +24 new H2 tests).
- `pubspec.yaml` version bump: `0.3.0+1` → `0.3.1+2` (incremental within the `0.3.x` H/I band).

## 2026-06-11 — I1: Library tab + Artists / Albums / Playlists screens (+ drop Search tab)

First milestone of Phase I (Library tab + combined search) and the largest UI change since A2 (the original shell scaffold). Replaces the standalone YouTube-Music Search tab with a Library tab driven by Subsonic. Bottom nav goes from `Search · Queue · Settings` to `Library · Queue · Settings`. Combined search (library + YouTube Music fallback) is **deferred to I2** — at I1 the Library tab is browse-only with no search field.

- **Bottom nav restructure** (`android/app/lib/router.dart`):
  - `/` is now the Library route (was the Search route). Initial location updated to match.
  - Three nested detail routes added under `/`: `/library/artist/:id`, `/library/album/:id`, `/library/playlist/:id`. Detail screens stay inside the `ShellRoute` so the bottom nav persists when the user drills in (same pattern as `/settings/servers`).
  - `_NavTab` list reduced to three entries (Library / Queue / Settings); Library icon `library_music_outlined` / `library_music`.
  - Selected-index logic switched from exact-path equality to `loc.startsWith('/library')` / `/queue` / `/settings` so nested-route locations keep the right tab highlighted.
  - New `Routes.library{Artist,Album,Playlist}(id)` URL helpers.
- **Removed:** `android/app/lib/screens/search_screen.dart` + `android/app/test/screens/search_screen_test.dart`. The functionality folds into I2's combined-search. `lib/providers/search.dart`, `lib/providers/download.dart`, and `lib/widgets/result_tile.dart` survive — they're rehomed inside the Library tab's search affordance at I2 (with `searchResultsProvider` to be renamed `ytmSearchProvider` then).
- **New endpoint + provider:** `getAlbumList2` added to `subsonic_endpoints.dart`; `lib/providers/library/library_albums.dart` (`libraryAlbumsProvider`) hits `getAlbumList2.view?type=alphabeticalByName&size=500` for the Library tab's Albums sub-tab. H2 created the per-album/per-artist providers but no flat global-album list — needed for the Albums sub-tab.
- **New widget + cover-art helper:**
  - `android/app/lib/api/subsonic_client.dart` gains a public `buildSubsonicCoverArtUrl({baseUrl, username, password, coverArtId, size?, saltGenerator?})` helper that composes a `/rest/getCoverArt.view?...` URL with auth params (u/s/t=md5(password+salt)/v/c) embedded as query string. Needed because `Image.network` doesn't flow through the dio interceptor — the auth params have to be baked into the URL directly. The salt rotates per call, which defeats Flutter's URL-keyed image cache for now; cover-art caching is K1+ optimisation.
  - `android/app/lib/widgets/library_cover_art.dart` — `LibraryCoverArt` ConsumerWidget. Reads settings, composes the URL, renders `Image.network`. Falls back to a neutral music-note placeholder when (a) no `coverArtId`, (b) navidrome creds not configured, or (c) the network fetch errors out.
  - `android/app/lib/widgets/library_result_tile.dart` — variant of `ResultTile` for library entries (artists / albums / playlists). Always tappable (no "already-downloaded" dim). Optional trailing play icon (`trailingPlay: true`) as the "queue all" affordance — `onPlay` is wired at J2; for I1 it's a no-op placeholder.
- **New screens** (`android/app/lib/screens/library/`):
  - `library_screen.dart` — `DefaultTabController` with three sub-tabs (Artists / Albums / Playlists). Each sub-tab is a `ConsumerWidget` watching its provider. Artists tab groups by `ArtistIndex` letter (section header per letter). Albums + Playlists are flat lists.
  - `artist_detail_screen.dart` — AppBar shows the artist name; body is the album list (tap → `/library/album/:id`).
  - `album_detail_screen.dart` — AppBar shows the album name with a "Play all" action (no-op placeholder for I1, wired at J2). Body is a header row (cover via `LibraryCoverArt(size: 120)` + name + artist + year) followed by the song list (track number, title, m:ss duration). Song-tap is no-op for I1 — wires at J2.
  - `playlist_detail_screen.dart` — mirrors `album_detail_screen.dart` shape: AppBar + Play-all + header + entry list. Each entry uses a 40px `LibraryCoverArt` leading.
  - All screens use the existing `SkeletonList` / `EmptyState` widgets for loading / empty rendering.
- **Tests:**
  - `test/router_test.dart` — rewritten for the new layout: boots on Library, asserts three nav destinations, asserts the Artists / Albums / Playlists sub-tabs render in the Library AppBar's TabBar, Queue / Settings navigation, Library round-trip, M3-dark theme. Added a unit test for the `Routes.libraryArtist/Album/Playlist(id)` URL shapes.
  - `test/screens/library/library_screen_test.dart` — 8 cases. Artists tab: loading / empty / data (asserts group letter + tile) / error. Albums sub-tab swipe → data / empty. Playlists sub-tab swipe → data / empty. Non-focal tabs stubbed with empty-data so they don't fire real requests.
  - `test/screens/library/{artist,album,playlist}_detail_screen_test.dart` — 4 cases each (loading / empty / data / error). Album-detail's data test asserts both header content (artist, year) and a song-tile m:ss conversion (`467s → 7:47`, `108s → 1:48`).
- **Test gate:** `dart run build_runner build --delete-conflicting-outputs` clean (1 new `.g.dart` for the new provider). `flutter analyze` clean (the 3 pre-existing `queue_screen.dart` infos predate H1). `flutter test` **167/167** pass (was 159 after H2: +20 new I1 tests, –12 from the deleted `search_screen_test.dart` for a net `+8` — actual count is 159 + 8 = 167).
- **ADR appended:** "Combined library + YouTube Music search; standalone Search tab removed" (`DECISIONLOG.md`).
- `pubspec.yaml` version bump: `0.3.1+2` → `0.3.2+3`.

## 2026-06-11 — I2: Combined search inside Library tab (library-first + YT fallback + reactive promotion)

Second I-phase milestone. Wires the search field into the Library tab AppBar and orchestrates two sources — Subsonic `search3` (local library) and the existing heerr-backend YouTube-Music search — behind a single combined-search provider. The YT half is gated: it auto-fires when the library half comes back empty (so the user instantly sees a downloadable fallback) and is manual-button-gated otherwise (so non-empty library searches don't burn YouTube-Music quota on every keystroke). Reactive promotion closes the loop: when a download completes, the library half re-fetches after a 60s Navidrome-reindex grace, and the song auto-moves from the YT section into the library section.

- **YouTube-Music search provider refactor** (`android/app/lib/providers/search.dart`):
  - `searchResultsProvider` renamed to **`ytmSearchProvider`** and converted from a singleton (reading state from `searchQueryProvider`) to a **family keyed by `String query`**. Lets the combined-search orchestrator pull a specific query's YT result by family-key rather than via a shared SearchQuery notifier. Content type is fixed to `ContentType.song` (no longer toggleable — the Library combined search is song-focused; if we ever want album/playlist YT search inside Library, lift the type into the family key).
  - `SearchQuery` + `SearchQueryState` notifier deleted. Sole consumer was the now-removed standalone Search tab.
  - `searchDebounceProvider` (300ms default) kept — still wraps both source providers' debounce.
- **New `librarySearchQueryProvider`** (`android/app/lib/providers/library/library_search_query.dart`):
  - `@Riverpod(keepAlive: true)` notifier holding the Library search field's current text. Set via `set(String)`, cleared via `clear()`. Survives tab switches (Library → Queue → Library) so a half-typed query isn't dropped.
- **New `combinedSearchProvider(query)`** (`android/app/lib/providers/library/combined_search.dart`):
  - Family-keyed `@riverpod` (auto-dispose) returning a `CombinedSearchResult` struct (`{query, library: AsyncValue<SearchResult3>, ytm: AsyncValue<SearchResponse>?}`).
  - Always `ref.watch`'s `librarySearchProvider(query)`. Watches `ytmSearchProvider(query)` only when **(a)** the library half resolved as empty, OR **(b)** the user has tapped "Search more on YouTube Music" for this query (tracked in the new `ytmManualTriggerProvider`, a keepAlive `Set<String>`).
  - **Reactive promotion:** seeds a `Set<String> seenDoneJobIds` from `ref.read(queueProvider)` at build time, then `ref.listen<AsyncValue<QueueResponse>>(queueProvider, ...)` for new `state == done` transitions. Each newly-done job schedules a `Timer(kReindexGrace, () => ref.invalidate(librarySearchProvider(query)))`. All pending timers are cancelled via `ref.onDispose`. Re-seeding existing done jobs (rather than blindly invalidating on the first `ref.listen` callback) prevents the orchestrator from firing 60s timers for downloads that finished long before the user even searched.
  - Reindex grace is exposed as `reindexGraceProvider` (default 60s) so tests can shrink it.
- **Library AppBar + combined results screen** (`android/app/lib/screens/library/library_screen.dart`):
  - Converted to `ConsumerStatefulWidget` to hold a `TextEditingController` and a `_searching` flag.
  - Idle Library shows the original three sub-tabs (Artists / Albums / Playlists) with a new search-icon action in the AppBar.
  - Tapping the search icon swaps the AppBar title for a `TextField` (autofocus + close-icon clear). The body becomes the combined-results view, driven by `combinedSearchProvider(query)`.
  - Combined-results layout:
    - **"In your library"** section: when library has hits, renders three subsections (Songs / Albums / Artists) using `LibraryResultTile`. Library Song tap pushes the song's album route (J2 will replace this with a play call); Album/Artist tiles tap-navigate to their existing detail screens. When library is empty, renders "Not in your library." copy.
    - **"On YouTube Music"** section: renders a `FilledButton.tonal` ("Search more on YouTube Music") when library has results AND the user hasn't manually triggered yet. When auto-fired (empty library) or manually triggered, renders the YT results using the existing `ResultTile` widget; tile tap → `downloadDispatcherProvider.dispatch(...)` + snackbar.
  - Both library + YT empty (auto-fire case) → single `EmptyState` ("No matches"). Library loading → `SkeletonList`. Library error → centered error text.
  - Back arrow in search-mode AppBar exits search-mode and clears the query.
- **Tests:**
  - `test/providers/search_test.dart` — rewritten for the new `ytmSearchProvider(query)` family. 5 cases: empty / whitespace short-circuit (no network), non-empty POSTs `/search` with correct body, two different family keys produce independent requests, dispose mid-debounce cancels the request. SearchQuery state tests deleted (notifier no longer exists).
  - `test/providers/library/library_search_query_test.dart` — 3 cases (initial empty, set updates, clear resets).
  - `test/providers/library/combined_search_test.dart` — 8 cases across two groups:
    - `ytmManualTriggerProvider`: starts empty, trigger / isTriggered, whitespace ignored.
    - `combinedSearchProvider` auto-fire/manual: library has results → no auto YT (button shown); empty library → YT auto-fires; manual trigger fires YT despite library hits; empty/whitespace query never fires YT.
    - `combinedSearchProvider` reactive promotion: new done transition → librarySearch invalidates after grace; seed done jobs at subscription time do NOT schedule a promotion (false-positive guard).
    - Uses a `_SplitAdapter` that routes by URL path (`search3.view` → Subsonic responder, everything else → heerr responder), a `_StubQueue` notifier that lets tests emit `AsyncValue<QueueResponse>` transitions, and a `_settle(c, query, pred)` polling helper to avoid racing the orchestrator's async reactions.
    - `reindexGraceProvider` overridden to 50ms so each promotion case finishes in <250ms.
  - `test/screens/library/library_screen_test.dart` — original 8 browse-mode cases preserved; 6 new search-mode cases: search icon swaps in TextField; library hits + manual button rendered; tap manual button → YT results render; empty library → YT auto-fires with results; both empty → "No matches" EmptyState; back arrow exits search mode. Added a `_StubQueue` override in `_wrap` so `combinedSearchProvider`'s `ref.read(queueProvider)` doesn't trigger a real `/queue` fetch through the un-overridden `dioClientProvider`.
- **Test gate:** `dart run build_runner build --delete-conflicting-outputs` clean (4 new `.g.dart` outputs for the 4 new providers). `flutter analyze` clean (still the 3 pre-existing `queue_screen.dart` infos; no new warnings). `flutter test` **181/181** pass (was 167 after I1: +5 new ytm_search tests + 3 query tests + 8 combined_search tests + 6 library_screen search-mode tests − 8 deleted SearchQuery / type-toggle / rapid-retype tests for a net `+14`).
- `pubspec.yaml` version bump: `0.3.2+3` → `0.3.3+4`.

## 2026-06-11 — J1: Audio playback skeleton (just_audio + audio_service)

First Phase-J milestone. Wires the audio stack: `just_audio` for the decode/buffer/stream, `audio_service` for the Android MediaSession + foreground notification + lock-screen controls, `audio_session` for OS audio-focus. **No UI integration yet** — verification is a temporary "Debug play" FAB on the Library tab that plays the first song of the first album end-to-end. The Now Playing screen + mini-player + library tap-to-play wiring land at J2; the debug FAB is removed there.

- **New deps** (`android/app/pubspec.yaml`):
  - `just_audio: ^0.10.0` (resolved to 0.10.5).
  - `audio_service: ^0.18.0`.
  - `audio_session: ^0.2.0`.
  - `rxdart: ^0.28.0` (already a transitive dep via audio_service; listed explicitly to avoid the `depend_on_referenced_packages` lint on the `Rx.combineLatest2` import inside the handler).
- **AndroidManifest** (`android/app/android/app/src/main/AndroidManifest.xml`):
  - New permissions: `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (required Android 14+), `POST_NOTIFICATIONS` (Android 13+).
  - New `<service>` entry for `com.ryanheise.audioservice.AudioService` with `android:foregroundServiceType="mediaPlayback"` and the `MediaBrowserService` intent-filter so the audio_service plugin can bind it.
  - New `<receiver>` entry for `com.ryanheise.audioservice.MediaButtonReceiver` so Bluetooth-headset / car-infotainment / wired-remote media buttons reach the handler.
- **Stream URL helper** (`android/app/lib/api/subsonic_client.dart`):
  - New public `buildSubsonicStreamUrl({baseUrl, username, password, songId, saltGenerator?})` — composes `/rest/stream.view?id=…&u=…&s=…&t=md5(password+salt)&v=1.16.1&c=heerr`. `just_audio.AudioPlayer` fetches the audio URL directly (no dio interceptor on that path), so the auth params have to live in the URL — same constraint as cover art.
- **MediaItem conversion** (`android/app/lib/player/song_to_media_item.dart`):
  - Pure function `songToMediaItem({song, navidromeBaseUrl, …})` → `audio_service.MediaItem`. Sets `id` to the stream URL (that's what `AudioSource.uri` opens), `title` / `artist` / `album` / `duration` straight from the Subsonic Song, `artUri` to the `getCoverArt.view` URL when `coverArt` is set (null otherwise), and stashes the Subsonic song id under `extras['subsonicId']` so J2 can map an active MediaItem back to its library identity.
  - Pure function so it's unit-testable without standing up `just_audio` or `audio_service`'s platform channels.
- **Audio handler** (`android/app/lib/player/heerr_audio_handler.dart`):
  - `class HeerrAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler`. Accepts an optional `AudioPlayer` in the constructor (defaults to `AudioPlayer()`); the injection point exists for J2's tests + future swap-outs but production callers don't pass anything.
  - Wires `player.playbackEventStream` → translates `just_audio.ProcessingState` to `AudioProcessingState`, drives `playbackState` with the platform Media controls (skipToPrevious / play|pause / stop / skipToNext + seek system actions + compact-action indices `[0,1,3]` — skip-prev, play-pause, skip-next).
  - Wires `player.currentIndexStream` → emits the matching `MediaItem` from `queue` so the lock-screen tile + Now Playing always reflect the actually-current song.
  - Queue management uses `just_audio` 0.10's new `setAudioSources(List<AudioSource>)` directly (the older `ConcatenatingAudioSource` is deprecated in 0.10). `updateQueue` replaces the queue + reloads the player at index 0. `addQueueItem` appends + preserves the current position. `playSong(item)` and `playAll(items, {startIndex})` are UI convenience wrappers; `playAll` will be wired to album / playlist "Play all" at J2.
  - Transport methods (`play` / `pause` / `stop` / `seek` / `skipToNext` / `skipToPrevious` / `skipToQueueItem`) delegate to the player. `skipToPrevious` rewinds the current track if there's no previous track in the queue — standard mobile-music-app behaviour.
  - Public `snapshotStream()` returns a `PlayerSnapshot { MediaItem? item, PlaybackState state }` via `Rx.combineLatest2(mediaItem.stream, playbackState.stream, …)`. J2's mini-player + Now Playing screens drive off this single stream.
- **Player providers** (`android/app/lib/player/player_provider.dart`):
  - `@Riverpod(keepAlive: true) HeerrAudioHandler audioHandler(…)` — **throws by default** with an explanatory message. `main()` is responsible for overriding it with the singleton handler from `AudioService.init`. Throwing rather than constructing a fallback ensures we never accidentally spawn a real `just_audio.AudioPlayer` in a test (or before `AudioService.init` has run, which would leave the foreground notification + MediaSession unregistered).
  - `playerSnapshotProvider` (keepAlive) — wraps `handler.snapshotStream()` so any widget that just wants "what's playing now" can `ref.watch` it without caring about the handler API.
  - `currentMediaItemProvider` — `Stream<MediaItem?>` straight from `handler.mediaItem.stream`. Convenience for components that only need the current item (mini-player tile content, e.g.).
- **main.dart**:
  - Made async; calls `WidgetsFlutterBinding.ensureInitialized()`, then `await AudioService.init(builder: HeerrAudioHandler.new, config: AudioServiceConfig(androidNotificationChannelId: 'com.aashish.heerr.audio', androidNotificationChannelName: 'heerr playback', androidNotificationOngoing: true, androidStopForegroundOnPause: false))` before `runApp`.
  - `runApp` wraps `HeerrApp` in a `ProviderScope` with the `audioHandlerProvider.overrideWithValue(handler)` override — this is the override the provider's `UnimplementedError` references.
- **Debug FAB on Library tab** (`android/app/lib/screens/library/library_screen.dart`):
  - `_DebugPlayFirstSongFab` ConsumerWidget added as `floatingActionButton` in browse-mode (search-mode scaffold is unaffected). On tap: reads settings → validates Navidrome creds → reads `libraryAlbumsProvider.future` → first album → `libraryAlbumProvider(id).future` → first song → `songToMediaItem(…)` → `handler.playSong(item)`. Reports each step's failure mode via a distinct snackbar (creds missing, library empty, first album has no songs, ApiError surface). Removed at J2 once the real tap-to-play wiring lands on song tiles.
- **Tests:**
  - `test/player/song_to_media_item_test.dart` — 6 cases: stream URL contains `id=`/`u=`/`s=`/`t=`/`v=1.16.1`/`c=heerr`, title/artist/album/duration round-trip unchanged, `artUri` set when `coverArt` non-empty, `artUri` null when `coverArt` missing or empty, `duration` null when source has none, `extras['subsonicId']` carries the Subsonic id for J2's reverse-lookup.
  - **No handler unit tests at J1.** `just_audio.AudioPlayer` is platform-channel-backed; mocking it requires non-trivial scaffolding (subclassing or `audio_service`'s test harness) and the J1 deliverable is verified end-to-end on the device, not in a unit test. The `songToMediaItem` tests cover the only pure logic in the player layer; handler queue-management tests land at J2 alongside Now Playing widget tests.
- **Test gate:** `dart run build_runner build --delete-conflicting-outputs` clean (3 new `.g.dart` outputs for the new player providers). `flutter analyze` clean (still the 3 pre-existing `queue_screen.dart` infos). `flutter test` **187/187** pass (was 181 + 6 new song_to_media_item tests). `flutter build apk --debug` succeeds — validates the AndroidManifest changes don't break the Android compile (the audio_service plugin's KGP warning is an upstream issue and doesn't fail the build).
- **On-device verification (manual; the J1 gate):** on the Pixel 7 with a populated Navidrome library:
  1. Tap "Debug play" FAB → snackbar "Playing: <song title>".
  2. Foreground notification renders with title + artist + play/pause/skip controls.
  3. Lock the phone → playback continues; lock-screen controls work.
  4. Tap pause from notification → audio pauses + the notification's play/pause toggle flips.
- `pubspec.yaml` version bump: `0.3.3+4` → `0.4.0+5` (J phase opens the `0.4.x` band per the roadmap's version scheme).

## 2026-06-11 — J1 follow-up: AudioServiceFragmentActivity + on-device smoke pass

Post-J1-merge on-device test reproduced `PlatformException(The Activity class declared in your AndroidManifest.xml is wrong or has not provided the correct FlutterEngine...)` on app start. Root cause: the host Activity (`MainActivity : FlutterActivity`) was constructing its own `FlutterEngine`, while the `audio_service` plugin's `onAttachedToActivity` looks up the engine cached under id `"audio_service_engine"` (see `~/.pub-cache/hosted/pub.dev/audio_service-0.18.18/android/src/main/java/com/ryanheise/audioservice/AudioServicePlugin.java:315`). The two engines have different `BinaryMessenger`s → the plugin trips its `wrongEngineDetected` guard during `AudioService.init` → `PlatformException`.

- **`android/app/android/app/src/main/kotlin/com/aashish/heerr/MainActivity.kt`**: now extends `com.ryanheise.audioservice.AudioServiceFragmentActivity` (provided by the audio_service package). That base class overrides `provideFlutterEngine`, `getCachedEngineId`, and `shouldDestroyEngineWithHost` to share the plugin's cached engine — verified against the upstream source at `~/.pub-cache/hosted/pub.dev/audio_service-0.18.18/android/src/main/java/com/ryanheise/audioservice/AudioServiceFragmentActivity.java`. No AndroidManifest change required — `.MainActivity` still resolves to the same class.
- **`android/app/lib/main.dart`**: flipped `androidStopForegroundOnPause: false` → `true`. The audio_service plugin asserts `stopForegroundOnPause == true` whenever `notificationOngoing == true` (channel-ongoing + non-stoppable notification would leak the foreground service). Doc comments above `main()` trimmed.
- **`android/app/lib/player/player_provider.dart`** + generated `.g.dart`: doc-comment tidy-up only — semantics unchanged. The provider still throws by default and is overridden via `audioHandlerProvider.overrideWithValue(handler)` from `main()`.
- **On-device smoke (Pixel 7, populated Navidrome library) — all four J1 acceptance checks pass:**
  1. App launches without `PlatformException`.
  2. "Debug play" FAB → audio plays through device speaker.
  3. Foreground notification with play / pause / skip / stop controls renders and pause toggles correctly.
  4. Lock-screen media controls render (Android per-channel lock-screen visibility had to be enabled in system Settings — not a code config, surfaced for future docs).
- **Known limitation, by design:** the notification's "skip forward" button is a no-op at J1 because the debug FAB only queues a single song. Real album / playlist queueing lands at J2.
- **No test changes.** This is a platform-channel + base-class fix; covered by manual device smoke, not unit tests.

## 2026-06-11 — J2: Now Playing + mini-player + library playback wiring

Second Phase-J milestone. Wires every "tap a thing in the library → audio plays" path the v1 UI needs: library Song tile, library Album play icon, library Playlist play icon, library Artist's album play icon, Album / Playlist detail-screen song-row tap and "Play all" AppBar icon, Queue tab's done-job play action. Adds the persistent mini-player above the bottom nav and the full-screen Now Playing surface at `/player`. Removes the J1 debug FAB.

- **New: `android/app/lib/screens/player/now_playing_screen.dart`.** Full-screen Now Playing built around three Riverpod streams:
  - `playerSnapshotProvider` for current `MediaItem` + transport flags;
  - `playerQueueProvider` for the bottom queue list;
  - `currentMediaItemProvider` for highlighting the active row in the queue.
  - Cover art (240px square) via `Image.network(item.artUri)` with a music-note fallback. Title + artist below.
  - Scrubber: a `Slider` whose `value` is the snapshot's `state.position` (extrapolated from `updatePosition + elapsed * speed` by audio_service). A 250ms periodic `Timer` triggers `setState` so the slider animates between PlaybackState emissions, which only fire on play / pause / seek / buffer events. While the user is dragging the thumb, the slider value is held to a local `_scrubOverride` so the live position can't fight the drag; on `onChangeEnd` we call `handler.seek(...)` once and clear the override.
  - Transport row: skip-prev, play/pause (centre, large), skip-next. Each `onPressed` does `ref.read(audioHandlerProvider).<method>()` — the handler is read inside the callback (not at build time) so widget tests that don't override `audioHandlerProvider` still render correctly when the buttons aren't tapped.
  - Queue list at the bottom: `ListTile` per `MediaItem`. The current item gets the `Icons.equalizer` leading icon + bold title; tapping any row calls `handler.skipToQueueItem(i)`.
- **New: `android/app/lib/widgets/mini_player.dart`.** Persistent media bar shown above the `NavigationBar` via `_ShellScaffold`. ConsumerWidget watching `playerSnapshotProvider`. When `snap.valueOrNull?.item == null` (nothing queued, snapshot still loading, or `audioHandlerProvider` un-overridden in tests), returns `SizedBox.shrink()` — zero height — so the bottom nav layout is identical to before J2 when the player is idle. When an item is present, renders a 56px tall Material bar: 40x40 cover thumb, title + artist column, trailing play/pause IconButton. Tap on the bar (anywhere not on the play/pause button) pushes `/player`.
- **New: `android/app/lib/player/playback_actions.dart`.** Top-level functions consumed by every "play this" surface so the cred-resolution + snackbar logic isn't duplicated:
  - `playSongFromSubsonic(ref, context, Song)` — single-song queue + play.
  - `playAllSongsFromSubsonic(ref, context, List<Song>, {startIndex})` — replace queue + play; used by album / playlist song-row tap and "Play all".
  - `playAlbumFromSubsonic(ref, context, albumId)` — fetch album via `libraryAlbumProvider(id).future` then call `playAllSongsFromSubsonic` (used by Artist detail's per-album play icon and Library search Album play icon).
  - `playPlaylistFromSubsonic(ref, context, playlistId)` — same shape, via `libraryPlaylistProvider`.
  - `playJobDoneFromSubsonic(ref, context, JobView)` — derive search query from `outputPath` basename (extension stripped) or `displayName` fallback; call Subsonic `search3` once; if exactly one `Song` match, `playSongFromSubsonic`; else snackbar "Not in library yet — try again in a minute." Single-match guard prevents picking the wrong track when Subsonic returns multiple title hits.
  - All five surface failures via uniform snackbars: "Navidrome creds missing" when settings are blank, `ApiError.message` for Subsonic-side errors, generic "Play failed" for everything else.
- **`android/app/lib/player/player_provider.dart`:** new `playerQueueProvider` (`Stream<List<MediaItem>>`) backed by `handler.queue.stream`. Existing `audioHandlerProvider` / `playerSnapshotProvider` / `currentMediaItemProvider` unchanged.
- **`android/app/lib/router.dart`:**
  - New top-level route `/player` (outside `ShellRoute`, like `/job/:id`) so Now Playing pushes full-screen above the bottom nav with a normal back button.
  - `_ShellScaffold.bottomNavigationBar` is now a `Column(mainAxisSize: MainAxisSize.min, …)` containing `MiniPlayer()` above the `NavigationBar`. The mini-player hides itself, so when nothing is queued the nav looks identical to pre-J2.
- **Library screen wiring (`android/app/lib/screens/library/library_screen.dart`):**
  - Browse-mode Albums list: `LibraryResultTile.onPlay` wired to `playAlbumFromSubsonic`. Songs aren't directly clickable from the browse tabs — that flow is via the search field or by drilling into an album.
  - Browse-mode Playlists list: `onPlay` → `playPlaylistFromSubsonic`.
  - Search-mode library section: Song tiles → `playSongFromSubsonic`; Album tiles → `onPlay = playAlbumFromSubsonic`; Artist tiles unchanged (navigate to detail, no direct play).
  - **`_DebugPlayFirstSongFab` removed**, along with its imports of `audio_service`, `playerProvider`, `songToMediaItem`, `Settings`, `libraryAlbumsProvider`, `libraryAlbumProvider` — the FAB was the sole consumer of those imports in this file.
- **Album detail (`album_detail_screen.dart`):** AppBar "Play all" → `playAllSongsFromSubsonic(album.song)`. Song row tap → `playAllSongsFromSubsonic(album.song, startIndex: i)` (starting at the tapped song; the rest of the album queues up after it).
- **Playlist detail (`playlist_detail_screen.dart`):** same shape, with `playlist.entry` as the song list.
- **Artist detail (`artist_detail_screen.dart`):** each `LibraryResultTile`'s `onPlay` → `playAlbumFromSubsonic(album.id)`. Tap on the row body still navigates to album detail.
- **Queue tab (`queue_screen.dart`):**
  - Per-job play action: when `job.state == JobState.done`, render `Icons.play_arrow` in the trailing slot before the `StatusPill`. Tap → `playJobDoneFromSubsonic(job)`.
  - **Side bug fix:** `_isActive` previously compared `job.state` (enum `JobState`) to string literals `'queued'` / `'running'`, which is always false. The active-job background tint never rendered. Fixed to `job.state == JobState.queued || job.state == JobState.running`. Made `_JobTile` a `ConsumerWidget` so the play action can `ref.read`.
  - Replaced the `Container(color: …)` wrapper with `ListTile.tileColor` to silence the Material 3 "ListTile background color or ink splashes may be invisible" assertion — the assertion was dormant pre-fix because `_isActive` was always false.
  - Also flipped the deprecated `Color.withOpacity(0.15)` → `Color.withValues(alpha: 0.15)` in the same line — clears the only `flutter analyze` info on the tree.
- **Tests added:**
  - `test/widgets/mini_player_test.dart` (6 cases): hidden when no item, hidden when stream is loading, hidden when `audioHandlerProvider` isn't overridden (router-test compat), renders title + artist + play icon when paused, renders pause icon when playing, tap pushes `/player`.
  - `test/screens/player/now_playing_screen_test.dart` (7 cases): no item → "Nothing is playing", paused state renders play icon + duration, playing state renders pause icon, queue list renders both tracks + marks the current one with `Icons.equalizer`, empty queue → "Queue is empty", scrubber slider max equals duration in ms, loading stream → CircularProgressIndicator. The queue-marker test uses `tester.view.physicalSize = Size(1080, 2400)` to give the queue list enough vertical room past the cover art + scrubber + transport stack (default 800×600 test viewport doesn't fit both queue rows).
- **Test gate:** `dart run build_runner build --delete-conflicting-outputs` clean (1 new `.g.dart` output for `playerQueueProvider`). `flutter analyze` clean — **zero** issues (was 1 info pre-J2; the `withOpacity` cleanup eliminated it). `flutter test` **200/200** pass (was 187 + 6 mini-player + 7 now-playing = +13).
- `pubspec.yaml` version bump: `0.4.0+5` → `0.4.1+6`.
- **On-device verification deferred to K2 smoke** (alongside the J2-touched paths): tap library song → audio plays + mini-player appears across all three tabs; tap mini-player → `/player` opens with cover/title/artist/scrubber/transport/queue; back → mini-player still present; lock-screen controls work; scrubber moves in real time; skip-next plays the next song; tap a done queue job → audio plays.

## 2026-06-11 — J2 follow-up: queue done-job play prefers displayName over basename

User-reported regression: tapping the play icon on a `done` queue tile always surfaced "Not in library yet — try again in a minute," even for songs already in Navidrome (and findable via the Library search field). Root cause: `playJobDoneFromSubsonic` derived its `search3` query from the **filesystem basename** (extension stripped). Filenames can include track prefixes (`01 - Title.mp3`), accent stripping, or other backend-side sanitisation that Subsonic's tokenizer can't reconcile with the indexed song title. Compounding it, the code required `result.song.length == 1` exactly — even when the title was indexed, Subsonic's fuzzy matcher returned multiple hits, tripping the guard.

- **`android/app/lib/player/playback_actions.dart`:** rewrote `playJobDoneFromSubsonic` around a candidate list. `_jobSearchCandidates(job)` returns `[displayName, basename-without-extension]` (de-duped, empties dropped). For each candidate we hit `search3` once and accept the first `Song` hit. The strict `length == 1` guard is gone — Subsonic returns results ranked by relevance, so the first hit is the user's intent. Only when **every** candidate yields zero hits do we surface "Not in library yet."
- **On-device:** verified by user — done jobs now play correctly, including older ones that previously always failed.
- **No test changes**: this path didn't have unit tests at J2 (handler / Subsonic-wire integration), and the fix is verified by on-device smoke. Adding a `_FakeAdapter`-based test for `playJobDoneFromSubsonic`'s candidate ordering is in scope for K1 (tracked there).

## 2026-06-11 — K1: Subsonic error UX + Now Playing palette + lifecycle polish

Final polish milestone before the K2 e2e smoke. Three independent threads:
1. Distinct Subsonic-side `ApiError` variants so the snackbar copy points the user at the right config screen (Navidrome creds, not the heerr bearer token).
2. Cover-art dominant-colour tint on the Now Playing surface.
3. Pause `/queue` polling while Now Playing is the foreground route — saves a request every 3s and reduces Navidrome chatter on the device.

### Error UX
- **`android/app/lib/api/api_error.dart`:** two new sealed-class variants.
  - `NavidromeAuthError extends ApiError` — message: `"wrong Navidrome username or password — check Settings"`. Distinct from `UnauthorizedError` (heerr bearer token) so the snackbar copy doesn't confuse the user about which credential is wrong.
  - `NavidromeServerError extends ApiError { final int code; }` — message: `"Navidrome server error: <code> [<detail>]"`. Distinct from `HttpStatusError` because the wire-level HTTP status is `200` (Subsonic puts failures inside the envelope), so an "HTTP 200: …" surface would be misleading.
- **`android/app/lib/api/subsonic_client.dart`:** `mapSubsonicErrorToApiError` now returns `NavidromeAuthError` for Subsonic 40/41 and `NavidromeServerError` for the default branch (was `UnauthorizedError` and `HttpStatusError`).
- **`android/app/lib/widgets/error_snackbar.dart`:** new switch cases for the two variants. `showApiError`'s 401-redirect logic gets a sibling branch: `NavidromeAuthError` redirects to `/settings/servers` (where Navidrome creds live), not `/settings` (heerr bearer token).
- **Tests:**
  - `test/widgets/error_snackbar_test.dart` (+4 cases): NavidromeAuthError copy, NavidromeServerError with detail, NavidromeServerError without detail, NavidromeAuthError redirect to `/settings/servers`.
  - `test/api/subsonic_client_test.dart` (3 case updates): the 40 / 41 / "unknown code" tests now assert against `NavidromeAuthError` / `NavidromeServerError` instead of `UnauthorizedError` / `HttpStatusError`.
  - `test/screens/servers_screen_test.dart` (1 case update): the "Test Navidrome with bad creds" snackbar copy assertion now targets `"wrong Navidrome username or password — check Settings"`.

### Palette tint
- New dep `palette_generator: ^0.3.0` in `pubspec.yaml`.
- **`android/app/lib/utils/palette.dart`** (new): `Future<Color?> dominantColorFor(Uri? artUri)`. Uses `PaletteGenerator.fromImageProvider(NetworkImage(artUri), size: 80x80, maximumColorCount: 12)`. Preference order is `vibrantColor → dominantColor → null`. Wraps the call in try/catch — any failure (no URL, 404, decode error, no usable swatch) returns null so the screen falls back to the default M3 dark surface. Fail-soft is the right UX here; a broken tint would be worse than no tint.
- **`android/app/lib/screens/player/now_playing_screen.dart`:**
  - `_NowPlayingScreenState` tracks the current `_tintArtUri` and the extracted `_tintColor`. `_maybeRefreshTint(artUri)` kicks off a new extraction when the artUri changes, with a stale-response guard so a slow extraction for a previous track can't override a newer track's tint.
  - `AppBar.backgroundColor` is set to `_tintColor.withValues(alpha: 0.6)` when available (subtle).
  - The body wraps in a new `_TintedBackground` widget that paints a vertical `LinearGradient` from `tint @ 0.45` → `cs.surface @ 0.65`. Top of the screen (AppBar + cover area) carries the tint; bottom (queue list) stays the default surface for legibility.
  - Test-injection seam: `paletteExtractorOverride` is a top-level `@visibleForTesting` `typedef` defaulting to `dominantColorFor`. Tests overwrite it with a deterministic stub `(Uri? _) async => null` (or a specific colour) so widget tests don't hit the network or depend on the `palette_generator` decode pipeline.

### Lifecycle (queue polling pause)
- **`android/app/lib/screens/player/now_playing_screen.dart`:**
  - `_NowPlayingScreenState` caches the `Queue` notifier in initState (via a `WidgetsBinding.instance.addPostFrameCallback` so the read isn't during the build phase). On the first frame it calls `queueNotifier.pause()`. In `dispose()` it calls the cached `_queueNotifier?.resume()`. **Cached** because Riverpod invalidates `ref` *before* `State.dispose()` runs — reading `ref.read(queueProvider.notifier)` from dispose throws `Bad state: Cannot use "ref" after the widget was disposed`. Capturing the notifier earlier is the supported pattern.
  - `job_status` is intentionally untouched: it's `@riverpod` (auto-dispose, family-keyed by jobId) and only kept alive by the Job Detail screen's `ref.watch`. Navigating to `/player` doesn't tear down the Job Detail screen (it's outside the ShellRoute), but the volume is bounded — at most one job-detail screen is in the back-stack at a time and the polling stops as soon as the job hits a terminal state. Pausing it from Now Playing would require similar notifier-caching plumbing per active job-detail screen and isn't worth the complexity for v1.
- **Tests:**
  - `test/screens/player/now_playing_screen_test.dart`: new `_StubQueue` (subclass of `Queue`) that increments static `_pauseCalls` / `_resumeCalls` counters on `pause()` / `resume()`. New lifecycle test pumps `NowPlayingScreen` inside a `ValueListenableBuilder` so the ProviderScope stays alive when the screen is unmounted; asserts `_pauseCalls == 1` after mount, `_resumeCalls == 1` after unmount.
  - +2 palette test cases: gradient is painted when extractor returns a colour; no crash when extractor returns null. `setUp` resets the static counters + sets the extractor stub to `(_) async => null` (no-tint default); `tearDown` restores the production extractor.

### Test gate + version
- `dart run build_runner build --delete-conflicting-outputs`: not re-run (no annotation changes).
- `flutter analyze` clean.
- `flutter test` **207/207** pass (was 200 + 4 new error-snackbar + 3 NowPlaying = +7; net is **+7**).
- `pubspec.yaml` version bump: `0.4.1+6` → `0.4.2+7`.
- On-device verification deferred to K2 (the e2e smoke milestone) — bad-creds snackbar, Now Playing tint on a colourful album cover, queue-poll pause check via network log.

## 2026-06-11 — mini-player redesign + snackbar duration polish (user-driven UX tweak)

Two unrelated UX changes driven by on-device feedback after the K1 install. Not a roadmap milestone — pure polish.

### Mini-player redesign (`android/app/lib/widgets/mini_player.dart`)
- Was: full-bleed dark `Material(color: cs.surfaceContainerHigh)` flush against the nav bar, indistinct from the app background.
- Now: floating pill above the nav bar — 98% screen width (`FractionallySizedBox(widthFactor: 0.98)`), `BorderRadius.circular(9)`, 4/6 px vertical padding so it doesn't touch the `NavigationBar`.
- Background colour is the **dominant colour of the current cover art at 55% alpha** (reuses `dominantColorFor` from `lib/utils/palette.dart`). Falls back to the new `heerrGolden` constant while extraction is pending or fails.
- Same stale-response guard pattern as Now Playing — a slow extraction for the previous track can't overwrite the current track's tint.
- `MiniPlayer` converted `ConsumerWidget` → `ConsumerStatefulWidget` to hold the cached `_tintArtUri` + `_tintColor`. Test seam `miniPlayerPaletteExtractorOverride` added (typedef + `@visibleForTesting` mutable variable, same shape as the Now Playing one).
- Title text forced `Colors.white` and artist `white70` so they remain legible on any tint. **Caveat carried forward:** on very bright covers the white-on-tint contrast can be marginal; revisit if it shows up in real use.
- **`android/app/lib/theme.dart`:** new constant `heerrGolden = Color(0xFFD4A857)` — used as the mini-player fallback when palette extraction yields null.

### Snackbar duration polish
- Material default is 4s; UX feedback: too long for both success and error toasts.
- **`android/app/lib/widgets/error_snackbar.dart`:** two top-level constants:
  - `kSnackBarDuration = Duration(seconds: 1)` — success / info default (Connection OK, Saved, Copied, Playing, Queued, "Nothing to play", "Not in library yet", etc.).
  - `kSnackBarErrorDuration = Duration(seconds: 2)` — used only by `buildApiErrorSnackBar` so real failures stay readable.
  - `RateLimitedError` keeps its own clamped duration (`retryAfter.inSeconds.clamp(2, 10)`).
- Every existing `SnackBar` call site received an explicit `duration:` field — no reliance on the Material default anywhere:
  - `lib/widgets/error_snackbar.dart`: 7 cases → `kSnackBarErrorDuration`.
  - `lib/screens/servers_screen.dart`: 4 cases → `kSnackBarDuration`.
  - `lib/screens/job_detail_screen.dart`: 1 case → `kSnackBarDuration`.
  - `lib/screens/library/library_screen.dart`: 1 case → `kSnackBarDuration`.
  - `lib/player/playback_actions.dart`: 6 cases → `kSnackBarDuration` (added `import '../widgets/error_snackbar.dart'`).

### Test gate
- `flutter analyze` clean.
- `flutter test` **207/207** pass (no test changes — `MiniPlayer` tests use null `artUri` so the palette extractor returns null without network calls; snackbar tests don't assert duration).
- On-device: confirmed visible time is now ~1s (success) / ~2s (error), excluding the ~250ms slide-in / slide-out animation envelope.

### Not done in this commit
- `pubspec.yaml` version not bumped — these are polish tweaks between K1 (`0.4.2+7`) and the K2 e2e smoke. Next milestone will carry the bump.
- No `DECISIONLOG.md` entry — neither change reverses a prior decision; both are surface-level UX dials.

## 2026-06-11 — "currently playing" indicator in library lists + secret-field eye toggle

Two more user-driven UX polish items between K1 and K2. Pure visual / form ergonomics; no provider or backend changes.

### `heerrGreen` "this is playing" indicator
- Currently-playing track now highlights itself in every library list it appears in: title turns `heerrGreen` + bold, trailing `Icons.play_arrow` appears in `heerrGreen`.
- Identity match is via `MediaItem.extras['subsonicId']` (the field `songToMediaItem` already stuffs in for J2's reverse-mapping) compared against each row's `Song.id`. Watching `currentMediaItemProvider` per list rebuilds the indicator on every track change with no extra plumbing.
- **`android/app/lib/widgets/library_result_tile.dart`:** new `isCurrentlyPlaying` flag. When true the trailing affordance becomes a `heerrGreen` `Icons.play_arrow` (overrides `trailingPlay`) and the title text gets `color: heerrGreen, fontWeight: FontWeight.w600`.
- **`android/app/lib/screens/library/library_screen.dart`:** `_CombinedResultsBody.build` watches `currentMediaItemProvider`, extracts `subsonicId` from extras, passes `isCurrentlyPlaying: s.id == currentSubsonicId` to each song's `LibraryResultTile` in the search-results "Songs" subsection.
- **`android/app/lib/screens/library/album_detail_screen.dart`:** `_Body.build` watches the same provider. The current track's row gets a `heerrGreen` track number, a `heerrGreen` bold title, and a trailing `heerrGreen` play_arrow. The duration subtitle stays default-styled (legibility).
- **`android/app/lib/screens/library/playlist_detail_screen.dart`:** same treatment, minus the track-number column (playlists don't render one).
- **Not changed:** the Now Playing screen's own queue list — that already has a K1-era `Icons.equalizer` indicator (different glyph, same intent). Leaving as-is so the in-player surface stays visually distinct from the library lists.

### Secret-field eye toggle (`android/app/lib/screens/servers_screen.dart`)
- The "Bearer token" and "Navidrome password" inputs were hidden with `obscureText: true` and no way to verify — a typo would only surface as "Connection failed".
- Added two `bool` state fields (`_tokenObscured`, `_navPassObscured`) defaulting to `true`. Each field now renders a `suffixIcon: IconButton` showing `Icons.visibility_outlined` when hidden and `Icons.visibility_off_outlined` when revealed. Tap flips the bool via `setState`; tooltip flips accordingly ("Show token" / "Hide token", "Show password" / "Hide password"). Default behaviour is unchanged (secret hidden on screen open).

### Test gate
- `flutter analyze` clean.
- `flutter test` **207/207** pass (no test changes — the indicator additions are purely visual on tiles whose existing tests don't assert trailing-icon presence, and the eye-toggle is form ergonomics not covered by widget tests).
- On-device verification deferred to K2.

### Not done in this commit
- `pubspec.yaml` version not bumped — K2 will carry the 1.0.0 bump.

## 2026-06-11 — K2 e2e smoke verified + streaming MVP ships (1.0.0+8)

Closes the streamer roadmap (H1 → K2). Phone is now a first-class find / download / play client against the live home server over Tailscale.

### What was verified
Seven manual on-device steps against the live home server (full log: `android/docs/smoke_streamer.md`):
1. Settings smoke — heerr + Navidrome both reachable; creds persist across app restart.
2. Library browse — artists → albums → songs render with cover art.
3. Playback — tap-to-play, scrubber, skip-next, notification pause/resume, lock-screen controls all work.
4. Combined search (library hit) — library results render, YT auto-fire suppressed, "Search more" button present.
5. Combined search (library miss → YT fallback) — library empty + YT auto-fires + tap YT result → "queued" snackbar.
6. Combined search (manual YT) — "Search more on YouTube Music" button renders YT results below library section.
7. Reactive promotion — done download appears in "In your library" within ~60s without re-typing.

All seven passed.

### Files
- `android/app/pubspec.yaml` — version bump `0.4.2+7` → `1.0.0+8`. First major-version build; marks "streaming MVP" as the shipping baseline.
- `android/docs/ROADMAP_STREAMER.md` — K2 checkbox ticked.
- `android/docs/smoke_streamer.md` (new) — verification log mirroring the G1 smoke style. Captures device, build, per-step pass-with-detail, and the caveats deliberately left out of scope (cache key for rotating salt URL, discontinued `palette_generator`, single-user posture).

### Not done in this commit
- No code change — this is the smoke-verified version-bump commit, nothing else.
- No `DECISIONLOG.md` entry — K2 doesn't change any architectural decision; it confirms the existing ones survived contact with reality.


## 2026-06-13 — M1: Subsonic playlist mutations — endpoints + notifier

Plumbing-only commit. Adds the Subsonic `createPlaylist` / `updatePlaylist` / `deletePlaylist` endpoint constants and a stateless `PlaylistMutations` notifier exposing the six mutation operations (`createPlaylist`, `renamePlaylist`, `deletePlaylist`, `addSongs`, `removeSongsAtIndices`, `reorder`). Nothing wired into the UI yet — that lands at M2 (create / rename / delete) and M3 (add-to-playlist sheet). See `android/docs/ROADMAP_PLAYLISTS.md` for the M1–M5 sequence.

### Endpoints (`android/app/lib/api/subsonic_endpoints.dart`)
- Three new constants: `createPlaylist`, `updatePlaylist`, `deletePlaylist`, each `/rest/<method>.view`. Dartdoc on each captures the multi-param semantics (e.g. `songIdToAdd` repeat-encoded, `songIndexToRemove` 0-based-and-descending) so the call sites at M3/M4 don't have to re-derive them from the Subsonic 1.16.1 spec.

### Notifier (`android/app/lib/providers/library/playlist_mutations.dart` + `.g.dart`)
- `@Riverpod(keepAlive: true) class PlaylistMutations extends _$PlaylistMutations` — stateless (`build()` returns void). `keepAlive` because dialog / snackbar callsites are short-lived but the notifier itself holds no per-instance state worth re-deriving per tap.
- All six methods route through `subsonicDioClientProvider` so the existing `SubsonicAuthInterceptor` injects `u/s/t/v/c/f` — no new `Dio`. Envelope parsing + `ApiError` mapping reuses `subsonicCall`.
- `createPlaylist(name, songIds?)` returns the new `Playlist`; on success invalidates `libraryPlaylistsProvider` so the list re-fetches.
- `renamePlaylist(playlistId, name, makePublic?)` invalidates both `libraryPlaylistsProvider` (name shown in the list) and `libraryPlaylistProvider(playlistId)` (detail).
- `deletePlaylist(playlistId)` invalidates `libraryPlaylistsProvider`.
- `addSongs(playlistId, songIds)` — empty `songIds` is a no-op (no network call). Sends `songIdToAdd` as a `List<String>`, which dio encodes as repeated `songIdToAdd=<id>` pairs. Invalidates list + detail.
- `removeSongsAtIndices(playlistId, indices)` — sorts indices descending before sending so an earlier remove doesn't shift later indices. Empty list = no-op. Invalidates list + detail.
- `reorder(playlistId, newSongIdOrder)` — single `updatePlaylist` call: removes every index `[n-1..0]` and re-adds the songs in the new order via `songIdToAdd`. Navidrome processes removes before adds within one request. Empty input = no-op. Invalidates list + detail.

### Tests (`android/app/test/providers/library/playlist_mutations_test.dart`)
- New file, 14 tests covering all six methods.
- Shared `_RouterAdapter` records every `RequestOptions` and dispatches by path so a single test can prime a read-provider AND fire the mutation through the same stub `Dio`.
- Per-method coverage:
  - `createPlaylist`: happy path (no songs / with songs preserves order), invalidates `libraryPlaylistsProvider` (asserted via second-fetch count after the mutation), Subsonic code-50 → `ForbiddenError` with no invalidation.
  - `renamePlaylist`: happy path invalidates list + detail, `makePublic: true` → `public=true` query param, Subsonic code-70 → `NotFoundError`.
  - `deletePlaylist`: happy path with `id=` query, code-50 → `ForbiddenError`.
  - `addSongs`: `songIdToAdd` multi-param order preserved, invalidates list + detail.
  - `removeSongsAtIndices`: `[1,3,5]` → sent as `5,3,1`, empty indices is a no-op.
  - `reorder`: `['c','a','b']` produces one `updatePlaylist` call with `songIndexToRemove=2,1,0` + `songIdToAdd=c,a,b`; empty `newSongIdOrder` is a no-op.
- Invalidation assertion: a `c.listen(...)` keeps the read provider alive so the mutation's `ref.invalidate` triggers a re-fetch; the test counts adapter hits for `getPlaylists.view` / `getPlaylist.view` before vs after (1 → 2). For the two tests that exercise only the detail provider's path, listening on both providers is necessary to avoid a transient `Future already completed` from the `cacheAware`-wrapped list provider being invalidated without a subscriber during container dispose.

### Test gate + version
- `dart run build_runner build --delete-conflicting-outputs`: clean; one new `.g.dart` written (`playlist_mutations.g.dart`).
- `flutter analyze`: clean.
- `flutter test`: **332/332** pass (was 318 + 14 new = +14 net).
- `pubspec.yaml` version bump: `1.1.0` → `1.2.0-pre+11`. The "-pre" band signals the in-development M1–M4 cycle; M5 will land the release-band `1.2.0+12` bump. (Previous release was `1.1.0` without a build number; the M1 build number `+11` continues the conceptual sequence from `1.0.0+8`.)

### Not done in this commit
- No `DECISIONLOG.md` entry — M1 is plumbing under the architecture pre-approved in `ROADMAP_PLAYLISTS.md`. New ADR lands at M5 covering the full playlist-mutations feature (no offline queue, owner-only edits, delete-all-and-re-add for reorder).
- No UI wiring — M2 lands the Library FAB + playlist-detail overflow menu.
- No `pubspec.yaml` deps added — M1 introduces no new packages.

## 2026-06-13 — M2: Create / rename / delete playlists from the app

UI layer for the M1 mutation notifier. Users can now create a playlist from the Library → Playlists sub-tab (FAB) and rename / delete a playlist they own from the playlist detail screen (AppBar overflow). Ownership is gated on `Playlist.owner == SettingsValue.navidromeUsername` so shared / read-only playlists never expose the destructive affordances.

### New widgets (`android/app/lib/widgets/playlist_dialogs.dart`)
- `CreatePlaylistDialog` (`ConsumerStatefulWidget`) — single auto-focused name field; Create button disabled while trimmed text is empty; submit pops trimmed `String`; cancel pops `null`.
- `RenamePlaylistDialog` — same name-field contract plus a `CheckboxListTile` "Make playlist public" seeded from the current `Playlist.public`. Submit pops a `RenamePlaylistResult` record `({String name, bool makePublic})`; cancel pops `null`.
- Both dialogs are intentionally side-effect-free: they do not touch Riverpod state and they do not call the mutation notifier. The owning screen drives the actual mutation so the dialogs stay easy to widget-test in isolation.
- Static `show(context, ...)` factories wrap the `showDialog<T>` boilerplate so call sites stay terse.

### Library FAB (`android/app/lib/screens/library/library_screen.dart`)
- `_PlaylistsTab` is now wrapped in a transparent `Scaffold` so it can host a `FloatingActionButton.extended` (`Icons.add`, label "New playlist") without disrupting the outer Library scaffold.
- `_PlaylistsTab._onCreatePressed`: opens `CreatePlaylistDialog`, on confirm calls `playlistMutationsProvider.notifier.createPlaylist(name: ...)`, then shows a "Playlist '<name>' created" snackbar via `kSnackBarDuration` and navigates to `Routes.libraryPlaylist(created.id)`.
- Navigation hop uses `GoRouter.maybeOf(context)?.push(...)` (mirrors the fail-soft pattern in `showApiError`) so widget tests without a router ancestor don't crash on the post-create hop.
- Failure modes go through `showApiError` (reuses the standard snackbar / 401 → /settings redirect).
- Empty-state subtitle rewritten from "Create a playlist on Navidrome to see it here." → "Tap + New playlist to create one." now that creation is in-app.

### Playlist-detail overflow (`android/app/lib/screens/library/playlist_detail_screen.dart`)
- New AppBar `PopupMenuButton<_PlaylistAction>` with Rename… / Delete…, gated on `canEdit` where:
  ```dart
  canEdit = loaded != null
      && settings != null
      && loaded.owner != null
      && loaded.owner == settings.navidromeUsername;
  ```
  Hides the entire menu (not just disables it) so non-owners get the same affordance set as the previous version of the screen.
- `_onRename`: opens `RenamePlaylistDialog`, calls `renamePlaylist(playlistId, name, makePublic: result.makePublic)`, snackbar "Playlist updated". `ApiError` → `showApiError`.
- `_onDelete`: shows a confirmation `AlertDialog` ("Delete '<name>'? This cannot be undone."), on confirm calls `deletePlaylist(current.id)`, snackbar "Playlist deleted", then `GoRouter.maybeOf(context)?.pop()` so the user returns to the Library list. Same fail-soft on the router as the create flow.
- New `enum _PlaylistAction { rename, delete }` so the `PopupMenuButton`'s value is type-safe.

### Tests
- New `test/widgets/playlist_dialogs_test.dart` (9 tests):
  - Create dialog: empty / whitespace-only name disables Create; submit trims; cancel returns `null`.
  - Rename dialog: seeds the name field + checkbox from initials; toggling the checkbox flips `makePublic`; empty name disables Save; cancel returns `null`.
- Extended `test/screens/library/library_screen_test.dart` (+2 tests):
  - FAB renders on the Playlists sub-tab.
  - FAB → dialog → Create calls `PlaylistMutations.createPlaylist` exactly once with the trimmed name (via a static-counter `_StubPlaylistMutations` overriding `playlistMutationsProvider`).
- Extended `test/screens/library/playlist_detail_screen_test.dart` (+5 tests):
  - Overflow menu hidden when `playlist.owner != navidromeUsername`.
  - Overflow menu hidden when no `navidromeUsername` is configured.
  - Overflow menu visible when `owner == navidromeUsername`.
  - Rename submit calls `renamePlaylist` with the new name + `makePublic`.
  - Delete shows the confirmation dialog; cancel does nothing; confirm calls `deletePlaylist` with the right id.
- The detail-screen tests introduce a `_UserStorage` `SecureStorage` stub that returns a fixed value for `navidrome_username` so `settingsProvider` builds with the desired `navidromeUsername` without overriding `settingsProvider` directly.

### Test gate + version
- `dart run build_runner build --delete-conflicting-outputs`: not re-run (no annotation changes — no new `@riverpod` / `@freezed`).
- `flutter analyze`: clean.
- `flutter test`: **348/348** pass (was 332 + 16 new = +16 net).
- `pubspec.yaml` version: stays at `1.2.0-pre+11` (the in-dev band carries M1–M4; M5 lands the release-band bump).

### Not done in this commit
- No `DECISIONLOG.md` entry — M2 stays within the architecture pre-approved in `ROADMAP_PLAYLISTS.md`. The combined ADR for playlist mutations lands at M5.
- Add-to-playlist flow (long-press song row → sheet) — M3.
- Reorder / remove-in-edit-mode UI — M4.
- On-device verification — folds into the M5 smoke run.

## 2026-06-13 — M3: Add-to-playlist sheet — song row long-press + album-level entry

Surfaces the M1 mutation notifier on every song-bearing screen: long-press a song row in album detail / playlist detail / library search → modal bottom sheet → pick an existing owned playlist OR create a new one. Album detail also gets an AppBar overflow "Add album to playlist…" that pre-loads the sheet with every song id from the album.

### New widget (`android/app/lib/widgets/add_to_playlist_sheet.dart`)
- `AddToPlaylistSheet` (`ConsumerWidget`) with `static show({context, songIds})` → `showModalBottomSheet` with `isScrollControlled: true` + `showDragHandle: true`. Sheet layout:
  - Title row: "Add N song(s) to playlist" (singular / plural).
  - "Create new playlist…" row at the top → opens `CreatePlaylistDialog` (reused from M2). On confirm: `PlaylistMutations.createPlaylist(name, songIds)` → snackbar `"Created '<name>' with N song(s)"`.
  - Existing-playlist list from `libraryPlaylistsProvider`, filtered to `owner == settings.navidromeUsername`. Tap → `PlaylistMutations.addSongs(playlistId, songIds)` → snackbar `"Added N song(s) to '<name>'"`.
  - Empty / no-Navidrome-username → nudge copy ("No editable playlists yet. Tap 'Create new playlist…' above.") so the FAB-less path still has a clear next step.
- Sheet pop / snackbar policy:
  - On success: capture `ScaffoldMessenger` from the sheet context, pop the sheet, then surface the confirmation snackbar on the captured messenger (the parent scaffold's). Capturing before pop is required because the sheet's `BuildContext` is deactivated by the time pop returns.
  - On failure: leave the sheet open and route through `showApiError` so the user can retry without re-discovering the entry point. The "create-new dialog → cancel" path likewise leaves the sheet up.

### Widget changes
- **`android/app/lib/widgets/library_result_tile.dart`** — new optional `VoidCallback? onLongPress`, forwarded to `ListTile.onLongPress`. Null → no handler attached, long-press is a no-op.
- **`android/app/lib/screens/library/album_detail_screen.dart`**:
  - Each song row (`ListTile`) gains `onLongPress` → `AddToPlaylistSheet.show(songIds: [song.id])`.
  - New AppBar `PopupMenuButton<_AlbumAction>` ("Add album to playlist…"), shown only once the album async has loaded. Value-typed via a private `enum _AlbumAction { addAlbumToPlaylist }`.
- **`android/app/lib/screens/library/playlist_detail_screen.dart`** — each song row gains `onLongPress` → `AddToPlaylistSheet.show(songIds: [song.id])` so a song can be copied from one playlist to another.
- **`android/app/lib/screens/library/library_screen.dart`** — the search-mode "In your library → Songs" sub-section threads `onLongPress` through `LibraryResultTile` to the same sheet.

### Tests
- **`test/widgets/library_result_tile_test.dart` (+2)** — long-press fires `onLongPress`; null `onLongPress` is a non-crashing no-op (the contract for tiles that don't opt in).
- **`test/widgets/add_to_playlist_sheet_test.dart` (new, 7 tests)**:
  - Renders title + Create-new row + owned playlists only (ownership filter excludes "Shared mix" owned by someone else).
  - Pluralises "1 song" / "N songs" in the title and snackbar.
  - No editable playlists → nudge copy at the bottom of the sheet.
  - No Navidrome username configured → ownership filter zeroes the list.
  - Tap existing playlist → `addSongs(playlistId, songIds)` called once; sheet pops; snackbar visible on host scaffold.
  - Tap "Create new playlist…" → `CreatePlaylistDialog` opens; submit → `createPlaylist(name, songIds)` called with the trimmed name + the full song-id list.
  - Create-new dialog Cancel leaves the sheet open and fires no mutation.
- **`test/screens/library/album_detail_screen_test.dart` (+2)**:
  - Long-press a song row → sheet opens; tapping a playlist in the sheet passes only that song's id to `addSongs`.
  - AppBar overflow → "Add album to playlist…" passes the full song-id list (two-song album → `['so-1', 'so-2']`).

### Test gate + version
- `dart run build_runner build --delete-conflicting-outputs`: not re-run (no annotations changed).
- `flutter analyze`: clean.
- `flutter test`: **359/359** pass (was 348 + 11 new = +11 net).
- `pubspec.yaml` version: stays at `1.2.0-pre+11`.

### Not done in this commit
- Reorder / edit mode — M4.
- Now Playing → "Add current to playlist" — deferred to a polish pass post-M4 per the roadmap.
- On-device verification — folds into the M5 smoke run.
- No `DECISIONLOG.md` entry — M3 stays within the architecture pre-approved in `ROADMAP_PLAYLISTS.md`.

## 2026-06-13 — M4: Playlist edit mode — remove + reorder

In-app playlist editing is now feature-complete: songs can be added (M3), removed (M4), reordered (M4), and the playlist itself renamed / deleted (M2). The Edit toggle on the playlist detail screen flips the song list into a `ReorderableListView` with per-row delete handles + drag handles, and the Check (save) action commits via the M1 mutation notifier with the minimum number of `updatePlaylist` calls.

### Screen rewrite (`android/app/lib/screens/library/playlist_detail_screen.dart`)
- Converted `PlaylistDetailScreen` from `ConsumerWidget` → `ConsumerStatefulWidget`. The new `_PlaylistDetailScreenState` holds the edit-mode working set:
  - `bool _isEditing` — current mode.
  - `List<Song> _editOrder` — working copy of the song list; drag-reorder mutates it.
  - `Set<String> _removedIds` — songs marked for removal (keyed by song id so reordering doesn't invalidate the set).
  - `bool _committing` — guards the Save action against double-tap while the mutation is in flight.
- AppBar surface:
  - **View mode (owner)**: offline-toggle • Play all • new Edit `IconButton(Icons.edit_outlined)` • Rename/Delete overflow (unchanged from M2).
  - **Edit mode**: only the Check `IconButton(Icons.check)`. Everything else is hidden so the user is focused on the edit operation.
  - The Edit affordance is gated on `owner == settings.navidromeUsername` (same rule as M2). Non-owners never see it.
- Edit body: `_PlaylistHeader` above an `Expanded(ReorderableListView.builder)`. Each row is a `ListTile` keyed by song id (required by `ReorderableListView`) with:
  - Leading: delete-toggle `IconButton`. `Icons.delete_outline` when keep-state, flips to `Icons.add_circle_outline` once the song is in `_removedIds`. Tapping toggles. Rows marked for removal stay in place visually so the index space the user is working in doesn't shift mid-edit.
  - Title / subtitle gain `TextDecoration.lineThrough` when removed.
  - Trailing: `ReorderableDragStartListener` wrapping an `Icons.drag_handle`. The whole list also responds to long-press drag-and-hold by default.
  - Uses the new `ReorderableListView.onReorderItem` callback (the historical `onReorder` is deprecated in Flutter 3.41+; the new variant auto-corrects the post-removal `newIndex` so the historical `if (newIndex > oldIndex) newIndex -= 1;` line is gone).
- Save (`_onCommit`): computes the diff between `_editOrder` / `_removedIds` and the original `playlist.entry`, then fires the **smallest** mutation that captures the user's intent:
  - **Nothing changed** → quiet exit, no network call.
  - **Removes only, no reorder** → one `removeSongsAtIndices(playlistId, originalIndices)` call. Indices are in the *original* list's coordinate space because that's what `songIndexToRemove` is keyed against on the wire; the M1 notifier sorts descending internally.
  - **Reorder (with or without removes)** → one `reorder(playlistId, survivingFromEdit)` call. The M1 `reorder()` issues a single `updatePlaylist` that deletes every index and re-adds the surviving songs in the new order. No separate `removeSongsAtIndices` / `addSongs` call from the UI layer.
  - On success: exit edit mode, snackbar "Playlist updated". On `ApiError`: `showApiError` and leave the user in edit mode so they can retry.
- Cancel via system back is handled by `PopScope`:
  - View mode: back pops the route normally (`canPop: true`).
  - Edit mode: back is intercepted (`canPop: false`). If `_hasPendingEdits(loaded)` is true the user gets a "Discard changes?" `AlertDialog`. "Discard" exits edit mode without applying any mutation; "Keep editing" leaves the screen alone. Edit mode without pending edits exits immediately on back, no dialog.

### Tests (`android/app/test/screens/library/playlist_detail_screen_test.dart`, +7)
- Edit button hidden when `owner != navidromeUsername`.
- Edit button visible when `owner == navidromeUsername`.
- Tap Edit → AppBar swaps in the Check icon; body renders a `ReorderableListView` with one drag handle + one delete handle per song.
- Remove one row + Save → `removeSongsAtIndices` called once with `[2]` (the original index of the removed song); `reorder` / `addSongs` not called.
- Reorder two rows (`onReorderItem(0, 2)`) + Save → `reorder` called once with the new id order `['so-b', 'so-c', 'so-a', 'so-d', 'so-e']`; `removeSongsAtIndices` / `addSongs` not called. The test invokes the `onReorderItem` callback directly via the widget instance because gesture-driven long-press-and-drag is brittle under `WidgetTester`'s hit-testing of `Draggable` feedback.
- Back with pending edits → discard dialog → "Discard" → no mutation fired and view mode is restored. Drives the system back via `WidgetsBinding.instance.handlePopRoute()` (the same path system Android-back routes through the framework).
- Save with no actual changes is a no-op (no mutation fired) and returns the user to view mode.
- The shared `_StubPlaylistMutations` was extended with counters for `reorder` / `removeSongsAtIndices` / `addSongs` so the M4 tests can assert exact call counts.

### Test gate + version
- `dart run build_runner build --delete-conflicting-outputs`: not re-run (no annotations changed).
- `flutter analyze`: clean.
- `flutter test`: **366/366** pass (was 359 + 7 new = +7 net).
- `pubspec.yaml` version: stays at `1.2.0-pre+11`.

### Not done in this commit
- On-device verification: M5.
- `DECISIONLOG.md` entry: lands at M5 as the combined ADR covering all of M1–M4 + the smoke verification.

## 2026-06-13 — User-driven polish: dedupe + Favourites + visible add-to-playlist icon

Post-M4 feature work driven by direct user feedback. Four asks:
1. Adding duplicate songs to a playlist was allowed — should not be.
2. Single songs were only addable via the (undiscoverable) long-press; needed a visible affordance.
3. A default "Favourites" playlist with a heart toggle.
4. Heart turns red (border + fill) when the song is in Favourites.

### `PlaylistMutations.addSongs` now dedupes (`android/app/lib/providers/library/playlist_mutations.dart`)
- Signature: `Future<void>` → `Future<int>` (the number of songs actually added).
- Internally fetches the playlist via the existing `getPlaylist.view` Subsonic endpoint (raw dio call, not through `libraryPlaylistProvider`, so the dedupe check sees a known-fresh entry list without perturbing provider-cache bookkeeping at the call site).
- Builds an existing-id set, filters `songIds` against it, and:
  - if filtered empty → returns 0 without firing `updatePlaylist` and without invalidating any provider;
  - otherwise → fires `updatePlaylist` with only the new songs and invalidates list + detail.
- Subsonic itself does NOT dedupe — pre-M4 code happily appended `songIdToAdd` even when the song was already in the playlist. The guarantee is now client-side.

### Favourites playlist (`android/app/lib/providers/library/favourites.dart` + extension on `PlaylistMutations`)
- New constant `kFavouritesPlaylistName = 'Favourites'` (UK spelling per user preference).
- New `@riverpod Future<Playlist?> favouritesPlaylist(ref)` — matches `name == 'Favourites'` and `owner == settings.navidromeUsername` against `libraryPlaylistsProvider`. Returns `null` when the playlist hasn't been lazy-created yet or no Navidrome username is configured.
- New `@riverpod Future<Set<String>> favouriteSongIds(ref)` — derived from `libraryPlaylistProvider(fav.id).entry`. Empty set when no Favourites playlist exists. UI watches this for the heart's filled-vs-outlined state, so heart toggling propagates through the existing mutation-invalidation chain without bespoke listening code.
- New method `PlaylistMutations.toggleFavourite(Song song)`:
  - No Favourites playlist yet → `createPlaylist(name: 'Favourites', songIds: [song.id])` (lazy creation).
  - Favourites exists, song not in it → `addSongs(playlistId, [song.id])` (which now dedupes internally as a defense in depth).
  - Favourites exists, song in it → `removeSongsAtIndices(playlistId, [songIdx])` after looking up the index in `libraryPlaylistProvider(favId).entry`.

### Visible per-song actions (`android/app/lib/widgets/song_row_actions.dart`, new)
- New `SongRowActions` `ConsumerWidget` factors the per-song trailing into one place. Renders a `Row(MainAxisSize.min, [heart, more, ?trailingStatus])` with:
  - **Heart** — `IconButton(visualDensity: compact)` with `Icons.favorite_border` (default) → `Icons.favorite` filled `Colors.redAccent` when `favouriteSongIdsProvider` contains the song id. Tap → `PlaylistMutations.toggleFavourite(song)`; on `ApiError` falls through to `showApiError`.
  - **`more_vert`** — opens `AddToPlaylistSheet.show(songIds: [song.id])`. This is the discoverable equivalent of the M3 long-press affordance (long-press still works; both call the same sheet).
  - **`trailingStatus`** — optional existing status icon (now-playing, offline-state, scheduled badge) appended to the right of the actions.
- Wired into both `album_detail_screen.dart` and `playlist_detail_screen.dart` view-mode song rows by replacing the previous bare `Icon?` `trailing` with `SongRowActions(song: s, trailingStatus: oldTrailing)`.
- Edit-mode rows in `playlist_detail_screen.dart` are untouched — their leading is the delete-toggle and their trailing is the drag handle, which is the correct semantics during an edit batch.
- Library-search "Songs" sub-section (`LibraryResultTile`) intentionally left out for now per the user's "Album + playlist detail" scope choice; long-press there still opens the sheet.

### Sheet snackbar refinement (`android/app/lib/widgets/add_to_playlist_sheet.dart`)
- `_onAddToExisting` now uses the `int` return from `addSongs`:
  - `added == 0` → `"Already in '<name>'"`
  - `added == requested` → `"Added N song(s) to '<name>'"`
  - `added < requested` → `"Added N song(s) to '<name>' (M already there)"`
- Same `_pluralise(int)` helper handles "1 song" vs "N songs" everywhere in the sheet.

### Test updates
- **`test/providers/library/playlist_mutations_test.dart`** (+5):
  - addSongs happy path now asserts `added == 2` and `getPlaylist.view` count == 3 (prime + addSongs internal fetch + post-invalidate refetch).
  - New: all-duplicates → returns 0 and `updatePlaylist` is never called.
  - New: partial duplicates → only the new songs go to `songIdToAdd` in order.
  - New: `toggleFavourite` no-favourites → `createPlaylist.view` with `name='Favourites'` + `songId='so-1'`.
  - New: `toggleFavourite` song-not-in → `updatePlaylist.view` with `songIdToAdd=so-1`, no `songIndexToRemove`.
  - New: `toggleFavourite` song-in → `updatePlaylist.view` with `songIndexToRemove=1`, no `songIdToAdd`.
- **`test/widgets/add_to_playlist_sheet_test.dart`** (+2):
  - All-duplicates → "Already in 'Morning'" snackbar.
  - Partial duplicates → "Added 2 songs to 'Morning' (1 already there)".
- **`test/widgets/song_row_actions_test.dart`** (new, 5 tests):
  - Heart outlined when not in Favourites.
  - Heart filled + `Colors.redAccent` when in Favourites.
  - Tapping the heart calls `PlaylistMutations.toggleFavourite(song)`.
  - `more_vert` opens `AddToPlaylistSheet` with this song id (the canonical signal is the sheet title rendering "Add 1 song to playlist").
  - `trailingStatus` is rendered alongside the action icons.
- **Existing finder scoping** — the new `more_vert` IconButton on every song row collides with the M2 AppBar overflow's `more_vert`. Updated:
  - `test/screens/library/playlist_detail_screen_test.dart` — all M2 overflow tests now scope via `find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.more_vert))`.
  - `test/screens/library/album_detail_screen_test.dart` — same fix for the M3 "Add album to playlist…" test.
- Stub `_StubPlaylistMutations` overrides updated for the new `Future<int>` signature on `addSongs` (return `songIds.length` by default; `AddToPlaylistSheet` sheet test gained an `addReturn` static so dedupe paths can be simulated).

### Test gate + version
- `dart run build_runner build --delete-conflicting-outputs`: clean; one new `.g.dart` written (`favourites.g.dart`).
- `flutter analyze`: clean.
- `flutter test`: **378/378** pass (was 366 + 12 new = +12 net).
- `pubspec.yaml` version: stays at `1.2.0-pre+11` (still in the M1–M4 in-dev band; M5 will land the release-band bump).

### Not done in this commit
- Heart icon on `LibraryResultTile` (library-search "Songs" sub-section) — out of scope per the user's Q3 choice. Long-press there still opens the sheet.
- "Add current to playlist" on Now Playing — still deferred per the M3 plan.
- `DECISIONLOG.md` entry — Favourites + dedupe stay within the architecture pre-approved in `ROADMAP_PLAYLISTS.md`. M5 will roll an ADR covering the full playlist-mutations feature including these additions.

## 2026-06-13 — M5: Playlists roadmap closed — v1.2.1 ships

Docs-only close-out for the playlist-mutations roadmap (M1 → M5 + the user-driven Favourites/dedupe polish). No production-code changes in this commit.

### `android/app/pubspec.yaml`
- Version bump: `1.2.0-pre+11` → `1.2.1`. First release-band build with playlist editing shipping. Substitutes for the roadmap's originally-planned `1.2.0+12` because the M4-polish round added Favourites + dedupe + the visible add-to-playlist icon, which the user asked to ship under `v1.2.1`.

### `android/docs/smoke_playlists.md` (new)
- Mirrors the shape of `smoke_streamer.md`: test environment + result + per-step procedure + caveats + done line.
- Eight on-device steps: create, add via long-press (or `more_vert`), add via album overflow, rename + publish, edit (reorder + remove), Favourites + heart toggle, delete + offline, dedupe sanity.
- Marked **verification pending** — each step has a TBD placeholder for the user to fill in after the on-device run. The procedure prose stays accurate either way; the PASS lines + the top-level Result line get updated post-install.

### `android/docs/DECISIONLOG.md`
- New 2026-06-13 ADR rolling up M1–M4 + the polish round into one entry. Covers:
  - Subsonic 1.16.1 endpoints directly, no backend coupling.
  - `@Riverpod(keepAlive: true) PlaylistMutations` single chokepoint.
  - Owner-only edit gate (`playlist.owner == settings.navidromeUsername`).
  - No offline mutation queue in v1.
  - Reorder via delete-all-and-re-add (Subsonic has no native reorder primitive).
  - `addSongs` client-side dedupe, `Future<int>` return.
  - Favourites as a regular lazy-created playlist named "Favourites" (not Subsonic's `star.view` primitive).
- Alternatives considered + trade-offs captured per the standard ADR shape.

### `android/docs/ROADMAP_PLAYLISTS.md`
- M1 through M5 boxes all ticked.
- Status line updated to "Roadmap closed (2026-06-13)" with pointers to the M1–polish commit shas (`d6635be` → `82b2654`).
- "Roadmap complete when" checklist updated: pubspec target `1.2.1` (not `1.2.0+12` per the polish-round substitution), tag `v1.2.1`.
- "Roadmap closed: 2026-06-13" line appended at the bottom.

### Test gate + version
- `dart run build_runner build --delete-conflicting-outputs`: not re-run (no annotations changed).
- `flutter analyze`: clean.
- `flutter test`: **378/378** pass (unchanged from the polish commit).
- `pubspec.yaml` version: `1.2.0-pre+11` → `1.2.1`.

### Not done in this commit
- The on-device smoke run itself. `smoke_playlists.md` is the user's to fill in PASS lines after they install `v1.2.1` on the Pixel 7 against the live home server.

## 2026-06-14 — N1: Subsonic scrobble.view integration at 50% playback

First Phase N milestone — wires the Android client to Navidrome's `scrobble.view` so play counts increment server-side and Navidrome can forward to Last.fm / ListenBrainz when those server-side integrations are configured.

### `android/app/lib/api/subsonic_endpoints.dart`
- Added `SubsonicEndpoints.scrobble = '/rest/scrobble.view'` with a doc comment naming the two firing rules (now-playing notification vs ≥ 50% submission) and the cross-link to ROADMAP N1.

### `android/app/lib/player/scrobble_controller.dart` (new)
- Plain Dart driver. Subscribes to the audio handler's `mediaItem.stream` (track changes) + the underlying just_audio player's `positionStream` (playback progress). Fires `scrobble(id, submission=false)` once per distinct `extras['subsonicId']`, then `scrobble(id, submission=true)` once when position reaches ≥ 50 % of `MediaItem.duration`. The "once per play" guard resets on track change; seeks back-and-forth across the threshold do not re-fire.
- MediaItems lacking a `subsonicId` extra (offline-only or malformed entries) are silently skipped. Null / zero `MediaItem.duration` suppresses the submission but the now-playing notification still fires. Exceptions from the `ScrobbleCall` are swallowed (best-effort).
- Exposes `start()` / `dispose()` for explicit lifecycle control.

### `android/app/lib/player/scrobble_provider.dart` (new)
- `@Riverpod(keepAlive: true) Future<void> scrobble(...)` constructs a `ScrobbleController` wired to `audioHandlerProvider`'s streams + `subsonicDioClientProvider`. The HTTP call is `GET /rest/scrobble.view?id=<sid>&submission=<bool>`; auth params (u/s/t/v/c/f) are injected by the existing `SubsonicAuthInterceptor`. `ref.onDispose` cancels the controller's stream subscriptions.

### `android/app/lib/main.dart`
- `HeerrApp` switched from `StatelessWidget` to `ConsumerWidget`. `ref.watch(scrobbleProvider)` is read at the root of the widget tree purely for the side effect of booting the controller (the keep-alive provider survives screen rebuilds across the session).

### Tests
- `android/app/test/player/scrobble_controller_test.dart` — 10 cases covering the full state machine:
  1. Track start fires `submission=false` with the subsonic id.
  2. Position ≥ 50 % fires `submission=true` exactly once.
  3. 49 % does *not* fire submission.
  4. Track change resets the guard so the new track fires its own submission.
  5. Re-emission of the same MediaItem does not re-fire the now-playing notification.
  6. `null` MediaItem clears state — same id refires after a stop.
  7. MediaItem without `subsonicId` extra fires no scrobbles.
  8. `null` duration suppresses submission but the now-playing notification still fires.
  9. Zero duration is guarded (no divide-by-zero, no submission).
  10. `dispose()` halts further stream processing.

### Test gate + version
- `dart run build_runner build --delete-conflicting-outputs`: clean; one new `.g.dart` (`scrobble_provider.g.dart`).
- `flutter analyze`: clean (added `// ignore_for_file: prefer_initializing_formals` in `scrobble_controller.dart` to keep public param names that don't leak the internal underscore prefix).
- `flutter test`: **388/388** pass (378 prior + 10 new).
- `pubspec.yaml` version: unchanged (in-progress N-band; bump at N5 close-out).

### Server-side dependency (informational, no code)
- Navidrome must have Last.fm or ListenBrainz integration configured in `navidrome.toml` / its web UI for the scrobble forwards to land. heerr's app emits the standard Subsonic `scrobble.view` calls regardless — what the server does with them is its own decision.

### Not done in this commit
- On-device smoke. Verify play count increments and (if configured) Last.fm scrobble appears after one end-to-end play.
- `DECISIONLOG.md` entry — N1 implements the architecture already locked in `ROADMAP.md` Phase N intro; N5 will roll an ADR covering the full Phase N feature.

## 2026-06-14 — N2: Seed collection provider (starred + frequent + Favourites fallback)

Pure data-layer milestone. Adds the `seedCollectionProvider` that the recommendations screen (N3) will consume — no UI yet.

### `android/app/lib/api/subsonic_endpoints.dart`
- Added `SubsonicEndpoints.getStarred2 = '/rest/getStarred2.view'` with a doc comment naming the N2 consumer.

### `android/app/lib/models/seed_track.dart` (new)
- Freezed model `SeedTrack { title, artist, sourceUrl? }`. Field names + `@JsonKey(name: 'source_url')` mirror the backend's `RecommendSeed` schema so the same model serialises as the `POST /api/v1/recommend` request body without a wire-shape mapper. `sourceUrl` is reserved for future use (when seeds carry a known `music.youtube.com/watch?v=…` URL so the ytmusic backend can skip the search-resolve step) — null in v1.

### `android/app/lib/providers/recommendations.dart` (new)
- Pure function `buildSeedCollection({starred, frequent, favourites, maxSeeds = 20})` — keeps merge rules testable without a Riverpod container:
  - Starred songs feed the list first (strongest signal of "user likes this").
  - Frequent albums feed next — each album contributes one seed shaped as `(album.name, album.artist)`. Treats the album as a quasi-track seed; engines that need a real song title will still get useful results because Last.fm's `track.getSimilar` and ytmusicapi's `search` both tolerate album-name queries well enough at the ranking stage.
  - Dedup by `(title.lower().trim(), artist.lower().trim())`.
  - Cap at `maxSeeds` (default 20 — backend ceiling is 50 with comfortable headroom).
  - Favourites fallback fires **only** when both primary sources produced zero seeds — avoids stacking Favourites on top of the starred/frequent ranking on every fetch.
  - Entries with missing/whitespace-only title or artist are silently skipped.
- `seedCollectionProvider` (Riverpod `@riverpod` async function):
  1. `GET /rest/getStarred2.view` → starred songs.
  2. `GET /rest/getAlbumList2.view?type=frequent&size=30` → frequent albums.
  3. If both empty, reads `favouritesPlaylistProvider` + `libraryPlaylistProvider(fav.id)` to pull the Favourites playlist's entries.
  4. Returns `buildSeedCollection(...)`.
- Errors propagate as `AsyncError`. Missing Navidrome username (no Favourites playlist resolvable) results in an empty list, not an error.

### Tests
- `android/app/test/providers/seed_collection_logic_test.dart` — 13 pure-function cases:
  empty everywhere, starred-only ordering, starred-before-frequent ranking, dedup case-insensitive, dedup whitespace-trim, missing-artist skip, missing-title skip, default-cap (20), explicit cap, Favourites-fallback fires on empty primary, Favourites-fallback skipped with starred non-empty, Favourites-fallback skipped with frequent non-empty, Favourites-fallback also caps + dedupes.
- `android/app/test/providers/seed_collection_provider_test.dart` — 5 integration cases against a routing dio adapter + settings override:
  1. Path + query-param assertions for `getStarred2.view` and `getAlbumList2.view?type=frequent&size=30`.
  2. Round-trip parsing: starred Song + frequent Album → SeedTracks in the right order.
  3. Favourites fallback path: empty primary + populated Favourites playlist → seeds from the playlist entries, plus assertion that `getPlaylists.view` + `getPlaylist.view` actually fired.
  4. Negative: primary non-empty → Favourites endpoints **not** hit.
  5. Empty-Favourites graceful: no Favourites playlist for the user → returns `[]`, no `getPlaylist.view` fire.

### Test gate + version
- `dart run build_runner build --delete-conflicting-outputs`: clean; two new `.g.dart`/`.freezed.dart` pairs (`seed_track.*`, `recommendations.g.dart`).
- `flutter analyze`: clean.
- `flutter test`: **406/406** pass (388 prior + 18 new).
- `pubspec.yaml` version: unchanged (in-progress N-band; bump at N5 close-out).

### Not done in this commit
- `recommendationsProvider` / Recommendations screen — N3 work; reads from `seedCollectionProvider` and calls `POST /api/v1/recommend`.
- Library cross-reference + "Find similar" affordance — N4.
- Engine-health indicator in Settings — N5.

## 2026-06-14 — N3: Recommendations screen + POST /recommend integration

UI-layer milestone. Adds the "For You" screen that surfaces backend recommendations, plus the Library entry point.

### `android/app/lib/api/endpoints.dart`
- Added `Endpoints.recommend = '/recommend'` and `Endpoints.recommendHealth = '/recommend/health'` (the latter is N5 wiring — declared now to keep the endpoint catalogue complete in one edit).
- **Bug-fix on the same edit:** the original I-phase plumbing accidentally elided the existing `static String status(String jobId)` helper. Restored — `job_status` provider depends on it.

### `android/app/lib/models/recommended_track.dart` (new)
- Freezed model mirroring the backend `RecommendResultItem` schema: `title`, `artist`, `sourceUrl` (`@JsonKey(name: 'source_url')`), nullable `score`, `inLibrary` (default `false` — hydrated at N4 by the Subsonic `search3` cross-reference).
- `sourceUrl` is always a `music.youtube.com/watch?v=…` URL regardless of which backend engine produced the recommendation — the backend's `YTMusicResolver` flattens the wire shape. So Download dispatches through the existing `POST /download` flow with no per-engine special-casing.

### `android/app/lib/providers/recommendations.dart` (extended)
- New `recommendationsProvider` (AsyncNotifier). `build()` reads `seedCollectionProvider`, POSTs `{seeds, limit: 20}` to `Endpoints.recommend`, parses the `results` list. Empty seeds are sent through unchanged — the ListenBrainz engine produces results purely from its own history, so an empty-seeds POST is meaningful for users running that engine; the other engines return `[]` and the screen falls back to its empty state.
- `refresh()` invalidates the provider so pull-to-refresh re-issues the chain (seedCollection → backend).

### `android/app/lib/screens/recommendations_screen.dart` (new)
- "For You" screen. AppBar title only (no actions). Body wrapped in `RefreshIndicator` so the user can pull to re-fetch.
- Loading: SkeletonList (6 rows). Error: empty-state widget with the typed `ApiError.message` as the subtitle. Empty: empty-state with "Star a few songs or play some music — recommendations need a starting point." copy.
- Per row: title + artist + `FilledButton.icon` "Download". The button reads only the in-flight set for **its own** URL via `downloadDispatcherProvider.select(...)` so other rows' dispatches don't rebuild the whole list. While in flight: spinner replaces the icon and the button is disabled.
- Tap → `downloadDispatcherProvider.dispatch(track.sourceUrl, sourceType: 'song', displayName: track.title)`. Success → "Queued '...'" snackbar (1 s). `ApiError` → `showApiError(action: 'download')` so 403 surfaces the standard "this token cannot download" copy.

### `android/app/lib/router.dart`
- Added `Routes.libraryRecommendations = '/library/recommendations'`.
- Added the `library/recommendations` `GoRoute` as a nested child of `Routes.library` (lives inside the ShellRoute so the bottom nav stays visible and the back navigation pops back into the Playlists tab).

### `android/app/lib/screens/library/library_screen.dart`
- "For You →" `ListTile` appended after the playlists list. Always rendered, even when the user has no playlists yet — recommendations are reachable on first launch.
- The pre-existing "No playlists yet" empty state was removed in this same edit so the For You tile is the only thing inside an empty list. The FAB on the same tab still handles the "create your first playlist" UX.

### Tests
- `android/app/test/providers/recommendations_provider_test.dart` — 5 cases:
  1. POST hits `/recommend` with the right seeds + `limit: 20`.
  2. Round-trip parse: `results: [...]` → `List<RecommendedTrack>` with `score` round-tripping (and absent score → `null`).
  3. Empty seeds still POSTs — ListenBrainz engine path.
  4. `refresh()` re-issues the POST (loose: asserts `adapter.requests.length` grew, not the exact response content — `invalidateSelf` + `await future` re-runs the chain N times in test under some scheduling, but the user-visible behaviour is "fresh data" not "exactly one request").
  5. Backend error surfaces as `ApiError`.
- `android/app/test/screens/recommendations_screen_test.dart` — 6 cases via stub `Recommendations` notifier:
  1. Loading state (AppBar visible, no rows).
  2. Error state ("Could not load recommendations" copy).
  3. Empty state ("Nothing to suggest yet" copy).
  4. Data render: 2 rows with title + artist + 2 Download buttons.
  5. Download dispatch records the right URL on the stub dispatcher and shows "Queued '...'" snackbar.
  6. Download `ApiError` surfaces the 403 snackbar copy.
- `android/app/test/screens/library/library_screen_test.dart` — existing "Playlists empty" test updated: now asserts the For You entry-point key is present (replaces the removed `EmptyState`).

### Test gate + version
- `dart run build_runner build --delete-conflicting-outputs`: clean; two new `.freezed.dart`/`.g.dart` pairs (`recommended_track.*`).
- `flutter analyze`: clean.
- `flutter test`: **417/417** pass (406 prior + 11 net new: 5 provider + 6 screen, 1 library test updated in-place).
- `pubspec.yaml` version: unchanged (in-progress N-band; bump at N5 close-out).

### Not done in this commit
- Library cross-reference (`inLibrary: true` rows render Play instead of Download) — N4.
- "Find similar" long-press affordance — N4.
- Engine-health chip in Settings — N5.

## 2026-06-14 — N4: Library cross-reference + Find Similar long-press

Closes the "find → download → play in one app" loop for the recommendations flow: results that are already in the user's Navidrome library render **Play** instead of **Download**, and any library song can launch a recommendation feed seeded from itself.

### `android/app/lib/models/recommended_track.dart`
- Added `subsonicSongId: String?` to the freezed model. Populated by the N4 cross-reference step; required for the Play branch (without it we can't drive Subsonic playback).

### `android/app/lib/providers/recommendations.dart`
- New `manualSeedProvider` (`StateProvider<SeedTrack?>`). When non-null, `recommendationsProvider.build()` uses it as the **sole** seed and ignores `seedCollectionProvider` for that visit. The screen clears it back to null on `dispose` so the next entry returns to the general "For You" feed.
- `Recommendations.build()` now hydrates each base result via `_hydrateLibraryMatches(base)`: parallel `search3.view?query=<artist> <title>&songCount=1` calls against the Subsonic dio. On match → `copyWith(inLibrary: true, subsonicSongId: <id>)`; on miss or per-result exception → row falls through unchanged. Subsonic dio not configured at all → cross-reference no-ops gracefully (every row stays remote).

### `android/app/lib/screens/recommendations_screen.dart`
- Switched `RecommendationsScreen` from `ConsumerWidget` → `ConsumerStatefulWidget` so it can clear `manualSeedProvider` in `dispose`.
- `_RecommendationTile`: when `track.inLibrary && track.subsonicSongId != null`, renders a **Play** `FilledButton.icon`. Tapping it builds a synthetic `Song(id, title, artist)` (avoids a round-trip through `getSong` for one play) and calls `playSongFromSubsonic(ref, context, song)`. Remote-only rows keep the Download path unchanged.

### `android/app/lib/widgets/add_to_playlist_sheet.dart`
- `AddToPlaylistSheet` accepts an optional `findSimilarSeed: SeedTrack?`. When non-null, renders a "Find similar →" `ListTile` at the top of the sheet (key `add-to-playlist-find-similar`). Tap sets `manualSeedProvider` to the seed, pops the sheet, and pushes `Routes.libraryRecommendations`. Album-level / multi-song callers leave it null and the affordance disappears.
- `AddToPlaylistSheet.show()` signature gained the same optional parameter; existing call sites that don't pass it get the original behaviour.

### `android/app/lib/screens/library/library_screen.dart`
- The library-search "Songs" sub-section long-press now passes `findSimilarSeed: _seedForSong(s)` so users can long-press a found song → "Find similar →" → recommendations seeded from that exact track. The `_seedForSong` helper returns `null` when the Subsonic song has no artist (backend `RecommendSeed` requires both title and artist) so the affordance gracefully hides for orphaned rows.

### Tests
- `android/app/test/providers/recommendations_provider_test.dart` — 3 new cases (8 total):
  1. Cross-reference: matching result gets `inLibrary=true` + correct `subsonicSongId`; non-matching result stays `inLibrary=false`. Verifies `search3.view` was called once per result with `songCount: 1`.
  2. Cross-reference failure tolerance: empty Subsonic envelope → row falls through as `inLibrary=false` (no exception).
  3. Manual-seed override: when `manualSeedProvider` is set, the POST body's `seeds` array contains exactly that one seed — `seedCollectionProvider` is bypassed.
- `android/app/test/screens/recommendations_screen_test.dart` — 1 new case (7 total): when one result has `inLibrary=true` + `subsonicSongId`, that row renders the Play button (not Download); a sibling remote-only row still renders Download.
- `android/app/test/widgets/add_to_playlist_find_similar_test.dart` (new) — 3 cases:
  1. "Find similar →" tile renders when `findSimilarSeed` is non-null.
  2. Tile is hidden when `findSimilarSeed` is null.
  3. Tapping the tile sets `manualSeedProvider` to the passed seed.

### Test gate + version
- `dart run build_runner build --delete-conflicting-outputs`: clean (no new annotations).
- `flutter analyze`: clean.
- `flutter test`: **424/424** pass (417 prior + 7 new: 3 provider + 1 screen + 3 sheet).
- `pubspec.yaml` version: unchanged (in-progress N-band; bump at N5 close-out).

### Not done in this commit
- Engine-health chip in Settings — N5.
- The "Find similar →" affordance is wired only through the library-search song rows so far; the album-detail + playlist-detail song rows would need the same wiring on their long-press. Deferred — the search-side surface is the highest-discoverability entry point in v1 and the others can be added without breaking changes.

## 2026-06-14 — N5: Engine health indicator in Settings + Phase N close-out

Closes the recommendations roadmap. Adds a Settings indicator for backend engine health, an app-resume refresh hook, and bumps the release band to v1.3.0.

### `android/app/lib/models/recommend_health.dart` (new)
- Freezed `RecommendHealth { engine, status, fallbackActive }` mirroring the backend `RecommendHealthResponse` (snake-case wire field for `fallback_active` via `@JsonKey`).

### `android/app/lib/providers/recommendations.dart`
- New `recommendHealthNotifierProvider` (keep-alive `@Riverpod` class). `build()` hits `GET /api/v1/recommend/health` via the heerr backend dio and stamps `_lastFetchAt`. `refreshIfStale(maxAge: 60s default)` no-ops when the cache is fresh, otherwise calls `ref.invalidateSelf()`. The default 60 s TTL stops resume/screen-open events from thrashing the backend.

### `android/app/lib/screens/settings_screen.dart`
- `SettingsScreen` switched from `ConsumerWidget` → `ConsumerStatefulWidget` so `initState` can fire a post-frame `refreshIfStale()`. (The provider's keep-alive cache + 60 s TTL keep cold opens cheap.)
- New `_RecommendationsSection` rendered below `_ServersTile`:
  - **Loading** state: `Engine health` row with `Checking…` subtitle.
  - **Error** state: `Could not reach backend — check token in Servers.` in the error colour.
  - **Data** state: `Engine: <name>` title + status chip (green `OK` / amber `Degraded`) + optional `Fallback active` chip. When degraded, a trailing `help_outline` IconButton toggles an inline diagnostic paragraph (`fallbackActive` → "running on the fallback, check your API key"; `!fallbackActive` → "no engine in the chain is reachable").
- Visual: chips use `withValues(alpha: …)` (Flutter ≥ 3.27 colour API) so the soft tint + outlined border render correctly under Material 3.

### `android/app/lib/router.dart`
- `_ShellScaffoldState.unawaitedResume` now also calls `recommendHealthNotifierProvider.refreshIfStale()` on app resume. Cheap — the 60 s TTL guards the call.

### Tests
- `android/app/test/providers/recommend_health_test.dart` (new) — 4 cases:
  1. `GETs /recommend/health` with the right path; parses the typed payload (ok / fallback_active=false round-trips).
  2. Degraded + `fallback_active=true` payload parses correctly.
  3. `refreshIfStale` is a no-op while the cached payload is < 60 s old (no second HTTP fetch).
  4. `refreshIfStale(maxAge: Duration.zero)` forces re-fetch on the next read (cache always treated as stale → second HTTP call observed).
- `android/app/test/screens/settings_screen_test.dart` — 4 new widget cases under a `Recommendations section` group:
  1. ok engine → green chip + no fallback badge + no help icon.
  2. Degraded engine → amber chip + help icon visible (no fallback badge when `fallback_active=false`).
  3. `fallback_active=true` → both the Degraded chip and the Fallback-active chip render.
  4. Tap the help icon → inline diagnostic copy ("Primary engine probe failed…") appears below the row.
  All tests inject a `_StubHealth` notifier whose `refreshIfStale` is a no-op so the SettingsScreen's post-frame refresh doesn't try to fire a real HTTP call through the unmocked `dioClientProvider`.

### Test gate + version
- `dart run build_runner build --delete-conflicting-outputs`: clean; one new pair (`recommend_health.freezed.dart`/`.g.dart`).
- `flutter analyze`: clean.
- `flutter test`: **432/432** pass (424 prior + 8 new: 4 provider + 4 widget).
- `pubspec.yaml`: bumped `1.2.1` → `1.3.0`. Release-band version for the Phase N (recommendations) feature ship.

### Phase N closed (2026-06-14)
- N1 ✅ Subsonic scrobble integration (track-start + ≥ 50 % submission).
- N2 ✅ Seed-collection provider (starred + frequent + Favourites fallback).
- N3 ✅ Recommendations screen + `POST /recommend` integration.
- N4 ✅ Library cross-reference + Find Similar long-press.
- N5 ✅ Engine health indicator in Settings.
- Tag: `v1.3.0` (after the on-device smoke).

### Not done in this commit
- On-device smoke. Verify recommendations populate, Play branch works for in-library matches, Find Similar long-press seeds the feed, Settings shows the engine chip.
- `DECISIONLOG.md` ADR for Phase N (will land alongside the smoke run + tag).
- Album-detail / playlist-detail song-row long-press still routes through the old `AddToPlaylistSheet.show(songIds: …)` shape without `findSimilarSeed`. The library-search song surface is the highest-discoverability entry point in v1; adding the same affordance to the other two surfaces is mechanical.


## 2026-06-14 — Phase O — Home screen (O1–O5)

### O1: Home tab + 4-tab nav restructure
- `android/app/lib/router.dart` — `Routes.home = '/'`; `Routes.library` becomes `/library` (was `/`). Library nested routes lose their leading `library/` prefix (`'artist/:id'`, `'album/:id'`, `'playlist/:id'`, `'recommendations'`) — the helper getters (`Routes.libraryArtist(id)` etc.) still produce the same `/library/<kind>/<id>` URLs so call sites are unchanged. `initialLocation` flipped to `Routes.home`.
- `_ShellScaffold._tabs` — now 4 tabs: **Home / Library / Downloads / Settings**. Queue tab dropped from the bottom nav (per user choice); reachable via a top-right `queue_music_outlined` IconButton in the Home AppBar. `_indexFor` keeps Home selected when `/queue` is foregrounded — `/queue` is now a routed-but-unbound destination from the nav point of view.
- `android/app/lib/screens/home/home_screen.dart` (new) — initial scaffold with greeting (`Good morning` / `Good afternoon` / `Good evening` based on device hour) and the Queue shortcut. Pure-Dart `greetingForHour(int)` helper exported for unit testing.
- `android/app/test/router_test.dart` — updated assertions for the 4-tab layout, "boots on Home" expectation, Queue-via-AppBar-icon navigation, and 4 unit tests for `greetingForHour` (morning / afternoon / evening / pre-dawn). 14 tests pass.

### O2: Home data providers
- `android/app/lib/api/subsonic_endpoints.dart` — new constant `getRandomSongs = '/rest/getRandomSongs.view'`.
- `android/app/lib/providers/home/home_providers.dart` (new) — four providers:
  - `homeRecentProvider`: `getAlbumList2.view?type=recent&size=8`.
  - `homeMostPlayedProvider`: `getAlbumList2.view?type=frequent&size=8`.
  - `homeRandomSongsProvider`: `getRandomSongs.view?size=20`.
  - `homeRecommendationsProvider`: thin wrapper around `recommendationsProvider`. Falls back to `homeRandomSongsProvider` mapped as `RecommendedTrack(inLibrary=true, subsonicSongId=<id>, sourceUrl='')` when the backend returns empty. Returns a `HomeRecommendations` record `(tracks, isFallback)` so the screen can flip the section header to "Discover" on fallback.
- `android/app/test/providers/home/home_providers_test.dart` (new) — 7 cases covering correct endpoint + query params, empty envelopes, the random-songs fallback path, and the artist-required filter that drops random songs missing the `artist` field.

### O3: Quick-access grid + horizontal sections
- `android/app/lib/widgets/home_grid_tile.dart` (new) — compact 2-col tile, 56 px square cover (left) + title (right). Used in the Home quick-access grid; tap → push album route.
- `android/app/lib/widgets/home_section.dart` (new) — Spotify-style horizontal section: bold header + `ListView.builder(scrollDirection: Axis.horizontal)` of 140 px square cover-art cards with title + optional subtitle below. Generic — used for "Jump back in" and "Most played".
- `android/app/lib/screens/home/home_screen.dart` — quick-access grid (recently played; falls back to recommendations when recent is empty; full-empty state when both are empty), "Jump back in" section (recent), "Most played" section (frequent). Each section invisible when its source is empty; loading uses `SkeletonBox`; errors silent in v1.
- `android/app/test/screens/home/home_screen_test.dart` (new) — 6 widget cases: greeting + Queue icon render; recent-albums populate the grid (capped at 6); both sections render when sources are non-empty; empty-recent → recommendation fallback grid OR empty-state; Queue-icon tap routes to /queue.

### O4: Picked for you / Discover recommendations section
- `android/app/lib/widgets/home_recommendation_card.dart` (new) — 160 px wide vertical card: square colour-swatch placeholder (no per-card cover-art lookup in v1 — would require an extra `getSong.view` round-trip per row), title, artist, action button. **Play** when `track.inLibrary && track.subsonicSongId != null`, **Download** otherwise. Same dispatcher / playback paths as the existing recommendations screen.
- `android/app/lib/screens/home/home_screen.dart` — `_RecommendationsSection`: horizontal scroll of cards from `homeRecommendationsProvider`. Header reads **"Picked for you"** when `isFallback=false`, **"Discover"** when `isFallback=true`. Hidden when there are no tracks (covered by the full-empty state in `_QuickAccessGrid`).
- `android/app/test/widgets/home_recommendation_card_test.dart` (new) — 2 cases: in-library renders Play, remote-only renders Download + fires the dispatcher.
- `android/app/test/screens/home/home_screen_test.dart` — 2 new cases asserting the "Picked for you" ↔ "Discover" header switching.

### O5: Tile-tap routing + pull-to-refresh + v1.4.0
- `android/app/lib/screens/home/home_screen.dart` — body wrapped in `RefreshIndicator`. Outer ListView pinned to `AlwaysScrollableScrollPhysics` so pull-to-refresh works even on the full-empty state. `_refresh(ref)` invalidates all four Home providers; awaits `homeRecentProvider` so the spinner stays up for at least one round-trip.
- Tile-tap routing was already wired in O3 (`context.push(Routes.libraryAlbum(a.id))`) — O5 adds the widget test that asserts the actual route shape lands at `/library/album/:id`.
- `android/app/test/screens/home/home_screen_test.dart` — 2 new cases: album-tile tap routes correctly; calling `RefreshIndicator.onRefresh()` re-fetches `homeRecentProvider`.
- `android/app/pubspec.yaml`: bumped `1.3.0` → `1.4.0`. Tag `v1.4.0` after on-device smoke.

### Test gate + version
- `dart run build_runner build --delete-conflicting-outputs`: clean; new pair for `home_providers.g.dart`.
- `flutter analyze`: clean.
- `flutter test`: **455/455** pass (432 prior + 23 new: 7 home-provider + 6 + 2 + 2 + 2 home-screen + 2 recommendation-card + 4 greeting + extra router).
- `pubspec.yaml`: `1.3.0` → `1.4.0`.

### Phase O closed (2026-06-14)
- O1 ✅ Home tab + 4-tab nav (Home / Library / Downloads / Settings).
- O2 ✅ Home data providers (recent, frequent, random songs, recommendations w/ fallback).
- O3 ✅ Quick-access grid + Jump back in + Most played sections.
- O4 ✅ Picked for you / Discover recommendations section.
- O5 ✅ Tile-tap routing + pull-to-refresh + v1.4.0 version bump.
- Tag: `v1.4.0` (after on-device smoke).

### Not done in this commit
- On-device smoke against the home server. Verify Home boots first; recent / frequent populate from live Navidrome data; recommendations show; pull-to-refresh re-fetches; Queue still reachable via AppBar icon.
- `DECISIONLOG.md` ADR for Phase O (will land alongside the smoke run + tag).
- Per-card cover art in `HomeRecommendationCard` — would need an extra `getSong.view` round-trip per row to resolve `coverArt`. Deferred until users notice the placeholder.


## 2026-06-15 — P1: persist Now Playing across cold starts

Lifts the cold-start "lost queue" surprise: the active queue, current track, and playback position are written to `<appDocs>/now_playing.json` and restored on the next launch — restored state is queued but not auto-played; the user taps to resume.

### Files (new)
- `android/app/lib/player/now_playing_snapshot.dart` — freezed `NowPlayingSnapshot(songs, currentIndex, positionMs, updatedAt)`. `Song` reuses the existing `models/subsonic/song.dart` JSON shape.
- `android/app/lib/player/now_playing_store.dart` — atomic load/save (`.tmp` + rename, same safety pattern as `OfflineManifestStore` from L1). Missing / empty / corrupt JSON → `load()` returns `null`. Keep-alive provider `nowPlayingStoreProvider` resolves the file at `<appDocs>/now_playing.json` via the existing `applicationDocumentsDirectoryProvider`.
- `android/app/lib/player/now_playing_persistence.dart` — `NowPlayingPersistence` orchestrator (debounced 500 ms save on any handler-stream event + immediate `flush()`); `buildSnapshotFromHandler` production helper; `nowPlayingPersistenceProvider` (keep-alive) fuses the handler's `queue` / `mediaItem` / `playbackState` streams into a single trigger; `nowPlayingRestoreProvider` runs the cold-start restore once.

### Files (modify)
- `android/app/lib/player/song_to_media_item.dart` — `coverArt` now rides in `MediaItem.extras` alongside `subsonicId` so `songFromMediaItem` (new) can round-trip without losing the cover-art id.
- `android/app/lib/player/heerr_audio_handler.dart` — new `restoreQueue(items, currentIndex, position)` method that sets up the queue + initial seek **without** calling `play()`.
- `android/app/lib/main.dart` — `HeerrApp` watches `nowPlayingPersistenceProvider` + `nowPlayingRestoreProvider` for side effects (same pattern as `scrobbleProvider`).
- `android/app/lib/router.dart` — `_ShellScaffoldState.didChangeAppLifecycleState` now calls `nowPlayingPersistence.flush()` on `paused` / `inactive` / `hidden` so a position written within the last 500 ms is captured before the OS may kill us.

### Tests (new, 21 total)
- `test/player/now_playing_snapshot_test.dart` — JSON round-trip including the empty-defaults case.
- `test/player/now_playing_store_test.dart` — 6 cases: missing-file / empty-file / corrupt-JSON → `null`; save+load round-trip; atomic-write (no stray `.tmp`); parent-dir auto-create; `clear()` idempotent.
- `test/player/now_playing_persistence_test.dart` — 7 cases: debounce collapses bursts to one save; `flush` bypasses debounce; `flush` cancels a pending debounce timer; `dispose` cancels pending work and stops listening; builder throwing is swallowed; save failure (unwriteable path) swallowed; second `start` call replaces the previous subscription + builder.
- `test/player/song_from_media_item_test.dart` — 5 cases: full-fields extraction; missing/empty `subsonicId` → null; absent `coverArt`; round-trip via `songToMediaItem` preserves Song fields.

### Test gate
- `dart run build_runner build --delete-conflicting-outputs`: clean.
- `flutter analyze`: clean.
- `flutter test`: **483/483** pass (462 prior + 21 new).

### Restore semantics — explicit non-goals for v1
- Restored queue does **not** auto-play. The mini-player appears with the last-played track at the saved position; the user taps to resume. This is a friction-vs-surprise tradeoff: auto-play would surprise users who closed the app to silence it.
- The persisted snapshot is **not** scoped per Navidrome server. Switching servers mid-session leaves the snapshot pointed at song ids that may not exist on the new server; restore still attempts the queue, and `just_audio` errors on play if the ids don't resolve. Acceptable because settings switches are rare; can be revisited if it bites.
- Scrobble may fire `submission=false` on restore for the restored current track because the existing `mediaItem.add` path triggers `ScrobbleController._onMediaItem`. This is no worse than today's `playSong` → `play()` ordering (which scrobbles before audio actually starts) and Last.fm / ListenBrainz dedupe now-playing notifications.

### Not done in this commit
- On-device smoke (deferred to P4 per ROADMAP).
- `DECISIONLOG.md` ADR — the v1.5.0 polish-band ADR landed at the scope/plan step (2026-06-15 entry covers P1–P3 together).


## 2026-06-15 — P2: Subsonic lyrics in Now Playing

Adds an AppBar lyrics toggle on the Now Playing screen — taps swap the 240×240 cover-art panel for a 240×240 scrollable plain-text lyrics box. Empty state is the same dimensions so the surrounding scrubber / transport / queue don't jump. Hits Subsonic's classic `GET /rest/getLyrics.view?artist=…&title=…`.

### Files (new)
- `android/app/lib/models/subsonic/lyrics.dart` — freezed `Lyrics(artist, title, value)`; all fields nullable to match Navidrome's "empty `lyrics` element when nothing known" behaviour.
- `android/app/lib/providers/library/lyrics.dart` — `lyricsForProvider(artist, title)` family. Returns `Lyrics?` — null is the "no lyrics for this track" empty state. Two paths arrive there: Subsonic code 70 (`NotFoundError` caught + swallowed) and an empty / whitespace-only `value` in the envelope. Other `ApiError`s rethrow.

### Files (modify)
- `android/app/lib/api/subsonic_endpoints.dart` — new `getLyrics` constant + docstring.
- `android/app/lib/screens/player/now_playing_screen.dart`:
  - `_NowPlayingScreenState._showLyrics: bool` — per-session view toggle, resets when the screen is popped.
  - AppBar action — `key: 'now-playing-lyrics-toggle'`, icon swaps between `lyrics_outlined` and `image_outlined`.
  - `_Body` now takes `showLyrics`; renders `_LyricsPane` instead of `_CoverArt` when true.
  - `_LyricsPane` reads `lyricsForProvider(artist, title)` and renders four states (loading / error / null-or-empty / data). Data state uses `SelectableText` inside a `Scrollbar` + `SingleChildScrollView` for long lyrics.
  - `_LyricsBox` keeps the box 240×240 so the layout never reflows on toggle.

### Tests (new, 15 total)
- `test/models/subsonic/lyrics_test.dart` — 3 cases: full-envelope round-trip; missing fields; empty envelope.
- `test/providers/library/lyrics_test.dart` — 7 cases: happy path hits correct path + params; code 70 → null; empty value → null; whitespace-only value → null; missing `lyrics` block → null; empty artist/title short-circuit (no HTTP call); other Subsonic errors rethrow as typed `ApiError`.
- `test/screens/player/now_playing_lyrics_toggle_test.dart` — 5 widget cases: toggle button visible; tap toggles cover ↔ lyrics and back; code-70 envelope renders the empty-state; non-70 error renders the error pane; null artist short-circuits the empty state without firing any HTTP call.

### Test gate
- `dart run build_runner build --delete-conflicting-outputs`: clean.
- `flutter analyze`: clean.
- `flutter test`: **498/498** pass (483 prior + 15 new).

### Design notes
- **Lyrics is a per-session view choice**, not a stored preference. Backgrounding then re-foregrounding Now Playing keeps the toggle; popping the screen resets it. This matches how Spotify / Apple Music treat the lyrics overlay and avoids a "why is lyrics on for tracks that have none?" first-impression.
- **No `getLyricsBySongId.view` / synced lyrics in v1.** Open-Subsonic's structured timed-lyrics extension is the future direction but Navidrome's stable release still exposes the classic plain-text endpoint. Upgrading later is a model + provider change; the screen wiring stays.
- **Selectable text** in the data view because users do copy lyrics to share — defaulting to selectable avoids the "this app stole my long-press" friction.

### Not done in this commit
- On-device smoke (deferred to P4).
- `DECISIONLOG.md` ADR — covered by the 2026-06-15 "v1.5.0 player polish band" entry.


## 2026-06-15 — P3: sleep timer

Adds a session-scoped sleep timer to Now Playing. Overflow menu → Sleep timer → bottom sheet with 15 / 30 / 45 / 60-minute presets + Custom… + Off (when active). When active, a countdown chip renders in the AppBar (taps reopens the sheet). On expiry, fires `audioHandlerProvider.pause()`. Survives app background; deliberately does not survive cold start.

### Files (new)
- `android/app/lib/player/sleep_timer.dart`:
  - `SleepTimerController` — pure-Dart `Timer.periodic` driver, takes an `onExpire` callback. Public stream + getter for `remaining`. Same plain-Dart pattern as `scrobble_controller.dart` so unit tests run under `fake_async` without standing up `audio_service` / `just_audio` platform channels.
  - `SleepTimerNotifier` (`@Riverpod(keepAlive: true)`) — wraps the controller, wires `onExpire` to `ref.read(audioHandlerProvider).pause()`, exposes `setDuration(Duration?)` + `cancel()`. `state` mirrors the controller's `remaining`.

### Files (modify)
- `android/app/lib/screens/player/now_playing_screen.dart`:
  - AppBar actions extended: when `sleepTimerNotifierProvider` state is non-null, a `_SleepCountdownChip` renders ahead of the existing lyrics toggle. New overflow `PopupMenuButton` with a single "Sleep timer" entry that opens `_SleepTimerSheet`.
  - `_SleepCountdownChip` — `InputChip` with bedtime glyph and `MM:SS` / `H:MM:SS` formatted countdown. Tapping reopens the sheet so the user can change / cancel without hunting the overflow.
  - `_SleepTimerSheet` — modal bottom sheet wrapped in `SingleChildScrollView` so the 6 tiles (5 presets + Custom… + conditional Off) survive small viewports without RenderFlex overflow.
  - `_CustomMinutesDialog` — `AlertDialog` with a numeric TextField; returns the parsed minutes (or null).

### Tests (new, 15 total)
- `test/player/sleep_timer_test.dart` — 10 controller cases under `fake_async`:
  1. Starts idle (`remaining == null`).
  2. `setDuration(5s)` ticks down to 1s.
  3. Expiry fires `onExpire` exactly once, clears `remaining`, no further ticks.
  4. `setDuration(null)` cancels mid-countdown without firing `onExpire`.
  5. `cancel()` is sugar for `setDuration(null)`.
  6. `setDuration` mid-countdown replaces the active timer (countdown resets).
  7. `Duration.zero` and negative durations are treated as cancel.
  8. Broadcast `stream` emits each state change exactly once, including expiry → null.
  9. Exception from `onExpire` is swallowed via `.catchError` (does not escape the timer callback into the FakeAsync zone).
  10. `dispose()` stops ticking and ignores further `setDuration` calls.
- `test/screens/player/now_playing_sleep_timer_test.dart` — 5 widget cases:
  1. Countdown chip is absent when timer is idle.
  2. Countdown chip is visible with formatted `15:00` text when active.
  3. Overflow → Sleep timer opens the sheet with all 5 preset keys present and Off hidden.
  4. Tapping "15 minutes" sets the timer + closes the sheet + reveals the chip.
  5. Off tile appears when active; tapping it cancels and hides the chip. (Tile may be below the fold in the small test viewport — test uses `tester.ensureVisible` before tapping.)

### Test gate
- `dart run build_runner build --delete-conflicting-outputs`: clean.
- `flutter analyze`: clean.
- `flutter test`: **513/513** pass (498 prior + 15 new).

### Design notes
- **Plain-Dart controller, thin Riverpod adapter.** Same shape as `scrobble_controller.dart` + `scrobble_provider.dart` (N1). Unit tests don't depend on `HeerrAudioHandler` (which pulls in `just_audio`'s platform channels and can't be instantiated in `flutter test`). The Riverpod notifier handles the integration; tests of the integration would belong in an on-device smoke (P4).
- **Session-scoped, not persisted.** A persisted sleep timer would need a "wall-clock end time" stored to disk and a restore path that compares now vs that end-time on cold start. Out of scope for v1; deferring matches user intent ("sleep timer is the gesture you make when going to sleep, not a preference").
- **Chip-tap reopens the sheet** rather than opening a separate "edit" affordance — matches Spotify's pattern and avoids a second control surface.
- **Custom minutes via TextField + parse.** A more polished v2 could replace with a numeric stepper / wheel picker; the TextField is the simplest input that works (numeric keyboard, integer parse, invalid entries silently dropped).

### Not done in this commit
- On-device smoke (deferred to P4).
- `DECISIONLOG.md` ADR — covered by the 2026-06-15 "v1.5.0 player polish band" entry.


## 2026-06-15 — P4: v1.5.0 — player polish band ships

Closes Phase P. Three player UX improvements bundled as the v1.5.0 polish band: persisted Now Playing across cold starts (P1 / X2), Subsonic lyrics in Now Playing (P2 / X3), session-scoped sleep timer (P3 / X4a). Pure-Android slice; no backend change. ADR locked at `DECISIONLOG.md` 2026-06-15 ("v1.5.0 player polish band").

### Files (modify)
- `android/app/pubspec.yaml`: bumped `1.4.0` → `1.5.0`. Release-band version for the player-polish ship.

### Test gate
- `flutter analyze`: clean.
- `flutter test`: **513/513** pass across the prior baseline + 51 P-phase tests (21 P1 + 15 P2 + 15 P3).

### Phase P closed (2026-06-15)
- P1 ✅ Persist Now Playing across cold starts.
- P2 ✅ Subsonic lyrics in Now Playing.
- P3 ✅ Sleep timer.
- P4 ✅ Version bump.
- Tag: `v1.5.0` (after the on-device smoke).

### Not done in this commit
- **On-device smoke.** Three steps to verify on the live Pixel against the home server before tagging:
  1. **P1 — persist NP.** Start a queue, play for ~30 s, force-close the app, relaunch → mini-player shows the last-played track at the saved position; tapping resumes from that position.
  2. **P2 — lyrics.** Play a track Navidrome has lyrics for → AppBar lyrics toggle swaps cover for scrollable text. Play a track *without* lyrics → toggle shows "No lyrics for this track".
  3. **P3 — sleep timer.** Set a 1-minute timer → countdown chip renders in AppBar; wait → playback pauses at expiry; chip disappears. Tap the chip mid-countdown → sheet reopens with "Off" tile.
- **`v1.5.0` git tag** — created after the smoke passes.


## 2026-06-15 — v1.5.0 smoke verified + two bug fixes

### Bug fixes shipped post-tagging

**Fix 1 — Navigation reset on server save** (`android/app/lib/main.dart`):
`HeerrApp` was a `ConsumerWidget` that called `buildHeerrRouter()` inside `build()`. When `settingsProvider` was invalidated on first server save, `scrobbleProvider` rebuilt → `HeerrApp.build()` ran → new `GoRouter` with `initialLocation: '/'` reset the navigation stack to Home. Fixed by converting to `ConsumerStatefulWidget` with the router held in `initState()`.

**Fix 2 — Lyrics unavailable for popular tracks** (`android/app/lib/providers/library/lyrics.dart`):
`getLyrics.view` and `getLyricsBySongId.view` both returned nothing because Navidrome's LRCLib integration was not configured in the home-server compose stack. Fixed by adding a direct LRCLib fallback (`https://lrclib.net/api/get?artist_name=…&track_name=…`) that runs when Navidrome returns empty. No auth or server-side config required; covers near all popular tracks.

Both fixes committed as `df90f18` and included in the re-tagged `v1.5.0`.

### On-device smoke — v1.5.0 (2026-06-15)

Verified on Pixel 7, Android 16 (API 36), against live home server over Tailscale.

- **Server setup (bug fix V):** Added server via Settings → Servers. Tapped "Test heerr" → "Connection OK" snackbar appeared; bottom sheet stayed open; no navigation to Home. ✅
- **P1 — Persist Now Playing:** Played a track for ~30 s, force-closed, relaunched → mini-player showed last-played track at saved position; did not auto-play; tapping resumed from correct position. ✅
- **P2 — Lyrics:** Opened Now Playing → tapped lyrics toggle → lyrics appeared for tested tracks via LRCLib direct fallback. Empty state shown correctly for tracks without lyrics. ✅
- **P3 — Sleep timer:** Set 1-minute timer from overflow → countdown chip appeared in AppBar → playback paused at expiry → chip disappeared. Chip-tap mid-countdown reopened sheet with Off tile. ✅

Phase P declared complete. `v1.5.0` tagged and pushed.


## 2026-06-16 — Phase Q (Q1–Q4): v2.0.0 background offline sync via WorkManager

Closes Phase Q. WorkManager-driven periodic background sync for the offline downloads feature. Pure-Android slice; no backend change. ADR at `DECISIONLOG.md` 2026-06-15 ("v2.0.0 background offline sync via WorkManager").

### Files (add)
- `android/app/lib/offline/background_sync.dart`: Entry point (`backgroundSyncCallbackDispatcher`, `@pragma('vm:entry-point')`), `runBackgroundSyncTask` (delegates to `OfflineSync.syncNow`), `constraintsFor` + `constraintsForSettings` (pure constraint derivation), `backgroundIntervalMinutesFor` (15-min floor clamp), `BackgroundSyncScheduler` abstract + `_WorkmanagerScheduler` production impl, `backgroundSyncSchedulerProvider` (keepalive Riverpod), `hasPendingSyncTargets` predicate, `onAppForegrounded` / `onAppBackgrounded` lifecycle handlers.
- `android/app/lib/offline/background_sync.g.dart`: Riverpod codegen for `backgroundSyncSchedulerProvider`.
- `android/app/test/offline/background_sync_test.dart`: 20 tests covering `runBackgroundSyncTask`, `constraintsFor`, `backgroundIntervalMinutesFor`, `hasPendingSyncTargets`, lifecycle handoff, and fg/bg manifest atomic-write contention.

### Files (modify)
- `android/app/pubspec.yaml`: added `workmanager: ^0.9.0` (bumped from initial `^0.5.2` — 0.5.x uses removed Flutter v1 embedding shims); bumped version `1.5.0` → `2.0.0`.
- `android/app/android/app/src/main/AndroidManifest.xml`: added `RECEIVE_BOOT_COMPLETED` permission (WorkManager needs it for boot-survival scheduling).
- `android/app/lib/main.dart`: `Workmanager().initialize(backgroundSyncCallbackDispatcher, isInDebugMode: kDebugMode)` before `AudioService.init`.
- `android/app/lib/providers/settings.dart`: added `offlineChargingOnly` field to `SettingsValue` record; `_kKeyOfflineChargingOnly` constant; `build()` reads it; `save()` writes it; `clear()` deletes it.
- `android/app/lib/offline/offline_settings.dart`: added `chargingOnly` to `OfflineSettingsValue` record; `build()` maps from `settingsProvider`; `setChargingOnly(bool)` notifier method.
- `android/app/lib/offline/offline_sync.dart`: updated fallback `OfflineSettingsValue` literal to include `chargingOnly: false`.
- `android/app/lib/screens/settings_screen.dart`: added "Charging only" `SwitchListTile` under "WiFi only"; updated fallback literal.
- `android/app/lib/router.dart`: `didChangeAppLifecycleState` — on backgrounded: `unawaited(_scheduleBackgroundSync())`; on resumed: `unawaited(_cancelBackgroundSync())` (fire-and-forget, does not block `unawaitedResume()`). Added `_cancelBackgroundSync()` and `_scheduleBackgroundSync()` helpers.
- Multiple test files: added `chargingOnly: false` / `offlineChargingOnly: false` to `OfflineSettingsValue` and `SettingsValue` record literals.

### Test gate
- `flutter analyze`: clean.
- `flutter test`: **533/533** pass (516 prior baseline + 8 Q2 new + 9 Q3 new).

### On-device smoke — v2.0.0 (2026-06-16)
Verified on Pixel 7, Android 16 (API 36).

- Mark album → background app → worker fires within one poll interval → Downloads tab shows completed downloads on re-open. ✅
- WiFi-off gate: worker skipped when device is off metered network. ✅
- Charging-only toggle: gates correctly on device charger state. ✅

### Phase Q closed (2026-06-16)
- Q1 ✅ WorkManager entry point + `runBackgroundSyncTask` delegates to `OfflineSync.syncNow`.
- Q2 ✅ Constraint derivation (`wifiOnly` / `chargingOnly`), interval clamp, `BackgroundSyncScheduler` abstraction, new `chargingOnly` setting + UI toggle, fg/bg atomic-write contention test.
- Q3 ✅ `hasPendingSyncTargets`, `onAppForegrounded`/`onAppBackgrounded`, router lifecycle wiring.
- Q4 ✅ v2.0.0 version bump, docs, on-device smoke.
- Tag: `v2.0.0`.

---

## 2026-06-16 — Gapless playback (X4b / v2.1.0)

### Change
- `android/app/lib/player/heerr_audio_handler.dart`: `AudioPlayer` constructor now passes `useLazyPreparation: false`. ExoPlayer prepares the next source in the queue before the current one ends, eliminating the inter-track gap on `setAudioSources`-driven playlists.
- `android/app/pubspec.yaml` → `2.1.0`.

### Why
just_audio's `AudioPlayer` defaults `useLazyPreparation: true`. With that default the next `AudioSource` in the playlist is not constructed / handed to ExoPlayer until the current one finishes — which is exactly when the audible gap appears. Flipping to `false` lets ExoPlayer queue the next renderer ahead of time and do its native gapless hand-off.

The change is a single constructor flag flip; no surface area in `setAudioSources` / `playAll` / `restoreQueue` changed. Eager preparation for streaming HTTP sources amounts to opening the URI and buffering the head — cheap on Tailscale-LAN to Navidrome.

### Test gate
- `flutter analyze`: clean (the pre-existing `isInDebugMode` deprecation warning in `main.dart` is unrelated and outside this change).
- `flutter test`: **533/533** pass.

### Notes
- Manual on-device verification deferred to the v2.1.0 smoke checkpoint in DEBT.md.
- ADR: `DECISIONLOG.md` 2026-06-16 entry ("X4b — gapless playback via `useLazyPreparation: false`").

### On-device smoke — v2.1.0 (2026-06-16)
Verified on Pixel 7, Android 16 (API 36).

- Play an album with continuous-flow tracks → no audible gap on track transitions. ✅
- Skip-next / pause / resume / seek still behave correctly. ✅
- Lock-screen + notification controls update on track change. ✅

### Phase R closed (2026-06-16)
- R1 ✅ `useLazyPreparation: false` on the `AudioPlayer` constructor.
- Tag: `v2.1.0`.

---

## 2026-06-17 — Phase S: multi-user profiles via Navidrome IdP (v3.0.0)

Re-scoped from "single-user, no multi-user login" (`/CLAUDE.md` §3) to multi-user
via the backend's new `POST /api/v1/auth/login` IdP shim (backend J6). Identity
is delegated to Navidrome; no other Sign-In-With-X provider is permitted. Hard
logout/login model — one active profile at a time. Per-server isolation is free
via the existing L1 `serverKey` because S8 overlays the active profile's
`(heerrBaseUrl, heerrBearerToken, navidromeBaseUrl, navidromeUsername,
navidromePassword)` onto `settingsProvider`.

### S1 — Profile freezed model
- New: `models/profile.dart` — freezed + json_serializable record with
  `{id, displayName, heerrBaseUrl, heerrBearerToken, navidromeBaseUrl,
  navidromeUsername, navidromePassword, createdAt, lastUsedAt}`.
- Tests: round-trip `fromJson(toJson()) == self`, `copyWith` semantics,
  value-equality.

### S2 — Profile registry provider
- New: `providers/profiles/profile_registry.dart` —
  `@Riverpod(keepAlive: true) class ProfileRegistry` exposing
  `addProfile / removeProfile / setActive / bumpLastUsed`. Backed by
  `flutter_secure_storage` under fixed keys `profiles_index` and
  `active_profile_id` (distinct from the legacy `server_profiles` /
  `active_server_name`).
- Tests: add / setActive / remove flows, persistence round-trip across
  two `ProviderContainer`s, corrupt-index fallback, dangling-active drop.

### S3 — Legacy creds migration shim
- New: `providers/profiles/legacy_migration.dart` —
  `migrateLegacyCreds(ProviderContainer)`. Detects pre-S full single-set
  creds, wraps them in a [Profile], persists via the registry, sets
  active, sweeps legacy keys. Idempotent on three axes (fresh-install,
  already-migrated, partial-creds all no-op).
- Modified: `main.dart` — runs migration before `runApp` against a root
  `ProviderContainer` that `UncontrolledProviderScope` adopts.
- Tests: full-creds path, fresh-install no-op, already-migrated no-op,
  partial-creds no-op, idempotency, empty-username treated as missing.

### S4 — Login API client
- New: `api/auth_login.dart` — `authLogin(baseUrl, username, password) ->
  AuthLoginResponse(token, scopes, navidromeUrl, navidromeUsername)`.
  Builds its own ad-hoc `Dio` (no bearer interceptor — login has no
  token yet). Maps `DioException` through the existing
  `mapDioErrorToApiError` chokepoint.
- Modified: `api/endpoints.dart` — new `Endpoints.authLogin = '/auth/login'`.
- Tests: happy path (token + scopes + Navidrome echo), 401 →
  `UnauthorizedError`, 503 → `RateLimitedError`, network failure →
  `NetworkError`, 500 → `HttpStatusError`.

### S5 — Login screen UI
- New: `screens/auth/login_screen.dart` — 3-field form (heerr base URL,
  Navidrome username, Navidrome password) + Sign-in button + password
  visibility toggle. On submit calls S4; on success constructs a
  [Profile] via the response's `navidromeUrl` + `navidromeUsername`,
  persists via `profileRegistry`, sets active, navigates to `/`. Errors
  route through `showApiError`.
- Modified: `router.dart` — adds `Routes.login` + a redirect closure
  that, when an `ProviderContainer` is supplied, rewrites all
  off-/login navigation to `/login` when no profile is active, and
  conversely redirects `/login` to `/` once active. Container plumbed
  via `buildHeerrRouter(container: ProviderScope.containerOf(context))`.
- Tests: renders three fields, empty-submit validation, non-http URL
  rejection, password-visibility toggle.

### S6 — Active profile provider
- New: `providers/profiles/active_profile.dart` —
  `activeProfileProvider` derives the currently-active [Profile] from
  the registry. Null when no profile is active or the active id points
  at a removed profile.
- Tests: null when none active, returns active after `setActive`,
  switching updates the provider, removed-active goes null.

### S7 — dio + Subsonic clients keyed off active profile
- Modified: `api/client.dart` — `dioClientProvider` watches
  `activeProfileProvider`; uses its `heerrBaseUrl` + `heerrBearerToken`
  when present. Falls back to legacy `settingsProvider` keys for the
  brief pre-hydration window and unmigrated installs.
- Modified: `api/subsonic_client.dart` — `subsonicDioClientProvider`
  applies the same pattern with `navidromeBaseUrl` +
  `navidromeUsername` + `navidromePassword`.
- Tests: switching active profile rebuilds heerr dio with new base URL;
  same for Subsonic dio.

### S8 — Per-server isolation invariant
- Modified: `providers/settings.dart` — `Settings.build()` watches
  `activeProfileProvider`; when present, overlays its per-server
  credentials onto the returned `SettingsValue`. Legacy keys remain the
  fallback. The overlay propagates the active profile's
  `(navidromeBaseUrl, navidromeUsername)` through every existing
  callsite that hashes those into a `serverKey` (L1 offline paths, L5
  library cache, P1 NowPlaying persistence, scrobble controller) —
  isolation is implicit and tested.
- Tests: distinct serverKey per profile, `settingsProvider` echoes
  active profile creds, `OfflinePaths.serverRoot` returns disjoint dirs
  per profile + alice's files survive a bob → alice round-trip.

### S9 — Profiles section in Settings
- New: `screens/settings/profiles_section.dart` — lists every profile
  with display name + Navidrome username + relative `lastUsedAt`,
  marks active, exposes Switch / Remove via per-row overflow menu,
  Add profile entry pushes `/login`. Switch / Remove dialogs use
  `FilledButton` confirmations; removing the active profile clears the
  pointer and pushes `/login`.
- Modified: `screens/settings_screen.dart` — mounts `ProfilesSection`
  above the existing offline / servers / recommendations sections.
- Tests: empty registry → empty-state + Add row; renders one row per
  profile + marks active via `ListTile.selected`; switch flow confirms
  via dialog and writes via `setActive`; remove-active leaves the
  registry without an active pointer.

### S10 — DECISIONLOG ADR + CLAUDE.md carve-out + DEBT updates
- New ADR (`DECISIONLOG.md` 2026-06-17 "Multi-user profiles via
  Navidrome IdP — heerr v3.0.0") — captures the seven sub-decisions
  above plus the trade-off on the settings overlay.
- Modified `android/CLAUDE.md`: rewrites the "Single-user." hard rule
  to permit the Navidrome IdP path specifically; updates the "Hard
  don'ts" to forbid every *other* Sign-In-With-X provider and to
  forbid reading per-server creds from `settingsProvider` and
  `activeProfileProvider` in the same callsite (the overlay makes one
  redundant).
- Modified `DEBT.md`: marks S1–S10 shipped, adds S11 as pending
  backend J6 + on-device smoke, slots per-user Last.fm /
  ListenBrainz + biometric unlock + soft profile switch into the
  v3.1.0 backlog.

### S11 — v3.0.0 on-device smoke verified
- Modified: `android/app/pubspec.yaml` → `3.0.0`. RC1 was promoted to
  the clean `v3.0.0` tag after the 7-step on-device smoke against the
  live home-server stack (heerr backend at `3.0.0`, J6
  `/auth/login` live, two real Navidrome users) passed.
- Fixes folded into the smoke window:
  - `main.dart` no longer reads `ProviderScope.containerOf` in
    `initState` — the root `ProviderContainer` is now injected into
    `HeerrApp` to avoid an inherited-widget lifecycle crash at boot.
  - Settings screen hides the legacy "Servers" tile when an active
    Profile exists (single source of truth = Profile registry).
  - `/login` redirect no longer rewrites to `/` when an active profile
    exists — required so the "Add profile" button can push `/login`.
  - Home tab gained a tappable search bar that drops into the Library
    tab's combined-search mode via a new `librarySearchAutoFocus`
    one-shot flag.

## 2026-06-19 — Architectural debt band A1 + A4 + A5 (credential/prefs cleanup)

Addresses the P0 architectural-debt items A1, A4, A5 from `docs/DEBT.md`
§5 (2026-06-18 audit). Pure-Android slice; no backend change. `flutter
analyze` clean; `flutter test` green (567 tests).

- **A1 — single credential source.**
  - `lib/providers/settings.dart`: deleted the legacy `ServerProfile`
    class and `ServerProfiles` notifier. `Settings.build` now sources all
    five per-server credential fields exclusively from
    `activeProfileProvider` — the pre-S single-set secure-storage keys
    (`backend_base_url`, `bearer_token`, `navidrome_*`) and the
    `server_profiles` / `active_server_name` blob are no longer read or
    written. `save()` lost its credential parameters (the only callers
    were the deleted `ServerProfiles` methods); it now carries offline
    prefs only.
  - Deleted `lib/screens/servers_screen.dart` + its test; removed the
    `/settings/servers` route, the `Routes.servers` constant, and the
    `_ServersTile` from `settings_screen.dart` (the Phase-S
    `ProfilesSection` is now the sole credential surface).
  - `lib/api/client.dart` + `lib/api/subsonic_client.dart`: both dio
    providers now read credentials only from `activeProfileProvider`,
    removing the `active?.x ?? settings.x` dual-read that violated the
    `android/CLAUDE.md` "don't read creds from settingsProvider AND
    activeProfileProvider in the same callsite" rule.
  - `lib/widgets/error_snackbar.dart`: `NavidromeAuthError` now redirects
    to `/login` (re-auth the profile) instead of the deleted Servers
    screen.
  - `lib/screens/auth/login_screen.dart`: pre-fills the base-URL +
    Navidrome-username fields from the gitignored `DevDefaults` (the
    consumer the deleted Servers screen used to have); the password is
    never defaulted.
- **A5 — offline prefs out of EncryptedSharedPreferences.**
  - New `lib/providers/prefs_storage.dart`: `PrefsStorage` abstraction
    (same interface as `SecureStorage`) + `SharedPrefsStorage` backed by
    the new `shared_preferences` dependency. The five offline-download
    prefs (`offline_enabled/sync_all/wifi_only/poll_interval_min/charging_only`)
    now live here, not in the Android keystore.
  - `migrateOfflinePrefs` (one-shot, idempotent) runs in `main.dart`
    after `migrateLegacyCreds`: copies the offline keys from secure
    storage into plain prefs, then deletes them from secure storage.
  - `pubspec.yaml`: added `shared_preferences: ^2.2.0`.
- **A4 — collapsed `Settings.build` sequential awaits.** With creds from
  the in-memory active profile and offline prefs read via one
  `Future.wait` batch, `Settings.build` drops from 10 sequential
  `await store.read(...)` calls against the keystore to a single
  concurrent batch.
- **Tests.** `settings_test.dart` rewritten around the active-profile +
  prefs split (credential reads driven via an `activeProfileProvider`
  override; offline reads/writes via a fake implementing both storage
  interfaces). `client_test` / `subsonic_client_test` rewired to seed
  creds via the profile registry. New shared helper
  `test/support/cred_test_support.dart` (`initPrefsMock()` +
  `activeProfileOverride()` + `testProfile()`) used across the offline /
  library / screen tests that previously seeded creds via legacy keys.
  12 legacy-credential tests removed (ServerProfile JSON round-trips,
  credential save/clear, Servers-entry, the whole `servers_screen_test`).
- **Note (A3 partial):** the dual-read hard-rule violation in the dio
  providers is fixed, but `BearerAuthInterceptor` /
  `SubsonicAuthInterceptor` still capture the token by value at
  Dio-construction time (rebuild-on-profile-change). The full
  stateless-interceptor refactor (A3) is left for a follow-up.

## 2026-06-19 — V5 smoke passed + v3.1.1 tagged

- On-device smoke for the A1/A4/A5 credential + offline-prefs band verified on the Pixel 7 against the home Navidrome with backend `3.0.0`:
  - Upgrade from v3.0.0: silent re-login; offline prefs survived migration.
  - No Servers tile or `/settings/servers` route present.
  - Profile add / switch / remove all correct.
  - Auth-error (401) redirects to `/login`.
  - Fresh-install boots to `/login` with empty profile registry.
- `pubspec.yaml` tagged `v3.1.1`.
- `DEBT.md`: V5 marked ✅; A7 already marked ✅ (resolved as part of the A1 band — `ServerProfile` deleted, `Profile` (freezed) is now the only profile model).

## 2026-06-19 — A6: split SettingsValue (creds via ServerCreds, offline prefs standalone)

- **New `lib/providers/server_creds.dart`.** `ServerCreds` record (Navidrome `baseUrl`/`username`/`password`) + synchronous `serverCredsProvider` re-slicing `activeProfileProvider`.
- **Deleted `lib/providers/settings.dart`** (`Settings` notifier + `SettingsValue`) and its generated `settings.g.dart`.
- **`lib/offline/offline_settings.dart`** is now the sole offline-prefs owner: reads/writes `PrefsStorage` directly (absorbed the key constants, defaults, `_parseBool`/`_parseInt`, `Future.wait` batch read, and per-key writes from the deleted `Settings`). Mutators (`setEnabled`/`setSyncAll`/…) write prefs directly; `_clearEstimateCacheFor` takes `ServerCreds`. The re-slice over `Settings` is gone.
- **Offline path layer retyped `SettingsValue` → `ServerCreds`** (bodies unchanged — field names match): `offline_paths.dart` (8 helpers), `offline_manifest.dart` (`load`/`save` + `offlineManifestProvider` now watches `serverCredsProvider`), `library_cache.dart`, `offline_downloader.dart`, `offline_marker.dart`, `offline_size_estimator.dart`, `offline_sync.dart` (cred reads).
- **Credential consumers outside offline** repointed to `serverCredsProvider`: `player/playback_actions.dart`, `player/now_playing_persistence.dart`, `providers/library/favourites.dart`, `screens/library/playlist_detail_screen.dart`, `widgets/add_to_playlist_sheet.dart`, `widgets/library_cover_art.dart`, `screens/settings_screen.dart` (clear-downloads path).
- **Tests.** Deleted `test/providers/settings_test.dart` (provider gone; offline-pref behavior covered by `offline_settings_test.dart`). `test/support/cred_test_support.dart` gained a `testCreds()` helper; `activeProfileOverride()` now feeds `serverCredsProvider` transitively. Offline tests that built `SettingsValue` literals now build `ServerCreds`; `seed_collection_provider_test` switched from a `_FakeSettings`/`settingsProvider` override to `activeProfileOverride`. `background_sync_test`'s "container error → false" case rewired to force a downstream throw (the sync creds read is now graceful, not throwing). `flutter analyze` clean; 558 tests green.
- **Note (A19):** `ServerCreds` / `OfflineSettingsValue` remain `typedef` records — the freezed migration stays tracked as A19.

## 2026-06-20 — Fix: R8 strips audio_service → media notification + lock-screen player gone (v3.1.2-rc2)

- **Bug (release-only):** lock-screen controls and the pull-down media notification stopped rendering. Playback itself still worked.
- **Root cause:** commit `403c5ff` enabled R8 minification (`isMinifyEnabled`/`isShrinkResources`) to fix the WorkManager boot crash, but `proguard-rules.pro` kept only `androidx.work`/`androidx.room`. AGP auto-keeps the manifest-declared `AudioService`/`MediaButtonReceiver`, so the foreground service started, but R8 stripped/obfuscated `audio_service`'s internal MediaSession + notification-builder classes. Invisible in `flutter run` (debug skips R8).
- **Fix:** `android/app/android/app/proguard-rules.pro` — added `-keep class com.ryanheise.audioservice.**` and `-keep class com.ryanheise.just_audio.**`.
- **Docs:** `SMOKE-TEST.md` — bumped to `v3.1.2-rc2`; added a "must smoke a RELEASE build" banner and made §6.8–6.10 the explicit R8 regression gate. `DEBT.md` — added V6 (pending) smoke row + a "Resolved bugs" record. Replaced a stray "User Inputs" scratch note with the proper record.
- Regression verification deferred to the V6 on-device smoke against a release APK.

## 2026-06-20 — V6 smoke passed; v3.1.2 tagged

- On-device smoke (v3.1.2-rc2 release APK) passed on the Pixel 7 against the home Navidrome:
  - Lock-screen controls and pull-down media notification present (R8 regression confirmed fixed).
  - Offline path re-keying on profile switch correct.
  - Offline prefs survive upgrade from v3.1.1.
- `android/SMOKE-TEST.md` deleted (per convention — one-liner in DEBT.md V6 row is the record).
- `DEBT.md`: V6 marked ✅; resolved-bugs record updated to "confirmed".
- Promoted: `v3.1.2-rc2` → `v3.1.2`.

## 2026-06-20 — A9: retry + debug-log interceptors on both dio clients

- **New `lib/api/interceptors.dart`:**
  - `RetryInterceptor` — bounded (default 2 retries / 3 attempts), backoff-based retry for *transient* dio failures. Retries connection/send/receive timeouts + connection errors (exponential backoff, base 500ms) and HTTP 503. For 503 it honours `Retry-After` only when short (`maxRetryAfter`, default 5s); a longer rate-limit is left to surface as `RateLimitedError` so the user gets the real countdown. Re-issues via `dio.fetch` (full chain re-runs, so the auth header is re-applied); recursion bounded by an attempt counter in `RequestOptions.extra`.
  - `DebugLogInterceptor` — request/response/error tracing gated on `kDebugMode`, via `debugPrint` (no `print`), redacts the `Authorization` header to `***`.
- **Wired into both dio builders** in interceptor order auth → retry → log: `lib/api/client.dart` (`dioClient`, tag `heerr`) and `lib/api/subsonic_client.dart` (`subsonicDioClient`, tag `subsonic`). Subsonic envelope failures arrive as HTTP 200 and remain handled by `subsonicCall`; the retry only fires on real transport 5xx / network errors there.
- **Tests:** new `test/api/interceptors_test.dart` (8 cases) — 503-then-200, connection-error-then-200, give-up-after-maxRetries (503 → `RateLimitedError`, network → `NetworkError`), short `Retry-After` honoured, long `Retry-After` not retried, 401 + 500 not retried; each asserts the exact attempt count. `flutter analyze` clean; full suite 566 green.
- Satisfies the `docs/CONTEXT.md` HTTP-stack promise ("Interceptors for the auth header + retry-on-503 + logging") — previously only the auth header was implemented (DEBT §5 A9).

## 2026-06-20 — A2 + A15: reactive-lifecycle correctness (router redirect + offline-sync gate)

- **A2 — `lib/router.dart`:** `buildHeerrRouter` now passes `refreshListenable:` a new `_RouterRefresh` `ChangeNotifier` that bridges `profileRegistryProvider` (via `container.listen`) to GoRouter. The first-launch/signed-out redirect previously re-evaluated only on navigation events, so removing the active profile left stale screens rendered against a torn-down profile until the next tab tap. The redirect now fires to `/login` the instant `activeId` goes null. Subscription is auto-closed on container dispose; GoRouter removes its own listener on `dispose()`, so no explicit teardown is needed.
- **A15 — `lib/offline/offline_sync.dart`:** `OfflineSync.build` now `ref.watch(activeProfileProvider)` and returns `_kIdle` (no `_runTick`, no Timer scheduled) when it's null — so the keep-alive sync provider no longer ticks while the user lingers on `/login` with no creds. Also cancels any leftover Timer at the top of every rebuild (a profile switch / settings toggle re-runs `build` on the same notifier instance). Login flips `activeProfile` non-null → `build` re-runs → normal enabled-check + first tick.
- **Tests:**
  - `test/router_test.dart` — new "A2" group: seed an active profile, render the app on Home, `removeProfile` without navigating → asserts redirect to `LoginScreen`. Adds a persisting `_MapStorage` secure-storage fake; reuses `_StubSync` to keep the shell's init microtask inert.
  - `test/offline/offline_sync_test.dart` — new guard "A15": offline enabled + no active profile → `build` yields idle with `lastError == null` (proving the gate skipped `_runTick`, which would otherwise have surfaced `'no creds'`) and no adapter hits.
- `flutter analyze` clean; full suite 568 green (+2). Resolves DEBT §5 A2 + A15.

## 2026-06-20 — A8 + A10: router god-file split + Repository/Service layer

- **A8 — `lib/app/lifecycle_coordinator.dart` (new):** the six app-lifecycle side-effects (offline-sync kick on launch, pause/resume, Now-Playing flush, background-sync schedule/cancel, recommend-health refresh) moved out of `_ShellScaffold` into `LifecycleCoordinator` (`ConsumerStatefulWidget` + `WidgetsBindingObserver`). The ShellRoute builder composes `LifecycleCoordinator(child: _ShellScaffold(...))`. `lib/router.dart` is now nav chrome only (dropped the observer mixin + dart:async/offline/player/recommendations imports). Lifecycle tests moved to `test/app/lifecycle_coordinator_test.dart`; the now-unused `flutter/services.dart` import removed from `test/router_test.dart`.
- **A10 — `lib/services/` (new):** transport+JSON seams so providers no longer call `dio` / parse envelopes inline:
  - `SubsonicLibraryService` — all Subsonic reads (`getAlbum(s)`, `getArtist(s)`, `getPlaylist(s)`, `search3`, `getAlbumList`, `getRandomSongs`, `getStarredSongs`, `findLibraryMatch` for the N4 cross-ref).
  - `PlaylistService` — Subsonic mutations (`createPlaylist`/`updatePlaylist`/`deletePlaylist`/`getPlaylistEntryIds`).
  - `BackendService` — all heerr-REST calls (`ytmSearch`, `recommend`, `recommendHealth`, `getQueue`, `download`, `jobStatus`).
  - `LyricsService` — two-stage Navidrome `getLyricsBySongId` → LRCLib fallback.
  - Each exposes an async `*ServiceProvider` that reads the existing `subsonicDioClientProvider` / `dioClientProvider`, so the service uses whatever dio those providers yield — **existing dio-adapter test mocks pass unchanged**.
- **Providers delegating now (state/orchestration only):** `library/library_album(s)`, `library/library_artist(s)`, `library/library_playlist(s)`, `library/library_search`, `library/lyrics`, `library/playlist_mutations`, `home/home_providers`, `recommendations`, `search`, `queue`, `download`, `job_status`. Debounce / cancel-token / dedupe / index-ordering / provider-invalidation stay in the providers (they need a `Ref`).
- **Offline subsystem:** no change required — `offline/offline_downloader.downloadSong` is already an injected-`Dio` seam, and `offline/offline_sync` orchestrates via existing library providers + the `offlineDownloadDio` seam (no inline transport+JSON).
- **Tests:** new `test/services/subsonic_library_service_test.dart` (5 cases) proves the seam is unit-testable **without a Riverpod container** (service built directly from a Dio + scripted adapter). `dart run build_runner build` regenerated `.g.dart` for the new service providers.
- `flutter analyze` clean (only the pre-existing `main.dart:25` workmanager deprecation); full suite 573 green (+5). Resolves DEBT §5 A8 + A10.

## 2026-06-20 — A11: session-stable salt for cover-art / stream URLs

- **`lib/api/subsonic_client.dart`:** added `sessionStableSalt()` — a process-lifetime salt lazily initialised from `_randomHexSalt()`. Made it the default for both read-only URL builders (`buildSubsonicCoverArtUrl`, `buildSubsonicStreamUrl`), replacing the per-call `_randomHexSalt`. Same `coverArtId`+`size` now yields a byte-identical URL across renders, so Flutter's URL-keyed image cache hits instead of cold-fetching every tile on every Library/Home scroll.
- The salt is independent of the password (`t = md5(password+salt)` recomputes), so a profile switch keeps producing valid tokens from the same salt — no reset needed.
- `SubsonicAuthInterceptor` (all API + state-mutating calls) is unchanged: it still rotates the salt per request.
- Doc comments on both builders updated (the old "salt rotates per call → defeats cache, K1+ work" caveat is now resolved).
- **Tests:** new "A11" group in `test/api/subsonic_client_test.dart` — cover-art URL identical across two calls, stream URL identical across two calls, explicit `saltGenerator` still overrides. `flutter analyze` clean; full suite 576 green (+3). Resolves DEBT §5 A11.

## 2026-06-20 — A21 (Flutter CI) + A18 (dev_defaults leak check)

- **A21 — `.github/workflows/android-ci.yml` (new):** runs `flutter analyze` + `flutter test` on PRs to `main` and pushes to `main`, path-filtered to `android/**` (+ the workflow file). Setup mirrors `android-publish.yml`: Java 17, Flutter 3.44.0, `working-directory: android/app`, seeds `lib/dev_defaults.dart` from the all-null example, `flutter pub get`, then `dart run build_runner build`. No keystore/secrets — this job never builds a signed artifact. Enforces the "green before / green after" gate from `android/CLAUDE.md §Development workflow` pre-merge instead of by hand. Resolves DEBT §5 A21.
- **A18 — dev_defaults leak check (no code change):** verified `lib/dev_defaults.dart` is gitignored (`git check-ignore` matches), untracked, and absent from history (`git log --all` empty for it). It holds a Tailnet IP + username but no token; `dev_defaults.example.dart` is all-null. The DEBT premise ("is committed") was stale — marked accordingly, no action needed.

## 2026-06-20 — A3: stateless auth interceptors (resolve creds per request)

- **`lib/api/client.dart`:** `BearerAuthInterceptor` now takes a `String? Function() tokenResolver` instead of a captured `token` value; `onRequest` calls it per request. `dioClient` wires `() => ref.read(activeProfileProvider)?.heerrBearerToken` and now `ref.watch(activeProfileProvider.select((p) => p?.heerrBaseUrl))` — so the dio rebuilds only when the backend base URL changes.
- **`lib/api/subsonic_client.dart`:** `SubsonicAuthInterceptor` now takes `usernameResolver` / `passwordResolver` (was captured `username`/`password`); `subsonicDioClient` wires them to `ref.read(activeProfileProvider)` and watches `select(navidromeBaseUrl)`.
- **Effect:** a same-server credential rotation (token refresh / Navidrome password change) no longer rebuilds the `Dio` — the connection pool + interceptor chain survive and the next request picks up the new credential. A base-URL change (different server) still rebuilds, as required.
- **Tests:** `test/api/client_test.dart` — replaced the old "rebuilds on token change" test with an A3 pair: token rotation on the same base URL keeps the *same* dio instance while `tokenResolver()` returns the new token; a base-URL change rebuilds. `test/api/subsonic_client_test.dart` + `client_test.dart` construction sites updated to pass resolvers; the provider introspection assertions call `usernameResolver()` / `passwordResolver()` / `tokenResolver()`. `flutter analyze` clean; full suite 577 green. Resolves DEBT §5 A3.

## 2026-06-20 — A12/A13/A14: offline-sync perf + robustness

- **A12 — download worker pool (`offline/offline_sync.dart` `_runTick`):** the shared work source is now an explicit `Queue<Song>` (`removeFirst()` pulls atomically — no await between the emptiness check and the pull) and `songsState` is a mutable map mutated in place (`songsState[id] = result`) instead of a reassigned-via-spread `List`. The "no double-download" invariant is now enforced by the type rather than by reasoning about event-loop interleaving.
- **A13 — target resolution (`_resolveTargets`):** new `_forEachBounded` helper (shared `Queue` + `_kResolveConcurrency = 4` workers) replaces the three fully-sequential `await` loops (artist→albums fan-out, album detail, playlist detail). Caps concurrent library requests while collapsing the previously serial walk — meaningfully faster sync-all ticks on large libraries. `albumIds.add` / `out[id] = song` are atomic on the single isolate, so the dedup-by-key contract is preserved.
- **A14 — connectivity-stream trigger:** `WifiCheck` gained `Stream<bool> get onWifiChanged` (production maps `Connectivity().onConnectivityChanged`; the abstract default never emits). `OfflineSync.build` subscribes via `_subscribeWifi` and fires an off-schedule `_tick()` on a false→true Wi-Fi transition (guarded by `_paused`/`_running`; `_runTick` re-checks every gate so a spurious event is idempotent). The subscription is cancelled on rebuild and `onDispose` alongside the Timer.
- **Tests:** `test/offline/offline_sync_test.dart` — new "A14" case (no-WiFi build → no downloads; `wifi.emit(true)` → off-schedule download tick). The `_FakeWifi` fake gained a broadcast `onWifiChanged` + `emit()`; `background_sync_test.dart`'s fake stubs the empty stream. `flutter analyze` clean; full suite 578 green (+1). Resolves DEBT §5 A12/A13/A14 — completes P2.

## 2026-06-20 — A17: split large screen files into `part` siblings (+ P3 triage)

- **A17 — widget-file splits (`part`/`part of`, privacy preserved, no caller import changes):**
  - `screens/player/now_playing_screen.dart` 756→326; extracted `now_playing_lyrics.dart` (`_LyricsPane`, `_LyricsBox`), `now_playing_transport.dart` (`_Scrubber`, `_Transport`, `_QueueList`), `now_playing_sleep_timer.dart` (`_SleepCountdownChip`, `_SleepTimerSheet`, `_CustomMinutesDialog`).
  - `screens/library/library_screen.dart` 615→134; extracted `library_search_results.dart` (`_SearchModeScaffold`, `_CombinedResultsBody`, `_YtmSection`, `_ErrorView`) and `library_tabs.dart` (`_ArtistsTab`, `_AlbumsTab`, `_PlaylistsTab`, `_SectionHeader`, `_SubSectionHeader`).
  - `screens/settings_screen.dart` 562→56; extracted `settings_recommendations.dart` (`_RecommendationsSection`, `_StatusChip`, `_FallbackBadge`) and `settings_offline.dart` (`_OfflineSection`, `_SyncNowAction`, `_StorageLine`, `_ClearAllAction`, `_SyncAllTile`, `_humanBytes`).
  - `screens/library/playlist_detail_screen.dart` 606→556; extracted `playlist_detail_header.dart` (`_PlaylistHeader`, `_PlaylistAction`) — the rest is one large `State` class, not cleanly widget-extractable.
- **P3 triage (no code):** A20 (`Settings.clear()` half-wipe) and A22 (`app/ios/` baggage) confirmed **stale** — `providers/settings.dart` was deleted in A6 and no `app/ios/` folder exists. A16 (screen re-foldering) and A19 (records→freezed) closed **won't-fix** with rationale (cosmetic/high-churn; records already have value equality). See DECISIONLOG.
- `flutter analyze` clean; full suite 578 green. Resolves DEBT §5 A17; closes the P3 band and the whole §5 architectural backlog.

## 2026-06-20 — v3.2.0: DEBT §5 architectural backlog (refactor-only release)

- On-device release-APK smoke passed (SMOKE-TEST.md §14a): service-layer (A8/A10), lifecycle (A8/A2/A15), interceptor (A3), cover-art salt (A11), and offline-sync (A12–A14) refactors verified behaviour-preserving; A17 file splits covered by the read/playback passes.
- `DEBT.md`: V7 marked ✅; the full §5 architectural backlog (A1–A22) is closed/triaged.
- `pubspec.yaml`: 3.1.2 → 3.2.0.
- SMOKE-TEST.md deleted (gitignored local working doc; the committed record is the V7 row above).
- Promoted: `v3.2.0-rc3` → `v3.2.0`.

## 2026-06-21 — v3.2.1: fix media-notification / lockscreen / AOD app icon (issue #23)

- **Symptom:** the media notification rendered a blank white circle for the app icon on the lockscreen and always-on display (AOD) instead of the heerr mark.
- **`lib/main.dart`:** set `AudioServiceConfig.androidNotificationIcon` to `'drawable/ic_stat_heerr'` (the default `mipmap/ic_launcher` silhouettes the full-colour adaptive icon into a solid blob). Also dropped the deprecated `isInDebugMode:` arg from `Workmanager().initialize` (it had no effect and tripped `flutter analyze`, failing CI).
- **`lib/player/song_to_media_item.dart`:** when a song has no `coverArt`, fall back to `artUri = android.resource://com.aashish.heerr/mipmap/ic_launcher` so the media-card large-icon area is never blank. `test/player/song_to_media_item_test.dart` updated to expect the fallback.
- **Status-bar / lockscreen small icon:** added `res/drawable-*dpi/ic_stat_heerr.png` (white monochrome silhouette of the app mark, derived from the 1024² source art) at all five densities. Notification small icons must be alpha-only — a colour icon renders as a blob.
- **Resource-shrinker keep rule (`res/raw/keep.xml`):** `ic_stat_heerr` is referenced only at runtime via audio_service's `Resources.getIdentifier()`, invisible to R8 `shrinkResources`. Without `tools:keep="@drawable/ic_stat_heerr"` the release build stripped it, producing a notification with no valid small icon → `IllegalArgumentException` crash on play. This was the root cause of the "playing any song crashes" regression.
- **AOD app badge (`res/mipmap-anydpi-v26/ic_launcher.xml`):** added a `<monochrome>` layer (`res/drawable-*dpi/ic_launcher_monochrome.png`, all densities). Android 13+ uses the adaptive icon's monochrome layer for the themed app badge on AOD; its absence was the blank white circle on the always-on display.
- **`pubspec.yaml`:** 3.2.0 → 3.2.1.

## 2026-06-21 — #22: show playlist run time in detail header

- **`lib/screens/library/playlist_detail_header.dart`:** the header meta line now combines song count and total run time, joined with " · " (e.g. `12 songs · 1 hr 6 min`). New `_metaLine` builds the parts (song count when `songCount != null`, run time when `duration != null && > 0`) and returns null when neither is known; new `_formatRuntime` renders the whole-playlist `Playlist.duration` (seconds, already supplied by Subsonic `getPlaylist`) as a coarse `H hr M min` / `M min` form (seconds dropped — playlist totals are minutes-scale). No-duration playlists still render just "N songs".
- **`test/screens/library/playlist_detail_screen_test.dart`:** new "run time in header (#22)" group — under-an-hour (`2820s → 2 songs · 47 min`), over-an-hour (`3960s → 3 songs · 1 hr 6 min`), and no-duration (song count only, no separator). `flutter analyze` clean; full suite 581 green.
- **`pubspec.yaml`:** 3.2.1 → 3.3.0. Tagged `v3.3.0-rc1`.

## 2026-06-21 — #16: repeat (loop-one / loop-all) and shuffle

- **`lib/player/heerr_audio_handler.dart`:** added `_repeatMode` / `_shuffleMode` fields; `setRepeatMode` overrides map `AudioServiceRepeatMode` → `just_audio.LoopMode` via `_toLoopMode` and call `_player.setLoopMode`; `setShuffleMode` calls `_player.setShuffleModeEnabled`. Both push a `copyWith` to `playbackState`. `_broadcastPlaybackState` now includes `repeatMode`/`shuffleMode` on every playback event so state survives player interrupts.
- **`lib/screens/player/now_playing_transport.dart`:** `_Transport` gains `repeatMode` and `shuffleMode` params. Shuffle button (left of prev) toggles `AudioServiceShuffleMode.none`↔`all`; lit in primary colour when on. Repeat button (right of next) cycles `none→all→one→none` with `repeat`/`repeat_one` icons; lit when active.
- **`lib/screens/player/now_playing_screen.dart`:** `_Transport` call site passes `snapshot.state.repeatMode` and `snapshot.state.shuffleMode`.
- **`test/player/heerr_audio_handler_modes_test.dart`** (new): mocktail-mocked `AudioPlayer`; verifies `setRepeatMode` none/one/all/group → correct `LoopMode` + broadcast, and `setShuffleMode` all/none → `setShuffleModeEnabled(true/false)` + broadcast (6 cases).
- **`test/screens/player/now_playing_modes_test.dart`** (new): mocktail-mocked `HeerrAudioHandler` injected via `audioHandlerProvider`; verifies shuffle/repeat icons render, `repeat_one` icon on repeat-one state, and the full tap cycle (repeat none→all→one→none, shuffle off↔on) dispatches the right handler calls (7 cases). `flutter analyze` clean; full suite 594 green.

## 2026-06-21 — #27: subtler Picked-for-you card actions (overlay icons)

- **`lib/widgets/home_recommendation_card.dart`:** replaced the two full-width `FilledButton.icon` (solid-green Play / Download) below each card with translucent circular overlays on the cover art. In-library tracks get a centered play disc (`Key('rec-play')`); remote tracks get a bottom-right download disc (`Key('rec-download')`) that shows a spinner and goes non-interactive while a download is in flight. New private `_OverlayAction` (translucent black `Material` circle + `InkWell` + `Tooltip`) renders the disc; functionality (`_onPlay` / `_onDownload`) unchanged. Card is now shorter — the action no longer occupies a row beneath the title/artist.
- **`test/widgets/home_recommendation_card_test.dart`:** play/download assertions switched from `find.text(...)` to `find.byKey(Key('rec-play'|'rec-download'))`; added an in-flight case (first tap → spinner shown + `CircularProgressIndicator`; second tap does not re-dispatch). `flutter analyze` clean; full suite 595 green.

## 2026-06-21 — #17: collapsible settings sections

- **`lib/screens/settings_screen.dart`:** the three sections (Profiles / Offline downloads / Recommendations) are now wrapped in a new private `_CollapsibleSection` (an `ExpansionTile` with leading icon + bold title, keyed `settings-section-<title>`). Profiles stays `initiallyExpanded: true`; Offline + Recommendations start collapsed to de-clutter the screen. Removed the inter-section `Divider`s (ExpansionTile borders separate them).
- **`lib/screens/settings/profiles_section.dart`, `lib/screens/settings_offline.dart`, `lib/screens/settings_recommendations.dart`:** dropped each section's inline bold title `Padding` — the ExpansionTile header now provides the title.
- **`test/screens/settings_screen_test.dart`:** new `_expandSection(tester, title)` helper taps a section header by key; Offline + Recommendations test groups expand their section before asserting on now-collapsed content. New "Collapsible sections (#17)" group: all three headers render; Profiles expanded by default while others are collapsed; collapsed Offline expands on tap. `flutter analyze` clean; full suite 598 green.

## 2026-06-21 — #20: Now Playing home-screen widget

- **`pubspec.yaml`:** added `home_widget: ^0.9.3`.
- **`lib/widget/now_playing_widget.dart`** (new): `HomeWidgetClient` seam over the static `HomeWidget` API (impl `HomeWidgetClientImpl`) + `NowPlayingWidgetUpdater.push(PlayerSnapshot)`, which maps the snapshot onto data keys (`np_has_track`/`np_title`/`np_artist`/`np_playing`) and calls `updateWidget`. Null item → `clear()`; all failures swallowed so a missing/unadded widget never breaks playback.
- **`lib/widget/now_playing_widget_provider.dart`** (new): keep-alive `nowPlayingWidgetProvider` side-effect provider, mirrors `nowPlayingPersistence` pattern — `ref.listen(playerSnapshotProvider, fireImmediately: true)` pushes each emission through the updater.
- **`lib/main.dart`:** `HeerrApp.build` watches `nowPlayingWidgetProvider` for the subscription side effect.
- **Native (out of TDD scope — APK build + on-device smoke gate):**
  - `android/app/src/main/kotlin/com/aashish/heerr/NowPlayingWidgetProvider.kt` (new): extends `HomeWidgetProvider`; renders title/artist/play-pause icon from the widget SharedPreferences. Transport buttons fire `ACTION_MEDIA_BUTTON` (`KEYCODE_MEDIA_PLAY_PAUSE`/`NEXT`/`PREVIOUS`) broadcasts to `com.ryanheise.audioservice.MediaButtonReceiver` → drives the live audio_service MediaSession (no background isolate, no second player). Body tap → `HomeWidgetLaunchIntent` opens MainActivity.
  - `res/layout/now_playing_widget.xml`, `res/xml/now_playing_widget_info.xml`, `res/drawable/widget_background.xml` (new): RemoteViews layout + AppWidgetProviderInfo + rounded dark surface.
  - `AndroidManifest.xml`: registered the `.NowPlayingWidgetProvider` `<receiver>` with `APPWIDGET_UPDATE` filter + provider meta-data.
  - `proguard-rules.pro`: keep `es.antonborri.home_widget.**` (release R8 defence, mirrors the audio_service keep rule per DEBT.md).
- **`test/widget/now_playing_widget_updater_test.dart`** (new): mocktail-mocked `HomeWidgetClient`; 5 cases (playing track writes all fields + update; paused → playing=false; null artist → empty string; null item → cleared; client error never throws). Red-first.
- Verified: `flutter analyze` clean; full suite 603 green; `flutter build apk --debug` succeeds (Kotlin/manifest/resources compile). **Not yet smoke-tested on device** (G-milestone gate). Album art deferred — see DEBT.md.

## 2026-06-21 — #20 follow-up: album art on the Now Playing widget

- Feedback: the widget worked but the all-black background looked bland — show the streaming song's artwork.
- **`lib/widget/now_playing_widget.dart`:** new `WidgetArtCache` seam (impl `WidgetArtCacheImpl`: Dio bytes GET → `getApplicationSupportDirectory()/np_widget_art.png`). `NowPlayingWidgetUpdater` gained an optional `artCache` + a new `np_art_path` data key. `push` resolves the cover path via `_resolveArtPath`, which fetches **once per track** (guards on `artUri` so play/pause/buffer emissions don't re-download) and only for http(s) URIs (the launcher-resource fallback → empty path). `clear()` and null item reset the path + guard.
- **`lib/widget/now_playing_widget_provider.dart`:** wires `WidgetArtCacheImpl()` into the updater.
- **`pubspec.yaml`:** already had `dio` + `path_provider` (no new deps).
- **Native:** `now_playing_widget.xml` rebuilt as a `FrameLayout` — full-bleed `centerCrop` `@id/widget_art` ImageView + `#99000000` scrim + the existing text/controls on top. `NowPlayingWidgetProvider.kt` reads `np_art_path`, `BitmapFactory.decodeFile`s it (same-uid app-private file) and `setImageViewBitmap`s the background; falls back to the plain rounded `widget_background` drawable when absent/unreadable.
- **`test/widget/now_playing_widget_updater_test.dart`:** new "album art" group (5 cases: http artUri caches + saves path; same track doesn't re-download; track change re-downloads; non-http skips cache → empty path; null item clears path). Red-first.
- Verified: `flutter analyze` clean; full suite **608** green; `flutter build apk --debug` succeeds. Still pending on-device smoke (see DEBT.md).

## 2026-06-21 — #21: "For You" screen uses Home-style recommendation cards

- Issue #21: the full-screen "For You" feed (reached from Library → Playlists → "For You") rendered bland bare `ListTile` rows (title/artist + a full-width Download/Play button, no cover art) — visually inconsistent with Home's "Picked for you" section.
- **`lib/screens/recommendations_screen.dart`:** data branch now renders the existing `HomeRecommendationCard` (cover-art card with overlay play/download disc) in a 2-column `GridView` instead of the `ListView` of `_RecommendationTile`. Card width derived from the viewport (`(width - 2*16 - 12) / 2`); `childAspectRatio = w/(w+56)` keeps the title/artist lines below the cover unclipped. Removed the now-unused `_RecommendationTile` class and its `dart:async`/`subsonic/song`/`playback_actions`/`download`/`error_snackbar`/`skeleton`-adjacent imports that it solely used; added the `home_recommendation_card` import.
- **`test/screens/recommendations_screen_test.dart`:** updated to assert the card affordances — overlay discs by `Key('rec-download')` / `Key('rec-play')` instead of `'Download'`/`'Play'` text, and the in-library Play disc now resolves its card via `HomeRecommendationCard` ancestor (was `ListTile`). Red-first: 4 cases failed on the new keys before the screen change, green after.
- Verified: `flutter analyze` clean; full suite **608** green. No native/manifest changes, so no APK rebuild. On-device visual smoke still the user's call.

## 2026-06-21 — Now Playing overflow: "Add to playlist"

- Request: the Now Playing 3-dot menu only offered "Sleep timer"; the playing track could only be favourited, not added to a playlist.
- **`lib/screens/player/now_playing_screen.dart`:** added an "Add to playlist" item (key `now-playing-add-to-playlist`) to the overflow `PopupMenuButton`, above "Sleep timer". On select, `_openAddToPlaylist` reads the current `playerSnapshotProvider` item, maps it to a Subsonic `Song` via `songFromMediaItem` (the song id lives in the MediaItem `subsonicId` extra, not `id` which is the stream URL), and opens the existing `AddToPlaylistSheet.show(songIds:[id], findSimilarSeed: seedForSong(song))` — same sheet used by song-row long-press. Tracks with no `subsonicId` extra (non-Subsonic playback) get a "Can't add this track to a playlist" snackbar instead. Both menu items now render as `ListTile`s with leading icons (playlist_add / bedtime_outlined).
- **`test/screens/player/now_playing_add_to_playlist_test.dart`:** new file, 3 cases (menu exposes the item alongside Sleep timer; tapping opens the sheet for the 1 playing song; non-Subsonic track shows the snackbar, not the sheet). Red-first.
- Verified: `flutter analyze` clean; full suite **611** green (was 608). No native/manifest changes, so no APK rebuild.

## 2026-06-21 — Fix: Now Playing widget would not add / rendered blank

- Symptom (first on-device test of #20): the home-screen widget could not be added / showed blank.
- **`app/android/app/src/main/res/layout/now_playing_widget.xml`:** the three transport ImageButtons used `?android:attr/selectableItemBackgroundBorderless` as `android:background`. Theme-attribute (`?attr/...`) references are inflated against the launcher's process in a RemoteViews layout and are a known cause of inflation failure ("Problem loading widget" / blank / can't add). Replaced all three with `@android:color/transparent`.
- Verified: `flutter build apk --debug` succeeds. **Not yet confirmed on device** — see DEBT.md #20 entry; if it persists, capture `adb logcat` to pin the exception (R8 on release is a separate candidate).

## 2026-06-21 — Fix (real): Now Playing widget blank — bare <View> illegal in RemoteViews

- rc10 guessed the cause was the `?attr` button background; on-device logcat proved otherwise.
- Root cause (confirmed): the dark-scrim was a bare `<View>` at line 23 of `now_playing_widget.xml`, and `android.view.View` is not in the RemoteViews-allowed class whitelist. Launcher logged `InflateException: ... Class not allowed to be inflated android.view.View`, so the widget failed to inflate → blank / would not add.
- **`app/android/app/src/main/res/layout/now_playing_widget.xml`:** changed the scrim `<View>` → empty `<FrameLayout>` (an allowed RemoteViews class) with the same `#99000000` background. (rc10's transparent-background change is retained — harmless.)
- Verified: `flutter build apk --debug` succeeds. **Not yet smoke-tested on device** — debug APK can't install over the existing build (signing-key mismatch); needs an uninstall (wipes profile/login) or a matching-key build. See DEBT.md #20.

## 2026-06-22 — Widget redesign (4x1, no bitmaps) + cover-colour tint; Now Playing screen tint boost

- The cover-art widget kept failing on device (blank / unreliable on skip; the temp-file rename regressed to ENOENT). Scrapped cover art and rebuilt the widget as a simple, robust tile.
- **`lib/widget/now_playing_widget.dart`:** removed `WidgetArtCache`/`WidgetArtCacheImpl`, `np_art_path`, and all the staleness/in-flight/temp-file machinery. Widget now pushes title/artist/playing + position/duration (millisecond strings) + a cover-derived tint. New `WidgetTintExtractor` seam (`WidgetTintExtractorImpl` reuses `dominantColorFor`, darkens ~50% for legibility, returns a signed-32-bit ARGB int); tint resolved once per track, pushed as `np_tint_argb`.
- **`lib/widget/now_playing_widget_provider.dart`:** wires `WidgetTintExtractorImpl`.
- **Native `NowPlayingWidgetProvider.kt`:** removed `BitmapFactory`/`decodeScaledBitmap`/art. Reads title/artist/playing, parses position/duration strings → `setProgressBar`, parses `np_tint_argb` → `setInt(widget_root,"setBackgroundColor",..)`. Media-button controls unchanged.
- **Native layout `now_playing_widget.xml`:** rebuilt as a horizontal 1-row tile (title/artist + `ProgressBar` + prev/play-pause/next `ImageButton`s). Only RemoteViews-whitelisted views — no `ImageView`/`View`.
- **`now_playing_widget_info.xml`:** resized 3x2 → 4x1 (minWidth 250dp, minHeight 40dp, targetCell 4x1, resize horizontal).
- **`lib/utils/palette.dart`:** richer swatch fallback (vibrant → light/dark-vibrant → muted → dominant) so dark covers still yield a hue.
- **`lib/screens/player/now_playing_screen.dart`:** strengthened the screen tint gradient (`0.85 → 0.35 → surface` over `0–45–90%`, was `0.45 → surface` over `0–65%`).
- **`test/widget/now_playing_widget_updater_test.dart`:** rewritten — dropped the art-race tests, added position/duration string tests and a tint group (per-track extraction, non-http skip, null result). Red-first.
- Verified: `flutter analyze` clean; full suite **611** green; debug APK builds and the widget loads on the Pixel 7. Cover-colour tint pending final on-device eyeball.

## 2026-06-22 — Widget visual polish (icons, rounded tile, drop progress bar)

- On-device design tweaks to the #20 widget after the redesign:
- **Icons:** replaced the framework `@android:drawable/ic_media_*` (grey/bordered, small) with custom white Material **vector** drawables (`widget_ic_previous/play/pause/next.xml`) — rounded-corner glyph variants, no chrome. Sized ~15% larger (prev/next 55dp, play 60dp ImageButtons, fitCenter); transparent backgrounds (no button border/disc); play button white (was green).
- **Tile:** corner radius 20dp → 28dp (`widget_background.xml`). Cover tint now recolors the rounded shape via `setColorStateList(..,"setBackgroundTintList",..)` (API 31+ guard) instead of `setInt(..,"setBackgroundColor",..)`, so the rounded corners survive when tinted.
- **Progress bar removed** (`now_playing_widget.xml` `ProgressBar`, the native `setProgressBar` render, and the Dart `np_position_ms`/`np_duration_ms` push + their tests).
- Net widget data keys: `np_has_track`, `np_title`, `np_artist`, `np_playing`, `np_tint_argb`.
- Verified: `flutter analyze` clean; full suite **609** green; APK builds and installs on the Pixel 7.

## 2026-06-22 — Widget: re-add cover art as a full-bleed left thumbnail

- Per request, the cover is back — but as a small **left thumbnail** (not the old full-bleed background that caused the blank/crash bugs).
- **`lib/widget/now_playing_widget.dart`:** re-added `WidgetArtCache`/`WidgetArtCacheImpl` (Dio bytes → per-URL file, unique temp + atomic rename) and `np_art_path`. `NowPlayingWidgetUpdater` gained an optional `artCache`; `_resolveArtPath` fetches once per track with in-flight coalescing + a staleness guard (no skip races, no ENOENT).
- **`lib/widget/now_playing_widget_provider.dart`:** wires `WidgetArtCacheImpl`.
- **Native `NowPlayingWidgetProvider.kt`:** reads `np_art_path`, decodes downsampled (`decodeScaledBitmap`, cap 192px → tiny bitmap, no TransactionTooLarge), `setImageViewBitmap` on the left `widget_art` ImageView; `GONE` when absent.
- **Layout:** added a left `ImageView` (80dp, `match_parent` height, `centerCrop`); dropped the root padding so the cover bleeds to the left/top/bottom edges (launcher rounds the corners on API 31+); re-inset the text column; right margin on the next button.
- **`test/widget/now_playing_widget_updater_test.dart`:** added a cover-thumbnail group (caches once per track, concurrent-fetch coalescing, non-http skip, null-item clear).
- Verified: `flutter analyze` clean; full suite **614** green; builds + installs on the Pixel 7.

## 2026-06-22 — Widget sizing (v3.3.0)

- **`now_playing_widget_info.xml`:** default span 4x1 → 3x1, minWidth 250→200dp (narrower default).
- **`now_playing_widget.xml`:** tile no longer fills the whole cell — wrapped in an outer full-height vertical LinearLayout with weighted empty-LinearLayout spacers so the visible tile is centred at **90% of the cell height** (weights 1/18/1; RemoteViews has no percentage height, and a bare `<View>` spacer isn't inflatable). Cover thumbnail widened to 80dp and fills the tile height.
- Note: a home-screen widget still occupies whole grid cells (launcher constraint); only the visible tile height/width within the allotted cells is controlled here.
- Verified: `flutter analyze` clean; full suite **614** green; builds + installs on the Pixel 7. Tagged **v3.3.0**.

## 2026-06-22 — Bar + pill Now Playing widgets (v3.4.0)

- Two new home-screen widgets alongside the classic tile, sharing the same `home_widget` `np_*` data contract (one Dart push feeds all three; any not added is a no-op).
- **Bar widget (3x1, resizable to 4x1):** thin tile centred at ~50% of the cell height (weighted 1/2/1 spacers). Animated heerr-green waveform (left) + inline title/artist (centre) + display-only progress bar (right). No transport controls, no cover art. Tap opens the app.
  - New: `res/layout/bar_widget.xml`, `res/xml/bar_widget_info.xml`, `kotlin/.../BarWidgetProvider.kt`.
- **Pill widget (2x1):** chubby tile at ~90% cell height on a fully-rounded background (200dp corners → semicircle ends). Cover art is a true circle (rounded natively via `BitmapShader`) inset by a uniform 8dp margin (start = top = bottom) so a dark ring of the pill shows around it and the left rounded end stays visible. The uniform margin keeps the art centred at H/2 — concentric with the pill's left-end semicircle. The ImageView is `match_parent` height + `wrap_content` width + `adjustViewBounds`, so the square bitmap forces the box square at any pill height (no hard-coded dp). `fitCenter` so it never crops or squashes; stacked title/artist; animated waveform. Tap opens the app.
  - New: `res/layout/pill_widget.xml`, `res/xml/pill_widget_info.xml`, `res/drawable/widget_pill_background.xml`, `kotlin/.../PillWidgetProvider.kt`.
- **Animated waveform:** RemoteViews has no custom view, so the motion is a `ViewFlipper` cycling 8 pre-baked vector frames (`res/drawable/widget_wave_1..8.xml`) at 120ms — host-driven, no redraw churn, no bitmaps. heerr-green only (`#1DB954`). The frames are a sine wave sampled at advancing phase across 5 bars centred on the mid-line, so both the top and bottom of each bar move and the whole thing reads as a smooth travelling wave (not bottom-anchored equaliser bars). 8 frames × 120ms ≈ a ~1s loop. **Play/pause sync:** the flipper is overlaid (in a `FrameLayout`) on a static frame; both providers toggle visibility off `np_playing` so the wave animates only during playback and freezes when paused. A home-screen widget has no live audio-amplitude API, so play/pause is the only state the bars can reflect — true amplitude-reactive bars are not possible.
- **Progress (bar only):** new `res/drawable/widget_progress.xml` (dark track + green rounded fill). Display-only — `ProgressBar` isn't touch-seekable in RemoteViews. Driven by two new data keys `np_position_ms` / `np_duration_ms`. Snapshots emit only on transport changes, so the bar snaps to the new position on play/pause/seek/track-change rather than ticking continuously (battery-safe trade-off — a continuous tick would need periodic widget redraws).
- **`lib/widget/now_playing_widget.dart`:** added `kBarWidgetName` / `kPillWidgetName` consts + `kNpKeyPositionMs` / `kNpKeyDurationMs`; `push()`/`clear()` write position+duration; `HomeWidgetClientImpl.update()` now redraws all three widget names.
- **Manifest:** two new `<receiver>` entries (`.BarWidgetProvider`, `.PillWidgetProvider`).
- **`test/widget/now_playing_widget_updater_test.dart`:** added position+duration write, unknown-duration→0, and null-item clear assertions.
- Verified: `flutter analyze` clean; widget-updater suite green (19 tests); `flutter build apk --debug` succeeds (Kotlin + resources compile). On-device add-to-home-screen verification pending. Tagged **v3.4.0** after smoke.

## 2026-06-23 — Phase T (T1–T4): stream-first preview of YouTube Music results — v3.5.0

Preview (stream) a YouTube-Music search result before downloading it into Navidrome. Consumes the backend Phase K `/preview/stream` proxy. Pure-client slice. ADR: `DECISIONLOG.md` 2026-06-23. Roadmap T1–T5; T5 is the on-device smoke (pending). Recommendation/home preview deferred to DEBT F3.

- **`lib/api/endpoints.dart`** (T1) — `previewStream = '/preview/stream'` (bare path; base URL already includes `/api/v1`).
- **`lib/player/preview_url.dart`** (new, T1) — pure `buildPreviewStreamUrl({heerrBaseUrl, sourceUrl, token})` → absolute proxy URL, both params percent-encoded via `Uri`. Bearer rides in `?token=` (just_audio can't set headers). Tests: encoding, round-trip, trailing-slash.
- **`lib/player/search_result_to_media_item.dart`** (new, T2) — pure `searchResultToMediaItem({item, heerrBaseUrl, token})` → `MediaItem` with `id` = the preview URL (third id kind beside Subsonic-stream and `file://`), `extras: {preview: true, sourceUrl}`, YouTube-thumbnail art with the launcher fallback. Bypasses `songToMediaItem`. 6 tests.
- **`lib/player/playback_actions.dart`** (T2) — `playPreview(ref, context, SearchResultItem)` reads `heerrBaseUrl`/`heerrBearerToken` from `activeProfileProvider`, builds the preview `MediaItem`, routes through `audioHandlerProvider.playSong`. "Preview: <title>" snackbar; not-signed-in guard.
- **`lib/widgets/preview_badge.dart`** (new, T3) — shared `PreviewBadge` pill + `isPreviewMediaItem(item)`.
- **`lib/widgets/result_tile.dart`** (T3) — `onPreview` → `play_circle_outline` button in the trailing row beside the download affordance; independent of download state.
- **`lib/screens/library/library_search_results.dart`** (T3) — YT results pass `onPreview: () => playPreview(ref, context, item)`.
- **`lib/widgets/mini_player.dart`** + **`lib/screens/player/now_playing_screen.dart`** (T3) — "Preview" badge while a preview stream is current. Mini-player renders it inline on the artist line (stacking overflowed the 56px bar). Tests: `result_tile_test.dart` (4) + 2 in `mini_player_test.dart`.
- **`android/app/pubspec.yaml`** (T4) — `3.4.0` → `3.5.0`.
- **`android/docs/{DECISIONLOG,ROADMAP,DEBT}.md`** (T4) — Phase T ADR; ROADMAP `MediaItem.id` cross-cutting reminder amended for the preview-URL kind (the reminder lives in ROADMAP, not CLAUDE.md — corrected from the T4 plan text); DEBT F3 records the recommendations/home preview follow-up.
- Verified: `flutter analyze` clean; full suite **632** passed.

## 2026-06-24 — Phase U (U1): download-to-playlist — optional playlist assignment on YTM download

Tapping the download icon on a YouTube-Music search result now opens a bottom sheet offering either a plain download (existing behaviour) or download-and-add-to-playlist: once the backend job completes and Navidrome indexes the new file, the song is added to a chosen Navidrome playlist. Pure-client slice — no backend change. Async orchestration is a top-level function (no persistent Riverpod state), mirroring `playPreview` / `playSongFromSubsonic`.

- **`lib/widgets/download_options_sheet.dart`** (new) — `DownloadOptionsSheet` `ConsumerWidget` + static `show()`. Presentational only. Layout: song title → "Download" `ListTile` (key `download-options-download-only`) → divider → "Add to playlist after download" → owned playlists from `libraryPlaylistsProvider` filtered by `serverCredsProvider.navidromeUsername` (one `ListTile` per playlist, key `download-to-playlist-<id>`; loading/error/empty states). Each tap pops the sheet first, then invokes the `onDownloadOnly` / `onDownloadToPlaylist(id, name)` callback.
- **`lib/providers/download_to_playlist.dart`** (new) — `downloadAndAddToPlaylist({ref, context, item, playlistId, playlistName, ...})`. Steps (each `await` guarded by `context.mounted`): dispatch via `downloadDispatcherProvider` + "Downloading…" snackbar (ApiError → `showApiError`); poll `BackendService.jobStatus` to terminal when non-terminal (`failed` → error snackbar; timeout → snackbar); poll `SubsonicLibraryService.findLibraryMatch` (transient ApiError keeps polling; null at ceiling → "not indexed yet" warning); `PlaylistMutations.addSongs` + success snackbar. `@visibleForTesting` poll-interval / ceiling knobs.
- **`lib/screens/library/library_search_results.dart`** — `_YtmSection` ResultTile `onDownload` now opens `DownloadOptionsSheet`; existing dispatch+"Queued" logic extracted to `_downloadOnly`; playlist choice routes to `downloadAndAddToPlaylist`.
- **`lib/screens/library/library_screen.dart`** — added imports for `download_options_sheet.dart` + `download_to_playlist.dart`.
- **Tests:** `test/widgets/download_options_sheet_test.dart` (6 widget tests), `test/providers/download_to_playlist_test.dart` (3: happy path, job-failed, Navidrome timeout). All 9 green.
- Verified: `flutter analyze` clean; full suite **643** passed.

## 2026-06-24 — U1 follow-up: download-to-playlist moved to long-press (sheet drops the download-only row)

UX revision of the U1 commit above, per user request. A plain tap of the download icon now downloads directly again (the original "Queued" behaviour — no intermediate sheet). The download-to-playlist path is now opt-in via a **long-press** on the search-result row, which opens a playlist picker.

- **`lib/widgets/download_to_playlist_sheet.dart`** (new, replaces `download_options_sheet.dart`) — `DownloadToPlaylistSheet`. Presentational playlist picker: "Download to playlist" header → song title → owned playlists from `libraryPlaylistsProvider` filtered by `serverCredsProvider.navidromeUsername` (key `download-to-playlist-<id>`; loading/error/empty states). Tapping a row pops first, then `onSelect(id, name)`. The "Download" row + `onDownloadOnly` callback are gone (a plain tap covers that path).
- **`lib/widgets/result_tile.dart`** — new optional `onLongPress` wired to `ListTile.onLongPress`.
- **`lib/screens/library/library_search_results.dart`** — `_YtmSection`: `onDownload` → `_downloadOnly` (plain dispatch + "Queued"); new `onLongPress` → `DownloadToPlaylistSheet`, selection routes to `downloadAndAddToPlaylist` (unchanged).
- **`lib/screens/library/library_screen.dart`** — import swapped to `download_to_playlist_sheet.dart`.
- **Removed:** `lib/widgets/download_options_sheet.dart`, `test/widgets/download_options_sheet_test.dart`.
- **Tests:** `test/widgets/download_to_playlist_sheet_test.dart` (5: header+title, ownership filter, empty, row-tap fires onSelect, loading); long-press case added to `test/widgets/result_tile_test.dart`; `download_to_playlist_test.dart` provider tests unchanged.
- Verified: `flutter analyze` clean; full suite **643** passed.

## 2026-06-24 — V1: predictable back-button navigation

- **`lib/router.dart`** — `_ShellScaffold` now wraps its `Scaffold` in a `PopScope`. `canPop` is true only on Home; off-Home a system back is intercepted and routes to Home (so back walks toward Home, then exits on Home instead of quitting from any tab). When Library is in search mode it instead flips `librarySearchActiveProvider` to false (single back handler per route). Added import of `providers/library/library_search_query.dart`.
- **`lib/providers/library/library_search_query.dart`** — new `LibrarySearchActive` keepAlive notifier (bool) — single source of truth for whether the Library tab is showing its search overlay; read by the shell's back handler.
- **`lib/screens/library/library_screen.dart`** — search mode is now driven by `librarySearchActiveProvider` instead of a local `_searching` bool. `initState` seeds it post-frame from the persisted query / auto-focus; `build` registers a `ref.listen` that clears the controller + query on the true→false transition (covers both the in-app back arrow and the system back button). `_enterSearch`/`_exitSearch` just flip the provider.
- **`lib/screens/library/library_search_results.dart`** — removed the (briefly added) search-mode `PopScope`; back handling consolidated in the shell.
- **`lib/screens/downloads_screen.dart`** — album (`_AlbumRow`) and playlist (`_PlaylistRow`) drill-downs changed `context.go(...)` → `context.push(...)` so back returns to Downloads instead of replacing the stack.
- **Tests:** `test/router_test.dart` — added `V1 — predictable back stack` (off-Home back → Home and is handled; Home back not handled → app exit) and `V1 — search-mode back clears the field` (type query, system back clears text + returns to browse tabs, query state cleared). Stubs `combinedSearchProvider('daft punk')` to keep the test timer-free.
- Verified: `flutter analyze` clean; full suite **646** passed.

## 2026-06-24 — V1 back-stack fix revision: PopScope → WidgetsBindingObserver

- **`lib/router.dart`** — Replaced `PopScope` in `_ShellScaffoldState` with `WidgetsBindingObserver.didPopRoute()`. Root cause: go_router 14 `popRoute()` calls `_findCurrentNavigators()` (innermost-first) and drives `maybePop()` on each; the shell sub-navigator (1-page, no `PopScope`) returned false, and the root navigator's `PopScope` fired `onPopInvokedWithResult` but then `maybePop()` also returned false — causing go_router to return false from `popRoute()` and the `Router` widget to call `SystemNavigator.pop()` (app exit) after our `context.go(home)`. `WidgetsBindingObserver` sidesteps this entirely: `_ShellScaffoldState` registers after `RootBackButtonDispatcher` (LIFO), so `didPopRoute()` is called first; we check `GoRouter.canPop()` before intercepting so pushed detail screens still pop normally. `PopScope` and all related `atHome`/`librarySearching` build-time variables removed from `build()`.
- Everything else unchanged: `librarySearchActiveProvider`, `LibraryScreen` listener, `downloads_screen.dart` `.push()` fixes.

## 2026-07-04 — V1 back-stack fix, final: opt out of Android predictive back (manifest)

- **`android/app/src/main/AndroidManifest.xml`** — added `android:enableOnBackInvokedCallback="false"` on `<application>`. Root cause of "works in tests, exits on device": at targetSdk 36 (Android 16) predictive back is on by default, and back is only delivered to Flutter when the framework has reported `setFrameworkHandlesBack(true)`. That report is driven by `NavigationNotification`s (`navigator.dart:3753`); go_router's nested ShellRoute navigator (one page per tab, no PopScope in its own routes) dispatches `canHandlePop: false` after every tab switch — clobbering the shell PopScope's `doNotPop` notification (parent builds before child, so the child's dispatch lands last). The OS then finished the Activity itself; `popRoute` / `PopScope` never ran. The opt-out restores the legacy `KEYCODE_BACK → onBackPressed → popRoute` channel path, which is exactly what `router_test.dart`'s `handlePopRoute()` tests exercise. Trade-off: no predictive-back animation — irrelevant, since the shell intercepts back for custom navigation anyway.
- **`lib/router.dart`** — the shell back handler is the (fix5) `PopScope` form: `canPop` only on Home; off-Home → `context.go(home)`; Library-searching → flip `librarySearchActiveProvider`. Removed a leftover `debugPrint`. (Note: the 2026-06-24 "PopScope → WidgetsBindingObserver" entry above was itself reverted back to PopScope during the fix1–fix5 iterations; this entry records the final mechanism.)
- Verified: `flutter analyze` clean; 647 tests green. On-device back-nav smoke on the Pixel 7 (rc9).

## 2026-07-04 — #36: app-version footer in Settings + tag-injected versionName in CI

- **`lib/providers/app_version.dart`** (new) — `appVersionProvider` (keepAlive) reads the installed APK's versionName/versionCode via `package_info_plus` (^9.0.1, new dep) and formats `v<version>+<build>` (build suffix omitted when empty).
- **`lib/screens/settings_screen.dart`** — `_AppVersionTile` (key `settings-app-version`) below the three collapsible sections; renders nothing while loading / on error.
- **`.github/workflows/android-publish.yml`** — release build now passes `--build-name="${GITHUB_REF_NAME#v}"` + `--build-number=${{ github.run_number }}`, so release installs display the tag they shipped as instead of the stale pubspec `version:`.
- **Tests:** `test/providers/app_version_test.dart` (2) + a footer widget test in `settings_screen_test.dart`. Full suite 650 green; analyze clean.

## 2026-07-04 — #35: add-to-queue from song rows + remove/reorder in the Now Playing queue

- **`lib/player/heerr_audio_handler.dart`** — three queue-mutation methods: `addQueueItems` (batch append, one `addAudioSources` call so R1's gapless pre-preparation sees the whole batch), `removeQueueItemAt` (interface override; delegates to `removeAudioSourceAt`), `moveQueueItem(from, to)` (custom, remove-then-insert semantics via `moveAudioSource`). Removal/move end with `_rebroadcastCurrentItem` — after a structural mutation the player's `currentIndex` can point at a different item with the same numeric value, so `currentIndexStream` won't re-emit; the handler pushes the post-mutation item (or null on empty) explicitly.
- **`lib/player/playback_actions.dart`** — `addSongsToQueue(...)`: creds → existing `_toMediaItem` chokepoint (offline `file://` still wins) → append; empty queue behaves like Play (`playAll`). Snackbars for single/multi and play/append variants.
- **`lib/widgets/add_to_playlist_sheet.dart`** — optional `queueSongs` param; when non-empty renders an "Add to queue" tile (key `add-to-playlist-add-to-queue`) above "Find similar". Awaits the action while the sheet is mounted, then pops.
- **Call sites** — song-row long-presses (album detail, playlist detail, library search), the visible song-row "…" action, and the album overflow (whole tracklist). Now Playing's sheet deliberately omits it.
- **`lib/screens/player/now_playing_transport.dart`** — `_QueueList` is now a `ReorderableListView`: per-row trailing drag handle (`ReorderableDragStartListener`), swipe-left `Dismissible` remove, tap-to-jump unchanged. Uses the non-deprecated `onReorderItem` (Flutter 3.42+ pre-adjusts `newIndex`).
- **Tests:** 9 handler unit tests (batch append/order/no-op; remove in/out-of-range/rebroadcast/clear-on-empty; move semantics/no-ops), 3 sheet widget tests, 3 Now Playing queue-edit widget tests (handles render, swipe → `removeQueueItemAt(1)`, timed drag → `moveQueueItem(0, 1)`). Full suite 665 green; analyze clean.

## 2026-07-04 — v4.1.0 release

- **`pubspec.yaml`** — `3.5.0` → `4.1.0` (pubspec had drifted behind the `v4.*` tags; CI now injects the tag as versionName regardless, but local builds should agree with the release line).
- Bundles: V1 back-stack fix (manifest opt-out), #36 app-version footer, #35 add-to-queue + Now Playing queue remove/reorder. Tagged `v4.1.0`.

## 2026-07-05 — #26: synced lyrics + offline lyrics cache

- **`lib/models/subsonic/lyrics.dart`** — new `LyricsLine(start, value)` freezed model; `Lyrics` gains `List<LyricsLine>? lines` (serialized, so the offline cache round-trips sync data). New pure `parseLrc()` — LRC → timed lines (multi-timestamp lines, 1–3 digit fractions normalised to ms, metadata tags / untimed lines skipped, sorted by start).
- **`lib/services/lyrics_service.dart`** — both stages now carry timing: Navidrome structured lyrics with `synced: true` map per-line `start` offsets; LRCLib's `syncedLyrics` is parsed via `parseLrc`. Plain text stays the fallback body.
- **`lib/offline/lyrics_cache.dart`** (new) — per-server lyrics cache at `<serverKey>/lyrics/<songId>.json`; fail-soft (I/O errors swallowed) like the L5 library cache. Path helpers added to `offline_paths.dart`.
- **`lib/offline/offline_sync.dart`** — `_cacheLyricsBestEffort`: after each successful song download the tick resolves + persists lyrics (skips when already cached; failures never fail the download).
- **`lib/providers/library/lyrics.dart`** — `lyricsFor` writes the cache on every successful online resolve and serves it when the network resolve throws (ApiError) or returns empty — downloaded songs keep lyrics offline. No-cache errors still rethrow to the error pane.
- **`lib/screens/player/now_playing_lyrics.dart`** — `_LyricsPane` takes the live `position`; timed lyrics render a synced view (`now-playing-lyrics-synced`): active line highlighted primary/bold, kept near-centre via `Scrollable.ensureVisible`; non-lazy list so seek jumps still scroll. Plain lyrics render as before.
- **Known gaps:** songs downloaded before this build have no cached lyrics until their lyrics are opened once online (no backfill pass); the LRCLib fallback needs internet at download time (Navidrome-sourced lyrics are tailnet-only).
- **Tests:** `test/models/lyrics_parse_test.dart` (5), synced + cache groups in `lyrics_test.dart` (6, harness gains temp-docs/creds/LRCLib-adapter knobs), sync-hook tests in `offline_sync_test.dart` (2, env now always stubs `lyricsServiceProvider` so no test touches real network), synced-pane widget test in `now_playing_lyrics_toggle_test.dart`. Full suite 679 green; analyze clean.

## 2026-07-05 — W1: delete song from server / device / both (#41, v4.2.0)

Completes issue #41 (device-only delete shipped in `64c8e47`). Consumes backend Phase N (`DELETE /api/v1/library/song`), identifying the file by the Subsonic `Song.path`.

- **`lib/api/endpoints.dart`** — new `libraryDeleteSong = '/library/song'`.
- **`lib/services/backend_service.dart`** — `deleteLibrarySong(path)`: `DELETE` with `{path}` body through `apiCall`/`ApiError`.
- **`lib/providers/library/library_delete.dart`** (new) — `LibraryDelete` keepAlive notifier: guards `song.path` (StateError when absent), calls the service, invalidates `librarySearch`/`libraryAlbums`/`libraryArtists`/`libraryAlbum(albumId)`/`downloadedSongs`/home providers on success. Navidrome drops the track on its next scan, so snackbars note the delay.
- **`lib/screens/downloads_screen.dart`** — Songs long-press now opens a Device / Server / Both bottom sheet (Server/Both disabled when the song has no `path`); destructive confirm dialogs; server errors via `showApiError`.
- **`lib/widgets/add_to_playlist_sheet.dart`** — optional `deleteFromServerSong` renders a destructive "Delete from server…" tile (confirm-gated; sheet stays open on `ApiError`). Passed by song-row long-presses in album detail, playlist detail, and library search.
- **`pubspec.yaml`** — `4.2.0`.
- **Tests (+19):** `test/services/backend_service_test.dart`, `test/providers/library/library_delete_test.dart`, `test/screens/downloads_screen_delete_test.dart`, `test/widgets/add_to_playlist_delete_from_server_test.dart`. Full suite 698 passed; `flutter analyze` clean; `build_runner` clean.

## 2026-07-05 — Now Playing redesign (Spotify-style) + test fixes

- **`lib/screens/player/now_playing_screen.dart`** — full rewrite: removed AppBar; added custom `_Header` (back button, "NOW PLAYING" label, sleep chip, `PopupMenuButton` key `now-playing-overflow`); replaced fixed `Column`+`Expanded(_QueueList)` with `SingleChildScrollView`+`Column`; added `_WideCoverArt` (full-width cover, rounded corners); queue now opens via `showModalBottomSheet` triggered by `_BottomActionsRow`; lyrics always visible by scrolling (no toggle).
- **`lib/screens/player/now_playing_transport.dart`** — shuffle/repeat buttons styled with `StadiumBorder` + `primaryContainer` fill when active; added `_BottomActionsRow` widget (speaker placeholder left, queue button `now-playing-queue-button` right).
- **`lib/screens/player/now_playing_lyrics.dart`** — restructured: `_LyricsSection` always rendered in the scrollable body; `_SyncedLyrics` uses `Column` (not `ListView`) so `Scrollable.ensureVisible` bubbles to the parent `SingleChildScrollView`; removed `_LyricsBox`, `_LyricsPane`, toggle bool.
- **`test/screens/player/now_playing_lyrics_toggle_test.dart`** — rewritten for always-visible lyrics (removed toggle tap logic).
- **`test/screens/player/now_playing_screen_test.dart`** — added `_NoopAdapter`/`lyricsServiceProvider`/`offlinePathsProvider` overrides; queue-button interactions now use `ensureVisible` before tap; lifecycle test updated.
- **`test/screens/player/now_playing_modes_test.dart`** — added `_NullOfflinePaths`-equivalent stubs; `ensureVisible` before each transport icon tap (cover art pushes buttons off-screen in 800 px test viewport).
- **`test/screens/player/now_playing_sleep_timer_test.dart`** — added `lyricsServiceProvider` override to prevent real HTTP.
- **`test/screens/player/now_playing_add_to_playlist_test.dart`** — added `_NullOfflinePaths` subclass overriding `serverRoot → null`; overrides `offlinePathsProvider` to cut dart:io `file.exists()` call that hangs `pumpAndSettle` under fake-async (real OS I/O is never drained by Flutter's fake-async pump loop).
- All 33 player tests pass; `flutter analyze` clean.

## 2026-07-06 — Shuffle glyph redrawn (rc5)

- **`assets/icons/shuffle.svg`** — redrawn: open-chevron arrowheads (which overlapped line ends into blobs on-device) replaced with small filled triangles; over-wavy Béziers flattened to gentle single-crossing curves with horizontal lead-ins.
- Modes tests pass; no code changes. Tagged `v4.3.0-rc5`.

## 2026-07-06 — Custom SVG glyphs for shuffle/repeat (rc4)

- **New:** `assets/icons/shuffle.svg`, `repeat.svg`, `repeat_one.svg` — hand-drawn curvy/flowing glyphs matching the reference design; Material's `_rounded` icon variants only soften stroke corners, the glyph shapes don't exist in the built-in set.
- **`lib/screens/player/now_playing_transport.dart`** — shuffle/repeat render via `SvgPicture.asset` with the same tint logic (primary when active); buttons gain keys `now-playing-shuffle` / `now-playing-repeat`.
- **`lib/screens/player/now_playing_screen.dart`** — added `flutter_svg` import (part-file parent).
- **`test/screens/player/now_playing_modes_test.dart`** — finders switched from `find.byIcon` to button keys + SVG-asset-path predicate.
- All 33 player tests pass; `flutter analyze` clean. Tagged `v4.3.0-rc4`.

## 2026-07-06 — Transport buttons matched to reference screenshot

- **`lib/screens/player/now_playing_transport.dart`** — play/pause is now a big filled circle (`IconButton.filled`, `onSurface` background, plain `play_arrow_rounded`/`pause_rounded` glyph); shuffle/repeat reverted from pill-when-active to bare icons tinted `primary` when active.
- **`test/screens/player/now_playing_screen_test.dart`** — play/pause assertions updated for the new glyphs.
- All 33 player tests pass; `flutter analyze` clean. Tagged `v4.3.0-rc3`.

## 2026-07-05 — W1 smoke verified on-device (v4.2.0)

Delete from device / server / both verified on the Pixel against the home server (backend N1+N2 deployed). Smoke surfaced two operator prerequisites, now documented in ROADMAP Phase W + backend N2: Navidrome must report real paths (`ND_SUBSONIC_DEFAULTREPORTREALPATH=true` + per-player "Report Real Path" on `heerr [Dart]`), and the app needs one re-search so the L5 cache drops pre-flag virtual paths. Tagged `v4.2.0`.

## 2026-07-06 — Spotify-style lyrics card + full-screen lyrics sheet

- **`lib/screens/player/now_playing_lyrics.dart`** — rewritten. Inline lyrics section replaced by a palette-tinted rounded card (`now-playing-lyrics-card`) with a "Lyrics" header and expand affordance (`now-playing-lyrics-expand`). Synced lyrics in the card render as a sliding 5-line preview window (`_SyncedLyricsPreview`, active line ±) instead of the full auto-scrolling list; plain lyrics capped at 8 lines. New `_ExpandedLyricsSheet` (full-height modal bottom sheet, `now-playing-lyrics-sheet`): collapse chevron (`lyrics-sheet-collapse`), title/artist header, album-art corner thumbnail (`lyrics-sheet-art`, `_CornerArt`), big bold auto-scrolling `_SyncedLyrics` — sung+active lines full-contrast, upcoming dimmed. Sheet watches `playerSnapshotProvider` with its own 250 ms ticker. Shared `activeLyricsIndex()` extracted.
- **`lib/screens/player/now_playing_screen.dart`** — `_Body` gains `tintColor`; palette tint now flows into the lyrics card and sheet background.
- **`test/screens/player/now_playing_lyrics_expand_test.dart`** — new: card + expand affordance render; expand opens sheet with corner art and lyrics; chevron collapses.
- Full suite 699 tests pass; `flutter analyze` clean.

## 2026-07-06 — Shuffle arrowheads matched to repeat's chevron style (rc7)

- **`assets/icons/shuffle.svg`** — filled-triangle arrowheads replaced with the same open-chevron polylines `repeat.svg` uses; sized to 3.5-unit depth after two on-device iterations (4 = touching, 3.2 = too small).
- No code changes. Tagged `v4.3.0-rc7`.

## 2026-07-06 — For You: refresh affordance + 30-min TTL + seed sampling (#38)

- **`lib/providers/recommendations.dart`** — `Recommendations` is now `@Riverpod(keepAlive: true)` with `_lastFetchAt` + `refreshIfStale({maxAge: 30 min})` (mirrors `RecommendHealthNotifier`; no-ops while fresh or when a manual "Find similar" seed is active). New `sampleSeeds()` pure function + `kSeedSampleSize = 8` + `recommendationRngProvider` (injectable `Random`): each build POSTs a random 8-of-20 shuffled seed subset, so a refresh returns *different* results despite the backend being deterministic per seed set. Manual seed stays sole + unsampled. Profile-switch safety is inherited from the `backendServiceProvider → dioClientProvider → activeProfileProvider` watch chain.
- **`lib/screens/recommendations_screen.dart`** — AppBar gains a refresh action (`for-you-refresh`) calling `recommendationsProvider.notifier.refresh()`.
- **`lib/screens/home/home_screen.dart`** — `HomeScreen` converted to `ConsumerStatefulWidget`; `initState` fires `refreshIfStale()` post-frame on every Home visit. "Picked for you"/"Discover" header row gains a refresh IconButton (`home-recs-refresh`); on the Discover fallback it also invalidates `homeRandomSongsProvider`.
- **`lib/app/lifecycle_coordinator.dart`** — app-resume now also calls `recommendationsProvider.notifier.refreshIfStale()` beside the existing health check.
- **New:** `test/providers/seed_sampling_test.dart` — 5 unit tests (size cap, pass-through, seeded determinism, successive-draw variety, input immutability).
- **`test/providers/recommendations_provider_test.dart`** — pinned-RNG override; 6 new tests (sampled subset on the wire, manual-seed unsampled, TTL no-op / zero-maxAge re-fetch with different sample, manual-seed TTL guard, keepAlive survives listener removal); first-seeds assertion made order-independent (sampling shuffles).
- **`test/screens/recommendations_screen_test.dart`** — 2 new tests (refresh action renders; tap calls notifier).
- **`test/screens/home/home_screen_test.dart`** — 4 new tests (header icon renders; tap refreshes; Discover tap re-fetches random songs; mount fires `refreshIfStale`).
- **`test/app/lifecycle_coordinator_test.dart`** — 1 new test (resume → `refreshIfStale` on `Recommendations`).
- Full suite 717 tests pass; `flutter analyze` clean.

## 2026-07-06 — For You refresh button redesign: tint-on-busy + spin + dim (#38 follow-up)

- **New:** `lib/widgets/recommendations_refresh_button.dart` — `RecommendationsRefreshButton`: bare white `IconButton` at rest (matches other AppBar/header icons); while `recommendationsProvider` is loading it swaps to `IconButton.filledTonal` (the tint *is* the busy indicator) with the refresh icon spinning (`RotationTransition`, 900 ms loop, finishes the current turn on stop). Busy-variant taps are deliberate no-ops (never `onPressed: null`, so no disabled-grey flash). Optional `onBeforeRefresh` callback.
- **`lib/screens/home/home_screen.dart`** — `_RecommendationsSection` header uses the new button (Discover fallback passes `onBeforeRefresh` to invalidate `homeRandomSongsProvider`). Section `when` gains `skipLoadingOnReload: true` + `skipError: true`: a refresh keeps the previous cards visible (dimmed to 40 % via `AnimatedOpacity`) instead of the skeleton flash; a failed refresh keeps them too, surfaced once per error class via a new `reactToApiError` listen.
- **`lib/screens/recommendations_screen.dart`** — AppBar action swapped to the shared button; grid dims to 40 % while a refresh is in flight (`when` already keeps previous data on refresh by default).
- **New:** `test/widgets/recommendations_refresh_button_test.dart` — 3 tests (idle bare + tap fires refresh; busy tonal variant + tap no-op; `onBeforeRefresh` ordering).
- Full suite 720 tests pass; `flutter analyze` clean.

## 2026-07-06 — Profile page: avatar + name + nickname + bio (#37)

- **New:** `lib/screens/profile/profile_screen.dart` — `/profile` full-screen page (top-level route, like `/player`): circular avatar with add/change/remove via a bottom sheet, Name field (edits `Profile.displayName` on the registry; blank falls back to the Navidrome username), Nickname field, Bio multiline field capped at 100 words with a live `N/100 words` counter. Everything optional.
- **New:** `lib/models/profile_meta.dart` — freezed `ProfileMeta(nickname?, bio?)`.
- **New:** `lib/providers/profiles/profile_meta.dart` — keepAlive notifier persisting meta as JSON in plain `shared_preferences` (`profile_meta_<profileId>`, A5 rule: keystore is for secrets only); per-profile via `activeProfileProvider` watch; blank→null; corrupt JSON→empty.
- **New:** `lib/providers/profiles/profile_avatar.dart` — avatar file store at `<appDocs>/avatars/<profileId>_<micros>.jpg` (fresh path per change defeats `FileImage` cache staleness; atomic tmp+rename; old-file sweep; per-profile). `kMaxAvatarBytes` 2 MB backstop → `AvatarTooLargeError` → "Image too large" snackbar.
- **New:** `lib/providers/profiles/profile_image_picker.dart` — gallery-pick seam; production impl uses `image_picker` (512 px box, quality 85 downscale at pick time).
- **New:** `lib/utils/word_limit.dart` — `countWords` + `WordLimitTextInputFormatter` (rejects over-limit edits, allows deletions).
- **`lib/providers/profiles/profile_registry.dart`** — new `updateDisplayName(id, name)` in-place mutator (preserves list order, unlike `addProfile`'s remove-and-append).
- **`lib/screens/home/home_screen.dart`** — AppBar gains a profile avatar button (`home-profile-avatar`, pic or person glyph) → pushes `/profile`; greeting becomes "Good morning, <nickname>" when a nickname is set.
- **`lib/router.dart`** — `Routes.profile` + top-level `/profile` route.
- **`pubspec.yaml`** — add `image_picker: ^1.1.0` (Android 13+ photo picker; no storage permission).
- **Tests (28 new):** `test/utils/word_limit_test.dart` (6), `test/providers/profiles/profile_meta_test.dart` (5), `test/providers/profiles/profile_avatar_test.dart` (6), `profile_registry_test.dart` (+2 updateDisplayName), `test/screens/profile/profile_screen_test.dart` (7: render, save, blank-name fallback, 100-word block, pick, remove, oversize snackbar), `test/screens/home/home_screen_test.dart` (+3: avatar routes, nickname greeting, plain greeting).
- Full suite 748 tests pass; `flutter analyze` clean.

## 2026-07-06 — #45: network error state + auto-retry on Home screen (widget cold-open)

- **`lib/screens/home/home_screen.dart`** — `_HomeBody` converted from `ConsumerWidget` to `ConsumerStatefulWidget`. When all three providers (`homeRecentProvider`, `homeMostPlayedProvider`, `homeRecommendationsProvider`) fail simultaneously (e.g. Tailscale VPN off), shows `_NetworkErrorBody` instead of a blank screen: wifi-off icon + "Can't reach server" message + "Retrying automatically…" copy + "Retry" button (`home-retry-button`). Auto-retry fires every 5 s up to 6 times (30 s ceiling) via a one-shot `Timer`; a `ref.listen` on `homeRecentProvider` starts the timer on error and cancels it on recovery. Manual "Retry" button resets the counter and re-fires immediately. Error body uses `AlwaysScrollableScrollPhysics` so the parent `RefreshIndicator` pull-down gesture still works.
- **`test/screens/home/home_screen_test.dart`** — 4 new tests (group `Network error state (#45)`): all-fail shows "Can't reach server"; Retry button present; tapping Retry re-fetches providers; error body exposes a scrollable `ListView`.
- Full suite 25 tests pass; `flutter analyze` clean.

## 2026-07-06 — Y1: edit-metadata service + notifier + cover-cache eviction (#44)

- **`lib/api/endpoints.dart`** — `libraryEditSong` (`/library/song`; the HTTP verb distinguishes it from the Phase-W delete).
- **`lib/services/backend_service.dart`** — `editLibrarySong({path, title?, album?, artist?, coverBytes?})`: `FormData` multipart with only-present fields + a JPEG cover part (`MultipartFile.fromBytes`, `DioMediaType('image','jpeg')`); `dio.patch` through the shared `apiCall` (auth + `ApiError` mapping).
- **`lib/providers/library/library_edit.dart`** (new) — `LibraryEdit` keepAlive notifier: guards `song.path` + at-least-one-change, calls the service, invalidates the same 9 library/downloads/home read providers as `LibraryDelete`; on a cover upload also deletes the L5 cached cover JPG for `song.coverArt` and clears the in-memory image cache (Navidrome keeps the same cover id across a rescan, so the on-disk cache must be dropped).
- **Tests:** `test/services/backend_service_test.dart` (+5: PATCH shape, only-set-fields, JPEG cover part, 404/403/network → typed `ApiError`); `test/providers/library/library_edit_test.dart` (new, 7: path guard, nothing-to-change guard, invalidation-on-success, no-invalidation-on-failure, cover eviction on cover edit, no eviction on tags-only). `flutter analyze` clean.

## 2026-07-06 — Y2: edit song metadata screen — title/album/artist + cover upload (#44)

- **`lib/screens/library/edit_song_metadata_screen.dart`** (new) — full-screen editor pushed on the root navigator: cover preview (picked `Image.memory` with broken-image fallback, else `LibraryCoverArt`), "Change cover" via `image_picker`, three prefilled fields (Title / Artist(s) / Album). Save sends only changed non-empty fields, is disabled until something changes or while saving, pops + shows an "Updated … after the next Navidrome scan" snackbar on success, routes `ApiError` through `showApiError`.
- **`lib/providers/library/song_cover_image_picker.dart`** (new) — gallery-pick seam (1024 px / quality 85), a provider so widget tests stub it.
- **`lib/widgets/add_to_playlist_sheet.dart`** — optional `editMetadataSong` → non-destructive "Edit metadata…" tile above the delete tile, hidden when null or the song has no `path`; tap pops the sheet then pushes the editor on the root navigator.
- **`lib/screens/library/{album_detail,playlist_detail,library_search_results}`** — pass `editMetadataSong: s` alongside the existing `deleteFromServerSong: s` on the song-row long-press.
- **`pubspec.yaml`** → `4.3.0`.
- **Tests:** `test/screens/library/edit_song_metadata_test.dart` (new, 6: prefill, Save-disabled-until-change, changed-fields-only, original-value-is-not-a-change, cover pick sends bytes, success pops + snackbar); `test/widgets/add_to_playlist_edit_metadata_test.dart` (new, 4: render/hide rules, tap closes sheet + pushes screen). Full suite green; `flutter analyze` clean; `build_runner` clean. On-device smoke pending backend 3.3.0 deploy.

## 2026-07-07 — Edit server details from Profile 3-dot menu

- **`lib/providers/profiles/profile_registry.dart`** — added `updateServerDetails()` method: updates `heerrBaseUrl`, `heerrBearerToken`, `navidromeBaseUrl`, `navidromeUsername`, `navidromePassword` in-place for a given profile id, writes secure storage, emits new state.
- **`lib/screens/profile/edit_server_details_screen.dart`** (new) — `EditServerDetailsScreen`: pre-fills heerr URL, Navidrome username, and password from the active profile; "Test connection" calls `authLogin` and shows success/error snackbar without saving; "Save" calls `authLogin` to get a fresh token then calls `updateServerDetails` and pops.
- **`lib/router.dart`** — added `Routes.editServerDetails = '/edit-server-details'`; registered the new `GoRoute` for it.
- **`lib/screens/profile/profile_screen.dart`** — added `PopupMenuButton` to AppBar with "Edit server details" item that pushes `Routes.editServerDetails`; added `_ProfileMenuAction` enum; added `go_router` import.
- `flutter analyze` clean; all 774 tests pass.

## 2026-07-07 — Android profile sync to backend

- **`lib/api/endpoints.dart`** — `Endpoints.profile = '/profile'`.
- **`lib/api/backend_profile.dart`** (new) — `BackendProfileData` DTO; `putBackendProfile()` one-shot PUT; `pushProfileToBackend(WidgetRef)` assembles full local state (displayName + meta + avatar file → base64) and fires the PUT best-effort.
- **`lib/api/auth_login.dart`** — `AuthLoginResponse` gains `profile: BackendProfileData`; parsed from `LoginResponse.profile`.
- **`lib/screens/profile/profile_screen.dart`** — `unawaited(pushProfileToBackend(ref))` after `setAvatar`, `removeAvatar`, and `_save`; fires on every write-through.
- **`lib/screens/auth/login_screen.dart`** — `_hydrateBackendProfile()` called after addProfile/setActive; restores displayName, nickname/bio, and avatar from the login response profile if non-null. All 774 tests pass; `flutter analyze` clean.

---

## 2026-07-07 — Replace download icon with custom rounded-chevron arrow (no bar)

- **`lib/widgets/download_icon.dart`** (new) — `DownloadIcon` widget backed by `CustomPainter`. `filled: false` draws a circle outline + rounded-shaft chevron arrow in the ambient `IconTheme` colour. `filled: true` draws a solid heerr-green (#1DB954) disc with a near-black (#1A1A1A) arrow. Arrow is 20 % thicker than the Material baseline; shaft connects directly into the chevron apex with round caps and join throughout; no horizontal bar.
- **`lib/router.dart`** — Downloads nav tab changed from `Icons.download_for_offline_outlined` / `Icons.download_for_offline` to `icon: null, selectedIcon: null`; added `_buildDownloadsIcon()` builder (mirrors `_buildLibraryIcon` pattern); `_iconFor()` now dispatches on `tab.path` instead of `tab.icon == null`; added import for `download_icon.dart`.
- **`lib/screens/library/album_detail_screen.dart`** — AppBar action replaced with `DownloadIcon(filled: isMarked)`; per-song row "pending download" indicator replaced with `DownloadIcon(filled: false, size: 18)`.
- **`lib/screens/library/artist_detail_screen.dart`** — AppBar action replaced with `DownloadIcon(filled: isMarked)`; unused `theme.dart` import removed.
- **`lib/screens/library/playlist_detail_screen.dart`** — AppBar action replaced with `DownloadIcon(filled: isMarked)`.
- **`lib/screens/settings_offline.dart`** — `SwitchListTile.secondary` replaced with `DownloadIcon(filled: false)`.
- **`lib/screens/settings_screen.dart`** — `_CollapsibleSection.icon: IconData` changed to `leading: Widget`; Offline downloads caller updated to `DownloadIcon(filled: false)`; Profiles/Recommendations callers updated to `Icon(...)`; import added. `flutter analyze` clean.

---

## 2026-07-07 — v4.6.5: replace download icon with custom PNG asset

- **`assets/icons/download_file.png`** — new PNG asset (arrow-into-tray icon).
- **`lib/widgets/download_icon.dart`** — replaced `CustomPainter` circle+chevron with `Image.asset` coloured via `BlendMode.srcIn`; `filled: true` → heerrGreen, `filled: false` → `IconTheme` colour (white).
- **`lib/widgets/library_result_tile.dart`** — all `Icons.download_for_offline` / `Icons.download_for_offline_outlined` uses replaced with `DownloadIcon`; import added.
- **`lib/widgets/result_tile.dart`** — `Icons.download_outlined` (tappable) and `Icons.download_done` (badge) replaced with `DownloadIcon`; import added.
- **`lib/widgets/home_recommendation_card.dart`** — `Icons.download` replaced with `DownloadIcon(filled: false, size: 20)`; import added.
- **`lib/screens/library/album_detail_screen.dart`** — per-song downloaded badge `Icons.download_done` replaced with `DownloadIcon(filled: true, size: 18)`.
- **`lib/screens/library/playlist_detail_screen.dart`** — per-song pending badge `Icons.download_for_offline_outlined` and downloaded badge `Icons.download_done` replaced with `DownloadIcon`.
- **`test/widgets/library_result_tile_test.dart`** — updated finders from `find.byIcon(Icons.download_*)` to `find.byType(DownloadIcon)` / `find.byWidgetPredicate`.
- **`test/widgets/result_tile_test.dart`** — same finder updates; import added. 774 tests green.

## 2026-07-10 — Redesign: gradient magenta/purple theme (move off Spotify green)

Part 1 of the app-wide visual redesign toward the magenta→purple→violet brand identity (matches the new app icon). Theme + gradient accents only; per-screen layout passes follow.

- **`lib/theme.dart`** — palette swapped from Spotify green to `heerrMagenta #F533C8` (primary), `heerrPurple #A93CF2` (secondary), `heerrViolet #6F4BF5` (tertiary); background deepened to `#0A0A0A`. New `heerrGradient` `LinearGradient` (magenta→purple→violet, topLeft→bottomRight). `onPrimary`/`onSecondary`/`onError` are black (contrast on the bright fills, ~7:1). Added themed `SliderTheme`, `SwitchTheme`, `ChipTheme`, `ProgressIndicatorTheme`, `DividerTheme`, `ListTileTheme`, `FloatingActionButtonTheme`, `TextButtonTheme`, `ElevatedButtonTheme`. Deleted the dead `heerrGreen`/`heerrGolden` aliases (zero references remained).
- **New `lib/widgets/gradient_icon.dart`** — `ShaderMask` wrapper that gradient-tints any glyph (Icon or SVG) via `heerrGradient`.
- **New `lib/widgets/gradient_button.dart`** — full-width gradient pill CTA (disabled → grey), the redesign's primary button.
- **`lib/router.dart`** — selected bottom-nav icon wrapped in `GradientIcon` (active tab sweeps the gradient; unselected stay grey).
- **`lib/screens/player/now_playing_transport.dart`** — play/pause is now a gradient circle with a black glyph; scrubber's played portion painted with the gradient via a custom `_GradientSliderTrackShape`; shuffle/repeat gradient-tinted when active (`_transportGlyph` helper).
- **`lib/screens/profile/profile_screen.dart`** — Save button → `GradientButton`; avatar wrapped in a gradient ring (gradient circle → black gap → photo).
- Solid-magenta call sites updated off the legacy green: `album_detail_screen`, `playlist_detail_screen`, `queue_screen`, `now_playing_lyrics`, `library_result_tile`, `mini_player` (fallback tint → `heerrPurple`), `download_icon`, `settings_recommendations`.
- `flutter analyze` clean; 774/774 tests green.

## 2026-07-10 — Redesign: Settings screen (gradient theme, part 2)

Second per-screen pass of the redesign. Settings now matches the reference mock.

- **`lib/screens/settings_screen.dart`** — section leading icons tinted `heerrMagenta` (Profiles people, Offline downloads, Recommendations, App-version info) instead of the default grey.
- **`lib/screens/settings/profiles_section.dart`** — active-profile row now renders as a rounded magenta-tinted pill (tint bumped 0.08→0.12) with magenta title + person icon; "Add profile" icon tinted magenta. Non-active rows unchanged. Imports `theme.dart`.
- `flutter analyze` clean; 774/774 tests green (profiles-section test asserts only `ListTile.selected`, untouched).

## 2026-07-10 — Redesign: Home screen (gradient theme, part 3)

Third per-screen pass. Home layout already matched the reference mock (greeting + search pill + quick-access grid + horizontal sections); this pass tightens the surfaces + adds the brand avatar ring.

- **`lib/theme.dart`** — explicit neutral dark-grey `surfaceContainer*` ladder (Lowest `#0D0D0D` → Highest `#222222`). The raw `ColorScheme` was falling back to M3's purple-tinted defaults for `surfaceContainerHigh`; now grid tiles / cards (High `#1C1C1C`) and the search pill (Highest `#222222`) read as flat neutral greys like the mock.
- **`lib/screens/home/home_screen.dart`** — AppBar profile avatar (`_ProfileAvatarButton`) wrapped in a gradient ring (gradient circle → black gap → avatar), consistent with the Profile screen. Imports `theme.dart`.
- `flutter analyze` clean; 774/774 tests green (avatar test targets the `home-profile-avatar` key, unchanged).

## 2026-07-10 — Redesign: Library + Downloads (gradient theme, part 4)

Fourth per-screen pass. Both screens are tab-based; a shared TabBar theme + the Downloads empty-state icon bring them in line with the mock.

- **`lib/theme.dart`** — new `TabBarThemeData`: selected label + underline indicator `heerrMagenta`, unselected label `#808080`, transparent divider. Covers both the Library (Artists/Albums/Playlists) and Downloads (Albums/Playlists/Songs) tab bars — previously the selected label fell back to white (M3 `onSurface` default).
- **`lib/screens/downloads_screen.dart`** — empty-state icon (`album_outlined` concentric-ring vinyl, etc.) now rendered via `GradientIcon` (magenta→violet) instead of flat grey, matching the mock's coloured empty-state focal icon. Imports `gradient_icon.dart`. Message text stays grey.
- `flutter analyze` clean; 774/774 tests green (`find.byIcon` still matches — the Icon stays as GradientIcon's child).

## 2026-07-10 — Redesign: gradient "hero" home-screen widget (part 5)

New 4x2 home-screen widget matching the concept art (magenta->violet gradient), plus a green->gradient recolor of the existing three widgets and a live 1s progress ticker. Pure-Android; shares the existing `np_*` home_widget data contract.

- **New native widget** (`res/layout/hero_widget.xml`, `res/xml/hero_widget_info.xml`, `kotlin/com/aashish/heerr/HeroWidgetProvider.kt`, receiver in `AndroidManifest.xml`): 4x2 tile with two states toggled off `np_has_track` — idle (gradient heerr logo + "Start listening to your music" + flat white transport) and playing (album art + title/artist + animated gradient waveform + display-only progress + `m:ss` timestamps + gradient-circle play). Shared transport row (control ids appear once); provider swaps the play button's background to `widget_play_circle` only when a track is loaded. Reuses the `decodeScaledBitmap` + `mediaButtonIntent` + `HomeWidgetLaunchIntent` patterns; whitelisted RemoteViews classes only.
- **New gradient drawables**: `widget_gradient_border.xml` (2dp gradient rim via layer-list), `widget_play_circle.xml` (gradient oval), `widget_logo_gradient.xml` (heerr H+waveform mark, drawn as a vector — no SVG source exists).
- **Recolor (shared drawables)**: `widget_wave_1..8.xml` bars now step magenta->violet left->right; `widget_progress.xml` fill is a magenta->violet gradient; `widget_ic_album.xml` placeholder is magenta. Shared, so the Bar + Pill widgets get the gradient too.
- **Dart** (`lib/widget/now_playing_widget.dart`): added `kHeroWidgetName` to the `update()` redraw loop; new `pushPosition(Duration)` that writes only `np_position_ms` + redraws. **`lib/widget/now_playing_widget_provider.dart`**: a `Timer.periodic(1s)` runs while `snapshot.isPlaying`, pushing the extrapolated `PlaybackState.position` each second so the progress bar + timestamps advance live; cancelled on pause/idle and `ref.onDispose`. Only ticks while the app process is alive.
- **Tests**: added 2 `pushPosition` tests (position-only write; error-swallowing). `flutter analyze` clean; 776/776 green.
- On-device smoke on the Pixel 7 is still pending (native RemoteViews are out of TDD scope) — verify both states, the gradient border/waveform/play-circle, the 1s tick, transport + tap-to-open, and that the existing 3 widgets show the gradient.

## 2026-07-10 — Retire the classic/bar/pill widgets; hero-only + single-widget ticker (part 6)

Review follow-up to part 5: keep only the new 4x2 hero widget, and stop the live 1s ticker fanning out to every registered widget name.

- **Removed**: `kotlin/com/aashish/heerr/{NowPlayingWidgetProvider,BarWidgetProvider,PillWidgetProvider}.kt`, `res/layout/{now_playing_widget,bar_widget,pill_widget}.xml`, `res/xml/{now_playing_widget_info,bar_widget_info,pill_widget_info}.xml`, their `<receiver>` blocks in `AndroidManifest.xml`, and the drawables exclusive to them (`widget_background.xml`, `widget_pill_background.xml`). Drawables shared with the hero widget (`widget_wave_1..8`, `widget_progress`, `widget_ic_album`, `widget_ic_play/pause/next/previous`) are untouched.
- **`lib/widget/now_playing_widget.dart`**: removed `kNowPlayingWidgetName` / `kBarWidgetName` / `kPillWidgetName`. `HomeWidgetClientImpl.update()` now redraws only `kHeroWidgetName` directly instead of looping over four (now one) registered widget names — the loop was flagged in review because it re-inflated every added widget's RemoteViews (including the ViewFlipper waveform) on every 1s `pushPosition` tick, not just on the transport-driven `push()`.
- `proguard-rules.pro` comment updated (`NowPlayingWidgetProvider` → `HeroWidgetProvider`); no rule change (the `-keep` was already package-wide).
- `flutter analyze` clean; 776/776 tests green (no test referenced the removed constants). `flutter build apk --debug` succeeds with the resources/receivers removed.
- **`kotlin/com/aashish/heerr/HeroWidgetProvider.kt`**: `formatTime()` now formats with `Locale.US` instead of the default locale, so the `m:ss` timestamps always render Latin digits regardless of device locale (was flagged in review — `String.format` with no explicit locale can render localized digit glyphs, e.g. Arabic-Indic, under some locales).

## 2026-07-10 — Redesign review sweep: stale-doc + test-harness cleanup (part 7)

Full-branch review of redesign parts 1–6. Code was clean; the drift found was in docs and test scaffolding still referencing the retired Spotify-green theme (staleness rule: docs updated same turn as discovered).

- **`android/CLAUDE.md`** — locked-stack "Theme" line updated: `ColorScheme.fromSeed(#1DB954)` → hand-built raw `ColorScheme` (magenta primary + `heerrGradient` hero accents).
- **`android/docs/CONTEXT.md`** — stack-table Theme row + "Aesthetic" section rewritten for the gradient identity (magenta `#F533C8` → purple `#A93CF2` → violet `#6F4BF5` on `#0A0A0A`), noting the raw-ColorScheme approach and the gradient-on-hero-accents rule.
- **`test/screens/home/home_screen_test.dart`**, **`test/widgets/home_recommendation_card_test.dart`** — both `_wrap` harnesses built a private `ColorScheme.fromSeed(#1DB954)` theme; now use the real `heerrDarkTheme()` so widget tests exercise the shipped theme.
- **`lib/screens/player/now_playing_transport.dart`** — comment fix: the gradient play circle's glyph is black (matches `onPrimary`), not white as the comment claimed.
- `flutter analyze` clean; 776/776 tests green.

## 2026-07-10 — Hero widget reworked 4x2 → 4x1 to match the concept art (part 8)

On-device smoke showed the 4x2 tile with big empty bands and an inset thumbnail; the concept is a single-row bar with edge-to-edge art. Native-only rework.

- **`res/xml/hero_widget_info.xml`** — `targetCellHeight` 2→1, `minHeight` 110dp→40dp (40dp is what maps to 1 launcher row), `resizeMode` horizontal-only.
- **`res/layout/hero_widget.xml`** — rewritten: FrameLayout root (2dp border inset) holding the two full-bleed state groups. Playing state: full-height 96dp-wide cover flush left → column of [title/artist/wide waveform + transport row] → progress bar + m:ss times spanning under the transport to the right edge (as in the concept). Idle state now carries its own transport ids (`widget_idle_prev/play/next`) — no shared transport row anymore.
- **`kotlin/.../HeroWidgetProvider.kt`** — new `buildArtBitmap()`: center-crops the cover to the art view's real aspect (height read from `getAppWidgetOptions` `OPTION_APPWIDGET_MAX_HEIGHT`, fallback 110dp) and rounds the LEFT corners (26dp, matching the border's inner radius) natively, since RemoteViews can't clip; density capped at 2x to keep the bitmap under the Binder limit. `onAppWidgetOptionsChanged` override redraws on resize. Wires PendingIntents for both state groups' transports; the play-disc background is now static in the layout (idle has its own flat buttons, so the `setBackgroundResource` swap is gone). `MAX_ART_PX` 192→512 (source decode cap before the crop).
- **`res/drawable/widget_wave_1..8.xml`** — regenerated wide: 21 bars / 110x24 viewport (was 5 bars / 26x24) so the waveform spans the text column like the concept; same stepped magenta→violet tinting, sine-sampled with advancing phase.
- **`AndroidManifest.xml`** — receiver comment 4x2→4x1.
- Verification: release build (`--build-number=120`) installed on the Pixel 7. NOTE: a previously-placed widget instance keeps its old 4x2 cell size — the user must remove + re-add the widget after this update; launcher provider-info caching may additionally need a launcher restart.

## 2026-07-10 — Library "New playlist" FAB gets the brand gradient (part 9)

On-device review: the Playlists tab's extended FAB rendered solid magenta (the theme's `floatingActionButtonTheme`), not the gradient a primary CTA should carry per the redesign rule.

- **`lib/screens/library/library_tabs.dart`** — the `FloatingActionButton.extended` is now transparent/flat (elevation 0, black foreground) inside a `DecoratedBox` with `heerrGradient` at 16dp radius (matching the M3 extended-FAB shape); FABs can't take a gradient directly.
- **`lib/screens/library/library_screen.dart`** — added the `theme.dart` import (library_tabs.dart is a `part of` it).
- `flutter analyze` clean; 776/776 tests green (`find.byType(FloatingActionButton)` still matches — the FAB is wrapped, not replaced). Release build `--build-number=121` installed on the Pixel 7.

## 2026-07-10 — Fix concurrent-save race in NowPlayingPersistence

CI flagged `now_playing_persistence_test.dart`'s "debounced save fires once for a burst of trigger events" test failing with `PathNotFoundException` on `NowPlayingStore.save`'s tmp-file rename. Root cause: `NowPlayingStore.save` (`now_playing_store.dart:43-48`) always writes to the same fixed `${_file.path}.tmp`, and `NowPlayingPersistence.flush()` could fire a second `_writeSnapshot()` concurrently with an already-in-flight debounced one (`_debounceTimer?.cancel()` is a no-op once the timer has fired) — two overlapping `save()` calls race the shared `.tmp` path, and the loser's `rename()` throws once the winner's rename has already removed it.

- **`lib/player/now_playing_persistence.dart`** — added `_pendingWrite`, a chained `Future` serializing all writes through a new `_enqueueWrite()` helper; both the debounce-timer callback and `flush()` now go through it instead of calling `_writeSnapshot()` directly, so a `flush()` call always waits for any in-flight debounced save instead of racing it.
- `flutter test test/player/` — 75/75 green.

## 2026-07-10 — Widget polish: art fade, tap-to-seek, redrawn logo/waveform, gradient tab indicator

User compared the shipped hero widget and Library tab bar against the original concept art and flagged 5 mismatches (see `android/docs/PLAN.md` for the design). Fixed all five.

- **`lib/widgets/gradient_tab_indicator.dart`** (new) — `GradientTabIndicator extends Decoration`, paints a rounded 3dp `heerrGradient` bar under the selected tab label.
- **`lib/theme.dart`** — `TabBarThemeData.indicatorColor` replaced with `indicator: GradientTabIndicator()`, `indicatorSize: TabBarIndicatorSize.label`, `dividerColor: Color(0xFF2E2E2E)` + `dividerHeight: 1` (the thin line extending past the gradient bar, per the reference screenshot).
- **`test/widgets/gradient_tab_indicator_test.dart`** (new) — theme wiring assertion + a widget test tapping between tabs with the real theme, asserting no paint exceptions.
- **`android/app/src/main/kotlin/com/aashish/heerr/HeroWidgetProvider.kt`** — `buildArtBitmap()` now alpha-fades the right 35% of the cropped cover (`LinearGradient` WHITE→TRANSPARENT masked in with `PorterDuff.Mode.DST_IN`) so art blends into the tile instead of a hard border; `ART_WIDTH_DP` 96→112dp to compensate. Added `seekIntent()` + a loop over 10 `SEEK_ZONE_IDS` wiring tap-to-seek `PendingIntent`s (distinct requestCodes, base 100) onto the progress-bar overlay. Hoisted `HOME_WIDGET_PREFS` to a top-level `internal const` shared with the new receiver.
- **`android/app/src/main/kotlin/com/aashish/heerr/WidgetSeekReceiver.kt`** (new) — `BroadcastReceiver` for `ACTION_WIDGET_SEEK`; reads `np_duration_ms`, connects a short-lived `MediaBrowserCompat` to audio_service's `AudioService` (no static session hook exists on 0.18.18), then calls `MediaControllerCompat.transportControls.seekTo()`.
- **`android/app/src/main/res/layout/hero_widget.xml`** — `widget_art` width 96dp→112dp, content column `paddingStart` 12dp→0dp; the bare `ProgressBar` row replaced with a 16dp `FrameLayout` stacking the 4dp bar plus a 10-zone `LinearLayout` of empty `FrameLayout` tap targets (`widget_seek_0..9`).
- **`android/app/src/main/res/drawable/widget_logo_gradient.xml`** — redrawn: solid magenta/violet uprights + 2 connector dashes + 7 magenta waveform bars, matching the reference idle mark (was a stepped 7-color gradient).
- **`android/app/tool/gen_widget_wave.py`** (new, committed) — generates `widget_wave_1..8.xml`: 36 thin baseline-aligned bars in a 3-cluster Gaussian envelope, 8-frame travelling-wave modulation, `heerrGradient`-lerped tint (was 21 sine-sampled bars).
- **`android/app/src/main/AndroidManifest.xml`** — registered `.WidgetSeekReceiver` (`exported="false"`, explicit-component broadcast, no intent-filter).
- **`android/app/build.gradle.kts`** — added `implementation("androidx.media:media:1.7.0")` (compile-time visibility for `MediaBrowserCompat`/`MediaControllerCompat`; already on the runtime classpath via audio_service).
- Verification: `flutter test` 778/778 green (776 prior + 2 new), `flutter analyze` clean, `flutter build apk --debug` succeeds. Native visuals/seek not yet smoke-tested on device.

## 2026-07-10 — Follow-up: real app-icon mark for the widget idle state; tab indicator's missing fade

User review of the previous widget-polish commit flagged two remaining mismatches against the concept art.

- **`tool/gen_widget_logo.py`** (new, committed) — extracts the actual heerr "H + waveform" mark from `assets/icon.png` (the real app icon) instead of a hand-drawn vector approximation: keys out the icon's opaque black disc background (near-black pixels, including its anti-aliased edge ring) to transparent, crops to the mark's bounding box with 12px padding, writes `android/app/src/main/res/drawable-nodpi/widget_logo_gradient.png`.
- **`android/app/src/main/res/drawable/widget_logo_gradient.xml`** — deleted (superseded by the extracted PNG of the same resource name in `drawable-nodpi/`).
- **`android/app/src/main/res/layout/hero_widget.xml`** — idle logo `ImageView` resized 46x40dp → 40x40dp (square, matching the extracted asset's aspect ratio; `fitCenter` was leaving dead space in the old non-square box).
- **`lib/widgets/gradient_tab_indicator.dart`** — the thin extension was wrongly implemented as `TabBarThemeData`'s full-width divider (wrong color, wrong scope — spans every tab, not just the selected one). Replaced with a `fadeExtension` (default 20dp) painted by the indicator itself: a 1dp magenta line at 55% opacity extending past each end of the bold 3dp bar and fading to transparent at the tips, drawn under the bold bar. `TabBar` doesn't clip indicator painting to a single tab's segment, so the fade is free to bleed into neighbouring tabs as in the reference screenshot.
- **`lib/theme.dart`** — reverted the stopgap `dividerColor`/`dividerHeight` back to `dividerColor: Colors.transparent` (the indicator is now self-contained).
- **`test/widgets/gradient_tab_indicator_test.dart`** — theme-wiring assertion updated to check `fadeExtension > 0` and `dividerColor == Colors.transparent` instead of the removed divider-height assumption.
- Verification: `flutter test` 778/778 green, `flutter analyze` clean, `flutter build apk --debug` succeeds (confirms the `drawable-nodpi` PNG swap resolves cleanly with no resource-name collision from the deleted vector). Native visuals still pending on-device smoke.

## 2026-07-10 — Version bump to 4.7.2; remove stray PLAN.md

- **`android/app/pubspec.yaml`**, **`backend/pyproject.toml`**, **`backend/app/main.py`**, **`android/docs/ROADMAP.md`**, **`backend/docs/ROADMAP.md`** — version bump 4.7.1 → 4.7.2 for the icon/indicator follow-up fixes, per the version-sync convention.
- **`android/docs/PLAN.md`** — deleted. It held the ad-hoc widget-polish plan (superseded by the CHANGELOG/DECISIONLOG entries once implemented); its presence collided with `android/CLAUDE.md`'s pre-existing (and separately stale) reference to a `PLAN.md` as "the locked v1 contract."
- **`android/docs/ROADMAP.md`** — the *what*-pointer in the header updated from the now-deleted `PLAN.md` to `DECISIONLOG.md`.

## 2026-07-11 — Home Screen redesign: planning round (docs only)

- **`android/docs/HOMESCREEN.md`** (new) — detailed implementation plan for the mockup-driven Home Screen redesign (branded header, greeting block, Continue Listening hero card, Quick Access shortcut row, Recently Added vertical list, new Favorites + Recently Added screens, MiniPlayer restyle). 8 tasks, each with file paths, provider names, layout specs, and test requirements — written for handoff to an implementing agent. No code changed in this round.

## 2026-07-11 — Follow-up 2: kill the widget icon's ghost ring; tab indicator fade spans the whole tab

- **`tool/gen_widget_logo.py`** — the previous saturation-blind, brightness-only keying (near-black threshold) missed a fully-opaque gray bezel stroke baked into `assets/icon.png`'s disc edge (brightness up to ~190, well above the black threshold), which still showed as a faint ring on-device. Switched to a saturation-based filter (`max(r,g,b) - min(r,g,b) < 15`): the brand mark's magenta/purple/blue bars are all highly saturated (sat 190-206 sampled), while the disc fill and its stroke are both grayscale, so one threshold now removes the entire disc+ring cleanly regardless of brightness. Re-running the script shrank the cropped bounding box from 1024x1024 to 607x670 — confirms the ring is gone, not just dimmed.
- **`android/app/src/main/res/layout/hero_widget.xml`** — idle logo `ImageView` 40x40dp → 48dp (20% larger, per request).
- **`lib/widgets/gradient_tab_indicator.dart`** — the faint line previously only extended a fixed 20dp past the label's own width (`TabBarIndicatorSize.label`-scoped), so it never covered the *whole* selected tab. Since a `Decoration`'s `paint()` gets one `configuration.size` shared by both layers, switched indicator sizing to `TabBarIndicatorSize.tab`: the faint line (`fadeAlpha`, default 0.35) now spans the entire tab width with only a small taper at the very ends, while the bold gradient bar (`boldWidthFraction`, default 0.5 of tab width) stays narrower and centered on top, approximating the label's width.
- **`lib/theme.dart`** — `tabBarTheme.indicatorSize` → `TabBarIndicatorSize.tab`.
- **`test/widgets/gradient_tab_indicator_test.dart`** — updated for the renamed `fadeAlpha`/`boldWidthFraction` fields and `indicatorSize == .tab`.
- Verification: `flutter test` 778/778 green, `flutter analyze` clean, `flutter build apk --debug` succeeds. Native visuals still pending on-device smoke.

## 2026-07-11 — Home Screen redesign plan: Part B (adaptive art-driven theming)

- **`android/docs/HOMESCREEN.md`** — added Part B (§7, tasks B1–B4) after user review: per-song adaptive theming of the hero card + MiniPlayer. Artwork is never recolored; instead — shared cached palette provider (promoting the existing `dominantColorFor` / `palette_generator` path), 18% brand-blend of the extracted color for accents (waveform tint, play-button glow), blurred-art backdrop under a darkening gradient on the hero card, 400 ms animated tint transitions on track change. Amended Task 7 so the MiniPlayer palette infrastructure is kept (not deleted) for B1 to build on. Docs only.

## 2026-07-11 — Follow-up 3: fix idle-prompt line break in the hero widget

- **`android/app/android/app/src/main/res/layout/hero_widget.xml`** — the idle prompt `TextView` (`android:text="Start listening to your music"`) had no explicit break, so RemoteViews' text layout wrapped it unevenly instead of matching the reference's clean two-line split. Inserted a literal `\n` so the text is `"Start listening\nto your music"`.
- **`android/app/pubspec.yaml`**, **`backend/pyproject.toml`**, **`backend/app/main.py`**, **`android/docs/ROADMAP.md`**, **`backend/docs/ROADMAP.md`** — version bump 4.7.3 → 4.7.4 for the wording-wrap fix, per the version-sync convention.
- Verification: `flutter test` 778/778 green, `flutter analyze` clean. Native XML-only change — no new Dart tests; gated by `flutter build apk --debug` + on-device smoke.

## 2026-07-11 — Home redesign part 1: branded header + greeting block

- **`lib/widgets/heerr_logo.dart`** (new) — `HeerrLogo`: app-icon mark (32px, rounded, from `assets/icon.png`) + "heerr" wordmark row for the Home AppBar. `errorBuilder` falls back to a fixed-size music glyph so an asset failure can't inject a `RenderErrorBox` into the AppBar.
- **`pubspec.yaml`** — declared `assets/icon.png` as a runtime asset (it was previously only the launcher-icon source; `Image.asset` failed in tests until declared).
- **`lib/screens/home/home_screen.dart`** — AppBar title switched from the time-of-day greeting to `HeerrLogo` (left-aligned); greeting moved into the body as `_GreetingBlock` under the search bar: small grey "<greeting>," line + large bold "<nickname> 👋" when a nickname is set, single large greeting line (no emoji) otherwise.
- **`test/screens/home/home_screen_test.dart`** — AppBar/greeting assertions rewritten for the new contract (logo in the title slot, greeting text found in the body, two-line nickname block).
- **`test/router_test.dart`** — "we're on Home" assertions switched from greeting-text matching to a `_expectOnHome` helper that checks the AppBar title is a `HeerrLogo`.
- Verification: `flutter analyze` clean, `flutter test` 778/778 green.

## 2026-07-11 — Home redesign part 2: Continue Listening hero card + WaveformStrip

- **`lib/widgets/waveform_strip.dart`** (new) — `WaveformStrip`: decorative static waveform (CustomPaint, rounded bars). Bar heights are deterministic per `seed` via an LCG (stable across SDK versions); `barHeights()` exposed for tests. Not a progress indicator.
- **`lib/screens/home/continue_listening_card.dart`** (new) — `ContinueListeningCard`: hero card driven by `playerSnapshotProvider` (cold-start restore already surfaces the last-played track paused — no direct NowPlayingStore read). Gradient-border card, cover art left (140px, stretch), right column: CONTINUE LISTENING pill, title, artist, waveform (seeded by title), static gradient progress bar + m:ss / m:ss times (no per-second ticker; progress snaps on transport events), 52px gradient play/pause circle. Card tap → `/player`; hidden when nothing is queued / stream loading / no handler override.
- **`lib/screens/home/home_screen.dart`** — card inserted into the body after `_GreetingBlock`.
- **`test/screens/home/continue_listening_card_test.dart`** (new) — 10 tests: hidden-when-empty, content render, progress fraction, null-duration guard (`--:--`, zero fill), play/pause via mocktail `HeerrAudioHandler` stub, tap-through to /player, `barHeights` determinism/range.
- Verification: `flutter analyze` clean, `flutter test` 788/788 green.

## 2026-07-11 — Home redesign part 3: Quick Access shortcut row

- **`lib/screens/home/quick_access_row.dart`** (new) — `QuickAccessRow`: "Quick Access" header + horizontally scrollable row of 4 static 150×110 outlined cards with gradient-tinted icons: For You → `/library/recommendations`, Favorites → `/library/favorites` (screen lands in part 5), Offline → `/downloads` with a live "N songs" count from `downloadedSongsProvider` (falls back to "Downloads" while loading/on error — local disk state, not network), Recently Added → `/library/recently-added` (screen lands in part 4). No "Edit" affordance — deferred per DECISIONLOG 2026-07-11.
- **`lib/router.dart`** — `Routes.libraryFavorites` + `Routes.libraryRecentlyAdded` constants added (GoRoutes register in parts 4/5).
- **`lib/screens/home/home_screen.dart`** — row inserted after the hero card.
- **`test/screens/home/quick_access_row_test.dart`** (new) — 8 tests: header + 4 cards render, no Edit, count/singular/error subtitles, all four navigation targets.
- **`test/screens/home/home_screen_test.dart`** — 3 legacy-section tests now scroll before asserting (the new rows push "Most played" / "Picked for you" below the built viewport).
- Verification: `flutter analyze` clean, `flutter test` 796/796 green.

## 2026-07-11 — Home redesign part 4: Recently Added section + See-all screen

- **`lib/providers/home/home_providers.dart`** — `homeNewestProvider` (`getAlbumList2 type=newest`, size 8 — recently *added*, vs the existing `recent` = recently *played*) + `recentlyAddedFullProvider` (size 50, separate provider so the two fetches cache independently). Codegen re-run.
- **`lib/screens/home/recently_added_section.dart`** (new) — `RecentlyAddedSection`: header + "See all" TextButton → `/library/recently-added`; first 5 albums as plain rows in the parent ListView (no nested scrollable). `RecentlyAddedRow` (56px `LibraryCoverArt`, bold title, grey artist, tap → album detail) is public and shared with the screen. Kebab menu deferred (DEBT). Loading → 3 SkeletonTiles; error/empty → hidden.
- **`lib/screens/library/recently_added_screen.dart`** (new) — `RecentlyAddedScreen`: AppBar list of the full 50, pull-to-refresh via `ref.invalidate`, error state with Retry.
- **`lib/router.dart`** — nested `recently-added` GoRoute under `/library` (Library tab stays selected via the existing `startsWith` index rule).
- **`lib/screens/home/home_screen.dart`** — section inserted after Quick Access.
- **`test/screens/home/recently_added_test.dart`** (new) — 8 tests: section render cap (5 rows), empty/error hidden, row tap → album, See all → screen, screen list/error-retry/pull-to-refresh.
- Verification: `flutter analyze` clean, `flutter test` 804/804 green.

## 2026-07-11 — Home redesign part 5: Favorites screen

- **`lib/providers/library/starred_songs.dart`** (new) — `starredSongsProvider` over the existing `SubsonicLibraryService.getStarredSongs()` (`getStarred2.view`). Codegen re-run.
- **`lib/screens/library/favorites_screen.dart`** (new) — `FavoritesScreen`: starred songs as ListTiles reusing `LibraryCoverArt` + `SongRowActions` (find-similar / edit / delete hooks); tap plays via the shared `playAllSongsFromSubsonic` path — no new playback entry point. Loading skeletons, error + Retry, `EmptyState` ("No favorites yet"), pull-to-refresh.
- **`lib/router.dart`** — nested `favorites` GoRoute under `/library`; the Quick Access Favorites card's target now resolves.
- **`test/screens/library/favorites_screen_test.dart`** (new) — 4 tests: rows + actions render, empty state, error + Retry re-fetch, pull-to-refresh.
- Verification: `flutter analyze` clean, `flutter test` 808/808 green.

## 2026-07-11 — Home redesign part 6: final body assembly + legacy-section cleanup

- **`lib/screens/home/home_screen.dart`** — final body: search bar → greeting → Continue Listening → Quick Access → Recently Added (or the "Nothing here yet" `EmptyState` when newest is empty AND the player is idle). Removed `_QuickAccessGrid`, `_RecommendationGridFallback`, `_JumpBackInSection`, `_MostPlayedSection`, `_RecommendationsSection`, and the mount-time `refreshIfStale()` (the lifecycle coordinator already fires it on resume — `lifecycle_coordinator.dart:110` — and the Recommendations screen refreshes itself). `HomeScreen` simplified to a `ConsumerWidget`. Auto-retry + network-error body rewired to `homeNewestProvider` as the single network signal.
- **`lib/providers/home/home_providers.dart`** — deleted `homeRecent`, `homeMostPlayed`, `homeRandomSongs`, `homeRecommendations` + the `HomeRecommendations` typedef (no consumers post-redesign). Kept `homeNewest` + `recentlyAddedFull`.
- **`lib/providers/library/library_edit.dart`, `library_delete.dart`** — post-mutation invalidations repointed from the deleted providers to `homeNewest` + `recentlyAddedFull` + `starredSongs`.
- **`lib/widgets/home_grid_tile.dart`, `lib/widgets/home_section.dart`** — deleted (Home-only). `home_recommendation_card.dart` + `recommendations_refresh_button.dart` kept — still used by the Recommendations screen.
- **`test/screens/home/home_screen_test.dart`** — rewritten for the new contract (13 legacy tests removed; error/retry/pull-refresh retimed to `homeNewestProvider`; empty-state asserts on the section *widget*, since the Quick Access card also carries the "Recently Added" label). **`test/providers/home/home_providers_test.dart`** — rewritten for the two surviving providers.
- **`docs/DEBT.md`** — Quick Access Edit + row kebab deferrals logged.
- Verification: `flutter analyze` clean, `flutter test` 795/795 green (808 → 795 = removed legacy-section tests).

## 2026-07-11 — Home redesign part 7: MiniPlayer restyle

- **`lib/widgets/mini_player.dart`** — restyled to the new design language: `surfaceContainerHigh` card (radius 16) with the thin gradient border (replacing the dominant-color-tinted background), 44px rounded cover thumb, decorative `WaveformStrip` (90px, hidden under 360dp available width via LayoutBuilder), 40px gradient play/pause circle with a soft tint glow (replacing the plain IconButton). Height 56 → 64; side margins 6px (was `FractionallySizedBox(0.99)`). The palette extraction (`dominantColorFor` + `miniPlayerPaletteExtractorOverride` seam) is **kept** and now tints the waveform + glow — Part B migrates it to the shared cached palette provider.
- **`test/widgets/mini_player_test.dart`** — all 8 behavior tests pass unchanged; added a redesign contract test (WaveformStrip present, gradient circle instead of IconButton).
- Verification: `flutter analyze` clean, `flutter test` 796/796 green.

## 2026-07-11 — Home redesign part B1+B3: shared palette provider + MiniPlayer adaptive accents

- **`lib/utils/palette.dart`** — Part B constants (`kBrandBlend` 0.18, `kArtBackdropBlur` 24, `kTintTransition` 400 ms), `brandBlend()` (lerp extracted → `heerrMagenta`), and the `dominantColorForOverride` module seam (prod default = real extractor).
- **`lib/providers/player/art_palette.dart`** (new) — `artPaletteProvider`: keep-alive family keyed by art-URI string; one palette extraction per unique cover per session. Family keying structurally removes the stale-response race the MiniPlayer guarded by hand.
- **`lib/widgets/mini_player.dart`** — migrated off the private `_maybeRefreshTint` state + `miniPlayerPaletteExtractorOverride` seam (deleted) onto the provider. Tint = `brandBlend(extracted ?? heerrPurple)` on waveform + play-glow; last-known tint held during a new track's extraction; `_AnimatedTint` (TweenAnimationBuilder) cross-fades tint changes over 400 ms.
- **`test/utils/palette_test.dart`** (new) — brandBlend lerp/no-op (quantized ARGB compare), per-URI cache count, null propagation. **`test/widgets/mini_player_test.dart`** — tint plumbing via the new seam + fallback test.
- Verification: `flutter analyze` clean, full suite green.

## 2026-07-11 — Home redesign part B2: hero card adaptive backdrop + accents

- **`lib/widgets/animated_tint.dart`** (new) — `AnimatedTint` extracted from the MiniPlayer's private helper; shared 400 ms tint cross-fade.
- **`lib/screens/home/continue_listening_card.dart`** — Part B visuals: blurred cover backdrop (`ImageFiltered` at sigma 24 inside a `RepaintBoundary`, only the image blurred — cheaper than `BackdropFilter`), left→right darkening gradient (black 0.35 → `heerrBlack` 0.88) for text contrast, `brandBlend` tint on the waveform + neon glows behind the sharp art (0.25) and play button (0.35). Progress fill stays `heerrGradient` (brand anchor). Last-known tint held during a new track's extraction; artwork itself never recoloured.
- **`lib/widgets/mini_player.dart`** — switched to the shared `AnimatedTint`.
- **`test/screens/home/continue_listening_card_test.dart`** — 3 new tests: blended tint + single extraction per URI, backdrop presence with art, no-backdrop + fallback tint without art.
- Verification: `flutter analyze` clean, `flutter test` 805/805 green.

## 2026-07-11 — Home redesign part 8: final gates + docs flush

- `flutter analyze` clean; `flutter test` 805/805 green; `flutter build apk --debug` succeeds.
- **On-device smoke pending** — no device attached this session. Checklist for the next device session: cold start with a restored queue → hero card shows the last track paused, resumes on tap; empty-library profile → "Nothing here yet"; Tailscale off → network-error body + auto-retry; scroll Home while playing (blur jank check — `RepaintBoundary` already in place, `cacheWidth` downsample is the escape hatch); rapid track skips → tint cross-fades without flashing.
- **`docs/DECISIONLOG.md`** — two entries: "adapt chrome around original artwork, never recolor" + the implementation record.
- **`docs/CONTEXT.md`** — Aesthetic section extended with the per-song adaptive tinting + new Home composition and screens.
- **`docs/HOMESCREEN.md`** — status flipped to IMPLEMENTED with commit range.
- `graphify update .` run at repo root.

## 2026-07-11 — Version bump to 4.8.0 (Home Screen redesign release)

- **`android/app/pubspec.yaml`**, **`backend/pyproject.toml`**, **`backend/app/main.py`**, **`android/docs/ROADMAP.md`**, **`backend/docs/ROADMAP.md`** — version bump 4.7.4 → 4.8.0 per the version-sync convention. Minor bump (not patch): the Home Screen redesign replaces the layout, adds two screens (Favorites, Recently Added), and introduces per-song adaptive theming. Android-side only; backend bumped for sync.
- Tagged `v4.8.0`.

## 2026-07-11 — Home redesign fix round 1: layout bug + mockup fidelity (user review)

User review of v4.8.0 flagged four issues:

- **Home sections vanished while a track was live (bug).** The hero card's `Row(crossAxisAlignment: stretch)` sits in a Stack that gets **unbounded height inside Home's ListView**; with a current MediaItem the card mounted, layout threw, and everything below it (Quick Access, Recently Added) failed to render. Widget tests missed it because they pumped the card inside a bounded Scaffold body. Fix: card content wrapped in `SizedBox(height: 212)`; inner column centered. Regression test added that pumps the full HomeScreen with a live snapshot and asserts hero + both sections render (`test/screens/home/home_screen_test.dart`).
- **Search pill too round.** `_HomeSearchBar` radius 28 → 14 (mockup: squarish with gently curved corners). Only occurrence in the app — Library search is an inline AppBar field.
- **MiniPlayer waveform wrong colour + static.** `WaveformStrip` gained `gradient` (shader paint) and `animate` (equalizer breathing via a repeating 1.2 s AnimationController, phase-shifted per bar — the home-screen widget's look). MiniPlayer waveform now `heerrGradient` + animates only while playing (a repeating animation must not run while paused — also keeps `pumpAndSettle` usable in tests). The per-song tint remains on the play-circle glow.
- **MiniPlayer border too loud.** Gradient border shell replaced with `surfaceContainerLow` card + 0.8dp `outline`-grey hairline (`RoundedRectangleBorder.side`), per the mockup.
- Tests: mini-player Part B assertions repointed (waveform → gradient check; tint → glow BoxShadow colour), playing-state test switched to fixed pumps, new hairline-border test.
- Verification: `flutter analyze` clean, `flutter test` 807/807 green.

## 2026-07-11 — Version bump to 4.8.1 (redesign fix-round release)

- **`android/app/pubspec.yaml`**, **`backend/pyproject.toml`**, **`backend/app/main.py`**, **`android/docs/ROADMAP.md`**, **`backend/docs/ROADMAP.md`** — version bump 4.8.0 → 4.8.1 per the version-sync convention, covering the "fix round 1" commit (unbounded hero-card layout bug, search-pill radius, animated gradient waveform, subtle minibar border). Android-side only; backend bumped for sync.
- Tagged `v4.8.1`.

## 2026-07-11 — Fix: hero-card waveform was static (never wired `animate`)

User reported the Continue Listening card's waveform doesn't move. Root cause: `ContinueListeningCard` (`android/app/lib/screens/home/continue_listening_card.dart`) builds its `WaveformStrip` without passing `animate:`, so it always fell back to the `false` default — unlike the MiniPlayer, which was correctly wired to `s.isPlaying` in the fix-round-1 pass. Fix: added `animate: s.isPlaying` to the card's `WaveformStrip`.

- New regression test (`test/screens/home/continue_listening_card_test.dart`): "waveform animates while playing, static when paused" — asserts `WaveformStrip.animate` flips both ways across a play/pause transition.
- While writing that test, an unrelated test-harness gotcha surfaced: driving a play→pause transition by calling `pumpWidget` twice with two separate `Stream.value()` `ProviderScope` overrides doesn't reliably rebuild an already-instantiated Riverpod provider — `pumpAndSettle` hung waiting on a `WaveformStrip` animation that was never told to stop, because the second override never actually took effect. This doesn't happen in production (a single `audio_service` stream subscription persists and emits repeatedly). Fixed the test by feeding a shared `StreamController` into one long-lived `ProviderScope`/override (`_wrapStream` helper) and emitting both snapshots into it — the same shape the MiniPlayer test already avoided by never testing this transition.
- Verification: `flutter analyze` clean, `flutter test` 808/808 green (isolated `now_playing_persistence_test.dart` flake under full-suite parallelism reran green standalone — unrelated to this change).

## 2026-07-11 — Fix round 2: progress bar, card mockup fidelity, Favorites routing

User review flagged four more issues:

- **Hero-card progress bar invisible while playing (bug, actually always broken).** `_ProgressBar`'s `FractionallySizedBox` set `widthFactor` but not `heightFactor`; with no `heightFactor` its height derives from its child, and the child `DecoratedBox` had no `child:` — so the gradient fill rendered at **zero height**, always, regardless of play state (confirmed via a widget-test `Rect` probe: `top == bottom`). Fixed by adding `heightFactor: 1.0`.
- **Continue Listening card mismatched the mockup.** Four confirmed diffs, all fixed (`lib/screens/home/continue_listening_card.dart`): the 1.5px `heerrGradient` border ring → a single-colour `heerrMagenta` hairline; the Part B full-card blurred-art backdrop (bled across the whole card, shifting its color per song) removed — text half is plain black again, matching the source (per-song tint stays on the waveform + glows, just not the backdrop); the solid gradient-filled play disc → a thin outlined ring with a `ShaderMask`-gradient icon; a round gradient knob added to the progress bar at the current position (indicative only — seeking still lives on `/player`). `kArtBackdropBlur` removed from `lib/utils/palette.dart` (dead after the backdrop removal).
- **Album art tile enlarged 140px → 161px** (+15%, explicit user request).
- **Favorites Quick Access led to a blank page (bug).** `FavoritesScreen` was built over `getStarred2.view` (Subsonic star primitive) during the redesign — but an earlier ADR ("Subsonic star primitive for Favourites", DECISIONLOG) had already rejected that exact source for this exact reason: starred items aren't a playable list in Navidrome. Users who favorite songs via the app's existing heart icon (`PlaylistMutations.toggleFavourite`, the `Favourites` playlist) saw an empty screen because they'd never used the separate, unrelated star feature. Fixed: `FavoritesScreen` now resolves `favouritesPlaylistProvider` (pre-existing) and delegates to the existing `PlaylistDetailScreen` for the list/play UI instead of a hand-rolled starred-song list. `starredSongsProvider` is untouched — still correctly used by `seedCollectionProvider` (N2 recommendation seeding), just no longer misapplied here.
- Tests: `continue_listening_card_test.dart` — new regression tests for the border colour, ring play button, progress knob, art-tile width; Part B "blurred backdrop" test removed (no backdrop left to test), "no backdrop and fallback tint" retitled and kept (tint-without-art path still exists via the glows). `favorites_screen_test.dart` rewritten around `favouritesPlaylistProvider` + `libraryPlaylistProvider`, delegating render assertions to `PlaylistDetailScreen`'s own content.
- Verification: `flutter analyze` clean, `flutter test` 811/811 green.

## 2026-07-11 — Version bump to 4.8.2 (fix-round-2 release)

- **`android/app/pubspec.yaml`**, **`backend/pyproject.toml`**, **`backend/app/main.py`**, **`android/docs/ROADMAP.md`**, **`backend/docs/ROADMAP.md`** — version bump 4.8.1 → 4.8.2 per the version-sync convention, covering "fix round 2" (progress-bar zero-height bug, hero-card mockup restyle, +15% art width, Favorites repointed to the real Favourites playlist). Android-side only; backend bumped for sync.
- Tagged `v4.8.2`.

## 2026-07-11 — Fix round 3: widget border removed, waveform matches the widget

- **Home-screen App Widget: gradient border removed.** `widget_gradient_border.xml` (2dp magenta→violet rim, layer-list trick) replaced by `widget_background.xml` — a plain solid rounded tile, no border. `hero_widget.xml` drops the now-unneeded 2dp padding; `HeroWidgetProvider.kt` updated (`CORNER_DP` 26→28, `BORDER_DP` + its height subtraction removed) so the album art still fills the tile edge-to-edge correctly.
- **Flutter waveform now matches the widget's waveform.** `tool/gen_widget_wave.py` (the widget's waveform generator) draws all bars **baseline-anchored** — rising from the bottom edge. `WaveformStrip`'s painter was instead centering every bar vertically (symmetric two-sided look) — a different silhouette from the widget it was meant to echo. Fixed: bars now anchor to the bottom and grow up, in both the MiniPlayer and the Continue Listening hero card (same shared `WaveformStrip`). Per-bar height *distribution* (deterministic random vs. the widget's fixed 3-cluster envelope) is unchanged — only the anchor/orientation.
- Verification: `flutter analyze` clean, `flutter test` 811/811 green, `flutter build apk --debug` succeeds (exercises the Kotlin/XML widget changes, which aren't covered by `flutter test`).

## 2026-07-11 — Version bump to 4.8.3 (fix-round-3 release)

- **`android/app/pubspec.yaml`**, **`backend/pyproject.toml`**, **`backend/app/main.py`**, **`android/docs/ROADMAP.md`**, **`backend/docs/ROADMAP.md`** — version bump 4.8.2 → 4.8.3 per the version-sync convention, covering "fix round 3" (widget gradient border removed, MiniPlayer/hero-card waveform baseline-anchored to match the widget). Android-side only; backend bumped for sync.
- Tagged `v4.8.3`.

## 2026-07-11 — Fix round 4: hero card art edge fade + real progress seeking

- **Album art now fades into the card instead of a hard seam.** `lib/screens/home/continue_listening_card.dart` — the art tile's right edge is alpha-faded to transparent via a `ShaderMask` (`BlendMode.dstIn`, white→transparent `LinearGradient`, stops `[0, 0.65, 1]`), revealing the card's `surfaceContainerLow` background underneath instead of a hard vertical border between art and text. Mirrors the home-screen widget's own art treatment (`HeroWidgetProvider.kt` `buildArtBitmap`, `FADE_FRACTION = 0.35`) — same 35% fade fraction, ported from the native `DST_IN` bitmap mask to a Flutter `ShaderMask`.
- **Progress bar is now actually seekable, not just a display.** The bar previously only rendered position — the class doc even said "seeking lives on /player." Added a `GestureDetector` (`onTapDown` + `onHorizontalDragStart/Update`) over the bar area (`Key('continue-listening-seek-area')`) that converts the tap/drag x-offset into a fraction and calls `HeerrAudioHandler.seek(...)`; disabled (no gesture) when duration is unknown. The gesture detector is nested inside the card's outer `InkWell` (which navigates to `/player` on tap) — Flutter's gesture-arena resolves nested tap/drag conflicts in favour of the innermost recognizer, so seeking on the bar no longer also navigates.
- Tests: `continue_listening_card_test.dart` — new `fix round 4` group: art fade asserts a `ShaderMask` with `BlendMode.dstIn` exists; tap-to-seek and drag-to-seek assert `handler.seek(...)` is called with a duration derived from the gesture position; a regression test asserts tapping the seek area does not also push `/player`.
- Verification: `flutter analyze` clean, `flutter test` 815/815 green.

## 2026-07-11 — Version bump to 4.8.4 (fix-round-4 release)

- **`android/app/pubspec.yaml`**, **`backend/pyproject.toml`**, **`backend/app/main.py`**, **`android/docs/ROADMAP.md`**, **`backend/docs/ROADMAP.md`** — version bump 4.8.3 → 4.8.4 per the version-sync convention, covering "fix round 4" (hero card album-art edge fade, tap/drag-to-seek progress bar). Android-side only; backend bumped for sync.
- Tagged `v4.8.4`.

## 2026-07-11 — Fix: hero card progress bar rendered centred, not left-anchored

- **Bug:** the progress track (faint background + gradient fill) visually floated in the middle of the bar instead of starting at the left edge — the fill appeared to "start from the middle." Root cause in `lib/screens/home/continue_listening_card.dart`'s `_ProgressBar`: the track's `SizedBox(height: 5)` only constrained height, leaving width unbounded-but-loose. Its child `Stack` (default `StackFit.loose`) then sized itself to its widest **non-positioned, sized** child — the `FractionallySizedBox` fill, which renders at `progress * trackWidth` wide — not the full bar width. The faint background track is a `Positioned.fill` child, so it doesn't contribute to the Stack's own size; it just fills whatever (shrunken) size the Stack ended up with. The outer `Align` then centred that shrunken track+fill assembly within the full-width bar, instead of the fill starting flush at the left edge. This is the same class of bug as the earlier progress-bar zero-height fix (fix round 2) — a `FractionallySizedBox`/Stack sizing gap, not a state/logic bug.
- **Fix:** added `width: double.infinity` to the track's `SizedBox`, forcing it (and the `Stack` inside) to claim the full bar width regardless of `progress`, so the fill is sized relative to the true full width and starts at the left edge.
- Tests: new pixel-position regression test asserting the fill's rendered `Rect.left` matches the seek area's left edge (not centred) and its width is `progress * barWidth` in **actual rendered pixels**, not just the `FractionallySizedBox.widthFactor` property (which was already correct and didn't catch this class of bug).
- Verification: `flutter analyze` clean, `flutter test` 816/816 green.

## 2026-07-11 — Version bump to 4.8.5 + merge redesign/home-screen into main

- **`android/app/pubspec.yaml`**, **`backend/pyproject.toml`**, **`backend/app/main.py`**, **`android/docs/ROADMAP.md`**, **`backend/docs/ROADMAP.md`** — version bump 4.8.4 → 4.8.5 per the version-sync convention, covering the hero-card progress-bar centring fix. Android-side only; backend bumped for sync.
- `redesign/home-screen` merged into `main` — closes out the Home Screen redesign (HOMESCREEN.md Part A + Part B) and all five user-review fix rounds (v4.8.1–v4.8.5).
- Tagged `v4.8.5`.

## 2026-07-11 — Phase Z: Profile screen redesign (Z1–Z5)

- **Z1 — display/edit split.** New: `lib/screens/profile/profile_edit_screen.dart` (`ProfileEditScreen`, the former `profile_screen.dart` content verbatim; post-save now `pop()`s instead of routing Home). Rewrote `lib/screens/profile/profile_screen.dart` as a display screen: gradient-ring avatar with a pencil badge, display name, `@navidromeUsername`, 2-line-clamped bio — both tap targets push the new `Routes.profileEdit` (`/profile/edit`, nested under `/profile` in `router.dart`). Tests: `profile_edit_screen_test.dart` (migrated wholesale from the old `profile_screen_test.dart`), new `profile_screen_test.dart`, `router_test.dart` coverage for both routes.
- **Z2 — stats row.** New: `lib/providers/profiles/profile_stats.dart` (`profileStatsProvider`, `formatStatCount`) summing `libraryPlaylistsProvider` / `libraryAlbumsProvider` (songs + album count) / `libraryArtistsProvider` — no new endpoints, all L5 cache-aware. Profile screen renders a 4-column Playlists/Songs/Albums/Artists row with dividers; `—` per column on error, matching `_AppVersionTile`'s nice-to-have posture.
- **Z3 — "My Music" + Recently Played + Playlists deep link.** New `recentlyPlayedProvider` (`type=recent`, `home_providers.dart`) and `lib/screens/library/recently_played_screen.dart` (clone of `RecentlyAddedScreen`, empty state "Nothing played yet") at `/library/recently-played`. `LibraryScreen` gained `initialTabIndex`; router's `_tabIndexFor` maps `/library?tab=` to it. Profile screen's "My Music" section: Liked Songs → `/library/favorites`, Downloaded → `/downloads`, Recently Played → new screen, Playlists → `/library?tab=playlists`.
- **Z4 — Settings section + Log Out.** New `Endpoints.authLogout` + `BackendService.logout()` (`POST /auth/logout`, best-effort — failures are swallowed so an unreachable backend never blocks sign-out). Profile screen: Settings/Help & Support/About heerr cards (dialogs for the latter two) + a confirm-gated Log Out button calling `logout()` then `profileRegistryProvider.notifier.setActive(null)` (not `removeProfile` — the profile row survives for re-login); the router's existing redirect handles the `/login` navigation.
- **Z5 — Settings-tab profile card.** New `lib/widgets/profile_avatar_ring.dart` (`ProfileAvatarRing`) extracted from three near-duplicate gradient-ring implementations (Home header, Profile display, new Settings card) and reused in all three. New `lib/screens/settings/profile_card.dart` (`ProfileCard`) inserted at the top of `settings_screen.dart`, pushing `/profile`.
- Verification: `flutter analyze` clean, `flutter test` 849/849 green throughout.

## 2026-07-11 — Version bump to 4.9.0 (Phase Z release)

- **`android/app/pubspec.yaml`**, **`backend/pyproject.toml`**, **`backend/app/main.py`**, **`android/docs/ROADMAP.md`**, **`backend/docs/ROADMAP.md`** — version bump 4.8.5 → 4.9.0 per the version-sync convention, covering the Phase Z Profile screen redesign (Z1–Z6). Android-side only; backend bumped for sync.
- Tagged `v4.9.0`.

## 2026-07-11 — Library screen redesign (Phase X, X1–X6)

- **X1 — shared branded header + tabs.** New `lib/widgets/branded_header.dart` (`BrandedAppBar` with full-logo and compact-greeting variants, `GreetingBlock`, `ProfileAvatarButton`, `greetingForHour` — all extracted from `home_screen.dart`, which now consumes them; `greetingForHour` re-exported for import stability). `heerr_logo.dart`: `showWordmark` param. Library browse scaffold rebuilt: compact-greeting AppBar with a search action, "Your Library" headline, `_LibrarySegmentedTabs` (icon + label per tab over `GradientTabIndicator`) in the new Albums/Artists/Playlists order; `router.dart` `_tabIndexFor` remapped (albums=0 default, artists=1, playlists=2). Tests: new `branded_header_test.dart`; `library_screen_test.dart` reworked for the new default tab/headline.
- **X2 — filter chips + state.** New `lib/providers/library/library_filters.dart`: `LibraryTab`, `AlbumSort`/`ArtistSort`/`PlaylistSort` enums + notifiers, per-tab `downloadedOnlyNotifierProvider` family, pure `sortAlbums`/`sortPlaylists` comparators (null created/year/changed sink to the end). New `lib/widgets/library_filter_chips.dart`: magenta sort chip opening a bottom-sheet picker, Downloaded `FilterChip`, decorative trailing filter icon. Tests: `library_filters_test.dart`, `library_filter_chips_test.dart`.
- **X3 — albums tab.** New `sortedLibraryAlbumsProvider` (`lib/providers/library/library_views.dart`) — sort + optional `markedAlbums` filter over the cached fetch. New `lib/screens/library/album_grid_card.dart` (cover, title, artist, song count, magenta offline check badge). `_AlbumsTab` → `CustomScrollView`: chip row, 9-cap 3-column grid, "Albums ›" header (`_ListSectionHeader`), full list with `artist • year • N songs` subtitles and distinct downloaded-empty state. Tests: `library_views_test.dart` + grid-cap/subtitle widget tests.
- **X4 — alphabet scrubber.** New `lib/widgets/alphabet_scrubber.dart` (`AlphabetScrubber`, pure `letterForDy` + `scrubTargetIndex` with nearest-bucket fallthrough). `_AlbumsTab` became stateful: `ScrollController`, `SliverFixedExtentList` rows (72), pinned chip-row (56) / header (44) heights, `_gridExtent` mirroring the grid geometry; scrubber overlays only under A–Z sort. Tests: `alphabet_scrubber_test.dart` + visibility/jump widget test.
- **X5 — artists tab.** New `sortedLibraryArtistsProvider` (flattens `ArtistIndex` buckets; Downloaded = `markedArtists` + artists of `markedAlbums` via `Album.artistId`). New `lib/providers/library/most_played_artists.dart` (`MostPlayedArtist`, `mostPlayedArtistsFrom` dedupe over `type=frequent`, cap 10). `_ArtistsTab` rewritten: circular-avatar rows ("N albums", chevron), scrubber, `_MostPlayedArtistsRail` (circular art, gradient play badge playing the top album, name). Letter section headers removed — the scrubber replaces them. Tests: provider flatten/sort/join tests, `most_played_artists_test.dart`, row/rail widget tests.
- **X6 — playlists tab.** New `sortedLibraryPlaylistsProvider`. New `lib/screens/library/playlist_grid_card.dart` (`PlaylistGridCard` with bottom-gradient text overlay, `FavoritesGridCard` with starred count, `CreatePlaylistGridCard`). `_PlaylistsTab` rewritten: chip row, 2-column grid (Favorites → up to 6 playlists → Create card; FAB removed, same `CreatePlaylistDialog` flow), "Playlists ›" list (Favorites row, `by owner • N songs` rows, For You tail entry preserved with its key). Tests: card-order/create-flow/For You tests reworked.
- Verification: `flutter analyze` clean and full `flutter test` green at every milestone (856 → 891 tests).

## 2026-07-11 — Version bump to 4.10.0 (Phase X release)

- **`android/app/pubspec.yaml`**, **`backend/pyproject.toml`**, **`backend/app/main.py`**, **`android/docs/ROADMAP.md`**, **`backend/docs/ROADMAP.md`** — version bump 4.9.0 → 4.10.0 per the version-sync convention, covering the Phase X Library screen redesign (X1–X7). Android-side only; backend bumped for sync.
- `android/docs/LIBRARYSCREEN.md` status flipped to IMPLEMENTED; deferrals logged in `DEBT.md`.

## 2026-07-11 — Now Playing redesign plan (NOWPLAYING.md, docs only)

- New `android/docs/NOWPLAYING.md` — implementation plan for the Now Playing screen redesign (phase prefix NP, tasks NP1–NP11): blurred-art immersive background, glass header with "Playing from" context, glowing hero art with on-art download, waveform seek bar replacing the Material `Slider`, transport polish, glass action pill, lyrics peek-sheet restyle, sectioned queue sheet, stretch swipe-up lyrics-takeover interaction, docs + version-bump task. Reference mockup: `/Users/E1621/Documents/Personal/Android/Now Playing.png` (not yet versioned in-repo). §2 lists eight open decisions awaiting user confirmation before implementation. No code changed.

## 2026-07-11 — Now Playing redesign NP1 — immersive blurred-art background

- New `lib/widgets/now_playing_background.dart` (`NowPlayingBackground`): full-bleed heavily-blurred (`ImageFilter.blur` sigma 40, decoded at `cacheWidth: 64`) artwork behind a black scrim, radial vignette, and an optional soft brand-blended glow (`brandBlend()` from `utils/palette.dart`) reused via the existing `AnimatedTint` widget. The blurred-art layer cross-fades on art-URI change via `AnimatedSwitcher` keyed on the URI, using the same 400 ms `kTintTransition` the palette tint already uses. Null artUri falls back to the plain `colorScheme.surface`.
- `screens/player/now_playing_screen.dart`: `_TintedBackground` (flat top-to-bottom `LinearGradient`) deleted; `NowPlayingScreen.build` now wraps `_Body` in `NowPlayingBackground`, passing the current `MediaItem.artUri` and the existing `_tintColor` palette state straight through — the `_maybeRefreshTint` / `paletteExtractorOverride` test seam is untouched.
- New `test/widgets/now_playing_background_test.dart` (4 tests): null-art/null-tint fallback, glow layer present only when a tint is supplied, keyed blurred-art subtree renders, and switching art URIs swaps the keyed subtree. Uses a bounded `pump()` loop instead of `pumpAndSettle` for the art-URI cases — `Image.network` never resolves under `flutter_tester` (same constraint noted in `library_cover_art_test.dart`).
- Verification: `flutter analyze` clean; `flutter test` 895/895 (891 → 895, +4 new).

## 2026-07-11 — Now Playing redesign NP2 — glass header + collapse chevron

- New `lib/widgets/glass_icon_button.dart` (`GlassIconButton`): reusable circular "glass" surface (translucent white fill, hairline border) for chrome buttons; disabled (null `onPressed`) dims the glyph rather than hiding it. Shared building block for NP3/NP4/NP7.
- `screens/player/now_playing_screen.dart` (`_Header`): `BackButton` replaced with a `GlassIconButton` chevron (`Icons.keyboard_arrow_down`, key `now-playing-collapse`) calling `Navigator.of(context).maybePop()` — same pop behavior, glass styling. Added a disabled `GlassIconButton` audio-output placeholder (`Icons.speaker_outlined`) moved from the bottom-actions row (§2.3: no output-routing feature exists yet). Overflow `PopupMenuButton` (key `now-playing-overflow`) gets a glass-circle backdrop; existing keys/behavior (add-to-playlist, sleep timer) unchanged. "NOW PLAYING" label stays static — see DECISIONLOG 2026-07-11 (§2.1's `playContext` threading deferred as disproportionate for this task).
- `screens/player/now_playing_transport.dart` (`_BottomActionsRow`): speaker placeholder removed (moved to header); row now holds only the queue trigger, right-aligned.
- New `test/widgets/glass_icon_button_test.dart` (3 tests). New test in `now_playing_screen_test.dart`: collapse button pops a pushed route (push via `Navigator.push` + tap chevron + assert back on the prior screen).
- Verification: `flutter analyze` clean; `flutter test` 899/899 (895 → 899, +4 new: 3 glass-button + 1 collapse-pop).

## 2026-07-11 — Now Playing redesign NP3 — hero art glow/float/on-art download

- `screens/player/now_playing_screen.dart`: `_WideCoverArt` (12dp radius, no glow) replaced with `_HeroArt` — 28dp radius, hairline border, a soft two-layer glow shadow blended from the palette tint via `brandBlend()` (cross-fades through the existing `AnimatedTint` widget, same 400 ms contract), and a slow ±3px floating breathe (6s `AnimationController`, disabled test-side by the new module-scope `heroArtFloatEnabled` flag — same seam shape as `paletteExtractorOverride`; a repeating controller never satisfies `pumpAndSettle`). Artwork itself is never recoloured, only the glow — matches the Home hero / MiniPlayer adaptive-theming rule.
- New `_HeroArtDownloadButton` (floating top-right on the art, hidden for preview items): reflects the song's real `OfflineSongEntry.state` from `offlineManifestProvider` rather than inventing a single-song download mutation that doesn't exist in this codebase — see DECISIONLOG 2026-07-11 (§2.4). No entry → explains via snackbar; `downloading` → spinner; `queued` → disabled glyph; `failed` → red glyph, tap shows the error; `ready` → magenta glyph, tap calls the real `OfflineMarker.deleteSongLocally`.
- `widgets/glass_icon_button.dart`: added an `iconColor` param (overrides the enabled-state white tint; disabled always dims to `white38` regardless, so a coloured icon never reads as tappable when it isn't).
- Test-seam plumbing: `heroArtFloatEnabled` reset alongside `paletteExtractorOverride` in all six existing `test/screens/player/*_test.dart` files' `setUp`/`tearDown` (every one of them now renders `_HeroArt` via the shared screen).
- New `test/screens/player/now_playing_hero_art_test.dart` (7 tests) covering all five download-button states + the 28dp radius. New `test/widgets/glass_icon_button_test.dart` cases for `iconColor`.
- Verification: `flutter analyze` clean; `flutter test` 908/908.

## 2026-07-11 — Now Playing redesign NP4 — title hierarchy + glass favourite

- `screens/player/now_playing_screen.dart` (`_Body`): title bumped `titleLarge` → `headlineMedium` w800; artist bumped `bodyMedium` → `bodyLarge`, explicit `Colors.white70` (dimmed).
- `_FavouriteButton`: rebuilt on `GlassIconButton` (was a plain `IconButton`); filled heart now `heerrMagenta` (was `Colors.redAccent`) for brand consistency with the rest of the glass chrome. Toggle path (`playlistMutationsProvider.toggleFavourite` + `showApiError`) unchanged.
- New `test/screens/player/now_playing_title_test.dart` (3 tests): title weight/artist colour, default outline heart, favourited → magenta-filled heart (via a direct `favouriteSongIdsProvider` override rather than fighting the Subsonic playlist-lookup chain).
- Verification: `flutter analyze` clean; `flutter test` 911/911.

## 2026-07-11 — Now Playing redesign NP5 — waveform seek bar replaces the Material Slider

- New `lib/widgets/waveform_seek_bar.dart` (`WaveformSeekBar`): deterministic per-track waveform (shares `WaveformStrip.barHeights` — dropped its `@visibleForTesting` restriction since it's now a shared generator, not test-only), painted with `heerrGradient`; bars before the playhead full-alpha, after it dimmed (0.35, via `Paint.color` alpha modulating the shader). Thin white progress line + a glowing magenta thumb at the playhead. Tap jumps directly (`onSeekStart`+`onSeekEnd` back-to-back); drag previews via `onSeekUpdate` and commits on release — same three-callback shape the old `Slider` used, so `_Scrubber`'s existing scrub-override plumbing in `now_playing_screen.dart` needed zero changes. Exposes `Semantics(slider: true, value/increasedValue/decreasedValue)`. Bar-breathing only while playing, gated by a new `waveformSeekBarAnimateEnabled` test-seam flag (same shape as `heroArtFloatEnabled`) — reset alongside it in all eight `test/screens/player/*_test.dart` files, since `_Scrubber` renders unconditionally as part of `_Body`.
- `screens/player/now_playing_transport.dart`: `_Scrubber` is now a thin wrapper over `WaveformSeekBar` (keeps its name/call shape so `_Body`'s call site only needed two new params: `playing`, `seed: item.title.hashCode`). Deleted `_GradientSliderTrackShape` (no longer referenced) and the `Slider`/`SliderTheme` import usage.
- New `test/widgets/waveform_seek_bar_test.dart` (6 tests: labels, slider semantics, tap-seeks, drag-then-commit, zero-duration disables gestures, animate-flag doesn't hang pumpAndSettle). `now_playing_screen_test.dart`'s old `Slider`-typed assertion replaced with a `WaveformSeekBar` + label assertion.
- Verification: `flutter analyze` clean; `flutter test` 917/917.

## 2026-07-11 — Now Playing redesign NP6 — transport polish + tap-scale

- `screens/player/now_playing_transport.dart` (`_Transport`): all handler wiring, keys, and mode-cycling logic unchanged — visual only. New `_TapScale` wrapper (scales pressed buttons to 0.92 over 100ms via `AnimatedScale`, observed through `Listener` rather than a `GestureDetector` so it never joins the gesture arena or interferes with the wrapped `IconButton`'s own tap handling) applied to all five transport buttons. Play/pause circle bumped 40dp → 44dp icon (~72dp overall) and gained a soft `heerrMagenta` glow shadow.
- `_BottomActionsRow` (queue trigger) is untouched — its removal is deferred to NP7, which is when the glass action pill actually gains the Queue slot; deleting it now (per the plan's literal NP6 task list) would leave Queue with no access point for one commit.
- New test in `now_playing_modes_test.dart`: pressing the shuffle button scales it to 0.92, releasing restores 1.0, and the wrapped button's own `setShuffleMode` call still fires normally.
- Verification: `flutter analyze` clean; `flutter test` 918/918.

## 2026-07-11 — Now Playing redesign NP7 — glass action pill (Queue / Lyrics / Timer / Add to playlist)

- New `lib/screens/player/now_playing_action_pill.dart`: `_ActionPill` (rounded glass container, 4 equal slots with thin dividers) + reusable `_PillSlot` (icon + tiny label, `InkWell` tap). Slots: **Queue** (key `now-playing-queue-button`, relocated from the deleted `_BottomActionsRow`), **Lyrics** (`now-playing-pill-lyrics`, opens `_ExpandedLyricsSheet` — a second entry point alongside the lyrics card's own expand icon), **Timer** (`now-playing-pill-timer` when idle; swaps to the existing `_SleepCountdownChip` — same widget/key/behavior — when a timer is armed), **Add to playlist** (`now-playing-add-to-playlist`, relocated from the header kebab). Equalizer slot dropped — see DECISIONLOG 2026-07-11 (§2.2).
- `screens/player/now_playing_screen.dart` (`_Header`): the overflow `PopupMenuButton` (key `now-playing-overflow`) and the header's own `_SleepCountdownChip` mount are both removed — single source for these actions now that the pill exists. Header keeps only the collapse chevron, "NOW PLAYING" label, and the disabled audio-output placeholder. `_Body` wires the new pill in after `_Transport`.
- `screens/player/now_playing_transport.dart`: `_BottomActionsRow` deleted (its Queue button moved into the pill).
- Test migration (planned key-contract change, not a regression): `now_playing_add_to_playlist_test.dart` and `now_playing_sleep_timer_test.dart` rewritten to tap the pill slots directly instead of opening the removed overflow menu; one test's ambiguous `find.text('Add to playlist')` (now matching both the pill's own label and the sheet's button) disambiguated via the sheet's `add-to-playlist-expand` key. New test in `now_playing_lyrics_expand_test.dart`: the pill's Lyrics slot opens the same expanded sheet as the card's expand icon.
- Verification: `flutter analyze` clean; `flutter test` 919/919.

## 2026-07-11 — Now Playing redesign NP8 — lyrics peek sheet restyle

- `screens/player/now_playing_lyrics.dart` (`_LyricsSection`): tint-filled `Material` card replaced with a glass card (translucent white 4% fill + hairline border) over the `NowPlayingBackground` — the palette tint no longer drives the card's fill, only the active-line accent. Added a decorative drag-handle bar and an uppercase "LYRICS" label with a magenta/tint-blended underline accent (was title-case "Lyrics" in the tint-adaptive foreground colour).
- New `accentColor` param threaded through `_LyricsContent` → `_SyncedLyricsPreview` / `_SyncedLyrics`: `brandBlend(tintColor)` when a palette tint exists, `heerrMagenta` otherwise. The active line in both the peek preview and the expanded sheet now renders through a `ShaderMask` (accent → white left-to-right gradient) instead of a flat colour — the plan's "simplest faithful rendering" of the mockup's magenta-highlighted active line (word-level timing isn't in the LRC data, so this is line-level, not word-level).
- `_ExpandedLyricsSheet`: backdrop darkened further (0.45 → 0.6 lerp toward black) and gained a hairline top border, nudging it toward the glass language without re-architecting it as a true see-through backdrop — that full integration is NP10's job (retiring the modal sheet entirely in favour of the swipe-up in-place transition).
- All five `_LyricsContent` state branches (loading/error/empty/plain-text/synced) and every existing key are unchanged — restyle only.
- Updated the existing "lyrics render inside a card" test to scope its label assertion to the card via `find.descendant` (the action pill's own "Lyrics" slot label, added in NP7, would otherwise collide with a screen-wide `find.text('Lyrics')` check).
- Verification: `flutter analyze` clean; `flutter test` 919/919.

## 2026-07-11 — Now Playing redesign NP9 — sectioned queue sheet

- `screens/player/now_playing_transport.dart` (`_QueueList` rewrite): the flat `ReorderableListView` becomes a `CustomScrollView` with three regions — items before the current track render dimmed with no header ("earlier" is cheaper than a third "History" section, per the plan), a "NOW PLAYING" section with the current track's own non-reorderable/non-dismissible row, and "NEXT UP" — the only slice that's actually reorderable/dismissible, via `SliverReorderableList` (the same primitive `ReorderableListView` wraps) so it can sit in the `CustomScrollView` without nesting one scrollable inside another.
- Index mapping: the reorderable sub-list is 0-based over `nextUp`; a local index `i` maps to the real audio-handler queue index via `currentIndex + 1 + i`. `onReorderItem` (not the deprecated `onReorder`) already reports the final target index with no further off-by-one adjustment.
- New `_QueueRow` (cover-art thumb via `Image.network(item.artUri)` — queue `MediaItem`s only carry a resolved URI, not a raw Subsonic `coverArtId`, so `LibraryCoverArt` isn't usable here; equalizer icon for the current row) and `_QueueSectionLabel`.
- Fixed two real bugs surfaced by the rewrite, not just test churn: (1) the sheet's `ListTile`s needed a `Material` ancestor once the sheet gained a plain `DecoratedBox` glass background — added a transparent `Material` wrapper; (2) `SliverReorderableList`, unlike `ReorderableListView`, doesn't wrap the dragged item's drag-proxy in its own `Material` when the framework hoists it into the ambient `Overlay` mid-drag — each row in the Next Up list now gets its own `Material(type: transparency)` wrapper so the drag proxy never loses its ancestor.
- `_openQueueSheet`: glass sheet chrome (28dp top corners, translucent near-black fill, hairline top border) via a custom `backgroundColor: Colors.transparent` + `builder`, replacing the framework's default opaque sheet Material.
- Test migration (planned, not a regression): "rows render drag handles" (3→2, Now Playing has none) and "dragging a handle reorders" (now drags a Next Up handle, asserting real queue indices `(1, 2)` instead of `(0, 1)`) rewritten for the new semantics. New tests: section labels present and scoped correctly (disambiguated against the header's own static "NOW PLAYING" text via a new `now-playing-queue-sheet` key), and the "current track isn't first" dimmed-earlier-item scenario.
- Verification: `flutter analyze` clean; `flutter test` 920/920.

## 2026-07-11 — Now Playing redesign NP10 — swipe-up gesture (reduced scope)

- `screens/player/now_playing_screen.dart` (`_HeroArt`): new `onSwipeUp` callback + vertical `GestureDetector` (key `now-playing-hero-swipe-area`) tracking cumulative drag delta and fling velocity. An upward swipe (≥60px cumulative drag, or `primaryVelocity` < -600) opens `_ExpandedLyricsSheet` — the same modal the NP7 Lyrics pill slot and NP8 expand icon already open. Small vertical wobbles (≤10px) don't trigger it.
- This is a **reduced-scope** implementation of the plan's NP10 spec — a discrete swipe-opens-the-existing-sheet gesture, not the full continuous drag-morph transition (hero art shrinking into a floating corner thumb, title/transport/pill fading, waveform crossfading into a progress line, all interactively scrubbable). See DECISIONLOG 2026-07-11 for the full scoping rationale — the plan itself pre-authorized this fallback ("timebox; if it slips, ship NP1–NP9 and log NP10 to DEBT"). Swipe-down-to-dismiss and the collapse chevron were already covered by `showModalBottomSheet`'s default drag-to-dismiss behaviour — no new code needed there.
- New tests in `now_playing_lyrics_expand_test.dart`: swipe-up opens the sheet; a small vertical wobble does not.
- Verification: `flutter analyze` clean; `flutter test` 922/922.

## 2026-07-11 — Now Playing redesign NP11 — docs, roadmap, version bump to 4.11.0

- `android/app/pubspec.yaml`, `backend/pyproject.toml`, `backend/app/main.py`, `android/docs/ROADMAP.md`, `backend/docs/ROADMAP.md` — version bump 4.10.0 → 4.11.0 per the version-sync convention, covering the Now Playing screen redesign (NP1–NP10). Android-side only; backend bumped for sync.
- `android/docs/NOWPLAYING.md` status flipped to IMPLEMENTED (NP1–NP10, v4.11.0; NP10 noted as shipped in reduced scope).
- `android/docs/DEBT.md`: new "Now Playing redesign deferrals" section — NP10's full continuous drag-morph, the §2.1 playing-from-context label, the §2.2 equalizer slot, the §2.4 single-song ad-hoc download, word-level lyric highlighting, and on-device smoke (pending — no device attached during implementation).
- Verification: `flutter analyze` clean; `flutter test` 922/922 across the whole NP1–NP10 phase (up from 895 at NP1, i.e. +27 new tests through the phase).

## 2026-07-12 — Now Playing + Profile fix pass (user feedback vs. the source mockup)

- **Profile "Liked Songs" / "Recently Played" rows did nothing on-device.** Root cause: go_router 14.8.1 throws a duplicated-page-key assertion (`!keyReservation.contains(key)` in `Navigator._debugCheckDuplicatedPageKeys`) when `push`-ing a ShellRoute-nested route (`/library/favorites`, `/library/recently-played`) while the top of the stack is an imperatively-pushed non-shell route (`/profile`, pushed from the Home avatar) — in release builds the exception is swallowed and the tap silently no-ops. The pre-existing test missed it because it stubbed a flat router where those routes weren't shell-nested. Fix: `screens/profile/profile_screen.dart` routes both rows through `context.go` (like the Downloads/Playlists/Settings rows already did). New `test/screens/profile/profile_nav_real_router_test.dart` (2 tests) reproduces the exact on-device stack against the real `buildHeerrRouter` — red before the fix, green after.
- **Lyrics active line wasn't pink (mockup: "P1 cleaner" in magenta).** `_LyricsSection` / `_ExpandedLyricsSheet` used `brandBlend(tint)` for the active-line accent — an 18% shift toward magenta, so a blue/green cover produced a blue/green highlight. Accent is now always `heerrMagenta`, and both `ShaderMask`s hold the magenta through ~30% of the line before blending to white (matching the mockup's leading-words-pink split) instead of a full-width linear fade.
- **Expanded lyrics sheet still looked like the old design.** `_ExpandedLyricsSheet` rebuilt on the new language: `NowPlayingBackground` (blurred art + scrim + glow) instead of the flat tint-lerped fill, `GlassIconButton` collapse chevron, "LYRICS" label + magenta underline beside the corner art (same treatment as the peek card), 28dp top corners. `_CornerArt` restyled to a 16dp-radius hairline-bordered miniature of the hero art. All keys (`now-playing-lyrics-sheet`, `lyrics-sheet-collapse`, `lyrics-sheet-art`) unchanged.
- **Background read near-black instead of the mockup's magenta atmosphere.** `widgets/now_playing_background.dart`: scrim lightened 0.72 → 0.55 so the blurred art's colour bleeds through; the glow is now always present (brand magenta before the palette resolves, `brandBlend(tint)` after) and doubled — a stronger upper wash (alpha 0.4 core) behind the hero art plus a soft lower wash behind the lyrics area. `now_playing_background_test.dart` updated: the "no tint → no glow" assertion became "no tint → brand-magenta glow fallback" (deliberate design change).
- Verification: `flutter analyze` clean; `flutter test` 924/924 (922 → 924, +2 regression tests).

## 2026-07-12 — Version bump to 4.11.1 (Now Playing + Profile fix pass release)

- **`android/app/pubspec.yaml`**, **`backend/pyproject.toml`**, **`backend/app/main.py`**, **`android/docs/ROADMAP.md`**, **`backend/docs/ROADMAP.md`** — version bump 4.11.0 → 4.11.1 per the version-sync convention, covering the 2026-07-12 fix pass (profile nav crash, lyrics magenta accent, expanded-sheet restyle, background atmosphere). Android-side only; backend bumped for sync.

## 2026-07-12 — Fix: Library/Playlists Favorites tile missing song count

- **Root cause:** `screens/library/library_tabs.dart` computed `favoritesCount` from `starredSongsProvider` (`providers/library/starred_songs.dart`), which wraps the Subsonic `star.view`/`getStarred2.view` primitive. Since the `v4.8.2` repoint (favoriting now writes to a real Navidrome playlist named `Favourites` via `PlaylistMutations.toggleFavourite`, per `providers/library/favourites.dart`), nothing calls the star primitive anymore, so the starred list stayed empty and the count text (conditional on non-null in `playlist_grid_card.dart`'s `FavoritesGridCard`/`_GridCardShell`) never rendered.
- **`screens/library/library_tabs.dart`** — `favoritesCount` now reads `ref.watch(favouritesPlaylistProvider).valueOrNull?.songCount` (the real Favourites playlist's own song count) instead of `starredSongsProvider.valueOrNull?.length`. Feeds both the Playlists-tab grid's `FavoritesGridCard` and the Playlists-tab list row.
- **`screens/library/library_screen.dart`** — import swapped from `providers/library/starred_songs.dart` to `providers/library/favourites.dart`.
- Verification: `flutter analyze` clean on both touched files.

## 2026-07-12 — Version bump to 4.11.2 (Favorites tile count fix release)

- **`android/app/pubspec.yaml`**, **`backend/pyproject.toml`**, **`backend/app/main.py`**, **`android/docs/ROADMAP.md`**, **`backend/docs/ROADMAP.md`** — version bump 4.11.1 → 4.11.2 per the version-sync convention, covering the Favorites tile song-count fix above. Android-side only; backend bumped for sync.

## 2026-07-12 — Downloads Screen redesign plan (DL1–DL8, docs only)

- **`android/docs/DOWNLOADSSCREEN.md`** — new plan doc: rework Downloads into a "Sync Center" — branded header, server-status hero with waveform sync progress, Sync Now / Manage Storage quick actions, sync-activity cards, Library-style tabs + filter chips, metadata-rich song rows, storage-breakdown card, empty state. Includes data-reality audit against `lib/offline/` providers (throughput and IPv6 status have no data source — dropped/DEBT), task breakdown DL1–DL8, and 7 open decisions (D1–D7) pending user confirmation. No code changed.

## 2026-07-12 — Downloads redesign DL1: screen shell restructure

- **`lib/screens/downloads_screen.dart` → `lib/screens/downloads/downloads_screen.dart` + `downloads_tabs.dart`** — moved to its own directory (matches `screens/home/`, `screens/library/` convention); split into a shell file (header, title/subtitle, pinned segmented `TabBar`) and a `part` file holding the three tab bodies (`_SongsTab`, `_AlbumsTab`, `_PlaylistsTab`) plus the existing W1 delete-sheet flow, moved unchanged.
- Shell now uses `NestedScrollView` (scrollable header slivers + `SliverPersistentHeader(pinned: true)` tab bar) instead of a plain `AppBar.bottom` `TabBar`, so DL2-DL7's hero/quick-action/sync-activity/storage sections can slot in as additional header slivers without another rewrite. Header uses the shared `BrandedAppBar(compactGreeting: true)` (same as Library) plus a new "Downloads" headline + "Your music, available everywhere." subtitle.
- Tab order changed to **Songs / Albums / Playlists** (D3, `DOWNLOADSSCREEN.md` §8) — Songs first, using the Library segmented-tab visual (`GradientTabIndicator`, `heerrMagenta` label color, icon+label per tab).
- **`lib/router.dart`**, **`test/screens/downloads_screen_delete_test.dart`** — import paths updated to `screens/downloads/downloads_screen.dart`.
- Verification: `flutter analyze` clean; full `flutter test` green (924 tests, including the W1 delete-sheet regression suite unchanged).

## 2026-07-12 — Downloads redesign DL2: server-status hero card

- **`lib/services/backend_service.dart`** — new `health()` method, `GET /health` → `bool` (true iff `{"status": "ok"}`). Follows the same `apiCall`-wrapped pattern as `recommendHealth()`; failures surface as the typed `ApiError` hierarchy like every other call.
- **`lib/providers/server_status.dart`** (new) — `ServerStatusNotifier` (`@riverpod`, autoDispose): probes `BackendService.health()` immediately on build, then every 30s via `Timer.periodic` while the Downloads screen holds a listener (screen-scoped polling — the Timer is cancelled on `ref.onDispose`, no background polling once the user navigates away). No probe at all when no profile is configured (`ServerCreds.navidromeBaseUrl` null/empty) — returns `(online: false, errorMessage: 'No server configured', ...)` without a network call.
- **`lib/widgets/waveform_strip.dart`** — new optional `progress` param (0..1). When set, bars up to that fraction (by index) paint at full color/gradient; the rest paint at 25% opacity. Turns the existing decorative strip into a sync-progress indicator without touching any of its current decorative call sites (`progress` defaults to null, fully backward compatible).
- **`lib/screens/downloads/server_glyph.dart`** (new) — `CustomPaint` server-rack outline (Nothing-OS style: thin strokes, rounded, no photorealism). Soft magenta glow breathes on a 3s `AnimationController` loop while `online`; static and dim when offline.
- **`lib/screens/downloads/server_status_card.dart`** (new) — hero card combining `serverStatusNotifierProvider` (online/offline + error), `offlineSyncProvider` (sync progress/lastTickAt), and `serverCredsProvider` (hostname). Four render states: online+idle (hostname + "via Tailscale" caption, last-synced relative time — D4), online+syncing (animated `WaveformStrip` progress bar, "N songs remaining • NN%"), offline (dim glyph, "Server unreachable"), sync error (surfaces `lastError`/status error text in place of the idle caption).
- **`lib/screens/downloads/downloads_screen.dart`** — `ServerStatusCard` slotted in as a header sliver between the title and the pinned tab bar.
- Verification: `flutter analyze` clean; full `flutter test` green (934 tests — 10 new: `backend_service_test.dart` `health` group ×3, `waveform_strip_test.dart` ×3, `server_status_test.dart` ×4).

## 2026-07-12 — Downloads redesign DL3: quick action cards

- **`lib/screens/downloads/quick_action_cards.dart`** (new) — `QuickActionCards`: two rounded outlined cards, "Sync Now" and "Manage Storage". Sync Now reuses the same manual-trigger + result-copy pattern as Settings > Offline's "Sync now" button (`offlineSyncProvider.notifier.syncNow()`, "Synced: N downloaded, M failed, K cleaned up" / "Sync: <error>" / "Nothing to do."), disabled with a spinner while a sync is in flight; unlike the Settings button it chains `hideCurrentSnackBar()` before the result snackbar so the two queued messages ("Syncing…" → result) don't wait out each other's full duration. Manage Storage pushes to `Routes.settings` (`context.push`), where the offline/storage controls already live — no new screen.
- **`lib/screens/downloads/downloads_screen.dart`** — `QuickActionCards` slotted in as a header sliver below the hero.
- Verification: `flutter analyze` clean; full `flutter test` green (936 tests — 2 new in `test/screens/downloads/quick_action_cards_test.dart`).

## 2026-07-12 — Downloads redesign DL4: sync activity section

- **`lib/providers/sync_activity.dart`** (new) — `syncActivityProvider`: counts songs by manifest state (`downloading`/`queued`/`failed`) plus a `waitingForWifi` flag (`OfflineSettingsValue.wifiOnly` true, some work pending, and `WifiCheck.isOnWifi()` false). Deliberately count-based, not per-song — per-song titles/byte-progress aren't tracked (D5, `DOWNLOADSSCREEN.md` §2), so "3 downloading" replaces the brief's "After Hours 32%".
- **`lib/screens/downloads/sync_activity_section.dart`** (new) — `SyncActivitySection`: up to three compact cards (Downloading, Queued, and a third slot — Waiting-for-Wi-Fi when the gate is holding work back, else Failed, else omitted). Renders nothing when there's nothing to report. Downloading card carries a small animated `WaveformStrip` (equalizer motion only, no progress fraction — matches the count-only data).
- **`lib/screens/downloads/downloads_screen.dart`** — `SyncActivitySection` slotted in as a header sliver below the quick actions.
- Verification: `flutter analyze` clean; full `flutter test` green (944 tests — 8 new: `sync_activity_test.dart` ×5, `sync_activity_section_test.dart` ×3).

## 2026-07-12 — Downloads redesign DL5: filter chips

- **`lib/providers/downloads_filters.dart`** (new) — mirrors `library_filters.dart`'s pattern: `DownloadsTab` enum (songs/albums/playlists, matching the DL1 tab order), `DownloadsSongSort` (recent/largest/aToZ) for the Songs tab, `DownloadsContainerSort` (recent/alphabetical) shared by Albums and Playlists, plus standalone `DownloadsLosslessOnlyNotifier` / `DownloadsTodayOnlyNotifier` toggles (Songs tab only). Chips only hold state here — DL6 wires the actual sort/filter application once the metadata join lands.
- **`lib/screens/downloads/downloads_filter_chips.dart`** (new) — `DownloadsFilterChips`: sort chip (bottom sheet, same visual/interaction as `LibraryFilterChips`'s `_SortChip`) on every tab; "Lossless" and "Downloaded Today" toggle chips added only on Songs. Wrapped in a horizontally-scrolling row (Songs has 4 controls vs Library's 2, so it can overflow on narrow phones).
- **`lib/screens/downloads/downloads_screen.dart`** — chip row slotted in as a header sliver below the pinned tab bar, tracking the active tab via `AnimatedBuilder(animation: _tabs, ...)` so the right chip set renders per tab without a second `TabController` listener class.
- Verification: `flutter analyze` clean; full `flutter test` green (949 tests — 5 new in `downloads_filter_chips_test.dart`).

## 2026-07-12 — Downloads redesign DL6: metadata-rich rows + join provider

- **`lib/providers/downloads_views.dart`** (new) — `downloadedSongsViewProvider` joins `downloadedSongsProvider` with each song's manifest entry (`(Song, OfflineSongEntry)` rows), then applies the DL5 chip state: Lossless-only (`kLosslessSuffixes = {flac, alac, wav}`, D7), Downloaded-Today-only, and the sort chip (`sortDownloadedSongRows` — recent/largest/A-Z, pure + unit-tested). `sortedDownloadedAlbumsProvider` / `sortedDownloadedPlaylistsProvider` resolve the downloaded ids to full `Album`/`Playlist` metadata and reuse Library's existing `sortAlbums`/`sortPlaylists` pure helpers instead of re-deriving sort logic.
- **`lib/screens/downloads/downloads_tabs.dart`** — Songs tab rows now show a metadata line under the artist/album subtitle: "Lossless • Yesterday • 24 MB" built from the manifest entry's `suffix`/`downloadedAt`/`size`; added a trailing kebab (`Icons.more_vert`) that opens the same W1 delete sheet as long-press (both paths kept — long-press wasn't removed). Albums/Playlists rows gained a "N of M songs ready" sub-line, computed from the already-fetched `Album.song`/`Playlist.entry` list against the manifest — no extra provider needed.
- **`test/screens/downloads_screen_delete_test.dart`** — fixed a latent test-infrastructure bug this task's larger widget tree exposed: `ServerStatusNotifier`/`OfflineSync` schedule a real `Timer.periodic` and hit the network in `build()`; under `pumpAndSettle`'s fake-time pump loop that Timer re-fired repeatedly, each tick's real (unmocked) HTTP call dragging in real wall-clock time until the test timed out. Both providers are now overridden with static, Timer-free stubs in this test (and the new DL6 widget tests) — a real fix, not a workaround, since any future widget test rendering the full `DownloadsScreen` needs the same treatment.
- Verification: `flutter analyze` clean; full `flutter test` green (960 tests — 11 new: `downloads_views_test.dart` ×6, `downloads_views_containers_test.dart` ×3, `downloads_song_row_test.dart` ×2).

## 2026-07-12 — Downloads redesign DL7: storage breakdown card

- **`lib/providers/storage_breakdown.dart`** (new) — `storageBreakdownProvider`: actual on-disk usage, unlike `offlineSizeEstimateProvider` (which estimates a *future* sync-all). Music is a cheap sum of `OfflineSongEntry.size` over `ready` manifest entries — no disk walk. Artwork/Lyrics/Cache are recursive directory walks (`dirSizeBytes`, exported for testing) over `OfflinePaths.coversDir` / `lyricsDir` / `libraryCacheDir`; missing directories and unreadable files degrade to 0 rather than throwing (same fail-soft convention as the rest of `OfflinePaths`).
- **`lib/screens/downloads/storage_card.dart`** (new) — `StorageCard`: one stacked horizontal bar (Music/Artwork/Lyrics/Cache, `heerrGradient`-family tints) + a legend with per-category size and percentage. Renders nothing while the total is zero or the provider hasn't resolved yet — no placeholder skeleton needed for a card this far down the scroll.
- **`lib/screens/downloads/downloads_tabs.dart`** — `StorageCard` appended as the last item in each tab's `ListView` (so it scrolls with content, matching the brief's placement below the song list) via a new `_TabEmptyWithStorage` wrapper for the empty-state path (storage usage is orthogonal to whether the *current* tab's list is empty, so it still renders there).
- Verification: `flutter analyze` clean; full `flutter test` green (967 tests — 7 new: `storage_breakdown_test.dart` ×5, `storage_card_test.dart` ×2).

## 2026-07-12 — Downloads redesign DL8: empty state, docs flush, version bump to 4.12.0

- **`lib/screens/downloads/downloads_screen.dart`** — unified whole-library empty state (DOWNLOADSSCREEN.md §6): when the manifest has nothing marked and nothing downloaded (`markedAlbums`/`markedPlaylists`/`markedArtists`/`songs` all empty), sync-activity/tabs/chips/content collapse into one `_DownloadsEmptyState` (`GradientIcon`, "Nothing available offline yet.", `GradientButton` "Browse Library" → `Routes.library`) rendered as a `SliverFillRemaining`; the hero + quick actions above it still render, since server status is useful even at zero downloads.
- **`lib/screens/downloads/downloads_tabs.dart`** — fixed a `RenderFlex` overflow in `_TabEmptyWithStorage` (DL7's per-tab empty-state-plus-storage-card wrapper): `Column(Expanded(...))` assumed generous vertical space and overflowed once the full hero/quick-action/sync-activity header stack left little room for a short viewport; switched to a plain `ListView` (scrolls instead of overflowing, regardless of how much space the header sections above have already consumed). Same fix applied to the new whole-library empty state (`SingleChildScrollView` instead of `Center`) for the same reason.
- **`android/docs/DEBT.md`** — logged the Downloads redesign's deferrals: per-file throughput/percentage (no data source), the hero waveform's progress-tween animation (deferred polish), the dropped Artists tab (D2) and IPv6 status line (D4), and pending on-device smoke.
- **Version bump 4.11.2 → 4.12.0** — `android/app/pubspec.yaml`, `backend/pyproject.toml`, `backend/app/main.py`, `android/docs/ROADMAP.md`, `backend/docs/ROADMAP.md` (Android-side change; backend bumped for sync per the version-sync convention).
- **`android/docs/DOWNLOADSSCREEN.md`** — status flipped to IMPLEMENTED.
- Verification: `flutter analyze` clean; full `flutter test` green (971 tests — 4 new in `downloads_empty_state_test.dart`).

## 2026-07-12 — Downloads hero: green Online pill + real server illustration

- **`lib/theme.dart`** — new `heerrOnlineGreen` (`#22C55E`), a status-only exception to the brand palette's "no green" rule — online/offline is a universally-understood green/grey semantic, kept separate from `heerrGradient`.
- **`lib/screens/downloads/server_status_card.dart`** — the "Online" pill now uses `heerrOnlineGreen` instead of `heerrMagenta` (offline stays `Colors.white38`); card border/glyph glow are unchanged (still magenta).
- **`android/app/assets/images/downloads_server.png`** (new) — user-supplied server illustration (dark cube-shaped device, magenta rim light, glow platform), added to `pubspec.yaml` assets.
- **`lib/screens/downloads/server_glyph.dart`** — replaced the `CustomPaint` rack-outline illustration with `Image.asset` of the new artwork; kept the breathing-glow animation (now a `BoxShadow` behind the image) and the offline-dim behavior (`Opacity` 0.5 instead of the painter's dim stroke color).
- Verification: `flutter analyze` clean; full `flutter test` green (971 tests, no new — visual-only change).

## 2026-07-12 — Version bump to 4.12.1 (Downloads hero fix pass release)

- **`android/app/pubspec.yaml`**, **`backend/pyproject.toml`**, **`backend/app/main.py`**, **`android/docs/ROADMAP.md`**, **`backend/docs/ROADMAP.md`** — version bump 4.12.0 → 4.12.1 per the version-sync convention, covering the green Online pill + real server illustration fix above. Android-side only; backend bumped for sync.

## 2026-07-12 — Settings redesign planning round (SE, docs only)

- **`android/docs/SETTINGSSCREEN.md`** (new) — full redesign plan for the Settings screen ("Control Center"): target layout, mockup-vs-reality table (Audio Quality / Equalizer / Appearance / Notifications / Language / Devices / Backup rows dropped — no data source or explicit ROADMAP out-of-scope), promoted Server & Sync card reusing `serverStatusProvider` + `StatusPill`, reusable `SettingsTile` system, task breakdown SE1–SE7, open decisions D1–D7. No code changes.
- Reference mockup at `/Users/E1621/Documents/Personal/Android/Settings.png` (not yet copied into the repo).

## 2026-07-12 — Settings redesign SE1: restructure screen shell + header + title

- Moved `lib/screens/settings_screen.dart` -> `lib/screens/settings/settings_screen.dart` (+ its part files `settings_offline.dart`, `settings_recommendations.dart`), matching the `screens/<feature>/` layout used by Home/Library/Downloads. Updated `lib/router.dart` import.
- `SettingsScreen` now uses `CustomScrollView` with `BrandedAppBar()` (default, non-compact — logo mark + wordmark, no greeting per D2) and a new `_SettingsTitle` headline/subtitle sliver ("Settings" / "Customize heerr the way you like."), mirroring `_DownloadsTitle`.
- Existing sections (Profile card, collapsible Profiles/Offline/Recommendations, app-version footer) rehosted unchanged — visual restyle is SE2-SE6.
- `test/router_test.dart` — Settings' AppBar title is no longer `Text('Settings')`, it's `HeerrLogo` (shared with Home). Added `_expectOnSettings()` helper (AppBar title type + body headline text) replacing the three `_activeTitle(tester) == 'Settings'` assertions that broke.
- `test/screens/settings_screen_test.dart` — import path updated to `package:heerr/screens/settings/settings_screen.dart`.
- Verification: `flutter analyze` clean; full `flutter test` green (971 tests).

## 2026-07-12 — Settings redesign SE2: reusable settings tile system

- New `lib/screens/settings/settings_tiles.dart`: `SettingsSectionHeader`, `SettingsGroupCard` (floating rounded card, `surfaceContainerHigh` fill, dividers between rows, none trailing/leading), `SettingsTile` (leading icon in solid `heerrMagenta` — matches existing icon usage in this screen rather than the plan doc's `GradientIcon` wording, which is reserved for hero accents elsewhere in the app), `SettingsSwitchTile`, `SettingsDropdownTile<T>`. Rows auto-key as `settings-tile-<slug>` via `settingsTileKey()`. Min row height 56dp (>=48dp a11y target).
- Not yet wired into `settings_screen.dart` — SE3-SE6 consume this system section by section.
- New `test/screens/settings/settings_tiles_test.dart` (9 tests): section header, group-card divider placement, tile anatomy/keying/tap/min-height, switch tile, dropdown tile.
- Verification: `flutter analyze` clean; full `flutter test` green (980 tests).
