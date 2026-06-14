import asyncio
import logging
from typing import Any, Protocol, cast

from ytmusicapi import YTMusic

logger = logging.getLogger(__name__)


class _YTMusicLike(Protocol):
    def search(
        self, query: str, filter: str | None = None, limit: int = 20
    ) -> list[dict]: ...


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
