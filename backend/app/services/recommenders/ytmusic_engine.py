import asyncio
import logging
from itertools import zip_longest
from typing import Any, Protocol, cast
from urllib.parse import parse_qs, urlparse

from ytmusicapi import YTMusic

from app.services.recommenders.base import RecommendedTrack, SeedTrack

logger = logging.getLogger(__name__)


class _YTMusicLike(Protocol):
    def get_watch_playlist(self, videoId: str, **kwargs: Any) -> dict: ...
    def search(self, query: str, filter: str | None = None, limit: int = 20) -> list[dict]: ...
    def get_song_related(self, browseId: str) -> list: ...
    def get_artist(self, channelId: str) -> dict: ...


# Max ytmusicapi calls in flight per request (they run in worker threads).
# ponytail: no response cache; 8 seeds measured 2.5-5.9s (one 11s outlier). Add a
# per-videoId/artist TTL cache if RX7/on-device refreshes routinely exceed ~6s.
_CONCURRENCY = 4
# Rank decay within one seed's list: score += weight / (1 + _DECAY * rank).
_DECAY = 0.1
# The only get_song_related shelf that holds *other* songs. "Other performances"
# is covers/mashups of the seed itself (RX4). ytmusicapi defaults to language="en".
_RELATED_SHELF = "You might also like"

_Candidate = tuple[str, str, str]  # (videoId, title, artist)


def _candidates(items: Any) -> list[_Candidate]:
    """Valid (videoId, title, first artist) triples from a list of ytmusicapi items."""
    if not isinstance(items, list):  # e.g. "About the artist" shelf has str contents
        return []
    out: list[_Candidate] = []
    for item in items:
        if not isinstance(item, dict):
            continue
        vid = item.get("videoId")
        title = item.get("title") or ""
        artists = item.get("artists") or []
        artist = artists[0].get("name", "") if artists and isinstance(artists[0], dict) else ""
        if vid and title and artist:
            out.append((vid, title, artist))
    return out


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
    """Zero-credential recommendation engine backed by ytmusicapi (RX6).

    Every seed is expanded concurrently (at most `_CONCURRENCY` calls in flight):
      - song seed: resolve its videoId (from `source_url`, else `search(filter='songs')`),
        then the watch-playlist radio interleaved with the "You might also like"
        related shelf, deduped;
      - artist seed (`title is None`): `search(filter='artists')` -> `get_artist`
        top songs.
    Each candidate scores `sum(seed.weight / (1 + 0.1 * rank))` over the seeds that
    produced it, so tracks several seeds agree on rank first. Seed videos are never
    returned. Per-user filtering / artist cap happen later, in `rerank`.
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
        if not seeds:
            return []
        sem = asyncio.Semaphore(_CONCURRENCY)

        async def call(fn: Any, *args: Any, **kwargs: Any) -> Any:
            async with sem:
                return await asyncio.to_thread(fn, *args, **kwargs)

        expanded = await asyncio.gather(*(self._expand(s, call) for s in seeds))

        seed_vids = {vid for vid, _ in expanded if vid}
        scores: dict[str, float] = {}
        meta: dict[str, tuple[str, str]] = {}
        for (_, cands), seed in zip(expanded, seeds, strict=True):
            # Rank among real candidates only: the radio lists the seed itself first (RX4).
            kept = [c for c in cands if c[0] not in seed_vids]
            for rank, (vid, title, artist) in enumerate(kept):
                scores[vid] = scores.get(vid, 0.0) + seed.weight / (1 + _DECAY * rank)
                meta.setdefault(vid, (title, artist))

        # sorted() is stable: ties keep first-seen (seed order, then rank) order.
        ranked = sorted(scores, key=lambda v: scores[v], reverse=True)[:limit]
        return [
            RecommendedTrack(
                title=meta[v][0],
                artist=meta[v][1],
                source_url=f"https://music.youtube.com/watch?v={v}",
                score=scores[v],
            )
            for v in ranked
        ]

    async def _expand(self, seed: SeedTrack, call: Any) -> tuple[str | None, list[_Candidate]]:
        """(seed videoId or None, ordered deduped candidates). Never raises."""
        try:
            if seed.title is None:
                return None, await self._artist_songs(seed.artist, call)
            video_id = _video_id_from_url(seed.source_url) or await self._resolve_via_search(
                seed, call
            )
            if video_id is None:
                return None, []
            return video_id, await self._song_neighbours(video_id, call)
        except Exception as exc:
            logger.warning("ytmusic seed %r/%r failed: %s", seed.artist, seed.title, exc)
            return None, []

    async def _song_neighbours(self, video_id: str, call: Any) -> list[_Candidate]:
        watch = await call(self._yt.get_watch_playlist, videoId=video_id)
        radio = _candidates(watch.get("tracks"))
        related: list[_Candidate] = []
        if watch.get("related"):
            try:
                shelves = await call(self._yt.get_song_related, watch["related"])
            except Exception as exc:
                logger.warning("ytmusic.get_song_related failed for %s: %s", video_id, exc)
                shelves = []
            for shelf in shelves or []:
                if isinstance(shelf, dict) and shelf.get("title") == _RELATED_SHELF:
                    related = _candidates(shelf.get("contents"))
                    break
        # Interleave so the curated related shelf isn't buried behind 50 radio tracks;
        # dedupe within the seed so one seed can't vote twice for a track.
        out: list[_Candidate] = []
        seen: set[str] = set()
        for pair in zip_longest(radio, related):
            for c in pair:
                if c is not None and c[0] not in seen:
                    seen.add(c[0])
                    out.append(c)
        return out

    async def _artist_songs(self, artist: str, call: Any) -> list[_Candidate]:
        hits = await call(self._yt.search, artist, filter="artists", limit=1)
        browse_id = hits[0].get("browseId") if hits and isinstance(hits[0], dict) else None
        if not browse_id:
            return []
        page = await call(self._yt.get_artist, browse_id)
        return _candidates((page.get("songs") or {}).get("results"))

    async def _resolve_via_search(self, seed: SeedTrack, call: Any) -> str | None:
        query = f"{seed.artist} {seed.title}".strip()
        if not query:
            return None
        try:
            results = await call(self._yt.search, query, filter="songs", limit=1)
        except Exception as exc:
            logger.warning("ytmusic.search failed for %r: %s", query, exc)
            return None
        if not results:
            return None
        first = results[0]
        vid = first.get("videoId") if isinstance(first, dict) else None
        return vid if isinstance(vid, str) and vid else None
