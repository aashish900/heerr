import uuid
from datetime import UTC, datetime, timedelta

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

import app.api.v1.podcasts as podcasts_module
from app.api.v1.router import api_v1
from app.db import get_session
from app.models import PodcastChannel, PodcastEpisode, PodcastProgress
from app.services.feeds import FeedFetchError

_FEED_URL = "https://example.com/feed.xml"


@pytest.fixture
async def episodes_app(app_sm):
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
async def client(episodes_app):
    transport = ASGITransport(app=episodes_app)
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
async def seeded_channel(app_sm, cleanup):
    async with app_sm() as s:
        channel = PodcastChannel(feed_url=_FEED_URL, title="Test Show")
        s.add(channel)
        await s.flush()
        now = datetime.now(UTC)
        episodes = [
            PodcastEpisode(
                channel_id=channel.id,
                guid=f"ep-{i}",
                title=f"Episode {i}",
                enclosure_url=f"https://example.com/ep{i}.mp3",
                published_at=now - timedelta(days=i),
            )
            for i in range(3)
        ]
        s.add_all(episodes)
        await s.commit()
        return channel.id, [e.id for e in episodes]


# ---- GET /podcasts/channels/{id}/episodes ----------------------------------


async def test_list_episodes_requires_auth(client, seeded_channel):
    channel_id, _ = seeded_channel
    r = await client.get(f"/api/v1/podcasts/channels/{channel_id}/episodes")
    assert r.status_code == 401


async def test_list_episodes_unknown_channel_404(client, make_token):
    raw = await make_token()
    r = await client.get(
        f"/api/v1/podcasts/channels/{uuid.uuid4()}/episodes",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 404


async def test_list_episodes_newest_first(client, make_token, seeded_channel):
    channel_id, episode_ids = seeded_channel
    raw = await make_token()
    r = await client.get(
        f"/api/v1/podcasts/channels/{channel_id}/episodes",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["total"] == 3
    assert [e["title"] for e in body["episodes"]] == ["Episode 0", "Episode 1", "Episode 2"]
    assert all(e["downloaded"] is False for e in body["episodes"])
    assert all(e["position_s"] == 0 and e["played"] is False for e in body["episodes"])


async def test_list_episodes_pagination(client, make_token, seeded_channel):
    channel_id, _ = seeded_channel
    raw = await make_token()
    r = await client.get(
        f"/api/v1/podcasts/channels/{channel_id}/episodes?limit=1&offset=1",
        headers={"Authorization": f"Bearer {raw}"},
    )
    body = r.json()
    assert body["total"] == 3
    assert len(body["episodes"]) == 1
    assert body["episodes"][0]["title"] == "Episode 1"


async def test_list_episodes_reflects_downloaded_and_progress(
    client, make_token, seeded_channel, app_sm
):
    channel_id, episode_ids = seeded_channel
    raw = await make_token()

    async with app_sm() as s:
        ep = await s.get(PodcastEpisode, episode_ids[0])
        ep.downloaded_path = "/data/media/podcasts/ep0.mp3"
        await s.commit()

    r = await client.get(
        f"/api/v1/podcasts/channels/{channel_id}/episodes",
        headers={"Authorization": f"Bearer {raw}"},
    )
    body = r.json()
    downloaded_titles = {e["title"] for e in body["episodes"] if e["downloaded"]}
    assert downloaded_titles == {"Episode 0"}


async def test_list_episodes_progress_scoped_to_current_user(
    client, make_token, seeded_channel, app_sm
):
    channel_id, episode_ids = seeded_channel
    raw = await make_token()

    async with app_sm() as s:
        r = await s.execute(text("SELECT system_admin_user_id()"))
        user_id = r.scalar_one()
        s.add(
            PodcastProgress(
                user_id=user_id,
                episode_id=episode_ids[0],
                position_s=42,
                played=True,
            )
        )
        await s.commit()

    r = await client.get(
        f"/api/v1/podcasts/channels/{channel_id}/episodes",
        headers={"Authorization": f"Bearer {raw}"},
    )
    body = r.json()
    ep0 = next(e for e in body["episodes"] if e["title"] == "Episode 0")
    assert ep0["position_s"] == 42
    assert ep0["played"] is True


# ---- POST /podcasts/channels/{id}/refresh ----------------------------------


async def test_refresh_requires_auth(client, seeded_channel):
    channel_id, _ = seeded_channel
    r = await client.post(f"/api/v1/podcasts/channels/{channel_id}/refresh")
    assert r.status_code == 401


async def test_refresh_unknown_channel_404(client, make_token):
    raw = await make_token()
    r = await client.post(
        f"/api/v1/podcasts/channels/{uuid.uuid4()}/refresh",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 404


async def test_refresh_calls_ingest_feed_with_channel_feed_url(
    client, make_token, seeded_channel, monkeypatch
):
    channel_id, _ = seeded_channel
    raw = await make_token()

    calls = []

    async def _fake_ingest(session, feed_url):
        calls.append(feed_url)
        channel = await session.get(PodcastChannel, channel_id)
        return channel

    monkeypatch.setattr(podcasts_module, "ingest_feed", _fake_ingest)

    r = await client.post(
        f"/api/v1/podcasts/channels/{channel_id}/refresh",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200
    assert calls == [_FEED_URL]


async def test_refresh_feed_error_returns_502(client, make_token, seeded_channel, monkeypatch):
    channel_id, _ = seeded_channel
    raw = await make_token()

    async def _raise(session, feed_url):
        raise FeedFetchError("boom")

    monkeypatch.setattr(podcasts_module, "ingest_feed", _raise)

    r = await client.post(
        f"/api/v1/podcasts/channels/{channel_id}/refresh",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 502
