import asyncio
from dataclasses import dataclass
from functools import lru_cache

from ytmusicapi import YTMusic


class YTMusicError(Exception):
    pass


@dataclass(frozen=True)
class YTMusicResult:
    source_url: str
    source_type: str  # 'song' | 'album' | 'playlist'
    title: str
    artist: str
    album: str | None
    duration_ms: int | None
    cover_url: str | None


class YTMusicClient:
    def __init__(self) -> None:
        self._yt = YTMusic()

    async def search(self, query: str, type_: str, limit: int) -> list[YTMusicResult]:
        filter_map = {"song": "songs", "album": "albums", "playlist": "playlists"}
        filter_ = filter_map.get(type_, "songs")

        def _search() -> list[dict]:
            return self._yt.search(query, filter=filter_, limit=limit)  # type: ignore[arg-type]

        try:
            raw: list[dict] = await asyncio.to_thread(_search)
        except Exception as exc:
            raise YTMusicError(str(exc)) from exc
        results = [self._parse(item, type_) for item in raw[:limit]]
        return [r for r in results if r is not None]

    def _parse(self, item: dict, type_: str) -> YTMusicResult | None:
        thumbnails: list[dict] = item.get("thumbnails") or []
        cover = thumbnails[-1]["url"] if thumbnails else None

        if type_ == "song":
            video_id = item.get("videoId")
            if not video_id:
                return None
            artists: list[dict] = item.get("artists") or []
            artist = artists[0]["name"] if artists else ""
            album_info: dict = item.get("album") or {}
            duration_s: int = item.get("duration_seconds") or 0
            return YTMusicResult(
                source_url=f"https://www.youtube.com/watch?v={video_id}",
                source_type="song",
                title=item.get("title", ""),
                artist=artist,
                album=album_info.get("name"),
                duration_ms=duration_s * 1000 if duration_s else None,
                cover_url=cover,
            )
        if type_ == "album":
            browse_id = item.get("browseId")
            if not browse_id:
                return None
            artists = item.get("artists") or []
            artist = artists[0]["name"] if artists else ""
            return YTMusicResult(
                source_url=f"https://music.youtube.com/browse/{browse_id}",
                source_type="album",
                title=item.get("title", ""),
                artist=artist,
                album=None,
                duration_ms=None,
                cover_url=cover,
            )
        if type_ == "playlist":
            browse_id = item.get("browseId")
            if not browse_id:
                return None
            return YTMusicResult(
                source_url=f"https://music.youtube.com/browse/{browse_id}",
                source_type="playlist",
                title=item.get("title", ""),
                artist=item.get("author", ""),
                album=None,
                duration_ms=None,
                cover_url=cover,
            )
        return None


@lru_cache(maxsize=1)
def get_ytmusic_client() -> YTMusicClient:
    return YTMusicClient()
