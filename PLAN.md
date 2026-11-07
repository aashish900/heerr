# PLAN — Better "For You" recommendations (phase RX)

Status: **planned, nothing built.** Step 1 (the engine) is RX0–RX9. Step 2 (a For You section on Home, plus a "Not interested" action) will be planned separately once RX ships.

> The previous plan in this file, Jam / remote control (phase JM, complete), lives in git history at `f4ce359:PLAN.md`. Older references to `/PLAN.md §5` in code and docs point there.

## 1. Goal

Recommend **songs you don't already own** that fit your taste: varied, not repeated, and never anything you've dismissed. Spotify Discover / YT Music "For you" is the benchmark.

## 2. Decisions (user-confirmed 2026-11-07)

- **"New" means not in your library.** Artists already in the library are fine.
- **Feedback is in scope.** Dismissed songs never come back, and recently shown songs are pushed down.
- **Engine config on the server is unknown.** Design for `ytmusic` as primary, with the shared re-ranking applied to every engine (`ytmusic`, `lastfm`, `listenbrainz`).
- **Step 2 (Home UI) is separate.** The dismiss *endpoint* ships here, and the *button* ships with step 2.

## 3. Facts (from code)

| # | Fact | Source |
|---|---|---|
| F1 | `YTMusicEngine.recommend` loops over seeds in order and `break`s once `len(out) >= limit`. | `backend/app/services/recommenders/ytmusic_engine.py`, `recommend()` |
| F2 | `get_watch_playlist` returns 25 tracks by default, so one seed fills the client's `limit=20`. | `.venv/.../ytmusicapi/mixins/watch.py:14` (`limit: int = 25`) |
| F3 | `get_watch_playlist` also returns a `related` browseId, and `get_song_related(browseId)` returns the "You might also like" shelves. | `ytmusicapi/mixins/watch.py:193`, `mixins/browsing.py:883` |
| F4 | Frequent albums become seeds shaped `SeedTrack(title: album.name, artist: album.artist)`. | `android/app/lib/providers/recommendations.dart`, `buildSeedCollection` |
| F5 | The backend resolves seeds without a URL via `search(f"{artist} {title}", filter="songs", limit=1)`. | `ytmusic_engine.py`, `_resolve_via_search` |
| F6 | Library songs are flagged `inLibrary` via `findLibraryMatch` (search3) but **not removed**. | `recommendations.dart`, `_hydrateLibraryMatches` |
| F7 | The client sends 8 randomly sampled seeds from up to 20, with `limit: 20` and a 30-minute keep-alive TTL. | `recommendations.dart`: `kSeedSampleSize`, `_kRecommendationsLimit`, `_kRecsMaxAge` |
| F8 | `POST /recommend` takes only `require_scope("read")` and doesn't resolve the user, so it can't filter per user. | `backend/app/api/v1/recommend.py` |
| F9 | `RecommendSeed` uses `extra="forbid"`, `title` is required (`min_length=1`), and `limit` is capped at 50. | `backend/app/schemas/recommend.py` |
| F10 | `jobs` has `user_id` and `source_url`, so per-user "already requested" is a single query. | `backend/app/models/job.py:68`, DECISIONLOG 2026-06-16 |
| F11 | The latest migration is `0015` (jam). | `backend/alembic/versions/0015_jam.py` |
| F12 | Home already shows "Picked for you" cards fed by `recommendationsProvider`. | `android/app/lib/screens/recommendations_screen.dart:71` (comment #21) |

**Root cause of the weak feed (inference from F1, F2, F4 and F6):** the first resolved seed alone fills all 20 slots, album-title seeds resolve to arbitrary songs, and owned songs aren't filtered. So the feed is one seed's radio, padded with songs you already have.

## 4. Assumptions (review before RX1)

1. The ytmusicapi calls (`get_song_related`, `get_artist`, `search(filter="artists")`) work unauthenticated from the server, as `get_watch_playlist` already does. RX4 verifies this first in a REPL.
2. 8 seeds × about 2 YTM calls each, with concurrency 4, finishes in **under 6 s**. If not, RX4 adds a per-videoId in-memory TTL cache, marked `ponytail:`.
3. The library filter (F6) also applies to the "Find similar" screen, which then shows only songs you don't own. Say so if Find similar should keep showing owned songs.
4. A "shown" mark expires after **7 days**, and a demoted score is multiplied by **0.3**. Both are tunable constants.
5. **At most 2 songs per artist** in a feed of 20.

## 5. Design

### 5.1 Pipeline

```
Android                            Backend
seeds (song w=1.0,                 POST /recommend
 artist w=0.7/0.4) ── sample 8 ──▶   engine.recommend(seeds, limit*2)   ← candidates + consensus score
 limit=40                            rerank(excl. jobs+dismissed, demote shown, ≤2/artist) → limit
                                     upsert rec_feedback.shown
◀── results ───────────────────────
hydrate inLibrary (search3) → drop owned → take 20
```

### 5.2 Seeds (Android)

| Source | Seed kind | Weight |
|---|---|---|
| `getStarred2` songs | song `(title, artist)` | 1.0 |
| `getAlbumList2?type=frequent&size=30` | **artist** `(artist)` | 0.7 |
| `getAlbumList2?type=recent&size=20` | **artist** `(artist)` | 0.4 |
| Favourites playlist (only if all of the above are empty) | song | 1.0 |

Dedupe songs by `title|artist` and artists by lowercased name. When an artist appears more than once, keep its highest weight. The cap stays at 20 and `sampleSeeds` (8 per request) is unchanged.

### 5.3 Wire contract (additive, old clients keep working)

```python
class RecommendSeed(BaseModel):
    model_config = ConfigDict(extra="forbid")
    title: str | None = Field(default=None, min_length=1)  # None ⇒ artist seed
    artist: str = Field(..., min_length=1)
    source_url: str | None = None
    weight: float = Field(default=1.0, ge=0.0, le=1.0)
```

`SeedTrack` (backend dataclass and Dart freezed model) mirrors this. `RecommendRequest.limit` stays capped at 50.

### 5.4 Candidate generation (`YTMusicEngine`)

For each seed, concurrently via `asyncio.gather` with `asyncio.Semaphore(4)` (calls stay in `asyncio.to_thread`):

- **Song seed:** resolve the videoId (reuse `_video_id_from_url` and `_resolve_via_search`). Call `get_watch_playlist(videoId)` and take its `tracks` (**50 in practice, with the seed itself first**, per RX4), skipping the seed. If `watch["related"]` is set, call `get_song_related(...)` and take **only the shelf titled "You might also like"** (20 songs). Never use "Other performances": it's covers and mashups *of the seed song*. The playlist, similar-artist and artist shelves have no `videoId`, and "About the artist" has string `contents`, so non-list contents are treated as empty. The ytmusicapi client defaults to `language="en"`, so the shelf title is stable. Merge the shelf songs into the radio list and **dedupe within the seed** before scoring (RX4 saw the same track in both lists for one seed).
- **Artist seed:** call `search(artist, filter="artists", limit=1)` and take its `browseId`. Call `get_artist(browseId)` and take `["songs"]["results"]`, the artist's top songs (**5 in practice**). `artists[0]` on these songs isn't always the seed artist, e.g. "Gehra Hua" lists Shashwat Sachdev before Arijit Singh. The 2-per-artist cap keys on `artists[0]`, which is accepted.

Each seed yields an ordered list. **Consensus scoring:**

```
score(track) = Σ over seeds that produced it:  seed.weight / (1 + 0.1 · rank_in_that_seed_list)
```

Then drop the seeds' own videoIds, sort by score descending, and return the top `limit` as `RecommendedTrack(score=...)`. A failure on one seed is logged at WARNING and skipped, as today.

### 5.5 Re-rank and feedback (any engine, `rerank.py`)

A pure function, so it can be tested without a database:

```python
def rerank(
    candidates: list[RecommendedTrack],
    *, excluded: set[str], recently_shown: set[str], limit: int, per_artist: int = 2,
) -> list[RecommendedTrack]
```

1. Drop `source_url ∈ excluded`.
2. Multiply the score by `0.3` if `source_url ∈ recently_shown`. A missing score (Last.fm / ListenBrainz) counts as `1.0 / (1 + 0.1 · index)`.
3. Sort by score descending, then greedily take items while skipping any artist (lowercased) that already has `per_artist` songs.
4. Stop at `limit`.

Route flow in `POST /recommend`:
`user = current_user` → `candidates = engine.recommend(seeds, min(limit*2, 100))` → `excluded = user's jobs (status != failed) ∪ user's dismissed` → `recently_shown = last_shown_at > now() - 7d` → `rerank` → upsert the shown rows → respond.

### 5.6 Data model (migration `0016_rec_feedback`)

```sql
CREATE TABLE rec_feedback (
  user_id       uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source_url    text        NOT NULL,
  shown_count   integer     NOT NULL DEFAULT 0,
  last_shown_at timestamptz,
  dismissed_at  timestamptz,
  PRIMARY KEY (user_id, source_url)
);
```

The upsert for shown rows is `INSERT ... ON CONFLICT (user_id, source_url) DO UPDATE SET shown_count = rec_feedback.shown_count + 1, last_shown_at = now()`. Rows are never pruned. Size is bounded by about 20 rows per refresh, which is fine for a family app (`ponytail:` note: prune when `last_shown_at` is older than 90 days if the table ever matters).

### 5.7 API

| Method | Path | Body | Response | Notes |
|---|---|---|---|---|
| POST | `/api/v1/recommend` | `{seeds, limit}` (5.3) | unchanged | now per user (5.5) |
| POST | `/api/v1/recommend/dismiss` | `{source_url}` | `204` | idempotent upsert of `dismissed_at = now()`; `read` scope; scoped to current user |
| GET | `/api/v1/recommend/health` | n/a | unchanged | n/a |

## 6. Out of scope (step 1)

- Home "For You" section and the "Not interested" button (step 2).
- Artist-level dislike, genre or mood shelves, time-of-day mixes.
- A backend-side play-history store. Navidrome stays the history source through Subsonic, and the backend never calls Navidrome as the user (it stores no passwords, ADR 2026-06-16).
- Embeddings / pgvector similarity. Revisit only if consensus ranking proves insufficient.
- Changes to the `lastfm` / `listenbrainz` engines beyond the shared re-rank.

## 7. Tasks

Backend first, TDD (`backend/CLAUDE.md`). Run `poetry run pytest` green before and after each task, and run `graphify update .` after code changes. Commit one task at a time with Conventional Commits.

### [x] RX0. Docs: ADR + roadmap entries (no code)
- `backend/docs/DECISIONLOG.md`: ADR "Recommendations v2: consensus candidates + per-user re-rank + feedback table", covering the decisions in §2 and the design in §5.4–5.6.
- `android/docs/DECISIONLOG.md`: ADR "For You seeds: artist seeds from frequent/recent albums; owned songs filtered client-side".
- `backend/docs/ROADMAP.md` and `android/docs/ROADMAP.md`: add "Phase RX — Better recommendations (v5.7.0)" with RX headings and a pointer to `/PLAN.md`.
- Commit: `docs: plan phase RX (recommendations v2)`.

### [x] RX1. Backend: `rerank()` pure function
1. Write `tests/test_rerank.py` first. Cover:
   - excluded URLs are dropped
   - recently shown items are demoted below unshown items of equal score
   - at most 2 per artist, case-insensitive
   - a missing score falls back to positional order
   - the output is capped at `limit`
   - an empty input gives an empty output
2. Implement `app/services/recommenders/rerank.py` (about 30 lines), with constants `SHOWN_PENALTY = 0.3` and `PER_ARTIST = 2`.
- Commit: `feat(backend): RX1 rerank recommendations (exclude, demote, artist cap)`.

### [x] RX2. Backend: migration + model
1. Add `alembic/versions/0016_rec_feedback.py` (§5.6), following the 0015 file layout.
2. Add `app/models/rec_feedback.py` (`RecFeedback`) and export it from `app/models/__init__.py`.
3. Gate: `alembic upgrade head` and `alembic downgrade -1` both run clean against the dev Postgres.
- Commit: `feat(backend): RX2 rec_feedback table (migration 0016)`.

### [x] RX3. Backend: route wiring + dismiss endpoint
1. Add tests to `tests/test_recommend.py`, reusing `FakeEngine` and testcontainers Postgres:
   - `/recommend` excludes the user's job URLs
   - another user's jobs are **not** excluded
   - a dismissed URL never returns
   - a second call demotes items shown on the first call
   - returned items are upserted (`shown_count` increments)
   - the engine is asked for `min(limit*2, 100)`
   - `/recommend/dismiss` returns 204, is idempotent, needs auth (401 without a token), and only affects the caller
2. Implement:
   - schema `DismissRequest {source_url: str}`
   - `POST /recommend` depends on `current_user` and runs the §5.5 flow
   - `POST /recommend/dismiss`
- Commit: `feat(backend): RX3 per-user recommend re-rank + /recommend/dismiss`.

### [x] RX4. Backend: verify ytmusicapi calls (spike, no feature code)
1. In `backend/.venv`, run a REPL on the server (inside the backend container) for one known song and one known artist. Call `get_watch_playlist`, then `get_song_related(watch["related"])`, `search(artist, filter="artists", limit=1)`, and `get_artist(browseId)["songs"]["results"]`.
2. Record the real response shapes, which keys hold `videoId` / `artists`, and the timings in `backend/docs/CHANGELOG.md`.
3. If any call fails unauthenticated, stop and revise §5.4 before RX5.

### [x] RX5. Backend: schema — artist seeds + weights
1. Tests first:
   - a payload without `weight` or `title` validates as an artist seed
   - an old-client payload (title + artist only) is unchanged
   - `weight > 1` gives 422
   - an empty-string title gives 422
2. Update `RecommendSeed` (§5.3), the `SeedTrack` dataclass (`title: str | None`, `weight: float = 1.0`) and the route mapping.
3. Check that `lastfm_engine.py` and `listenbrainz_engine.py` skip seeds with no title (or treat them as artist seeds via `artist.getTopTracks`, which Last.fm already has as `_ARTIST_TOP_WEIGHT`). Add tests for this.
- Commit: `feat(backend): RX5 artist seeds + seed weights in /recommend`.

### [x] RX6. Backend: YTMusic engine rewrite
1. Tests first, in `tests/test_recommend_ytmusic.py` (or extend the existing engine tests), with a fake `_YTMusicLike` that also covers `get_song_related` and `get_artist`:
   - 3 song seeds each returning 25 tracks: the output contains tracks from all 3 (the F1 regression)
   - a track produced by 2 seeds outranks single-seed tracks
   - a weight-1.0 seed outranks a weight-0.4 seed at the same rank
   - seed videoIds are never in the output
   - an artist seed goes through `search(filter="artists")` and `get_artist`, and yields its top songs
   - one seed raising an exception doesn't kill the others
   - a missing `related` key skips `get_song_related`
   - concurrency never exceeds 4 (track max in-flight inside the fake)
2. Implement §5.4 in `ytmusic_engine.py`, extending the `_YTMusicLike` protocol with `get_song_related` and `get_artist`.
3. Time a real `/recommend` call with 8 seeds over Tailscale. If it takes more than 6 s, add an in-memory TTL cache keyed by videoId or artist (marked `ponytail:`).
- Commit: `feat(backend): RX6 ytmusic engine — concurrent multi-seed, related songs, artist seeds, consensus score`.

### [ ] RX7. Backend: curl smoke on the home server
1. Rebuild and deploy (`docker compose up -d --build heerr-backend`), and confirm `heerr-migrate` applied `0016`.
2. Call `POST /recommend` with 3 starred-song seeds and 1 artist seed, `limit: 20`. Check that the results include more than 8 distinct artists and nothing you've already requested.
3. Call `POST /recommend/dismiss` with one result, then call `/recommend` again with the same seeds and confirm the dismissed song is gone and earlier results have moved down.
4. Confirm `GET /recommend/health` is unchanged.
5. Log the commands and their output in `backend/docs/CHANGELOG.md`. Per `/CLAUDE.md`, Android work starts only after this passes.

### [ ] RX8. Android: seeds, request size, owned-song filter
Files: `android/app/lib/models/seed_track.dart`, `android/app/lib/providers/recommendations.dart`, `android/app/lib/services/backend_service.dart` (body serialisation only, if needed).
1. `SeedTrack`: make `title` nullable and add `@Default(1.0) double weight`. Then run code generation:
   ```bash
   cd android/app && dart run build_runner build --delete-conflicting-outputs
   ```
   Make sure `toJson` leaves out a null `title`, not `"title": null`. The backend would accept `null` too, since it's `str | None`.
2. `seedForSong` ("Find similar") stays a song seed with weight 1.0.
3. Update `buildSeedCollection` to take `recent` as well, emit artist seeds per §5.2, and dedupe artists while keeping the max weight.
4. In `seedCollection`, add `service.getAlbumList(type: 'recent', size: 20)`.
5. In the `Recommendations.build`, request `limit: 40` (rename `_kRecommendationsLimit` and add `_kRecommendationsShown = 20`). After `_hydrateLibraryMatches`, use `.where((r) => !r.inLibrary).take(20)`.
6. Tests in `android/app/test/providers/recommendations_provider_test.dart`:
   - frequent and recent albums produce artist seeds (no album-title seeds)
   - an artist appearing in both gets weight 0.7
   - starred songs come first
   - owned results are filtered out and the list is capped at 20
   - the Favourites fallback still works
   Also update the `_StubRecs` users if their signatures change.
7. Gate: `flutter analyze` and `flutter test` both pass.
- Commit: `feat(flutter): RX8 artist seeds + weights, hide owned songs in For You`.

### [ ] RX9. End-to-end smoke + version 5.7.0 + docs
1. Bump the version to **5.7.0** in all five places (`/CLAUDE.md` §3): `backend/pyproject.toml`, `backend/app/main.py`, `android/app/pubspec.yaml`, and both ROADMAP status lines.
2. Install on the Pixel 7:
   ```bash
   cd android/app && flutter run --release
   ```
   Open For You and pull to refresh twice. Check:
   - no song you own appears
   - more than 5 distinct artists
   - the second refresh is mostly different from the first
   - Find similar on a song still works
3. Update docs:
   - `backend/docs/CONTEXT.md`: the recommendations bullet (engine pipeline, `rec_feedback`)
   - both CHANGELOGs
   - tick the RX boxes here and in both ROADMAPs
- Commit: `chore: bump version to 5.7.0 (recommendations v2)`.

## 8. Risks

| Risk | Mitigation |
|---|---|
| ytmusicapi is unofficial, so YouTube can change response shapes. | Parse defensively (skip items missing `videoId` / `artists`). RX4 records the real shapes. One failing seed doesn't fail the request. |
| More YTM calls per refresh (about 16 instead of about 8) could hit rate limits or get slow. | Semaphore of 4, the client's 30-minute TTL, and an optional TTL cache (RX6 step 3). |
| `findLibraryMatch` (search3, fuzzy) can miss an owned song with different metadata, so it leaks into For You. | Accepted for v1. The user's `jobs` exclusion on the backend catches anything downloaded through heerr. |
| Filtering owned songs from 40 candidates leaves fewer than 20. | Raise `limit` to 50 (the schema cap) if it happens often. Decide during RX9. |
| Demoting shown songs for 7 days can thin the feed for users with few seeds. | The demotion only multiplies the score; nothing is excluded except dismissed and requested songs. |
