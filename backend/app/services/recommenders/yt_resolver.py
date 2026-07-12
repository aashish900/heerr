import asyncio
import logging
from typing import Any, Protocol, cast
from urllib.parse import parse_qs, urlparse

from ytmusicapi import YTMusic

logger = logging.getLogger(__name__)


def cover_url_for_source_url(source_url: str) -> str | None:
    """Public cover-art URL for a resolved `watch?v=<id>` source URL.

    Server-side counterpart of what the client used to derive locally —
    resolving here keeps upstream host knowledge out of the client binary.
    Returns None for empty/unparseable URLs or non-watch URLs (e.g. album
    `browse/` URLs), in which case the client falls back to its placeholder.
    """
    if not source_url:
        return None
    try:
        parsed = urlparse(source_url)
    except ValueError:
        return None
    host = parsed.netloc.lower()
    video_id: str | None = None
    if host.endswith("youtu.be"):
        video_id = parsed.path.lstrip("/").split("/")[0] or None
    elif host.endswith("youtube.com"):
        video_id = (parse_qs(parsed.query).get("v") or [None])[0]
    if not video_id:
        return None
    return f"https://img.youtube.com/vi/{video_id}/mqdefault.jpg"


class _YTMusicLike(Protocol):
    def search(self, query: str, filter: str | None = None, limit: int = 20) -> list[dict]: ...


class YTResolver(Protocol):
    """Resolves (artist, title) pairs to playable `music.youtube.com` URLs.

    Used by recommendation engines whose upstream APIs (Last.fm, ListenBrainz)
    return raw artist + title strings: the downloader pipeline (spotDL) needs
    a YouTube Music URL, so every result is resolved before it leaves the
    engine.
    """

    async def resolve(self, artist: str, title: str) -> str | None: ...


class YTMusicResolver:
    def __init__(self, yt: _YTMusicLike | None = None) -> None:
        self._yt: _YTMusicLike = yt if yt is not None else cast(_YTMusicLike, YTMusic())

    async def resolve(self, artist: str, title: str) -> str | None:
        query = f"{artist} {title}".strip()
        if not query:
            return None
        try:
            results: list[dict] = await asyncio.to_thread(
                self._yt.search, query, filter="songs", limit=1
            )
        except Exception as exc:
            logger.warning("ytmusic.search failed for %r: %s", query, exc)
            return None
        if not results:
            return None
        first: Any = results[0]
        if not isinstance(first, dict):
            return None
        vid = first.get("videoId")
        if not isinstance(vid, str) or not vid:
            return None
        return f"https://music.youtube.com/watch?v={vid}"
