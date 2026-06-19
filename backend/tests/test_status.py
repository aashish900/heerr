import hashlib
import uuid
from datetime import UTC

import pytest
import sqlalchemy as sa
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

from app.api.v1.router import api_v1
from app.db import get_session
from app.models import Download, Job


@pytest.fixture
async def jobs_app(app_sm):
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
async def client(jobs_app):
    transport = ASGITransport(app=jobs_app)
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


async def _seed_job(
    app_sm,
    *,
    token_id,
    source_url: str,
    source_type: str = "song",
    state: str = "queued",
    error_msg: str | None = None,
    display_name: str | None = None,
    set_started: bool = False,
    set_finished: bool = False,
) -> Job:
    from datetime import datetime

    job = Job(
        source_url=source_url,
        source_type=source_type,
        state=state,
        display_name=display_name,
        error_msg=error_msg,
        created_by_token_id=token_id,
        user_id=sa.func.system_admin_user_id(),
        started_at=datetime.now(UTC) if set_started else None,
        finished_at=datetime.now(UTC) if set_finished else None,
    )
    async with app_sm() as s:
        s.add(job)
        await s.commit()
        await s.refresh(job)
    return job


async def _seed_download(app_sm, *, job_id, source_url, path):
    async with app_sm() as s:
        s.add(
            Download(
                source_url=source_url,
                job_id=job_id,
                user_id=sa.func.system_admin_user_id(),
                output_path=path,
            )
        )
        await s.commit()


# ---- auth -----------------------------------------------------------------


async def test_status_requires_auth(client):
    r = await client.get(f"/api/v1/status/{uuid.uuid4()}")
    assert r.status_code == 401


async def test_status_requires_read_scope(client, make_token):
    raw = await make_token(scopes=("download",))
    r = await client.get(
        f"/api/v1/status/{uuid.uuid4()}",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 403


# ---- 404 ------------------------------------------------------------------


async def test_status_unknown_id_returns_404(client, make_token):
    raw = await make_token()
    r = await client.get(
        f"/api/v1/status/{uuid.uuid4()}",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 404


async def test_status_invalid_uuid_returns_422(client, make_token):
    raw = await make_token()
    r = await client.get(
        "/api/v1/status/not-a-uuid",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 422


# ---- contract shape -------------------------------------------------------


async def test_queued_track_has_full_contract_shape(client, make_token, app_sm, cleanup):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    job = await _seed_job(
        app_sm,
        token_id=token_id,
        source_url="https://www.youtube.com/watch?v=q1",
        state="queued",
    )
    r = await client.get(
        f"/api/v1/status/{job.id}",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200
    body = r.json()
    assert set(body.keys()) == {
        "job_id",
        "source_url",
        "source_type",
        "state",
        "display_name",
        "progress",
        "error",
        "output_path",
        "created_at",
        "started_at",
        "finished_at",
    }
    assert body["state"] == "queued"
    assert body["display_name"] is None
    assert body["progress"] is None
    assert body["error"] is None
    assert body["output_path"] is None
    assert body["started_at"] is None
    assert body["finished_at"] is None


async def test_status_returns_stored_display_name(client, make_token, app_sm, cleanup):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    job = await _seed_job(
        app_sm,
        token_id=token_id,
        source_url="https://www.youtube.com/watch?v=disp-status",
        state="queued",
        display_name="Imagine — John Lennon",
    )
    r = await client.get(
        f"/api/v1/status/{job.id}",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200
    assert r.json()["display_name"] == "Imagine — John Lennon"


async def test_running_job_has_started_at(client, make_token, app_sm, cleanup):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    job = await _seed_job(
        app_sm,
        token_id=token_id,
        source_url="https://www.youtube.com/watch?v=run1",
        state="running",
        set_started=True,
    )
    r = await client.get(
        f"/api/v1/status/{job.id}",
        headers={"Authorization": f"Bearer {raw}"},
    )
    body = r.json()
    assert body["state"] == "running"
    assert body["started_at"] is not None
    assert body["finished_at"] is None


async def test_done_track_has_output_path(client, make_token, app_sm, cleanup):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    job = await _seed_job(
        app_sm,
        token_id=token_id,
        source_url="https://www.youtube.com/watch?v=done1",
        state="done",
        set_started=True,
        set_finished=True,
    )
    await _seed_download(
        app_sm,
        job_id=job.id,
        source_url="https://www.youtube.com/watch?v=done1",
        path="/data/media/music/done1.mp3",
    )
    r = await client.get(
        f"/api/v1/status/{job.id}",
        headers={"Authorization": f"Bearer {raw}"},
    )
    body = r.json()
    assert body["state"] == "done"
    assert body["output_path"] == "/data/media/music/done1.mp3"
    assert body["finished_at"] is not None


async def test_done_album_has_no_output_path(client, make_token, app_sm, cleanup):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    job = await _seed_job(
        app_sm,
        token_id=token_id,
        source_url="https://music.youtube.com/browse/done-al",
        source_type="album",
        state="done",
        set_started=True,
        set_finished=True,
    )
    r = await client.get(
        f"/api/v1/status/{job.id}",
        headers={"Authorization": f"Bearer {raw}"},
    )
    body = r.json()
    assert body["state"] == "done"
    assert body["output_path"] is None


async def test_failed_job_has_error(client, make_token, app_sm, cleanup):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    job = await _seed_job(
        app_sm,
        token_id=token_id,
        source_url="https://www.youtube.com/watch?v=fail1",
        state="failed",
        error_msg="spotdl crashed",
        set_started=True,
        set_finished=True,
    )
    r = await client.get(
        f"/api/v1/status/{job.id}",
        headers={"Authorization": f"Bearer {raw}"},
    )
    body = r.json()
    assert body["state"] == "failed"
    assert body["error"] == "spotdl crashed"
    assert body["output_path"] is None


# ---- J8: per-user isolation -----------------------------------------------


async def test_status_404_for_other_users_job(client, app_sm, cleanup):
    """user-A requesting user-B's job id gets 404 (no leak)."""
    import hashlib
    import secrets
    import uuid

    from sqlalchemy import text

    from app.models import Job, Token, User

    async with app_sm() as s:
        ua = User(navidrome_username=f"alice-{uuid.uuid4().hex[:8]}")
        ub = User(navidrome_username=f"bob-{uuid.uuid4().hex[:8]}")
        s.add_all([ua, ub])
        await s.flush()

        raw_a = f"raw-{secrets.token_urlsafe(16)}"
        s.add(
            Token(
                token_hash=hashlib.sha256(raw_a.encode()).hexdigest(),
                scopes=["read", "download"],
                user_id=ua.id,
            )
        )
        await s.flush()

        # Job belongs to bob; alice tries to read it.
        tok_b_id = (
            await s.execute(
                text(
                    "INSERT INTO tokens (token_hash, scopes, user_id)"
                    " VALUES (:h, ARRAY['read','download']::text[], :u) RETURNING id"
                ),
                {
                    "h": hashlib.sha256(secrets.token_urlsafe(16).encode()).hexdigest(),
                    "u": str(ub.id),
                },
            )
        ).scalar_one()
        bob_job = Job(
            source_url="https://www.youtube.com/watch?v=bobs",
            source_type="song",
            state="queued",
            created_by_token_id=tok_b_id,
            user_id=ub.id,
        )
        s.add(bob_job)
        await s.commit()
        bob_job_id = str(bob_job.id)

    r = await client.get(
        f"/api/v1/status/{bob_job_id}", headers={"Authorization": f"Bearer {raw_a}"}
    )
    assert r.status_code == 404


async def test_status_admin_can_read_any_users_job(client, app_sm, make_token, cleanup):
    import hashlib
    import secrets
    import uuid

    from sqlalchemy import text

    from app.models import Job, User

    async with app_sm() as s:
        u = User(navidrome_username=f"dana-{uuid.uuid4().hex[:8]}")
        s.add(u)
        await s.flush()
        tok_id = (
            await s.execute(
                text(
                    "INSERT INTO tokens (token_hash, scopes, user_id)"
                    " VALUES (:h, ARRAY['read','download']::text[], :u) RETURNING id"
                ),
                {
                    "h": hashlib.sha256(secrets.token_urlsafe(16).encode()).hexdigest(),
                    "u": str(u.id),
                },
            )
        ).scalar_one()
        job = Job(
            source_url="https://www.youtube.com/watch?v=danas",
            source_type="song",
            state="queued",
            created_by_token_id=tok_id,
            user_id=u.id,
        )
        s.add(job)
        await s.commit()
        jid = str(job.id)

    raw_admin = await make_token(is_admin=True)
    r = await client.get(f"/api/v1/status/{jid}", headers={"Authorization": f"Bearer {raw_admin}"})
    assert r.status_code == 200
    assert r.json()["job_id"] == jid
