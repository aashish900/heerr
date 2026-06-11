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
