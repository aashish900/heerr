import asyncio
import logging
from typing import Any, Protocol

import httpx

from app.services.recommenders.base import RecommendedTrack, SeedTrack
from app.services.recommenders.yt_resolver import YTMusicResolver, YTResolver

logger = logging.getLogger(__name__)

# Baseline weight assigned to artist.getTopTracks results (no upstream `match`
# score). Kept well below the typical track.getSimilar matches so similar-track
# results outrank same-artist broadening when both exist.
_ARTIST_TOP_WEIGHT = 0.05

_TRACK_SIMILAR_LIMIT = 20
_ARTIST_TOP_LIMIT = 10
_USER_TOP_LIMIT = 10
_USER_TOP_PERIOD = "1month"


class _LastFMClient(Protocol):
    async def track_get_similar(
        self, artist: str, title: str, limit: int
    ) -> list[dict]: ...

    async def artist_get_top_tracks(
        self, artist: str, limit: int
    ) -> list[dict]: ...

    async def user_get_top_tracks(
        self, user: str, period: str, limit: int
    ) -> list[dict]: ...


class LastFMHTTPClient:
    """Async wrapper around the Last.fm 2.0 REST API.

    Production implementation. Tests should typically inject a fake conforming
    to the `_LastFMClient` protocol instead — wire-format coverage is light by
    design.
    """

    _BASE = "https://ws.audioscrobbler.com/2.0/"

    def __init__(
        self,
        api_key: str,
        http: httpx.AsyncClient | None = None,
    ) -> None:
        self._api_key = api_key
        self._http = http if http is not None else httpx.AsyncClient(timeout=10.0)

    async def _call(self, method: str, **params: Any) -> dict:
        query: dict[str, Any] = {
            "method": method,
            "api_key": self._api_key,
            "format": "json",
            **params,
        }
        r = await self._http.get(self._BASE, params=query)
        r.raise_for_status()
        data: dict = r.json()
        return data

    async def track_get_similar(
        self, artist: str, title: str, limit: int
    ) -> list[dict]:
        data = await self._call(
            "track.getSimilar", artist=artist, track=title, limit=limit
        )
        block = data.get("similartracks") or {}
        return block.get("track") or []

    async def artist_get_top_tracks(
        self, artist: str, limit: int
    ) -> list[dict]:
        data = await self._call("artist.getTopTracks", artist=artist, limit=limit)
        block = data.get("toptracks") or {}
        return block.get("track") or []

    async def user_get_top_tracks(
        self, user: str, period: str, limit: int
    ) -> list[dict]:
        data = await self._call(
            "user.getTopTracks", user=user, period=period, limit=limit
        )
        block = data.get("toptracks") or {}
        return block.get("track") or []


def _seed_key(artist: str, title: str) -> tuple[str, str]:
    return artist.strip().lower(), title.strip().lower()


def _parse_match(raw: Any) -> float:
    try:
        return float(raw) if raw is not None else 0.0
    except (TypeError, ValueError):
        return 0.0


def _track_fields(item: dict) -> tuple[str, str]:
    title = item.get("name") or ""
    artist_block = item.get("artist") or {}
    artist = artist_block.get("name") if isinstance(artist_block, dict) else ""
    return artist or "", title


class LastFMEngine:
    """Last.fm-backed recommendation engine.

    Per seed: fires `track.getSimilar` (primary, match-weighted) and
    `artist.getTopTracks` (broadening, baseline weight) in parallel. When
    `username` is set, seeds are augmented with `user.getTopTracks?period=1month`
    so the engine can produce results without any client-supplied seeds.

    Final candidate list is deduped by case-insensitive (artist, title),
    sorted by max-match desc, then resolved to `music.youtube.com` URLs via
    the injected `YTResolver`. Unresolvable candidates are dropped; the rest
    is capped at `limit`.
    """

    name = "lastfm"

    def __init__(
        self,
        api_key: str,
        username: str | None = None,
        client: _LastFMClient | None = None,
        resolver: YTResolver | None = None,
    ) -> None:
        if not api_key:
            raise RuntimeError("LastFMEngine requires LASTFM_API_KEY")
        self._client: _LastFMClient = (
            client if client is not None else LastFMHTTPClient(api_key)
        )
        self._resolver: YTResolver = (
            resolver if resolver is not None else YTMusicResolver()
        )
        self._username = username

    async def probe(self) -> bool:
        # Hit one cheap Last.fm endpoint to verify the API key is valid and
        # the service is reachable. `track.getSimilar` for a guaranteed-popular
        # song with limit=1 is the smallest documented call.
        try:
            await self._client.track_get_similar("The Beatles", "Hey Jude", 1)
            return True
        except Exception as exc:
            logger.warning("lastfm probe failed: %s", exc)
            return False

    async def health_chain(self) -> list[tuple[str, bool]]:
        return [(self.name, await self.probe())]

    async def recommend(
        self, seeds: list[SeedTrack], limit: int
    ) -> list[RecommendedTrack]:
        all_seeds: list[SeedTrack] = list(seeds)

        if self._username:
            try:
                user_tracks = await self._client.user_get_top_tracks(
                    self._username, _USER_TOP_PERIOD, _USER_TOP_LIMIT
                )
            except Exception as exc:
                logger.warning(
                    "lastfm.user_get_top_tracks failed for %s: %s",
                    self._username,
                    exc,
                )
                user_tracks = []
            for t in user_tracks:
                artist, title = _track_fields(t)
                if artist and title:
                    all_seeds.append(SeedTrack(title=title, artist=artist))

        # Dedupe seeds and pre-seed self-exclusion set.
        seen_seeds: set[tuple[str, str]] = set()
        unique_seeds: list[SeedTrack] = []
        for s in all_seeds:
            key = _seed_key(s.artist, s.title)
            if key in seen_seeds:
                continue
            seen_seeds.add(key)
            unique_seeds.append(s)

        if not unique_seeds:
            return []

        per_seed = await asyncio.gather(
            *(self._fetch_for_seed(s) for s in unique_seeds),
            return_exceptions=True,
        )

        candidates: dict[tuple[str, str], tuple[str, str, float]] = {}
        for result in per_seed:
            if isinstance(result, BaseException):
                continue
            for artist, title, match in result:
                key = _seed_key(artist, title)
                if key in seen_seeds:
                    continue
                existing = candidates.get(key)
                if existing is None or existing[2] < match:
                    candidates[key] = (artist, title, match)

        ranked = sorted(candidates.values(), key=lambda x: x[2], reverse=True)

        out: list[RecommendedTrack] = []
        for artist, title, match in ranked:
            if len(out) >= limit:
                break
            url = await self._resolver.resolve(artist, title)
            if url is None:
                continue
            out.append(
                RecommendedTrack(
                    title=title, artist=artist, source_url=url, score=match
                )
            )
        return out

    async def _fetch_for_seed(
        self, seed: SeedTrack
    ) -> list[tuple[str, str, float]]:
        async def _similar() -> list[dict]:
            try:
                return await self._client.track_get_similar(
                    seed.artist, seed.title, _TRACK_SIMILAR_LIMIT
                )
            except Exception as exc:
                logger.warning(
                    "lastfm.track_get_similar failed for %s/%s: %s",
                    seed.artist,
                    seed.title,
                    exc,
                )
                return []

        async def _top() -> list[dict]:
            try:
                return await self._client.artist_get_top_tracks(
                    seed.artist, _ARTIST_TOP_LIMIT
                )
            except Exception as exc:
                logger.warning(
                    "lastfm.artist_get_top_tracks failed for %s: %s",
                    seed.artist,
                    exc,
                )
                return []

        similar, top = await asyncio.gather(_similar(), _top())

        results: list[tuple[str, str, float]] = []
        for t in similar:
            artist, title = _track_fields(t)
            if not artist or not title:
                continue
            results.append((artist, title, _parse_match(t.get("match"))))
        for t in top:
            artist, title = _track_fields(t)
            if not artist or not title:
                continue
            results.append((artist, title, _ARTIST_TOP_WEIGHT))
        return results
