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

_SONG_URL = "https://www.youtube.com/watch?v=abc"
_ALBUM_URL = "https://music.youtube.com/browse/al1"
_PLAYLIST_URL = "https://music.youtube.com/browse/pl1"


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
    async with AsyncClient(transport=transport, base_url="http://test") as c:
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
        r = await s.execute(text("SELECT id FROM tokens WHERE token_hash = :h"), {"h": h})
        return r.scalar_one()


# ---- auth / scope ---------------------------------------------------------


async def test_download_requires_auth(client):
    r = await client.post(
        "/api/v1/download",
        json={"source_url": _SONG_URL, "source_type": "song"},
    )
    assert r.status_code == 401


async def test_download_requires_download_scope(client, make_token):
    raw = await make_token(scopes=("read",))
    r = await client.post(
        "/api/v1/download",
        json={"source_url": _SONG_URL, "source_type": "song"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 403


# ---- URL validation -------------------------------------------------------


@pytest.mark.parametrize(
    "url",
    [
        "",
        "not-a-url",
        "https://vimeo.com/abc",
        "https://www.youtube.com/watch?v=",  # empty video ID
        "https://open.spotify.com/track/abc",
        "https://music.youtube.com/browse/",  # empty browse ID
    ],
)
async def test_invalid_url_returns_422(client, make_token, url):
    raw = await make_token()
    r = await client.post(
        "/api/v1/download",
        json={"source_url": url, "source_type": "song"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 422


async def test_unknown_field_returns_422(client, make_token):
    raw = await make_token()
    r = await client.post(
        "/api/v1/download",
        json={"source_url": _SONG_URL, "source_type": "song", "extra": 1},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 422


# ---- new-URL dispatch -----------------------------------------------------


async def test_new_song_url_creates_queued_job_and_enqueues_worker(
    client, make_token, fake_enqueuer, app_sm, cleanup
):
    raw = await make_token()
    url = "https://www.youtube.com/watch?v=new1"
    r = await client.post(
        "/api/v1/download",
        json={"source_url": url, "source_type": "song"},
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
                text("SELECT source_url, source_type, state FROM jobs WHERE id = :i"),
                {"i": job_id},
            )
        ).first()
        assert row.source_url == url
        assert row.source_type == "song"
        assert row.state == "queued"


async def test_download_persists_display_name(client, make_token, fake_enqueuer, app_sm, cleanup):
    raw = await make_token()
    url = "https://www.youtube.com/watch?v=disp1"
    r = await client.post(
        "/api/v1/download",
        json={"source_url": url, "source_type": "song", "display_name": "Imagine — John Lennon"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 202, r.text
    job_id = UUID(r.json()["job_id"])
    async with app_sm() as s:
        name = (
            await s.execute(
                text("SELECT display_name FROM jobs WHERE id = :i"),
                {"i": job_id},
            )
        ).scalar_one()
    assert name == "Imagine — John Lennon"


async def test_download_display_name_is_optional(
    client, make_token, fake_enqueuer, app_sm, cleanup
):
    raw = await make_token()
    url = "https://www.youtube.com/watch?v=nodisp1"
    r = await client.post(
        "/api/v1/download",
        json={"source_url": url, "source_type": "song"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 202, r.text
    job_id = UUID(r.json()["job_id"])
    async with app_sm() as s:
        name = (
            await s.execute(
                text("SELECT display_name FROM jobs WHERE id = :i"),
                {"i": job_id},
            )
        ).scalar_one()
    assert name is None


async def test_new_album_url_uses_album_type(client, make_token, fake_enqueuer, app_sm, cleanup):
    raw = await make_token()
    r = await client.post(
        "/api/v1/download",
        json={"source_url": _ALBUM_URL, "source_type": "album"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 202
    job_id = UUID(r.json()["job_id"])
    async with app_sm() as s:
        type_ = (
            await s.execute(
                text("SELECT source_type FROM jobs WHERE id = :i"),
                {"i": job_id},
            )
        ).scalar_one()
    assert type_ == "album"


async def test_new_playlist_url_uses_playlist_type(
    client, make_token, fake_enqueuer, app_sm, cleanup
):
    raw = await make_token()
    r = await client.post(
        "/api/v1/download",
        json={"source_url": _PLAYLIST_URL, "source_type": "playlist"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 202
    job_id = UUID(r.json()["job_id"])
    async with app_sm() as s:
        type_ = (
            await s.execute(
                text("SELECT source_type FROM jobs WHERE id = :i"),
                {"i": job_id},
            )
        ).scalar_one()
    assert type_ == "playlist"


# ---- idempotency: active-job dedupe --------------------------------------


async def test_active_job_returns_existing_with_deduped_true(
    client, make_token, fake_enqueuer, app_sm, cleanup
):
    raw = await make_token()
    url = "https://www.youtube.com/watch?v=dup"
    r1 = await client.post(
        "/api/v1/download",
        json={"source_url": url, "source_type": "song"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    first_job_id = r1.json()["job_id"]

    r2 = await client.post(
        "/api/v1/download",
        json={"source_url": url, "source_type": "song"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r2.status_code == 202
    body = r2.json()
    assert body["deduped"] is True
    assert body["job_id"] == first_job_id
    assert len(fake_enqueuer.calls) == 1


# ---- idempotency: already on disk -----------------------------------------


async def test_on_disk_song_returns_synthetic_done(
    client, make_token, fake_enqueuer, app_sm, cleanup
):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    url = "https://www.youtube.com/watch?v=on-disk"

    job_id = uuid.uuid4()
    async with app_sm() as s:
        s.add(
            Job(
                id=job_id,
                source_url=url,
                source_type="song",
                state="done",
                created_by_token_id=token_id,
            )
        )
        await s.flush()
        s.add(
            Download(
                source_url=url,
                job_id=job_id,
                output_path="/data/media/music/on-disk.mp3",
            )
        )
        await s.commit()

    r = await client.post(
        "/api/v1/download",
        json={"source_url": url, "source_type": "song"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 202
    body = r.json()
    assert body["state"] == "done"
    assert body["deduped"] is True
    assert body["job_id"] == str(job_id)
    assert fake_enqueuer.calls == []


# ---- J9: per-user idempotency --------------------------------------------


async def test_download_same_url_different_users_creates_separate_jobs(
    client, app_sm, fake_enqueuer, cleanup
):
    """user-A's active job for X does not block user-B's /download X."""
    import hashlib
    import secrets
    import uuid as _uuid

    from app.models import Token, User

    async with app_sm() as s:
        ua = User(navidrome_username=f"alice-{_uuid.uuid4().hex[:8]}")
        ub = User(navidrome_username=f"bob-{_uuid.uuid4().hex[:8]}")
        s.add_all([ua, ub])
        await s.flush()
        raw_a = f"raw-{secrets.token_urlsafe(16)}"
        raw_b = f"raw-{secrets.token_urlsafe(16)}"
        s.add(
            Token(
                token_hash=hashlib.sha256(raw_a.encode()).hexdigest(),
                owner_label=ua.navidrome_username,
                scopes=["read", "download"],
                user_id=ua.id,
            )
        )
        s.add(
            Token(
                token_hash=hashlib.sha256(raw_b.encode()).hexdigest(),
                owner_label=ub.navidrome_username,
                scopes=["read", "download"],
                user_id=ub.id,
            )
        )
        await s.commit()

    url = "https://www.youtube.com/watch?v=shared-dl"

    # user-A queues the URL.
    ra = await client.post(
        "/api/v1/download",
        json={"source_url": url, "source_type": "song"},
        headers={"Authorization": f"Bearer {raw_a}"},
    )
    assert ra.status_code == 202
    a_body = ra.json()
    assert a_body["deduped"] is False
    a_job_id = a_body["job_id"]

    # user-B queues the SAME URL — must get a fresh job, not user-A's.
    rb = await client.post(
        "/api/v1/download",
        json={"source_url": url, "source_type": "song"},
        headers={"Authorization": f"Bearer {raw_b}"},
    )
    assert rb.status_code == 202
    b_body = rb.json()
    assert b_body["deduped"] is False
    assert b_body["job_id"] != a_job_id

    # user-A re-POSTing the same URL still dedupes for themselves.
    ra2 = await client.post(
        "/api/v1/download",
        json={"source_url": url, "source_type": "song"},
        headers={"Authorization": f"Bearer {raw_a}"},
    )
    assert ra2.status_code == 202
    assert ra2.json()["deduped"] is True
    assert ra2.json()["job_id"] == a_job_id
