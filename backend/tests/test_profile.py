"""GET /api/v1/profile + PUT /api/v1/profile."""

from __future__ import annotations

import base64

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import create_app


@pytest.fixture
async def client(app_sm, make_token):
    token = await make_token()
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        ac.headers["Authorization"] = f"Bearer {token}"
        yield ac


async def test_get_profile_initially_all_null(client):
    r = await client.get("/api/v1/profile")
    assert r.status_code == 200
    body = r.json()
    assert body == {
        "display_name": None,
        "nickname": None,
        "bio": None,
        "avatar_b64": None,
    }


async def test_put_profile_round_trips_text_fields(client):
    payload = {
        "display_name": "Alice",
        "nickname": "ali",
        "bio": "Music lover",
        "avatar_b64": None,
    }
    r = await client.put("/api/v1/profile", json=payload)
    assert r.status_code == 200
    assert r.json() == payload


async def test_get_after_put_returns_saved_values(client):
    payload = {
        "display_name": "Bob",
        "nickname": "bobby",
        "bio": "Rock fan",
        "avatar_b64": None,
    }
    await client.put("/api/v1/profile", json=payload)
    r = await client.get("/api/v1/profile")
    assert r.status_code == 200
    assert r.json() == payload


async def test_put_avatar_round_trips(client):
    raw = b"\x89PNG\r\nhello"
    b64 = base64.b64encode(raw).decode()
    payload = {
        "display_name": None,
        "nickname": None,
        "bio": None,
        "avatar_b64": b64,
    }
    r = await client.put("/api/v1/profile", json=payload)
    assert r.status_code == 200
    assert r.json()["avatar_b64"] == b64


async def test_put_avatar_null_clears_existing(client):
    raw = b"some bytes"
    b64 = base64.b64encode(raw).decode()
    await client.put(
        "/api/v1/profile",
        json={"display_name": None, "nickname": None, "bio": None, "avatar_b64": b64},
    )
    r = await client.put(
        "/api/v1/profile",
        json={"display_name": None, "nickname": None, "bio": None, "avatar_b64": None},
    )
    assert r.status_code == 200
    assert r.json()["avatar_b64"] is None


async def test_profile_requires_auth(app_sm):
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        assert (await ac.get("/api/v1/profile")).status_code == 401
        assert (
            await ac.put(
                "/api/v1/profile",
                json={
                    "display_name": None,
                    "nickname": None,
                    "bio": None,
                    "avatar_b64": None,
                },
            )
        ).status_code == 401
