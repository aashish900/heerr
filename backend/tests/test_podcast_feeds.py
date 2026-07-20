import hashlib
import secrets
import uuid
from datetime import UTC, datetime, timedelta

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

from app.api.v1.router import api_v1
from app.db import get_session
from app.models import (
    PodcastChannel,
    PodcastEpisode,
    PodcastProgress,
    PodcastSubscription,
    Token,
    User,
)

_FEED_A = "https://example.com/a.xml"
_FEED_B = "https://example.com/b.xml"


@pytest.fixture
async def feeds_app(app_sm):
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
async def client(feeds_app):
    transport = ASGITransport(app=feeds_app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.fixture
async def cleanup(app_sm):
    yield
    async with app_sm() as s:
        await s.execute(text("DELETE FROM podcast_progress"))
        await s.execute(text("DELETE FROM podcast_subscription"))
        await s.execute(text("DELETE FROM podcast_episode"))
        await s.execute(text("DELETE FROM podcast_channel"))
        await s.commit()


@pytest.fixture
async def second_user_token(app_sm):
    async with app_sm() as s:
        user = User(navidrome_username=f"bob-{uuid.uuid4().hex[:8]}")
        s.add(user)
        await s.flush()
        raw = f"raw-{secrets.token_urlsafe(16)}"
        s.add(
            Token(
                token_hash=hashlib.sha256(raw.encode()).hexdigest(),
                scopes=["read", "download"],
                user_id=user.id,
            )
        )
        await s.commit()
    return raw, user.id


@pytest.fixture
async def seeded(app_sm, cleanup, make_token, system_admin_user_id):
    """Two channels, each with one episode, both subscribed by the
    system-admin user. Channel A's episode is in-progress + downloaded;
    Channel B's episode is untouched (fresh/latest)."""
    now = datetime.now(UTC)
    async with app_sm() as s:
        channel_a = PodcastChannel(feed_url=_FEED_A, title="Show A", image_url="https://a/art.png")
        channel_b = PodcastChannel(feed_url=_FEED_B, title="Show B", image_url="https://b/art.png")
        s.add_all([channel_a, channel_b])
        await s.flush()

        ep_a = PodcastEpisode(
            channel_id=channel_a.id,
            guid="a-1",
            title="A Episode 1",
            enclosure_url="https://a/ep1.mp3",
            published_at=now - timedelta(days=2),
            downloaded_path="/data/podcasts/a-1.mp3",
            downloaded_at=now - timedelta(days=1),
        )
        ep_b = PodcastEpisode(
            channel_id=channel_b.id,
            guid="b-1",
            title="B Episode 1",
            enclosure_url="https://b/ep1.mp3",
            published_at=now,
        )
        s.add_all([ep_a, ep_b])
        await s.flush()

        s.add_all(
            [
                PodcastSubscription(user_id=system_admin_user_id, channel_id=channel_a.id),
                PodcastSubscription(user_id=system_admin_user_id, channel_id=channel_b.id),
                PodcastProgress(
                    user_id=system_admin_user_id,
                    episode_id=ep_a.id,
                    position_s=42,
                    played=False,
                    last_played_at=now,
                ),
            ]
        )
        await s.commit()

    raw = await make_token()
    return {
        "token": raw,
        "channel_a": channel_a.id,
        "channel_b": channel_b.id,
        "ep_a": ep_a.id,
        "ep_b": ep_b.id,
    }


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


# ---- GET /podcasts/episodes -------------------------------------------------


async def test_episode_feed_requires_auth(client):
    r = await client.get("/api/v1/podcasts/episodes?filter=latest")
    assert r.status_code == 401


async def test_episode_feed_requires_filter_param(client, seeded):
    r = await client.get("/api/v1/podcasts/episodes", headers=_auth(seeded["token"]))
    assert r.status_code == 422


async def test_episode_feed_rejects_bad_filter_value(client, seeded):
    r = await client.get("/api/v1/podcasts/episodes?filter=bogus", headers=_auth(seeded["token"]))
    assert r.status_code == 422


async def test_in_progress_filter_returns_only_unplayed_started_episodes(client, seeded):
    r = await client.get(
        "/api/v1/podcasts/episodes?filter=in_progress", headers=_auth(seeded["token"])
    )
    assert r.status_code == 200
    body = r.json()
    assert body["total"] == 1
    ep = body["episodes"][0]
    assert ep["id"] == str(seeded["ep_a"])
    assert ep["channel_title"] == "Show A"
    assert ep["channel_image_url"] == "https://a/art.png"
    assert ep["position_s"] == 42
    assert ep["played"] is False


async def test_latest_filter_returns_all_subscribed_episodes_newest_first(client, seeded):
    r = await client.get("/api/v1/podcasts/episodes?filter=latest", headers=_auth(seeded["token"]))
    assert r.status_code == 200
    body = r.json()
    assert body["total"] == 2
    ids = [ep["id"] for ep in body["episodes"]]
    # ep_b published now, ep_a published 2 days ago → newest first.
    assert ids == [str(seeded["ep_b"]), str(seeded["ep_a"])]


async def test_downloaded_filter_returns_only_downloaded_episodes(client, seeded):
    r = await client.get(
        "/api/v1/podcasts/episodes?filter=downloaded", headers=_auth(seeded["token"])
    )
    assert r.status_code == 200
    body = r.json()
    assert body["total"] == 1
    assert body["episodes"][0]["id"] == str(seeded["ep_a"])
    assert body["episodes"][0]["downloaded"] is True


async def test_pagination_bounds_on_latest_filter(client, seeded):
    r = await client.get(
        "/api/v1/podcasts/episodes?filter=latest&limit=1&offset=1",
        headers=_auth(seeded["token"]),
    )
    assert r.status_code == 200
    body = r.json()
    assert body["total"] == 2
    assert len(body["episodes"]) == 1
    assert body["episodes"][0]["id"] == str(seeded["ep_a"])


async def test_no_subscriptions_returns_empty_list(client, make_token, cleanup):
    raw = await make_token()
    r = await client.get("/api/v1/podcasts/episodes?filter=latest", headers=_auth(raw))
    assert r.status_code == 200
    body = r.json()
    assert body == {"episodes": [], "total": 0}


async def test_feed_is_isolated_per_user(client, seeded, second_user_token):
    second_raw, _second_user_id = second_user_token
    r = await client.get("/api/v1/podcasts/episodes?filter=latest", headers=_auth(second_raw))
    assert r.status_code == 200
    # second_user_token has no subscriptions of its own — seeded's channels
    # belong solely to the system-admin user.
    assert r.json() == {"episodes": [], "total": 0}
