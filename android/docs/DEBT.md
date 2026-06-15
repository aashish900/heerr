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

---

## 3. Functional gaps in v1.4.0

Real missing features; in-scope (not listed in ROADMAP "out of scope").

| # | Item | Effort | Notes |
|---|------|--------|-------|
| F1 | Cover art on `HomeRecommendationCard` — placeholder swatch in v1. | Low | One `getSong.view` per row at render; throttle to avoid N parallel requests. Named as deferred in `CHANGELOG.md` O4 "not done". |
| F2 | Find Similar long-press on **album-detail** and **playlist-detail** song rows. | Low | Only library-search surface currently routes through `AddToPlaylistSheet` with `findSimilarSeed`. Mechanical to add; `CHANGELOG.md` N5 "not done" flags it explicitly. |

---

## 4. v2 candidates (currently out-of-scope)

Items listed in ROADMAP `## Out of scope` — do not implement without a DECISIONLOG entry re-scoping them.

| # | Item | Unlock condition |
|---|------|-----------------|
| X1 | WorkManager / true background sync (offline downloads foreground-only in v1). | User reports foreground-only window is insufficient. |
| X2 | Persist "Now Playing" queue across cold starts. | User reports the cold-start drop is a friction point. |
| X3 | Lyrics — `getLyrics.view` exists in Subsonic 1.16; cheap to add. | Re-scope decision. |
| X4 | Sleep timer / gapless playback / crossfade. | Re-scope decision. |
| X5 | Cast / Sonos / external player hand-off. | Re-scope decision. |
| X6 | Tablet / foldable adaptive layouts. | Re-scope decision. |

---

## Suggested order of attack

1. **V1 + V2** — verify on-device against the home server before declaring v1.4.0 final.
2. **F1, F2** — polish passes, each under half a day.
3. **X-series** — only after a user-driven re-scoping conversation.
