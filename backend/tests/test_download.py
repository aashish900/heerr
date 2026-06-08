import hashlib
import uuid
from uuid import UUID

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

from app.api.v1.router import api_v1
from app.db import get_session
from app.models import Download, Job
from app.services.workers import get_enqueuer


class RecordingEnqueuer:
    def __init__(self):
        self.calls: list[UUID] = []

    def __call__(self, bg, job_id):
        self.calls.append(job_id)


@pytest.fixture
async def fake_enqueuer():
    return RecordingEnqueuer()


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
    app.dependency_overrides[get_enqueuer] = lambda: fake_enqueuer
    app.include_router(api_v1)
    yield app


@pytest.fixture
async def client(download_app):
    transport = ASGITransport(app=download_app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as c:
        yield c


@pytest.fixture
async def cleanup(app_sm):
    yield
    async with app_sm() as s:
        await s.execute(text("DELETE FROM downloads"))
        await s.execute(text("DELETE FROM jobs"))
        await s.commit()


async def _token_id_for(app_sm, raw: str):
    h = hashlib.sha256(raw.encode()).hexdigest()
    async with app_sm() as s:
        r = await s.execute(
            text("SELECT id FROM tokens WHERE token_hash = :h"), {"h": h}
        )
        return r.scalar_one()


# ---- auth / scope ---------------------------------------------------------


async def test_download_requires_auth(client):
    r = await client.post(
        "/api/v1/download",
        json={"spotify_uri": "spotify:track:abc"},
    )
    assert r.status_code == 401


async def test_download_requires_download_scope(client, make_token):
    raw = await make_token(scopes=("read",))
    r = await client.post(
        "/api/v1/download",
        json={"spotify_uri": "spotify:track:abc"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 403


# ---- URI validation -------------------------------------------------------


@pytest.mark.parametrize(
    "uri",
    [
        "",
        "not-a-uri",
        "spotify:podcast:abc",
        "spotify:track:",
        "https://open.spotify.com/track/abc",
        "spotify::abc",
    ],
)
async def test_invalid_uri_returns_422(client, make_token, uri):
    raw = await make_token()
    r = await client.post(
        "/api/v1/download",
        json={"spotify_uri": uri},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 422


async def test_unknown_field_returns_422(client, make_token):
    raw = await make_token()
    r = await client.post(
        "/api/v1/download",
        json={"spotify_uri": "spotify:track:abc", "extra": 1},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 422


# ---- new-URI dispatch -----------------------------------------------------


async def test_new_track_uri_creates_queued_job_and_enqueues_worker(
    client, make_token, fake_enqueuer, app_sm, cleanup
):
    raw = await make_token()
    uri = "spotify:track:new1"
    r = await client.post(
        "/api/v1/download",
        json={"spotify_uri": uri},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 202, r.text
    body = r.json()
    assert body["state"] == "queued"
    assert body["deduped"] is False
    job_id = UUID(body["job_id"])
    assert fake_enqueuer.calls == [job_id]

    async with app_sm() as s:
        row = (
            await s.execute(
                text("SELECT spotify_uri, spotify_type, state FROM jobs WHERE id = :i"),
                {"i": job_id},
            )
        ).first()
        assert row.spotify_uri == uri
        assert row.spotify_type == "track"
        assert row.state == "queued"


async def test_new_album_uri_uses_album_type(
    client, make_token, fake_enqueuer, app_sm, cleanup
):
    raw = await make_token()
    uri = "spotify:album:al1"
    r = await client.post(
        "/api/v1/download",
        json={"spotify_uri": uri},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 202
    body = r.json()
    job_id = UUID(body["job_id"])
    async with app_sm() as s:
        type_ = (
            await s.execute(
                text("SELECT spotify_type FROM jobs WHERE id = :i"),
                {"i": job_id},
            )
        ).scalar_one()
    assert type_ == "album"


async def test_new_playlist_uri_uses_playlist_type(
    client, make_token, fake_enqueuer, app_sm, cleanup
):
    raw = await make_token()
    uri = "spotify:playlist:pl1"
    r = await client.post(
        "/api/v1/download",
        json={"spotify_uri": uri},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 202
    body = r.json()
    job_id = UUID(body["job_id"])
    async with app_sm() as s:
        type_ = (
            await s.execute(
                text("SELECT spotify_type FROM jobs WHERE id = :i"),
                {"i": job_id},
            )
        ).scalar_one()
    assert type_ == "playlist"


# ---- idempotency: active-job dedupe --------------------------------------


async def test_active_job_returns_existing_with_deduped_true(
    client, make_token, fake_enqueuer, app_sm, cleanup
):
    raw = await make_token()
    uri = "spotify:track:dup"
    r1 = await client.post(
        "/api/v1/download",
        json={"spotify_uri": uri},
        headers={"Authorization": f"Bearer {raw}"},
    )
    first_job_id = r1.json()["job_id"]

    r2 = await client.post(
        "/api/v1/download",
        json={"spotify_uri": uri},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r2.status_code == 202
    body = r2.json()
    assert body["deduped"] is True
    assert body["job_id"] == first_job_id
    # second call must not enqueue another worker
    assert len(fake_enqueuer.calls) == 1


# ---- idempotency: already on disk -----------------------------------------


async def test_on_disk_track_returns_synthetic_done(
    client, make_token, fake_enqueuer, app_sm, cleanup
):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    uri = "spotify:track:on-disk"

    # seed a completed job + download
    job_id = uuid.uuid4()
    async with app_sm() as s:
        s.add(
            Job(
                id=job_id,
                spotify_uri=uri,
                spotify_type="track",
                state="done",
                created_by_token_id=token_id,
            )
        )
        await s.flush()
        s.add(
            Download(
                spotify_track_uri=uri,
                job_id=job_id,
                output_path="/data/media/music/on-disk.mp3",
            )
        )
        await s.commit()

    r = await client.post(
        "/api/v1/download",
        json={"spotify_uri": uri},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 202
    body = r.json()
    assert body["state"] == "done"
    assert body["deduped"] is True
    assert body["job_id"] == str(job_id)
    assert fake_enqueuer.calls == []  # no worker scheduled
