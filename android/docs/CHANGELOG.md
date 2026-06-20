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
