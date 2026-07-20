# PODCASTS.md — Podcast discovery + download (feasibility + plan)

Status: **SHIPPED** (backend P1–P6, Android PC1–PC5, `v5.0.0`). Drafted 2026-07-20 as a
pre-implementation plan; kept as-is below for historical context except where noted — see
`DECISIONLOG.md` for what actually shipped and where it deviated from this plan.
Tracking issue: [#53](https://github.com/aashish900/heerr/issues/53).
Scope decision (locked by owner): **Full podcast model** + **Podcast Index / RSS** discovery.

> **2026-07-20 update:** discovery was swapped from Podcast Index to **Apple's iTunes Search
> API** after Podcast Index's signup form began rejecting free-email-provider addresses (no key
> was ever obtained). Every "Podcast Index" reference below is the original plan, kept for
> history — the shipped discovery source is iTunes Search (`app/services/podcast_search.py`).
> See `DECISIONLOG.md` 2026-07-20 "Podcast discovery: Podcast Index -> iTunes Search."

> **2026-07-20 update:** a user-supplied design ("Podcast Flow") triggered a follow-on redesign
> round (Android Phase PR + backend Phase PA) promoting podcasts to a first-class Library/Home
> surface. Backend Phase PA (`v5.3.0`) added `GET /podcasts/episodes` (cross-subscription feeds)
> and a `sort` param on the per-channel episode list — both in `app/api/v1/podcasts.py`. See
> `DECISIONLOG.md` 2026-07-20 "PA1/PA2: podcast aggregate feeds."

This is a cross-cutting feature (backend backbone + Android client). It lives here because
backend-first is the project rule (`/CLAUDE.md` §3). Android phases depend on the backend
endpoints existing and curl-testable first.

Roadmap entries: backend **Phase P (P1–P6)** in `backend/docs/ROADMAP.md`; Android
**Phase PC (PC1–PC5)** in `android/docs/ROADMAP.md`. This doc is the design rationale behind them.

---

## 1. Feasibility verdict

**Feasible.** Discovery and download are *easier* than the existing music path. The cost is that
**Navidrome supplies zero podcast semantics**, so podcast subscriptions / episode ordering /
played-state / resume must be built by us as a first-class model. This is a real feature (~a
dozen phases across backend + app), not a bolt-on.

### Grounded facts

- Navidrome does **not** implement the Subsonic podcast API server-side. Issue
  [navidrome#793](https://github.com/navidrome/navidrome/issues/793) is `OPEN` (verified via
  `gh issue view`); [PrivacyTools review](https://privacytools.io/app/navidrome) states "no
  podcast support" server-side. → We cannot reuse the Navidrome/Subsonic streaming path for
  podcasts. **The backend must own podcast metadata, storage, and audio serving.**
- Podcast enclosures in RSS are direct audio URLs → download is a plain streamed `httpx` GET.
  No spotDL, no yt-dlp, no venv isolation for the podcast path.
- Podcast Index API is free/open (requires a registered key+secret, HMAC-SHA1 auth header).

### Why NOT the existing pipeline

- `/data/media/music` is Navidrome-watched. Anything written there is indexed as a **song**.
  Podcast episodes there = loose tracks with no feed grouping/ordering/progress. Rejected.
- spotDL/yt-dlp extraction is for YouTube Music `videoId`s. RSS enclosures are already direct
  audio — extraction machinery is unnecessary for this path.

---

## 2. Architecture

### 2.1 New data model (Postgres, Alembic migration)

Channel/episode **metadata is shared** (dedupe by normalized `feed_url`); **subscription and
progress are per-user** — mirrors the existing "shared library, per-user isolation" pattern
(CONTEXT.md Phase J).

- `podcast_channel` — `id`, `feed_url` (unique, normalized), `title`, `author`, `description`,
  `image_url`, `categories`, `last_fetched_at`, `http_etag`, `http_last_modified`.
- `podcast_episode` — `id`, `channel_id` FK, `guid` (unique per channel), `title`,
  `description`, `published_at`, `duration_s`, `enclosure_url`, `enclosure_type`,
  `enclosure_bytes`, `image_url`, `episode_no`, `season_no`, `downloaded_path` (nullable),
  `downloaded_bytes` (nullable), `downloaded_at` (nullable). Download state is **shared** (one
  file on disk), like music files.
- `podcast_subscription` — (`user_id`, `channel_id`) unique, `subscribed_at`. Per-user.
- `podcast_progress` — (`user_id`, `episode_id`) unique, `position_s`, `played` bool,
  `last_played_at`. Per-user.

### 2.2 Discovery — Podcast Index

- New service `app/services/podcastindex.py`: search shows, lookup feed by id. HMAC-SHA1 auth.
- New env: `PODCASTINDEX_KEY`, `PODCASTINDEX_SECRET` (`.env` / `.env.example`; never committed).
- Tests mock at the service boundary via `dependency_overrides`, same pattern as
  `get_ytmusic_client` (`tests/test_search.py`).

### 2.3 Feed ingest — RSS

- New service `app/services/feeds.py` using `feedparser`. On subscribe / refresh: conditional
  GET (`If-None-Match` / `If-Modified-Since` from stored etag/last-modified), parse, upsert
  channel + episodes (dedupe by `guid`). Cap ingest (e.g. newest N episodes) — some feeds carry
  thousands.
- Refresh policy v1: **on-demand** (subscribe, open-channel, manual refresh endpoint). No
  periodic scheduler yet — consistent with "no Celery until outgrown" (`backend/CLAUDE.md`).

### 2.4 Download

- New dir `PODCAST_OUTPUT_DIR` (e.g. `/data/media/podcasts`), **NOT** Navidrome-watched. Add to
  compose mount + `.env.example`.
- Worker streams `enclosure_url` → temp → fsync → move into `PODCAST_OUTPUT_DIR`; set
  `downloaded_*` columns.
- **Reuse the existing job queue** (`jobs` table + BackgroundTasks + Sync Center/`/queue` UI) by
  adding a `kind` discriminator (`song` | `episode`) and a nullable `episode_id`. This reuses
  the whole existing progress/polling UX rather than inventing a parallel one.
  - Alternative considered: track download state solely on `podcast_episode` with a separate
    poll endpoint. Rejected v1 — duplicates the queue UX the app already has.

### 2.5 Audio serving (the piece Navidrome can't give us)

- **Downloaded episode:** `GET /podcasts/episodes/{id}/audio` streams the local file with **HTTP
  Range** support (required for seek + resume). Bearer-auth like `/preview/stream`; token may
  ride in `?token=` for `just_audio` (same constraint as preview, CONTEXT.md Phase K).
- **Stream-on-demand (not downloaded):** hand the app the public `enclosure_url` directly. It's a
  public podcast MP3 — the device fetching it is a normal HTTP GET and does **not** expose the
  backend, so it does not violate the Tailscale-only rule (that rule protects backend ingress).
  - Alternative: proxy through the backend like preview. Rejected v1 — adds load/complexity for
    no security gain on already-public URLs. Revisit if a feed needs auth headers.

---

## 3. Backend phases (P1–P6) — build in order, TDD, curl-testable each

| Phase | Deliverable | Key gate |
|---|---|---|
| **P1** | Data model + Alembic migration (4 tables). No endpoints. | `alembic upgrade head` clean; constraints proven; `compare_metadata` clean. |
| **P2** | `app/services/podcastindex.py` + `POST /api/v1/podcasts/search` (scope `read`). Env keys. | search returns channels; service mocked; 401/403; upstream fail → 502. |
| **P3** | `feedparser` ingest + subscribe / unsubscribe / list subscriptions (per-user). | subscribe upserts + dedupes; shared channel across users; unsubscribe scoped. |
| **P4** | `GET …/channels/{id}/episodes` (paginated, w/ progress + downloaded) + `POST …/refresh`. | pagination; 304 short-circuits; new episodes appear. |
| **P5** | Episode download worker + `POST …/episodes/{id}/download`; job `kind` discriminator; in `/queue`. | enclosure → `PODCAST_OUTPUT_DIR`; `/queue` reflects it; dedupe idempotency. |
| **P6** | `GET …/episodes/{id}/audio` (Range) + `PUT …/progress`; enclosure passthrough; docs + `v5.0.0`. | Range/206 + 416; resume round-trips; played flag; home-server smoke. |

Cross-cutting per phase: log `username`, never log tokens; append DECISIONLOG ADR + CHANGELOG;
`poetry run pytest` green before/after; ruff + mypy clean.

## 4. Android phases (PC1–PC5) — after the backend endpoints exist

Reuse the locked stack (dio/riverpod/freezed/go_router). Each is a pure-client slice.

| Phase | Backend prereq | Deliverable |
|---|---|---|
| **PC1** | P2–P4 | Freezed models (`PodcastChannel/Episode/Subscription/EpisodeProgress`) + `endpoints.dart` + dio API wrapper. |
| **PC2** | P2, P3 | Discover screen (search Podcast Index) + subscribe/unsubscribe. |
| **PC3** | P3, P4 | Subscriptions screen + Channel-detail episode list (played badge, resume, published date). |
| **PC4** | P5 | Episode download → reuse Sync Center/queue UI. Offline (`file://`) vs stream selection. |
| **PC5** | P6 | Player integration (4th `MediaItem` kind); throttled progress `PUT` (~15 s + pause/stop); "Podcasts" nav; docs + `v5.0.0`. |

## 5. Risks / open items

- **Player URI kind:** episodes are a 4th `MediaItem.id` kind. Must support seek/resume, which the
  ephemeral preview proxy does not — P6's audio endpoint must implement Range. (android ROADMAP.)
- **Podcast Index key:** free registration at podcastindex.org required before P2 smoke.
- **Feed size / bad feeds:** cap ingest, tolerate malformed RSS, handle redirected/dead enclosures.
- **Version bump:** large feature → suggest `v5.0.0` (owner to confirm). Version-sync rule applies
  across all 5 locations at implementation time (`/CLAUDE.md` §3), not now.
- **Progress conflict:** last-write-wins per (user, episode) is fine for single-device v1.

## 6. Explicitly out of scope (v1 of this feature)

- Periodic/background auto-refresh scheduler (on-demand only).
- OPML import/export.
- Chapters, transcripts, per-episode artwork extraction.
- Variable playback speed (app-side later; not a backend concern).
- Auto-download of new episodes on subscribe.
- Proxying on-demand streams through the backend.
