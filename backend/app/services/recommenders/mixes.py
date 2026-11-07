"""Vibe mixes (Phase MX, /PLAN.md §5.2): YouTube Music "Moods & moments"
playlists, personalised by how much each overlaps the user's taste artists.

This module's scoring functions are pure (no I/O) so the rules are testable on
their own; fetching + caching is layered on top (MX3).
"""

import asyncio
import logging
import time
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Any, Protocol, cast

from ytmusicapi import YTMusic

from app.services.recommenders.base import RecommendedTrack, SeedTrack

logger = logging.getLogger(__name__)

# Candidate playlists considered per mood, in YTM's own order (MX3 fetches these).
CANDIDATE_PLAYLISTS = 24
# Best-matching playlists kept; `variant` rotates PICK of them (regenerate).
POOL = 8
PICK = 4
# Artist cap applied by the shared rerank (more than For You's 2: a mix is longer).
PER_ARTIST = 3
# Position decay within a playlist: score / (1 + DECAY * position).
DECAY = 0.02
# Base playlist weight so a zero-affinity (fallback) playlist still ranks tracks.
BASE = 0.5
# Max ytmusicapi calls in flight while fetching a mood's playlists.
FETCH_CONCURRENCY = 4
# Tracks requested per playlist (YTM curated playlists hold ~100).
PLAYLIST_TRACKS = 100
# Mood catalogue + curated playlists change rarely; one fetch a day is plenty.
CACHE_TTL_S = 24 * 3600


@dataclass(frozen=True)
class Vibe:
    id: str
    title: str
    mood: str  # YTM "Moods & moments" category title it is built from


VIBES: list[Vibe] = [
    Vibe("chill", "Chill Mix", "Chill"),
    Vibe("feel-good", "Feel Good Mix", "Feel good"),
    Vibe("party", "Party Mix", "Party"),
    Vibe("romance", "Romance Mix", "Romance"),
    Vibe("heartbreak", "Heartbreak Mix", "Sad"),
    Vibe("workout", "Workout Mix", "Workout"),
    Vibe("focus", "Focus Mix", "Focus"),
    Vibe("sleep", "Sleep Mix", "Sleep"),
]
_VIBES_BY_ID = {v.id: v for v in VIBES}


class MoodNotFound(Exception):
    """The vibe's YTM mood category is gone (renamed upstream / other locale)."""


_Track = tuple[str, str, tuple[str, ...]]  # (videoId, title, artists)


def _norm(name: str) -> str:
    return name.strip().lower()


def _parse(item: Any) -> _Track | None:
    """(videoId, title, artist names) from a ytmusicapi track dict, else None."""
    if not isinstance(item, dict):
        return None
    vid = item.get("videoId")
    title = item.get("title") or ""
    artists = tuple(
        a["name"]
        for a in item.get("artists") or []
        if isinstance(a, dict) and isinstance(a.get("name"), str) and a["name"].strip()
    )
    if not vid or not title or not artists:
        return None
    return vid, title, artists


def _taste_weight(artists: tuple[str, ...], taste: dict[str, float]) -> float:
    return max((taste.get(_norm(a), 0.0) for a in artists), default=0.0)


def taste_profile(seeds: list[SeedTrack]) -> dict[str, float]:
    """artist (lowercased) -> strongest seed weight. Song and artist seeds both count."""
    taste: dict[str, float] = {}
    for s in seeds:
        key = _norm(s.artist)
        if key:
            taste[key] = max(taste.get(key, 0.0), s.weight)
    return taste


def playlist_affinity(items: list[Any], taste: dict[str, float]) -> float:
    """Weighted share of the playlist's tracks by taste artists (any listed artist)."""
    tracks = [t for t in (_parse(i) for i in items) if t is not None]
    if not tracks:
        return 0.0
    return sum(_taste_weight(artists, taste) for _, _, artists in tracks) / len(tracks)


def pick_playlists(
    scored: list[tuple[str, float]], *, variant: int
) -> tuple[list[tuple[str, float]], bool]:
    """Choose PICK of the POOL best (playlist_id, affinity) pairs.

    `scored` is in YTM order; the stable sort keeps that order for ties, so with
    no overlap at all this degrades to YTM's own top picks (personalized=False).
    `variant` rotates through the pool so "regenerate" yields a different mix.
    """
    if not scored:
        return [], False
    pool = sorted(scored, key=lambda p: p[1], reverse=True)[:POOL]
    n = min(PICK, len(pool))
    start = variant * PICK
    chosen = [pool[(start + i) % len(pool)] for i in range(n)]
    return chosen, max(a for _, a in scored) > 0


def score_tracks(
    chosen: list[tuple[float, list[Any]]], taste: dict[str, float]
) -> list[RecommendedTrack]:
    """Rank the chosen playlists' tracks, best first.

    Each listing adds (BASE + affinity) / (1 + DECAY * position) — a track several
    playlists carry accumulates — then the track's taste weight is added once.
    """
    scores: dict[str, float] = {}
    meta: dict[str, tuple[str, tuple[str, ...]]] = {}
    for affinity, items in chosen:
        position = 0
        for item in items:
            parsed = _parse(item)
            if parsed is None:
                continue
            vid, title, artists = parsed
            scores[vid] = scores.get(vid, 0.0) + (BASE + affinity) / (1 + DECAY * position)
            meta.setdefault(vid, (title, artists))
            position += 1
    for vid, (_, artists) in meta.items():
        scores[vid] += _taste_weight(artists, taste)

    ranked = sorted(scores, key=lambda v: scores[v], reverse=True)
    return [
        RecommendedTrack(
            title=meta[v][0],
            artist=meta[v][1][0],
            source_url=f"https://music.youtube.com/watch?v={v}",
            score=scores[v],
        )
        for v in ranked
    ]


# --- fetch + cache (MX3) ---------------------------------------------------


class _YTMoodsLike(Protocol):
    def get_mood_categories(self) -> dict: ...
    def get_mood_playlists(self, params: str) -> list: ...
    def get_playlist(self, playlistId: str, limit: int = 100) -> dict: ...


class TTLCache:
    """Async get-or-load with a per-entry expiry. `now` is injectable for tests.

    ponytail: per-process dict, no locking — two concurrent misses both fetch
    (harmless duplicate YTM call). Redis/shared cache only if workers > 1.
    """

    def __init__(self, ttl_s: float, now: Callable[[], float]) -> None:
        self._ttl = ttl_s
        self._now = now
        self._data: dict[Any, tuple[float, Any]] = {}

    async def get(self, key: Any, load: Callable[[], Awaitable[Any]]) -> Any:
        hit = self._data.get(key)
        if hit is not None and hit[0] > self._now():
            return hit[1]
        value = await load()
        self._data[key] = (self._now() + self._ttl, value)
        return value


@dataclass(frozen=True)
class MixResult:
    vibe_id: str
    title: str
    personalized: bool
    tracks: list[RecommendedTrack]  # ranked, before the per-user rerank


class MixBuilder:
    """Builds a vibe's mix: mood playlists from YTM (cached), scored by taste."""

    def __init__(
        self,
        yt: _YTMoodsLike | None = None,
        *,
        now: Callable[[], float] = time.monotonic,
        ttl_s: float = CACHE_TTL_S,
    ) -> None:
        self._yt: _YTMoodsLike = yt if yt is not None else cast(_YTMoodsLike, YTMusic())
        self._cache = TTLCache(ttl_s, now)

    async def build(self, vibe_id: str, seeds: list[SeedTrack], *, variant: int) -> MixResult:
        vibe = _VIBES_BY_ID[vibe_id]  # KeyError → the route answers 404
        params = await self._mood_params(vibe.mood)
        playlist_ids = await self._mood_playlist_ids(params)

        sem = asyncio.Semaphore(FETCH_CONCURRENCY)

        async def tracks_of(pid: str) -> list[Any] | None:
            async with sem:
                return await self._playlist_tracks(pid)

        fetched = await asyncio.gather(*(tracks_of(p) for p in playlist_ids))
        playlists = {pid: t for pid, t in zip(playlist_ids, fetched, strict=True) if t is not None}

        taste = taste_profile(seeds)
        scored = [(pid, playlist_affinity(t, taste)) for pid, t in playlists.items()]
        chosen, personalized = pick_playlists(scored, variant=variant)
        tracks = score_tracks([(aff, playlists[pid]) for pid, aff in chosen], taste)
        return MixResult(vibe.id, vibe.title, personalized, tracks)

    async def _mood_params(self, mood: str) -> str:
        cats = await self._cache.get(
            ("categories",), lambda: asyncio.to_thread(self._yt.get_mood_categories)
        )
        for items in (cats or {}).values():
            for item in items or []:
                if isinstance(item, dict) and item.get("title") == mood and item.get("params"):
                    return str(item["params"])
        raise MoodNotFound(mood)

    async def _mood_playlist_ids(self, params: str) -> list[str]:
        items = await self._cache.get(
            ("mood", params), lambda: asyncio.to_thread(self._yt.get_mood_playlists, params)
        )
        ids = [i["playlistId"] for i in items or [] if isinstance(i, dict) and i.get("playlistId")]
        return ids[:CANDIDATE_PLAYLISTS]

    async def _playlist_tracks(self, playlist_id: str) -> list[Any] | None:
        """The playlist's track dicts, or None on failure (not cached: retried next time)."""
        try:
            page = await self._cache.get(
                ("playlist", playlist_id),
                lambda: asyncio.to_thread(
                    self._yt.get_playlist, playlist_id, limit=PLAYLIST_TRACKS
                ),
            )
        except Exception as exc:
            logger.warning("ytmusic.get_playlist failed for %s: %s", playlist_id, exc)
            return None
        return list((page or {}).get("tracks") or [])
