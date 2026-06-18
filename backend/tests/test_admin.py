import hashlib
import uuid
from datetime import UTC
from uuid import UUID

import pytest
import sqlalchemy as sa
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
        ("POST", "/api/v1/admin/users"),
        ("GET", "/api/v1/admin/users"),
        ("DELETE", f"/api/v1/admin/users/{uuid.uuid4()}"),
        ("GET", "/api/v1/admin/jobs"),
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
            "navidrome_username": "system-admin",
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
        json={"owner_label": "x", "scopes": ["bogus"], "navidrome_username": "system-admin"},
    )
    assert r.status_code == 422


async def test_create_token_empty_scopes_returns_422(client, make_token, cleanup):
    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    r = await client.post(
        "/api/v1/admin/tokens",
        headers=h,
        json={"owner_label": "x", "scopes": [], "navidrome_username": "system-admin"},
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
            "navidrome_username": "system-admin",
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
        json={
            "owner_label": "admin-test-revoke",
            "scopes": ["read"],
            "navidrome_username": "system-admin",
        },
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
        json={
            "owner_label": "admin-test-dblrev",
            "scopes": ["read"],
            "navidrome_username": "system-admin",
        },
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
    source_url: str,
    state: str = "failed",
    error_msg: str | None = None,
    attempt_count: int = 1,
):
    from datetime import datetime

    j = Job(
        source_url=source_url,
        source_type="song",
        state=state,
        error_msg=error_msg,
        attempt_count=attempt_count,
        created_by_token_id=token_id,
        user_id=sa.func.system_admin_user_id(),
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
        source_url="https://www.youtube.com/watch?v=retry-1",
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
        source_url=f"https://www.youtube.com/watch?v=state-{state}",
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
    uri = "https://www.youtube.com/watch?v=race-retry"
    # Failed job and an active queued job (different rows) on the same URI
    failed = await _seed_job(
        app_sm,
        token_id=token_id,
        source_url=uri,
        state="failed",
    )
    await _seed_job(
        app_sm,
        token_id=token_id,
        source_url=uri,
        state="queued",
    )
    h = {"Authorization": f"Bearer {raw_admin}"}
    r = await client.post(f"/api/v1/admin/jobs/{failed.id}/retry", headers=h)
    assert r.status_code == 409


# ---- J10: POST /admin/users ----------------------------------------------


async def test_create_user_admin_only(client, make_token, cleanup):
    raw_user = await make_token(is_admin=False)
    h = {"Authorization": f"Bearer {raw_user}"}
    r = await client.post(
        "/api/v1/admin/users",
        json={"navidrome_username": "alice"},
        headers=h,
    )
    assert r.status_code == 403


async def test_create_user_persists_and_is_idempotent(client, make_token, app_sm, cleanup):
    import uuid as _uuid

    from sqlalchemy import text as _text

    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    name = f"alice-{_uuid.uuid4().hex[:8]}"

    r1 = await client.post(
        "/api/v1/admin/users",
        json={"navidrome_username": name},
        headers=h,
    )
    assert r1.status_code == 200
    body1 = r1.json()
    assert body1["navidrome_username"] == name
    assert body1["last_login_at"] is None

    # Repeat call returns the same row (idempotent), not a 409.
    r2 = await client.post(
        "/api/v1/admin/users",
        json={"navidrome_username": name},
        headers=h,
    )
    assert r2.status_code == 200
    body2 = r2.json()
    assert body2["id"] == body1["id"]

    # Only one users row exists.
    async with app_sm() as s:
        c = await s.execute(
            _text("SELECT count(*) FROM users WHERE navidrome_username = :u"),
            {"u": name},
        )
        assert c.scalar_one() == 1
        await s.execute(
            _text("DELETE FROM users WHERE navidrome_username = :u"),
            {"u": name},
        )
        await s.commit()


async def test_create_user_validates_input(client, make_token, cleanup):
    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    assert (await client.post("/api/v1/admin/users", json={}, headers=h)).status_code == 422
    assert (
        await client.post(
            "/api/v1/admin/users",
            json={"navidrome_username": ""},
            headers=h,
        )
    ).status_code == 422
    assert (
        await client.post(
            "/api/v1/admin/users",
            json={"navidrome_username": "x", "extra": 1},
            headers=h,
        )
    ).status_code == 422


# ---- N1: GET /admin/users + DELETE /admin/users/{id} ----------------------


async def test_list_users_returns_seeded_and_created_rows(client, make_token, cleanup):
    import uuid as _uuid

    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}

    name = f"listme-{_uuid.uuid4().hex[:8]}"
    await client.post("/api/v1/admin/users", json={"navidrome_username": name}, headers=h)

    r = await client.get("/api/v1/admin/users", headers=h)
    assert r.status_code == 200
    usernames = {u["navidrome_username"] for u in r.json()}
    # Backfill migration seeds system-admin and legacy-admin.
    assert "system-admin" in usernames
    assert name in usernames


async def test_delete_user_removes_orphan_user(client, make_token, app_sm, cleanup):
    import uuid as _uuid

    from sqlalchemy import text as _text

    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    name = f"todelete-{_uuid.uuid4().hex[:8]}"

    r1 = await client.post(
        "/api/v1/admin/users",
        json={"navidrome_username": name},
        headers=h,
    )
    user_id = r1.json()["id"]

    r2 = await client.delete(f"/api/v1/admin/users/{user_id}", headers=h)
    assert r2.status_code == 204

    async with app_sm() as s:
        n = (
            await s.execute(_text("SELECT count(*) FROM users WHERE id = :i"), {"i": user_id})
        ).scalar_one()
        assert n == 0


async def test_delete_unknown_user_returns_404(client, make_token, cleanup):
    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    r = await client.delete(f"/api/v1/admin/users/{uuid.uuid4()}", headers=h)
    assert r.status_code == 404


async def test_delete_user_with_tokens_returns_409(client, make_token, app_sm, cleanup):
    import uuid as _uuid

    from sqlalchemy import text as _text

    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    name = f"hastokens-{_uuid.uuid4().hex[:8]}"
    r1 = await client.post(
        "/api/v1/admin/users",
        json={"navidrome_username": name},
        headers=h,
    )
    user_id = r1.json()["id"]
    await client.post(
        "/api/v1/admin/tokens",
        headers=h,
        json={
            "owner_label": "admin-test-blocker",
            "scopes": ["read"],
            "navidrome_username": name,
        },
    )

    r = await client.delete(f"/api/v1/admin/users/{user_id}", headers=h)
    assert r.status_code == 409
    assert "token" in r.json()["detail"].lower()

    # Cleanup the FK chain so the cleanup fixture can drop the user row.
    async with app_sm() as s:
        await s.execute(_text("DELETE FROM tokens WHERE user_id = :i"), {"i": user_id})
        await s.execute(_text("DELETE FROM users WHERE id = :i"), {"i": user_id})
        await s.commit()


async def test_delete_user_with_jobs_returns_409(client, make_token, app_sm, cleanup):
    import uuid as _uuid

    from sqlalchemy import text as _text

    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    name = f"hasjobs-{_uuid.uuid4().hex[:8]}"
    r1 = await client.post(
        "/api/v1/admin/users",
        json={"navidrome_username": name},
        headers=h,
    )
    user_id = uuid.UUID(r1.json()["id"])

    # Seed a job under this user using the admin token's id.
    admin_token_id = await _token_id_for(app_sm, raw_admin)
    job = Job(
        source_url=f"https://www.youtube.com/watch?v=delme-{_uuid.uuid4().hex[:6]}",
        source_type="song",
        state="done",
        created_by_token_id=admin_token_id,
        user_id=user_id,
    )
    async with app_sm() as s:
        s.add(job)
        await s.commit()

    r = await client.delete(f"/api/v1/admin/users/{user_id}", headers=h)
    assert r.status_code == 409
    assert "job" in r.json()["detail"].lower()

    async with app_sm() as s:
        await s.execute(_text("DELETE FROM jobs WHERE user_id = :i"), {"i": user_id})
        await s.execute(_text("DELETE FROM users WHERE id = :i"), {"i": user_id})
        await s.commit()


async def test_delete_system_admin_user_is_blocked(client, make_token, app_sm, cleanup):
    from sqlalchemy import text as _text

    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    async with app_sm() as s:
        sys_id = (
            await s.execute(_text("SELECT id FROM users WHERE navidrome_username = 'system-admin'"))
        ).scalar_one()

    r = await client.delete(f"/api/v1/admin/users/{sys_id}", headers=h)
    assert r.status_code == 409
    assert "system-admin" in r.json()["detail"]


# ---- N2: GET /admin/jobs (list + filters) ---------------------------------


async def test_list_jobs_non_admin_returns_403(client, make_token, cleanup):
    raw = await make_token(is_admin=False)
    h = {"Authorization": f"Bearer {raw}"}
    r = await client.get("/api/v1/admin/jobs", headers=h)
    assert r.status_code == 403


async def test_list_jobs_returns_all_states_no_filter(client, make_token, app_sm, cleanup):
    raw_admin = await make_token(is_admin=True)
    token_id = await _token_id_for(app_sm, raw_admin)
    await _seed_job(
        app_sm, token_id=token_id, source_url="https://www.youtube.com/watch?v=q1", state="queued"
    )
    await _seed_job(
        app_sm, token_id=token_id, source_url="https://www.youtube.com/watch?v=d1", state="done"
    )
    await _seed_job(
        app_sm, token_id=token_id, source_url="https://www.youtube.com/watch?v=f1", state="failed"
    )

    h = {"Authorization": f"Bearer {raw_admin}"}
    r = await client.get("/api/v1/admin/jobs", headers=h)
    assert r.status_code == 200
    states = {j["state"] for j in r.json()}
    assert {"queued", "done", "failed"}.issubset(states)


async def test_list_jobs_filter_by_state(client, make_token, app_sm, cleanup):
    raw_admin = await make_token(is_admin=True)
    token_id = await _token_id_for(app_sm, raw_admin)
    await _seed_job(
        app_sm, token_id=token_id, source_url="https://www.youtube.com/watch?v=s-q", state="queued"
    )
    await _seed_job(
        app_sm, token_id=token_id, source_url="https://www.youtube.com/watch?v=s-d", state="done"
    )

    h = {"Authorization": f"Bearer {raw_admin}"}
    r = await client.get("/api/v1/admin/jobs?state=queued", headers=h)
    assert r.status_code == 200
    body = r.json()
    assert all(j["state"] == "queued" for j in body)
    urls = {j["source_url"] for j in body}
    assert "https://www.youtube.com/watch?v=s-q" in urls
    assert "https://www.youtube.com/watch?v=s-d" not in urls


async def test_list_jobs_invalid_state_returns_422(client, make_token, cleanup):
    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    r = await client.get("/api/v1/admin/jobs?state=bogus", headers=h)
    assert r.status_code == 422


async def test_list_jobs_filter_by_user(client, make_token, app_sm, cleanup):
    import uuid as _uuid

    from sqlalchemy import text as _text

    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    name = f"jobuser-{_uuid.uuid4().hex[:8]}"
    r1 = await client.post(
        "/api/v1/admin/users",
        json={"navidrome_username": name},
        headers=h,
    )
    other_uid = uuid.UUID(r1.json()["id"])

    admin_token_id = await _token_id_for(app_sm, raw_admin)
    # Job for the other user.
    j_other = Job(
        source_url="https://www.youtube.com/watch?v=other-job",
        source_type="song",
        state="done",
        created_by_token_id=admin_token_id,
        user_id=other_uid,
    )
    # Job for system-admin.
    await _seed_job(
        app_sm,
        token_id=admin_token_id,
        source_url="https://www.youtube.com/watch?v=sysadm-job",
        state="done",
    )
    async with app_sm() as s:
        s.add(j_other)
        await s.commit()

    r = await client.get(f"/api/v1/admin/jobs?user={name}", headers=h)
    assert r.status_code == 200
    urls = {j["source_url"] for j in r.json()}
    assert "https://www.youtube.com/watch?v=other-job" in urls
    assert "https://www.youtube.com/watch?v=sysadm-job" not in urls

    async with app_sm() as s:
        await s.execute(_text("DELETE FROM jobs WHERE user_id = :i"), {"i": other_uid})
        await s.execute(_text("DELETE FROM users WHERE id = :i"), {"i": other_uid})
        await s.commit()


async def test_list_jobs_unknown_user_returns_404(client, make_token, cleanup):
    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    r = await client.get("/api/v1/admin/jobs?user=nobody-here", headers=h)
    assert r.status_code == 404


async def test_list_jobs_limit_out_of_range_returns_422(client, make_token, cleanup):
    raw_admin = await make_token(is_admin=True)
    h = {"Authorization": f"Bearer {raw_admin}"}
    assert (await client.get("/api/v1/admin/jobs?limit=0", headers=h)).status_code == 422
    assert (await client.get("/api/v1/admin/jobs?limit=501", headers=h)).status_code == 422
