# DEBT.md — heerr Android client

Outstanding work as of 2026-06-15. Append new items; strike-through + date when resolved.

---

## 1. Documentation / process debt

These are gates the project's own ROADMAP "complete when" checklist requires.

| # | Item | Status | Ref |
|---|------|--------|-----|
| D1 | Fix stale ROADMAP.md status line — said "Phases A–M complete, N1–N5 pending"; all N/O boxes checked. | ✅ 2026-06-15 | `ROADMAP.md:7` |
| D2 | Phase N ADR in `DECISIONLOG.md` (scrobble + seed strategy + recommendations + cross-reference + health). | ✅ existed | `DECISIONLOG.md` 2026-06-14 |
| D3 | Phase O ADR in `DECISIONLOG.md` (Home screen + 4-tab nav restructure). | ✅ 2026-06-15 | `DECISIONLOG.md` 2026-06-14 |
| D4 | Offline downloads (L-phase) ADR in `DECISIONLOG.md`. | ✅ 2026-06-15 | `DECISIONLOG.md` 2026-06-12 |
| D5 | Delete empty `android/app/pubspec.yaml.bak` (0 bytes, leftover noise). | ✅ 2026-06-15 | deleted |

---

## 2. Verification gates not yet run

Manual smokes called out as deferred in the CHANGELOG. No written log required — verified on-device is sufficient.

| # | Phase | Status |
|---|-------|--------|
| V1 | N (recommendations) | ✅ 2026-06-15 — verified on-device as part of v1.5.0 smoke. |
| V2 | O (home screen) | ✅ 2026-06-15 — verified on-device as part of v1.5.0 smoke. |
| V3 | P (v1.5.0 polish) | ✅ 2026-06-15 — P1/P2/P3 all passed; bug fixes for nav reset + LRCLib fallback also verified. `v1.5.0` tagged. |
| V4 | Q (v2.0.0 background sync) | ✅ 2026-06-16 — mark album → background → worker fires → downloads complete; WiFi-off gate skips worker; charging-only toggle gates correctly. `v2.0.0` tagged. |

---

## 3. Functional gaps in v1.4.0

Real missing features; in-scope (not listed in ROADMAP "out of scope").

| # | Item | Status | Notes |
|---|------|--------|-------|
| F1 | Cover art on `HomeRecommendationCard`. | ✅ already done | `_CoverArt` in `widgets/home_recommendation_card.dart` already does library cover → YouTube thumbnail → placeholder; `coverArt` field is hydrated on `RecommendedTrack` by the N4 cross-reference step. DEBT entry was stale. |
| F2 | Find Similar long-press on **album-detail** and **playlist-detail** song rows. | ✅ 2026-06-15 | `seedForSong(Song)` extracted to `models/seed_track.dart`; both detail screens now pass `findSimilarSeed: seedForSong(s)` on `onLongPress`. `flutter analyze` clean; 462/462 tests pass. |

---

## 4. v2 / v3 candidates

Scheduled items moved to the active ROADMAP. Unscheduled items remain in this section until re-scoped.

### Scheduled — v1.5.0 (Phase P)

| # | Item | Status |
|---|------|--------|
| X2 | Persist "Now Playing" queue across cold starts. | ✅ P1 shipped 2026-06-15 |
| X3 | Lyrics via Subsonic `getLyrics.view`. | ✅ P2 shipped 2026-06-15 |
| X4a | Sleep timer (just the sleep-timer subset of the original X4 bundle). | ✅ P3 shipped 2026-06-15 |

ADR: `DECISIONLOG.md` 2026-06-15 ("v1.5.0 player polish band").

### Scheduled — v2.0.0 (Phase Q)

| # | Item | Status |
|---|------|--------|
| X1 | WorkManager / true background sync. | ✅ Q1–Q4 shipped 2026-06-16 |

ADR: `DECISIONLOG.md` 2026-06-15 ("v2.0.0 background offline sync via WorkManager").

### Scheduled — v2.1.0 (Phase R)

| # | Item | Status |
|---|------|--------|
| X4b | Gapless playback (`useLazyPreparation: false` on the `just_audio` `AudioPlayer`). | ✅ R1 shipped 2026-06-16; on-device smoke passed; `v2.1.0` tagged. |

ADR: `DECISIONLOG.md` 2026-06-16 ("X4b: gapless playback via `useLazyPreparation: false`").

### Scheduled — v3.0.0 (Phase S)

| # | Item | Status |
|---|------|--------|
| S1–S10 | Multi-user profiles via Navidrome IdP (registry, migration, login, active-profile provider, dio wiring, isolation audit, Settings UI, docs). | ✅ shipped 2026-06-17 |
| S11 | v3.0.0 smoke + bump. On-device smoke passed on the Pixel 7 against the home Navidrome with backend `3.0.0`. Promoted to `v3.0.0`. | ✅ shipped 2026-06-17 |

ADR: `DECISIONLOG.md` 2026-06-17 ("Multi-user profiles via Navidrome IdP — heerr v3.0.0").

### Deferred — v3.1.0 backlog

| # | Item | Unlock condition |
|---|------|-----------------|
| S-future | Per-user Last.fm / ListenBrainz forwarding configured *on the device* instead of via `navidrome.toml`. | Reports of mis-attributed scrobbles in a multi-user household where Navidrome's per-user forwarding isn't enough. |
| S-future | Biometric unlock for the per-profile Navidrome password. | User asks for re-auth on app resume; pulls in `local_auth` dep. |
| S-future | Soft profile switching (in-memory swap, no app teardown). | Profile-switch latency becomes a friction point in practice. |

### Unscheduled — v3 backlog

Items still in ROADMAP `## Out of scope`. Do not implement without a new DECISIONLOG entry re-scoping them.

| # | Item | Unlock condition |
|---|------|-----------------|
| X5 | Cast / Sonos / external player hand-off. | Re-scope decision; high-risk transport work. |
| X7 | Android TV version (leanback UI, D-pad navigation, side-by-side with phone build). | Re-scope decision; needs separate target/flavour + leanback launcher + remote-friendly UI. |

---

## Suggested order of attack

1. ✅ **V1 + V2** — verified on-device 2026-06-15.
2. ✅ **P1 → P4** — v1.5.0 shipped 2026-06-15.
3. ✅ **Q1 → Q4** — v2.0.0 shipped 2026-06-16.
4. **X-series remainder** — only after a re-scoping conversation lands.

---

## 5. Architectural debt (audit 2026-06-18)

Findings from a senior-Android-dev architectural pass over `android/app/lib/` (14.3k LOC, 103 hand-written `.dart` files). Ordered by criticality / blast radius first, low-hanging fruit at the tail. Each item cites the offending file path + line so a future task can pick it up cold.

### P0 — Correctness / contract violations (fix next)

| # | Item | Evidence | Why it bites |
|---|------|----------|--------------|
| A1 | **Dual credential systems still coexist after Phase S.** `Settings.build` reads the *active Profile* AND overlays it on the legacy single-set keys (`backend_base_url`, `bearer_token`, `navidrome_*`). `ServerProfiles.saveProfile` / `.activate` still **write** to both the legacy `server_profiles` blob AND mirror into the single-set keys via `settingsProvider.save(...)`. The Phase-S `ProfileRegistry` writes to a third location (`profiles_index`). | `providers/settings.dart:110-134` (overlay), `providers/settings.dart:231-272` (mirror-on-save), `providers/profiles/profile_registry.dart:50-114` | Violates the `android/CLAUDE.md` hard rule *"Don't read per-server credentials from `settingsProvider` and `activeProfileProvider` in the same callsite"*. Any new screen that picks the wrong source ships drift. Legacy `ServerProfiles` notifier appears to be dead code post-S3 migration — confirm + delete, then drop the overlay branch from `Settings.build`. |
| A2 | **GoRouter S5 redirect uses `container.read` with no `refreshListenable`.** Redirect re-evaluates only on navigation events. Deleting the active profile in Settings does not push the user to `/login` until they tap a tab. | `router.dart:62-80` | Concrete user-visible bug post-profile-delete: stale screens render against a torn-down active profile until next navigation. Wire `refreshListenable:` with a `ProviderSubscription`→`ChangeNotifier` adapter on `profileRegistryProvider`. |
| A3 | **`BearerAuthInterceptor` captures token by value at Dio-construction time.** Token rotation requires fully rebuilding the `Dio` (current behavior — `dioClientProvider` rebuilds on `settingsProvider` change). All in-flight requests against the old Dio still send the old token; the new Dio doesn't inherit connection pool / interceptor chain order. | `api/client.dart:15-27`, `api/client.dart:33-58` | Marginal cost today (single-user), but the Phase-S multi-profile switch already triggers full Dio rebuilds on every save. Move token resolution inside `onRequest` (read via the closured `Ref`) so the interceptor is stateless w.r.t. credentials. Same fix applies to `SubsonicAuthInterceptor` (`api/subsonic_client.dart:39-70`). |
| A4 | **`Settings.build` performs 10 sequential `await store.read(...)` per invalidation, and is invalidated on every `save`.** Every settings save (toggling WiFi-only, picking poll interval, etc.) re-reads all 10 keys serially from EncryptedSharedPreferences. | `providers/settings.dart:100-135` (10 reads), `providers/settings.dart:182, 197` (`invalidateSelf` after each save) | Hot on Settings screen UX — visible jank when toggling rapidly. Either (a) batch with `Future.wait`, or (b) keep state in-memory and only persist deltas. (b) also fixes A1 by collapsing the dual source. |
| A5 | **Offline prefs (5 non-secret booleans/int) live in `flutter_secure_storage`.** EncryptedSharedPreferences is for the bearer token + Navidrome password; `offlineEnabled / syncAll / wifiOnly / pollIntervalMin / chargingOnly` are user prefs, not secrets, and pay the keystore round-trip on every read. | `providers/settings.dart:43-47, 116-133, 161-181` | Misuse of secure storage; complicates A4 cleanup. Split into `OfflinePrefsRepository` backed by `shared_preferences` (regular). One-shot migration on first launch of the next version (read-from-secure → write-to-prefs → delete-secure). |

### P1 — Design conflicts / consolidation

| # | Item | Evidence | Why it bites |
|---|------|----------|--------------|
| A6 | **`SettingsValue` is a 12-field tuple mixing creds + Navidrome creds + offline prefs.** Any consumer that just needs `bearerToken` watches the whole record and rebuilds on offline-toggle changes (and vice versa). | `providers/settings.dart:19-34` | Cascading rebuilds: `dioClientProvider` rebuilds on offline-prefs changes; offline screens rebuild on token rotation. Split into `HeerrCredsValue`, `NavidromeCredsValue`, `OfflinePrefsValue` — each its own provider. Fixes the redundant `OfflineSettings` notifier (it currently exists only to re-slice `SettingsValue` — see `offline/offline_settings.dart:13-35`). |
| A7 | **`ServerProfile` (legacy) is hand-rolled JSON, `Profile` (Phase S) is `freezed`+`json_serializable`.** Two model conventions for the same domain object. | `providers/settings.dart:58-95` vs `models/profile.dart:20-36` | Confusing for any new contributor. Subsumed by A1 — delete `ServerProfile` when the dual system goes away. |
| A8 | **`router.dart` is a god file (393 LOC) — route table + ShellScaffold + AppLifecycleObserver + offline-sync pause/resume + Now-Playing flush + background-sync scheduling + recommendation-health refresh.** | `router.dart:175-329` (single State class owns six side-effects) | Single Responsibility violation. The lifecycle host should be its own widget under `lib/app/` (e.g. `LifecycleCoordinator`) that the shell composes. Makes `_ShellScaffold` testable in isolation. |
| A9 | **No retry / logging interceptor.** `android/CLAUDE.md` and `CONTEXT.md` both promise "interceptors for the auth header + retry-on-503 + logging" but only auth is implemented. `RateLimitedError` is mapped from 503 and a `Retry-After` is parsed — and then thrown to the caller with no retry. | `api/client.dart:45-58`, `api/api_error.dart:142-152` | Backend transient 503s surface as user-visible snackbars. Add a `RetryInterceptor` (dio_smart_retry or hand-rolled) that honours `Retry-After`, and a `LogInterceptor` gated on `kDebugMode`. |
| A10 | **No Repository/Service layer — providers call `dio` and parse JSON inline.** | e.g. `providers/recommendations.dart`, `providers/search.dart`, `offline/offline_sync.dart:160-305` (transport+filesystem+state in one provider) | Couples Riverpod state, transport, JSON shape, and IO together. Hard to unit-test transport without spinning up Riverpod containers. Introduce a thin `XService` per domain (search, library, queue, offline) that returns typed models; providers wrap services for state. Big refactor; do it incrementally per feature. |

### P2 — Performance / correctness smells

| # | Item | Evidence | Why it bites |
|---|------|----------|--------------|
| A11 | **`buildSubsonicCoverArtUrl` / `buildSubsonicStreamUrl` rotate the salt per call.** Comment acknowledges it defeats Flutter's URL-keyed image cache. Library/Home grids render hundreds of cover art tiles per scroll. | `api/subsonic_client.dart:91-120, 122-156` | Cold network fetch per render of every tile. The salt only needs to rotate per session (or hourly) — Navidrome accepts a stable salt within a session. Add an optional `saltPolicy` param that lets the cover-art path opt into a session-stable salt while keeping per-request rotation for state-mutating calls. K1 was pre-noted in code — surface as a concrete debt item. |
| A12 | **`OfflineSync._runTick` shares a mutable `List<Song> toDownload` across N async workers** via `removeAt(0)`. Dart's single-threaded event loop makes this *currently* race-free (no awaits between the length check and the removal), but the pattern is fragile — a refactor that inserts an await between `isNotEmpty` and `removeAt(0)` silently introduces double-downloads. | `offline/offline_sync.dart:251-279` | Use an explicit `Queue<Song>` + an `Iterator` or a `Stream`-based worker pool (`pool` package, or a hand-rolled semaphore). Same invariant, but enforced by the type. |
| A13 | **Artist→albums fan-out in `_resolveTargets` is sequential.** For a marked artist with N albums, N back-to-back `await ref.read(libraryAlbumProvider(id).future)`. Sync-all magnifies (every library album, sequential). | `offline/offline_sync.dart:325-385` | Long ticks on a large library. Bound parallelism with `Future.wait` over chunks (e.g. 4 concurrent). |
| A14 | **Wi-Fi check is poll-only, not stream-based.** `_runTick` snapshots wifi state once; if Wi-Fi comes back mid-tick the user waits for the next poll (15 min default). | `offline/offline_sync.dart:60-79, 220-237` | Connectivity_plus already exposes `onConnectivityChanged`. Subscribe in `OfflineSync.build`, and trigger `_tick()` on a transition to Wi-Fi. |
| A15 | **`OfflineSync` is `keepAlive: true` and starts its Timer in `build`,** but the foreground lifecycle host is `_ShellScaffold` (not mounted on the `/login` route). On a fresh install the user lingers on /login → sync provider has already built once (during keep-alive initialization) and is ticking without a lifecycle observer. | `offline/offline_sync.dart:88-111`, `router.dart:236-247` (shell registers observer) | Wasted ticks on a screen that has no creds anyway (and `_runTick` returns early with `'no creds'` — but it does run). Either gate the build on `activeProfile != null`, or move the lifecycle observer into the app-level (A8). |

### P3 — Low-hanging cleanup

| # | Item | Evidence | Notes |
|---|------|----------|-------|
| A16 | Mixed screen layout convention: `screens/settings_screen.dart` (flat) vs `screens/settings/profiles_section.dart` (subfolder). Same for `screens/queue_screen.dart` vs `screens/library/*`. | `lib/screens/` tree | Pick one (subfolder per domain). Move flat `*_screen.dart` files under their domain folder. Pure rename — analyzer will catch any import miss. |
| A17 | Large widget files due for split: `now_playing_screen.dart` (756 LOC), `library_screen.dart` (615), `playlist_detail_screen.dart` (608), `settings_screen.dart` (595), `servers_screen.dart` (472). | `wc -l` survey | Extract per-section private widgets to sibling files. Improves rebuild scope (Flutter rebuilds the smallest matching widget). |
| A18 | `dev_defaults.dart` is committed (the `.example` companion exists) — risk of leaking server URLs. | `lib/dev_defaults.dart` + `dev_defaults.example.dart` | If it carries any real Tailscale host / token, move it to `.gitignore` and document the seeding workflow in `README.md`. (Check before deleting — may already be benign.) |
| A19 | `OfflineSyncStatus`, `OfflineSyncResult`, `SettingsValue`, `OfflineSettingsValue`, `ProfileRegistryState` are all `typedef` records. Records have no `copyWith`, no exhaustive pattern matching beyond destructure, no `==`-by-field guarantee across mutations. | `offline/offline_sync.dart:33-58`, `providers/settings.dart:19-34`, etc. | Move to `freezed` for parity with the rest of the model layer (A7). Keeps refactors cheap when fields are added. |
| A20 | `Settings.clear()` does not clear `profiles_index` / `active_profile_id` / `server_profiles` / `active_server_name` — only the single-set keys + offline prefs. | `providers/settings.dart:185-198` | "Clear settings" leaves the profile registry intact, so the user ends up with a profile they can't authenticate (creds half-wiped). Either expand `clear()` or rename it to make its scope obvious. |
| A21 | No CI workflow for `flutter analyze` / `flutter test` (the user runs them manually per ROADMAP gate). | `.github/workflows/` not referenced in `android/docs/`. Verify. | Pre-merge enforcement of the "green before, green after" rule in `android/CLAUDE.md §Development workflow`. Cheap; one workflow file. |
| A22 | iOS-related plugin baggage (`just_audio`, `audio_service`, `connectivity_plus`, `flutter_secure_storage`) pulls in CocoaPods/Swift code that is built into the project tree even though iOS is out of scope. | `app/ios/` (existence) | Either delete `app/ios/` so the next `flutter pub get` doesn't re-generate it, or document it as benign. Confirmation of the project policy first (don't delete unprompted). |

### Suggested order of attack (architectural)

1. **A1 → A4 → A5** in one band: kill the dual credential system and the secure-storage misuse together; the rest of P0/P1 piggy-backs on the cleaner state shape.
2. **A6 → A7** (model consolidation) — required before A8/A10 to avoid churn.
3. **A9** (retry+logging interceptor) — small, isolated, immediate UX win on transient backend failures.
4. **A2 + A15** — both about reactive lifecycle correctness; fix together.
5. **A8 → A10** — the bigger refactor; do it once the credential layer is settled.
6. **P2 (perf)** — A11 is the highest-impact-per-LOC; A12/A13/A14 follow as the offline subsystem gets touched.
7. **P3** — opportunistic; pick up alongside any feature work that lands in the same file.
