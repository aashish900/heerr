"""J6: POST /api/v1/auth/login — Navidrome-IdP login flow."""

import hashlib
import uuid

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select, text

from app import config
from app.api.v1.auth import get_navidrome_verifier
from app.api.v1.router import api_v1
from app.db import get_session
from app.models import Token, User
from app.services.navidrome_auth import NavidromeUnreachable

_NAVIDROME_URL = "http://navidrome.example.tailnet:4533"


class RecordingVerifier:
    """Stand-in for the real Subsonic ping handshake."""

    def __init__(
        self,
        *,
        accept: dict[tuple[str, str], bool] | None = None,
        raises: Exception | None = None,
    ) -> None:
        self.accept = accept or {}
        self.raises = raises
        self.calls: list[tuple[str, str]] = []

    async def __call__(self, username: str, password: str) -> bool:
        self.calls.append((username, password))
        if self.raises is not None:
            raise self.raises
        return self.accept.get((username, password), False)


@pytest.fixture(autouse=True)
def _env(monkeypatch, pg_async_url):
    monkeypatch.setenv("DATABASE_URL", pg_async_url)
    monkeypatch.setenv("MUSIC_OUTPUT_DIR", "/data")
    monkeypatch.setenv("NAVIDROME_URL", _NAVIDROME_URL)
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
                "DELETE FROM tokens WHERE user_id IN"
                " (SELECT id FROM users WHERE navidrome_username NOT IN"
                " ('legacy-admin', 'system-admin'))"
            )
        )
        await s.execute(
            text(
                "DELETE FROM users WHERE navidrome_username NOT IN"
                " ('legacy-admin', 'system-admin')"
            )
        )
        await s.commit()


def _build_app(app_sm, verifier: RecordingVerifier) -> FastAPI:
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
    app.dependency_overrides[get_navidrome_verifier] = lambda: verifier
    app.include_router(api_v1)
    return app


async def _client(app: FastAPI) -> AsyncClient:
    transport = ASGITransport(app=app)
    return AsyncClient(transport=transport, base_url="http://test")


async def test_login_new_user_happy_path(app_sm, cleanup):
    username = f"alice-{uuid.uuid4().hex[:8]}"
    verifier = RecordingVerifier(accept={(username, "pw"): True})
    app = _build_app(app_sm, verifier)
    async with await _client(app) as c:
        r = await c.post("/api/v1/auth/login", json={"username": username, "password": "pw"})
    assert r.status_code == 200
    body = r.json()
    assert set(body) == {"token", "scopes", "navidrome_url", "navidrome_username", "profile"}
    assert body["navidrome_url"] == _NAVIDROME_URL
    assert body["navidrome_username"] == username
    assert body["scopes"] == ["read", "download"]
    assert verifier.calls == [(username, "pw")]

    # User row exists; token row linked to it.
    async with app_sm() as s:
        user = (
            await s.execute(select(User).where(User.navidrome_username == username))
        ).scalar_one()
        assert user.last_login_at is not None
        h = hashlib.sha256(body["token"].encode()).hexdigest()
        tok = (await s.execute(select(Token).where(Token.token_hash == h))).scalar_one()
        assert tok.user_id == user.id
        assert sorted(tok.scopes) == ["download", "read"]
        assert tok.is_admin is False


async def test_login_existing_user_bumps_last_login_and_mints_new_token(app_sm, cleanup):
    username = f"bob-{uuid.uuid4().hex[:8]}"
    # Pre-seed the user.
    async with app_sm() as s:
        s.add(User(navidrome_username=username))
        await s.commit()
        first_login = (
            (await s.execute(select(User).where(User.navidrome_username == username)))
            .scalar_one()
            .last_login_at
        )

    verifier = RecordingVerifier(accept={(username, "pw"): True})
    app = _build_app(app_sm, verifier)
    async with await _client(app) as c:
        r = await c.post("/api/v1/auth/login", json={"username": username, "password": "pw"})
    assert r.status_code == 200

    async with app_sm() as s:
        user = (
            await s.execute(select(User).where(User.navidrome_username == username))
        ).scalar_one()
        # last_login_at moved forward.
        assert user.last_login_at is not None
        if first_login is not None:
            assert user.last_login_at >= first_login
        # Only one user row exists for this name (no duplicate insert).
        count = await s.execute(
            text("SELECT count(*) FROM users WHERE navidrome_username = :u"),
            {"u": username},
        )
        assert count.scalar_one() == 1
        # New token belongs to this user.
        token_rows = (
            (await s.execute(select(Token).where(Token.user_id == user.id))).scalars().all()
        )
        assert len(token_rows) == 1


async def test_login_bad_credentials_returns_401(app_sm, cleanup):
    verifier = RecordingVerifier(accept={})  # nothing accepted
    app = _build_app(app_sm, verifier)
    async with await _client(app) as c:
        r = await c.post(
            "/api/v1/auth/login",
            json={"username": "alice", "password": "wrong"},
        )
    assert r.status_code == 401
    assert "invalid credentials" in r.json()["detail"].lower()

    # No user row was created on failure.
    async with app_sm() as s:
        n = await s.execute(
            text("SELECT count(*) FROM users WHERE navidrome_username = :u"),
            {"u": "alice"},
        )
        assert n.scalar_one() == 0


async def test_login_navidrome_unreachable_returns_503(app_sm, cleanup):
    verifier = RecordingVerifier(raises=NavidromeUnreachable("no route"))
    app = _build_app(app_sm, verifier)
    async with await _client(app) as c:
        r = await c.post(
            "/api/v1/auth/login",
            json={"username": "alice", "password": "pw"},
        )
    assert r.status_code == 503
    assert "unreachable" in r.json()["detail"].lower()


async def test_login_validates_request_body(app_sm, cleanup):
    verifier = RecordingVerifier()
    app = _build_app(app_sm, verifier)
    async with await _client(app) as c:
        # Missing fields.
        assert (await c.post("/api/v1/auth/login", json={})).status_code == 422
        # Empty strings.
        assert (
            await c.post("/api/v1/auth/login", json={"username": "", "password": "pw"})
        ).status_code == 422
        # Extra fields rejected.
        assert (
            await c.post(
                "/api/v1/auth/login",
                json={"username": "u", "password": "p", "extra": True},
            )
        ).status_code == 422
    # Verifier never reached for any of those.
    assert verifier.calls == []
