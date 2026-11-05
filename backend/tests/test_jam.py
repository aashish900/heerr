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


# ----- JM3: commands / sync / state ----------------------------------------

_SONG = {"id": "nd-1", "title": "Song", "artist": "A"}


async def _joined(client, host, guest):
    body = await _start(client, host)
    await client.post("/api/v1/jam/join", json={"code": body["code"]}, headers=guest[0])
    return body["id"]


async def _send(client, sid, headers, kind, payload=None):
    return await client.post(
        f"/api/v1/jam/{sid}/commands",
        json={"kind": kind, "payload": payload or {}},
        headers=headers,
    )


async def _sync(client, sid, headers, after, state=None):
    return await client.post(
        f"/api/v1/jam/{sid}/sync", json={"state": state, "after": after}, headers=headers
    )


async def test_command_relayed_to_host(client, host, guest):
    sid = await _joined(client, host, guest)
    boot = (await _sync(client, sid, host, None)).json()
    assert boot["commands"] == [] and boot["ended"] is False

    r = await _send(client, sid, guest[0], "play_songs", {"songs": [_SONG], "start_index": 0})
    assert r.status_code == 201, r.text
    await _send(client, sid, guest[0], "seek", {"position_ms": 5000})

    body = (await _sync(client, sid, host, boot["cursor"])).json()
    assert [c["kind"] for c in body["commands"]] == ["play_songs", "seek"]
    assert body["commands"][0]["payload"]["songs"][0] == _SONG
    assert body["commands"][0]["sender"] == guest[1]
    assert body["cursor"] == body["commands"][-1]["id"]

    again = (await _sync(client, sid, host, body["cursor"])).json()
    assert again["commands"] == [] and again["cursor"] == body["cursor"]


async def test_bootstrap_skips_stale_commands(client, host, guest):
    sid = await _joined(client, host, guest)
    await _send(client, sid, guest[0], "pause")
    boot = (await _sync(client, sid, host, None)).json()
    assert boot["commands"] == [] and boot["cursor"] > 0


async def test_sync_non_host_forbidden(client, host, guest):
    sid = await _joined(client, host, guest)
    r = await _sync(client, sid, guest[0], None)
    assert r.status_code == 403


async def test_state_round_trip(client, host, guest):
    sid = await _joined(client, host, guest)
    state = {"playing": True, "position_ms": 1200, "current": _SONG, "queue": [_SONG]}
    await _sync(client, sid, host, None, state=state)
    r = await client.get(f"/api/v1/jam/{sid}/state", headers=guest[0])
    assert r.status_code == 200
    body = r.json()
    assert body["state"] == state and body["ended"] is False and body["state_at"]
    assert body["host_username"]


async def test_ended_session(client, host, guest):
    sid = await _joined(client, host, guest)
    await client.delete(f"/api/v1/jam/{sid}", headers=host)
    assert (await _send(client, sid, guest[0], "play")).status_code == 404
    assert (await _sync(client, sid, host, 0)).json()["ended"] is True
    assert (await client.get(f"/api/v1/jam/{sid}/state", headers=guest[0])).json()["ended"]


@pytest.mark.parametrize(
    "kind,payload",
    [
        ("rewind", {}),
        ("play_songs", {}),
        ("play_songs", {"songs": []}),
        ("play_songs", {"songs": [{"title": "no id"}]}),
        ("play_songs", {"songs": [_SONG], "start_index": 3}),
        ("enqueue", {"songs": "x"}),
        ("seek", {}),
        ("seek", {"position_ms": -1}),
    ],
)
async def test_bad_command_rejected(client, host, guest, kind, payload):
    sid = await _joined(client, host, guest)
    r = await _send(client, sid, guest[0], kind, payload)
    assert r.status_code == 422


async def test_unknown_session_404(client, guest):
    sid = uuid.uuid4()
    assert (await _send(client, sid, guest[0], "play")).status_code == 404
    assert (await client.get(f"/api/v1/jam/{sid}/state", headers=guest[0])).status_code == 404
