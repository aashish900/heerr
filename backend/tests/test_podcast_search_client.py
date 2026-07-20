import httpx
import pytest

from app.services import podcast_search
from app.services.podcast_search import PodcastSearchClient, PodcastSearchError

_RealAsyncClient = httpx.AsyncClient


def _mock_client_factory(handler):
    def _factory(*args, **kwargs):
        return _RealAsyncClient(transport=httpx.MockTransport(handler))

    return _factory


_ITUNES_RESPONSE = {
    "resultCount": 2,
    "results": [
        {
            "collectionName": "Daily News",
            "artistName": "News Co",
            "feedUrl": "https://example.com/feed.xml",
            "artworkUrl600": "https://example.com/art600.jpg",
            "artworkUrl100": "https://example.com/art100.jpg",
        },
        {
            # No feedUrl — should be filtered out.
            "collectionName": "No Feed Show",
            "artistName": "Someone",
        },
    ],
}


async def test_search_maps_itunes_results(monkeypatch):
    captured: dict = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["params"] = dict(request.url.params)
        return httpx.Response(200, json=_ITUNES_RESPONSE)

    monkeypatch.setattr(podcast_search.httpx, "AsyncClient", _mock_client_factory(handler))

    client = PodcastSearchClient()
    results = await client.search("news", 10)

    assert len(results) == 1
    r = results[0]
    assert r.feed_url == "https://example.com/feed.xml"
    assert r.title == "Daily News"
    assert r.author == "News Co"
    assert r.image_url == "https://example.com/art600.jpg"
    assert r.description is None

    assert captured["params"]["term"] == "news"
    assert captured["params"]["media"] == "podcast"
    assert captured["params"]["limit"] == "10"


async def test_search_falls_back_to_artwork_100_when_600_missing(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={
                "results": [
                    {
                        "collectionName": "Show",
                        "feedUrl": "https://example.com/f.xml",
                        "artworkUrl100": "https://example.com/art100.jpg",
                    }
                ]
            },
        )

    monkeypatch.setattr(podcast_search.httpx, "AsyncClient", _mock_client_factory(handler))

    client = PodcastSearchClient()
    results = await client.search("news", 10)
    assert results[0].image_url == "https://example.com/art100.jpg"


async def test_search_raises_podcast_search_error_on_http_failure(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500)

    monkeypatch.setattr(podcast_search.httpx, "AsyncClient", _mock_client_factory(handler))

    client = PodcastSearchClient()
    with pytest.raises(PodcastSearchError):
        await client.search("news", 10)


async def test_search_no_results_returns_empty_list(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"results": []})

    monkeypatch.setattr(podcast_search.httpx, "AsyncClient", _mock_client_factory(handler))

    client = PodcastSearchClient()
    assert await client.search("nothing", 10) == []
