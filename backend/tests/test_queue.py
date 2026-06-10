import asyncio
import hashlib
from datetime import UTC

import pytest
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
    display_name: str | None = None,
    set_finished: bool = False,
):
    from datetime import datetime

    j = Job(
        source_url=source_url,
        source_type=source_type,
        state=state,
        display_name=display_name,
        created_by_token_id=token_id,
        finished_at=datetime.now(UTC) if set_finished else None,
    )
    async with app_sm() as s:
        s.add(j)
        await s.commit()
        await s.refresh(j)
    return j


# ---- auth -----------------------------------------------------------------


async def test_queue_requires_auth(client):
    r = await client.get("/api/v1/queue")
    assert r.status_code == 401


async def test_queue_requires_read_scope(client, make_token):
    raw = await make_token(scopes=("download",))
    r = await client.get("/api/v1/queue", headers={"Authorization": f"Bearer {raw}"})
    assert r.status_code == 403


# ---- shape ----------------------------------------------------------------


async def test_empty_queue_returns_empty_lists(client, make_token, cleanup):
    raw = await make_token()
    r = await client.get("/api/v1/queue", headers={"Authorization": f"Bearer {raw}"})
    assert r.status_code == 200
    body = r.json()
    assert body == {"active": [], "recent": []}


async def test_queue_separates_active_and_recent(client, make_token, app_sm, cleanup):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)

    q = await _seed_job(
        app_sm, token_id=token_id, source_url="https://www.youtube.com/watch?v=q", state="queued"
    )
    r_ = await _seed_job(
        app_sm,
        token_id=token_id,
        source_url="https://www.youtube.com/watch?v=r",
        state="running",
    )
    d = await _seed_job(
        app_sm,
        token_id=token_id,
        source_url="https://www.youtube.com/watch?v=d",
        state="done",
        set_finished=True,
    )
    f = await _seed_job(
        app_sm,
        token_id=token_id,
        source_url="https://www.youtube.com/watch?v=f",
        state="failed",
        set_finished=True,
    )

    body = (
        await client.get(
            "/api/v1/queue",
            headers={"Authorization": f"Bearer {raw}"},
        )
    ).json()

    active_ids = {it["job_id"] for it in body["active"]}
    recent_ids = {it["job_id"] for it in body["recent"]}
    assert active_ids == {str(q.id), str(r_.id)}
    assert recent_ids == {str(d.id), str(f.id)}


async def test_active_sorted_oldest_first(client, make_token, app_sm, cleanup):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)

    first = await _seed_job(
        app_sm, token_id=token_id, source_url="https://www.youtube.com/watch?v=older"
    )
    await asyncio.sleep(0.01)  # ensure later created_at
    second = await _seed_job(
        app_sm, token_id=token_id, source_url="https://www.youtube.com/watch?v=newer"
    )

    body = (
        await client.get(
            "/api/v1/queue",
            headers={"Authorization": f"Bearer {raw}"},
        )
    ).json()
    order = [it["job_id"] for it in body["active"]]
    assert order == [str(first.id), str(second.id)]


async def test_recent_sorted_newest_first(client, make_token, app_sm, cleanup):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)

    older = await _seed_job(
        app_sm,
        token_id=token_id,
        source_url="https://www.youtube.com/watch?v=f-older",
        state="done",
        set_finished=True,
    )
    await asyncio.sleep(0.01)
    newer = await _seed_job(
        app_sm,
        token_id=token_id,
        source_url="https://www.youtube.com/watch?v=f-newer",
        state="failed",
        set_finished=True,
    )

    body = (
        await client.get(
            "/api/v1/queue",
            headers={"Authorization": f"Bearer {raw}"},
        )
    ).json()
    order = [it["job_id"] for it in body["recent"]]
    assert order == [str(newer.id), str(older.id)]


async def test_recent_capped_at_20(client, make_token, app_sm, cleanup):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)

    for i in range(25):
        await _seed_job(
            app_sm,
            token_id=token_id,
            source_url=f"https://www.youtube.com/watch?v=bulk-{i}",
            state="done",
            set_finished=True,
        )

    body = (
        await client.get(
            "/api/v1/queue",
            headers={"Authorization": f"Bearer {raw}"},
        )
    ).json()
    assert len(body["recent"]) == 20


async def test_queue_returns_display_name_for_each_item(client, make_token, app_sm, cleanup):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    a = await _seed_job(
        app_sm,
        token_id=token_id,
        source_url="https://www.youtube.com/watch?v=disp-active",
        state="queued",
        display_name="Active Track — Artist",
    )
    d = await _seed_job(
        app_sm,
        token_id=token_id,
        source_url="https://www.youtube.com/watch?v=disp-done",
        state="done",
        display_name="Done Track — Artist",
        set_finished=True,
    )
    body = (
        await client.get(
            "/api/v1/queue",
            headers={"Authorization": f"Bearer {raw}"},
        )
    ).json()
    active = next(it for it in body["active"] if it["job_id"] == str(a.id))
    recent = next(it for it in body["recent"] if it["job_id"] == str(d.id))
    assert active["display_name"] == "Active Track — Artist"
    assert recent["display_name"] == "Done Track — Artist"


async def test_queue_display_name_null_when_unset(client, make_token, app_sm, cleanup):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    j = await _seed_job(
        app_sm,
        token_id=token_id,
        source_url="https://www.youtube.com/watch?v=no-disp-q",
        state="queued",
    )
    body = (
        await client.get(
            "/api/v1/queue",
            headers={"Authorization": f"Bearer {raw}"},
        )
    ).json()
    item = next(it for it in body["active"] if it["job_id"] == str(j.id))
    assert item["display_name"] is None


async def test_recent_track_has_output_path(client, make_token, app_sm, cleanup):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    job = await _seed_job(
        app_sm,
        token_id=token_id,
        source_url="https://www.youtube.com/watch?v=withdl",
        state="done",
        set_finished=True,
    )
    async with app_sm() as s:
        s.add(
            Download(
                source_url="https://www.youtube.com/watch?v=withdl",
                job_id=job.id,
                output_path="/data/media/music/withdl.mp3",
            )
        )
        await s.commit()

    body = (
        await client.get(
            "/api/v1/queue",
            headers={"Authorization": f"Bearer {raw}"},
        )
    ).json()
    item = next(it for it in body["recent"] if it["job_id"] == str(job.id))
    assert item["output_path"] == "/data/media/music/withdl.mp3"
