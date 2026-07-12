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
| V5 | A1/A4/A5 credential + offline-prefs band (v3.1.1) | ✅ 2026-06-19 — on-device smoke passed. Upgrade from v3.0.0: silent re-login + offline prefs survived; no Servers tile/route; profile add/switch/remove; auth-error redirects to `/login`; fresh-install defaults. Tagged `v3.1.1`. |
| V6 | A6 SettingsValue split + R8 media-notification fix (v3.1.2) | ✅ 2026-06-20 — on-device smoke passed. Release APK confirmed: lock-screen + pull-down media controls present; offline path re-keying on profile switch correct; offline prefs survive upgrade from v3.1.1. Tagged `v3.1.2`. |
| V7 | DEBT §5 architectural-debt band — refactor-only (v3.2.0): A8/A10 service layer + LifecycleCoordinator, A3 stateless interceptors, A11 cover-art salt, A12–A14 offline-sync, A2/A15 reactive lifecycle, A17 file splits | ✅ 2026-06-20 — on-device smoke passed (SMOKE-TEST.md §14a). Release APK confirmed: all read/playback/offline/search/playlist/lyrics paths intact post-refactor; cover-art tiles no longer refetch on re-scroll; WiFi-off→on triggers off-schedule sync; profile-remove redirects to `/login` immediately; profile switch loads new creds + audio. Tagged `v3.2.0`. |

---

## 3. Functional gaps in v1.4.0

Real missing features; in-scope (not listed in ROADMAP "out of scope").

| # | Item | Status | Notes |
|---|------|--------|-------|
| F1 | Cover art on `HomeRecommendationCard`. | ✅ already done | `_CoverArt` in `widgets/home_recommendation_card.dart` already does library cover → YouTube thumbnail → placeholder; `coverArt` field is hydrated on `RecommendedTrack` by the N4 cross-reference step. DEBT entry was stale. |
| F2 | Find Similar long-press on **album-detail** and **playlist-detail** song rows. | ✅ 2026-06-15 | `seedForSong(Song)` extracted to `models/seed_track.dart`; both detail screens now pass `findSimilarSeed: seedForSong(s)` on `onLongPress`. `flutter analyze` clean; 462/462 tests pass. |
| F3 | Extend stream-first **preview** (Phase T) to the **Recommendations screen** + **Home "Picked for you" cards** for `inLibrary == false` rows. | ⏳ deferred | T (v3.5.0) shipped preview on the Library search results only. `playPreview` + `searchResultToMediaItem` are reusable, but those surfaces deal in `RecommendedTrack`/`HomeRecommendationCard` (not `SearchResultItem`); needs a small adapter `sourceUrl → playPreview`. Pick up if previewing a recommendation is requested. ADR: `DECISIONLOG.md` 2026-06-23 (Phase T). |

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
| A1 | ✅ **RESOLVED 2026-06-19** (DECISIONLOG 2026-06-19; CHANGELOG 2026-06-19). `ServerProfile`/`ServerProfiles`/`ServersScreen`/`_ServersTile`/`/settings/servers` deleted; `Settings.build` reads creds only from `activeProfileProvider`; dio providers no longer dual-read. ~~**Dual credential systems still coexist after Phase S.**~~ `Settings.build` reads the *active Profile* AND overlays it on the legacy single-set keys (`backend_base_url`, `bearer_token`, `navidrome_*`). `ServerProfiles.saveProfile` / `.activate` still **write** to both the legacy `server_profiles` blob AND mirror into the single-set keys via `settingsProvider.save(...)`. The Phase-S `ProfileRegistry` writes to a third location (`profiles_index`). | `providers/settings.dart:110-134` (overlay), `providers/settings.dart:231-272` (mirror-on-save), `providers/profiles/profile_registry.dart:50-114` | Violates the `android/CLAUDE.md` hard rule *"Don't read per-server credentials from `settingsProvider` and `activeProfileProvider` in the same callsite"*. Any new screen that picks the wrong source ships drift. Legacy `ServerProfiles` notifier appears to be dead code post-S3 migration — confirm + delete, then drop the overlay branch from `Settings.build`. |
| A2 | ✅ **RESOLVED 2026-06-20** (DECISIONLOG 2026-06-20; CHANGELOG 2026-06-20). `buildHeerrRouter` now passes `refreshListenable:` a `_RouterRefresh` `ChangeNotifier` that bridges `profileRegistryProvider` via `container.listen` (auto-closed on container dispose; GoRouter removes its own listener on dispose, so no explicit teardown). The redirect re-evaluates the instant `activeId` goes null. ~~**GoRouter S5 redirect uses `container.read` with no `refreshListenable`.**~~ | `router.dart:62-80` | Post-profile-delete redirect to `/login` is now immediate, not deferred to the next navigation. Regression test in `test/router_test.dart` (A2 group). |
| A3 | ✅ **RESOLVED 2026-06-20** (DECISIONLOG 2026-06-20; CHANGELOG 2026-06-20). Both interceptors are now stateless w.r.t. credentials: `BearerAuthInterceptor` takes a `String? Function() tokenResolver` and `SubsonicAuthInterceptor` takes `usernameResolver`/`passwordResolver`, all reading `ref.read(activeProfileProvider)` per request. `dioClient`/`subsonicDioClient` now `ref.watch(...select(baseUrl))`, so the `Dio` rebuilds **only** on a base-URL change — a same-server token/password rotation reuses the existing instance (connection pool + interceptor chain intact). ~~**`BearerAuthInterceptor` captures token by value at Dio-construction time** …~~ | `api/client.dart`, `api/subsonic_client.dart` | Token rotation no longer churns the dio; tests in `test/api/client_test.dart` (A3 group: no-rebuild-on-rotate, rebuild-on-baseurl-change). |
| A4 | ✅ **RESOLVED 2026-06-19** — creds come from the in-memory active profile; the five offline prefs are read in one `Future.wait` batch. `Settings.build` no longer does sequential keystore reads. ~~**`Settings.build` performs 10 sequential `await store.read(...)` per invalidation, and is invalidated on every `save`.**~~ Every settings save (toggling WiFi-only, picking poll interval, etc.) re-reads all 10 keys serially from EncryptedSharedPreferences. | `providers/settings.dart:100-135` (10 reads), `providers/settings.dart:182, 197` (`invalidateSelf` after each save) | Hot on Settings screen UX — visible jank when toggling rapidly. Either (a) batch with `Future.wait`, or (b) keep state in-memory and only persist deltas. (b) also fixes A1 by collapsing the dual source. |
| A5 | ✅ **RESOLVED 2026-06-19** — moved to `shared_preferences` behind a new `PrefsStorage` seam (`providers/prefs_storage.dart`), with an idempotent one-shot `migrateOfflinePrefs` in `main.dart`. ~~**Offline prefs (5 non-secret booleans/int) live in `flutter_secure_storage`.**~~ EncryptedSharedPreferences is for the bearer token + Navidrome password; `offlineEnabled / syncAll / wifiOnly / pollIntervalMin / chargingOnly` are user prefs, not secrets, and pay the keystore round-trip on every read. | `providers/settings.dart:43-47, 116-133, 161-181` | Misuse of secure storage; complicates A4 cleanup. Split into `OfflinePrefsRepository` backed by `shared_preferences` (regular). One-shot migration on first launch of the next version (read-from-secure → write-to-prefs → delete-secure). |

### P1 — Design conflicts / consolidation

| # | Item | Evidence | Why it bites |
|---|------|----------|--------------|
| A6 | ✅ **RESOLVED 2026-06-19** (DECISIONLOG 2026-06-19; CHANGELOG 2026-06-19). `SettingsValue`/`Settings` (`providers/settings.dart`) deleted. Per-server creds now come from a thin synchronous `ServerCreds` re-slice over `activeProfileProvider` (`providers/server_creds.dart`); `OfflineSettings` (`offline/offline_settings.dart`) is the sole offline-prefs owner, reading `PrefsStorage` directly — the redundant re-slice notifier is gone. **No `HeerrCredsValue`** was created: post-A1 the dio clients read `activeProfileProvider` directly, so the heerr-creds slice had zero consumers (the literal DEBT proposal predated A1 and was stale). ~~**`SettingsValue` is a 12-field tuple mixing creds + Navidrome creds + offline prefs.**~~ Any consumer that just needs `bearerToken` watches the whole record and rebuilds on offline-toggle changes (and vice versa). | `providers/settings.dart:19-34` | Cascading rebuilds eliminated: cred consumers watch `serverCredsProvider` (rebuild only on profile switch); offline-pref consumers watch `offlineSettingsProvider`. |
| A7 | ✅ **RESOLVED 2026-06-19** — `ServerProfile` deleted in the A1 band; `Profile` (freezed) is now the only profile model. ~~**`ServerProfile` (legacy) is hand-rolled JSON, `Profile` (Phase S) is `freezed`+`json_serializable`.**~~ Two model conventions for the same domain object. | `providers/settings.dart:58-95` vs `models/profile.dart:20-36` | Confusing for any new contributor. Subsumed by A1 — delete `ServerProfile` when the dual system goes away. |
| A8 | ✅ **RESOLVED 2026-06-20** (DECISIONLOG 2026-06-20; CHANGELOG 2026-06-20). The six lifecycle side-effects moved into `lib/app/lifecycle_coordinator.dart` (`LifecycleCoordinator` `ConsumerStatefulWidget` + `WidgetsBindingObserver`); the ShellRoute builder composes `LifecycleCoordinator(child: _ShellScaffold(...))`. `_ShellScaffold` is now pure nav chrome (no observer mixin). ~~**`router.dart` is a god file (393 LOC) …**~~ | `router.dart` (now nav-only), `lib/app/lifecycle_coordinator.dart` | Lifecycle host testable in isolation — tests moved to `test/app/lifecycle_coordinator_test.dart`. |
| A9 | ✅ **RESOLVED 2026-06-20** (DECISIONLOG 2026-06-20; CHANGELOG 2026-06-20). New `api/interceptors.dart`: hand-rolled `RetryInterceptor` (bounded 2 retries; transient timeouts/connection-errors with 500ms exponential backoff + 503 honouring `Retry-After` only when ≤ 5s, else surfaces `RateLimitedError`) + `DebugLogInterceptor` (`kDebugMode`-gated, `debugPrint`, redacts `Authorization`). Wired into both `dioClient` and `subsonicDioClient` in order auth → retry → log. ~~**No retry / logging interceptor.**~~ `android/CLAUDE.md` and `CONTEXT.md` both promise "interceptors for the auth header + retry-on-503 + logging" but only auth is implemented. | `api/client.dart:45-58`, `api/api_error.dart:142-152` | The CONTEXT.md HTTP-stack promise is now fully met; transient 503/network blips retry silently instead of snackbar-ing. 8 new tests in `test/api/interceptors_test.dart`. |
| A10 | ✅ **RESOLVED 2026-06-20** (DECISIONLOG 2026-06-20; CHANGELOG 2026-06-20). Three transport+JSON service seams added under `lib/services/`: `SubsonicLibraryService` (all Subsonic reads), `PlaylistService` (Subsonic mutations), `BackendService` (all heerr-REST calls: search/recommend/health/queue/download/job-status), plus `LyricsService` (two-stage Navidrome→LRCLib). All 15 inline-dio providers now delegate to a service via an async `*ServiceProvider`; Riverpod state/orchestration (debounce, cancel-token, dedupe, invalidation) stays in the providers. Service providers read the same `subsonicDioClientProvider`/`dioClientProvider`, so existing dio-adapter test mocks pass unchanged; transport is now unit-testable container-free (`test/services/subsonic_library_service_test.dart`). ~~**No Repository/Service layer …**~~ The offline subsystem needed no change — `offline_downloader.downloadSong` is already an injected-dio seam and `offline_sync` orchestrates via existing providers (no inline transport+JSON). | `lib/services/*.dart`, all `providers/**` that previously held `dio.get`/`dio.post` | Transport decoupled from Riverpod; container-free unit tests now possible. |

### P2 — Performance / correctness smells

| # | Item | Evidence | Why it bites |
|---|------|----------|--------------|
| A11 | ✅ **RESOLVED 2026-06-20** (DECISIONLOG 2026-06-20; CHANGELOG 2026-06-20). Added a process-lifetime `sessionStableSalt()` and made it the default for both read-only URL builders (`buildSubsonicCoverArtUrl` / `buildSubsonicStreamUrl`), so the same `coverArtId`+`size` yields an identical URL across renders and Flutter's URL-keyed image cache hits. `SubsonicAuthInterceptor` (all API + state-mutating calls) still rotates per request. The salt is password-independent, so a profile switch keeps producing valid tokens from the same salt. ~~**`buildSubsonicCoverArtUrl` / `buildSubsonicStreamUrl` rotate the salt per call …**~~ | `api/subsonic_client.dart` (`sessionStableSalt`) | No more cold fetch per tile per scroll. Tests in `test/api/subsonic_client_test.dart` (A11 group). |
| A12 | ✅ **RESOLVED 2026-06-20** (DECISIONLOG 2026-06-20; CHANGELOG 2026-06-20). The download worker pool now pulls from an explicit `Queue<Song>` via `removeFirst()` (atomic — no await between the emptiness check and the pull), and `songsState` is a mutable map updated in place (`map[id] = result`) instead of a shared reassigned `List`/spread. The no-double-download invariant is now type-enforced. ~~**`OfflineSync._runTick` shares a mutable `List<Song> toDownload` …**~~ | `offline/offline_sync.dart` (`_runTick` worker pool) | Fragile interleaving replaced by a Queue. |
| A13 | ✅ **RESOLVED 2026-06-20** (DECISIONLOG 2026-06-20; CHANGELOG 2026-06-20). `_resolveTargets` now runs the artist→albums fan-out and the album/playlist detail fetches through a `_forEachBounded` helper (shared `Queue` + `_kResolveConcurrency = 4` workers) instead of a sequential `await` loop. ~~**Artist→albums fan-out in `_resolveTargets` is sequential …**~~ | `offline/offline_sync.dart` (`_resolveTargets`, `_forEachBounded`) | Sync-all ticks no longer serialize every album fetch. |
| A14 | ✅ **RESOLVED 2026-06-20** (DECISIONLOG 2026-06-20; CHANGELOG 2026-06-20). `WifiCheck` gained `Stream<bool> get onWifiChanged` (mapped from `Connectivity().onConnectivityChanged`); `OfflineSync.build` subscribes and fires an off-schedule `_tick()` on a false→true transition (guarded by `_paused`/`_running`; `_runTick` re-checks every gate). Subscription is cancelled on rebuild + dispose alongside the Timer. ~~**Wi-Fi check is poll-only, not stream-based …**~~ | `offline/offline_sync.dart` (`WifiCheck.onWifiChanged`, `_subscribeWifi`) | A Wi-Fi reconnect no longer waits out the poll interval. Test in `test/offline/offline_sync_test.dart` (A14). |
| A15 | ✅ **RESOLVED 2026-06-20** (DECISIONLOG 2026-06-20; CHANGELOG 2026-06-20). `OfflineSync.build` now `ref.watch(activeProfileProvider)` and returns `_kIdle` (no `_runTick`, no Timer) when it's null; it also cancels any stale Timer at the top of every rebuild. Watching the active profile means login rebuilds the provider and the first tick fires then. ~~**`OfflineSync` …starts its Timer in `build`** while the user lingers on /login.~~ | `offline/offline_sync.dart:88-111`, `router.dart:236-247` (shell registers observer) | No wasted ticks on `/login`. Regression test in `test/offline/offline_sync_test.dart` (guards group, A15). The lifecycle-observer relocation (A8) remains separate. |

### P3 — Low-hanging cleanup

| # | Item | Evidence | Notes |
|---|------|----------|-------|
| A16 | ⛔ **WON'T-FIX 2026-06-20** (DECISIONLOG 2026-06-20). Pure cosmetic re-foldering — moving 5 flat `*_screen.dart` files into per-domain subfolders rewrites ~48 internal relative imports + 5 importers + churns git blame for zero behaviour or rebuild-scope benefit. Decided not worth the churn; revisit only if a domain folder grows enough to justify it. ~~Mixed screen layout convention …~~ | `lib/screens/` tree | Closed as won't-fix (low value / high churn). |
| A17 | ✅ **RESOLVED 2026-06-20** (DECISIONLOG 2026-06-20; CHANGELOG 2026-06-20). The four large screen files are split via `part`/`part of` sibling files (privacy preserved, no caller import changes): `now_playing_screen.dart` 756→326 (+ `now_playing_lyrics`/`_transport`/`_sleep_timer`), `library_screen.dart` 615→134 (+ `library_search_results`/`library_tabs`), `settings_screen.dart` 562→56 (+ `settings_recommendations`/`settings_offline`), `playlist_detail_screen.dart` 606→556 (+ `playlist_detail_header`; dominated by one State class, so only the header/enum extracted). `servers_screen.dart` no longer exists (deleted in A1). ~~Large widget files due for split …~~ | the four screen files + new `part` siblings | Files now read in section-sized chunks. |
| A18 | ✅ **STALE — verified safe 2026-06-20** (CHANGELOG 2026-06-20). The premise ("`dev_defaults.dart` is committed") was wrong: the file is gitignored (`git check-ignore` matches), untracked, and never appears in history (`git log --all -- …/dev_defaults.dart` is empty). It holds a Tailnet IP + username but **no token/secret**, and `dev_defaults.example.dart` carries all-null placeholders. CI seeds the example copy to compile. No action beyond this correction. ~~`dev_defaults.dart` is committed …~~ | `lib/dev_defaults.dart` (gitignored), `lib/dev_defaults.example.dart` | No leak; nothing to do. |
| A19 | ⛔ **WON'T-FIX 2026-06-20** (DECISIONLOG 2026-06-20). Premise is partly wrong: Dart records already have value (`==`-by-field) equality, so the only real gain is `copyWith` — which nothing currently needs (these records are rebuilt wholesale each tick/read). Converting 7 record typedefs to `freezed` is high construction-site churn for marginal benefit. Closed as won't-fix; revisit if a `copyWith` need actually arises. ~~`OfflineSyncStatus`, … are all `typedef` records …~~ | `offline/offline_sync.dart`, `providers/server_creds.dart`, `offline/offline_settings.dart`, etc. | Closed as won't-fix (records already have value equality). |
| A20 | ✅ **STALE — resolved by A6 2026-06-20.** `Settings`/`Settings.clear()` and the legacy single-set keys were deleted in the A6 band (`providers/settings.dart` is gone). No half-wipe path exists anymore — creds live only on the active `Profile` and are managed via the `ProfileRegistry`. ~~`Settings.clear()` does not clear `profiles_index` …~~ | (deleted `providers/settings.dart`) | Nothing to do. |
| A21 | ✅ **RESOLVED 2026-06-20** (CHANGELOG 2026-06-20). Added `.github/workflows/android-ci.yml` — runs `flutter analyze` + `flutter test` on PRs to `main` and pushes to `main`, path-filtered to `android/**`. Mirrors `android-publish.yml` setup (Java 17, Flutter 3.44.0, `working-directory: android/app`, dev_defaults seeded from the all-null example, `pub get` + codegen) but needs no keystore/secrets. ~~No CI workflow for `flutter analyze` / `flutter test` …~~ | `.github/workflows/android-ci.yml` | The "green before / green after" gate is now enforced pre-merge. |
| A22 | ✅ **STALE — verified 2026-06-20.** `android/app/ios/` does not exist (no iOS platform folder is present in the tree). Nothing to delete; `flutter pub get` is not regenerating it. ~~iOS-related plugin baggage … `app/ios/` …~~ | (no `app/ios/`) | Nothing to do. |

### Suggested order of attack (architectural)

1. ✅ **A1 → A4 → A5** in one band: kill the dual credential system and the secure-storage misuse together; the rest of P0/P1 piggy-backs on the cleaner state shape.
2. ✅ **A6 → A7** (model consolidation) — done 2026-06-19. A7 collapsed into the A1 band; A6 shipped as the `ServerCreds` + `OfflineSettings` split.
3. ✅ **A9** (retry+logging interceptor) — done 2026-06-20.
4. ✅ **A2 + A15** — done 2026-06-20.
5. ✅ **A8 → A10** — done 2026-06-20 (one commit). Router god-file split + Repository/Service layer across all 15 inline-dio providers.
6. ✅ **P2 (perf)** — done 2026-06-20. A11 (session-stable salt) + A12/A13/A14 (offline-sync queue / bounded fan-out / connectivity-stream trigger).
7. ✅ **P3** — closed 2026-06-20. A17 done (widget-file splits); A18/A21 done earlier; A20/A22 stale (already gone); A16/A19 closed won't-fix (low value / high churn — see DECISIONLOG). **DEBT §5 architectural backlog fully triaged.**

---

## Resolved bugs

### R8 strips audio_service → media notification + lock-screen player gone (release only)

**Reported (2026-06-20):** Lock-screen controls gone; pull-down media notification not visible.

**Root cause:** Commit `403c5ff` enabled R8 minification (`isMinifyEnabled = true` +
`isShrinkResources = true`) to fix the WorkManager boot crash, but the keep rules in
`proguard-rules.pro` covered only `androidx.work` / `androidx.room`. AGP auto-keeps the
manifest-declared `AudioService` + `MediaButtonReceiver`, so the foreground service still
started (playback worked), but R8 stripped/obfuscated `audio_service`'s internal
MediaSession + notification-builder classes — so the notification + lock-screen controls
silently stopped rendering. Release-only; invisible in `flutter run` (debug skips R8).

**Fix (v3.1.2-rc2):** added `-keep class com.ryanheise.audioservice.**` and
`-keep class com.ryanheise.just_audio.**` to `proguard-rules.pro`. Confirmed by V6 smoke
(§6.8–6.10) against a release APK — lock-screen + pull-down notification restored. `v3.1.2` tagged.
---

## #20 — Now Playing widget: no album art ✅ RESOLVED 2026-06-21

~~The home-screen Now Playing widget (#20) shows title + artist + working
play/pause/next/prev controls + tap-to-open, but **no album art**.~~ Resolved:
`NowPlayingWidgetUpdater` now downloads the current track's cover (Subsonic
`artUri`, via a `WidgetArtCache` seam → Dio bytes → app-private PNG) once per
track, and `NowPlayingWidgetProvider.kt` decodes it as a full-bleed
`centerCrop` background behind a dark scrim. Fetched only while the app is
alive (widget keeps the last cover when the process is dead). Non-network art
(launcher fallback) → plain rounded background. (CHANGELOG 2026-06-21.)

Also pending: **on-device smoke test** of the widget (add to home screen, verify
controls hit the live MediaSession and title/artist/play-pause state track
playback). The APK builds clean but the widget has not been exercised on a
device yet.

**2026-06-21 — widget would not add / rendered blank on device.** First on-device
attempt failed (couldn't add / blank).

- *First guess (rc10, wrong):* suspected the transport buttons'
  `?android:attr/selectableItemBackgroundBorderless` background. Replaced all
  three with `@android:color/transparent`. Harmless, but **not** the cause.
- *Actual root cause (rc11, confirmed via logcat):* the dark-scrim was a bare
  `<View>`, and `android.view.View` is **not in the RemoteViews-allowed class
  whitelist**. Launcher logcat:
  `InflateException: Binary XML file line #23 ... Class not allowed to be
  inflated android.view.View`. Fixed by changing the scrim `<View>` →
  `<FrameLayout>` (allowed). Lesson: RemoteViews layouts may only use the
  whitelisted classes (FrameLayout/LinearLayout/RelativeLayout/GridLayout +
  TextView/ImageView/Button/ImageButton/ProgressBar/etc.) — never bare `View`.

**2026-06-22 — redesigned the widget; dropped cover art entirely.** After the
art approach kept failing on device (blank background / unreliable on skip; the
in-flight temp-file rename even regressed to ENOENT), the widget was rebuilt as
a compact **4x1** tile: title + artist, prev / play-pause / next, and a
display-only position `ProgressBar`. Layout uses only RemoteViews-whitelisted
classes (LinearLayout / TextView / ProgressBar / ImageButton) — no `ImageView`,
no `BitmapFactory`, no files. Position/duration cross the channel as
millisecond *strings* (sidesteps the home_widget int/Long ambiguity). Confirmed
loading on the Pixel 7.

Cover **colour** tint added back as the cheap version of the original "bonus":
`WidgetTintExtractor` computes the cover's dominant colour in Dart (reusing
`dominantColorFor`), darkens it ~50% for white-text legibility, and pushes a
**signed** ARGB int (string) — native paints the tile background via
`setInt(..,"setBackgroundColor",..)`. No bitmaps cross Binder. Computed once
per track while the app is alive; the tile keeps the last colour when the
process is dead. A draggable seek bar is intentionally not attempted (not
reliably supported in home-screen widgets); tapping the tile opens the app.

## Home redesign deferrals (2026-07-11, HOMESCREEN.md)

- **Quick Access "Edit"** — the mockup shows an Edit action implying user-reorderable/hideable shortcut cards. Shipped as a static 4-card row; customization (persisted order/visibility + edit mode UI) deferred.
- **Recently-Added row kebab menu** — the mockup shows a per-row overflow menu. Rows currently tap through to the album detail; an album-level action sheet (play / shuffle / download) is deferred.

## Library redesign deferrals (2026-07-11, LIBRARYSCREEN.md)

- **Explicit "E" badge on album rows** — the mockup shows an explicit-content badge; no explicit flag exists in the Subsonic album/song payloads the app consumes. Needs a data source before it can ship.
- **Trailing filter icon is decorative** — the chip row renders a disabled `filter_list` icon ("More filters coming soon"); no additional filters exist yet.
- **Artist song counts** — rows show "N albums" only; true per-artist song counts require a `getArtist` fan-out (one request per artist) that was rejected for v1.
- **"See all" on Most Played Artists** — the rail caps at 10 with no see-all surface; the full artists list is the same screen, so a dedicated most-played-ordered view was skipped.
- **"Year" as a range filter** — Year ships as a sort option inside the sort chip, not the mockup's separate "Year ▾" range picker.
- **On-device smoke pending** — X1–X6 verified by widget tests only; no device was attached during implementation (same status as the Home redesign smoke).

## Now Playing redesign deferrals (2026-07-11, NOWPLAYING.md)

- **NP10 full continuous drag-morph transition** — the plan's spec was an interactively-scrubbable transform (hero art shrinking into a floating corner thumb, title/transport/pill fading, waveform crossfading into a progress line, all in lockstep with drag progress, retiring `_ExpandedLyricsSheet` as a modal). Shipped instead as a discrete swipe-up-opens-the-existing-sheet gesture — see DECISIONLOG 2026-07-11 for the full rationale. Revisit only as its own scoped effort; the `onSwipeUp` callback on `_HeroArt` is the hook a future implementation would replace.
- **"Playing from \<context\>" header label (§2.1)** — the player has no play-source context to show; header keeps the static "NOW PLAYING" label. Would need `playContext` threaded through every queue-dispatch call site (album/playlist/search/recommendations) into `MediaItem.extras` — deferred as disproportionate to a header label (DECISIONLOG 2026-07-11).
- **Equalizer pill slot (§2.2)** — dropped; no in-app or system-EQ-intent feature exists. Pill ships as 4 slots (Queue/Lyrics/Timer/Add to playlist), not 5.
- **Single-song ad-hoc download (§2.4)** — the hero-art download button reflects existing per-song offline state and offers `deleteSongLocally` when ready, but there's no "download just this track outside any album/playlist" mutation anywhere in the app. Would need new `OfflineManifest`/`OfflineSync` shape.
- **Lyrics word-level karaoke highlight** — LRC lyric data is line-timed only; the active-line accent is a whole-line gradient, not word-by-word.
- **On-device smoke pending** — NP1–NP10 verified by widget tests only (908→922 across the phase); no device was attached during implementation.

## Downloads redesign deferrals (2026-07-12, DOWNLOADSSCREEN.md)

- **Per-file download throughput/percentage** — the brief's "24 MB/s" and per-song "32%" have no data source; `offline_downloader.dart` doesn't instrument `Dio`'s `onReceiveProgress`. The sync-activity Downloading card shows a count ("3 downloading") instead of a named song with a live percentage.
- **Progress-fraction tween on the hero waveform** — `WaveformStrip.progress` repaints the filled/dim bar split immediately on each rebuild rather than tweening between old/new values (`AnimatedFractionallySizedBox`-style implicit animation from the plan's §6 motion budget). Low-cost polish, deferred rather than adding another animation controller for a fractional visual gain.
- **Artists tab dropped (D2)** — the brief's four tabs became three (Songs/Albums/Playlists); manifest artists already expand to albums, so a dedicated Artists browsing mode was redundant. Revisit only if a genuinely artist-specific offline view is requested.
- **IPv6 status line replaced (D4)** — "IPv6 Connected" has no data source (the app never inspects the Tailscale connection directly); the hero shows hostname + "via Tailscale" instead.
- **On-device smoke pending** — DL1–DL8 verified by widget/provider tests only (971 total); no device was attached during implementation.

## Settings redesign deferrals (2026-07-12, SETTINGSSCREEN.md)

- **Every mockup section with no real data source dropped (D1)** — Audio Quality, Playback/Crossfade, Equalizer, Lyrics settings, Background & Animations, Appearance, Notifications, Language, Devices, Backup, Import Music. Several are explicit ROADMAP "Out of scope" items (crossfade, equaliser, i18n, light theme, push notifications); the rest simply have no provider/backend behind them. No placeholder/"coming soon" rows were shipped.
- **Auto Cleanup toggle (D4)** — the sync sweep runs automatically on every tick; there's no standalone on/off control. Mentioned in the offline master-switch subtitle instead of a dedicated row.
- **GitHub link's platform-channel tap unverified** — `AboutFooter`'s "GitHub" row calls `url_launcher`'s `launchUrl`, which needs a real Android intent resolver; not exercisable in `flutter_test` (the widget test overrides the tap via an injectable `onGithubTap` callback instead).
- **On-device smoke pending** — SE1–SE7 verified by widget tests only (986 total); no device was attached during implementation.
