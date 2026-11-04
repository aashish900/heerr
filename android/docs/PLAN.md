# PLAN — Home "Shuffle all" button (full library)

Status: planned, nothing executed. Execute one step at a time; tick the box and commit after each step.

## Decisions (user-confirmed 2026-11-04)
- Scope: **true full library**, not a random-500 sample.
- Placement: button on the **right of the greeting row** on Home (Music tab), not under it.
- Client-only change; no backend change (backend-first rule not triggered).

## Facts (from code)
- No backend "all songs" endpoint. Library is read from Navidrome via Subsonic: `android/app/lib/services/subsonic_library_service.dart`.
- `getRandomSongs` (`subsonic_library_service.dart:182`) caps at 500 -> not enough.
- `search3` (`subsonic_library_service.dart:132`) takes only `query`; no `songCount`/`songOffset`. `findLibraryMatch` (line 149) shows how to pass `songCount`.
- Home Music body: `android/app/lib/screens/home/home_screen.dart:205-228`; `GreetingBlock` at line 212 (class in `widgets/branded_header.dart:135`, padding `fromLTRB(16,16,16,8)`).
- Player: `HeerrAudioHandler.playAll` (`player/heerr_audio_handler.dart:203`, guarded by `_isLoadingSource`), `setShuffleMode` (line 301).
- Helpers in `player/playback_actions.dart`: `playAllSongsFromSubsonic` (207), `addSongsToQueue` (~160), `_toMediaItem` (69), `_resolveCreds` (39).
- Existing shuffle icon: `assets/icons/shuffle.svg`.
- Version now 5.3.7 (backend + android share it).

## Assumption (unverified — gated by S0)
Navidrome `search3` with `query=""` returns all songs and honours `songCount`/`songOffset` paging.

## Steps

### [x] S0. Spike: verify Navidrome paging  (no code)
- curl `search3.view?query=&songCount=500&songOffset=0` and `songOffset=500` with real creds.
- Pass: distinct pages; summed count ≈ library size.
- Fail: switch to album fan-out (`getAlbumList` + per-album `getAlbum`); record in DECISIONLOG; amend S1.
- Output: result noted in this file under "Spike result".

### [x] S1. `getAllSongs` paging in the library service
- File: `android/app/lib/services/subsonic_library_service.dart`.
- Add `Future<List<Song>> getAllSongs({void Function(List<Song> page)? onPage})`: loop `search3` with `query=''`, `songCount=500`, `artistCount=0`, `albumCount=0`, increasing `songOffset`; stop on a short page. Reuse `subsonicCall`.
- Test: mock Dio, 2 full pages + 1 short -> concatenated, stops; empty library -> `[]`.
- Commit: `feat(flutter): SH1 — getAllSongs paged search3`

### [x] S2. Shuffle-all play action
- File: `android/app/lib/player/playback_actions.dart`.
- Add `shuffleAllSongsFromSubsonic(ref, context)`:
  - First page -> shuffle in Dart -> `playAllSongsFromSubsonic` (reuses creds, `_toMediaItem`, empty-list snackbar).
  - Remaining pages in background -> shuffle each -> append via `addSongsToQueue` path, in chunks (avoid ANR; respect `_isLoadingSource`).
  - Do NOT enable just_audio shuffle mode (reorders after `setAudioSources`, pins current index).
  - Guard against re-entry (in-flight flag); abort appends if the user starts other playback.
- DEVIATION (done): fetch ALL pages first, shuffle once, then play 50 / append 200-chunks (shuffling per page would bias to the first 500 songs). Core is `playShuffledInChunks` (pure, tested); re-entry guard + queue-head check (`shouldContinue`) live in the action.
- Test: first chunk played, rest appended in order, no dupes, early stop, empty/small lists (`test/player/shuffle_all_queue_test.dart`). Action itself (WidgetRef) not unit-tested; covered by S3 widget test stub + S5 smoke.
- Commit: `feat(flutter): SH2 — shuffle-all play action`

### S3. Home button
- File: `android/app/lib/screens/home/home_screen.dart` (~line 212).
- Wrap `GreetingBlock` in `Row(Expanded(GreetingBlock), shuffle button)`; `shuffle.svg` icon; key `home-shuffle-all-button`; Music tab only; spinner/disabled while loading.
- Check vertical alignment against greeting padding.
- Test: `android/app/test/screens/home/home_screen_test.dart` — button present, tap calls action (mocktail stub; `audioHandlerProvider` stays un-overridden per existing pattern).
- Commit: `feat(flutter): SH3 — Home shuffle-all button`

### S4. Offline behaviour
- No network -> fall back to `downloadedSongsProvider` songs (shuffled) via `playAllSongsFromSubsonic`; if none, snackbar "Nothing to play."
- Test: offline path uses downloaded songs.
- Commit: `feat(flutter): SH4 — shuffle-all offline fallback`

### S5. On-device smoke
- Tap -> playback starts within ~2s on full library; queue grows to library size; no ANR; next/prev OK; re-tap doesn't double-load; airplane mode per S4.
- Note large-library ceiling (10k+ songs) as a `ponytail:` comment where relevant.

### S6. Docs
- `android/docs/ROADMAP.md`: new `## Phase SH` before `## Cross-cutting reminders` (line ~972) with milestone SH1 (Files / Deliverable / Test gate / Smoke / Commit); update Status line and "Roadmap complete when" list (~line 1006).
- `android/docs/DECISIONLOG.md`: search3 paging vs random-500 vs album fan-out; Dart-side shuffle.
- `android/docs/CHANGELOG.md`: per-task entry.
- `android/docs/CONTEXT.md`: only if standing facts change.

### S7. Version bump 5.3.7 -> 5.4.0 (one commit, all five files)
- `backend/pyproject.toml`, `backend/app/main.py`, `android/app/pubspec.yaml`, `backend/docs/ROADMAP.md`, `android/docs/ROADMAP.md`.

### S8. Housekeeping
- `graphify update .`; `cd android/app && flutter analyze && flutter test`.

## Risks
- Empty-query `search3` is Navidrome-specific (S0 gates everything).
- Memory/time on very large libraries -> chunked append.
- Rapid re-taps / competing playback -> in-flight guard.

## Spike result
S0 PASSED (2026-11-04, run on server, localhost:4533): `search3` query='' songCount=500:
- offset=0 -> 500 songs, first id 3XPgtNdEC9vuEHZpjtWbcJ
- offset=500 -> 500 songs, first id TybA17jxr12Psc6miV8YVk
- offset=1000 -> 16 songs (short page = end) => library = 1016 songs.
Assumption confirmed: empty-query search3 pages the whole library. Album fan-out not needed.
