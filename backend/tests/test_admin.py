import hashlib
import uuid
from datetime import UTC
from uuid import UUID

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

from app.api.v1.router import api_v1
from app.db import get_session
from app.models import Job
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
async def admin_app(app_sm, fake_enqueuer):
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
async def client(admin_app):
    transport = ASGITransport(app=admin_app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.fixture
async def cleanup(app_sm):
    """Wipe rows the test creates so tests don't see each other's tokens/jobs."""
    yield
    async with app_sm() as s:
        await s.execute(text("DELETE FROM downloads"))
        await s.execute(text("DELETE FROM jobs"))
        # tokens created by admin endpoint stay until end-of-test;
        # delete everything except those owned by make_token (which has its own cleanup).
        await s.execute(text("DELETE FROM tokens WHERE owner_label LIKE 'admin-test-%'"))
        await s.commit()


async def _token_id_for(app_sm, raw: str):
    h = hashlib.sha256(raw.encode()).hexdigest()
    async with app_sm() as s:
        r = await s.execute(text("SELECT id FROM tokens WHERE token_hash = :h"), {"h": h})
        return r.scalar_one()


# ---- auth gates -----------------------------------------------------------


async def test_admin_endpoints_require_auth(client):
    for method, path in [
        ("POST", "/api/v1/admin/tokens"),
        ("GET", "/api/v1/admin/tokens"),
        ("POST", f"/api/v1/admin/tokens/{uuid.uuid4()}/revoke"),
        ("POST", f"/api/v1/admin/jobs/{uuid.uuid4()}/retry"),
    ]:
        r = await client.request(method, path, json={})
        assert r.status_code == 401, f"{method} {path}"


async def test_non_admin_token_returns_403(client, make_token):
    raw = await make_token(is_admin=False, scopes=("read", "download"))
    h = {"Authorization": f"Bearer {raw}"}
    r = await client.get("/api/v1/admin/tokens", headers=h)
    assert r.status_code == 403


# ---- POST /admin/tokens ---------------------------------------------------


async def test_create_token_returns_raw_once_and_persists_hash(client, make_token, app_sm, cleanup):
    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    r = await client.post(
        "/api/v1/admin/tokens",
        headers=h,
        json={
            "owner_label": "admin-test-aashish",
            "scopes": ["read", "download"],
            "is_admin": False,
        },
    )
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["raw_token"]
    assert body["owner_label"] == "admin-test-aashish"
    assert set(body["scopes"]) == {"read", "download"}
    assert body["is_admin"] is False

    raw_new = body["raw_token"]
    raw_hash = hashlib.sha256(raw_new.encode()).hexdigest()
    async with app_sm() as s:
        rec = (
            await s.execute(
                text("SELECT token_hash, owner_label FROM tokens " "WHERE token_hash = :h"),
                {"h": raw_hash},
            )
        ).first()
        assert rec is not None
        assert rec.owner_label == "admin-test-aashish"

    # raw should NOT appear stored anywhere
    async with app_sm() as s:
        leaked = (
            await s.execute(
                text("SELECT count(*) FROM tokens WHERE token_hash = :raw"),
                {"raw": raw_new},
            )
        ).scalar_one()
        assert leaked == 0


async def test_create_token_invalid_scope_returns_422(client, make_token, cleanup):
    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    r = await client.post(
        "/api/v1/admin/tokens",
        headers=h,
        json={"owner_label": "x", "scopes": ["bogus"]},
    )
    assert r.status_code == 422


async def test_create_token_empty_scopes_returns_422(client, make_token, cleanup):
    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    r = await client.post(
        "/api/v1/admin/tokens",
        headers=h,
        json={"owner_label": "x", "scopes": []},
    )
    assert r.status_code == 422


# ---- GET /admin/tokens ----------------------------------------------------


async def test_list_tokens_does_not_leak_hash_or_raw(client, make_token, cleanup):
    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    r1 = await client.post(
        "/api/v1/admin/tokens",
        headers=h,
        json={
            "owner_label": "admin-test-listed",
            "scopes": ["read"],
        },
    )
    raw_new = r1.json()["raw_token"]
    raw_hash = hashlib.sha256(raw_new.encode()).hexdigest()

    r2 = await client.get("/api/v1/admin/tokens", headers=h)
    assert r2.status_code == 200
    body = r2.json()
    assert any(t["owner_label"] == "admin-test-listed" for t in body)
    # Neither the raw nor the hash should appear in the JSON
    serialized = r2.text
    assert raw_new not in serialized
    assert raw_hash not in serialized


# ---- POST /admin/tokens/{id}/revoke --------------------------------------


async def test_revoke_token_sets_revoked_at(client, make_token, cleanup):
    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    create_r = await client.post(
        "/api/v1/admin/tokens",
        headers=h,
        json={"owner_label": "admin-test-revoke", "scopes": ["read"]},
    )
    token_id = create_r.json()["id"]

    revoke_r = await client.post(f"/api/v1/admin/tokens/{token_id}/revoke", headers=h)
    assert revoke_r.status_code == 204

    list_r = await client.get("/api/v1/admin/tokens", headers=h)
    target = next(t for t in list_r.json() if t["id"] == token_id)
    assert target["revoked_at"] is not None


async def test_revoke_unknown_token_returns_404(client, make_token, cleanup):
    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    r = await client.post(f"/api/v1/admin/tokens/{uuid.uuid4()}/revoke", headers=h)
    assert r.status_code == 404


async def test_revoke_already_revoked_returns_409(client, make_token, cleanup):
    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    create_r = await client.post(
        "/api/v1/admin/tokens",
        headers=h,
        json={"owner_label": "admin-test-dblrev", "scopes": ["read"]},
    )
    token_id = create_r.json()["id"]
    await client.post(f"/api/v1/admin/tokens/{token_id}/revoke", headers=h)
    r = await client.post(f"/api/v1/admin/tokens/{token_id}/revoke", headers=h)
    assert r.status_code == 409


# ---- POST /admin/jobs/{id}/retry -----------------------------------------


async def _seed_job(
    app_sm,
    *,
    token_id,
    spotify_uri: str,
    state: str = "failed",
    error_msg: str | None = None,
    attempt_count: int = 1,
):
    from datetime import datetime

    j = Job(
        spotify_uri=spotify_uri,
        spotify_type="track",
        state=state,
        error_msg=error_msg,
        attempt_count=attempt_count,
        created_by_token_id=token_id,
        finished_at=datetime.now(UTC) if state in ("done", "failed") else None,
    )
    async with app_sm() as s:
        s.add(j)
        await s.commit()
        await s.refresh(j)
    return j


async def test_retry_failed_job_resets_state_and_enqueues_worker(
    client, make_token, fake_enqueuer, app_sm, cleanup
):
    raw_admin = await make_token(is_admin=True)
    token_id = await _token_id_for(app_sm, raw_admin)
    job = await _seed_job(
        app_sm,
        token_id=token_id,
        spotify_uri="spotify:track:retry-1",
        state="failed",
        error_msg="boom",
        attempt_count=2,
    )

    h = {"Authorization": f"Bearer {raw_admin}"}
    r = await client.post(f"/api/v1/admin/jobs/{job.id}/retry", headers=h)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["state"] == "queued"
    assert body["error"] is None
    assert body["finished_at"] is None
    assert fake_enqueuer.calls == [job.id]

    async with app_sm() as s:
        row = (
            await s.execute(
                text("SELECT state, attempt_count, error_msg " "FROM jobs WHERE id = :i"),
                {"i": job.id},
            )
        ).first()
        assert row.state == "queued"
        assert row.attempt_count == 3
        assert row.error_msg is None


@pytest.mark.parametrize("state", ["queued", "running", "done"])
async def test_retry_non_failed_returns_409(client, make_token, app_sm, state, cleanup):
    raw_admin = await make_token(is_admin=True)
    token_id = await _token_id_for(app_sm, raw_admin)
    job = await _seed_job(
        app_sm,
        token_id=token_id,
        spotify_uri=f"spotify:track:state-{state}",
        state=state,
    )
    h = {"Authorization": f"Bearer {raw_admin}"}
    r = await client.post(f"/api/v1/admin/jobs/{job.id}/retry", headers=h)
    assert r.status_code == 409


async def test_retry_unknown_job_returns_404(client, make_token, cleanup):
    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    r = await client.post(f"/api/v1/admin/jobs/{uuid.uuid4()}/retry", headers=h)
    assert r.status_code == 404


async def test_retry_blocked_when_another_active_job_for_same_uri(
    client, make_token, app_sm, cleanup
):
    raw_admin = await make_token(is_admin=True)
    token_id = await _token_id_for(app_sm, raw_admin)
    uri = "spotify:track:race-retry"
    # Failed job and an active queued job (different rows) on the same URI
    failed = await _seed_job(
        app_sm,
        token_id=token_id,
        spotify_uri=uri,
        state="failed",
    )
    await _seed_job(
        app_sm,
        token_id=token_id,
        spotify_uri=uri,
        state="queued",
    )
    h = {"Authorization": f"Bearer {raw_admin}"}
    r = await client.post(f"/api/v1/admin/jobs/{failed.id}/retry", headers=h)
    assert r.status_code == 409
