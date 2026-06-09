import time
from dataclasses import dataclass
from functools import lru_cache

import httpx

from app.config import get_settings

_TOKEN_URL = "https://accounts.spotify.com/api/token"
_SEARCH_URL = "https://api.spotify.com/v1/search"
_REFRESH_MARGIN_SEC = 60
_HTTP_TIMEOUT_SEC = 10.0


@dataclass(frozen=True)
class SpotifyResult:
    spotify_uri: str
    spotify_url: str
    title: str
    artist: str
    album: str | None
    duration_ms: int | None
    cover_url: str | None


class SpotifyError(Exception):
    pass


class SpotifyRateLimited(SpotifyError):
    def __init__(self, retry_after: int):
        super().__init__(f"Spotify rate limited; retry after {retry_after}s")
        self.retry_after = retry_after


class SpotifyClient:
    def __init__(
        self,
        client_id: str,
        client_secret: str,
        *,
        transport: httpx.AsyncBaseTransport | None = None,
    ):
        self._client_id = client_id
        self._client_secret = client_secret
        self._token: str | None = None
        self._expires_at: float = 0.0
        self._transport = transport

    def _make_http(self) -> httpx.AsyncClient:
        return httpx.AsyncClient(transport=self._transport, timeout=_HTTP_TIMEOUT_SEC)

    async def _get_token(self, http: httpx.AsyncClient) -> str:
        now = time.monotonic()
        if self._token is not None and now < self._expires_at:
            return self._token
        r = await http.post(
            _TOKEN_URL,
            data={"grant_type": "client_credentials"},
            auth=(self._client_id, self._client_secret),
        )
        r.raise_for_status()
        body = r.json()
        self._token = body["access_token"]
        self._expires_at = now + int(body["expires_in"]) - _REFRESH_MARGIN_SEC
        return self._token

    async def _search(self, query: str, type_: str, limit: int) -> dict:
        async with self._make_http() as http:
            token = await self._get_token(http)
            r = await http.get(
                _SEARCH_URL,
                params={"q": query, "type": type_, "limit": limit},
                headers={"Authorization": f"Bearer {token}"},
            )
            if r.status_code == 429:
                retry = int(r.headers.get("Retry-After", "1"))
                raise SpotifyRateLimited(retry)
            if r.status_code >= 500:
                raise SpotifyError(f"Spotify {r.status_code}: {r.text[:200]}")
            r.raise_for_status()
            return r.json()

    async def search_tracks(self, query: str, limit: int = 20) -> list[SpotifyResult]:
        body = await self._search(query, "track", limit)
        return [_track(t) for t in body["tracks"]["items"] if t]

    async def search_albums(self, query: str, limit: int = 20) -> list[SpotifyResult]:
        body = await self._search(query, "album", limit)
        return [_album(a) for a in body["albums"]["items"] if a]

    async def search_playlists(self, query: str, limit: int = 20) -> list[SpotifyResult]:
        body = await self._search(query, "playlist", limit)
        return [_playlist(p) for p in body["playlists"]["items"] if p]


def _first_image(images: list[dict] | None) -> str | None:
    if not images:
        return None
    return images[0].get("url")


def _track(t: dict) -> SpotifyResult:
    album_obj = t.get("album") or {}
    artists = t.get("artists") or [{}]
    return SpotifyResult(
        spotify_uri=t["uri"],
        spotify_url=(t.get("external_urls") or {}).get("spotify", ""),
        title=t["name"],
        artist=artists[0].get("name", ""),
        album=album_obj.get("name"),
        duration_ms=t.get("duration_ms"),
        cover_url=_first_image(album_obj.get("images")),
    )


def _album(a: dict) -> SpotifyResult:
    artists = a.get("artists") or [{}]
    return SpotifyResult(
        spotify_uri=a["uri"],
        spotify_url=(a.get("external_urls") or {}).get("spotify", ""),
        title=a["name"],
        artist=artists[0].get("name", ""),
        album=None,
        duration_ms=None,
        cover_url=_first_image(a.get("images")),
    )


def _playlist(p: dict) -> SpotifyResult:
    owner = p.get("owner") or {}
    return SpotifyResult(
        spotify_uri=p["uri"],
        spotify_url=(p.get("external_urls") or {}).get("spotify", ""),
        title=p["name"],
        artist=owner.get("display_name", ""),
        album=None,
        duration_ms=None,
        cover_url=_first_image(p.get("images")),
    )


@lru_cache
def get_spotify_client() -> SpotifyClient:
    s = get_settings()
    return SpotifyClient(
        client_id=s.spotify_client_id,
        client_secret=s.spotify_client_secret.get_secret_value(),
    )
