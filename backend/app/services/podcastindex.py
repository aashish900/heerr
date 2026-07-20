"""P2: Podcast Index client — show discovery for `POST /podcasts/search`.

Podcast Index (podcastindex.org) auth is HMAC-ish but not a standard signature
scheme: `Authorization` is the hex SHA1 digest of `key + secret + unix_time`,
sent alongside `X-Auth-Key` and `X-Auth-Date`. No OAuth flow, no token refresh.
"""

from __future__ import annotations

import hashlib
import time
from dataclasses import dataclass
from functools import lru_cache

import httpx

from app.config import Settings, get_settings

_BASE_URL = "https://api.podcastindex.org/api/1.0"
_USER_AGENT = "heerr/1.0"


class PodcastIndexError(Exception):
    pass


class PodcastIndexNotConfigured(PodcastIndexError):
    pass


@dataclass(frozen=True)
class PodcastIndexResult:
    feed_url: str
    title: str
    author: str | None
    image_url: str | None
    description: str | None


class PodcastIndexClient:
    def __init__(self, settings: Settings) -> None:
        self._key = settings.podcastindex_key
        self._secret = settings.podcastindex_secret

    def _auth_headers(self) -> dict[str, str]:
        if not self._key or not self._secret:
            raise PodcastIndexNotConfigured(
                "PODCASTINDEX_KEY / PODCASTINDEX_SECRET are not configured"
            )
        auth_date = str(int(time.time()))
        digest = hashlib.sha1((self._key + self._secret + auth_date).encode()).hexdigest()
        return {
            "X-Auth-Key": self._key,
            "X-Auth-Date": auth_date,
            "Authorization": digest,
            "User-Agent": _USER_AGENT,
        }

    async def search(self, query: str, limit: int) -> list[PodcastIndexResult]:
        headers = self._auth_headers()
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(
                    f"{_BASE_URL}/search/byterm",
                    params={"q": query, "max": limit},
                    headers=headers,
                )
                resp.raise_for_status()
                data = resp.json()
        except httpx.HTTPError as exc:
            raise PodcastIndexError(str(exc)) from exc

        feeds = data.get("feeds") or []
        return [
            PodcastIndexResult(
                feed_url=feed["url"],
                title=feed.get("title", ""),
                author=feed.get("author") or None,
                image_url=feed.get("image") or feed.get("artwork") or None,
                description=feed.get("description") or None,
            )
            for feed in feeds
            if feed.get("url")
        ]


@lru_cache(maxsize=1)
def get_podcastindex_client() -> PodcastIndexClient:
    return PodcastIndexClient(get_settings())
