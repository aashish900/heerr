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
| S11 | v3.0.0 smoke + bump. Backend J6–J12 already live at `3.0.0-rc1`; the only gate left is the 7-step on-device smoke on the Pixel 7 against the home Navidrome. Promote `v3.0.0-rc1` → `v3.0.0` after it passes. | ⏳ pending on-device smoke only |

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
