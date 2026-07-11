# LIBRARYSCREEN.md — Library Screen redesign plan

Status: **PLANNED** 2026-07-11. Written against branch `redesign/profile-screen` @ `312e958` (v4.9.0).
Reference mockup: pasted in the planning session (three-panel image: Albums / Artists / Playlists tabs). **Not yet on disk** — save it as `/Users/E1621/Documents/Personal/Android/Library Screen.png` (or `android/docs/assets/library-screen.png` to version it).
Milestone prefix: **X** (X1–X7) — the only unused letter in the A–Z roadmap sequence.

Goal: move the Library screen from the plain Material `TabBar` + flat `ListView` layout to the branded design: shared heerr header, "Your Library" headline, icon segmented tabs (Albums / Artists / Playlists), per-tab filter chips, album grid with downloaded badges, alphabet scrubber, artist rows with a Most Played rail, and playlist cards with Favorites + Create Playlist tiles.

---

## 0. Ground rules for the implementing agent

- Bootstrap first: `/CLAUDE.md`, `android/CLAUDE.md`, `android/docs/CONTEXT.md`, `DECISIONLOG.md`, `CHANGELOG.md`.
- `graphify-out/graph.json` exists — `graphify query "<question>"` before reading unfamiliar source; `graphify update .` after code changes.
- **TDD:** failing widget/provider test first. `flutter test` + `flutter analyze` green before starting and before declaring each task done. Working dir: `android/app/`.
- All colors from `lib/theme.dart` (`heerrMagenta`, `heerrGradient`, …) / `Theme.of(context).colorScheme`. No new hex literals unless specified here.
- No emojis in code/commits (the 👋 greeting is a UI string, allowed there only).
- Flush `docs/CHANGELOG.md` (+ `DECISIONLOG.md` for decisions) at the end of each task.
- One commit per task: `feat(flutter): library redesign X<n> — <thing>`.

---

## 1. Mockup spec (top → bottom, all three tabs)

| # | Zone | Content |
|---|------|---------|
| 1 | Header | Same as Home: heerr logo mark, "Good evening, / Aashish 👋" greeting, search icon, queue icon, avatar with gradient ring |
| 2 | Title | "Your Library" headline (large, bold) |
| 3 | Segmented tabs | Pill-style row with icons: Albums / Artists / Playlists — active tab magenta |
| 4 | Chip row | Per-tab: sort dropdown chip (magenta when active), "Downloaded" toggle chip, (Albums only) "Year ▾" chip, trailing filter icon |
| 5 | Tab body | See per-tab spec below |
| 6 | Mini-player | Existing pinned `MiniPlayer` — no work |
| 7 | Bottom nav | **Unchanged** (decision §2.1) — mockup's 5-tab nav is out of scope |

### Albums tab
- 3-column grid of album cards: square cover, title (bold, 1 line), artist (grey), "N songs", pink check badge bottom-right when downloaded.
- A–Z index scrubber pinned to the right edge (# then A–Z).
- Section "Albums ›" below the grid: list rows — 48px cover thumb, title (+ explicit "E" badge in mockup — **no data source, dropped**, see §5), "artist • year • N songs" subtitle, kebab overflow.

### Artists tab
- Chips: "A–Z ▾", "Downloaded", filter icon.
- Rows: circular avatar, artist name, "N albums • M songs" (**albums count only** per decision §2.4), chevron on first row / kebab on the rest → we render kebab consistently.
- A–Z scrubber on the right.
- Section "Most Played Artists" + "See all": horizontal rail of circular avatars with a small gradient play badge, names below.

### Playlists tab
- Chips: "Recently Added ▾", "Downloaded", filter icon.
- 2-column card grid: cover with dark gradient overlay, title, "by <owner>", "N songs"; first card = **Favorites** with heart icon; last card = **+ Create Playlist**.
- Section "Playlists ›" below: list rows — thumb, title, "by <owner> • N songs", kebab. Favorites appears as the first row with a heart-tile thumb.

---

## 2. Decisions already made (do not re-ask)

Confirmed with the user 2026-07-11:

1. **Bottom nav unchanged.** The mockup's Home/Library/Downloads/Search/Profile nav is out of scope; the app keeps Home/Library/Downloads/Settings. A nav overhaul would be its own cross-cutting phase.
2. **Grid = recent subset, list = full library.** On Albums and Playlists tabs the top grid shows a subset honoring the sort chip (9 albums / 6 playlist cards); the "Albums ›" / "Playlists ›" section below lists the *entire* (filtered/sorted) library in one scroll view.
3. **Tab order becomes Albums / Artists / Playlists** (mockup order). The `/library?tab=` deep-link mapping in `router.dart` is updated in the same task — switch to named values, not raw indices.
4. **Artist rows show "N albums" only.** Subsonic `getArtists` has no song count; per-artist `getArtist` fan-out rejected. Logged to DEBT.md.

---

## 3. Current-state map (file:line facts)

- Library screen: `lib/screens/library/library_screen.dart` (162 lines) — plain AppBar "Library" + search icon, `DefaultTabController` order Artists/Albums/Playlists, search mode owned by `librarySearchActiveProvider`. `initialTabIndex` consumed at :132; deep-link mapping `_tabIndexFor` in `lib/router.dart`.
- Tab bodies: `lib/screens/library/library_tabs.dart` (part file) — `_ArtistsTab` (:7), `_AlbumsTab` (:50), `_PlaylistsTab` (:95, has create-playlist FAB + trailing "For You" entry :164).
- Search results part file: `lib/screens/library/library_search_results.dart` — untouched by this redesign; search entry moves into the new header's magnifier icon but flips the same `librarySearchActiveProvider`.
- Data providers (`lib/providers/library/`): `libraryAlbumsProvider` (getAlbumList2 `type=alphabeticalByName&size=500`, cache-aware), `libraryArtistsProvider` (`getArtists` → `List<ArtistIndex>`), `libraryPlaylistsProvider`.
- Service: `SubsonicLibraryService.getAlbumList(type, size)` (`lib/services/subsonic_library_service.dart:59`) — already parameterised; Home uses `recent`/`frequent`.
- Models: `Album{year, songCount, created, coverArt}` (`lib/models/subsonic/album.dart`), `Artist{albumCount, coverArt, artistImageUrl}` — no songCount (`artist.dart`), `Playlist{owner, songCount, created, changed, coverArt}` (`playlist.dart`).
- Downloaded state: `offlineManifestProvider` → `markedAlbums` / `markedPlaylists` sets (used at `library_tabs.dart:70,154`). **No per-artist set.**
- Header building blocks (from Home/Profile redesigns): `HeerrLogo` (`lib/widgets/heerr_logo.dart`), `greetingForHour()` + `_GreetingBlock` + `_ProfileAvatarButton` (`lib/screens/home/home_screen.dart:26,82`), `ProfileAvatarRing` (`lib/widgets/profile_avatar_ring.dart`), queue shortcut (home_screen.dart:67).
- Reusable widgets: `LibraryCoverArt` (`lib/widgets/library_cover_art.dart`), `GradientTabIndicator` (`lib/widgets/gradient_tab_indicator.dart`), `Skeleton*`, `EmptyState`, `LibraryResultTile`, `song_row_actions.dart`, `playlist_dialogs.dart` (`CreatePlaylistDialog`).
- Favorites: `lib/screens/library/favorites_screen.dart` + `starredSongsProvider` (`lib/providers/library/starred_songs.dart`); routed — reuse for the Favorites card.
- Most-played source: Home's `homeMostPlayedProvider` (`lib/providers/home/home_providers.dart`) wraps `getAlbumList(type: 'frequent')` — artists derivable by deduping `album.artistId`.
- Existing tests: `test/screens/library/` — tab tests will need rewrites for the new order/layout; keep search-mode coverage intact.

---

## 4. Task breakdown

### X1 — Shared branded header + "Your Library" + segmented tabs + tab reorder

**Files:** new `lib/widgets/branded_header.dart`; `lib/screens/home/home_screen.dart` (extract, keep behavior); `lib/screens/library/library_screen.dart`; `lib/router.dart`; tests for all three.

1. Extract the Home AppBar content (logo + queue icon + avatar) **and** the greeting block into a reusable `BrandedHeader` widget (`lib/widgets/branded_header.dart`) so Home and Library render the identical header. Home must be pixel-identical after the refactor (its existing widget tests are the regression gate).
2. Library scaffold: `BrandedHeader` (with a search `IconButton` action that calls the existing `_enterSearch`), then `Text('Your Library', style: headlineMedium/w800)`, then the segmented tab row.
3. Segmented tabs: restyle `TabBar` (icons + labels, `GradientTabIndicator` or pill highlight per mockup — pick whichever reads closer to the mockup with the existing widget first). New order: **0=Albums, 1=Artists, 2=Playlists**.
4. `lib/router.dart` `_tabIndexFor`: map `?tab=albums|artists|playlists` (named) → new indices; keep legacy numeric values working if any caller passes them. Update the Profile Z3 "Playlists" deep link expectation tests.
5. Search mode, `librarySearchActiveProvider` semantics, and the shell back-button PopScope contract are untouched.

**Test gate:** header renders on both screens; tab order; deep-link mapping; search-mode entry/exit still green.
**Commit:** `feat(flutter): library redesign X1 — shared branded header, Your Library headline, segmented tabs, tab reorder`

### X2 — Filter-chip row + per-tab sort/filter state

**Files:** new `lib/widgets/library_filter_chips.dart`; new `lib/providers/library/library_filters.dart` (+ codegen); tests.

1. State (Riverpod, codegen): per-tab sort enum + `downloadedOnly` bool.
   - `AlbumSort { recentlyAdded, alphabetical, year }` (default `recentlyAdded` per mockup).
   - `ArtistSort { aToZ, zToA }` (default `aToZ`).
   - `PlaylistSort { recentlyAdded, alphabetical }` (default `recentlyAdded`).
2. `LibraryFilterChips` widget: sort chip opens a bottom-sheet/menu of the enum values (chip label mirrors selection, magenta when non-default per mockup styling — active chip is filled magenta); `Downloaded` toggle chip; trailing filter `IconButton` is **decorative-only for now** (no extra filters exist) — render it but no-op with a tooltip, log to DEBT.
3. Pure client-side sorting — no new endpoints. `recentlyAdded` sorts by `Album.created` / `Playlist.changed ?? created` descending; `year` by `Album.year` descending (nulls last); alphabetical by name.

**Test gate:** provider defaults + transitions; chip row renders per tab config; sort comparators unit-tested (null year/created handling).
**Commit:** `feat(flutter): library redesign X2 — filter chips + per-tab sort/downloaded state`

### X3 — Albums tab: grid + full list section

**Files:** `lib/screens/library/library_tabs.dart` (`_AlbumsTab` rewrite); new `lib/screens/library/album_grid_card.dart`; tests.

1. Derived provider `sortedLibraryAlbumsProvider`: `libraryAlbumsProvider` (existing 500-item cache-aware fetch) → apply sort + `downloadedOnly` (filter on `markedAlbums`).
2. Body = one `CustomScrollView`:
   - Sliver 1: chip row (X2).
   - Sliver 2: 3-column `SliverGrid` of the **first 9** sorted albums — `AlbumGridCard`: `LibraryCoverArt` cover, title, artist, "N songs", pink check badge (`Icons.check_circle`, `heerrMagenta`) when in `markedAlbums`. Tap → `Routes.libraryAlbum(id)`.
   - Sliver 3: "Albums ›" section header (tappable — scrolls to the list / no-op v1).
   - Sliver 4: full sorted list — rows: 48px thumb, title, "artist • year • N songs" (omit null parts), kebab overflow reusing existing album actions (play via `playAlbumFromSubsonic`, open). Explicit badge dropped (no data).
3. Keep `EmptyState` / skeleton / `ApiError` branches from the current `_AlbumsTab`.

**Test gate:** grid caps at 9; sort chip changes order; downloaded filter; badge rendering; list subtitle formatting with null year.
**Commit:** `feat(flutter): library redesign X3 — albums grid + full list + downloaded badges`

### X4 — Alphabet index scrubber (shared widget)

**Files:** new `lib/widgets/alphabet_scrubber.dart`; wire into `_AlbumsTab` + (X5) `_ArtistsTab`; tests.

1. `AlphabetScrubber`: right-edge vertical strip `#, A–Z`; drag/tap → callback with the letter; highlights the active letter. Pure widget + a testable `letterForOffset` mapping.
2. Consumer contract: parent owns a `ScrollController` + a `Map<String, int>` of first-index-per-letter (built from the sorted list, `#` = non-alpha leading chars); scrubber jump = `controller.jumpTo`/`animateTo` to the target sliver offset (use `scrollable_positioned_list`-free approach: fixed-extent rows in the list section make offsets computable — keep row extent constant for this reason).
3. Shown only when the tab's sort is alphabetical (matches mockup: Albums shows it in A–Z contexts, Artists always since A–Z is its default).

**Test gate:** letter mapping unit tests; scrub gesture jumps list; hidden under non-alphabetical sort.
**Commit:** `feat(flutter): library redesign X4 — alphabet index scrubber`

### X5 — Artists tab: rows + Most Played Artists rail

**Files:** `library_tabs.dart` (`_ArtistsTab` rewrite); new `lib/providers/library/most_played_artists.dart`; tests.

1. Rows: circular avatar (`LibraryCoverArt` clipped in a `CircleAvatar`, `artistImageUrl` fallback per existing tile logic), name, "N albums" subtitle (decision §2.4), kebab (menu: open artist). Tap → `Routes.libraryArtist(id)`. Flatten the current `ArtistIndex` groups into one sorted list (A–Z / Z–A per chip); alphabet scrubber (X4) on the right.
2. `Downloaded` chip on this tab: filter artists whose `artistId` appears on any album in `markedAlbums` — computable by joining `libraryAlbumsProvider` albums (`artistId`) with the manifest. If join proves flaky (missing `artistId`), hide the chip on Artists and log DEBT.
3. `mostPlayedArtistsProvider`: `getAlbumList(type: 'frequent', size: 50)` → dedupe by `artistId` preserving order → `List<Artist>`-shaped view (id, name, coverArt from the album). Horizontal rail: circular art with a small gradient play-badge overlay (badge plays that artist's most-frequent album via `playAlbumFromSubsonic`; tapping the avatar opens artist detail). "See all" → artists list already on screen, so route "See all" to sort-by-most-played? **No** — v1: "See all" hidden (rail shows up to 10). Log to DEBT if wanted.

**Test gate:** flattened sorting; downloaded join; rail dedupe logic; play-badge action.
**Commit:** `feat(flutter): library redesign X5 — artist rows, downloaded filter, most played rail`

### X6 — Playlists tab: card grid + Favorites + Create Playlist + full list

**Files:** `library_tabs.dart` (`_PlaylistsTab` rewrite); new `lib/screens/library/playlist_grid_card.dart`; tests.

1. Sorted/filtered provider over `libraryPlaylistsProvider` (X2 state; downloaded = `markedPlaylists`).
2. 2-column `SliverGrid`, in order: **Favorites card** (heart icon, gradient tile or starred cover mosaic v1 = gradient tile + heart; count from `starredSongsProvider` length; tap → existing favorites route) → up to 6 playlist cards (`LibraryCoverArt` + dark gradient overlay via `DecoratedBox`, title, "by <owner>", "N songs") → **"+ Create Playlist" card** (dashed/soft border, gradient plus icon) reusing the existing `_onCreatePressed` flow (`CreatePlaylistDialog` → create → snackbar → push detail). The FAB is removed.
3. "Playlists ›" list section below: Favorites row first (heart thumb), then all playlists — thumb, title, "by <owner> • N songs", kebab (existing playlist actions). Keep the **"For You"** recommendations entry as the list tail row (unchanged behavior, `library-for-you-entry` key preserved).
4. Owner display: `Playlist.owner` verbatim; null → omit "by" segment.

**Test gate:** card order (Favorites first, Create last); create flow unchanged; downloaded filter; For You entry retained; owner-null formatting.
**Commit:** `feat(flutter): library redesign X6 — playlist cards, favorites tile, create-playlist card, full list`

### X7 — Docs, DEBT, version bump 4.10.0, on-device smoke

**Files:** `DECISIONLOG.md` (ADR: library redesign decisions §2 + dropped explicit badge), `CHANGELOG.md`, `DEBT.md` (explicit badge, filter icon no-op, artist song counts, Most-Played "See all", per-artist downloaded join if deferred), `ROADMAP.md` (X section + status line), version bump in the five locked locations (`android/app/pubspec.yaml`, `backend/pyproject.toml`, `backend/app/main.py`, both ROADMAP status lines).

**Done when:** `flutter analyze` clean; full `flutter test` green; `graphify update .` run; manual smoke on device (all three tabs, scrubber, chips, create playlist, deep link from Profile).
**Commit:** `docs(flutter): library redesign X7 — ADR, changelog, roadmap + version bump to 4.10.0`

---

## 5. Dropped / deferred (log in DEBT.md at X7)

| Item | Why |
|------|-----|
| Explicit "E" badge on album rows | No explicit flag in Subsonic `Album` model (`album.dart`) — no data source. |
| Bottom nav Search + Profile tabs | Out of scope (decision §2.1). |
| Artist song counts | Requires per-artist `getArtist` fan-out (decision §2.4). |
| Trailing filter icon behavior | No additional filters exist yet; rendered no-op. |
| "See all" on Most Played Artists | Rail capped at 10; artists list is the same screen. |
| "Year ▾" as a standalone range filter | v1 treats Year as a sort option inside the sort chip, not a separate year-range picker. |
