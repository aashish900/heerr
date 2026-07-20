import uuid

import pytest
from fastapi import BackgroundTasks, FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

from app.api.v1.router import api_v1
from app.db import get_session
from app.models import PodcastChannel, PodcastEpisode
from app.services.workers import get_podcast_enqueuer

_FEED_URL = "https://example.com/feed.xml"
_ENCLOSURE_URL = "https://example.com/ep1.mp3"


class FakeEnqueuer:
    def __init__(self):
        self.calls: list[uuid.UUID] = []

    def __call__(self, bg: BackgroundTasks, job_id: uuid.UUID) -> None:
        self.calls.append(job_id)


@pytest.fixture
async def fake_enqueuer():
    return FakeEnqueuer()


@pytest.fixture
async def download_app(app_sm, fake_enqueuer):
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
    app.dependency_overrides[get_podcast_enqueuer] = lambda: fake_enqueuer
    app.include_router(api_v1)
    yield app


@pytest.fixture
async def client(download_app):
    transport = ASGITransport(app=download_app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.fixture
async def cleanup(app_sm):
    yield
    async with app_sm() as s:
        await s.execute(text("DELETE FROM jobs"))
        await s.execute(text("DELETE FROM podcast_episode"))
        await s.execute(text("DELETE FROM podcast_channel"))
        await s.commit()


@pytest.fixture
async def episode_id(app_sm, cleanup):
    async with app_sm() as s:
        channel = PodcastChannel(feed_url=_FEED_URL, title="Test Show")
        s.add(channel)
        await s.flush()
        episode = PodcastEpisode(
            channel_id=channel.id,
            guid="ep-1",
            title="Episode 1",
            enclosure_url=_ENCLOSURE_URL,
        )
        s.add(episode)
        await s.commit()
        return episode.id


async def test_download_requires_auth(client, episode_id):
    r = await client.post(f"/api/v1/podcasts/episodes/{episode_id}/download")
    assert r.status_code == 401


async def test_download_requires_download_scope(client, make_token, episode_id):
    raw = await make_token(scopes=("read",))
    r = await client.post(
        f"/api/v1/podcasts/episodes/{episode_id}/download",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 403


async def test_download_unknown_episode_404(client, make_token):
    raw = await make_token()
    r = await client.post(
        f"/api/v1/podcasts/episodes/{uuid.uuid4()}/download",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 404


async def test_download_enqueues_job(client, make_token, episode_id, fake_enqueuer):
    raw = await make_token()
    r = await client.post(
        f"/api/v1/podcasts/episodes/{episode_id}/download",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 202
    body = r.json()
    assert body["state"] == "queued"
    assert body["deduped"] is False
    assert len(fake_enqueuer.calls) == 1
    assert str(fake_enqueuer.calls[0]) == body["job_id"]


async def test_download_is_idempotent_while_active(client, make_token, episode_id, fake_enqueuer):
    raw = await make_token()
    headers = {"Authorization": f"Bearer {raw}"}
    r1 = await client.post(f"/api/v1/podcasts/episodes/{episode_id}/download", headers=headers)
    r2 = await client.post(f"/api/v1/podcasts/episodes/{episode_id}/download", headers=headers)

    assert r1.json()["deduped"] is False
    assert r2.json()["deduped"] is True
    assert r1.json()["job_id"] == r2.json()["job_id"]
    # only the first call enqueues a background task
    assert len(fake_enqueuer.calls) == 1


async def test_download_job_appears_in_queue(client, make_token, episode_id):
    raw = await make_token()
    r = await client.post(
        f"/api/v1/podcasts/episodes/{episode_id}/download",
        headers={"Authorization": f"Bearer {raw}"},
    )
    job_id = r.json()["job_id"]

    q = await client.get("/api/v1/queue", headers={"Authorization": f"Bearer {raw}"})
    assert q.status_code == 200
    ids = {j["job_id"] for j in q.json()["active"]}
    assert job_id in ids
