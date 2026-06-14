import asyncio
import logging
from typing import Any, Protocol, cast
from urllib.parse import parse_qs, urlparse

from ytmusicapi import YTMusic

from app.services.recommenders.base import RecommendedTrack, SeedTrack

logger = logging.getLogger(__name__)


class _YTMusicLike(Protocol):
    def get_watch_playlist(self, videoId: str, **kwargs: Any) -> dict: ...
    def search(self, query: str, filter: str | None = None, limit: int = 20) -> list[dict]: ...


def _video_id_from_url(url: str | None) -> str | None:
    if not url:
        return None
    try:
        parsed = urlparse(url)
    except ValueError:
        return None
    if "youtube.com" not in parsed.netloc:
        return None
    if parsed.path != "/watch":
        return None
    vs = parse_qs(parsed.query).get("v")
    return vs[0] if vs else None


class YTMusicEngine:
    """Zero-credential recommendation engine backed by ytmusicapi.

    For each seed: resolves the seed's YouTube videoId (from `source_url` when
    it points at `music.youtube.com/watch?v=…`, otherwise via a single
    `search(filter='songs', limit=1)` call). Calls `get_watch_playlist(videoId)`
    to fetch related tracks and accumulates results deduped by videoId, capped
    at `limit`.
    """

    name = "ytmusic"

    def __init__(self, yt: _YTMusicLike | None = None) -> None:
        self._yt: _YTMusicLike = yt if yt is not None else cast(_YTMusicLike, YTMusic())

    async def probe(self) -> bool:
        # ytmusicapi has no auth; the library is instantiable offline. There is
        # no cheap network call that proves YouTube Music is reachable from the
        # container that wouldn't add latency on every health poll, so we treat
        # the engine as always-available and let actual recommend() calls
        # surface upstream failures.
        return True

    async def health_chain(self) -> list[tuple[str, bool]]:
        return [(self.name, await self.probe())]

    async def recommend(self, seeds: list[SeedTrack], limit: int) -> list[RecommendedTrack]:
        seen: set[str] = set()
        out: list[RecommendedTrack] = []

        for seed in seeds:
            if len(out) >= limit:
                break
            video_id = _video_id_from_url(seed.source_url)
            if video_id is None:
                video_id = await self._resolve_via_search(seed)
            if video_id is None:
                continue
            # Don't recommend the seed itself.
            seen.add(video_id)

            try:
                watch = await asyncio.to_thread(self._yt.get_watch_playlist, videoId=video_id)
            except Exception as exc:
                logger.warning("ytmusic.get_watch_playlist failed for %s: %s", video_id, exc)
                continue

            for track in watch.get("tracks") or []:
                if len(out) >= limit:
                    break
                vid = track.get("videoId")
                if not vid or vid in seen:
                    continue
                title = track.get("title") or ""
                artists = track.get("artists") or []
                artist_name = (
                    artists[0].get("name", "") if artists and isinstance(artists[0], dict) else ""
                )
                if not title or not artist_name:
                    continue
                seen.add(vid)
                out.append(
                    RecommendedTrack(
                        title=title,
                        artist=artist_name,
                        source_url=f"https://music.youtube.com/watch?v={vid}",
                        score=None,
                    )
                )

        return out

    async def _resolve_via_search(self, seed: SeedTrack) -> str | None:
        query = f"{seed.artist} {seed.title}".strip()
        if not query:
            return None
        try:
            results = await asyncio.to_thread(self._yt.search, query, filter="songs", limit=1)
        except Exception as exc:
            logger.warning("ytmusic.search failed for %r: %s", query, exc)
            return None
        if not results:
            return None
        first = results[0]
        vid = first.get("videoId") if isinstance(first, dict) else None
        return vid if isinstance(vid, str) and vid else None
