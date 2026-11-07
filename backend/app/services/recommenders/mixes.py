"""Vibe mixes (Phase MX, /PLAN.md §5.2): YouTube Music "Moods & moments"
playlists, personalised by how much each overlaps the user's taste artists.

This module's scoring functions are pure (no I/O) so the rules are testable on
their own; fetching + caching is layered on top (MX3).
"""

from typing import Any

from app.services.recommenders.base import RecommendedTrack, SeedTrack

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
