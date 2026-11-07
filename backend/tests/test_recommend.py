import hashlib
import uuid

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

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
    assert fake_engine.last_limit == 20  # RX3: route over-fetches limit*2
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
                "cover_url": "https://img.youtube.com/vi/abc/mqdefault.jpg",
            }
        ]
    }


async def test_recommend_unparseable_source_url_gives_null_cover(client, make_token, fake_engine):
    fake_engine.results = [
        RecommendedTrack(
            title="Album",
            artist="Someone",
            source_url="https://music.youtube.com/browse/MPREb_xyz",
            score=None,
        ),
    ]
    raw = await make_token(scopes=("read",))
    resp = await client.post(
        "/api/v1/recommend",
        json=_VALID_BODY,
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert resp.status_code == 200
    assert resp.json()["results"][0]["cover_url"] is None


def test_cover_url_for_watch_url():
    from app.services.recommenders.yt_resolver import cover_url_for_source_url

    assert (
        cover_url_for_source_url("https://music.youtube.com/watch?v=abc123")
        == "https://img.youtube.com/vi/abc123/mqdefault.jpg"
    )
    assert (
        cover_url_for_source_url("https://www.youtube.com/watch?v=def456")
        == "https://img.youtube.com/vi/def456/mqdefault.jpg"
    )
    assert (
        cover_url_for_source_url("https://youtu.be/xyz789")
        == "https://img.youtube.com/vi/xyz789/mqdefault.jpg"
    )


def test_cover_url_for_bad_urls_is_none():
    from app.services.recommenders.yt_resolver import cover_url_for_source_url

    assert cover_url_for_source_url("") is None
    assert cover_url_for_source_url("not a url") is None
    assert cover_url_for_source_url("https://example.com/watch?v=abc") is None
    assert cover_url_for_source_url("https://music.youtube.com/watch?foo=bar") is None
    assert cover_url_for_source_url("https://music.youtube.com/browse/MPREb_1") is None


# --- RX3: per-user re-rank + feedback -------------------------------------


def _yt(vid: str) -> str:
    return f"https://music.youtube.com/watch?v={vid}"


def _rt(vid: str, artist: str | None = None, score: float = 1.0) -> RecommendedTrack:
    return RecommendedTrack(
        title=f"t-{vid}", artist=artist or f"artist-{vid}", source_url=_yt(vid), score=score
    )


@pytest.fixture
async def rx_user(app_sm):
    """A fresh user + read token. Returns (user_id, raw_token, token_id); cleans up all rows."""
    async with app_sm() as s:
        uid = (
            await s.execute(
                text("INSERT INTO users (navidrome_username) VALUES (:u) RETURNING id"),
                {"u": f"rx3-{uuid.uuid4().hex[:8]}"},
            )
        ).scalar_one()
        raw = f"raw-{uuid.uuid4().hex}"
        tid = (
            await s.execute(
                text(
                    "INSERT INTO tokens (token_hash, scopes, user_id) "
                    "VALUES (:h, :sc, :u) RETURNING id"
                ),
                {"h": hashlib.sha256(raw.encode()).hexdigest(), "sc": ["read"], "u": uid},
            )
        ).scalar_one()
        await s.commit()
    yield uid, raw, tid
    async with app_sm() as s:
        await s.execute(text("DELETE FROM jobs WHERE user_id = :u"), {"u": uid})
        await s.execute(text("DELETE FROM tokens WHERE user_id = :u"), {"u": uid})
        await s.execute(
            text("DELETE FROM users WHERE id = :u"), {"u": uid}
        )  # cascades rec_feedback
        await s.commit()


async def _add_job(app_sm, user_id, token_id, vid: str, state: str) -> None:
    async with app_sm() as s:
        await s.execute(
            text(
                "INSERT INTO jobs (source_url, source_type, state, created_by_token_id, user_id) "
                "VALUES (:url, 'song', :st, :t, :u)"
            ),
            {"url": _yt(vid), "st": state, "t": token_id, "u": user_id},
        )
        await s.commit()


async def _feedback(app_sm, user_id) -> dict[str, tuple[int, bool, bool]]:
    async with app_sm() as s:
        rows = await s.execute(
            text(
                "SELECT source_url, shown_count, last_shown_at IS NOT NULL, "
                "dismissed_at IS NOT NULL FROM rec_feedback WHERE user_id = :u"
            ),
            {"u": user_id},
        )
        return {r[0]: (r[1], r[2], r[3]) for r in rows}


async def _rec(client, raw: str, limit: int = 10) -> list[str]:
    resp = await client.post(
        "/api/v1/recommend",
        json={"seeds": [{"title": "S", "artist": "A"}], "limit": limit},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert resp.status_code == 200, resp.text
    return [r["source_url"].rsplit("=", 1)[1] for r in resp.json()["results"]]


async def test_recommend_overfetches_from_engine(client, rx_user, fake_engine):
    _, raw, _ = rx_user
    await _rec(client, raw, limit=10)
    assert fake_engine.last_limit == 20
    await _rec(client, raw, limit=50)
    assert fake_engine.last_limit == 100


async def test_recommend_excludes_users_requested_jobs(client, app_sm, rx_user, fake_engine):
    uid, raw, tid = rx_user
    fake_engine.results = [_rt("done"), _rt("queued"), _rt("failed"), _rt("fresh")]
    await _add_job(app_sm, uid, tid, "done", "done")
    await _add_job(app_sm, uid, tid, "queued", "queued")
    await _add_job(app_sm, uid, tid, "failed", "failed")
    assert await _rec(client, raw) == ["failed", "fresh"]


async def test_recommend_ignores_other_users_jobs(
    client, app_sm, rx_user, make_token, system_admin_user_id, fake_engine
):
    _, raw, _ = rx_user
    fake_engine.results = [_rt("theirs")]
    admin_raw = await make_token(scopes=("read",))
    async with app_sm() as s:
        admin_tid = (
            await s.execute(
                text("SELECT id FROM tokens WHERE token_hash = :h"),
                {"h": hashlib.sha256(admin_raw.encode()).hexdigest()},
            )
        ).scalar_one()
    await _add_job(app_sm, system_admin_user_id, admin_tid, "theirs", "done")
    try:
        assert await _rec(client, raw) == ["theirs"]
    finally:
        async with app_sm() as s:
            await s.execute(text("DELETE FROM jobs WHERE source_url = :u"), {"u": _yt("theirs")})
            await s.commit()


async def test_recommend_records_shown_and_demotes_next_time(client, app_sm, rx_user, fake_engine):
    uid, raw, _ = rx_user
    fake_engine.results = [_rt("a", score=1.0), _rt("b", score=0.9)]
    assert await _rec(client, raw, limit=1) == ["a"]
    assert await _feedback(app_sm, uid) == {_yt("a"): (1, True, False)}

    # "a" was shown, so 1.0 * 0.3 < 0.9 → "b" now leads.
    assert await _rec(client, raw, limit=2) == ["b", "a"]
    fb = await _feedback(app_sm, uid)
    assert fb[_yt("a")][0] == 2
    assert fb[_yt("b")][0] == 1


async def test_dismiss_requires_auth(client):
    resp = await client.post("/api/v1/recommend/dismiss", json={"source_url": _yt("x")})
    assert resp.status_code == 401


async def test_dismiss_validates_body(client, rx_user):
    _, raw, _ = rx_user
    h = {"Authorization": f"Bearer {raw}"}
    assert (await client.post("/api/v1/recommend/dismiss", json={}, headers=h)).status_code == 422
    resp = await client.post("/api/v1/recommend/dismiss", json={"source_url": ""}, headers=h)
    assert resp.status_code == 422


async def test_dismiss_is_idempotent_and_hides_song(client, app_sm, rx_user, fake_engine):
    uid, raw, _ = rx_user
    h = {"Authorization": f"Bearer {raw}"}
    fake_engine.results = [_rt("bad"), _rt("good")]
    assert await _rec(client, raw) == ["bad", "good"]

    for _ in range(2):
        resp = await client.post(
            "/api/v1/recommend/dismiss", json={"source_url": _yt("bad")}, headers=h
        )
        assert resp.status_code == 204
        assert resp.content == b""

    assert await _rec(client, raw) == ["good"]
    assert (await _feedback(app_sm, uid))[_yt("bad")][2] is True


async def test_dismiss_only_affects_caller(client, rx_user, make_token, fake_engine):
    _, raw, _ = rx_user
    other_raw = await make_token(scopes=("read",))  # system-admin user
    fake_engine.results = [_rt("zzz-only-mine")]
    resp = await client.post(
        "/api/v1/recommend/dismiss",
        json={"source_url": _yt("zzz-only-mine")},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert resp.status_code == 204
    assert await _rec(client, raw) == []
    assert await _rec(client, other_raw) == ["zzz-only-mine"]


async def test_dismiss_unrelated_url_without_prior_show(client, app_sm, rx_user):
    uid, raw, _ = rx_user
    resp = await client.post(
        "/api/v1/recommend/dismiss",
        json={"source_url": _yt("never-shown")},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert resp.status_code == 204
    assert (await _feedback(app_sm, uid))[_yt("never-shown")] == (0, False, True)


# --- RX5: artist seeds + seed weights --------------------------------------


async def _post_seeds(client, raw: str, seeds: list[dict]):
    return await client.post(
        "/api/v1/recommend",
        json={"seeds": seeds, "limit": 5},
        headers={"Authorization": f"Bearer {raw}"},
    )


async def test_artist_seed_without_title_accepted(client, rx_user, fake_engine):
    _, raw, _ = rx_user
    resp = await _post_seeds(client, raw, [{"artist": "Prateek Kuhad", "weight": 0.7}])
    assert resp.status_code == 200, resp.text
    seed = fake_engine.last_seeds[0]
    assert (seed.title, seed.artist, seed.weight) == (None, "Prateek Kuhad", 0.7)


async def test_explicit_null_title_is_artist_seed(client, rx_user, fake_engine):
    _, raw, _ = rx_user
    resp = await _post_seeds(client, raw, [{"title": None, "artist": "A"}])
    assert resp.status_code == 200, resp.text
    assert fake_engine.last_seeds[0].title is None


async def test_old_client_seed_defaults_weight_to_one(client, rx_user, fake_engine):
    _, raw, _ = rx_user
    resp = await _post_seeds(client, raw, [{"title": "Song", "artist": "A"}])
    assert resp.status_code == 200
    seed = fake_engine.last_seeds[0]
    assert (seed.title, seed.weight) == ("Song", 1.0)


@pytest.mark.parametrize(
    "seed",
    [
        {"artist": "A", "weight": 1.5},
        {"artist": "A", "weight": -0.1},
        {"title": "", "artist": "A"},
        {"title": "Song"},
    ],
)
async def test_invalid_seed_returns_422(client, rx_user, seed):
    _, raw, _ = rx_user
    assert (await _post_seeds(client, raw, [seed])).status_code == 422
