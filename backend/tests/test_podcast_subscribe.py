import hashlib
import secrets
import uuid

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select, text

import app.api.v1.podcasts as podcasts_module
from app.api.v1.router import api_v1
from app.db import get_session
from app.models import PodcastChannel, Token, User
from app.services.feeds import FeedFetchError

_FEED_URL = "https://example.com/feed.xml"


@pytest.fixture
async def subscribe_app(app_sm):
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
async def client(subscribe_app):
    transport = ASGITransport(app=subscribe_app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.fixture
async def cleanup(app_sm):
    yield
    async with app_sm() as s:
        await s.execute(text("DELETE FROM podcast_progress"))
        await s.execute(text("DELETE FROM podcast_subscription"))
        await s.execute(text("DELETE FROM podcast_episode"))
        await s.execute(text("DELETE FROM podcast_channel"))
        await s.commit()


async def _fake_ingest_ok(session, feed_url, *, _title="Test Show"):
    """Mirrors ingest_feed's upsert-by-feed_url behavior without real HTTP."""
    existing = await session.scalar(
        select(PodcastChannel).where(PodcastChannel.feed_url == feed_url)
    )
    if existing is not None:
        return existing
    channel = PodcastChannel(feed_url=feed_url, title=_title)
    session.add(channel)
    await session.flush()
    return channel


@pytest.fixture(autouse=True)
def patch_ingest(monkeypatch):
    async def _default(session, feed_url):
        return await _fake_ingest_ok(session, feed_url)

    monkeypatch.setattr(podcasts_module, "ingest_feed", _default)
    return _default


@pytest.fixture
async def second_user_token(app_sm):
    async with app_sm() as s:
        user = User(navidrome_username=f"bob-{uuid.uuid4().hex[:8]}")
        s.add(user)
        await s.flush()
        raw = f"raw-{secrets.token_urlsafe(16)}"
        s.add(
            Token(
                token_hash=hashlib.sha256(raw.encode()).hexdigest(),
                scopes=["read", "download"],
                user_id=user.id,
            )
        )
        await s.commit()
    return raw


# ---- POST /podcasts/subscribe ----------------------------------------------


async def test_subscribe_requires_auth(client):
    r = await client.post("/api/v1/podcasts/subscribe", json={"feed_url": _FEED_URL})
    assert r.status_code == 401


async def test_subscribe_requires_read_scope(client, make_token):
    raw = await make_token(scopes=())
    r = await client.post(
        "/api/v1/podcasts/subscribe",
        json={"feed_url": _FEED_URL},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 403


async def test_subscribe_creates_channel(client, make_token, cleanup):
    raw = await make_token()
    r = await client.post(
        "/api/v1/podcasts/subscribe",
        json={"feed_url": _FEED_URL},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["feed_url"] == _FEED_URL
    assert body["title"] == "Test Show"
    assert "id" in body


async def test_subscribe_is_idempotent(client, make_token, cleanup):
    raw = await make_token()
    headers = {"Authorization": f"Bearer {raw}"}
    r1 = await client.post(
        "/api/v1/podcasts/subscribe", json={"feed_url": _FEED_URL}, headers=headers
    )
    r2 = await client.post(
        "/api/v1/podcasts/subscribe", json={"feed_url": _FEED_URL}, headers=headers
    )
    assert r1.status_code == 200
    assert r2.status_code == 200
    assert r1.json()["id"] == r2.json()["id"]


async def test_subscribe_feed_error_returns_502(client, make_token, monkeypatch, cleanup):
    async def _raise(session, feed_url):
        raise FeedFetchError("boom")

    monkeypatch.setattr(podcasts_module, "ingest_feed", _raise)
    raw = await make_token()
    r = await client.post(
        "/api/v1/podcasts/subscribe",
        json={"feed_url": _FEED_URL},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 502


async def test_subscribe_empty_feed_url_returns_422(client, make_token):
    raw = await make_token()
    r = await client.post(
        "/api/v1/podcasts/subscribe",
        json={"feed_url": ""},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 422


# ---- DELETE /podcasts/subscribe/{channel_id} -------------------------------


async def test_unsubscribe_requires_auth(client):
    r = await client.delete(f"/api/v1/podcasts/subscribe/{uuid.uuid4()}")
    assert r.status_code == 401


async def test_unsubscribe_unknown_returns_404(client, make_token):
    raw = await make_token()
    r = await client.delete(
        f"/api/v1/podcasts/subscribe/{uuid.uuid4()}",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 404


async def test_unsubscribe_removes_subscription(client, make_token, cleanup):
    raw = await make_token()
    headers = {"Authorization": f"Bearer {raw}"}
    sub = await client.post(
        "/api/v1/podcasts/subscribe", json={"feed_url": _FEED_URL}, headers=headers
    )
    channel_id = sub.json()["id"]

    r = await client.delete(f"/api/v1/podcasts/subscribe/{channel_id}", headers=headers)
    assert r.status_code == 204

    listed = await client.get("/api/v1/podcasts/subscriptions", headers=headers)
    assert listed.json()["channels"] == []


# ---- GET /podcasts/subscriptions -------------------------------------------


async def test_list_subscriptions_requires_auth(client):
    r = await client.get("/api/v1/podcasts/subscriptions")
    assert r.status_code == 401


async def test_list_subscriptions_scoped_to_current_user(
    client, make_token, second_user_token, cleanup
):
    raw_a = await make_token()
    r = await client.post(
        "/api/v1/podcasts/subscribe",
        json={"feed_url": _FEED_URL},
        headers={"Authorization": f"Bearer {raw_a}"},
    )
    assert r.status_code == 200

    listed_a = await client.get(
        "/api/v1/podcasts/subscriptions", headers={"Authorization": f"Bearer {raw_a}"}
    )
    assert len(listed_a.json()["channels"]) == 1

    listed_b = await client.get(
        "/api/v1/podcasts/subscriptions",
        headers={"Authorization": f"Bearer {second_user_token}"},
    )
    assert listed_b.json()["channels"] == []


async def test_two_users_can_subscribe_to_same_channel(
    client, make_token, second_user_token, cleanup, app_sm
):
    raw_a = await make_token()
    headers_a = {"Authorization": f"Bearer {raw_a}"}
    headers_b = {"Authorization": f"Bearer {second_user_token}"}

    await client.post("/api/v1/podcasts/subscribe", json={"feed_url": _FEED_URL}, headers=headers_a)
    await client.post("/api/v1/podcasts/subscribe", json={"feed_url": _FEED_URL}, headers=headers_b)

    listed_a = await client.get("/api/v1/podcasts/subscriptions", headers=headers_a)
    listed_b = await client.get("/api/v1/podcasts/subscriptions", headers=headers_b)
    assert len(listed_a.json()["channels"]) == 1
    assert len(listed_b.json()["channels"]) == 1
    assert listed_a.json()["channels"][0]["id"] == listed_b.json()["channels"][0]["id"]

    # exactly one channel row shared between both users' subscriptions
    async with app_sm() as s:
        r = await s.execute(
            text("SELECT COUNT(*) FROM podcast_channel WHERE feed_url = :u"), {"u": _FEED_URL}
        )
        assert r.scalar_one() == 1
