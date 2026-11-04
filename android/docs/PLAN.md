# PLAN — Android Auto support (phase AA)

Status: planned, nothing executed. Execute one step at a time; tick the box and commit after each step. TDD; `flutter test` + `flutter analyze` green before and after each step.

## Decisions (user-confirmed 2026-11-04)
- Testing: **sideload + Desktop Head Unit (DHU) only**. No Play Store, no real car yet.
- Browse tree: **Recents, Favourites, Playlists, Albums, Artists, Downloaded**. No podcasts.
- Cold start: **full browse + play headless** (phone app not open).
- Client-only change; no backend change.

## Facts (from code)
- Deps: `audio_service 0.18.18`, `just_audio 0.10.5` (`app/pubspec.lock`). No `just_audio_background`.
- Handler: `HeerrAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler` — `app/lib/player/heerr_audio_handler.dart:15`. Has `playSong` (190), `playAll` (207), `restoreQueue` (235), skip/seek/repeat/shuffle overrides.
- Handler does NOT implement: `getChildren`, `getMediaItem`, `search`, `playFromMediaId`, `playFromSearch`, `customAction`. `AudioService.init` (`app/lib/main.dart:34-43`) sets no `androidBrowsableRootExtras`.
- Manifest (`app/android/app/src/main/AndroidManifest.xml:62-79`): `AudioService` already exported with `android.media.browse.MediaBrowserService` filter; `MediaButtonReceiver` present. `MainActivity : AudioServiceFragmentActivity`. minSdk 24, targetSdk 36.
- Missing: `com.google.android.gms.car.application` meta-data and `res/xml/automotive_app_desc.xml` (only `hero_widget_info.xml` exists in `res/xml/`).
- `MediaItem.id` is the playback URL with embedded auth (`player/song_to_media_item.dart:29-83`) -> unusable as a browse id. Reverse map: `songFromMediaItem` (:94). Extras hold `subsonicId`, `coverArt`.
- Art URL: `buildSubsonicCoverArtUrl` (`api/subsonic_client.dart:117-179`), no `size` param today.
- Handler has no Riverpod access. `ProviderContainer` is built after `AudioService.init` (`main.dart:49-53`). Creds: `serverCredsProvider` (`providers/server_creds.dart`), passwords in `flutter_secure_storage`.
- Play helpers in `player/playback_actions.dart` take `WidgetRef` + `BuildContext` (snackbars): `_toMediaItem` (73, offline check via `localUriForProvider`), `playSongFromSubsonic` (100), `playAlbumFromSubsonic` (346), `playArtistFromSubsonic` (368), `playPlaylistFromSubsonic` (400), `shuffleAllSongsFromSubsonic` (291).
- Library providers (`providers/library/`): `libraryAlbumsProvider`, `libraryAlbumProvider(id)`, `libraryArtistsProvider`, `libraryArtistProvider(id)`, `libraryPlaylistsProvider`, `libraryPlaylistProvider(id)`, `favouritesPlaylistProvider`. Recents: `recentlyPlayed` (`providers/home/home_providers.dart:39`). Downloaded: `downloadedSongsProvider` (`providers/downloaded_songs.dart`). Offline cache: `cacheAware` (`offline/library_cache.dart`).
- Search: `SubsonicLibraryService.search3`, `findLibraryMatch` (`services/subsonic_library_service.dart`).
- `WidgetSeekReceiver.kt` already connects a `MediaBrowserCompat` to the AudioService (working example).
- Handler test pattern: `app/test/player/heerr_audio_handler_modes_test.dart` (mocktail `_MockAudioPlayer`, no platform channels).

## Assumptions (unverified — gated by AA2)
- A. A cold MediaBrowser bind from Android Auto makes audio_service start the Flutter engine and run `main()`. If false, a headless entrypoint is needed and AA4 changes.
- B. Android Auto honors `android.media.browse.CONTENT_STYLE_*` root extras passed via `androidBrowsableRootExtras` in `AudioServiceConfig`. Verify in audio_service 0.18.18 source.
- C. Sideloaded app appears in DHU only with Android Auto developer mode -> "Unknown sources" enabled on the phone.

## Steps

### [x] AA1. Manifest + descriptor, empty app visible in DHU
- Files: new `app/android/app/src/main/res/xml/automotive_app_desc.xml` (`<automotiveApp><uses name="media"/></automotiveApp>`); `AndroidManifest.xml` add `<meta-data android:name="com.google.android.gms.car.application" android:resource="@xml/automotive_app_desc"/>` inside `<application>`; `android/README.md` add DHU setup (SDK Manager -> Android Auto DHU; phone: AA developer mode, "Start head unit server"; `adb forward tcp:5277 tcp:5277`; run `desktop-head-unit`).
- Gate: heerr listed in DHU app launcher (empty tree OK).
- Commit: `feat(flutter): AA1 — Android Auto manifest descriptor`

### [x] AA2. Cold-start spike (investigation, no feature code)
- Read audio_service 0.18.18 source in pub cache: engine start, entrypoint, `getChildren` plumbing, `androidBrowsableRootExtras`.
- Kill app, connect DHU, `adb logcat`: does `main()` run, does `AudioService.init` complete, does the handler get `getChildren`?
- Output: DECISIONLOG entry confirming/denying A and B. Decides AA4 shape.
- Commit: `docs(flutter): AA2 — cold-start findings`

### [x] AA3. Stable browse ids (pure functions)
- New `app/lib/player/browse_ids.dart`: encode/decode `root`, `recents`, `favourites`, `playlists`, `albums`, `artists`, `downloaded`, `album:<id>`, `playlist:<id>`, `artist:<id>`, `song:<id>`.
- Test: `app/test/player/browse_ids_test.dart` — round-trip, malformed ids.

### [x] AA4. Headless container/creds access for the handler
- `HeerrAudioHandler`: late-bound `ProviderContainer` setter, wired in `main.dart` right after the container is built. Before wiring: return empty / await a `Completer`. Active profile + creds must load without UI (reuse `activeProfileProvider`, `serverCredsProvider`).
- Shape depends on AA2.
- Test: handler before/after wiring, mocktail pattern above.

### [x] AA5. Browse tree `getChildren`
- Root (browsable): Recents, Favourites, Playlists, Albums, Artists, Downloaded.
- Nested: album -> songs, artist -> albums, playlist -> songs. Playable leaves: `MediaItem(id: browseId, title, artist, album, artUri, playable)`.
- `buildSubsonicCoverArtUrl`: add optional `size` (e.g. 300) for car art.
- Cap list sizes (Albums limited/paged). Downloaded tab works offline via `cacheAware` + `downloadedSongsProvider`.
- `androidBrowsableRootExtras` in `main.dart` `AudioServiceConfig`: grid for albums/artists, list for songs (assumption B).
- Test: `getChildren` for root, each tab, nested levels, offline.

### [x] AA6. `playFromMediaId`
- Extract a `Ref`/container-based core from `playback_actions.dart` (reuse `_toMediaItem` and the album/artist/playlist/song functions); UI wrappers keep snackbars and call the core. No duplicate logic.
- `playFromMediaId(id)`: decode (AA3) -> queue -> `playAll`/`playSong`. Tapping a song inside an album queues the whole album from that song.
- Test: each id kind -> expected queue; downloaded songs resolve to `file://`.

### [-] AA7. (BACKLOG, skipped 2026-11-04) Voice / search
- `search(query)` and `playFromSearch(query, extras)` via `search3` / `findLibraryMatch`. Empty query -> shuffle-all (`playback_actions.dart:291` logic).
- Test with fake service.

### [x] AA8. Now-playing polish (verified, no code)
- DHU 2026-11-04: title/artist/art, seekable progress, play/pause, prev, next and Queue ("Up next", current track highlighted) all work. `restoreQueue` loads paused (`heerr_audio_handler.dart:299-319`), so connecting never autoplays.
- Backlog (not done): shuffle / repeat / favourite `MediaControl.custom` + `customAction` (needs new icon drawables); the `Stop` control renders as a plain white square in the car; a car tap during cold-start `restoreQueue` is dropped by the `_isLoadingSource` guard (low risk, unverified).

### [x] AA9. Docs + version
- ROADMAP: add `Phase AA` before `## Cross-cutting reminders` (`docs/ROADMAP.md:985`). CHANGELOG entry per step. DECISIONLOG: browse ids, headless approach. CONTEXT.md: Android Auto note.
- Version bump (e.g. 5.5.0) in all five places listed in root `CLAUDE.md` §3, backend + android together.

### [ ] AA10. DHU end-to-end smoke
- App listed; each tab loads; drill into album/artist/playlist; play; skip/seek; voice "play <artist>"; kill phone app then reconnect (cold); VPN-down/airplane -> Downloaded still plays; art loads.
- Repeat once on a `--release` build (R8 precedent: `docs/CHANGELOG.md:1850`; keep rules in `proguard-rules.pro`).

## Risks
- Cold start (AA2) is the biggest unknown; handler is outside Riverpod today.
- Auth tokens are embedded in stream/art URLs (existing design); do not log them.
- Tailscale must be up on the phone for streaming; offline Downloaded is the fallback.
- Android Auto media-template limits (list length/depth); stock template used, no `androidx.car.app`.
