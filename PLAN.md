# PLAN — Vibe mixes ("Chill Mix", "Party Mix", …) (phase MX)

Status: **planned, nothing built.** Target release: **v5.8.0**.

> The previous plan in this file, recommendations v2 (phase RX), lives in git history at `e9882b9:PLAN.md`. RX is shipped (v5.7.0–v5.7.4) except **RX9**, the on-device smoke, which is still open and tracked in both ROADMAPs.

## 1. Goal

Recommendations also generate **playlists for moods and vibes**: personalised mixes like Spotify's Daily Mixes or YouTube Music's mood mixes. You can stream them, download single songs, and save a whole mix as a Navidrome playlist.

## 2. Decisions (user-confirmed 2026-11-07)

- A **fixed set of 8 vibes**, each personalised to your taste.
- **In-app mix screen:** stream all of it as previews and download single songs. Plus **"Save as playlist"**, which downloads every song and creates a Navidrome playlist.
- A **"Your Mixes" shelf on Home**, below For You.
- The vibe names are heerr's own; the user said not to reuse the example names.

## 3. Feasibility (verified live 2026-11-07, ytmusicapi 1.12.1, unauthenticated)

| Call | Result | Time |
|---|---|---|
| `get_mood_categories()` | **12 moods** (Chill, Commute, Diwali, Energize, Feel good, Focus, Gaming, Party, Romance, Sad, Sleep, Workout) and **38 genres** (incl. Hindi, Punjabi, Indian indie, Desi hip-hop, Tamil) | 0.96 s |
| `get_mood_playlists(Chill)` | **310** curated playlists, mixed languages ("Coffee Shop Blend", "Uncut Bollywood", "Retro Lounge: Tamil") | 0.40 s |
| `get_mood_playlists(Party)` | 145 playlists ("Bollywood Dance Essentials", "Punjabi Dance Essentials", …) | 0.31 s |
| `get_playlist(id, limit=100)` | 97–100 tracks with `videoId`, `title` and `artists` | ~0.5 s |

- **Feasible:** YouTube Music supplies the mood labels and curated track pools. heerr picks the playlists in each mood that best match your artists, then ranks their tracks.
- **Not feasible:** filtering *your own* recommendations by mood. YouTube Music has no per-track mood tags, Spotify's audio-features API is deprecated, and Last.fm tags would need an API key plus one call per track. So the design is **mood pool, personalised by taste**.
- **Found while checking:** downloads have **no concurrency limit** (`backend/app/services/workers.py`: each `/download` starts its own spotDL subprocess via `BackgroundTasks`). "Save as playlist" would start about 25 spotDL processes at once, so MX1 adds a throttle.

## 4. Assumptions (review before MX1)

1. The server's YouTube Music results are localised to its IP region (India, judging by the probe's Bollywood and Tamil playlists). That's good for a Desi flavour. These are inferences, not verified on the server; MX5 checks them.
2. Looking at the first **24** playlists of a mood is enough to find ones that overlap your artists. MX5 checks this, and the fallback is a non-personalised mix that says so.
3. spotDL takes roughly 20–40 s per song (a guess, not measured). At 2 at a time, saving a 25-song mix takes about **5–8 minutes**. MX5 measures it.
4. The backend runs a single uvicorn worker, so an in-process cache is fine.

## 5. Design

### 5.1 Vibes (fixed)

| id | Title | YTM "Moods & moments" title |
|---|---|---|
| `chill` | Chill Mix | Chill |
| `feel-good` | Feel Good Mix | Feel good |
| `party` | Party Mix | Party |
| `romance` | Romance Mix | Romance |
| `heartbreak` | Heartbreak Mix | Sad |
| `workout` | Workout Mix | Workout |
| `focus` | Focus Mix | Focus |
| `sleep` | Sleep Mix | Sleep |

### 5.2 Mix algorithm (`backend/app/services/recommenders/mixes.py`)

For each request `(vibe, seeds, variant, limit)`:

1. **Taste profile:** `artist (trimmed, lowercased) → weight`, built from the client seeds. Every seed carries an artist and a weight (starred-song artists 1.0, frequent-album artists 0.7, recent-album artists 0.4). The highest weight per artist wins.
2. **Mood lookup:** find the vibe's category in `get_mood_categories()["Moods & moments"]` by title. If it's missing, raise `MoodNotFound` (the API returns 503).
3. **Candidates:** the first `CANDIDATE_PLAYLISTS = 24` from `get_mood_playlists(params)`, in YTM order. Fetch each with `get_playlist(id, limit=100)` concurrently (semaphore 4). A failing playlist is logged and skipped.
4. **Playlist affinity:** the taste weight of tracks with any listed artist in the profile, divided by the playlist's track count.
5. **Pick:** sort playlists by affinity (descending; stable, so ties keep YTM order) and take the top `POOL = 8`. Choose `PICK = 4` of them by rotating with `variant` (the playlists at indices `(variant*PICK + i) % 8`).
   - `personalized = max affinity > 0`.
   - If every affinity is 0, use YTM's first 8 in the same way, with `personalized: false`.
6. **Track score:** for each chosen playlist `p` and each track at position `i`, add `(0.5 + affinity_p) / (1 + 0.02·i)`. Then add the track's best taste weight, once, if any of its artists is in the profile. Duplicates across playlists add up, so consensus wins.
7. **Shared re-rank:** run `rerank()` (`backend/app/services/recommenders/rerank.py`) with:
   - `excluded` = the user's non-failed jobs plus dismissed songs (the RX3 history query)
   - covers and alternate versions dropped (already built in)
   - `recently_shown = ∅`, so mixes don't rotate on their own
   - `per_artist = 3`
   - `limit` (≤ 50)
8. **Cache:** a 24-hour in-process TTL cache for categories, per-mood playlist lists, and per-playlist tracks. Expected cold time is about 4.5 s; warm, under 1 s.
   `# ponytail: per-process dict; Redis only if >1 worker or memory matters.`

### 5.3 API (`backend/app/api/v1/recommend.py`, `read` scope)

| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/api/v1/recommend/mixes` | n/a | `[{id, title}]`. Static, no network. |
| POST | `/api/v1/recommend/mixes/{id}` | `{seeds: [RecommendSeed], limit: 1–50 = 50, variant: ≥0 = 0}` | `{id, title, personalized, results: [RecommendResultItem]}`. 404 for an unknown id, 503 when the mood is missing upstream. |

Mixes don't write "shown" rows to `rec_feedback`. Dismissals still apply through `excluded`.

### 5.4 Download throttle (`backend/app/services/workers.py`)

- A module-level `asyncio.Semaphore`, sized by the `DOWNLOAD_CONCURRENCY` env var (default **2**), wraps the download step of `run_job` (spotDL and podcast episodes).
- A job transitions `queued → running` only **after** it acquires a slot, so the Queue screen stays truthful.
- It applies to every download, not just mixes.

### 5.5 Android

- **Models** (`android/app/lib/models/mix.dart`, freezed): `MixVibe {id, title}` and `MixResponse {id, title, personalized, results: List<RecommendedTrack>}`.
- **API** (`android/app/lib/services/backend_service.dart`): `mixVibes()` and `mix(id, {seeds, limit, variant})`.
- **Providers** (`android/app/lib/providers/mixes.dart`):
  - `mixVibesProvider`: keep-alive.
  - `MixNotifier`: a keep-alive family keyed by id. `build` sends **all** seeds from `seedCollectionProvider` (unsampled), then drops owned songs. `regenerate()` increments `variant`.
- **Shared owned-filter:** extract `Recommendations._hydrateLibraryMatches` into a top-level `hydrateLibraryMatches(ref, tracks)` in `android/app/lib/providers/recommendations.dart`, so For You and mixes both use it.
- **Playback:** add `playPreviews(ref, context, List<SearchResultItem> items, {int startIndex = 0})` to `android/app/lib/player/playback_actions.dart`. It maps items through `searchResultToMediaItem` and calls the existing `HeerrAudioHandler.playAll`. It's blocked during a jam, like `playPreview`.
- **Home shelf** (`android/app/lib/screens/home/your_mixes_section.dart`):
  - A "Your Mixes" header and a horizontal row of 8 square tiles (gradient cover, white title), placed after `ForYouSection`.
  - Hidden if the vibe list fails or is empty.
- **Mix screen:** route `/mixes/:id`, file `android/app/lib/screens/mixes/mix_screen.dart`.
  - **Header:** cover and title, "Made for <nickname>" (or "Popular <mood> picks" when `personalized: false`), and **Play all**, **Regenerate** and **Save as playlist**.
  - **Rows:** art, title and artist, plus a download button via `downloadRecommendation`. A row tap plays the mix from that song.
  - **States:** loading (spinner), error (message plus Retry), empty ("Nothing new for this vibe").
- **Save as playlist** (`android/app/lib/providers/mix_saver.dart`, a keep-alive notifier, so leaving the screen doesn't cancel it):
  1. Create an empty Navidrome playlist named "<Mix title> · <d MMM>" via `PlaylistMutations.createPlaylist`.
  2. Dispatch `POST /download` for every song (the backend throttle runs 2 at a time).
  3. Await each song with `waitForLibrarySong`, which is steps 2–3 of `downloadAndAddToPlaylist` extracted into a context-free function.
  4. Call `addSongs` **in mix order** once all have resolved or timed out.
  5. Progress shows on the button ("Saving 12/25"), then a summary ("Saved 23 of 25 · 2 failed").

  `# ponytail: an app kill mid-save leaves a partial playlist (downloads still finish server-side).`

## 6. Out of scope

- Genre mixes (Hindi, Punjabi, …), daily auto-generated mixes, push notifications.
- Per-track mood tagging (no data source, see §3).
- Saving a mix without downloading. Navidrome playlists can only hold library songs.
- Persisting an in-progress save across an app kill.

## 7. Tasks

Backend first, TDD (`backend/CLAUDE.md`, `android/CLAUDE.md`):
- Run `poetry run pytest` / `flutter analyze` + `flutter test` green before and after every task.
- Run `graphify update .` after code changes.
- One commit per task, with the message given.

### [x] MX0. Docs: ADRs + roadmap entries (no code)
1. `backend/docs/DECISIONLOG.md`: add an ADR "Vibe mixes from YTM Moods & moments, personalised by playlist affinity" covering §3 and §5.2–5.4. Include the download throttle as its own ADR.
2. `android/docs/DECISIONLOG.md`: add an ADR "Your Mixes shelf, mix screen, save-as-playlist via download + wait" covering §5.5.
3. In both ROADMAPs, add a "Phase MX — Vibe mixes (v5.8.0)" section with the MX headings. Keep RX9 open.
4. Add a changelog entry in both CHANGELOGs.
- Commit: `docs: plan phase MX (vibe mixes)`.

### [x] MX1. Backend: cap concurrent downloads
1. Tests first, in `tests/test_workers.py` (or a new `tests/test_download_concurrency.py`), with a fake runner that blocks on an event:
   - 5 jobs enqueued with `DOWNLOAD_CONCURRENCY=2` never have more than 2 in the runner at once
   - jobs 3–5 stay `queued` until a slot frees up
   - all 5 end `done`
   - a failing runner releases its slot
2. Add `DOWNLOAD_CONCURRENCY` to `app/config.py` Settings (default 2, `ge=1`) and to `.env.example`, with a comment.
3. In `workers.py`, use a module-level semaphore sized from settings, acquired before `mark_running` and released in `finally`.
- Commit: `feat(backend): MX1 cap concurrent downloads (DOWNLOAD_CONCURRENCY=2)`.

### [x] MX2. Backend: mix scoring (pure functions)
1. Tests first, in `tests/test_mixes_scoring.py`, with fixture playlists as plain dicts in the RX4 shapes:
   - `taste_profile(seeds)`: lowercases and trims, max weight wins, song and artist seeds both count
   - `playlist_affinity(tracks, taste)`: weighted share of matching tracks, matching on **any** listed artist; 0 for an empty playlist
   - `pick_playlists(scored, variant)`: top 8 by affinity with stable ties, 4 chosen by rotation, so variant 0 and variant 1 differ and variant 2 wraps
   - all-zero affinity falls back to YTM order with `personalized=False`
   - `score_tracks(chosen, taste)`: position decay, the taste bonus added once, duplicates across playlists summed, items without a `videoId`/title/artist skipped
2. Implement these in `app/services/recommenders/mixes.py`, with constants `CANDIDATE_PLAYLISTS=24`, `POOL=8`, `PICK=4` and `PER_ARTIST=3`.
- Commit: `feat(backend): MX2 mix scoring`.

### [x] MX3. Backend: YTM mood fetch + 24-hour cache
1. Tests first, in `tests/test_mixes_fetch.py`. The fake YTM client gets `get_mood_categories`, `get_mood_playlists` and `get_playlist`, plus call counters and an in-flight counter.
   - a mood is found by title, and a missing one raises `MoodNotFound`
   - 24 candidates are fetched with at most 4 in flight
   - a failing `get_playlist` is skipped
   - a second build within the TTL makes **no** YTM calls
   - an expired TTL refetches (time is injected so tests don't sleep)
2. Implement `VIBES` (§5.1), the `MixBuilder` class (fetch, cache, then the MX2 functions), and `TTLCache`. Calls run via `asyncio.to_thread`, as in `ytmusic_engine.py`.
- Commit: `feat(backend): MX3 ytm mood fetch + cache`.

### [x] MX4. Backend: mix endpoints
1. Move the RX3 `_history(session, user_id, urls)` from `api/v1/recommend.py` into `app/services/recommenders/history.py` (no behaviour change; existing tests stay green).
2. Tests first, in `tests/test_mixes_api.py`, with a fake `MixBuilder` via `dependency_overrides`:
   - `GET /mixes` returns all 8 `{id, title}`, and 401 without a token
   - `POST /mixes/chill` returns results with `cover_url`, plus `personalized` and `title`
   - an unknown id gives 404, and `MoodNotFound` gives 503
   - `limit` above 50 and a negative `variant` give 422
   - the user's non-failed jobs and dismissed songs are excluded, while other users' jobs aren't
   - covers are dropped, and at most 3 per artist
   - **no** `rec_feedback` "shown" rows are written
3. Implement the schemas (`MixRequest`, `MixResponse`, `MixVibeItem` in `app/schemas/recommend.py`), the routes, and a `get_mix_builder` dependency (a module-level singleton, so the cache survives between requests).
- Commit: `feat(backend): MX4 mix endpoints`.

### [x] MX5. Backend: home-server smoke (docs only)
1. Tag a backend release, or build and deploy as you usually do, then run `docker compose pull heerr-backend && docker compose up -d heerr-backend`.
2. Smoke script (throwaway read-only `system-admin` token, revoked on exit, like RX7):
   - `GET /recommend/mixes` returns 8 vibes
   - `POST /recommend/mixes/chill` and `/party` with your real seeds: record cold and warm timings (targets: cold < 6 s, warm < 1 s), `personalized`, the result count, distinct artists, and the top 10 titles. Check that they read like your taste.
   - `variant=1` returns a different list
   - 5 rapid `POST /download`s: the queue shows at most 2 `running`. Record the time per song.
3. Write the results to `backend/docs/CHANGELOG.md`. **If `personalized` is false for your seeds on most vibes, stop and revisit §5.2** (raise `CANDIDATE_PLAYLISTS`, or match related artists) before any Android work.

### [ ] MX6. Android: mix data layer
1. Tests first:
   - `test/models/mix_test.dart`: JSON round trips
   - `test/services/backend_service_mix_test.dart`: the right paths and bodies
   - `test/providers/mixes_provider_test.dart`:
     - sends **all** seeds, not a sample
     - drops owned songs via `hydrateLibraryMatches`
     - `regenerate()` posts `variant+1`
     - errors surface as `AsyncError`
2. Extract `hydrateLibraryMatches` (For You behaviour unchanged, and `recommendations_provider_test.dart` stays green).
3. Implement `lib/models/mix.dart` (freezed), the two `BackendService` methods and endpoint constants, and `lib/providers/mixes.dart`. Then run code generation from `android/app`:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
- Commit: `feat(flutter): MX6 mix data layer`.

### [ ] MX7. Android: `playPreviews` and the mix screen
1. Tests first:
   - `test/player/playback_actions_previews_test.dart`: maps N items to N preview `MediaItem`s, calls `playAll` with `startIndex`, and is blocked during a jam
   - `test/screens/mixes/mix_screen_test.dart`:
     - loading, error with Retry, and empty states
     - "Made for <nickname>" vs "Popular … picks"
     - Play all calls `playAll` from 0, and a row tap plays from that index
     - the row download dispatches
     - Regenerate calls the notifier
2. Implement `playPreviews`, `MixScreen`, and the route `Routes.mix(id)` → `/mixes/:id` in `lib/router.dart`.
- Commit: `feat(flutter): MX7 mix screen`.

### [ ] MX8. Android: "Your Mixes" on Home
1. Tests first:
   - `test/screens/home/your_mixes_section_test.dart`: 8 tiles in a horizontal row; a tap pushes `/mixes/<id>`; hidden on error or an empty list
   - `home_screen_test.dart`: the section sits below For You and above Recently Added (stub the provider in `_homeOverrides`)
2. Implement `YourMixesSection`, with one gradient per vibe built from the theme colours, and insert it in `home_screen.dart`.
- Commit: `feat(flutter): MX8 Your Mixes on Home`.

### [ ] MX9. Android: save a mix as a playlist
1. Extract `waitForLibrarySong(...)` from `downloadAndAddToPlaylist` (context-free; it returns a song id or null). The existing `download_to_playlist` tests stay green.
2. Tests first, in `test/providers/mix_saver_test.dart`, with fake dispatcher, job status, library-match and playlist mutations:
   - creates "<title> · <d MMM>"
   - dispatches every song
   - adds the resolved songs **in mix order**
   - reports failed and timed-out counts
   - progress updates as songs resolve
   - a second save of the same mix while one is running is a no-op
3. Add widget tests on the mix screen: the button shows "Saving x/y" and then a summary.
4. Implement `MixSaver` (keep-alive, keyed by mix id) and wire up the button.
- Commit: `feat(flutter): MX9 save mix as playlist`.

### [ ] MX10. On-device smoke, then 5.8.0 and docs
1. On the Pixel (`flutter run --release` from `android/app`):
   - 8 tiles on Home
   - Chill opens with songs you don't own, and Play all queues them
   - Regenerate changes the list
   - a row download works
   - Save as playlist creates "Chill Mix · <date>" and fills it
2. Bump the version to **5.8.0** in all five places (`/CLAUDE.md` §3).
3. Update docs:
   - `backend/docs/CONTEXT.md`: a mixes bullet plus the download throttle
   - both CHANGELOGs
   - tick the boxes here and in both ROADMAPs
- Commit: `chore: bump version to 5.8.0 (vibe mixes)`.

## 8. Risks

| Risk | Mitigation |
|---|---|
| YTM renames a mood | Moods are looked up by title, a missing one returns 503 (tested), and the mix screen shows an error with Retry. |
| Your artists don't appear in a mood's top 24 playlists | Fall back to `personalized: false` with "Popular … picks" in the UI. MX5 measures how often it happens before Android work starts. |
| Save as playlist is slow (about 25 songs, 2 at a time) | Progress on the button, a keep-alive notifier, and the real time per song measured in MX5. |
| A cold mix takes about 4.5 s | A spinner on the mix screen; the 24-hour cache makes repeats under 1 s. |
| The download throttle slows ordinary single downloads during a burst | A queued job shows as `queued` (truthful), and `DOWNLOAD_CONCURRENCY` is tunable without a rebuild. |
