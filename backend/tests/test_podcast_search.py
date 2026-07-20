import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.v1.router import api_v1
from app.db import get_session
from app.services.podcast_search import (
    PodcastSearchError,
    PodcastSearchResult,
    get_podcast_search_client,
)


class FakePodcastSearch:
    def __init__(self):
        self.results: list[PodcastSearchResult] = []
        self.raise_error: bool = False
        self.last_query: str | None = None
        self.last_limit: int | None = None

    async def search(self, query: str, limit: int) -> list[PodcastSearchResult]:
        self.last_query = query
        self.last_limit = limit
        if self.raise_error:
            raise PodcastSearchError("upstream down")
        return list(self.results)


@pytest.fixture
async def fake_podcast_search():
    return FakePodcastSearch()


@pytest.fixture
async def podcast_app(app_sm, fake_podcast_search):
    app = FastAPI()

    async def override_get_session():
        async with app_sm() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    app.dependency_overrides[get_session] = override_get_session
    app.dependency_overrides[get_podcast_search_client] = lambda: fake_podcast_search
    app.include_router(api_v1)
    yield app


@pytest.fixture
async def client(podcast_app):
    transport = ASGITransport(app=podcast_app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


def _result(feed_url: str, title: str = "Show") -> PodcastSearchResult:
    return PodcastSearchResult(
        feed_url=feed_url,
        title=title,
        author="Host",
        image_url="https://example.com/art.jpg",
        description="A show",
    )


# ---- auth / scope branches ------------------------------------------------


async def test_search_requires_auth(client):
    r = await client.post("/api/v1/podcasts/search", json={"query": "news"})
    assert r.status_code == 401


async def test_search_requires_read_scope(client, make_token):
    raw = await make_token(scopes=("download",))
    r = await client.post(
        "/api/v1/podcasts/search",
        json={"query": "news"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 403


# ---- request validation ---------------------------------------------------


async def test_empty_query_returns_422(client, make_token):
    raw = await make_token()
    r = await client.post(
        "/api/v1/podcasts/search",
        json={"query": ""},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 422


async def test_unknown_field_returns_422(client, make_token):
    raw = await make_token()
    r = await client.post(
        "/api/v1/podcasts/search",
        json={"query": "news", "evil": True},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 422


async def test_limit_out_of_range_returns_422(client, make_token):
    raw = await make_token()
    r = await client.post(
        "/api/v1/podcasts/search",
        json={"query": "news", "limit": 999},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 422


# ---- contract shape --------------------------------------------------------


async def test_search_returns_contract_fields(client, make_token, fake_podcast_search):
    raw = await make_token()
    fake_podcast_search.results = [_result("https://example.com/feed.xml", title="Daily News")]
    r = await client.post(
        "/api/v1/podcasts/search",
        json={"query": "news"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["results"] == [
        {
            "feed_url": "https://example.com/feed.xml",
            "title": "Daily News",
            "author": "Host",
            "image_url": "https://example.com/art.jpg",
            "description": "A show",
        }
    ]


async def test_query_and_limit_passed_to_client(client, make_token, fake_podcast_search):
    raw = await make_token()
    await client.post(
        "/api/v1/podcasts/search",
        json={"query": "space exploration", "limit": 5},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert fake_podcast_search.last_query == "space exploration"
    assert fake_podcast_search.last_limit == 5


# ---- upstream failure -------------------------------------------------------


async def test_upstream_error_returns_502(client, make_token, fake_podcast_search):
    raw = await make_token()
    fake_podcast_search.raise_error = True
    r = await client.post(
        "/api/v1/podcasts/search",
        json={"query": "news"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 502
