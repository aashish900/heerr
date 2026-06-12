# ROADMAP_PLAYLISTS.md — heerr Android playlist-mutations feature

Track progress through the post-offline playlist-mutations feature. Same cadence as `ROADMAP.md` / `ROADMAP_STREAMER.md` / `ROADMAP_OFFLINE.md`: each milestone = one git commit with the test gate green where applicable. Tick the box when committed.

This roadmap continues the alphabet from `ROADMAP_OFFLINE.md`: A1–G1 covered the ingestion client, H1–K2 covered the streaming client, L1–L6 covered offline downloads. **M1–M5 cover playlist mutations** — the user can create, rename, delete, add-to, remove-from, and reorder playlists directly from the app, against the Subsonic API exposed by Navidrome.

**Status (2026-06-12):** planning. No code yet. Locked decisions below are proposed defaults — confirm before starting M1.

---

## How a future Claude session picks this up (stateless bootstrap)

Read **in order** before touching code:

1. `/CLAUDE.md` (project-wide rules)
2. `android/CLAUDE.md` (Android-specific rules — `flutter_secure_storage`, no Cupertino, no iOS, polling-not-WebSocket, dio interceptor is the single source of truth for auth)
3. `android/docs/CONTEXT.md` (env, target device, what the app is and is NOT)
4. `android/docs/DECISIONLOG.md` (every ADR — newest at bottom; new playlist-mutations ADR is appended at M5)
5. `android/docs/CHANGELOG.md` (per-task history)
6. **This file** for the playlist-mutations build sequence.

Reference docs:
- `android/docs/PLAN.md` — frozen v1 ingestion contract (unchanged by this work).
- `android/docs/ROADMAP_STREAMER.md` — H1–K2 closed; provides the architectural backdrop for everything Subsonic-related.
- `android/docs/ROADMAP_OFFLINE.md` — L1–L6; the Subsonic-against-Navidrome read path and library-cache layer.
- `backend/docs/PLAN.md` — backend contract (unchanged by this work).

The user has DevOps / Python / SQL / Docker fluency and **zero Flutter background** — hand-hold paths and commands; use backend analogies when explaining concepts.

---

## User decisions (proposed defaults — confirm before M1)

If the user disagrees with any of these, swap in the chosen value and append a DECISIONLOG entry capturing the swap. If implementation tempts a deviation later, append a DECISIONLOG entry first.

- **Scope:** full CRUD — create, rename, delete, add songs, remove songs, reorder — to be useful in practice. The milestone gates are designed so we can stop at M2 (bare create + rename + delete), M3 (add-and-be-useful), or M4 (complete) without rework.
- **Add-to-playlist entry points:** (a) song row long-press → context menu → "Add to playlist…", and (b) album-detail AppBar overflow → "Add album to playlist…" (adds all songs in the album). Playlist-detail "Add to playlist" not exposed (user is already in one). Now Playing → "Add current to playlist" deferred to a polish pass post-M4.
- **Reorder mechanics:** Subsonic's `updatePlaylist` exposes only `songIdToAdd` (append) and `songIndexToRemove` (delete-at-index) — no native reorder. The reorder implementation does the math client-side and issues a single `updatePlaylist` call per save with the diff (one batch of removes + one batch of adds in the new order at the tail). Trade-off captured in M4.
- **Offline behavior:** mutations require online connectivity. **No offline mutation queue in v1** — failures surface via existing `reactToApiError` snackbars ("cannot reach backend — check tailscale"). The library cache (L5) is invalidated on every successful mutation so the next online read reflects the change.
- **Cover art:** not configurable from the app in v1. Subsonic's `createPlaylist` / `updatePlaylist` don't accept cover-art uploads; Navidrome auto-derives cover art from the first track. Documented out-of-scope below.
- **Public / private toggle:** exposed in v1 via the rename dialog ("Make playlist public" checkbox). Default matches Navidrome's default (private). Trivial to expose; refusing to expose it is more code than including it.
- **Owner / shared playlists:** read-only. The mutation UI is hidden for playlists where `Playlist.owner != settings.navidromeUsername` (you can only edit playlists you own).

---

## Architecture (proposed)

- **New module** at `android/app/lib/providers/library/playlist_mutations.dart` — a single `@Riverpod(keepAlive: true) class PlaylistMutations extends _$PlaylistMutations` notifier exposing the six mutation methods. Keeps the surface flat — one Riverpod symbol the UI imports.
- **Endpoints** added to `android/app/lib/api/subsonic_endpoints.dart`: `createPlaylist`, `updatePlaylist`, `deletePlaylist`. Path constants only; query-param shape is owned by the mutations notifier.
- **Reuse the Subsonic dio client.** Mutations go through `subsonicDioClientProvider` so the auth interceptor handles `u/s/t/v/c/f`. No new `Dio` instance.
- **Cache invalidation is the contract.** Every mutation that resolves successfully invalidates `libraryPlaylistsProvider` and (when applicable) `libraryPlaylistProvider(playlistId)`. The L5 cache-aware wrapper re-fetches + repopulates the on-disk cache transparently.
- **No new DB, no new freezed model.** `Playlist` (`lib/models/subsonic/playlist.dart`) already covers all the metadata we need. `createPlaylist` returns the new Playlist; we hand it to the caller so the UI can route to the new detail screen without an extra round-trip.
- **No backend change.** Pure-Android slice, same as L1–L6.
- **No offline impact on the offline provider.** Marked playlists keep working unchanged. When a playlist's song list mutates, the next `OfflineSync` tick reconciles via the existing per-playlist enumeration — no special-case code in `offline_sync.dart`.

### Subsonic playlist mutation cheatsheet (1.16.1)

All paths under `/rest/`. Auth params (`u/s/t/v/c/f`) injected by `SubsonicAuthInterceptor`. Every response is wrapped in the standard `{"subsonic-response": {...}}` envelope and `subsonicCall` handles parsing + error mapping.

| Endpoint | Required params | Optional params | Returns |
|---|---|---|---|
| `createPlaylist.view` | `name` | `songId` (multi, may repeat) | New playlist (envelope key: `playlist`). Songs added in the order the `songId` params appear. |
| `updatePlaylist.view` | `playlistId` | `name`, `comment`, `public` (bool), `songIdToAdd` (multi), `songIndexToRemove` (multi) | Empty envelope on success. Renames / re-publishes / appends / deletes-at-index in one call. |
| `deletePlaylist.view` | `id` | — | Empty envelope on success. |

Notes:
- `songIndexToRemove` is **0-based** and refers to the index in the *current* playlist (before the call). Order matters — remove from the highest index first so earlier indices don't shift, or pass the full list and rely on Navidrome to dedupe (Navidrome's implementation does the right thing, but other Subsonic backends might not — assume strict-order semantics).
- `createPlaylist` accepting `songId` multi-params lets us create + populate in one call. M3's "Add to playlist → Create new" flow uses this.
- `dio` multi-param encoding: pass `List<String>` as the value (e.g. `{'songId': ['a', 'b']}`) — dio's default encoder produces `songId=a&songId=b`, which is what Subsonic expects. Verify in `dio_logger` output before declaring M1 done.

### Provider shape (M1)

```dart
@Riverpod(keepAlive: true)
class PlaylistMutations extends _$PlaylistMutations {
  @override
  void build() {}  // stateless notifier; build() returns void

  Future<Playlist> createPlaylist({
    required String name,
    List<String> songIds = const <String>[],
  });

  Future<void> renamePlaylist({
    required String playlistId,
    required String name,
    bool? makePublic,
  });

  Future<void> deletePlaylist(String playlistId);

  Future<void> addSongs({
    required String playlistId,
    required List<String> songIds,
  });

  Future<void> removeSongsAtIndices({
    required String playlistId,
    required List<int> indices,  // 0-based; method sorts desc before sending
  });

  Future<void> reorder({
    required String playlistId,
    required List<String> newSongIdOrder,
  });
}
```

Each method:
1. Builds the query-param map (using `List<String>` values for multi-params).
2. Calls `subsonicCall` through `subsonicDioClientProvider`.
3. On success → `ref.invalidate(libraryPlaylistsProvider)` + `ref.invalidate(libraryPlaylistProvider(playlistId))` as applicable.
4. On failure → rethrows the `ApiError` so callers can show their own snackbars via `reactToApiError`.

---

## Reused utilities (do not re-implement)

Before writing new code, confirm these still exist and have the signatures listed. If they've drifted, follow the staleness rule (`/CLAUDE.md` §2): update this roadmap in the same commit and reconcile.

| File | Function / class | Why we reuse |
|---|---|---|
| `android/app/lib/api/subsonic_client.dart` | `subsonicDioClientProvider` | All mutations go through the same auth-interceptor-equipped dio. |
| `android/app/lib/api/subsonic_client.dart` | `subsonicCall<T>` | Envelope parsing + Subsonic-error → `ApiError` mapping for every mutation. |
| `android/app/lib/api/subsonic_endpoints.dart` | `SubsonicEndpoints` constants | M1 appends the three mutation path constants here. |
| `android/app/lib/providers/library/library_playlists.dart` | `libraryPlaylistsProvider` | Invalidated after every mutation that affects the list. |
| `android/app/lib/providers/library/library_playlist.dart` | `libraryPlaylistProvider(id)` | Invalidated after every mutation that affects one playlist. |
| `android/app/lib/models/subsonic/playlist.dart` | `Playlist` model | `createPlaylist` returns one of these; UI consumes it directly. |
| `android/app/lib/widgets/error_snackbar.dart` | `showApiError`, `reactToApiError`, `kSnackBarDuration` | Every mutation snackbar reuses this. |
| `android/app/lib/widgets/library_result_tile.dart` | `LibraryResultTile` | Plumb in long-press → "Add to playlist…" at M3. |
| `android/app/lib/router.dart` | `Routes.libraryPlaylist(id)` | Post-create navigation hops to the new playlist's detail route. |
| `android/app/lib/offline/library_cache.dart` | `LibraryCache` | No direct touch — invalidation of the providers + the cache-aware wrapper handles cache freshness on next online read. |

---

## Conventions

- TDD by default (`/CLAUDE.md` §2). Widget + unit tests in the same commit as code.
- Out-of-TDD-scope: `pubspec.yaml` deps (none expected), `AndroidManifest.xml` (none expected), manual device smoke (its own gate at M5).
- Commit messages: Conventional Commits with the `flutter` scope (`feat(flutter): …`, `chore(flutter): …`).
- One milestone = one commit. Follow-up fixes within a milestone = separate commits under the same milestone.
- **Halt and confirm at each milestone boundary** (same cadence as A1–L6).
- Codegen: run `dart run build_runner build --delete-conflicting-outputs` at the end of any milestone that touches `@freezed` / `@riverpod` annotations.
- Lint + tests: `flutter analyze` clean and `flutter test` green BEFORE and AFTER each milestone.
- `pubspec.yaml` `version:` bumps per milestone (see each commit message). v1.1.0 was the offline ship; v1.2.0 ships playlists.

---

## Phase M — Playlist mutations

### [ ] M1. Endpoints + mutation notifier (no UI)

**Files (new):**
- `android/app/lib/providers/library/playlist_mutations.dart` — the `PlaylistMutations` notifier described in **Architecture → Provider shape**. Six methods + their riverpod-codegen part file. Each method invalidates the relevant read providers on success and rethrows `ApiError` on failure.

**Files (modify):**
- `android/app/lib/api/subsonic_endpoints.dart` — add three constants:
  ```dart
  static const String createPlaylist = '/rest/createPlaylist.view';
  static const String updatePlaylist = '/rest/updatePlaylist.view';
  static const String deletePlaylist = '/rest/deletePlaylist.view';
  ```
  with one-line dartdoc explaining the contract referenced above.
- `android/app/pubspec.yaml` — version bump `1.1.0+10 → 1.2.0-pre+11` (in-development band).
- `android/app/lib/providers/library/playlist_mutations.g.dart` — generated by build_runner.

**Deliverable:** the new module compiles. `PlaylistMutations.createPlaylist(name: 'test')` against a fake `Dio` adapter writes the expected query string (`name=test`), parses the returned `Playlist`, and triggers `libraryPlaylistsProvider` invalidation. **Nothing is wired into the UI yet** — this is plumbing only.

**Test gate (new tests):**
- `test/providers/library/playlist_mutations_test.dart` — for each of the six methods, one test per case:
  - happy path: stub `Dio` returns the expected envelope; method resolves to the expected return value; the right providers are invalidated (assert via `ref.listen` counting + `container.refresh`).
  - error path: stub returns a Subsonic `failed` envelope (e.g. code 70 "not found"); method throws the mapped `ApiError`; no providers are invalidated.
  - `createPlaylist` with `songIds` populated: query string contains `songId=a&songId=b` in order.
  - `removeSongsAtIndices` with `[1, 3, 5]`: sent as `songIndexToRemove` descending (`5, 3, 1`).
  - `reorder`: diff computed correctly — same set of songs in a different order produces a single `updatePlaylist` call with `songIndexToRemove` covering every index + `songIdToAdd` in the new order.

**Done when:** `dart run build_runner build --delete-conflicting-outputs` clean; `flutter analyze` clean; `flutter test` green; new test count is the prior baseline + the new M1 tests.

**Commit:** `feat(flutter): subsonic playlist mutations — endpoints + notifier`

---

### [ ] M2. Create + rename + delete UI

**Files (modify):**
- `android/app/lib/screens/library/library_screen.dart` — `_PlaylistsTab` gets a floating `FloatingActionButton.extended` (`Icons.add, label: 'New playlist'`). Tap → opens `_CreatePlaylistDialog`. On confirm: `await ref.read(playlistMutationsProvider.notifier).createPlaylist(name: '<name>')` → snackbar "Playlist created" → `context.push(Routes.libraryPlaylist(newPlaylist.id))`. On failure: `showApiError`. The empty-state subtitle ("Create a playlist on Navidrome to see it here.") is rewritten to "Tap **+ New playlist** to create one." with a styled-up affordance.
- `android/app/lib/screens/library/playlist_detail_screen.dart` — AppBar overflow `PopupMenuButton`:
  - "Rename…" → `_RenamePlaylistDialog` (pre-filled name + "Make public" checkbox seeded from current `Playlist.public`).
  - "Delete…" → confirmation `AlertDialog` ("Delete '<name>'? This cannot be undone."). On confirm: call `deletePlaylist`, then `context.pop()` back to Library, snackbar "Playlist deleted".
  - Both menu items are hidden when `playlist.owner != settings.navidromeUsername` (read-only ownership rule).

**Files (new):**
- `android/app/lib/widgets/playlist_dialogs.dart` — `_CreatePlaylistDialog` + `_RenamePlaylistDialog` (both `ConsumerStatefulWidget`). Single name field with non-empty validation; rename adds a "Make public" `CheckboxListTile`. Each returns the entered name via `Navigator.pop`. The screens own the actual mutation call so the dialogs stay pure.

**Test gate (new tests):**
- `test/widgets/playlist_dialogs_test.dart` — empty name disables the confirm button; submit returns the trimmed name; cancel returns null.
- `test/screens/library/library_screen_test.dart` extensions — FAB visible on Playlists tab; tapping FAB + entering a name calls `playlistMutationsProvider.notifier.createPlaylist` once via a stub.
- `test/screens/library/playlist_detail_screen_test.dart` extensions — overflow menu visible when `owner == username`; hidden otherwise. "Rename" submits → notifier called with new name + public flag. "Delete" → confirmation required, then notifier called.

**Deliverable:** user can create a playlist from the Library tab, rename / re-publish / delete it from the detail screen. Empty playlists are usable in subsequent milestones — songs come at M3. Failure modes surface via the existing snackbar copy.

**Done when:** analyze / test green. Manually verify on the Pixel against the home server: create a playlist, see it appear in the list, open it (empty state), rename, delete, watch the row disappear.

**Commit:** `feat(flutter): create / rename / delete playlists from the app`

---

### [ ] M3. Add-to-playlist UX

**Files (modify):**
- `android/app/lib/widgets/library_result_tile.dart` — add optional `VoidCallback? onLongPress`. When non-null, `InkWell.onLongPress` calls it. Existing tap behaviour unchanged.
- `android/app/lib/screens/library/album_detail_screen.dart` — song row tiles pass `onLongPress: () => _showAddToPlaylistSheet(context, ref, songIds: [song.id])`. AppBar overflow gains "Add album to playlist…" calling the same sheet with `songIds: album.song.map((s) => s.id).toList()`.
- `android/app/lib/screens/library/playlist_detail_screen.dart` — same row-level `onLongPress` (so you can copy a song from one playlist to another).
- `android/app/lib/screens/library/library_screen.dart` — Songs surfaced in the "In your library" search section (Subsonic search3 results) also gain the long-press handler.

**Files (new):**
- `android/app/lib/widgets/add_to_playlist_sheet.dart` — `showModalBottomSheet`-wrapped `ConsumerWidget`. Body:
  - First row: "**+ Create new playlist…**" → opens `_CreatePlaylistDialog` (reused from M2) with the songs pre-attached → calls `createPlaylist(name: ..., songIds: ...)` → pops the sheet → snackbar "Created '<name>' with N songs".
  - Below that: list of existing playlists from `libraryPlaylistsProvider`, filtered to those owned by the current user (`owner == settings.navidromeUsername`). Tap → calls `addSongs(playlistId, songIds)` → pops → snackbar "Added N songs to '<name>'".
  - Loading / error states match the existing Library tab.

**Test gate (new tests):**
- `test/widgets/library_result_tile_test.dart` extensions — `onLongPress` fires on long-press; null `onLongPress` does not crash on long-press.
- `test/widgets/add_to_playlist_sheet_test.dart` — renders the create-new row + existing playlists; selecting an existing playlist calls `addSongs` with the right args; "Create new" path calls `createPlaylist` with the right args; ownership filter excludes playlists owned by someone else.
- `test/screens/library/album_detail_screen_test.dart` extensions — long-pressing a song row opens the sheet; "Add album to playlist…" passes the full song-id list.

**Deliverable:** every song-bearing surface (album detail, playlist detail, library search) supports "Add to playlist" via long-press; album detail also supports "Add the whole album". Sheet shows existing playlists + an inline create-new option.

**Done when:** analyze / test green. Manual: long-press a song from an album → pick an existing playlist → see the row count update in the Playlists tab. Long-press → "Create new" → enter a name → playlist appears with that song.

**Commit:** `feat(flutter): add-to-playlist sheet — song row long-press + album-level entry`

---

### [ ] M4. Edit mode — remove songs + reorder

**Files (modify):**
- `android/app/lib/screens/library/playlist_detail_screen.dart` — add an "Edit" toggle action (top-right `IconButton(Icons.edit_outlined)` → `IconButton(Icons.check)` when active). Edit mode behaviour:
  - Song list switches to `ReorderableListView`. Each row gains a `ReorderableDragStartListener` + a leading delete handle (`Icons.delete_outline` → adds the index to a pending-remove set).
  - Pending removes are visually struck-through but kept in place (so other indices don't shift mid-edit).
  - Toggling Edit off (the check icon) computes the diff vs the original list and issues a single `removeSongsAtIndices` + `addSongs` combo via `reorder()`, then invalidates the playlist provider. The reorder call uses the diff strategy described in Architecture above (delete-all + re-add when any reorder is detected; otherwise just the remove batch).
  - Cancel via a `WillPopScope` confirmation if the user has pending edits ("Discard changes?").
- `android/app/lib/screens/library/playlist_detail_screen.dart` — the Edit action is hidden when `owner != settings.navidromeUsername` (consistent with M2 ownership rule).

**Test gate (new tests):**
- `test/screens/library/playlist_detail_screen_test.dart` extensions:
  - Edit mode hidden for non-owner; visible for owner.
  - Removing a row and committing calls `removeSongsAtIndices` with the right (descending) index list, and does **not** call `addSongs`/`reorder`.
  - Reordering two rows + committing calls `reorder` once with the new id order; does not separately call `removeSongsAtIndices`/`addSongs` (single batched call).
  - Cancel via back-button with pending edits shows the discard-confirmation dialog; "Discard" leaves the playlist unchanged.

**Deliverable:** in-app playlist editing is complete — songs can be added (M3), removed (M4), reordered (M4), the whole playlist renamed / deleted (M2).

**Done when:** analyze / test green. Manual: open a multi-song playlist, enter Edit mode, drag a row, mark another row for removal, tap Done, watch the playlist re-render in the new order with the removed row gone. Open Navidrome's web UI on a desktop, verify the canonical state matches.

**Commit:** `feat(flutter): playlist edit mode — remove + reorder`

---

### [ ] M5. End-to-end smoke + docs

**Files (new):**
- `android/docs/smoke_playlists.md` — mirror `smoke_offline.md` / `smoke_streamer.md` shape. Device, build version, per-step pass-with-detail, caveats.
- New ADR appended to `android/docs/DECISIONLOG.md`: "Playlist mutations — Subsonic `createPlaylist` / `updatePlaylist` / `deletePlaylist`; no offline mutation queue in v1; owner-only edit gate; reorder via delete-all-and-re-add."
- New entry in `android/docs/CHANGELOG.md` summarising M1–M5.

**Files (modify):**
- `android/app/pubspec.yaml` — version bump to `1.2.0+12`. First release-band build with playlist mutations shipping.
- This roadmap — tick the boxes for M1–M5 and append a "Roadmap closed" line at the bottom.

**Test gate:** manual on Pixel 7 against the live home server — six steps, all must pass:

1. **Create:** Library → Playlists → "+ New playlist" → name `Smoke test`. Confirmation snackbar. New empty playlist appears in the list; tapping it lands on the (empty) detail screen.
2. **Add via long-press:** Library → search "foo" → long-press a song row → "Add to playlist…" → pick `Smoke test`. Snackbar "Added 1 song to 'Smoke test'". Playlist detail now shows the song.
3. **Add via album:** Library → Albums → open any album → AppBar overflow → "Add album to playlist…" → pick `Smoke test`. Snackbar reflects the song count. Detail screen shows the new entries appended.
4. **Rename + publish:** open `Smoke test` → overflow → "Rename…" → change to `Smoke test (renamed)` + tick "Make public". Snackbar "Playlist updated". Library list shows the new name. Navidrome web UI confirms `public=true`.
5. **Edit:** enter Edit mode → drag the first song to last position → mark the second song for removal → tap Done. Detail re-renders in the new order; removed song is gone; Navidrome web UI confirms canonical state.
6. **Delete + offline:** delete the playlist via the overflow menu → confirmation → playlist disappears from the list. Then go offline (WiFi off) → try to create another playlist → expect "cannot reach backend — check tailscale" snackbar. Re-enable WiFi → retry succeeds.

**Done when:** all six steps pass. `flutter analyze` clean. `flutter test` green. CHANGELOG + DECISIONLOG + smoke_playlists.md committed. `pubspec.yaml` bumped to `1.2.0+12`.

**Commit:** `chore(flutter): playlists e2e smoke verified`

---

## Cross-cutting reminders

- `flutter analyze` green before declaring any milestone done — same gate as all prior phases.
- `flutter test` green before AND after each milestone.
- `dart run build_runner build --delete-conflicting-outputs` clean after every codegen-affecting milestone (M1 is the main one; M3 adds a small widget but no codegen).
- No `print` in production code — `debugPrint` only.
- **Staleness rule** (`/CLAUDE.md` §2): any contract / stack change → update `DECISIONLOG.md` + this roadmap in the same commit.
- **No new env vars or `.env`.** Mutations use the existing Navidrome creds from `flutter_secure_storage`.
- **No new manifest permissions.** Nothing here needs more than the existing internet permission.
- **No backend change.** This is a pure-Android feature; the FastAPI service stays untouched.
- **Owner-only edits.** Every mutating UI affordance is gated on `playlist.owner == settings.navidromeUsername`. Any new affordance added later must honour this — DRY via a small `bool canEdit(Playlist, SettingsValue)` helper if more than two callsites accumulate.

---

## Out of scope (do not implement in this roadmap)

- **Offline mutation queue.** Mutations require online connectivity. Failures surface via `reactToApiError`. Revisit only if the user reports the foreground-only window is insufficient in practice.
- **Cover-art upload.** Subsonic doesn't expose a clean cover-upload endpoint; Navidrome auto-derives from the first track. Out until Subsonic / Navidrome adds one.
- **Smart / dynamic playlists.** Subsonic has `getNowPlaying` and similar but no editable smart-playlist primitives; nothing to wire here.
- **Bulk move / merge playlists.** No Subsonic primitives; would require client-side compose against multiple endpoints. Out unless explicitly requested.
- **Now Playing → "Add current to playlist".** Polish; nice to have, not needed for the v1 mutation story. Can be added in 30 minutes after M3 if requested.
- **Shared / collaborative playlist editing.** Subsonic doesn't model this beyond the public/private toggle. Out.
- **Reorder via a single API call.** Subsonic's `updatePlaylist` only supports append + remove-at-index. We synthesise reorder client-side. If Subsonic adds a native reorder primitive, swap the implementation behind the `reorder()` method without changing callers.
- **Undo for delete.** Surface via the snackbar action slot only if the user requests it. Otherwise the confirmation dialog is the safety net.

---

## Roadmap complete when

1. All 5 milestone boxes checked (M1–M5).
2. Every test gate green at its milestone.
3. M5 smoke succeeds against the real home stack (6/6 steps).
4. `DECISIONLOG.md` entry written.
5. `CHANGELOG.md` entries exist for each milestone group.
6. `smoke_playlists.md` written.
7. `pubspec.yaml` at `1.2.0+12`.
8. `git log --oneline android/` reads as a clean M1→M5 progression under the `feat(flutter):` / `chore(flutter):` Conventional-Commits cadence.
