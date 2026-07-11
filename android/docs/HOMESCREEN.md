# HOMESCREEN.md — Home Screen redesign plan

Status: **PLANNED** (not started). Written 2026-07-11 against `main` @ `783e8fe`.
Structure: **Part A** (§4, tasks 1–8) = the mockup layout. **Part B** (§7, tasks B1–B4) = adaptive art-driven theming of the hero card + MiniPlayer. Part B depends on Part A tasks 2 and 7 having landed.
Reference mockup: `/Users/E1621/Documents/Personal/Android/Home Screen.png` (outside the repo — copy into `android/docs/assets/` if it should be versioned).

Goal: move the Home Screen away from the Spotify-clone layout (greeting AppBar + album grid + horizontal shelves) to heerr's own identity: branded header, hero **Continue Listening** card, **Quick Access** shortcut cards, and a vertical **Recently Added** list — all on the existing near-black + magenta→purple→violet gradient palette (`lib/theme.dart`).

---

## 0. Ground rules for the implementing agent

- Read `/CLAUDE.md`, `android/CLAUDE.md`, `android/docs/CONTEXT.md`, `DECISIONLOG.md`, `CHANGELOG.md` first (bootstrap order is in `android/CLAUDE.md`).
- `graphify-out/graph.json` exists at repo root — run `graphify query "<question>"` before grepping/reading unfamiliar source, and `graphify update .` after code changes.
- **TDD**: failing widget/provider test first, then implementation. `flutter test` + `flutter analyze` green before starting and before declaring each task done. Working dir for both: `android/app/`.
- No emojis in code/commits. (The 👋 in the greeting is a **UI string from the mockup** — allowed there, nowhere else.)
- All colors come from `Theme.of(context).colorScheme` / constants in `lib/theme.dart` (`heerrMagenta`, `heerrPurple`, `heerrViolet`, `heerrBlack`, `heerrGradient`). Do not introduce new hex literals except where this plan explicitly specifies one.
- Flush `docs/CHANGELOG.md` (+ `DECISIONLOG.md` where a decision is made) at the end of each task.

---

## 1. Mockup spec (top → bottom)

| # | Zone | Mockup content |
|---|------|----------------|
| 1 | Header | heerr logo mark (gradient waveform-in-bars) + wordmark "heerr" left; queue-list icon + avatar with gradient ring right |
| 2 | Search | Full-width rounded pill "Search songs, artists, albums…" with leading magnifier |
| 3 | Greeting | Small grey "Good evening," over large bold "Aashish 👋" |
| 4 | Hero card | Large rounded card, thin gradient border. Left ~45%: album art. Right: "CONTINUE LISTENING" pill badge, track title (large bold), artist (grey), decorative magenta waveform, progress slider with elapsed/total times, gradient circular play button bottom-right |
| 5 | Quick Access | Section header "Quick Access" + "Edit" text-action (magenta). Row of 4 outlined square cards: For You ★ "Made for you", Favorites ♥ "Loved songs", Offline ⬇ "183 songs", Recently Added 🕐 "New music". Neon-gradient outline icons, dark card bg, subtle border |
| 6 | Recently Added | Section header + "See all" (magenta). Vertical rows: 56px art thumb, bold title, grey artist, trailing kebab |
| 7 | Pinned bar | MiniPlayer restyled: art thumb, title/artist, magenta waveform strip, gradient circular play button on a dark card |
| 8 | Bottom nav | Home / Library / Downloads / Settings — **already matches** the app (`lib/router.dart:229`), no work |

## 2. Decisions already made (do not re-ask)

Confirmed with the user 2026-07-11:

1. **Old sections die.** `_QuickAccessGrid` (album 2×3 grid), `_JumpBackInSection`, `_MostPlayedSection`, `_RecommendationsSection` are removed from Home. Match the mockup exactly.
2. **Favorites screen gets built** in this redesign (backend support exists: `SubsonicLibraryService.getStarredSongs()` → `getStarred2.view`, `lib/services/subsonic_library_service.dart:193`).
3. **"Edit" on Quick Access is deferred.** Static 4 cards; render no Edit action. Log the deferral in `docs/DEBT.md`.
4. **MiniPlayer restyle is in scope** (final task).

## 3. Current-state map (what exists, file:line)

- Home screen: `lib/screens/home/home_screen.dart` (611 lines). Keep: `greetingForHour()` (:29), `_ProfileAvatarButton` (:109), `_HomeBody` auto-retry scaffolding (:153), `_NetworkErrorBody` (:246), `_HomeSearchBar` (:571), `RefreshIndicator` wiring (:98). Remove: everything listed in §2 item 1.
- Home providers: `lib/providers/home/home_providers.dart` — `homeRecentProvider`, `homeMostPlayedProvider`, `homeRandomSongsProvider`, `homeRecommendationsProvider`. After this redesign only a new `homeNewestProvider` is needed by Home; see task 6 for which old ones survive.
- Player state: `playerSnapshotProvider` (`lib/player/player_provider.dart:26`) streams `PlayerSnapshot { MediaItem? item, PlaybackState state; isPlaying; position }` (`lib/player/heerr_audio_handler.dart:293`). Cold-start restore (`lib/player/now_playing_persistence.dart` + `now_playing_snapshot.dart`) already reloads the last queue + position into the handler **without autoplay** — so the hero card works off `playerSnapshotProvider` alone; no direct store read needed.
- MiniPlayer: `lib/widgets/mini_player.dart` — pinned in `_ShellScaffold` (`lib/router.dart:334`), dominant-color tinted pill.
- Reusable widgets: `lib/widgets/skeleton.dart`, `empty_state.dart`, `error_snackbar.dart`, `gradient_icon.dart`, `gradient_button.dart`, `library_cover_art.dart` (cover-art-by-id rendering — check via graphify before writing a new art widget).
- Waveform drawing already exists for the Android home-screen app-widget: `lib/widget/now_playing_widget.dart` — extract/adapt rather than redraw (task 2).
- Logo assets: `assets/icon.png` (current mark), `assets/icon_legacy.png`.
- Routes: `lib/router.dart:31` `Routes` class. Recommendations screen already routed at `Routes.libraryRecommendations` = `/library/recommendations`.
- Downloads/offline count: `downloadedSongsProvider` in `lib/providers/downloaded_songs.dart` (from the offline manifest).
- Existing tests: `test/screens/home/home_screen_test.dart` — will need a substantial rewrite; keep the greeting-helper and error/retry test coverage patterns.

---

## 4. Task breakdown

Each task = one commit (Conventional Commits, e.g. `feat(flutter): home redesign part N — <thing>`). Order matters — later tasks assume earlier ones landed.

### Task 1 — Branded header + greeting block

**Files:** `lib/screens/home/home_screen.dart`, new `lib/widgets/heerr_logo.dart`, `test/screens/home/home_screen_test.dart`.

1. New widget `HeerrLogo` (`lib/widgets/heerr_logo.dart`): the logo mark + wordmark row.
   - Mark: `Image.asset('assets/icon.png', width: 32, height: 32)` inside `ClipRRect(borderRadius: 8)`. (If `icon.png` includes baked-in background padding that looks wrong at 32px, fall back to a `CustomPaint` of the waveform-bars mark — the painter already exists in `lib/widget/now_playing_widget.dart`; extract it in task 2 and reuse. Don't gold-plate: asset first.)
   - Wordmark: `Text('heerr', style: textTheme.headlineSmall.copyWith(fontWeight: FontWeight.w700))`.
2. Home `AppBar` becomes: `title: HeerrLogo()`, `centerTitle: false`, actions unchanged (`Icons.queue_music_outlined` → `Routes.queue`, then `_ProfileAvatarButton`). The greeting **leaves the AppBar**.
3. Greeting block becomes the first item of the body `ListView`, below the search bar per mockup order? **No — mockup order is search bar first, then greeting.** Body order: `_HomeSearchBar`, then new `_GreetingBlock`.
   - `_GreetingBlock`: two-line column, padding `EdgeInsets.fromLTRB(16, 16, 16, 8)`.
     - Line 1: `'${greetingForHour(DateTime.now().hour)},'` — `textTheme.bodyLarge`, color `onSurfaceVariant`.
     - Line 2: nickname from `ref.watch(profileMetaNotifierProvider).valueOrNull?.nickname` + `' \u{1F44B}'` (👋) — `textTheme.headlineMedium`, `FontWeight.w800`.
     - **No nickname set:** render line 1 without the trailing comma as the large line (single-line block); no emoji.
4. Tests: AppBar shows the logo row and no greeting text; body shows greeting lines; nickname/no-nickname branches; existing queue-shortcut and avatar tests keep passing.

### Task 2 — "Continue Listening" hero card

**Files:** new `lib/widgets/waveform_strip.dart`, new `lib/screens/home/continue_listening_card.dart`, `lib/screens/home/home_screen.dart`, new `test/screens/home/continue_listening_card_test.dart`.

1. **`WaveformStrip`** (`lib/widgets/waveform_strip.dart`): stateless decorative waveform.
   - `CustomPaint`; bars of deterministic pseudo-random heights (seed from a `seed` int param so the same track renders the same shape — pass `item.title.hashCode`). Params: `height` (default 28), `color` (default `heerrMagenta`), optional `gradient`.
   - Extract/adapt the bar-drawing from `lib/widget/now_playing_widget.dart` if compatible; otherwise a fresh ~40-line painter. **Read that file first** (graphify: `graphify query "now_playing_widget waveform painter"`).
   - Unit test: paints without error at multiple widths; deterministic for equal seeds.
2. **`ContinueListeningCard`** (`lib/screens/home/continue_listening_card.dart`), `ConsumerWidget`:
   - Watch `playerSnapshotProvider`. `item == null` (or provider loading/error — e.g. router tests without an `audioHandlerProvider` override) → `SizedBox.shrink()`. Follow the guard pattern in `lib/widgets/mini_player.dart:58-64`.
   - Layout: `Container` margin `fromLTRB(16, 8, 16, 8)`, `height ~200`, `borderRadius 24`. **Gradient border**: outer `Container` with `decoration: BoxDecoration(gradient: heerrGradient, borderRadius: 24)`, `padding: EdgeInsets.all(1.5)`, inner container `color: surfaceContainerLow`, radius `22.5`. (Same ring technique as `_ProfileAvatarButton`, `home_screen.dart:121-140`.)
   - Row: left — cover art from `item.artUri` (`Image.network`, `errorBuilder` → music-note placeholder; reuse `_CoverThumb` approach from mini_player.dart), width ≈ 40% of card, full height, clipped to the card's left radius. Right — padded column:
     - Badge: pill (`Colors.white10`, radius 999) with `'CONTINUE LISTENING'` in `labelSmall`, letter-spacing 1.2.
     - `item.title` — `titleLarge`, w700, maxLines 1, ellipsis.
     - `item.artist` — `bodyMedium`, `onSurfaceVariant`, maxLines 1.
     - `WaveformStrip(height: 24, seed: item.title.hashCode)`.
     - Progress row: thin `LinearProgressIndicator`-style bar is NOT enough — mockup has a slider look, but the hero must not be a live scrubber (keep seeking on `/player`). Render a static progress bar: `FractionallySizedBox` fill of `heerrGradient` over a `Color(0x33FFFFFF)` track, `value = position.inMilliseconds / (item.duration?.inMilliseconds ?? 1)` clamped 0..1. Under it, `Row` with `_fmt(position)` left and `_fmt(item.duration)` right in `bodySmall` grey. Position comes from `snapshot.position`; it updates on stream events (play/pause/track change), which is acceptable — **do not add a per-second ticker** on Home.
     - Play button bottom-right: 56px circle, `heerrGradient` fill, `Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.black)`. Tap → `ref.read(audioHandlerProvider).play()` / `.pause()` (mirror `_PlayPauseButton`, mini_player.dart:175).
   - Card tap (outside the button) → `context.push('/player')`.
3. Insert into the Home body after `_GreetingBlock`.
4. Tests (override `playerSnapshotProvider` with a controlled stream, same pattern as existing mini-player tests — find them via `graphify query "mini player test playerSnapshotProvider override"`): hidden when no item; renders title/artist/badge; play button toggles via a recorded fake handler; card tap pushes `/player`; duration `null` doesn't divide-by-zero.

### Task 3 — Quick Access row

**Files:** new `lib/screens/home/quick_access_row.dart`, `lib/screens/home/home_screen.dart`, `lib/router.dart` (only if a route constant is missing), new `test/screens/home/quick_access_row_test.dart`.

1. `QuickAccessCard` (private to the file): fixed-size card ~150×110, `surfaceContainerLow` bg, radius 16, `Border.all(color: outline)` (`#2E2E2E` from theme). Content column, left-aligned: outlined icon 28px wrapped in `GradientIcon` (`lib/widgets/gradient_icon.dart`) for the neon look, title `titleSmall` w600, subtitle `bodySmall` `onSurfaceVariant`.
2. `QuickAccessRow`: section header `'Quick Access'` (`titleLarge`, padding 16) — **no Edit action** (deferred, §2). Below: horizontally scrollable `SingleChildScrollView`/`ListView` of the 4 cards, 12px gaps, 16px edge padding (4 cards won't fit a narrow phone width at readable size — horizontal scroll, like the mockup's edge-cropped 4th card).
3. The 4 cards:
   | Card | Icon | Subtitle | Tap target |
   |---|---|---|---|
   | For You | `Icons.star_outline` | `'Made for you'` | `context.push(Routes.libraryRecommendations)` |
   | Favorites | `Icons.favorite_outline` | `'Loved songs'` | `context.push(Routes.libraryFavorites)` (route lands in task 5 — stub the constant now, screen in task 5; or reorder: implement task 5 first if the agent prefers — either order is fine, just note it) |
   | Offline | `Icons.download_outlined` | live count: `'N songs'` from `ref.watch(downloadedSongsProvider)` (`lib/providers/downloaded_songs.dart`); while loading/error show `'Downloads'` | `context.go(Routes.downloads)` |
   | Recently Added | `Icons.schedule_outlined` | `'New music'` | `context.push(Routes.libraryRecentlyAdded)` (screen lands in task 4) |
4. Tests: 4 cards render with correct labels; offline subtitle reflects an overridden `downloadedSongsProvider`; each tap navigates to the right route (use the real `buildHeerrRouter` or a `MockGoRouter` — follow whatever pattern `home_screen_test.dart` already uses).

### Task 4 — Recently Added section + See-all screen

**Files:** `lib/providers/home/home_providers.dart`, new `lib/screens/home/recently_added_section.dart`, new `lib/screens/library/recently_added_screen.dart`, `lib/router.dart`, tests for each.

1. Provider: in `home_providers.dart` add
   ```dart
   @riverpod
   Future<List<Album>> homeNewest(HomeNewestRef ref) async {
     final service = await ref.watch(subsonicLibraryServiceProvider.future);
     return service.getAlbumList(type: 'newest', size: 8);
   }
   ```
   Run codegen: `dart run build_runner build --delete-conflicting-outputs` (wd: `android/app/`). Verify `'newest'` is a valid `getAlbumList2` type against the service (`lib/services/subsonic_library_service.dart:61` — it takes `type` as a string passthrough; Subsonic API defines `newest` = recently **added**, which is exactly what we want, vs `recent` = recently played).
2. `RecentlyAddedSection` (`lib/screens/home/recently_added_section.dart`): header row `'Recently Added'` + `TextButton('See all')` (theme already makes TextButtons magenta) → `context.push(Routes.libraryRecentlyAdded)`. Below: **non-scrolling column** of the first 5 albums (vertical rows inside the parent `ListView` — no nested scrollable). Row: 56px cover (reuse `lib/widgets/library_cover_art.dart` — check its API via graphify first), title `titleMedium` w600, artist `bodyMedium` grey, tap → `context.push(Routes.libraryAlbum(a.id))`. **Kebab menu: omit** (defer with a `DEBT.md` note — the mockup shows one, but album row actions don't exist as a sheet yet; row tap → album detail covers the need).
   - Loading → `SkeletonList`/`SkeletonTile`s (`lib/widgets/skeleton.dart`); error → `SizedBox.shrink()`; empty → `SizedBox.shrink()` (the full-empty-library case is handled by the screen-level empty state, task 6).
3. `RecentlyAddedScreen` (`lib/screens/library/recently_added_screen.dart`): plain scaffold + AppBar `'Recently Added'`, full list from a size-50 fetch (either a `.family` variant or a second provider `recentlyAddedFullProvider(size: 50)`), same row widget, pull-to-refresh via `ref.invalidate`.
4. Routes: add to `Routes` — `static const String libraryRecentlyAdded = '/library/recently-added';` and register a nested `GoRoute(path: 'recently-added', …)` under the `/library` route (`lib/router.dart:118`) so the Library tab stays selected (`_indexFor` uses `startsWith(Routes.library)`, router.dart:294).
5. Tests: section renders rows from an overridden `homeNewestProvider`; See-all navigates; screen lists albums and refreshes.

### Task 5 — Favorites screen

**Files:** new `lib/providers/library/starred_songs.dart`, new `lib/screens/library/favorites_screen.dart`, `lib/router.dart`, tests.

1. Provider `starredSongsProvider`: `@riverpod Future<List<Song>>` calling `service.getStarredSongs()` (`lib/services/subsonic_library_service.dart:194`). Codegen again.
2. Route: `Routes.libraryFavorites = '/library/favorites'`, nested under `/library` like task 4.
3. `FavoritesScreen`: AppBar `'Favorites'`; body states — loading `SkeletonList`, error → `reactToApiError` pattern + retry (copy an existing library screen's error handling; find one via `graphify query "library screen error retry pattern"`), empty → `EmptyState(icon: Icons.favorite_outline, title: 'No favorites yet', subtitle: 'Star songs to collect them here.')`, data → song rows. **Reuse the existing song-row + actions widgets** (`lib/widgets/song_row_actions.dart`, and whatever row widget the playlist-detail screen uses — check first) so play/queue behavior is consistent; tapping a row should play it via the same `playback_actions.dart` path other song lists use. Do not invent a new playback entry point.
4. Tests: three states render; tap plays through a faked handler/actions seam consistent with existing playlist-screen tests.

### Task 6 — Home body assembly, cleanup, error/empty rewiring

**Files:** `lib/screens/home/home_screen.dart`, `lib/providers/home/home_providers.dart`, possibly-dead widgets, `test/screens/home/home_screen_test.dart`, `docs/DEBT.md`.

1. Final body `ListView` (order): `_HomeSearchBar` → `_GreetingBlock` → `ContinueListeningCard` → `QuickAccessRow` → `RecentlyAddedSection`. Keep `AlwaysScrollableScrollPhysics` + bottom padding 24 + the `RefreshIndicator`.
2. `_refresh` / `_invalidateAll` now invalidate: `homeNewestProvider` + `downloadedSongsProvider`? **No** — offline count is local disk, not network; invalidate only `homeNewestProvider`. Await `ref.read(homeNewestProvider.future).catchError(...)` as the spinner anchor.
3. Auto-retry (`_HomeBodyState`): canonical network signal switches from `homeRecentProvider` to `homeNewestProvider`. "All failed" collapses to just `homeNewest.hasError` (it's the only network-bound Home section now — hero is player-local, Quick Access is static/local). Keep `_NetworkErrorBody` verbatim.
4. Empty library (newest returns `[]` **and** player has nothing): show the existing `EmptyState` copy ("Nothing here yet … Play some music or download a track…") in place of `RecentlyAddedSection`.
5. Remove now-dead code: `_QuickAccessGrid`, `_RecommendationGridFallback`, `_JumpBackInSection`, `_MostPlayedSection`, `_RecommendationsSection` from `home_screen.dart`; the `initState` `refreshIfStale()` call (recommendations no longer render on Home — the Recommendations screen manages its own freshness; **verify that before deleting**, `graphify query "refreshIfStale recommendations screen"`); providers `homeRecentProvider`, `homeMostPlayedProvider`, `homeRandomSongsProvider`, `homeRecommendationsProvider` **only if** nothing else imports them (check with graphify/`flutter analyze` — `homeRandomSongs`/`homeRecommendations` may be referenced by the recommendations flow); widgets `home_grid_tile.dart`, `home_section.dart`, `home_recommendation_card.dart` only if unreferenced (`home_recommendation_card` is likely used by `recommendations_screen.dart` — keep it there).
6. Rewrite `test/screens/home/home_screen_test.dart` for the new body; preserve `greetingForHour` unit tests and the error/auto-retry tests (retimed to `homeNewestProvider`).
7. `docs/DEBT.md`: add entries — "Quick Access Edit/reorder deferred", "Recently-Added row kebab actions deferred".

### Task 7 — MiniPlayer restyle

**Files:** `lib/widgets/mini_player.dart`, its test.

Match mockup zone 7 while keeping all behavior (visibility rules, tap→`/player`, play/pause, preview badge):
1. Background: drop the dominant-color-tinted **background** → `surfaceContainerHigh` card, radius 16, thin gradient border (same 1.5px technique as the hero card). **Do NOT delete the palette extraction infrastructure** (`utils/palette.dart` / `dominantColorFor`, the `miniPlayerPaletteExtractorOverride` test seam) — Part B (task B1) promotes it to a shared cached provider and re-applies it as an accent tint. If Part B is being implemented in the same run, skip the interim flat background and go straight to the B3 spec.
2. Row: 44px rounded art thumb → title (w600) + artist/preview-badge line → `WaveformStrip(height: 20, width ~90, seed: item.title.hashCode)` (hide below ~360dp available width via `LayoutBuilder` to protect small screens) → 40px gradient-circle play/pause button (black icon), replacing the plain `IconButton`.
3. Height 64 (up from 56). Keep the `FractionallySizedBox(0.99)` float or switch to 16px side margins to match the new card language — implementer's call, note it in CHANGELOG.
4. Update `test/widgets/mini_player_test.dart` (locate actual path first): visibility rules, play/pause toggle, tap-through, preview badge all still covered; palette-seam tests deleted.

### Task 8 — Final gates + docs flush

1. `flutter analyze` and `flutter test` fully green (wd `android/app/`).
2. Manual smoke on the Pixel 7 (wireless adb): cold start with a restored queue → hero card shows last track and resumes on tap; empty-library profile → empty state; Tailscale off → network-error body + auto-retry.
3. `graphify update .` at repo root.
4. Docs: one consolidated `android/docs/CHANGELOG.md` entry per task-commit (or one per commit as they land); `DECISIONLOG.md` entry "2026-07-XX — Home Screen redesign (own identity)" recording: mockup-driven layout, old sections dropped, Favorites screen added, Edit + kebab deferred, MiniPlayer restyled; update `CONTEXT.md` "Screens" list (add Favorites + Recently Added; describe the new Home composition).
5. **No version bump** unless this ships as a release; if bumping, follow `/CLAUDE.md` §3 version-sync (all five files, one commit).

---

## 5. Explicit assumptions (flag to the user if any prove false)

- `assets/icon.png` renders acceptably as the 32px header mark. (Fallback: extracted waveform painter.)
- Subsonic `getAlbumList2 type=newest` returns recently-**added** albums on Navidrome (standard Subsonic semantics) — verify with one curl against the home server or a unit-level check before building the screen on top of it.
- `playerSnapshotProvider` emits the restored (paused) item on cold start, so the hero card populates without touching `NowPlayingStore` directly. Inferred from `now_playing_snapshot.dart:8-13` docs; verify on-device in task 8.
- The hero card's static (event-driven, not ticking) progress display is acceptable UX. Live scrubbing stays on `/player`.

## 6. Out of scope (do not build)

- Quick Access Edit/reorder/persistence (deferred → DEBT).
- Kebab action sheet on Recently-Added rows (deferred → DEBT).
- Any change to bottom nav, Library, Downloads, Settings, Now Playing screens. (Part B touches only the hero card + MiniPlayer; the `/player` screen's own art treatment is a separate future task.)
- Light theme, tablets, iOS — per standing project rules.
- **Recoloring album artwork itself** — explicitly rejected (see §7 preamble). The art always renders original; only the surrounding chrome adapts.

---

## 7. Part B — adaptive art-driven theming (hero card + MiniPlayer)

Added 2026-07-11 after user review. The mockup's hero card shows the Starboy art recolored magenta/purple to sit inside the heerr palette — that was mockup-only illustration. **Decision: never modify the artwork.** Instead the chrome around it adapts per-song: extract the art's dominant color, blend it toward the brand palette, use a blurred copy of the art as the card backdrop under a darkening gradient, and animate transitions between songs. (Rationale: users recognize their covers; recolored art reads as a bug. Same conclusion as the user's external recommendation — options "blur + gradient" + "brand tint" combined.)

Design constants (single source of truth — put them in `lib/utils/palette.dart`):
- `kBrandBlend = 0.18` — fraction to lerp the extracted color toward `heerrMagenta`.
- `kArtBackdropBlur = 24.0` — sigma for the blurred backdrop.
- `kTintTransition = Duration(milliseconds: 400)` — color animation on track change.

### Task B1 — shared cached palette provider

**Files:** `lib/utils/palette.dart`, new `lib/providers/player/art_palette.dart`, `lib/widgets/mini_player.dart`, new `test/providers/player/art_palette_test.dart`.

1. Read `lib/utils/palette.dart` first (`graphify query "dominantColorFor palette_generator"`). Today each consumer (MiniPlayer) calls `dominantColorFor(artUri)` ad-hoc with its own stale-guard state (`mini_player.dart:42-54`).
2. New provider:
   ```dart
   @riverpod
   Future<Color?> artPalette(ArtPaletteRef ref, String artUri) => ...
   ```
   Family keyed by the art URI string; calls `dominantColorFor`. Riverpod caches per-key automatically — add `ref.keepAlive()` (or `@Riverpod(keepAlive: true)`) so re-visits don't re-extract; palette extraction decodes the whole image and is the expensive step, so cache-per-URI is the performance contract. Keep a test seam analogous to the existing `miniPlayerPaletteExtractorOverride` — a `dominantColorForOverride` at module scope in `palette.dart`, and migrate the MiniPlayer seam onto it (update its tests).
3. Add `Color brandBlend(Color extracted)` in `palette.dart`: `Color.lerp(extracted, heerrMagenta, kBrandBlend)!`. Unit tests: known input → expected lerp output; null-safety at the callsites (extraction failure → fall back to `heerrPurple`, matching current MiniPlayer behavior at `mini_player.dart:67`).
4. Nothing visual changes in this task — it's the plumbing commit. MiniPlayer switches to `ref.watch(artPaletteProvider(uri))` internally with identical rendered output (the stale-response guard becomes unnecessary — provider families key by URI, so a late completion for an old URI can't clobber the new one; delete `_maybeRefreshTint`).

### Task B2 — hero card adaptive backdrop + accents

**Files:** `lib/screens/home/continue_listening_card.dart`, its test.

Replaces the Task 2 flat `surfaceContainerLow` inner background:
1. **Backdrop:** inside the card's inner container, a `Stack`:
   - Layer 1: the album art stretched to fill the whole card, blurred — `ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: kArtBackdropBlur, sigmaY: kArtBackdropBlur), child: Image.network(artUri, fit: BoxFit.cover))`. Use `ImageFiltered` on the image, **not** `BackdropFilter` (BackdropFilter blurs everything beneath it in the saveLayer and is the more expensive path; we only need the image itself blurred).
   - Layer 2: darkening gradient so text passes contrast — `LinearGradient` left→right: `Colors.black.withValues(alpha: 0.35)` → `heerrBlack.withValues(alpha: 0.88)`. Left stays lighter (the sharp art sits there anyway), right goes near-black under the text column.
   - Layer 3: the existing Task-2 content row (sharp art left, text/waveform/progress/button right) unchanged.
2. **Accents:** watch `artPaletteProvider(item.artUri.toString())`; `tint = brandBlend(extracted ?? heerrPurple)`.
   - `WaveformStrip(color: tint)`.
   - Progress bar fill: keep `heerrGradient` (brand anchor — don't tint everything or the identity washes out).
   - Play button: keep the gradient fill, add glow `BoxShadow(color: tint.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 2)`.
   - Sharp-art container: same glow at `alpha: 0.25` (the mockup's neon-ring feel without touching pixels).
3. **Animation:** wrap tint consumers in `TweenAnimationBuilder<Color?>(tween: ColorTween(end: tint), duration: kTintTransition)` (or `AnimatedContainer` where it's a decoration) so track changes cross-fade the accent color instead of snapping. While the palette future for a new URI is unresolved, keep showing the previous tint (`AsyncValue.valueOrNull` + last-known-value pattern) — no flash to fallback purple mid-transition.
4. Tests: with `dominantColorForOverride` returning a fixed color, assert the waveform/glow use `brandBlend(fixed)`; extraction-failure path falls back to `heerrPurple`; blurred backdrop layer exists (`find.byType(ImageFiltered)`); no per-frame palette re-extraction (override counts invocations — exactly one per unique URI).

### Task B3 — MiniPlayer adaptive accents

**Files:** `lib/widgets/mini_player.dart`, its test.

On top of the Task 7 restyle (dark card, gradient border, waveform, gradient play circle):
1. `tint = brandBlend(extracted)` from `artPaletteProvider` — applied to `WaveformStrip(color: tint)` and a soft `BoxShadow(color: tint.withValues(alpha: 0.25), blurRadius: 16)` on the play circle. Background **stays** `surfaceContainerHigh` — no blurred backdrop here; at 64px tall it would just look muddy and costs a blur per frame over scrolling content.
2. Same `TweenAnimationBuilder` cross-fade as B2 on track change.
3. Tests: tint plumbing via the override seam; fallback color; visibility/behavior suite from Task 7 still green.

### Task B4 — Part B gates + docs

1. `flutter analyze` + `flutter test` green; `graphify update .`.
2. On-device smoke (Pixel 7): scroll Home while a track with art plays — no jank from the blur (if the blurred hero backdrop drops frames, wrap it in `RepaintBoundary` first, and only if still janky downsample: decode the backdrop copy at `cacheWidth: 200`); rapid next/next/next track skips — tint animates, never flashes, no stale tint from a slow extraction.
3. `DECISIONLOG.md` entry: "adapt chrome around original art; never recolor artwork" with the rejected alternative (mockup-style recolored covers). `CHANGELOG.md` per commit. `CONTEXT.md` aesthetic paragraph gains one line about per-song adaptive tinting.

### Part B assumptions

- `palette_generator` is already in `pubspec.yaml` (it powers today's MiniPlayer tint — verify, don't re-add).
- Blur of a single ~card-sized image is cheap on the Pixel 7 (Impeller). Verified in B4; `cacheWidth` downsample is the escape hatch.
- `MediaItem.artUri` is a stable cache key per track (it carries the Subsonic cover-art URL; if it embeds a rotating auth salt the palette cache would miss on every process restart — acceptable — but confirm it's stable *within* a session, else key by `item.id`/cover-art id instead).
