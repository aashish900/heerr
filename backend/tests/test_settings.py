"""GET/PATCH /settings — per-user recommendation config (DEBT M5)."""

import uuid

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

from app.api.v1.router import api_v1
from app.db import get_session
from app.models import User


@pytest.fixture
async def settings_app(app_sm):
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
async def client(settings_app):
    transport = ASGITransport(app=settings_app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.fixture
async def make_user(app_sm):
    """Async factory: creates a user, returns its UUID. Cleans up on teardown."""
    created: list[uuid.UUID] = []

    async def _make(username: str | None = None) -> uuid.UUID:
        username = username or f"user-{uuid.uuid4().hex[:8]}"
        async with app_sm() as s:
            u = User(navidrome_username=username)
            s.add(u)
            await s.commit()
            created.append(u.id)
            return u.id

    yield _make

    async with app_sm() as s:
        for uid in created:
            await s.execute(text("DELETE FROM tokens WHERE user_id = :u"), {"u": uid})
            await s.execute(text("DELETE FROM users WHERE id = :u"), {"u": uid})
        await s.commit()


def _auth(raw: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {raw}"}


async def test_get_settings_missing_auth_returns_401(client):
    resp = await client.get("/api/v1/settings")
    assert resp.status_code == 401


async def test_get_settings_defaults(client, make_user, make_token):
    uid = await make_user()
    raw = await make_token(user_id=uid)
    resp = await client.get("/api/v1/settings", headers=_auth(raw))
    assert resp.status_code == 200
    assert resp.json() == {"lastfm_username": None, "listenbrainz_token_set": False}


async def test_patch_sets_lastfm_username(client, make_user, make_token):
    uid = await make_user()
    raw = await make_token(user_id=uid)
    resp = await client.patch(
        "/api/v1/settings", json={"lastfm_username": "alice"}, headers=_auth(raw)
    )
    assert resp.status_code == 200
    assert resp.json() == {"lastfm_username": "alice", "listenbrainz_token_set": False}
    # persisted
    resp = await client.get("/api/v1/settings", headers=_auth(raw))
    assert resp.json()["lastfm_username"] == "alice"


async def test_patch_token_is_not_echoed(client, make_user, make_token):
    uid = await make_user()
    raw = await make_token(user_id=uid)
    resp = await client.patch(
        "/api/v1/settings", json={"listenbrainz_token": "secret-tok"}, headers=_auth(raw)
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body == {"lastfm_username": None, "listenbrainz_token_set": True}
    assert "listenbrainz_token" not in body


async def test_patch_partial_does_not_clobber_other_key(client, make_user, make_token):
    uid = await make_user()
    raw = await make_token(user_id=uid)
    await client.patch("/api/v1/settings", json={"lastfm_username": "alice"}, headers=_auth(raw))
    await client.patch(
        "/api/v1/settings", json={"listenbrainz_token": "secret-tok"}, headers=_auth(raw)
    )
    resp = await client.get("/api/v1/settings", headers=_auth(raw))
    assert resp.json() == {"lastfm_username": "alice", "listenbrainz_token_set": True}


async def test_patch_null_clears_value(client, make_user, make_token):
    uid = await make_user()
    raw = await make_token(user_id=uid)
    await client.patch("/api/v1/settings", json={"lastfm_username": "alice"}, headers=_auth(raw))
    resp = await client.patch(
        "/api/v1/settings", json={"lastfm_username": None}, headers=_auth(raw)
    )
    assert resp.json()["lastfm_username"] is None


async def test_patch_extra_field_returns_422(client, make_user, make_token):
    uid = await make_user()
    raw = await make_token(user_id=uid)
    resp = await client.patch("/api/v1/settings", json={"nope": "x"}, headers=_auth(raw))
    assert resp.status_code == 422


async def test_settings_are_per_user(client, make_user, make_token):
    uid_a = await make_user()
    uid_b = await make_user()
    raw_a = await make_token(user_id=uid_a)
    raw_b = await make_token(user_id=uid_b)
    await client.patch("/api/v1/settings", json={"lastfm_username": "alice"}, headers=_auth(raw_a))
    resp_b = await client.get("/api/v1/settings", headers=_auth(raw_b))
    assert resp_b.json()["lastfm_username"] is None
