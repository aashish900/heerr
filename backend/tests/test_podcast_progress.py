import uuid

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

from app.api.v1.router import api_v1
from app.db import get_session
from app.models import PodcastChannel, PodcastEpisode

_FEED_URL = "https://example.com/feed.xml"


@pytest.fixture
async def progress_app(app_sm):
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
    app.include_router(api_v1)
    yield app


@pytest.fixture
async def client(progress_app):
    transport = ASGITransport(app=progress_app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.fixture
async def cleanup(app_sm):
    yield
    async with app_sm() as s:
        await s.execute(text("DELETE FROM podcast_progress"))
        await s.execute(text("DELETE FROM podcast_episode"))
        await s.execute(text("DELETE FROM podcast_channel"))
        await s.commit()


@pytest.fixture
async def seeded(app_sm, cleanup):
    async with app_sm() as s:
        channel = PodcastChannel(feed_url=_FEED_URL, title="Test Show")
        s.add(channel)
        await s.flush()
        episode = PodcastEpisode(
            channel_id=channel.id,
            guid="ep-1",
            title="Episode 1",
            enclosure_url="https://example.com/ep1.mp3",
        )
        s.add(episode)
        await s.commit()
        return channel.id, episode.id


@pytest.fixture
async def episode_id(seeded):
    return seeded[1]


async def test_progress_requires_auth(client, episode_id):
    r = await client.put(
        f"/api/v1/podcasts/episodes/{episode_id}/progress",
        json={"position_s": 10, "played": False},
    )
    assert r.status_code == 401


async def test_progress_unknown_episode_404(client, make_token):
    raw = await make_token()
    r = await client.put(
        f"/api/v1/podcasts/episodes/{uuid.uuid4()}/progress",
        json={"position_s": 10, "played": False},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 404


async def test_progress_negative_position_422(client, make_token, episode_id):
    raw = await make_token()
    r = await client.put(
        f"/api/v1/podcasts/episodes/{episode_id}/progress",
        json={"position_s": -1, "played": False},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 422


async def test_progress_creates_row(client, make_token, episode_id):
    raw = await make_token()
    r = await client.put(
        f"/api/v1/podcasts/episodes/{episode_id}/progress",
        json={"position_s": 42, "played": False},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body == {"episode_id": str(episode_id), "position_s": 42, "played": False}


async def test_progress_upserts_on_repeat_calls(client, make_token, episode_id):
    raw = await make_token()
    headers = {"Authorization": f"Bearer {raw}"}
    await client.put(
        f"/api/v1/podcasts/episodes/{episode_id}/progress",
        json={"position_s": 10, "played": False},
        headers=headers,
    )
    r2 = await client.put(
        f"/api/v1/podcasts/episodes/{episode_id}/progress",
        json={"position_s": 200, "played": True},
        headers=headers,
    )
    assert r2.status_code == 200
    assert r2.json() == {"episode_id": str(episode_id), "position_s": 200, "played": True}


async def test_progress_reflected_in_episode_list(client, make_token, seeded):
    channel_id, episode_id = seeded
    raw = await make_token()
    headers = {"Authorization": f"Bearer {raw}"}
    await client.put(
        f"/api/v1/podcasts/episodes/{episode_id}/progress",
        json={"position_s": 77, "played": True},
        headers=headers,
    )

    r = await client.get(f"/api/v1/podcasts/channels/{channel_id}/episodes", headers=headers)
    ep = next(e for e in r.json()["episodes"] if e["id"] == str(episode_id))
    assert ep["position_s"] == 77
    assert ep["played"] is True


async def test_progress_scoped_to_current_user(client, make_token, seeded, app_sm):
    import hashlib
    import secrets

    from app.models import Token, User

    channel_id, episode_id = seeded
    raw_a = await make_token()
    headers_a = {"Authorization": f"Bearer {raw_a}"}
    await client.put(
        f"/api/v1/podcasts/episodes/{episode_id}/progress",
        json={"position_s": 55, "played": True},
        headers=headers_a,
    )

    async with app_sm() as s:
        user_b = User(navidrome_username=f"bob-{uuid.uuid4().hex[:8]}")
        s.add(user_b)
        await s.flush()
        raw_b = f"raw-{secrets.token_urlsafe(16)}"
        s.add(
            Token(
                token_hash=hashlib.sha256(raw_b.encode()).hexdigest(),
                scopes=["read", "download"],
                user_id=user_b.id,
            )
        )
        await s.commit()

    headers_b = {"Authorization": f"Bearer {raw_b}"}
    r_b = await client.get(f"/api/v1/podcasts/channels/{channel_id}/episodes", headers=headers_b)
    ep_b = next(e for e in r_b.json()["episodes"] if e["id"] == str(episode_id))
    assert ep_b["position_s"] == 0
    assert ep_b["played"] is False
