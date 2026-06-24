# PLAN.md — android

Detailed implementation plans for upcoming milestones. Each section maps to a
roadmap phase. Remove a section once its milestone is committed and its
CHANGELOG entry exists.

---

## Phase U — Download-to-playlist (optional post-download playlist assignment)

**Roadmap milestone:** U1  
**Goal:** When a user taps the download icon on a YouTube Music search result,
show a bottom sheet that lets them either download directly (current behaviour)
or download and automatically add the song to one of their Navidrome playlists
once the download job completes and Navidrome indexes the file.

The flow is entirely client-side; no new backend endpoint is required.

---

### Design overview

```
YTM result row
  └─ tap download icon
       └─ DownloadOptionsSheet (new bottom sheet)
            ├─ "Download"  → existing one-tap flow (unchanged)
            └─ [playlist name] row (per owned playlist)
                 └─ downloadAndAddToPlaylist() (new top-level async fn)
                      1. dispatch download  ──→ jobId + initial state
                      2. poll job until terminal (if not already done)
                      3. poll Navidrome search3 until song indexed
                      4. addSongs(playlistId, [songId])
                      5. snackbar at each stage
```

No persistent provider state is needed — the async flow lives as a top-level
function, mirroring the pattern already used by `playSongFromSubsonic` and
`playPreview`.

---

### New file 1: `android/app/lib/widgets/download_options_sheet.dart`

A `ConsumerWidget` shown via `showModalBottomSheet`. Purely presentational —
no async logic. Callbacks are owned by the caller.

**Public API:**

```dart
class DownloadOptionsSheet extends ConsumerWidget {
  /// Show the sheet. [onDownloadOnly] fires for the plain download row.
  /// [onDownloadToPlaylist] fires with (playlistId, playlistName) for
  /// playlist rows. Both callbacks are invoked AFTER the sheet is popped.
  static void show({
    required BuildContext context,
    required SearchResultItem item,
    required VoidCallback onDownloadOnly,
    required void Function(String playlistId, String playlistName) onDownloadToPlaylist,
  });
}
```

**Sheet body layout (top to bottom):**
1. Title: `item.title` (song name)
2. `ListTile` labelled "Download" — key `'download-options-download-only'`
3. `Divider()`
4. Section label: "Add to playlist after download"
5. `ref.watch(libraryPlaylistsProvider)` — filter to playlists whose `owner`
   equals `ref.watch(serverCredsProvider).navidromeUsername`:
   - Loading → `CircularProgressIndicator()`
   - Error → brief error text
   - Empty (no owned playlists) → italic "No playlists yet — create one in the
     Library tab."
   - Each playlist → `ListTile` key `'download-to-playlist-${p.id}'` with
     `p.name` as title

Each tap: `Navigator.of(context).pop()` first (dismiss sheet), then invoke the
callback. This mirrors `AddToPlaylistSheet`'s pattern.

**Imports needed:**
- `package:flutter/material.dart`
- `package:flutter_riverpod/flutter_riverpod.dart`
- `../models/search_result_item.dart`
- `../models/subsonic/playlist.dart`
- `../providers/library/library_playlists.dart`
- `../providers/server_creds.dart`

---

### New file 2: `android/app/lib/providers/download_to_playlist.dart`

A single top-level async function — no Riverpod provider or persistent state.

```dart
/// Dispatches a download for [item], waits for the job to complete,
/// waits for Navidrome to index the file, then adds it to [playlistId].
///
/// Shows progress snackbars at each stage. API errors surface via
/// snackbars; the caller does not need to handle them.
///
/// [jobPollInterval], [naviPollInterval], [maxJobPolls], [maxNaviPolls]
/// are exposed only for testing (@visibleForTesting).
Future<void> downloadAndAddToPlaylist({
  required WidgetRef ref,
  required BuildContext context,
  required SearchResultItem item,
  required String playlistId,
  required String playlistName,
  @visibleForTesting Duration jobPollInterval = const Duration(seconds: 2),
  @visibleForTesting Duration naviPollInterval = const Duration(seconds: 5),
  @visibleForTesting int maxJobPolls = 150,   // ~5 min
  @visibleForTesting int maxNaviPolls = 18,   // ~90 s
}) async { ... }
```

**Internal steps:**

**Step 1 — Dispatch:**
```dart
final DownloadResponse response = await ref
    .read(downloadDispatcherProvider.notifier)
    .dispatch(item.sourceUrl, sourceType: item.sourceType, displayName: item.title);
// on ApiError: showApiError(context, e, action: 'download'); return
```
Show snackbar: `"Downloading ${item.title} — will add to $playlistName when ready"`

**Step 2 — Poll job until terminal** (skip entirely if `response.state.isTerminal`):
```dart
for (int i = 0; i < maxJobPolls; i++) {
  await Future.delayed(jobPollInterval);
  final BackendService backend = await ref.read(backendServiceProvider.future);
  final JobView status = await backend.jobStatus(response.jobId);
  if (status.state == JobState.failed) {
    // snackbar: "Download failed: ${status.error ?? 'unknown error'}"
    return;
  }
  if (status.state.isTerminal) break;
  if (i == maxJobPolls - 1) {
    // snackbar: "Download is taking too long — add to playlist manually when done."
    return;
  }
}
```
`context.mounted` guard after every `await`.

**Step 3 — Poll Navidrome until indexed:**
```dart
final SubsonicLibraryService naviService =
    await ref.read(subsonicLibraryServiceProvider.future);
SubsonicSongMatch? match;
for (int i = 0; i < maxNaviPolls; i++) {
  await Future.delayed(naviPollInterval);
  match = await naviService.findLibraryMatch('${item.title} ${item.artist}');
  if (match != null) break;
  // ApiError is caught and ignored per iteration (transient — keep polling)
}
if (match == null) {
  // snackbar: "${item.title} downloaded but not indexed yet — add to $playlistName manually."
  return;
}
```

**Step 4 — Add to playlist:**
```dart
await ref.read(playlistMutationsProvider.notifier)
    .addSongs(playlistId: playlistId, songIds: [match.id]);
// snackbar: "Added ${item.title} to $playlistName"
// on ApiError: showApiError(context, e)
```

**Imports needed:**
- `package:flutter/foundation.dart` (for `@visibleForTesting`)
- `package:flutter/material.dart`
- `package:flutter_riverpod/flutter_riverpod.dart`
- `../api/api_error.dart`
- `../models/download_response.dart`
- `../models/enums.dart`
- `../models/job_view.dart`
- `../models/search_result_item.dart`
- `../providers/download.dart`
- `../providers/library/playlist_mutations.dart`
- `../services/backend_service.dart`
- `../services/subsonic_library_service.dart`
- `../widgets/error_snackbar.dart`

---

### Changed file: `android/app/lib/screens/library/library_screen.dart`

Add two imports (after existing imports block):

```dart
import '../../widgets/download_options_sheet.dart';
import '../../providers/download_to_playlist.dart';
```

---

### Changed file: `android/app/lib/screens/library/library_search_results.dart`

In `_YtmSection.build`, replace the `onDownload` inline closure on each
`ResultTile` with a call to `DownloadOptionsSheet.show`:

```dart
onDownload: () => DownloadOptionsSheet.show(
  context: context,
  item: item,
  onDownloadOnly: () async {
    // EXISTING logic: dispatch + "Queued: ${item.title}" snackbar
    try {
      await ref.read(downloadDispatcherProvider.notifier).dispatch(
        item.sourceUrl,
        sourceType: item.sourceType,
        displayName: item.title,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: kSnackBarDuration,
          content: Text('Queued: ${item.title}'),
        ),
      );
    } on ApiError catch (e) {
      if (!context.mounted) return;
      showApiError(context, e, action: 'download');
    }
  },
  onDownloadToPlaylist: (String playlistId, String playlistName) =>
      downloadAndAddToPlaylist(
        ref: ref,
        context: context,
        item: item,
        playlistId: playlistId,
        playlistName: playlistName,
      ),
),
```

No other changes to `library_search_results.dart`.

---

### Tests to write

#### `android/app/test/widgets/download_options_sheet_test.dart`

Widget tests for `DownloadOptionsSheet`. Use a helper `_openSheet(tester, ...)` that:
- Pumps a `ProviderScope` → `MaterialApp` → `Scaffold` → `Builder` → `ElevatedButton`
  whose `onPressed` calls `DownloadOptionsSheet.show(...)`
- Taps the button then calls `pumpAndSettle()` (or limited pumps for the
  loading state — use a `Completer` that never completes and skip `settle`
  to avoid a timeout)

Tests:
1. Shows `item.title` and the "Download" `ListTile` key.
2. Shows only playlists owned by `navidromeUsername`; hides others.
3. Shows "No playlists yet" when no owned playlists exist.
4. Tapping "Download" fires `onDownloadOnly` and closes the sheet.
5. Tapping a playlist row fires `onDownloadToPlaylist(id, name)` and closes
   the sheet.
6. Shows `CircularProgressIndicator` while playlists are loading.

**Test stubs needed:** none — override `libraryPlaylistsProvider` and
`activeProfileProvider` (via `activeProfileOverride()`) only.

#### `android/app/test/providers/download_to_playlist_test.dart`

Unit/widget tests for `downloadAndAddToPlaylist`. Pump a minimal widget that
calls the function via a button tap. Use `@visibleForTesting` parameters to
pass `Duration.zero` poll intervals and small poll counts so tests don't hang.

**Stub classes:**
```dart
class _StubDownloadDispatcher extends DownloadDispatcher { ... }
  // build() → <String>{},  dispatch() async → _response

class _StubBackendService extends BackendService { ... }
  // extends BackendService with super(Dio());  jobStatus() async → _status

class _StubSubsonicLibraryService extends SubsonicLibraryService { ... }
  // extends SubsonicLibraryService with super(Dio());  findLibraryMatch() async → _match

class _StubPlaylistMutations extends PlaylistMutations { ... }
  // build() → void;  addSongs() async → songIds.length; tracks call count + args
```

**Override syntax:**
- `downloadDispatcherProvider.overrideWith(() => _StubDownloadDispatcher(response))`
  — no-arg factory (Notifier pattern)
- `backendServiceProvider.overrideWith((_) => Future.value(_StubBackendService(...)))`
  — FutureProvider pattern
- `subsonicLibraryServiceProvider.overrideWith((_) => Future.value(_StubSubsonicLibraryService(...)))`
- `playlistMutationsProvider.overrideWith(() => _StubPlaylistMutations())`
  — no-arg factory (Notifier pattern)

**Tests:**
1. **Happy path** — `dispatchResponse.state == done` (skips job poll),
   `findLibraryMatch` returns a match → `addSongs` called with correct
   `playlistId` + `songId`, success snackbar visible.
2. **Job failed** — `dispatchResponse.state == queued`, `jobStatus` returns
   `failed` → error snackbar shown, `addSongs` NOT called.
3. **Navidrome timeout** — `dispatchResponse.state == done`, `findLibraryMatch`
   always returns `null`, `maxNaviPolls = 1` → warning snackbar shown,
   `addSongs` NOT called.

**Snackbar timing note:** `pumpAndSettle()` drives async operations to
completion and stops when the UI is stable (i.e., when the first snackbar's
show-animation is complete). The first snackbar ("Downloading...") is shown
early in the function. For test 3 the warning snackbar is the *second* in the
queue; after `pumpAndSettle()` advance fake time past the first snackbar's
display duration before asserting:

```dart
await tester.tap(find.text('go'));
await tester.pumpAndSettle();          // settles on first snackbar
await tester.pump(const Duration(seconds: 5));  // first snackbar dismisses
await tester.pumpAndSettle();          // second snackbar shows + settles
expect(find.textContaining('not indexed yet'), findsOneWidget);
```

Tests 1 and 2 have no snackbar-queue issue (only one snackbar is expected in
the visible slot at assertion time) and just need `pumpAndSettle()`.

---

### Verification

```bash
cd android/app
flutter test test/widgets/download_options_sheet_test.dart
flutter test test/providers/download_to_playlist_test.dart
flutter test          # full suite — no regressions
flutter analyze       # zero issues
```

Manual (on-device):
1. Search a YouTube Music result in the Library tab.
2. Tap the download icon → `DownloadOptionsSheet` appears.
3. Pick a playlist → sheet dismisses, "Downloading..." snackbar appears.
4. Wait for download to complete and Navidrome to index (~10–30 s depending on
   scan interval) → "Added [title] to [playlist]" snackbar appears.
5. Navigate to Library → Playlists → confirm song is in the playlist.
6. Also verify plain "Download" tap still works (no regression).

---

### Commit message

```
feat(flutter): U1 — download-to-playlist — optional playlist assignment on YTM download
```

---
