"""C5: POST /api/v1/auth/logout — token self-revoke."""

import hashlib
import uuid

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select, text

from app import config
from app.api.v1.router import api_v1
from app.db import get_session
from app.models import Token, User


@pytest.fixture(autouse=True)
def _env(monkeypatch, pg_async_url):
    monkeypatch.setenv("DATABASE_URL", pg_async_url)
    monkeypatch.setenv("MUSIC_OUTPUT_DIR", "/data")
    monkeypatch.setenv("NAVIDROME_URL", "http://nd.example.tailnet:4533")
    config.get_settings.cache_clear()
    yield
    config.get_settings.cache_clear()


@pytest.fixture
async def cleanup(app_sm):
    yield
    async with app_sm() as s:
        await s.execute(text("DELETE FROM jobs"))
        await s.execute(
            text(
                "DELETE FROM tokens WHERE user_id IN "
                "(SELECT id FROM users WHERE navidrome_username LIKE 'logout-test-%')"
            )
        )
        await s.execute(text("DELETE FROM users WHERE navidrome_username LIKE 'logout-test-%'"))
        await s.commit()


def _build_app(app_sm) -> FastAPI:
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
    return app


async def _seed_token(app_sm, *, username: str) -> str:
    raw = f"logout-raw-{uuid.uuid4().hex}"
    async with app_sm() as s:
        user = User(navidrome_username=username)
        s.add(user)
        await s.flush()
        s.add(
            Token(
                token_hash=hashlib.sha256(raw.encode()).hexdigest(),
                scopes=["read", "download"],
                is_admin=False,
                user_id=user.id,
            )
        )
        await s.commit()
    return raw


async def test_logout_revokes_current_token(app_sm, cleanup):
    username = f"logout-test-{uuid.uuid4().hex[:8]}"
    raw = await _seed_token(app_sm, username=username)
    app = _build_app(app_sm)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        r = await c.post(
            "/api/v1/auth/logout",
            headers={"Authorization": f"Bearer {raw}"},
        )
    assert r.status_code == 204
    assert r.content == b""

    async with app_sm() as s:
        h = hashlib.sha256(raw.encode()).hexdigest()
        tok = (await s.execute(select(Token).where(Token.token_hash == h))).scalar_one()
        assert tok.revoked_at is not None


async def test_logout_second_call_returns_401(app_sm, cleanup):
    username = f"logout-test-{uuid.uuid4().hex[:8]}"
    raw = await _seed_token(app_sm, username=username)
    app = _build_app(app_sm)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        first = await c.post(
            "/api/v1/auth/logout",
            headers={"Authorization": f"Bearer {raw}"},
        )
        assert first.status_code == 204
        second = await c.post(
            "/api/v1/auth/logout",
            headers={"Authorization": f"Bearer {raw}"},
        )
    assert second.status_code == 401


async def test_logout_without_token_returns_401(app_sm, cleanup):
    app = _build_app(app_sm)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        r = await c.post("/api/v1/auth/logout")
    assert r.status_code == 401


async def test_logout_does_not_affect_other_user_tokens(app_sm, cleanup):
    alice_user = f"logout-test-{uuid.uuid4().hex[:8]}"
    bob_user = f"logout-test-{uuid.uuid4().hex[:8]}"
    alice = await _seed_token(app_sm, username=alice_user)
    bob = await _seed_token(app_sm, username=bob_user)
    app = _build_app(app_sm)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        r = await c.post(
            "/api/v1/auth/logout",
            headers={"Authorization": f"Bearer {alice}"},
        )
        assert r.status_code == 204

    async with app_sm() as s:
        alice_h = hashlib.sha256(alice.encode()).hexdigest()
        bob_h = hashlib.sha256(bob.encode()).hexdigest()
        alice_tok = (await s.execute(select(Token).where(Token.token_hash == alice_h))).scalar_one()
        bob_tok = (await s.execute(select(Token).where(Token.token_hash == bob_h))).scalar_one()
        assert alice_tok.revoked_at is not None
        assert bob_tok.revoked_at is None
