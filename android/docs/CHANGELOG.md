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
