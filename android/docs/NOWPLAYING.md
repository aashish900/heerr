# NOWPLAYING.md — Now Playing screen redesign plan

Status: **IMPLEMENTED** 2026-07-11 (NP1–NP10, v4.11.0). NP10 shipped in reduced scope — see DECISIONLOG 2026-07-11.
Reference mockup: `/Users/E1621/Documents/Personal/Android/Now Playing.png` (single-panel image: Starboy / The Weeknd). Consider copying to `android/docs/assets/now-playing.png` to version it.
Milestone prefix: **NP** (NP1–NP10) — A–Z letters are exhausted (X went to the Library redesign), so this phase uses a two-letter prefix.

Goal: move the Now Playing screen from the vertical-tint-gradient + Material `Slider` layout to the branded design: blurred-artwork immersive background, glowing hero artwork with floating glass actions, waveform seek bar, restyled transport, a glass action pill (Queue / Lyrics / Timer / More), a draggable lyrics peek sheet, and a restyled queue sheet. Stretch: the "swipe art up → lyrics take over" shared-element signature interaction.

---

## 0. Ground rules for the implementing agent

- Bootstrap first: `/CLAUDE.md`, `android/CLAUDE.md`, `android/docs/CONTEXT.md`, `DECISIONLOG.md`, `CHANGELOG.md`.
- `graphify-out/graph.json` exists — `graphify query "<question>"` before reading unfamiliar source; `graphify update .` after code changes.
- **TDD:** failing widget/provider test first. `flutter test` + `flutter analyze` green before starting and before declaring each task done. Working dir: `android/app/`.
- **Colors:** the brief's hex values (#FF4D9D / #C23EFF / #7A4DFF) are **not** adopted. The app's locked brand palette stays: `heerrMagenta #F533C8`, `heerrPurple #A93CF2`, `heerrViolet #6F4BF5`, `heerrGradient` (`lib/theme.dart:5-11`). No new hex literals unless specified here. Never green.
- Artwork is never recolored — only surrounding chrome (DECISIONLOG 2026-07-11, Home redesign Part B). Reuse `brandBlend()` / `kTintTransition` from `lib/utils/palette.dart`.
- Preserve every existing behavior contract: queue-polling pause/resume on screen enter/leave, scrub-override seek pattern, preview-badge branch, sleep-timer chip + sheet, add-to-playlist path, test seams (`paletteExtractorOverride`), and all existing `Key(...)` handles used by tests (rename only together with the tests).
- Motion: every animation must respect `MediaQuery.disableAnimations` / reduced-motion; widget tests must not depend on infinite animations (gate repeating controllers behind a flag the test can disable, same approach as `WaveformStrip.animate`).
- Flush `docs/CHANGELOG.md` (+ `DECISIONLOG.md` for decisions) at the end of each task.
- One commit per task: `feat(flutter): now playing redesign NP<n> — <thing>`.

---

## 1. Mockup spec (top → bottom)

| # | Zone | Content |
|---|------|---------|
| 1 | Header | Chevron-down collapse (left, circular glass), "PLAYING FROM / Favorites ›" two-line center label, volume/output icon + kebab (right, circular glass) |
| 2 | Hero artwork | Large square, ~28dp radius, hairline light border, soft neon glow in extracted colors, floating circular glass **download** button top-right on the art |
| 3 | Title block | "Starboy" (large, bold, left) / "The Weeknd, Daft Punk" (grey, smaller); circular glass **heart** button on the right |
| 4 | Waveform seek bar | Full-width waveform in magenta→violet gradient; played portion overlaid with a thin white line + glowing round thumb; elapsed / total times below the ends; "Dolby Atmos" badge centered (dropped — §2.6) |
| 5 | Transport | shuffle · prev · big gradient circular pause/play · next · repeat; side icons outlined/minimal, shuffle+repeat magenta when active |
| 6 | Action pill | Rounded-rect glass container: Queue / Lyrics / Equalizer / Timer / More — icon + tiny label each, thin dividers; drag handle below |
| 7 | Lyrics peek sheet | Rounded glass sheet docked at bottom: "LYRICS / RELATED" tabs (RELATED dropped — §2.5), expand icon, ~4 synced lines with active line large + white and a magenta highlight span, quote + share round buttons |
| 8 | Background | Blurred, heavily darkened artwork with magenta/red highlights bleeding through, soft vignette; animates between songs |

---

## 2. Open decisions — confirm before implementing

Nothing in this section is confirmed yet. Each has a stated assumption; review and override before NP1 starts.

1. **"PLAYING FROM <context>"** — the player has no play-source context today (`MediaItem.extras` carries `subsonicId` etc., not the originating album/playlist). **Assumption:** NP2 adds a `playContext` string to the queue-set path (`playback_actions.dart` callers already know the source: album title / playlist name / "Search" / "Recommendations") carried in `MediaItem.extras['playContext']`; falls back to the static "NOW PLAYING" label when absent. Tapping it navigates to the source route when a route is also carried. Alternative: keep the static label and drop the feature (cheapest).
2. **Equalizer action** — the app has no equalizer. **Assumption:** the pill slot fires the system EQ via `android.media.action.DISPLAY_AUDIO_EFFECT_CONTROL_PANEL` intent (needs the `just_audio` `androidAudioSessionId`); if the device has no EQ activity, show a snackbar. Alternative: drop the slot (4-item pill: Queue / Lyrics / Timer / More).
3. **Volume/output icon (header right)** — currently a disabled `speaker_outlined` placeholder lives in `_BottomActionsRow`. **Assumption:** move it to the header as a disabled placeholder (visual parity with mockup, still no-op) and delete `_BottomActionsRow`. Cast/output routing remains out of scope.
4. **Download button on the artwork** — per-song offline download exists (`offline_marker.dart` song entries, `widgets/download_icon.dart`). **Assumption:** the glass button marks/unmarks the current song for offline, mirroring the state icons used in `song_row_actions.dart`, hidden for preview items.
5. **"RELATED" tab in the lyrics sheet** — no data source for related-to-this-track rows in-place. **Assumption:** dropped from the collapsed peek sheet; "Find similar" already exists via the overflow → Add-to-playlist sheet seed path. Alternative: a second tab that sets `manualSeedProvider` and pushes `/library/recommendations`.
6. **"Dolby Atmos" badge** — no data source. **Dropped**, not an open decision, listed for completeness.
7. **Quote / share buttons on lyrics** — share = `share_plus`-style intent of the current line? **Assumption:** dropped in v1 (no `share_plus` dependency today; adding a dep for a decorative affordance isn't justified). Log to DEBT.
8. **NP10 signature interaction (swipe-up art → docked mini art + full lyrics)** — highest-effort, highest-risk task. **Assumption:** in scope but last, and shippable separately; the release does not block on it.

---

## 3. Current-state map (file:line facts)

- Screen: `lib/screens/player/now_playing_screen.dart` (452 lines) + part files `now_playing_transport.dart` (358), `now_playing_lyrics.dart` (509), `now_playing_sleep_timer.dart`. Routed top-level full-screen at `/player` (`lib/router.dart:214-218`).
- State pattern: `_NowPlayingScreenState` owns a 250 ms `setState` ticker, a `_scrubOverride` for in-drag seek preview, queue-polling pause/resume (`queueProvider.notifier.pause()/resume()` on init/dispose), and per-art tint refresh via `paletteExtractorOverride` (test seam, `now_playing_screen.dart:33-36`).
- Background: `_TintedBackground` (`now_playing_screen.dart:215`) — vertical `LinearGradient` from the dominant color to `cs.surface`. No blur, no artwork in the backdrop.
- Artwork: `_WideCoverArt` (`now_playing_screen.dart:416`) — 12dp radius `Image.network`, no glow/border/actions.
- Seek: `_Scrubber` + `_GradientSliderTrackShape` (`now_playing_transport.dart:3,76`) — Material `Slider`, gradient active track.
- Transport: `_Transport` (`now_playing_transport.dart:144`) — gradient play circle already matches the mockup's centerpiece; shuffle/repeat are bundled SVGs (`assets/icons/shuffle.svg`, `repeat.svg`, `repeat_one.svg`) via `_transportGlyph` + `GradientIcon`.
- Bottom row: `_BottomActionsRow` (`now_playing_transport.dart:252`) — disabled speaker placeholder + queue button.
- Queue sheet: `_QueueList` (`now_playing_transport.dart:281`) — `ReorderableListView` + `Dismissible`; reorder and swipe-to-remove **already work**. Presented via `_openQueueSheet` as a 70 %-height modal sheet.
- Lyrics: `_LyricsSection` card → `_ExpandedLyricsSheet` full-screen modal (`now_playing_lyrics.dart:7,338`); synced highlighting via `activeLyricsIndex` (`:243`), preview window `_SyncedLyricsPreview` (5 lines), data via `lyricsForProvider` (`lib/providers/library/lyrics.dart`, Subsonic `getLyrics` + LRCLib fallback in `lib/services/lyrics_service.dart`).
- Sleep timer: `sleepTimerNotifierProvider` + `_SleepCountdownChip` + `_SleepTimerSheet` (`now_playing_sleep_timer.dart`).
- Favourite: `_FavouriteButton` (`now_playing_screen.dart:183`) via `playlistMutationsProvider.toggleFavourite` — heart is currently `Colors.redAccent`, inline next to the title.
- Palette: `lib/utils/palette.dart` — `dominantColorFor` (vibrant-first extraction), `brandBlend()` (18 % toward magenta), `kTintTransition` (400 ms), `dominantColorForOverride` test seam; `artPaletteProvider` caches per URI (used by Home hero + MiniPlayer).
- Waveform: `lib/widgets/waveform_strip.dart` — deterministic-per-seed bars, optional `animate` breathing, optional `gradient` shader. Explicitly *not* a progress indicator today.
- Player plumbing: `playerSnapshotProvider` / `playerQueueProvider` / `currentMediaItemProvider` / `audioHandlerProvider` (`lib/player/player_provider.dart`); `HeerrAudioHandler` exposes `seek`, `moveQueueItem`, `removeQueueItemAt`, `skipToQueueItem`, shuffle/repeat modes.
- Offline per-song: `lib/offline/offline_marker.dart` (song-level entries, `deleteSongLocally`), `lib/widgets/download_icon.dart`, `lib/widgets/song_row_actions.dart` (existing per-song download affordances to mirror).
- Glass/gradient building blocks from prior redesigns: `GradientIcon`, `gradient_button.dart`, `profile_avatar_ring.dart`, `animated_tint.dart`, `branded_header.dart`.
- Existing tests: `test/screens/player/` (`now_playing_lyrics_toggle_test.dart`, `now_playing_add_to_playlist_test.dart`, + transport/scrubber coverage) — they pin the `Key(...)` handles listed above; keep keys stable or update tests in the same task.

---

## 4. Task breakdown

### NP1 — Immersive blurred-art background

**Files:** new `lib/screens/player/now_playing_background.dart` (part file or standalone widget); `now_playing_screen.dart` (replace `_TintedBackground`); tests.

1. New `NowPlayingBackground(artUri, tint, child)`: stack of
   - the artwork rendered full-bleed through `ImageFiltered` (`ImageFilter.blur`, sigma ~40) — decode small (`cacheWidth` ~64) so the blur is cheap;
   - a black scrim (`Colors.black` at ~0.72 alpha) so content always reads;
   - a radial vignette (`RadialGradient`, transparent center → black edges);
   - a very soft `brandBlend(tint)` glow layer so covers with weak color still "feel heerr".
2. Cross-fade the whole backdrop on track change with `AnimatedSwitcher(duration: kTintTransition)` keyed on the art URI (same 400 ms contract as the Home hero).
3. Keep the existing `_maybeRefreshTint` / `paletteExtractorOverride` flow — the tint still feeds glows, lyrics highlight, and thumb glow downstream.
4. Null art → plain `cs.surface` (current fallback behavior).

**Test gate:** backdrop renders scrim+vignette layers with and without art; switcher keys change with the art URI; null-art fallback; existing screen tests stay green.
**Commit:** `feat(flutter): now playing redesign NP1 — blurred-art immersive background`

### NP2 — Header: collapse chevron, "Playing from" label, output icon

**Files:** `now_playing_screen.dart` (`_Header` rewrite); `lib/player/playback_actions.dart` + `song_to_media_item.dart` (only if decision §2.1 lands as "carry playContext"); tests.

1. Circular glass buttons (reusable `_GlassIconButton`: `BoxDecoration` circle, `Colors.white` at ~6 % fill, hairline `white24` border — extract to `lib/widgets/glass_icon_button.dart` since NP3/NP4 reuse it): chevron-down (pops the route) left; output icon (§2.3) + existing overflow kebab right.
2. Center label: "PLAYING FROM" (`labelSmall`, letter-spaced, grey) over the context name (magenta, with ›) per §2.1; static "NOW PLAYING" fallback preserved (existing tests reference the header).
3. Sleep-countdown chip and overflow menu (add-to-playlist, sleep timer) keep their current keys and behavior.

**Test gate:** chevron pops; label falls back correctly; overflow + sleep chip behavior unchanged.
**Commit:** `feat(flutter): now playing redesign NP2 — glass header + playing-from context`

### NP3 — Hero artwork: 28dp radius, glow, float, on-art download

**Files:** `now_playing_screen.dart` (`_WideCoverArt` rewrite → `_HeroArt`); tests.

1. Restyle: `BorderRadius.circular(28)`, hairline `white24` border, two `BoxShadow`s from `brandBlend(tint)` (a tight bright one + a wide soft one) for the neon glow; glow color animates with `AnimatedContainer`/`TweenAnimationBuilder` over `kTintTransition`.
2. Subtle float: a slow (~6 s) repeating vertical translation of ±3 px via an `AnimationController` — disabled under reduced-motion and behind a `bool animate` parameter (default true, tests pass false).
3. Floating glass download button top-right on the art (§2.4): reflects the song's offline state (not-downloaded / downloading / done) mirroring `song_row_actions.dart` semantics; hidden for preview items (`isPreviewMediaItem`).
4. Keep the null-art placeholder branch.

**Test gate:** radius/border/badge render; download button toggles marker state via a fake; hidden on preview; placeholder branch.
**Commit:** `feat(flutter): now playing redesign NP3 — hero art glow, float, on-art download`

### NP4 — Title block + glass favourite

**Files:** `now_playing_screen.dart` (title `Row` + `_FavouriteButton` restyle); tests.

1. Title `headlineMedium`/w800 (bigger than today's `titleLarge`), artist `bodyLarge` grey; left-aligned, generous spacing.
2. `_FavouriteButton` becomes a circular glass button; filled heart in `heerrMagenta` when favourited (replaces `Colors.redAccent` — brand consistency), outline white when not. Toggle path (`playlistMutationsProvider.toggleFavourite` + `showApiError`) unchanged.
3. Preview badge branch unchanged.

**Test gate:** favourite toggle still fires + snackbars on `ApiError`; magenta-filled vs outline states.
**Commit:** `feat(flutter): now playing redesign NP4 — title hierarchy + glass favourite`

### NP5 — Waveform seek bar (replaces the Slider)

**Files:** new `lib/widgets/waveform_seek_bar.dart`; `now_playing_transport.dart` (`_Scrubber` rewrite to wrap it); `waveform_strip.dart` (extract/shared bar-sequence helper if useful); tests.

1. New `WaveformSeekBar`: a `CustomPaint` of deterministic bars (reuse `WaveformStrip`'s seeded generator — seed on `item.title.hashCode` so a track always has the same shape), painted with `heerrGradient`; bars left of the playhead at full alpha, right of it dimmed (~0.35); thin 2 px white progress line along the baseline of the played portion; glowing round thumb (`heerrMagenta` core + soft glow) at the playhead.
2. Gestures: `GestureDetector` tap-down + horizontal drag → position fraction → `onSeekStart/Update/End` — plumb into the **existing** `_scrubOverride` pattern verbatim (drag previews position; release calls `audioHandler.seek`). Semantics: expose as a slider (`Semantics(slider: true, value/increase/decrease)`) since we lose Material `Slider`'s a11y for free.
3. `animate` bar-breathing only while `snapshot.isPlaying` (same look as the MiniPlayer equalizer), off under reduced-motion/tests.
4. Elapsed / total labels below the ends (keep `_fmt`). Zero/unknown duration → gestures disabled (current `max <= 0` contract).
5. Delete `_GradientSliderTrackShape` once nothing references it.

**Test gate:** drag emits monotonic seek updates + final seek; tap seeks; zero-duration disables; painted-fraction golden-free assertions via the painter's exposed state; a11y slider semantics present.
**Commit:** `feat(flutter): now playing redesign NP5 — waveform seek bar`

### NP6 — Transport restyle

**Files:** `now_playing_transport.dart` (`_Transport`); tests.

1. Keep all handler wiring, keys, and the mode-cycling logic — this task is visual only.
2. Play circle: slightly larger (~72 dp), soft `heerrMagenta` glow shadow, animated scale-on-tap (~0.92, 100 ms) on every transport button (shared `_TapScale` wrapper; skipped under reduced motion).
3. Prev/next: outlined rounded glyphs, white, 36 dp; shuffle/repeat SVG glyph treatment unchanged (already matches the mockup).
4. Delete `_BottomActionsRow` (queue moves to NP7's pill; speaker moved in NP2).

**Test gate:** all five buttons still dispatch the same handler calls; existing shuffle/repeat mode-cycle tests green.
**Commit:** `feat(flutter): now playing redesign NP6 — transport polish + tap scale`

### NP7 — Glass action pill (Queue / Lyrics / Equalizer / Timer / More)

**Files:** new `lib/screens/player/now_playing_action_pill.dart` (part file); `now_playing_screen.dart` (body wiring); tests.

1. Rounded-rect (`radius 28`) glass container, five equal slots with thin `white12` dividers: icon (outlined, thin) over a tiny `labelSmall` caption.
   - **Queue** → existing `_openQueueSheet` (key `now-playing-queue-button` moves here).
   - **Lyrics** → scrolls/expands the lyrics sheet (opens `_ExpandedLyricsSheet` — same action as today's expand icon).
   - **Equalizer** → §2.2 resolution (system-EQ intent or dropped slot).
   - **Timer** → existing `_openSleepTimerSheet`; slot shows the countdown (reuses `_SleepCountdownChip` content) when a timer is armed.
   - **More** → existing overflow menu items (add-to-playlist, sleep timer duplicate removed from kebab if it lives here — pick one home, don't double-list).
2. Header kebab: if More absorbs everything, the header kebab from NP2 is removed in this task (single source for overflow).

**Test gate:** each slot fires its action; timer slot reflects an armed countdown; no duplicated sleep-timer entry.
**Commit:** `feat(flutter): now playing redesign NP7 — glass action pill`

### NP8 — Lyrics peek sheet restyle

**Files:** `now_playing_lyrics.dart` (`_LyricsSection` restyle); tests.

1. `_LyricsSection` becomes the mockup's docked glass card: drag-handle bar, "LYRICS" section label (magenta underline accent), expand icon (existing key `now-playing-lyrics-expand`), and the existing `_SyncedLyricsPreview` window restyled — active line `titleLarge`/w700 white with the leading words in `heerrMagenta` (simplest faithful rendering: whole active line magenta→white `ShaderMask`; do **not** attempt word-level timing, LRC data is line-level), neighbours dimmed grey.
2. Background: glass over the NP1 backdrop (translucent `white` ~4 % + hairline border) instead of the solid palette-tint `Material` — the tint now lives in the highlight color (`brandBlend`), not the card fill.
3. `_ExpandedLyricsSheet` gets the same visual language (blurred backdrop passes through; big bold lines already exist). All state branches (loading / error / empty / plain-text / synced) and their keys unchanged.
4. RELATED tab per §2.5 (assumed dropped).

**Test gate:** all five content-state branches keep their keys; expand path works; active-line styling asserted.
**Commit:** `feat(flutter): now playing redesign NP8 — lyrics peek sheet restyle`

### NP9 — Queue sheet restyle (Now Playing / Next Up)

**Files:** `now_playing_transport.dart` (`_QueueList` + `_openQueueSheet`); tests.

1. Section the existing flat list: "Now Playing" (the current item, non-dismissible, waveform-equalizer leading icon in magenta) and "Next Up" (everything after it); items before the current one stay listed under "History" or are simply shown dimmed above (pick the cheaper — dimmed above, no third header).
2. Rows get cover-art thumbs (`LibraryCoverArt` via the item's art URI) instead of the generic note icon; keep `ReorderableListView` + `Dismissible` wiring and index math **exactly** (section headers must not shift the handler indices — use a flat list with in-row header widgets or map view-index → queue-index explicitly, and test that mapping).
3. Sheet chrome: glass background, rounded 28 top corners, drag handle (already via `showDragHandle`).

**Test gate:** reorder/dismiss/skip still hit the correct queue indices with headers present (the index-mapping test is the point of this task); current-item row not dismissible.
**Commit:** `feat(flutter): now playing redesign NP9 — sectioned queue sheet`

### NP10 (stretch) — Signature interaction: swipe art up → lyrics takeover

**Files:** `now_playing_screen.dart` + a new coordinator part file; tests (state machine only; the visual transition is smoke-verified on device).

1. Vertical-drag recognizer on the hero art. Drag-up progress `t ∈ [0,1]` drives a single `AnimationController`:
   - art shrinks/translates from hero position to a small (~88 dp) floating thumb top-left (reuses the position `_CornerArt` occupies today);
   - title/transport/pill fade out;
   - the lyrics surface expands from the peek card to full height;
   - the waveform seek bar morphs into the thin progress line (crossfade).
2. Release: settle to nearest state (`< 0.4` → snap back, else complete). Swipe down / chevron reverses. Back button in lyrics state collapses first, pops second (`PopScope`).
3. Implementation shape: keep it as **one screen with two layout states** driven by the controller (no route push — a route-level hero transition can't be dragged interactively). `_ExpandedLyricsSheet` as a modal is retired in this end state; its content widgets (`_SyncedLyrics`, `_CornerArt`) are reused in-place.
4. Reduced-motion: jump-cut between the two states, no interpolation.
5. Riskiest task in the phase — timebox; if it slips, ship NP1–NP9 and log NP10 to DEBT with this section as the spec.

**Test gate:** state machine (drag thresholds, back-button ordering, track-change during expanded state) unit-tested via the controller; content-state keys still resolvable in both layouts.
**Commit:** `feat(flutter): now playing redesign NP10 — swipe-up lyrics takeover`

### NP11 — Docs, version bump, smoke

1. `DECISIONLOG.md` ADR for the phase (background approach, waveform-seek-bar replacement of Slider, §2 resolutions, NP10 outcome); `CHANGELOG.md` per-task entries should already exist — this task batches the roadmap update.
2. Version bump (minor — e.g. `4.10.0` → `4.11.0`, confirm against whatever is current at implementation time) across **all five** locations per `/CLAUDE.md` §3 version-sync: `backend/pyproject.toml`, `backend/app/main.py`, `android/app/pubspec.yaml`, both `ROADMAP.md` status lines.
3. On-device smoke on the Pixel 7: track change (backdrop + glow cross-fade), waveform seek (tap + drag + zero-duration stream edge case), offline download button, queue reorder with sections, lyrics sync + expand, sleep timer slot, NP10 gesture if shipped, and a battery sanity pass (blur + three concurrent animations is the new hot path — check `flutter run --profile` frame times on the screen).
4. `graphify update .`

**Commit:** `docs(flutter): now playing redesign NP11 — ADR, changelog, roadmap + version bump`

---

## 5. Dropped from the mockup / brief (with reasons)

| Item | Reason |
|------|--------|
| Brief's hex palette (#FF4D9D…) | Locked brand palette in `theme.dart` wins; no new hex literals. |
| "Dolby Atmos" badge | No data source (Subsonic exposes no spatial-audio metadata). |
| "RELATED" lyrics-sheet tab | No in-place data source; Find Similar already exists via the seed path (§2.5). |
| Quote/share lyric buttons | Needs a share-intent dep for a decorative affordance; DEBT if requested (§2.7). |
| Word-level lyric karaoke highlight | LRC data is line-timed only; word timing would be fabricated. |
| Cast / output routing | Placeholder icon only; out of scope (same status as today). |
| Per-frequency "real" waveform | Would require decoding audio PCM on device; deterministic seeded bars keep the exact visual for free. |

---

## 6. Test-impact inventory

Tests that will need edits (keys/layout, not behavior): `test/screens/player/now_playing_lyrics_toggle_test.dart`, `now_playing_add_to_playlist_test.dart`, and any transport/scrubber tests pinning `Slider` (NP5 removes the `Slider` widget entirely — those assertions move to `WaveformSeekBar`). The queue-polling pause/resume and preview-badge tests must pass **unmodified** — they pin behavior this redesign does not touch.
