# DOWNLOADSSCREEN.md — Downloads Screen redesign plan ("Sync Center")

Status: **PLANNED** 2026-07-12 against `main` @ v4.11.2. Not yet implemented.
Reference: prompt-only brief (no mockup image on disk). Concept: reframe Downloads from "list of downloaded songs" to a **Sync Center** — the surface that communicates "my library is synchronized with my home server".
Milestone prefix: **DL** (DL1–DL8). X and NP are taken (Library, Now Playing).

Goal: replace the plain `AppBar` + `TabBar` layout in `lib/screens/downloads_screen.dart` with the branded design: shared heerr header, "Downloads" headline + subtitle, server-status hero card with animated waveform sync progress, quick actions (Sync Now / Manage Storage), live sync-activity cards, Library-style segmented tabs + filter chips, metadata-rich song rows, storage-breakdown card, empty state. Pinned `MiniPlayer` and bottom nav come free from the shell (`lib/router.dart:389`) — no work.

---

## 0. Ground rules for the implementing agent

- Bootstrap first: `/CLAUDE.md`, `android/CLAUDE.md`, `android/docs/CONTEXT.md`, `DECISIONLOG.md`, `CHANGELOG.md`.
- `graphify-out/graph.json` exists — `graphify query "<question>"` before reading unfamiliar source; `graphify update .` after code changes.
- **TDD:** failing widget/provider test first. `flutter test` + `flutter analyze` green before starting and before declaring each task done. Working dir: `android/app/`.
- All colors from `lib/theme.dart` (`heerrMagenta`, `heerrGradient`, …) / `Theme.of(context).colorScheme`. No new hex literals. No green anywhere.
- Thin client stays thin: everything on this screen reads existing on-device state (`OfflineSync`, `OfflineManifest`) or polls existing REST endpoints. No WebSocket, no new backend endpoints in this phase.
- No emojis in code/commits.
- Flush `docs/CHANGELOG.md` (+ `DECISIONLOG.md` for decisions) at the end of each task.
- One commit per task: `feat(flutter): downloads redesign DL<n> — <thing>`.

---

## 1. Target layout (top → bottom)

| # | Zone | Content | Widget |
|---|------|---------|--------|
| 1 | Header | Shared `BrandedAppBar(compactGreeting: true)` — logo mark, greeting, queue, avatar (`lib/widgets/branded_header.dart`) | reuse |
| 2 | Title | "Downloads" headline + subtitle "Your music, available everywhere." | `_DownloadsTitle` |
| 3 | Hero | Server status + sync progress card (see §2) | `ServerStatusCard` |
| 4 | Quick actions | Two outlined cards: **Sync Now**, **Manage Storage** | `QuickActionCards` |
| 5 | Sync activity | Three compact cards: Downloading / Queued / Waiting for Wi-Fi | `SyncActivitySection` |
| 6 | Tabs | Segmented control, same interaction model as Library: **Songs / Albums / Playlists** (see decision D2) | `DownloadsTabBar` |
| 7 | Chips | Per-tab filter chips (see §4) | `DownloadsFilterChips` |
| 8 | Content | Tab body — metadata-rich rows | `DownloadedSongList` etc. |
| 9 | Storage | Storage-breakdown card (Music / Artwork / Lyrics / Cache) | `StorageCard` |
| 10 | Mini player + nav | Shell-provided — **no work** | — |

Whole screen is one `CustomScrollView`; sections 2–9 are slivers. 8dp-grid spacing, generous vertical rhythm (24dp between sections).

File layout mirrors `screens/home/` and `screens/library/`:

```
lib/screens/downloads/
├── downloads_screen.dart        shell + slivers (moved from lib/screens/downloads_screen.dart)
├── server_status_card.dart      hero
├── quick_action_cards.dart
├── sync_activity_section.dart
├── downloads_tabs.dart          tab bodies (part of downloads_screen.dart, like library_tabs.dart)
├── downloads_filter_chips.dart
├── storage_card.dart
└── server_glyph.dart            CustomPaint server illustration
```

---

## 2. Hero card — data reality

The brief asks for: Online status, "Navidrome", "IPv6 Connected", last sync, animated waveform progress, "3 songs remaining", "24 MB/s", "78%". What the codebase actually has:

| Brief element | Source | Verdict |
|---|---|---|
| Sync running / progress | `offlineSyncProvider` → `OfflineSyncStatus` record: `running`, `targetCount`, `readyCount`, `failedCount`, `lastTickAt` (`lib/offline/offline_sync.dart:45`) | **exists** — % = `readyCount/targetCount`, "N remaining" = `targetCount - readyCount` |
| Last sync | `lastTickAt` on the same record | **exists** — render relative ("2 min ago") |
| Server online | No provider today. `Endpoints.health` exists (`lib/api/endpoints.dart`) but nothing polls it outside Settings | **new** — `serverStatusProvider`: poll backend `/health` on a 30s timer while the screen is visible (polling is the contract, `android/CLAUDE.md`) |
| "Navidrome" label + host | `serverCredsProvider.navidromeBaseUrl` | **exists** — show hostname, not full URL |
| "IPv6 Connected" | No data source. Tailscale detail invisible to the app | **drop** — replace with hostname / "via Tailscale" static caption (decision D4) |
| "24 MB/s" throughput | Downloader (`lib/offline/offline_downloader.dart`) does not measure throughput | **drop for v1** — log to DEBT.md; instrumenting dio's `onReceiveProgress` is a later task |
| Animated waveform progress | `WaveformStrip` (`lib/widgets/waveform_strip.dart`) is decorative, not a progress bar | **extend** — add optional `progress` (0..1) param: bars up to the progress fraction painted with `heerrGradient`, the rest at low-opacity outline. `animate: true` only while `running` |
| Server illustration + breathing glow | none | **new** — `server_glyph.dart`: `CustomPaint`, minimal server-rack outline (thin strokes, rounded), magenta glow via `BoxShadow`/blur, glow opacity driven by a slow `AnimationController` while online. No image assets |

Hero states: **Online + idle** (status row, last sync), **Online + syncing** (waveform progress, N remaining, %), **Offline / unreachable** (muted glyph, "Server unreachable", last sync, downloads still playable messaging), **Sync error** (`lastError` surfaced).

---

## 3. Sync activity — data reality

Per-song states exist in the manifest: `queued / downloading / ready / failed` (`lib/offline/offline_manifest.dart:44`). "Waiting for Wi-Fi" is **not** a per-song state — it's the global condition `offlineSettings.wifiOnly && !isOnWifi` (`wifiCheckProvider`, `lib/offline/offline_sync.dart:75`).

- `syncActivityProvider` (new, `lib/providers/sync_activity.dart`): derives from `offlineManifestProvider` + `wifiCheckProvider` + `offlineSettingsProvider` → record `(downloading: {title, progress?}, queuedCount, waitingForWifi: bool, waitingCount)`.
- Per-file byte progress is not tracked today; the Downloading card shows the current song title without a % unless DL-debt throughput work lands. Card copy degrades gracefully.
- When `waitingForWifi` is false the third card shows Failed count instead (failedCount > 0) or is hidden — three cards max, never four.
- Subtle `WaveformStrip(animate:)` in the Downloading card only; Queued/Waiting cards are static (brief says "do not over animate").

---

## 4. Tabs, chips, content

- **Tabs: Songs / Albums / Playlists.** Current screen already has these three (`lib/screens/downloads_screen.dart:60`). The brief adds Artists; the manifest has `markedArtists` but they expand to albums anyway — **drop Artists tab** (decision D2). Reuse the Library segmented-tab visual (`gradient_tab_indicator.dart` + the pill pattern from `library_screen.dart`), icon + label per tab.
- **Chips** (new `downloadsFilterProvider`, per-tab): Songs tab — sort chip (Recent / Largest / A–Z; `downloadedAt` + `size` from `OfflineSongEntry`), **Lossless** toggle (`suffix == 'flac'`), **Today** toggle (`downloadedAt` same-day). Albums/Playlists tabs — sort chip only (A–Z / Recent). Reuse the chip visuals from `lib/widgets/library_filter_chips.dart` (extract the shared chip style if copy-paste looms).
- **Song rows:** artwork (`LibraryCoverArt`), title, artist, metadata line `Lossless • Yesterday • 24 MB` built from `OfflineSongEntry.suffix/downloadedAt/size`. Requires joining `downloadedSongsProvider` output with manifest entries — new provider `downloadedSongsWithMetaProvider` returning `(Song, OfflineSongEntry)` pairs, so the widget layer stays dumb. Trailing kebab opens the existing delete sheet (`_showDeleteOptions`, keep the W1 three-target contract intact — device / server / both).
- **Albums / Playlists tabs:** keep current provider wiring (`downloadedAlbumIdsProvider`, `offlineManifestProvider` → `markedPlaylists`), restyle rows to `LibraryResultTile` with a downloaded badge, add "N songs ready of M" sub-line where cheap (album song count is already in the cached `Album`).

---

## 5. Storage card — data reality

`offlineSizeEstimateProvider` (`lib/offline/offline_size_estimator.dart`) estimates what a **future sync-all would take** — wrong number for this card. Actual usage:

- **Music:** sum of `OfflineSongEntry.size` over `ready` entries — cheap, manifest-only.
- **Artwork / Lyrics / Cache:** directory walks of the offline dirs (`lib/offline/offline_paths.dart`, `library_cache.dart`, `lyrics_cache.dart`).
- New `storageBreakdownProvider` (`lib/providers/storage_breakdown.dart`): returns `({int music, int artwork, int lyrics, int cache})`; dir walks run in an isolate-friendly async loop, result cached per screen visit (invalidate on delete actions). Render as one stacked horizontal bar, each segment a `heerrGradient`-family tint at different opacity, legend rows with per-category size + %.

---

## 6. Empty state & motion

- **Empty (nothing ready + nothing marked):** reuse `EmptyState` pattern (`lib/widgets/empty_state.dart`) — large `GradientIcon`, "Nothing available offline yet.", body copy, `GradientButton` "Browse Library" → `context.go(Routes.library)`. Hero + quick actions still render above it (server status is useful even with zero downloads); sync-activity, chips, storage collapse.
- **Motion budget** (each gated on `running` / online so tests can `pumpAndSettle`):
  - waveform progress animates while syncing (`WaveformStrip.animate`)
  - progress fraction tweens via `AnimatedFractionallySizedBox`-style implicit animation
  - Sync Now icon rotates while `running` (`RotationTransition`)
  - server glyph glow breathes (slow 3–4s loop, online only)
  - nothing else pulses — cards are static

---

## 7. Task breakdown

Each task: failing test first → implement → `flutter test` + `flutter analyze` green → CHANGELOG flush → commit.

| Task | Scope | New/changed files | Tests |
|---|---|---|---|
| **DL1** | Restructure: move screen to `lib/screens/downloads/downloads_screen.dart`, `CustomScrollView` shell, `BrandedAppBar`, title+subtitle, existing three tab bodies rehosted unchanged, router import updated | `downloads_screen.dart`, `downloads_tabs.dart`, `router.dart` | screen renders header/title/tabs; existing downloads_screen tests migrated |
| **DL2** | `serverStatusProvider` (health poll, 30s, screen-scoped) + `ServerStatusCard` + `server_glyph.dart` + `WaveformStrip.progress` param | `server_status_card.dart`, `server_glyph.dart`, `providers/server_status.dart`, `widgets/waveform_strip.dart` | provider: online/offline/error transitions (fake dio); widget: 4 hero states; waveform progress paints deterministic |
| **DL3** | `QuickActionCards` — Sync Now → `ref.read(offlineSyncProvider.notifier).syncNow()` with result snackbar (reuse existing `OfflineSyncResult` copy); Manage Storage → `context.push(Routes.settings)` (offline section lives in `settings_screen.dart` part file) | `quick_action_cards.dart` | tap fires syncNow (mock notifier); disabled while `running` |
| **DL4** | `syncActivityProvider` + `SyncActivitySection` (3 cards, wifi/failed swap logic §3) | `providers/sync_activity.dart`, `sync_activity_section.dart` | provider: state derivation from fake manifest; widget: card visibility matrix |
| **DL5** | Segmented tabs (Library visual) + `downloadsFilterProvider` + chips | `downloads_filter_chips.dart`, `providers/downloads_filters.dart` | chip toggles mutate provider; sort orders verified |
| **DL6** | `downloadedSongsWithMetaProvider` + metadata-rich song rows + kebab → existing delete sheet; restyled Albums/Playlists rows | `providers/downloaded_songs.dart` (extend), `downloads_tabs.dart` | join provider unit test; row renders size/suffix/date line; delete flow regression |
| **DL7** | `storageBreakdownProvider` + `StorageCard` | `providers/storage_breakdown.dart`, `storage_card.dart` | provider vs fake dirs; card segments/legend |
| **DL8** | Empty state, motion polish (§6), DEBT.md entries (throughput, per-file %), docs flush, on-device smoke checklist, version bump (all 5 locations, `/CLAUDE.md` §3) → **4.12.0** | misc | full `flutter test` sweep |

Dependency order is linear DL1→DL8; DL4/DL5 could swap but don't bother.

---

## 8. Open decisions (confirm before DL1)

- **D1 — Health target.** Hero "Online" = backend `/health` reachable, or Navidrome ping, or both (two dots)? Proposed: backend `/health` only — it's the only server the thin client talks to.
- **D2 — Artists tab.** Brief says Songs/Albums/Artists/Playlists; current screen and manifest browsing model make Artists redundant (artists expand to albums). Proposed: drop Artists, keep three tabs, order **Songs / Albums / Playlists** (Songs first — it's the "what's on my phone" primary view).
- **D3 — Tab order vs Library.** Library order is Albums/Artists/Playlists (LIBRARYSCREEN.md §2.3). Downloads proposing Songs-first breaks cross-screen symmetry. Accept or mirror Library?
- **D4 — "IPv6 Connected" replacement.** Proposed: server hostname + "via Tailscale" caption. Alternative: drop the line entirely.
- **D5 — Throughput ("24 MB/s") and per-file %.** Proposed: out of scope, DEBT.md entry; needs `onReceiveProgress` instrumentation in `offline_downloader.dart`.
- **D6 — Storage card placement.** Brief puts it after the song list (bottom). Alternative: fold into hero. Proposed: bottom, as briefed.
- **D7 — Lossless definition.** `suffix == 'flac'` only, or a set (`flac`, `alac`, `wav`)? Proposed: set.

---

## 9. Out of scope

- Backend changes of any kind.
- Bottom-nav overhaul (same ruling as LIBRARYSCREEN.md §2.1).
- Real-time push, WebSocket, per-song server-side progress.
- Dynamic-color extraction work — `MiniPlayer` is shell-owned and already done.
- Golden tests / device benchmarks (v1 test policy, `android/CLAUDE.md`).
