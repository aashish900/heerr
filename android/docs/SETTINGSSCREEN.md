# SETTINGSSCREEN.md — Settings Screen redesign plan ("Control Center")

Status: **PLANNED** 2026-07-12. Not yet implemented. Open decisions D1–D7 (§8) unconfirmed.
Reference mockup: `/Users/E1621/Documents/Personal/Android/Settings.png` (outside the repo — copy to `android/docs/assets/settings-screen.png` to version it).
Milestone prefix: **SE** (SE1–SE7). A–Z, X, NP, DL are taken; Phase S (profiles) already owns the single letter S.

Goal: replace the plain `AppBar` + `ExpansionTile` layout in `lib/screens/settings_screen.dart` with the branded design: shared heerr header (no greeting — see brief addendum), "Settings" headline + subtitle, floating profile card, a promoted **Server & Sync** card with live status + Sync Now, grouped floating section cards with reusable tiles, and an About-heerr footer. Pinned `MiniPlayer` + bottom nav come free from the shell (`lib/router.dart`) — no work.

---

## 0. Ground rules for the implementing agent

- Bootstrap first: `/CLAUDE.md`, `android/CLAUDE.md`, `android/docs/CONTEXT.md`, `DECISIONLOG.md`, `CHANGELOG.md`.
- `graphify-out/graph.json` exists — `graphify query "<question>"` before reading unfamiliar source; `graphify update .` after code changes.
- **TDD:** failing widget/provider test first. `flutter test` + `flutter analyze` green before starting and before declaring each task done. Working dir: `android/app/`.
- All colors from `lib/theme.dart` (`heerrMagenta`, `heerrGradient`, elevation ladder) / `Theme.of(context).colorScheme`. No new hex literals.
- **Zero functionality loss.** Every control on the current screen (offline toggles, sync interval, Sync Now, storage line, clear-all, profiles CRUD, recommendations health, app version) must exist and work after the redesign. Restyle, never remove.
- Thin client stays thin: no new backend endpoints, no WebSocket. Everything reads existing providers.
- No emojis in code/commits. Flush `docs/CHANGELOG.md` (+ `DECISIONLOG.md`) at the end of each task.
- One commit per task: `feat(flutter): settings redesign SE<n> — <thing>`.

---

## 1. Target layout (top → bottom)

| # | Zone | Content | Widget |
|---|------|---------|--------|
| 1 | Header | `BrandedAppBar` — logo mark only, **no greeting** (brief addendum overrides the mockup) + shared trailing actions (see D2) | reuse |
| 2 | Title | "Settings" headline + subtitle "Customize heerr the way you like." | `_SettingsTitle` (same pattern as `_DownloadsTitle`) |
| 3 | Profile card | Floating card: avatar ring, display name, "Manage your profile", chevron → `Routes.profile` | `ProfileCard` (restyle existing `settings/profile_card.dart`) |
| 4 | Server & Sync | **Promoted card** — hostname, Online status pill, "Last synced N min ago", inline **Sync Now** action, sync preferences rows (see §3) | `ServerSyncCard` |
| 5 | Downloads & Storage | Group card: offline master switch, Wi-Fi only, Charging only, Sync entire library, Storage row, Clear all (see §4) | `SettingsGroupCard` + tiles |
| 6 | Profiles | Group card hosting existing `ProfilesSection` (credential surface — untouched logic) | reuse |
| 7 | Recommendations | Group card hosting existing engine-health section | reuse |
| 8 | About | Footer: version, open-source licenses, GitHub, tagline "Made for self-hosted music lovers" | `AboutFooter` |
| 9 | Mini player + nav | Shell-provided — **no work** | — |

Whole screen is one `CustomScrollView`; sections are slivers. 8dp grid, 24dp between section cards. Section labels ("Downloads & Storage", …) render as small `SettingsSectionHeader` text above each card, per the mockup.

File layout (dir already exists with `profile_card.dart` / `profiles_section.dart`):

```
lib/screens/settings/
├── settings_screen.dart        shell + slivers (moved from lib/screens/settings_screen.dart)
├── settings_tiles.dart         SettingsGroupCard / SettingsTile / SettingsSectionHeader
├── server_sync_card.dart       promoted Server & Sync card
├── settings_offline.dart       moved part file (restyled tiles, same providers)
├── settings_recommendations.dart  moved part file (restyled, same providers)
├── about_footer.dart
├── profile_card.dart           existing (restyled)
└── profiles_section.dart       existing (logic untouched)
```

`router.dart` import path updates accordingly.

---

## 2. Mockup rows — data reality

The mockup invents settings the app (and backend) don't have. Row-by-row verdict:

| Mockup row | Reality | Verdict |
|---|---|---|
| Audio Quality "Lossless" | No transcode/quality setting anywhere; app streams the original file. Backend has no quality endpoint. | **drop** (D1) |
| Playback "Crossfade, gapless" | Crossfade + equalizer are ROADMAP "Out of scope" by explicit decision (crossfade overrides album transitions). Gapless is built-in (Phase R), not a toggle. | **drop** (D1) |
| Equalizer | ROADMAP out-of-scope. | **drop** |
| Lyrics settings | Lyrics feature exists (NP phase) but has no user-facing preferences. | **drop** (D1) |
| Background & Animations "Dynamic" | Now Playing background is always dynamic; no toggle exists. | **drop** (D1) |
| Download Settings (Wi-Fi only, smart downloads) | `offlineSettingsProvider` — enabled / wifiOnly / chargingOnly / syncAll / pollIntervalMinutes (`lib/offline/offline_settings.dart`) | **exists** — restyle |
| Storage Management | Manifest storage line + `storageBreakdownProvider` (DL7, `lib/providers/storage_breakdown.dart`) + clear-all | **exists** — restyle, reuse breakdown |
| Auto Cleanup "On" | No standalone feature. The sync sweep (`sweptCount` in `OfflineSyncResult`) removes unmarked files automatically and is not toggleable. | **drop or informational caption** (D4) |
| Import Music | That's the app's core queue/download flow (Search → queue), not a setting. | **drop** |
| Home Server + Connected + last sync | `serverCredsProvider` (hostname), `serverStatusProvider` (DL2 health poll), `offlineSyncProvider.lastTickAt` | **exists** — the §3 card |
| Backup & Restore | No feature, no backend endpoint. | **drop** |
| Devices "2" | No device registry anywhere. | **drop** |
| Appearance "System" | Theme is a single hand-built AMOLED dark scheme; light theme is ROADMAP out-of-scope; no Material You. | **drop** (D1) |
| Notifications | Push/FCM is ROADMAP out-of-scope; polling is the contract. | **drop** |
| Language "English" | i18n is ROADMAP out-of-scope. | **drop** |
| About heerr | `appVersionProvider` exists; `showLicensePage()` is free from Flutter; GitHub URL is static. Privacy policy / Terms don't exist as documents. | **exists (partial)** — version + licenses + GitHub; drop Privacy/Terms |
| "Premium User" badge | Brief itself forbids it. | **drop** |
| Greeting in header | Brief addendum removes it for Settings. | **drop** |
| Bright green "Connected" | Brief says subtle. `heerrOnlineGreen` + `StatusPill` already exist as the sanctioned status-only green (Downloads hero, `lib/theme.dart`). | **reuse StatusPill** (D3) |

Net effect: after cuts, the screen has ~6 sections — Profile, Server & Sync, Downloads & Storage, Profiles, Recommendations, About. That is short enough that **flat group cards beat collapsible sections** (the brief's collapsible suggestion is conditioned on "if the number of settings grows") — see D5.

---

## 3. Server & Sync card (promoted)

Composite card, visually one step above the other groups (slightly larger padding, `GradientIcon` server glyph or reuse `server_glyph.dart` from Downloads at small scale):

- **Status row:** hostname from `serverCredsProvider` (host only, not full URL), `StatusPill` Online/Offline from `serverStatusProvider` (existing 30s screen-scoped poll — reuse, don't duplicate), "Last synced N min ago" from `offlineSyncProvider.lastTickAt` (relative-time helper already written for DL2 — extract to `lib/utils/` if it's currently private).
- **Inline Sync Now:** reuse the exact `_SyncNowAction` logic (busy spinner, `OfflineSyncResult` snackbar copy) restyled as a `GradientButton`/outlined button on the card. Disabled while `running`.
- **Sync preferences rows** (inline controls per brief addendum, no sub-screen): Sync interval dropdown (`_kPollChoices`), Wi-Fi only + Charging only switches. Placement here vs Downloads & Storage is D6.
- States: Online / Offline ("Server unreachable — downloads still play") / never-synced (`lastTickAt == null` → "Not synced yet").

No new providers. No new endpoints.

---

## 4. Downloads & Storage group

Restyle of the existing `_OfflineSection` into `SettingsTile`s inside a `SettingsGroupCard`:

- Master switch "Offline downloads" (inline `Switch`, brief addendum: inline controls) with the existing greyed-out/`AbsorbPointer` sub-control behavior kept.
- "Sync entire library" keeps its confirmation dialog + size estimate (`offlineSizeEstimateProvider`) untouched.
- **Storage row:** title "Storage", subtitle from manifest counts (`N albums · M songs · X GB`), tapping expands or navigates to the breakdown — reuse `StorageCard`/`storageBreakdownProvider` from `lib/screens/downloads/storage_card.dart` rather than re-deriving (extract to `lib/widgets/` if import direction gets awkward).
- "Clear all downloads" stays destructive-red with its confirmation dialog, as the last row.
- Wi-Fi only / Charging only / Sync interval live here **or** in the Server & Sync card — D6, one home only, never both.

---

## 5. Reusable tile system (the core of this phase)

```
SettingsSectionHeader   small grey uppercase-ish label above a card
SettingsGroupCard       rounded 24dp card, cs.surfaceContainerLow fill,
                        1px cs.outline border, thin dividers between rows
SettingsTile            leading GradientIcon (outlined icon, gradient shader),
                        title, subtitle, optional trailing value (magenta),
                        chevron; InkWell ripple; min height 56dp (≥48dp target)
SettingsSwitchTile      same anatomy, trailing Switch (theme already styles it)
SettingsDropdownTile    same anatomy, trailing DropdownButton
```

Rules: subtitles explain purpose ("Pause syncing on cellular data."), value text uses `heerrMagenta`, icons are `*_outlined` Material icons via the existing `GradientIcon` (`lib/widgets/gradient_icon.dart`). Every tile keyed `settings-tile-<slug>` for widget tests. Existing test keys (`settings-app-version`, `settings-section-*`, profile/offline keys) preserved or migrated deliberately in the same task that moves them.

Motion budget (all trivially pump-and-settleable):
- cards use the standard InkWell ripple; pressed state via slight scale (`AnimatedScale`, 0.98, 100ms) on tappable cards only (ProfileCard, Server & Sync)
- Sync Now icon rotates while busy (`RotationTransition`, same as DL3)
- nothing else animates — Settings is a utility surface

---

## 6. About footer

- App version row (existing `appVersionProvider`, keep key `settings-app-version`).
- "Open source licenses" → `showLicensePage(context: …, applicationName: 'heerr')` — zero-cost, built into Flutter.
- "GitHub" → `url_launcher` to the repo URL. **Check first:** if `url_launcher` isn't already in `pubspec.yaml`, adding a plugin needs a rebuild — flag in the task, it's a legitimate small dependency.
- Tagline line: "Made for self-hosted music lovers" in `cs.onSurfaceVariant`, centered, small.
- No Privacy Policy / Terms rows (no such documents exist — adding dead links is worse than omitting).

---

## 7. Task breakdown

Each task: failing test first → implement → `flutter test` + `flutter analyze` green → CHANGELOG flush → commit.

| Task | Scope | New/changed files | Tests |
|---|---|---|---|
| **SE1** | Restructure: move screen to `lib/screens/settings/settings_screen.dart` (+ move both part files), `CustomScrollView` shell, `BrandedAppBar` (no greeting), title+subtitle. Existing sections rehosted **visually unchanged**; router import updated | `settings_screen.dart`, `settings_offline.dart`, `settings_recommendations.dart`, `router.dart` | existing settings tests migrated + still green; header/title render |
| **SE2** | Tile system: `SettingsSectionHeader`, `SettingsGroupCard`, `SettingsTile` + switch/dropdown variants | `settings_tiles.dart` | tile anatomy, tap/ripple, switch callback, ≥48dp target |
| **SE3** | ProfileCard restyle: floating card, `ProfileAvatarRing`, name from `profileMetaNotifierProvider`, "Manage your profile", chevron → `Routes.profile` | `profile_card.dart` | renders name/avatar, tap navigates |
| **SE4** | `ServerSyncCard`: status row (reuse `serverStatusProvider` + `StatusPill`), last-sync relative time, inline Sync Now (logic lifted from `_SyncNowAction`), states matrix | `server_sync_card.dart`, possibly `lib/utils/relative_time.dart` extraction | online/offline/never-synced states; Sync Now fires notifier, disabled while running |
| **SE5** | Downloads & Storage group: `_OfflineSection` tiles → `SettingsTile` system, storage row reusing `storageBreakdownProvider`, clear-all kept; D6 placement applied | `settings_offline.dart` | every existing toggle/dialog regression-tested; storage row renders |
| **SE6** | Profiles + Recommendations groups: wrap `ProfilesSection` and recommendations health in `SettingsGroupCard`s, restyle inner tiles, zero logic change | `settings_screen.dart`, `settings_recommendations.dart` | existing profiles/recommendations tests green after restyle |
| **SE7** | `AboutFooter` (version, licenses page, GitHub link, tagline), motion polish (§5), docs flush (CHANGELOG, DECISIONLOG for D1–D7 outcomes, DEBT.md if anything deferred), on-device smoke checklist, version bump all 5 locations (`/CLAUDE.md` §3) → **4.13.0** | `about_footer.dart`, `pubspec.yaml` (maybe `url_launcher`), version files | licenses page opens; full `flutter test` sweep |

Linear SE1→SE7. SE3/SE4 could swap; don't bother.

---

## 8. Open decisions (confirm before SE1)

- **D1 — Fictional sections.** Mockup's Music & Playback (Audio Quality, Playback, Equalizer, Lyrics, Background), Appearance, Notifications, Language, Devices, Backup have no data source, and several are explicit ROADMAP out-of-scope items. Proposed: **drop them all** — no placeholder/mock rows in a shipping screen; dead tiles erode trust in a settings surface. Alternative: keep a disabled "coming soon" group (not recommended).
- **D2 — Header trailing actions.** Mockup shows Search + avatar; `BrandedAppBar`'s shared contract is Queue + avatar (all redesigned screens). There is no settings-search feature. Proposed: **Queue + avatar** (consistency), no search.
- **D3 — Online indicator color.** Proposed: reuse `StatusPill` + `heerrOnlineGreen` exactly as the Downloads hero does — one sanctioned status green beats a second bespoke "subtle" indicator. Alternative: grey/magenta dot.
- **D4 — Auto Cleanup.** The sync sweep exists but isn't toggleable. Proposed: **no row**; mention sweeping in the master switch subtitle ("Unmarked files are cleaned up automatically."). Alternative: build a real toggle (new setting + sync change — scope creep).
- **D5 — Flat vs collapsible.** Current screen uses `ExpansionTile`s (#17); post-cut section count (~6) is small. Proposed: **flat group cards** per mockup; Profiles group may keep an internal expander if its row count is long. This retires the `_CollapsibleSection` widget.
- **D6 — Sync-preference placement.** Wi-Fi only / Charging only / Sync interval: in the promoted Server & Sync card, or in Downloads & Storage? Proposed: **Downloads & Storage** (they gate downloading, not server connectivity); Server & Sync card stays status + Sync Now only.
- **D7 — Version.** Proposed target **4.13.0** at SE7 (minor bump, same convention as X/NP/DL phases).

---

## 9. Out of scope

- Backend changes of any kind; no new endpoints, no quality/transcode API.
- Crossfade, equalizer, i18n, light theme, push notifications (ROADMAP "Out of scope" — do not re-litigate).
- Backup/restore, device registry, import-music settings row.
- Settings search.
- Bottom-nav changes (same ruling as LIBRARYSCREEN.md / DOWNLOADSSCREEN.md).
- Golden tests / device benchmarks (v1 test policy, `android/CLAUDE.md`).
