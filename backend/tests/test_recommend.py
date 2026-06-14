import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.v1.router import api_v1
from app.db import get_session
from app.services.recommenders.base import RecommendedTrack
from app.services.recommenders.factory import get_recommendation_engine


class FakeEngine:
    name = "fake"

    def __init__(
        self,
        results: list[RecommendedTrack] | None = None,
        health: list[tuple[str, bool]] | None = None,
    ):
        self.results = results or []
        self._health = health if health is not None else [("fake", True)]
        self.last_seeds = None
        self.last_limit: int | None = None

    async def recommend(self, seeds, limit):
        self.last_seeds = list(seeds)
        self.last_limit = limit
        return list(self.results)

    async def probe(self):
        return self._health[0][1] if self._health else True

    async def health_chain(self):
        return list(self._health)


@pytest.fixture
async def fake_engine():
    return FakeEngine()


@pytest.fixture
async def recommend_app(app_sm, fake_engine):
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
    app.dependency_overrides[get_recommendation_engine] = lambda: fake_engine
    app.include_router(api_v1)
    yield app


@pytest.fixture
async def client(recommend_app):
    transport = ASGITransport(app=recommend_app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


_VALID_BODY = {
    "seeds": [{"title": "Song", "artist": "Artist"}],
    "limit": 10,
}


async def test_recommend_missing_auth_returns_401(client):
    resp = await client.post("/api/v1/recommend", json=_VALID_BODY)
    assert resp.status_code == 401


async def test_recommend_wrong_scope_returns_403(client, make_token):
    raw = await make_token(scopes=("download",))
    resp = await client.post(
        "/api/v1/recommend",
        json=_VALID_BODY,
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert resp.status_code == 403


async def test_recommend_invalid_limit_low_returns_422(client, make_token):
    raw = await make_token(scopes=("read",))
    resp = await client.post(
        "/api/v1/recommend",
        json={"seeds": [], "limit": 0},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert resp.status_code == 422


async def test_recommend_invalid_limit_high_returns_422(client, make_token):
    raw = await make_token(scopes=("read",))
    resp = await client.post(
        "/api/v1/recommend",
        json={"seeds": [], "limit": 51},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert resp.status_code == 422


async def test_recommend_extra_field_returns_422(client, make_token):
    raw = await make_token(scopes=("read",))
    body = {**_VALID_BODY, "extra": "nope"}
    resp = await client.post(
        "/api/v1/recommend",
        json=body,
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert resp.status_code == 422


async def test_recommend_stub_returns_empty_results(client, make_token, fake_engine):
    raw = await make_token(scopes=("read",))
    resp = await client.post(
        "/api/v1/recommend",
        json=_VALID_BODY,
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert resp.status_code == 200
    assert resp.json() == {"results": []}
    assert fake_engine.last_limit == 10
    assert fake_engine.last_seeds is not None
    assert len(fake_engine.last_seeds) == 1
    assert fake_engine.last_seeds[0].title == "Song"
    assert fake_engine.last_seeds[0].artist == "Artist"
    assert fake_engine.last_seeds[0].source_url is None


async def test_recommend_health_missing_auth_returns_401(client):
    resp = await client.get("/api/v1/recommend/health")
    assert resp.status_code == 401


async def test_recommend_health_wrong_scope_returns_403(client, make_token):
    raw = await make_token(scopes=("download",))
    resp = await client.get(
        "/api/v1/recommend/health",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert resp.status_code == 403


async def test_recommend_health_single_engine_ok(client, make_token, fake_engine):
    fake_engine._health = [("ytmusic", True)]
    raw = await make_token(scopes=("read",))
    resp = await client.get(
        "/api/v1/recommend/health",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert resp.status_code == 200
    assert resp.json() == {
        "engine": "ytmusic",
        "status": "ok",
        "fallback_active": False,
    }


async def test_recommend_health_single_engine_degraded(client, make_token, fake_engine):
    fake_engine._health = [("lastfm", False)]
    raw = await make_token(scopes=("read",))
    resp = await client.get(
        "/api/v1/recommend/health",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert resp.json() == {
        "engine": "lastfm",
        "status": "degraded",
        "fallback_active": False,
    }


async def test_recommend_health_chain_primary_ok_no_fallback(client, make_token, fake_engine):
    fake_engine._health = [("lastfm", True), ("ytmusic", True)]
    raw = await make_token(scopes=("read",))
    resp = await client.get(
        "/api/v1/recommend/health",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert resp.json() == {
        "engine": "lastfm",
        "status": "ok",
        "fallback_active": False,
    }


async def test_recommend_health_chain_primary_down_fallback_active(client, make_token, fake_engine):
    fake_engine._health = [("lastfm", False), ("ytmusic", True)]
    raw = await make_token(scopes=("read",))
    resp = await client.get(
        "/api/v1/recommend/health",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert resp.json() == {
        "engine": "lastfm",
        "status": "degraded",
        "fallback_active": True,
    }


async def test_recommend_health_chain_all_down(client, make_token, fake_engine):
    fake_engine._health = [("lastfm", False), ("ytmusic", False)]
    raw = await make_token(scopes=("read",))
    resp = await client.get(
        "/api/v1/recommend/health",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert resp.json() == {
        "engine": "lastfm",
        "status": "degraded",
        "fallback_active": False,
    }


async def test_recommend_returns_engine_results(client, make_token, fake_engine):
    fake_engine.results = [
        RecommendedTrack(
            title="Similar",
            artist="OtherArtist",
            source_url="https://music.youtube.com/watch?v=abc",
            score=0.91,
        ),
    ]
    raw = await make_token(scopes=("read",))
    resp = await client.post(
        "/api/v1/recommend",
        json=_VALID_BODY,
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body == {
        "results": [
            {
                "title": "Similar",
                "artist": "OtherArtist",
                "source_url": "https://music.youtube.com/watch?v=abc",
                "score": 0.91,
            }
        ]
    }
