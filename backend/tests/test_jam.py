import uuid

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

from app.api.v1.router import api_v1
from app.db import get_session
from app.models import User


@pytest.fixture
async def client(app_sm):
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
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    async with app_sm() as s:
        await s.execute(text("DELETE FROM jam_session"))
        await s.commit()


@pytest.fixture
async def guest(app_sm, make_token):
    """(auth headers, username) for a second, non-host user."""
    name = f"guest-{uuid.uuid4().hex[:8]}"
    async with app_sm() as s:
        u = User(navidrome_username=name)
        s.add(u)
        await s.commit()
        uid = u.id
    raw = await make_token(user_id=uid)
    yield {"Authorization": f"Bearer {raw}"}, name


@pytest.fixture
async def host(make_token):
    return {"Authorization": f"Bearer {await make_token()}"}


async def _start(client, host):
    r = await client.post("/api/v1/jam", headers=host)
    assert r.status_code == 201, r.text
    return r.json()


async def test_create_returns_code(client, host):
    body = await _start(client, host)
    assert len(body["code"]) == 6
    assert body["code"].isalnum() and body["code"].isupper()
    assert body["id"] and body["expires_at"]


async def test_second_create_ends_first(client, host, guest):
    first = await _start(client, host)
    await _start(client, host)
    r = await client.post("/api/v1/jam/join", json={"code": first["code"]}, headers=guest[0])
    assert r.status_code == 404


async def test_join_with_code(client, host, guest):
    body = await _start(client, host)
    r = await client.post("/api/v1/jam/join", json={"code": body["code"].lower()}, headers=guest[0])
    assert r.status_code == 200, r.text
    assert r.json()["id"] == body["id"]
    assert r.json()["host_username"]


async def test_join_wrong_code(client, host, guest):
    await _start(client, host)
    r = await client.post("/api/v1/jam/join", json={"code": "ZZZZZZ"}, headers=guest[0])
    assert r.status_code == 404


async def test_join_expired(client, host, guest, app_sm):
    body = await _start(client, host)
    async with app_sm() as s:
        await s.execute(text("UPDATE jam_session SET expires_at = now() - interval '1 second'"))
        await s.commit()
    r = await client.post("/api/v1/jam/join", json={"code": body["code"]}, headers=guest[0])
    assert r.status_code == 404


async def test_join_own_session_conflicts(client, host):
    body = await _start(client, host)
    r = await client.post("/api/v1/jam/join", json={"code": body["code"]}, headers=host)
    assert r.status_code == 409


async def test_end_session(client, host, guest):
    body = await _start(client, host)
    r = await client.delete(f"/api/v1/jam/{body['id']}", headers=guest[0])
    assert r.status_code == 403
    r = await client.delete(f"/api/v1/jam/{body['id']}", headers=host)
    assert r.status_code == 204
    r = await client.post("/api/v1/jam/join", json={"code": body["code"]}, headers=guest[0])
    assert r.status_code == 404


async def test_end_unknown(client, host):
    r = await client.delete(f"/api/v1/jam/{uuid.uuid4()}", headers=host)
    assert r.status_code == 404


async def test_requires_auth(client):
    r = await client.post("/api/v1/jam")
    assert r.status_code == 401
