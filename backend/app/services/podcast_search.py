"""Podcast discovery for `POST /podcasts/search`.

Uses Apple's iTunes Search API — no signup, no key, no auth headers. Chosen
over Podcast Index (the original P2 client) after Podcast Index's signup
form began rejecting free-email-provider addresses; see
`backend/docs/DECISIONLOG.md` 2026-07-20 "Podcast discovery: Podcast Index
-> iTunes Search". Coverage is a slightly different net (iTunes indexes
podcasts submitted to Apple's directory — the large majority of public
shows) but the response shape returned to Android is unchanged, so the
client needed no changes for this swap.
"""

from __future__ import annotations

from dataclasses import dataclass

import httpx

_BASE_URL = "https://itunes.apple.com/search"
_USER_AGENT = "heerr/1.0"


class PodcastSearchError(Exception):
    pass


@dataclass(frozen=True)
class PodcastSearchResult:
    feed_url: str
    title: str
    author: str | None
    image_url: str | None
    description: str | None


class PodcastSearchClient:
    async def search(self, query: str, limit: int) -> list[PodcastSearchResult]:
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(
                    _BASE_URL,
                    params={
                        "term": query,
                        "media": "podcast",
                        "entity": "podcast",
                        "limit": limit,
                    },
                    headers={"User-Agent": _USER_AGENT},
                )
                resp.raise_for_status()
                data = resp.json()
        except httpx.HTTPError as exc:
            raise PodcastSearchError(str(exc)) from exc

        results = data.get("results") or []
        return [
            PodcastSearchResult(
                feed_url=r["feedUrl"],
                title=r.get("collectionName", ""),
                author=r.get("artistName") or None,
                image_url=r.get("artworkUrl600") or r.get("artworkUrl100") or None,
                description=r.get("description") or None,
            )
            for r in results
            if r.get("feedUrl")
        ]


def get_podcast_search_client() -> PodcastSearchClient:
    return PodcastSearchClient()
