# PLAN.md — heerr Android client v1 (frozen contract)

The locked v1 spec for the Android app. Any deviation requires a `DECISIONLOG.md` entry. This file is the source of truth for *what we're building*; `ROADMAP.md` is *how/when*.

---

## 1. Stack

Locked choices (see `DECISIONLOG.md` 2026-06-09 entries for the *why*):

| Concern | Choice | Notes |
|---|---|---|
| Flutter SDK | 3.44.0 stable | Match the user's installed version. |
| Dart | 3.12.0 | Bundled with Flutter 3.44.0. |
| State management | `flutter_riverpod` + `riverpod_annotation` + `riverpod_generator` | Code-generated providers; type-safe DI. |
| HTTP | `dio` | One `Dio` instance shared across all providers; built via Riverpod provider. |
| JSON | `freezed` + `json_serializable` + `build_runner` | Codegen — one command rebuilds models. |
| Token storage | `flutter_secure_storage` | EncryptedSharedPreferences on Android. |
| Navigation | `go_router` | Declarative; supports redirects (used for "no-token → Settings" flow). |
| Lint | `flutter_lints` + custom `analysis_options.yaml` | Strict mode + `prefer_const_constructors`, etc. |
| Test | `flutter_test` + `mocktail` | Widget tests + provider tests. No mockito. |

Versions are pinned in `pubspec.yaml` at milestone A1. Major-version upgrades are DECISIONLOG-worthy events.

---

## 2. Project layout (target shape at end of A1)

```
android/
├── README.md                  ← operational entry point
├── CLAUDE.md                  ← Claude rules
├── docs/                      ← PLAN.md, ROADMAP.md, etc.
└── app/                       ← `flutter create` lives here
    ├── pubspec.yaml           pinned deps + asset declarations
    ├── analysis_options.yaml  flutter_lints + extras
    ├── android/               Android-only manifest + gradle
    ├── lib/
    │   ├── main.dart          ProviderScope + MaterialApp.router
    │   ├── theme.dart         M3 dark theme builder
    │   ├── router.dart        go_router config + redirects
    │   ├── api/
    │   │   ├── client.dart    Dio provider + interceptors
    │   │   └── endpoints.dart endpoint URL constants
    │   ├── models/            freezed models (search results, jobs, etc.)
    │   │   ├── enums.dart            SpotifyType + JobState
    │   │   ├── search_request.dart
    │   │   ├── search_result_item.dart
    │   │   ├── search_response.dart
    │   │   ├── download_request.dart
    │   │   ├── download_response.dart
    │   │   ├── job_view.dart
    │   │   └── queue_response.dart
    │   ├── providers/         Riverpod providers per feature
    │   │   ├── settings.dart      backendUrl + bearerToken (FutureProvider)
    │   │   ├── search.dart        searchQuery, searchResults
    │   │   ├── queue.dart         polling provider
    │   │   └── job_status.dart    polling provider parameterized by jobId
    │   ├── screens/
    │   │   ├── settings_screen.dart
    │   │   ├── search_screen.dart
    │   │   ├── queue_screen.dart
    │   │   └── job_detail_screen.dart
    │   └── widgets/           reusable widgets (StatusPill, ResultTile, etc.)
    └── test/                  widget + provider tests
```

The `app/` subdir holds the Flutter project so that `android/` itself contains the convention docs (CLAUDE.md, README.md, docs/) without polluting `flutter create` defaults.

---

## 3. API contract consumed

Endpoints (from `backend/docs/PLAN.md`):

### `GET /health` (no auth)

```dart
// Settings screen "Test connection" button hits this.
// Response: 200 {"status":"ok"}
// Used to verify URL + (separately) token validity (a request to any other
// endpoint with the bearer header).
```

### `POST /search` (scope `read`)

Source of truth: `backend/app/schemas/search.py`. Models live at `android/app/lib/models/{search_request,search_response,search_result_item}.dart`.

```dart
// Request body.
@freezed
class SearchRequest with _$SearchRequest {
  const factory SearchRequest({
    required String query,             // free text or a spotify URI
    required SpotifyType type,         // track | album | playlist
    @Default(20) int limit,            // 1..50
  }) = _SearchRequest;
}

// Response body — flat list, no envelope `type` field.
@freezed
class SearchResponse with _$SearchResponse {
  const factory SearchResponse({
    required List<SearchResultItem> results,
  }) = _SearchResponse;
}

@freezed
class SearchResultItem with _$SearchResultItem {
  const factory SearchResultItem({
    required String spotifyUri,        // "spotify:track:..."
    required String spotifyUrl,        // "https://open.spotify.com/track/..."
    required String title,
    required String artist,            // formatted "Artist 1, Artist 2"
    String? album,                     // null for playlists
    int? durationMs,                   // null for albums/playlists
    String? coverUrl,                  // 300x300 from Spotify, may be null
    required bool alreadyDownloaded,   // backend hint — dim the row
    String? activeJobId,               // UUID of queued/running job for this URI
  }) = _SearchResultItem;
}
```

### `POST /download` (scope `download`)

Source of truth: `backend/app/schemas/download.py`.

```dart
@freezed
class DownloadRequest with _$DownloadRequest {
  const factory DownloadRequest({
    required String spotifyUri,
    // No "type" field — backend infers from URI prefix.
  }) = _DownloadRequest;
}

@freezed
class DownloadResponse with _$DownloadResponse {
  const factory DownloadResponse({
    required String jobId,
    required JobState state,           // "queued" | "running" | "done" | "failed"
    required bool deduped,             // true if URI was already done OR active
  }) = _DownloadResponse;
}
```

### `GET /status/{job_id}` (scope `read`)

Source of truth: `backend/app/schemas/job.py::JobView`. Note: backend uses
`job_id` (not `id`) and `error` (not `error_msg`); no `attempt_count`,
no `owner_label` in the v1 wire shape; `progress` is reserved (always
`null` in v1).

```dart
@freezed
class JobView with _$JobView {
  const factory JobView({
    required String jobId,
    required String spotifyUri,
    required SpotifyType spotifyType,
    required JobState state,
    int? progress,                     // reserved; null in v1
    String? error,
    String? outputPath,                // populated for "track" jobs only in v1
    required DateTime createdAt,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) = _JobView;
}
```

### `GET /queue` (scope `read`)

Source of truth: `backend/app/schemas/job.py::QueueResponse`.

```dart
@freezed
class QueueResponse with _$QueueResponse {
  const factory QueueResponse({
    required List<JobView> active,     // queued + running
    required List<JobView> recent,     // most-recently-finished 20
  }) = _QueueResponse;
}
```

All timestamps are ISO-8601 UTC; the client renders `relative time` ("just now", "2 min ago") in lists, full timestamp on the job detail screen.

JSON wire keys are snake_case; Dart fields are lowerCamelCase. Mapping is set globally via `android/app/build.yaml` (`field_rename: snake`). Enum values are mapped via `@JsonValue('queued')` etc. in `lib/models/enums.dart`.

---

## 4. Configuration

The user enters two values once on the Settings screen, persisted via `flutter_secure_storage`:

| Key | Example value | Notes |
|---|---|---|
| `backend_base_url` | `http://100.106.120.121:8000/api/v1` | The Tailscale-MagicDNS-or-IP root for the backend API. Trailing slash trimmed. |
| `bearer_token` | `rXq…` | Raw token from `python -m app.cli create-token`. |

No build-time config (`--dart-define`) for v1 — the URL is user-supplied because the tailnet IP is per-installation.

Both keys are read at app launch via a `FutureProvider` and held in memory thereafter. Saving from Settings invalidates the provider so dependent providers (dio client) rebuild.

---

## 5. Routing

go_router configuration:

| Route | Screen | Guarded by |
|---|---|---|
| `/` | Search | `bearer_token` set (else redirect to `/settings`) |
| `/settings` | Settings | none |
| `/queue` | Queue | `bearer_token` set |
| `/job/:id` | Job detail | `bearer_token` set |

Bottom navigation bar with three tabs: Search · Queue · Settings. Job-detail pushes on top of the current tab.

The redirect to `/settings` when the token is missing is a `redirect:` callback on the router.

---

## 6. State management

One `Provider` per concern. Riverpod codegen via `@riverpod`:

- `settingsProvider` — reads/writes secure storage. Reactive.
- `dioClientProvider` — depends on `settingsProvider`; builds a `Dio` instance with the Bearer interceptor + a 10s timeout. Auto-invalidates when settings change.
- `searchQueryProvider` — current query string + type (mutable via the search bar).
- `searchResultsProvider` — `FutureProvider` parameterised by `searchQueryProvider`; debounced 300ms.
- `queueProvider` — `StreamProvider` that ticks every 3s + emits `QueueResponse`.
- `jobStatusProvider(jobId)` — family provider; `StreamProvider` ticking every 2s while state is non-terminal.
- `downloadDispatchProvider` — a function-style provider that exposes `dispatch(uri)` and returns a `Future<DownloadResponse>`.

---

## 7. Theme

```dart
ThemeData heerrDarkTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1DB954), // Spotify green
    brightness: Brightness.dark,
  ),
  // Defaults sufficient otherwise; tweaks in milestone A2.
);
```

A `theme.dart` file is the single source of truth. No per-screen theme overrides except for explicitly-named exceptions documented in DECISIONLOG.

---

## 8. Polling cadence (locked)

- **Queue:** 3000 ms tick. Pauses when the screen is off-foreground (`AppLifecycleState.paused` / `inactive` → cancel timer; `resumed` → restart and force one tick).
- **Job detail:** 2000 ms tick while state ∈ {`queued`, `running`}. Stops once `done` or `failed`. Resumes only on screen re-entry.
- **Search:** no polling. Debounce 300ms on text input.

Polling is implemented via Riverpod's `StreamProvider` + `Stream.periodic`. **Not** via raw `Timer`s leaked from `StatefulWidget`s.

---

## 9. Error UX (locked)

| Backend response | UX |
|---|---|
| 401 Unauthorized | Snackbar "auth failed — re-paste your token". Push to `/settings` after dismiss. |
| 403 Forbidden | Snackbar "this token cannot do {action}" (action ∈ {search, download}). No redirect. |
| 422 Unprocessable | If the failing field is user-entered (e.g. malformed URI), surface inline form error. Else snackbar with the `detail` string. |
| 503 Service Unavailable | Banner "Spotify rate-limited — retry in {Retry-After}s". Auto-retry once after the timer. |
| Network failure / timeout | Snackbar "can't reach backend — check Tailscale". |
| Other 4xx/5xx | Snackbar with the backend's `detail` string verbatim, prefixed with the status code. |

Dio interceptor handles classification; UI consumes a typed `ApiError` model. No raw exception strings hit the user.

---

## 10. Tests

Widget tests (`flutter test`) for every screen — at minimum:
- Renders the expected primary widget when in loading / success / empty / error state.
- Tapping the primary action invokes the right provider method (mocked via `mocktail`).
- Polling providers tick at the right interval (use `fake_async` to control time).

Unit tests for:
- API client: every endpoint's request/response round-trip via `DioAdapter` (a `dio` test adapter).
- Model serialization: `fromJson`/`toJson` round-trips for every freezed model.
- Settings provider: round-trip write/read via the test backend of `flutter_secure_storage`.

Out-of-scope for v1: golden tests, integration tests on a real device. Smoke against the live home-server is the manual G1 milestone.

---

## 11. Out of scope (v1 — explicit "no")

- Spotify SDK / OAuth on device.
- Push notifications / FCM.
- Background downloads.
- Biometric unlock.
- Light theme.
- iOS / Cupertino.
- Per-user accounts.
- Admin endpoints (`/api/v1/admin/*`) — CLI-only.
- Tablet layouts.
- Internationalisation.
- Analytics / crash reporting.

Anything in this list reopening requires a new `DECISIONLOG.md` entry and an updated ROADMAP milestone.

---

## 12. Definition of done (v1)

1. APK builds via `flutter build apk --release` and installs on the Pixel 7 over `adb install`.
2. App launches, Settings screen accepts URL + token, "Test connection" returns ok.
3. Search finds a Spotify track and shows results with thumbnails.
4. Tapping a result POSTs `/download` and the job appears in the Queue with state `queued` → `running` → `done`.
5. The downloaded file appears in Navidrome within ~1 minute (Navidrome's scan interval).
6. Re-tapping the same result shows `deduped=true` UX (e.g. "already downloaded" toast).
7. Revoking the token (via the backend CLI) and re-launching the app → 401 → redirect to Settings.

These 7 steps are the G1 smoke script.
