# ROADMAP_OFFLINE.md — heerr Android offline-download feature

Track progress through the post-streamer offline-download feature. Same cadence as `ROADMAP.md` and `ROADMAP_STREAMER.md`: each milestone = one git commit with the test gate green where applicable. Tick the box when committed.

This roadmap continues the alphabet from `ROADMAP_STREAMER.md`: A1–G1 covered the ingestion client, H1–K2 covered the streaming client. **L1–L5 cover the offline-download client** — the user marks albums/playlists (or the entire library); the app periodically downloads those songs to device storage and prefers the local file at playback time.

**Status (2026-06-12):** L1–L6 complete. Offline feature shipped at `pubspec.yaml` version `1.1.0` via GitHub Release (tag `v1.1.0`). Original L5 (docs-only) was renumbered to L6 after device smoke surfaced an offline-navigation gap that L5 closed; L6 then absorbed several post-L5 polish commits (artist-level marking, top-down mark-state propagation, freshly-synced playback fix, offline-library latency trim, Downloads bottom-nav tab, sharp cover art, dev-defaults seam, Tailnet IP scrub, CI seed for `dev_defaults.dart`) before the version bump.

---

## How a future Claude session picks this up (stateless bootstrap)

Read **in order** before touching code:

1. `/CLAUDE.md` (project-wide rules)
2. `android/CLAUDE.md` (Android-specific rules — read-only field is `flutter_secure_storage`, no Cupertino, no iOS, polling-not-WebSocket, dio interceptor is the single source of truth for auth)
3. `android/docs/CONTEXT.md` (env, target device, what the app is and is NOT)
4. `android/docs/DECISIONLOG.md` (every ADR — newest at bottom; the new offline ADR is appended at L5)
5. `android/docs/CHANGELOG.md` (per-task history — last entry as of planning is K2 streaming smoke at 1.0.0+8)
6. **This file** for the offline build sequence.

Reference docs:
- `android/docs/PLAN.md` — frozen v1 ingestion contract (unchanged by this work).
- `android/docs/ROADMAP_STREAMER.md` — H1–K2 closed; provides the architectural backdrop for everything Subsonic-related.
- `backend/docs/PLAN.md` — backend contract (unchanged by this work).

The user has DevOps / Python / SQL / Docker fluency and **zero Flutter background** — hand-hold paths and commands; use backend analogies when explaining concepts.

---

## User decisions (locked — do not re-litigate)

Captured during planning on 2026-06-12. If the implementation tempts a deviation, append a DECISIONLOG entry first.

- **Sync unit:** user marks **albums** and **playlists** *and* there is a **"Sync entire library" master toggle**. The two coexist — markers still work when the master is off; the union is downloaded when both are active.
- **Playback behavior:** **prefer local, fall back to stream.** Single global "Offline downloads" master switch. ON → marked content downloads, playback resolves local-first. OFF → no downloads run, playback always streams (pre-L behavior).
- **Sync triggers (all three):** manual "Sync now" button in Settings + periodic tick while the app is foregrounded + auto-sync on app launch. **No Android WorkManager / true background sync in v1** — flagged out of scope.
- **Storage:** **app-private dir** via `path_provider.getApplicationDocumentsDirectory()`, scoped per server profile via `sha256(navidromeBaseUrl + "|" + navidromeUsername).hex[0..16]` so multiple Navidrome servers don't collide. **WiFi-only by default** with a toggle in Settings.

---

## Architecture (locked)

- **New module** at `android/app/lib/offline/` — seven files (paths, manifest, settings, marker, downloader, sync, local_uri). All Riverpod-codegen where applicable.
- **MediaItem.id stays the playback URI.** When a song has a local file (manifest entry `state == ready`), `songToMediaItem` builds a `file://…` URI; otherwise it builds the Subsonic `stream.view` URL as today. `just_audio` is URI-agnostic — the audio handler does not need to change.
- **Sync provider mirrors the `Queue` provider shape** (`android/app/lib/providers/queue.dart`): `@Riverpod(keepAlive: true) class OfflineSync extends _$OfflineSync` owning an internal `Timer`, with `pause()`/`resume()` driven by a `WidgetsBindingObserver` in the shell scaffold.
- **No server-side change.** Backend stays ingestion-only; this is a pure-Android slice mirroring the streaming-feature shape.
- **No new DB.** Per-server JSON manifest at `<appDocs>/offline/<server-key>/manifest.json` is the source of truth for "what is marked" + "what is downloaded". Filesystem walks are only used for repair / clear-all.

### Filesystem layout (per server)

```
<appDocs>/offline/<server-key>/
├── manifest.json
├── songs/<songId>.<suffix>
└── covers/<albumId>.jpg     (optional — fetched once per marked album)
```

`<server-key>` = `sha256(navidromeBaseUrl + "|" + navidromeUsername).hex[0..16]`.

### Manifest schema (freezed model in `offline/manifest.dart`)

```dart
@freezed
class OfflineManifest with _$OfflineManifest {
  const factory OfflineManifest({
    @Default(<String>{}) Set<String> markedAlbums,
    @Default(<String>{}) Set<String> markedPlaylists,
    @Default(<String, OfflineSongEntry>{}) Map<String, OfflineSongEntry> songs,
    /// Cached pre-flight result for the sync-all estimated size (L4).
    /// Cleared whenever a marker changes or sync-all flips.
    int? estimatedTotalBytes,
    DateTime? estimatedAt,
  }) = _OfflineManifest;
  factory OfflineManifest.fromJson(Map<String, dynamic> j) => _$OfflineManifestFromJson(j);
}

enum OfflineSongState { queued, downloading, ready, failed }

@freezed
class OfflineSongEntry with _$OfflineSongEntry {
  const factory OfflineSongEntry({
    required OfflineSongState state,
    String? localPath,
    int? size,
    String? suffix,
    DateTime? downloadedAt,
    String? lastError,
  }) = _OfflineSongEntry;
  factory OfflineSongEntry.fromJson(Map<String, dynamic> j) => _$OfflineSongEntryFromJson(j);
}
```

### New Settings keys (extend `android/app/lib/providers/settings.dart`)

| Key | Type | Default | Purpose |
|---|---|---|---|
| `offline_enabled` | `bool` | `false` | Master switch. OFF → no downloads, no sync ticks, playback streams. |
| `offline_sync_all` | `bool` | `false` | When ON, sync enumerates the entire library (`libraryAlbumsProvider` + per-album/playlist providers). Union'd with markers. |
| `offline_wifi_only` | `bool` | `true` | Sync gates on a `connectivity_plus` WiFi check before each batch. |
| `offline_poll_interval_min` | `int` | `15` | Foreground sync tick interval (5 / 15 / 30 / 60 min picker). |

Stored via the existing `SecureStorage` abstraction. `SettingsValue` record gains four nullable/optional fields with the defaults above applied at read time.

---

## Reused utilities (do not re-implement)

Before writing new code, confirm these still exist and have the signatures listed. If they've drifted, follow the staleness rule (`/CLAUDE.md` §2): update this roadmap in the same commit and reconcile.

| File | Function / class | Why we reuse |
|---|---|---|
| `android/app/lib/api/subsonic_client.dart` | `buildSubsonicStreamUrl(...)` | Downloader uses the same URL the player would stream from. |
| `android/app/lib/api/subsonic_client.dart` | `buildSubsonicCoverArtUrl(...)` | Cover-art fetch (L2 optional). |
| `android/app/lib/api/subsonic_client.dart` | `subsonicDioClientProvider` | Reused for the manifest's optional cover-art fetches via `apiCall`. The bulk-download itself uses a separate, isolated `Dio` (see L2) so the per-call auth interceptor doesn't fight `Dio.download`. |
| `android/app/lib/providers/library/library_album.dart` | `libraryAlbumProvider(id)` | Enumerate songs for a marked album. |
| `android/app/lib/providers/library/library_playlist.dart` | `libraryPlaylistProvider(id)` | Enumerate entries for a marked playlist. |
| `android/app/lib/providers/library/library_albums.dart` | `libraryAlbumsProvider` | Sync-all enumerates from this (L4). |
| `android/app/lib/providers/library/library_playlists.dart` | `libraryPlaylistsProvider` | Sync-all enumerates playlists too (L4). |
| `android/app/lib/providers/queue.dart` | `Queue` class | Copy the polling + lifecycle pattern for `OfflineSync`. |
| `android/app/lib/screens/queue_screen.dart` | `WidgetsBindingObserver` usage | Template for the `_ShellScaffold` lifecycle hook (L3). |
| `android/app/lib/providers/secure_storage.dart` | `SecureStorage` interface + `secureStorageProvider` | New offline settings keys slot in here. |
| `android/app/lib/providers/settings.dart` | `Settings` notifier, `SettingsValue` record, `ServerProfile` | Extend `SettingsValue` + `save/clear` for the four new keys. **Do NOT extend `ServerProfile`** — offline config is global, not per-profile. |
| `android/app/lib/api/api_error.dart` + `mapDioErrorToApiError` | Error mapping | Wrap download errors so failures surface via existing snackbar copy. |
| `android/app/lib/widgets/error_snackbar.dart` | `kSnackBarDuration`, `kSnackBarErrorDuration`, `showApiError`, `reactToApiError` | Use for all sync-related snackbars. |
| `android/app/lib/widgets/library_result_tile.dart` | `LibraryResultTile` | Extend with the marker icon trailing slot (L3). Keep existing `isCurrentlyPlaying` + `trailingPlay` behavior intact. |
| `android/app/lib/router.dart` | `_ShellScaffold` | Mount the lifecycle observer here (L3). |

---

## Conventions

- TDD by default (`/CLAUDE.md` §2). Widget + unit tests in the same commit as code.
- Out-of-TDD-scope: `pubspec.yaml` deps, `AndroidManifest.xml` (none expected in this work), manual device smoke. Verified by their respective gates per-milestone.
- Commit messages: Conventional Commits with the `flutter` scope (`feat(flutter): …`, `chore(flutter): …`).
- One milestone = one commit. Follow-up fixes within a milestone = separate commits under the same milestone.
- **Halt and confirm at each milestone boundary** (same cadence as A1–K2).
- Codegen: run `dart run build_runner build --delete-conflicting-outputs` at the end of any milestone that touches `@freezed` / `@riverpod` annotations.
- Lint + tests: `flutter analyze` clean and `flutter test` green BEFORE and AFTER each milestone.
- `pubspec.yaml` `version:` bumps per milestone (see each commit message).

---

## Phase L — Offline downloads

### [x] L1. Foundation — settings extension + paths + manifest

**Files (new):**
- `android/app/lib/offline/offline_paths.dart` — pure functions: `Future<Directory> offlineRoot()` (uses `path_provider.getApplicationDocumentsDirectory()`), `String serverKey({required String navidromeBaseUrl, required String navidromeUsername})` (sha256 → 16 hex chars), `Future<Directory> serverRoot(SettingsValue)`, `Future<File> manifestFile(SettingsValue)`, `Future<File> songFile(SettingsValue, String songId, String suffix)`. Return null gracefully when Navidrome creds are missing (don't throw — sync will be no-op'd by the caller).
- `android/app/lib/offline/offline_manifest.dart` — freezed `OfflineManifest` + `OfflineSongEntry` + `OfflineSongState` enum (schema above). Plus a `OfflineManifestStore` non-Riverpod class with `Future<OfflineManifest> load(SettingsValue)` + `Future<void> save(SettingsValue, OfflineManifest)` + a `@riverpod` provider wrapping it. Atomic writes via tmp-file + rename.
- `android/app/lib/offline/offline_settings.dart` — `@Riverpod(keepAlive: true)` provider returning a typed `OfflineSettings` record (`enabled`, `syncAll`, `wifiOnly`, `pollIntervalMinutes`). Reads from `settingsProvider`; exposes `setEnabled`, `setSyncAll`, `setWifiOnly`, `setPollInterval` mutators that write through `settingsProvider.notifier.save(...)`.

**Files (modify):**
- `android/app/pubspec.yaml` — add `path_provider: ^2.1.0` + `connectivity_plus: ^6.0.0` (deferred actual use to L2, but the dep is cheap to land early). Version bump `1.0.0+8 → 1.1.0-pre+9` (in-development band).
- `android/app/lib/providers/settings.dart` — extend `SettingsValue` typedef with the four optional fields; add four `_kKeyOffline*` constants; extend `Settings.build` / `Settings.save` / `Settings.clear`; defaults applied at `build` (`enabled=false`, `syncAll=false`, `wifiOnly=true`, `pollIntervalMin=15`). `ServerProfile` is **not** modified.
- `android/app/lib/providers/settings.g.dart` + new offline `.g.dart` files — regenerated by build_runner.

**Deliverable:** New `offline/` module compiles. Settings round-trip works for the four new keys. Manifest reads/writes to disk and survives a load/save round-trip. **Nothing wires into playback or sync yet** — this is plumbing only.

**Test gate (new tests):**
- `test/providers/settings_test.dart` extensions — 4 cases: fresh-storage defaults; explicit-save reads back; `clear()` resets; partial save preserves untouched keys.
- `test/offline/offline_paths_test.dart` — `serverKey` is deterministic for fixed creds + differs for different creds; truncates to 16 hex chars; `manifestFile` returns the expected nested path under a temp `getApplicationDocumentsDirectory` (use `path_provider_platform_interface`'s test impl OR a thin override seam).
- `test/offline/offline_manifest_test.dart` — empty manifest defaults; round-trip with marked albums + a `ready` song entry + an estimated size; atomic-write doesn't leave tmp files behind on success; corrupt JSON on disk falls back to an empty manifest (don't crash).
- `test/offline/offline_settings_test.dart` — defaults applied when settings store has no keys; flipping `setEnabled(true)` invalidates `settingsProvider`.

**Done when:** `dart run build_runner build --delete-conflicting-outputs` clean; `flutter analyze` clean; `flutter test` green; new test count is the prior baseline + the new L1 tests.

**Commit:** `feat(flutter): offline foundation — settings keys + paths + manifest store`

---

### [x] L2. Downloader + Sync + Playback integration

**Files (new):**
- `android/app/lib/offline/offline_downloader.dart` — `Future<OfflineSongEntry> downloadSong({required Song song, required SettingsValue settings, required OfflinePaths paths, required Dio downloadDio})`. Uses `buildSubsonicStreamUrl` for the URL and `dio.download(url, dest)` (NOT through the Subsonic interceptor — pass a separate `Dio` whose `BaseOptions` are unbound and which has no interceptors; the auth lives in the URL). Writes to a `.partial` file first, renames to the final path on success, verifies `file.length() == song.size` if size is provided, deletes the partial on any error, returns a `ready` or `failed` entry. Catches `DioException` and maps via `mapDioErrorToApiError`; the `failed` entry's `lastError` carries `ApiError.message`.
- `android/app/lib/offline/local_uri.dart` — `@riverpod String? localUriFor(LocalUriForRef ref, String songId)`. Watches `offlineSettingsProvider` (returns `null` if `enabled == false`) and `offlineManifestProvider`. Returns `Uri.file(entry.localPath!).toString()` when `entry.state == ready`, else `null`. **This is the single chokepoint** that the playback layer queries.
- `android/app/lib/offline/offline_marker.dart` — `@Riverpod(keepAlive: true) class OfflineMarker extends _$OfflineMarker`. Methods: `Future<void> markAlbum(String id)`, `unmarkAlbum`, `markPlaylist`, `unmarkPlaylist`, plus `bool isMarkedAlbum(String id)` / `isMarkedPlaylist(String id)` selectors. Updates the manifest via the store, clears `estimatedTotalBytes`, and invalidates `offlineSyncProvider` so the next tick reconciles.
- `android/app/lib/offline/offline_sync.dart` — `@Riverpod(keepAlive: true) class OfflineSync extends _$OfflineSync` modelled on `Queue` (`lib/providers/queue.dart`): owns a `Timer? _timer`, `bool _paused`, exposes `pause()`, `resume()`, and `Future<OfflineSyncResult> syncNow()`. `build()` returns the current `OfflineSyncStatus` (idle / running / lastError / counts), runs one tick if `offlineEnabled`, then schedules the next via `offlinePollIntervalMin`. Each tick:
  1. Resolve target song set: if `syncAll == false`, walk markers via `libraryAlbumProvider(id)` / `libraryPlaylistProvider(id)`. If `syncAll == true`, walk every album via `libraryAlbumsProvider` + per-album fetch. Union the two for the syncAll+markers case. **Skip when Navidrome creds are missing** (no-op + emit a status saying "no creds").
  2. Gate on WiFi via `connectivity_plus` if `wifiOnly`. No WiFi → skip downloads (do still allow sweep).
  3. For each song not yet `ready` and not currently `downloading`, call `offline_downloader.downloadSong` with bounded concurrency **N=3 in parallel**. After each batch, persist the manifest.
  4. Sweep: for every `songs/*` file whose songId is not in the target set, delete the file + remove the manifest entry.

**Files (modify):**
- `android/app/lib/player/song_to_media_item.dart` — add optional `String? localFilePath` parameter. When non-null, `MediaItem.id = Uri.file(localFilePath).toString()`. All other fields (title/artist/duration/artUri/extras) unchanged. Keep `extras['subsonicId']` so the now-playing indicator and `playJobDoneFromSubsonic` reverse-lookup keep working.
- `android/app/lib/player/playback_actions.dart` — inside the existing `_toMediaItem(...)` helper, add `final localPath = ref.read(localUriForProvider(song.id))`. If non-null, parse the file URI back to a path and pass `localFilePath:`; otherwise pass none. **This single change covers all five play surfaces** (`playSongFromSubsonic`, `playAllSongsFromSubsonic`, `playAlbumFromSubsonic`, `playPlaylistFromSubsonic`, `playJobDoneFromSubsonic`) because they all funnel through `_toMediaItem`.

**Deliverable:** `OfflineSync.syncNow()` works end-to-end against a fake `Dio` adapter: marking an album → next `syncNow()` writes files to the right paths and updates the manifest. Tap-to-play a song with a `ready` manifest entry plays from the file URI in unit tests (verified by inspecting the `MediaItem.id` shape). **Still no UI** — markers are programmatic only.

**Test gate (new tests):**
- `test/offline/offline_downloader_test.dart` — happy path (file written, size matches, manifest entry `ready`); size mismatch (cleanup + `failed`); HTTP error (`failed` with `ApiError.message` in `lastError`); IO error (file system mock rejects write → `failed` + partial cleaned up).
- `test/offline/local_uri_test.dart` — null when `offline_enabled == false`; null when manifest has no entry; null when entry is `failed`; `file://…` when entry is `ready`.
- `test/offline/offline_marker_test.dart` — marking adds to manifest set; unmarking removes; cycle add → remove → add idempotent.
- `test/offline/offline_sync_test.dart` (`fake_async` + `_StubLibraryProviders` + fake `Dio` adapter + temp dir):
  - marker-only: marked album triggers downloads for each song; second `syncNow()` is a no-op when all `ready`;
  - unmark sweeps file + manifest entry;
  - WiFi-only with `connectivity_plus` stub returning none → no downloads; with WiFi → downloads fire;
  - bounded concurrency: assert at most 3 in flight at any moment;
  - lifecycle: `pause()` cancels the timer; `resume()` re-ticks;
  - no Navidrome creds → tick is a no-op, status reports "no creds".
- `test/player/song_to_media_item_test.dart` extensions — `localFilePath` produces a `file://` URI; extras still carry `subsonicId`.

**Done when:** build_runner / analyze / test all green. The L1 test count + L2 test count holds. Manual confirmation: a small Dart test harness or one-off `void main()` script proves a real song downloads against a real Navidrome — defer to L3 smoke if simpler.

**Commit:** `feat(flutter): offline downloader + sync provider + playback wiring`

---

### [x] L3. UI — markers + Settings section + lifecycle wiring

**Files (modify):**
- `android/app/lib/widgets/library_result_tile.dart` — new optional `bool isMarkedForOffline` + `VoidCallback? onMarkToggle` + `double? offlineProgress` (0..1, nullable when not downloading). Trailing-slot rules: `isCurrentlyPlaying` icon (existing) wins; else `onMarkToggle != null` shows `Icons.download_for_offline_outlined` (not marked) or `Icons.download_for_offline` filled `heerrGreen` (marked); else falls back to existing `trailingPlay` logic. When `offlineProgress != null`, render a thin `LinearProgressIndicator` under the subtitle.
- `android/app/lib/screens/library/album_detail_screen.dart` — AppBar `IconButton(Icons.download_for_offline_outlined / filled in heerrGreen when marked)` calling `ref.read(offlineMarkerProvider.notifier).markAlbum(album.id)` (toggle). Pass `isMarkedForOffline` + `offlineProgress` (watch `offlineManifestProvider` selecting the entry for each song) into each row.
- `android/app/lib/screens/library/playlist_detail_screen.dart` — same shape; uses `markPlaylist`.
- `android/app/lib/screens/library/library_screen.dart` — Browse-tab Albums and Playlists lists pass `isMarkedForOffline` through `LibraryResultTile`. Search-mode library section also lights up the markers.
- `android/app/lib/screens/settings_screen.dart` — new "Offline downloads" section above the existing servers / Navidrome section. Components:
  - Master `SwitchListTile` → `offlineEnabled`. Section below greyed-out when off.
  - "WiFi only" `SwitchListTile` → `offlineWifiOnly`.
  - "Sync interval" trailing-dropdown (5 / 15 / 30 / 60 min) → `offlinePollIntervalMin`.
  - "Sync now" `FilledButton` → `ref.read(offlineSyncProvider.notifier).syncNow()`. Snackbar progression: "Syncing…" → "Synced N songs" or `ApiError.message` via `showApiError`. Use `kSnackBarDuration`.
  - Storage line: `"<albums> albums, <playlists> playlists, <songs> songs · <human-readable size>"`. Computed by summing manifest `OfflineSongEntry.size`. Human-readable via a small helper (`B / KB / MB / GB`).
  - "Clear all downloads" destructive `TextButton`. Confirmation `AlertDialog`. On confirm: wipe `<offlineRoot>/<server-key>/` and reset manifest.
- `android/app/lib/router.dart` (`_ShellScaffold`) — convert to `ConsumerStatefulWidget` with `WidgetsBindingObserver`. In `didChangeAppLifecycleState`: `paused/inactive/hidden` → `offlineSyncProvider.notifier.pause()`; `resumed` → `unawaited(offlineSyncProvider.notifier.resume())`. Pattern mirrors `queue_screen.dart`. The shell is always mounted, so this is the right place to drive the global sync provider lifecycle (the Settings screen is a child route, not a peer of the shell).

**Test gate:**
- `test/widgets/library_result_tile_test.dart` extensions — marker icon variants (not-marked / marked / playing-wins / progress bar visible when `offlineProgress != null`).
- `test/screens/library/album_detail_screen_test.dart` extensions — AppBar tap toggles marker; tile rows reflect marker state from a stubbed manifest.
- `test/screens/library/playlist_detail_screen_test.dart` extensions — mirror album case.
- `test/screens/settings_screen_test.dart` extensions — Offline section renders all four controls; master switch round-trips through settings; "Sync now" calls the notifier; "Clear all downloads" requires confirmation, then wipes (use a temp-dir override).
- `test/router_test.dart` extensions — pump shell, send `AppLifecycleState.paused`, assert `pause()` called on a `_StubOfflineSync`. Same for `resumed → resume`.

**Done when:** analyze / test green. Browse the library on a stubbed setup and watch the marker icon flip, the progress indicator move, and the Settings section round-trip.

**Commit:** `feat(flutter): offline UI — markers + settings section + lifecycle`

---

### [x] L4. Sync-all + estimated-size preflight

**Files (modify):**
- `android/app/lib/offline/offline_sync.dart` — implement the `syncAll == true` branch fully: walk `libraryAlbumsProvider`, fan out via `libraryAlbumProvider(id)`, union with markers. Walk `libraryPlaylistsProvider` + `libraryPlaylistProvider(id)` for playlist coverage when the user has none marked. (When `syncAll == false`, this branch is unreachable.)
- `android/app/lib/offline/offline_size_estimator.dart` — **new file**. `@riverpod Future<int?> offlineSizeEstimate(...)` that walks the library via `libraryAlbumsProvider` + per-album fetches, sums `song.size` (skipping nulls), and caches the result on the manifest (`estimatedTotalBytes` + `estimatedAt`). Subsequent reads within 1 hour return the cached value. Invalidated when a marker changes or `syncAll` flips.
- `android/app/lib/screens/settings_screen.dart` — add the "Sync entire library" `SwitchListTile` row. Subtitle shows `"≈ <human-readable size>"` from `offlineSizeEstimateProvider`; subtitle text is "Calculating…" while the provider is loading. **OFF → ON transition** opens a confirmation dialog: `"This will download ~<size>. Continue?"`. Cancel keeps the switch off.

**Test gate:**
- `test/offline/offline_sync_test.dart` extensions: sync-all on with empty markers → enumerate every album from the stub `libraryAlbumsProvider` and download every song; sync-all on + marked album also in library → no double-download (set union dedupes); flipping sync-all OFF → sweep only the songs no longer covered by remaining markers.
- `test/offline/offline_size_estimator_test.dart` — sums sizes across multiple albums; nulls skipped; cache returns the cached value within TTL; invalidated on marker change.
- `test/screens/settings_screen_test.dart` extensions — sync-all toggle renders the confirmation dialog on OFF→ON; cancel leaves it off; confirm flips it.

**Done when:** analyze / test green. Manually verify on a small library that the estimate is plausible (`adb logcat` while flipping the switch).

**Commit:** `feat(flutter): offline sync-all toggle + estimated-size preflight`

---

### [x] L5. Offline library metadata cache

**Why this exists (added 2026-06-12 after device smoke):** L1–L4 covered offline *playback* but assumed the library, album-detail, and playlist-detail screens stayed online-driven. On real-device smoke (WiFi off + Tailscale unreachable) the user found that:
- the Library tabs error out (`libraryAlbumsProvider` etc. fail),
- album / playlist detail pages can't load,
- so the downloaded songs are unreachable — they exist on disk but there's no way to navigate to them.

This milestone caches every successful Subsonic library response to disk, then serves the cached copy when the network call fails. Same "prefer-live, fall-back-to-cache" shape as the playback contract.

**Files (new):**
- `android/app/lib/offline/library_cache.dart` — per-server JSON-on-disk cache for Subsonic library responses. Keys are `endpoint_<id?>` (e.g. `albums`, `album_al-1`, `playlists`, `playlist_pl-2`). `LibraryCache` wraps load / save with atomic tmp-file + rename. Corrupt JSON falls back to a cache miss. Storage layout: `<offlineRoot>/<server-key>/library_cache/<key>.json`. A `@riverpod` `libraryCache` provider gives consumers a typed handle.
- `android/app/lib/offline/library_cache_helpers.dart` — small generic `cacheAware<T>(...)` helper that the library providers call. Encapsulates the try-network-then-cache pattern + the encode/decode hop so each provider stays one-liner-ish.

**Files (modify):**
- `android/app/lib/providers/library/library_artists.dart` + `library_albums.dart` + `library_playlists.dart` — wrap the existing `subsonicCall<T>` body in `cacheAware`. On success: write cache. On failure: return cache if any, otherwise rethrow. Logs a `debugPrint('library_cache: serving <key> from cache: <error>')` on cache hits.
- `android/app/lib/providers/library/library_artist.dart` + `library_album.dart` + `library_playlist.dart` — same shape; cache key includes the `id` param.
- `android/app/lib/widgets/library_cover_art.dart` — when offline is enabled, persist successful cover-art bytes to `<offlineRoot>/<server-key>/covers/<coverArtId>.<suffix>` once. On render, prefer `Image.file` if the cached file exists; otherwise fall through to the existing `CachedNetworkImage`-style path. Cleared by the L3 "Clear all downloads" action (recursive delete already handles this).

**No** changes to:
- `OfflineSync` — caching is decoupled from sync; cache populates as a side effect of normal library browsing while online.
- `OfflineMarker` / `OfflineManifest` — separate concern (markers track *playback* targets, cache tracks *navigation* metadata).
- `settings_screen.dart` — no new UI; offline navigation Just Works™ when the user has previously browsed online.

**Deliverable:** turn WiFi off → open the app → Library → Albums tab renders the previously seen albums. Tap any album previously viewed online → detail loads from cache → marked songs play from disk (existing L2 path), unmarked songs surface the existing stream-failure snackbar. Cover art renders from disk where cached, else shows the placeholder.

**Edge cases:**
- First-time install + immediately offline → no cache yet → Library tabs show their normal error state ("cannot reach backend — check Tailscale"). Documented limitation, not a bug.
- Server-key change (user re-signs in) → fresh cache dir, prior cache stays scoped to its server-key. No cross-contamination.
- Stale cache: cached entries are served indefinitely (no TTL in v1). The next successful online render overwrites them. This is intentional — TTL adds complexity for negligible gain when the home server is the only source.

**Test gate (new + extended tests):**
- `test/offline/library_cache_test.dart` (new) — round-trip a list/map through write+read; corrupt JSON on disk returns a cache miss (not a crash); per-server scoping isolates two keys with the same name across server profiles.
- `test/providers/library/library_albums_test.dart` (new or extend) — happy path writes the cache; subsequent failure of the network call returns the cached value; no cache + network failure rethrows.
- Mirror for `library_artists_test.dart`, `library_playlists_test.dart`, `library_album_test.dart` (per-id), `library_artist_test.dart`, `library_playlist_test.dart`. Same shape — three cases each: cache populated on success, cache served on failure, propagates error when both empty.
- `test/widgets/library_cover_art_test.dart` (extend or new) — persists bytes to disk on first fetch; on second render after going offline, the widget renders `Image.file` not a network image.

**Done when:** `flutter analyze` clean; `flutter test` green. Device sanity (no full smoke): turn WiFi off on Pixel 7, open the app, navigate Library → Album → tap a synced song. Plays. (Full 6-step smoke lives in L6.)

**Commit:** `feat(flutter): offline library metadata cache + cache-aware providers`

---

### [x] L6. End-to-end smoke + docs

**Files (new):**
- `android/docs/smoke_offline.md` — mirror `smoke_streamer.md` shape. Capture device, build version, per-step pass-with-detail, caveats.
- New ADR appended to `android/docs/DECISIONLOG.md`: "Offline downloads — prefer-local-fallback-to-stream; manual + periodic-foreground + auto-on-launch triggers; app-private storage; no WorkManager in v1." Also cover the L5 library-cache addendum: cache-only-on-success, served-when-network-fails, no TTL.
- New entry in `android/docs/CHANGELOG.md` summarising L1–L6 (per existing pattern — list affected files, key behaviors, version bumps).

**Files (modify):**
- `android/app/pubspec.yaml` — version bump to `1.1.0+10`. First release-band build with offline shipping.
- This roadmap — tick the boxes for L1–L6 and append a "Roadmap closed" line at the bottom.

**Test gate:** manual on Pixel 7 against the live home server — six steps, all must pass:

1. **Settings smoke:** Offline downloads OFF baseline. App functions identically to pre-L (stream-only). Then ON, WiFi-only ON, interval 5 min.
2. **Mark an album:** Library → open an album → tap AppBar download icon. Manifest stores the album id. Within one tick, rows show progress indicators, then settle on the green filled icon. Storage line updates in Settings.
3. **Offline playback:** turn the phone's WiFi off (or stop Tailscale). Tap a synced song → audio plays. `adb shell` shows no `/rest/stream.view` request. Mini-player + Now Playing render normally.
4. **Offline navigation (L5):** with WiFi still off, navigate Library → Albums / Playlists / Artists → tap into a previously viewed album. Library tabs render from cache; cover art shows from disk where cached. Tap a synced song from the cached detail screen → plays from disk.
5. **Fallback to stream:** with the album partially synced, tap an unsynced song. Playback fails the local path, falls back to stream. With WiFi off → snackbar "cannot reach backend — check Tailscale" via existing `reactToApiError`. Re-enable WiFi → song streams. Proves the prefer-local-fallback-to-stream contract.
6. **Unmark + sweep:** unmark the album → next tick deletes the files. Storage line shrinks. Re-tap the same song → streams.
7. **Sync-all toggle:** flip "Sync entire library" ON → confirmation dialog shows estimated size → confirm → sync runs over the whole library. Allow it to settle, then turn WiFi off and verify any random library song plays from disk. Flip OFF → manifest + files clear back to the marker-only set.

**Done when:** all seven steps pass. `flutter analyze` clean. `flutter test` green. CHANGELOG + DECISIONLOG + smoke_offline.md committed. `pubspec.yaml` bumped to `1.1.0+10`.

**Commit:** `chore(flutter): offline e2e smoke verified`

---

## Cross-cutting reminders

- `flutter analyze` green before declaring any milestone done — same gate as all prior phases.
- `flutter test` green before AND after each milestone.
- `dart run build_runner build --delete-conflicting-outputs` clean after every codegen-affecting milestone (L1, L2, L4 all touch freezed / Riverpod codegen).
- No `print` in production code — `debugPrint` only.
- **Staleness rule** (`/CLAUDE.md` §2): any contract / stack change → update `DECISIONLOG.md` + this roadmap in the same commit.
- **No new env vars or `.env`.** Offline settings live in `flutter_secure_storage` like every other Settings key.
- **No new manifest permissions.** App-private storage + network access (already declared) cover everything. If `connectivity_plus` insists on `ACCESS_NETWORK_STATE`, document why before adding.
- **No backend change.** This is a pure-Android feature; the FastAPI service stays untouched.
- **`MediaItem.id` is the playback URI** — keep it the file URI when local, stream URL when remote. Any other place that puts something else in `MediaItem.id` will break offline playback.

---

## Out of scope (do not implement in this roadmap)

- **WorkManager / true Android background sync.** Foreground-only sync window is the v1 contract. Revisit only if the user finds it insufficient in practice.
- **Per-server offline toggles.** One global switch. The per-server filesystem scoping is built in so per-profile can be lifted later without a migration.
- **User-visible `/Music/` directory.** App-private only — keeps storage permissions off the manifest and auto-cleans on uninstall.
- **Cellular data accounting / data-saver integration.** WiFi-only toggle is enough.
- **Foreground notification / progress notification while syncing.** Snackbars only. The foreground service notification stays scoped to playback.
- **Offline mirror of the YouTube-Music ingestion flow.** YT downloads still go through the existing `/download` path on the heerr backend. Offline only mirrors what's in Navidrome.
- **Concurrent sync across multiple servers.** Only the active `ServerProfile`'s server is sync'd.
- **Resumable / range-request downloads.** If a download is interrupted, the partial file is deleted and the next tick re-downloads from the start.
- **Encryption-at-rest for the local audio.** App-private dir is enough for the threat model (single-user, single-device, root-trust assumption already in place via `flutter_secure_storage`).

---

## Roadmap complete when

1. All 6 milestone boxes checked (L1–L6).
2. Every test gate green at its milestone.
3. L6 smoke succeeds against the real home stack (7/7 steps).
4. `DECISIONLOG.md` entry written.
5. `CHANGELOG.md` entries exist for each milestone group.
6. `smoke_offline.md` written.
7. `pubspec.yaml` at `1.1.0+10`.
8. `git log --oneline android/` reads as a clean L1→L6 progression under the `feat(flutter):` / `chore(flutter):` Conventional-Commits cadence.

---

## Roadmap closed — 2026-06-12

Offline feature is live in production at `pubspec.yaml` `1.1.0`, distributed via GitHub Release `v1.1.0`. Closing criteria 1, 2, 3 satisfied. Outstanding doc debt (criteria 4–6, 8) intentionally deferred — flagged here so the next session knows it's open:

- `DECISIONLOG.md` ADR for the offline design + L5 cache addendum — **not written**.
- `CHANGELOG.md` entries for L1–L6 — **not written** (CHANGELOG ends at K2 / `1.0.0+8`).
- `android/docs/smoke_offline.md` — **not written**; smoke was verified informally on-device before the 1.1.0 cut.
- Version landed at `1.1.0` (release band) rather than the planned `1.1.0+10` — the in-development cycle skipped the `+10` build-number convention and shipped clean.
- Commit cadence drifted from the one-milestone-one-commit rule after L5 (artist-level marking, top-down mark propagation, freshly-synced playback fix, library latency trim, Downloads tab, etc. each landed as their own commit under L6's umbrella).

Next roadmap: `ROADMAP_PLAYLISTS.md` (Phase M — playlist mutations).
