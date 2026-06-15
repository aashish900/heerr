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

| # | Phase | What to verify |
|---|-------|----------------|
| V1 | N (recommendations) | Recommendations populate from backend; Play branch works for in-library matches; Find Similar long-press seeds the feed; Settings shows the engine health chip. |
| V2 | O (home screen) | Home boots first; recent / frequent albums populate from live Navidrome data; recommendations show; pull-to-refresh re-fetches; Queue still reachable via AppBar icon. |
| V3 | P (v1.5.0 polish) | P1: queue + position restored after force-close. P2: lyrics toggle works on a track with lyrics; empty state on a track without. P3: 1-min sleep timer pauses playback at expiry; chip + sheet roundtrip works. Tag `v1.5.0` after pass. |

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

| # | Item | Milestone |
|---|------|-----------|
| X1 | WorkManager / true background sync. | Q1–Q4 |

ADR: `DECISIONLOG.md` 2026-06-15 ("v2.0.0 background offline sync via WorkManager").

### Unscheduled — v3 backlog

Items still in ROADMAP `## Out of scope`. Do not implement without a new DECISIONLOG entry re-scoping them.

| # | Item | Unlock condition |
|---|------|-----------------|
| X4b | Gapless playback (`ConcatenatingAudioSource` switch in `just_audio`). | User reports gap between tracks is noticeable in their listening flow. |
| X4c | Crossfade (dual-player infra). | Demand + v2 stability proven. |
| X5 | Cast / Sonos / external player hand-off. | Re-scope decision; high-risk transport work. |
| X6 | Tablet / foldable adaptive layouts. | Re-scope decision; mechanical retrofit across 4 main screens + dialogs. |

---

## Suggested order of attack

1. **V1 + V2** — verify on-device against the home server before declaring v1.4.0 final.
2. **P1 → P4** — v1.5.0 polish band per ROADMAP Phase P.
3. **Q1 → Q4** — v2.0.0 background sync per ROADMAP Phase Q.
4. **X-series remainder** — only after v2.0.0 ships and a re-scoping conversation lands.
