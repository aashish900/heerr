import os
import uuid

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

from app.api.v1.router import api_v1
from app.db import get_session
from app.models import PodcastChannel, PodcastEpisode

_FEED_URL = "https://example.com/feed.xml"
_BODY = b"0123456789" * 100  # 1000 bytes


@pytest.fixture
async def stream_app(app_sm):
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
async def client(stream_app):
    transport = ASGITransport(app=stream_app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.fixture
async def cleanup(app_sm):
    yield
    async with app_sm() as s:
        await s.execute(text("DELETE FROM jobs"))
        await s.execute(text("DELETE FROM podcast_progress"))
        await s.execute(text("DELETE FROM podcast_episode"))
        await s.execute(text("DELETE FROM podcast_channel"))
        await s.commit()


@pytest.fixture
async def downloaded_episode(app_sm, cleanup, tmp_path):
    audio_path = tmp_path / "ep.mp3"
    audio_path.write_bytes(_BODY)
    async with app_sm() as s:
        channel = PodcastChannel(feed_url=_FEED_URL, title="Test Show")
        s.add(channel)
        await s.flush()
        episode = PodcastEpisode(
            channel_id=channel.id,
            guid="ep-1",
            title="Episode 1",
            enclosure_url="https://example.com/ep1.mp3",
            downloaded_path=str(audio_path),
            downloaded_bytes=len(_BODY),
        )
        s.add(episode)
        await s.commit()
        return episode.id


@pytest.fixture
async def not_downloaded_episode(app_sm, cleanup):
    async with app_sm() as s:
        channel = PodcastChannel(feed_url=_FEED_URL, title="Test Show")
        s.add(channel)
        await s.flush()
        episode = PodcastEpisode(
            channel_id=channel.id,
            guid="ep-2",
            title="Episode 2",
            enclosure_url="https://example.com/ep2.mp3",
        )
        s.add(episode)
        await s.commit()
        return episode.id


async def test_stream_requires_auth(client, downloaded_episode):
    r = await client.get(f"/api/v1/podcasts/episodes/{downloaded_episode}/audio")
    assert r.status_code == 401


async def test_stream_unknown_episode_404(client, make_token):
    raw = await make_token()
    r = await client.get(
        f"/api/v1/podcasts/episodes/{uuid.uuid4()}/audio",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 404


async def test_stream_not_downloaded_returns_404(client, make_token, not_downloaded_episode):
    raw = await make_token()
    r = await client.get(
        f"/api/v1/podcasts/episodes/{not_downloaded_episode}/audio",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 404


async def test_stream_full_file_200(client, make_token, downloaded_episode):
    raw = await make_token()
    r = await client.get(
        f"/api/v1/podcasts/episodes/{downloaded_episode}/audio",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200
    assert r.content == _BODY
    assert r.headers["accept-ranges"] == "bytes"
    assert r.headers["content-type"] == "audio/mpeg"


async def test_stream_range_returns_206(client, make_token, downloaded_episode):
    raw = await make_token()
    r = await client.get(
        f"/api/v1/podcasts/episodes/{downloaded_episode}/audio",
        headers={"Authorization": f"Bearer {raw}", "Range": "bytes=10-19"},
    )
    assert r.status_code == 206
    assert r.content == _BODY[10:20]
    assert r.headers["content-range"] == f"bytes 10-19/{len(_BODY)}"
    assert r.headers["content-length"] == "10"


async def test_stream_suffix_range_returns_206(client, make_token, downloaded_episode):
    raw = await make_token()
    r = await client.get(
        f"/api/v1/podcasts/episodes/{downloaded_episode}/audio",
        headers={"Authorization": f"Bearer {raw}", "Range": "bytes=-10"},
    )
    assert r.status_code == 206
    assert r.content == _BODY[-10:]


async def test_stream_unsatisfiable_range_returns_416(client, make_token, downloaded_episode):
    raw = await make_token()
    r = await client.get(
        f"/api/v1/podcasts/episodes/{downloaded_episode}/audio",
        headers={"Authorization": f"Bearer {raw}", "Range": "bytes=5000-6000"},
    )
    assert r.status_code == 416
    assert r.headers["content-range"] == f"bytes */{len(_BODY)}"


async def test_stream_accepts_query_token(client, make_token, downloaded_episode):
    raw = await make_token()
    r = await client.get(f"/api/v1/podcasts/episodes/{downloaded_episode}/audio?token={raw}")
    assert r.status_code == 200
    assert r.content == _BODY


async def test_stream_missing_file_on_disk_returns_404(
    client, make_token, downloaded_episode, app_sm
):
    async with app_sm() as s:
        ep = await s.get(PodcastEpisode, downloaded_episode)
        os.remove(ep.downloaded_path)

    raw = await make_token()
    r = await client.get(
        f"/api/v1/podcasts/episodes/{downloaded_episode}/audio",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 404
