"""MX4 — GET /recommend/mixes + POST /recommend/mixes/{id}."""

import hashlib
import uuid

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

from app.api.v1.recommend import get_mix_builder
from app.api.v1.router import api_v1
from app.db import get_session
from app.services.recommenders.base import RecommendedTrack
from app.services.recommenders.mixes import MixResult, MoodNotFound


def _yt(vid: str) -> str:
    return f"https://music.youtube.com/watch?v={vid}"


def _rt(vid: str, artist: str | None = None, title: str | None = None, score: float = 1.0):
    return RecommendedTrack(
        title=title or f"t-{vid}",
        artist=artist or f"artist-{vid}",
        source_url=_yt(vid),
        score=score,
    )


class FakeBuilder:
    def __init__(self) -> None:
        self.tracks: list[RecommendedTrack] = []
        self.personalized = True
        self.raise_mood = False
        self.calls: list[tuple] = []

    async def build(self, vibe_id, seeds, *, variant):
        self.calls.append((vibe_id, list(seeds), variant))
        if self.raise_mood:
            raise MoodNotFound("Chill")
        return MixResult(vibe_id, "Chill Mix", self.personalized, list(self.tracks))


@pytest.fixture
def builder():
    return FakeBuilder()


@pytest.fixture
async def client(app_sm, builder):
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
    app.dependency_overrides[get_mix_builder] = lambda: builder
    app.include_router(api_v1)
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c


@pytest.fixture
async def user(app_sm):
    """Fresh user + read token: (user_id, raw_token, token_id); rows cleaned up."""
    async with app_sm() as s:
        uid = (
            await s.execute(
                text("INSERT INTO users (navidrome_username) VALUES (:u) RETURNING id"),
                {"u": f"mx4-{uuid.uuid4().hex[:8]}"},
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
        await s.execute(text("DELETE FROM users WHERE id = :u"), {"u": uid})
        await s.commit()


def _auth(raw: str) -> dict:
    return {"Authorization": f"Bearer {raw}"}


async def _mix(client, raw, body=None, vibe="chill"):
    return await client.post(
        f"/api/v1/recommend/mixes/{vibe}",
        json=body if body is not None else {"seeds": [{"artist": "Anuv Jain", "weight": 0.7}]},
        headers=_auth(raw),
    )


def _vids(resp) -> list[str]:
    return [r["source_url"].rsplit("=", 1)[1] for r in resp.json()["results"]]


# --- GET /recommend/mixes ---------------------------------------------------


async def test_list_requires_auth(client):
    assert (await client.get("/api/v1/recommend/mixes")).status_code == 401


async def test_list_returns_the_eight_vibes(client, user):
    _, raw, _ = user
    resp = await client.get("/api/v1/recommend/mixes", headers=_auth(raw))
    assert resp.status_code == 200
    body = resp.json()
    assert [v["id"] for v in body] == [
        "chill",
        "feel-good",
        "party",
        "romance",
        "heartbreak",
        "workout",
        "focus",
        "sleep",
    ]
    assert body[0] == {"id": "chill", "title": "Chill Mix"}


# --- POST /recommend/mixes/{id} --------------------------------------------


async def test_mix_requires_auth(client):
    resp = await client.post("/api/v1/recommend/mixes/chill", json={"seeds": []})
    assert resp.status_code == 401


async def test_mix_returns_results_and_passes_seeds_and_variant(client, user, builder):
    _, raw, _ = user
    builder.tracks = [_rt("a", "X"), _rt("b", "Y")]
    resp = await _mix(
        client,
        raw,
        {
            "seeds": [
                {"title": "Co2", "artist": "Prateek Kuhad"},
                {"artist": "Anuv Jain", "weight": 0.7},
            ],
            "variant": 2,
        },
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert (body["id"], body["title"], body["personalized"]) == ("chill", "Chill Mix", True)
    assert body["results"][0] == {
        "title": "t-a",
        "artist": "X",
        "source_url": _yt("a"),
        "score": 1.0,
        "cover_url": "https://img.youtube.com/vi/a/mqdefault.jpg",
    }
    vibe, seeds, variant = builder.calls[0]
    assert (vibe, variant) == ("chill", 2)
    assert [(s.title, s.artist, s.weight) for s in seeds] == [
        ("Co2", "Prateek Kuhad", 1.0),
        (None, "Anuv Jain", 0.7),
    ]


async def test_unpersonalized_flag_passes_through(client, user, builder):
    _, raw, _ = user
    builder.personalized = False
    builder.tracks = [_rt("a")]
    assert (await _mix(client, raw)).json()["personalized"] is False


async def test_unknown_vibe_is_404_without_building(client, user, builder):
    _, raw, _ = user
    resp = await _mix(client, raw, vibe="polka")
    assert resp.status_code == 404
    assert builder.calls == []


async def test_missing_mood_upstream_is_503(client, user, builder):
    _, raw, _ = user
    builder.raise_mood = True
    assert (await _mix(client, raw)).status_code == 503


@pytest.mark.parametrize(
    "body",
    [
        {"seeds": [], "limit": 51},
        {"seeds": [], "limit": 0},
        {"seeds": [], "variant": -1},
        {"seeds": [], "extra": True},
    ],
)
async def test_invalid_body_is_422(client, user, body):
    _, raw, _ = user
    assert (await _mix(client, raw, body)).status_code == 422


async def test_limit_trims_results(client, user, builder):
    _, raw, _ = user
    builder.tracks = [_rt(str(i), f"artist{i}", score=1 - i / 100) for i in range(10)]
    resp = await _mix(client, raw, {"seeds": [], "limit": 3})
    assert _vids(resp) == ["0", "1", "2"]


async def test_default_limit_is_50(client, user, builder):
    _, raw, _ = user
    builder.tracks = [_rt(str(i), f"artist{i}", score=1 - i / 1000) for i in range(60)]
    assert len((await _mix(client, raw, {"seeds": []})).json()["results"]) == 50


async def test_at_most_three_songs_per_artist(client, user, builder):
    _, raw, _ = user
    builder.tracks = [_rt(f"s{i}", "Arijit Singh", score=1 - i / 10) for i in range(5)] + [
        _rt("other", "Anuv Jain", score=0.1)
    ]
    assert _vids(await _mix(client, raw)) == ["s0", "s1", "s2", "other"]


async def test_covers_and_alternate_versions_dropped(client, user, builder):
    _, raw, _ = user
    builder.tracks = [
        _rt("ac", "Anuv Jain", title="Baarishein (Acoustic)"),
        _rt("og", "Anuv Jain", title="Baarishein"),
    ]
    assert _vids(await _mix(client, raw)) == ["og"]


async def test_users_requested_and_dismissed_songs_excluded(client, app_sm, user, builder):
    uid, raw, tid = user
    builder.tracks = [_rt("done"), _rt("failed"), _rt("dismissed"), _rt("fresh")]
    async with app_sm() as s:
        for vid, state in (("done", "done"), ("failed", "failed")):
            await s.execute(
                text(
                    "INSERT INTO jobs (source_url, source_type, state, created_by_token_id, user_id) "
                    "VALUES (:url, 'song', :st, :t, :u)"
                ),
                {"url": _yt(vid), "st": state, "t": tid, "u": uid},
            )
        await s.execute(
            text(
                "INSERT INTO rec_feedback (user_id, source_url, dismissed_at) "
                "VALUES (:u, :url, now())"
            ),
            {"u": uid, "url": _yt("dismissed")},
        )
        await s.commit()

    assert _vids(await _mix(client, raw)) == ["failed", "fresh"]


async def test_mix_does_not_record_shown_rows(client, app_sm, user, builder):
    uid, raw, _ = user
    builder.tracks = [_rt("a"), _rt("b")]
    await _mix(client, raw)
    async with app_sm() as s:
        n = (
            await s.execute(
                text("SELECT count(*) FROM rec_feedback WHERE user_id = :u"), {"u": uid}
            )
        ).scalar_one()
    assert n == 0
