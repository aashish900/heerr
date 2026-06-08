import hashlib
import uuid
from datetime import datetime, timezone

import pytest
from fastapi import Depends, FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.api.deps import bearer_token, require_admin, require_scope
from app.db import get_session
from app.models import Token


@pytest.fixture
async def app_engine(pg_async_url):
    engine = create_async_engine(pg_async_url, pool_pre_ping=True)
    yield engine
    await engine.dispose()


@pytest.fixture
async def app_sm(app_engine):
    return async_sessionmaker(app_engine, expire_on_commit=False)


@pytest.fixture
async def auth_app(app_sm):
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

    @app.get("/whoami")
    async def whoami(tok=Depends(bearer_token)):
        return {"owner": tok.owner_label, "scopes": tok.scopes}

    @app.get("/needs-download")
    async def needs_download(tok=Depends(require_scope("download"))):
        return {"ok": True}

    @app.get("/needs-read-and-download")
    async def needs_both(tok=Depends(require_scope("read", "download"))):
        return {"ok": True}

    @app.get("/admin-only")
    async def admin_only(tok=Depends(require_admin)):
        return {"ok": True}

    yield app


@pytest.fixture
async def client(auth_app):
    transport = ASGITransport(app=auth_app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.fixture
async def make_token(app_sm):
    inserted_hashes: list[str] = []

    async def _make(
        owner: str = "test",
        scopes: tuple[str, ...] = ("read", "download"),
        is_admin: bool = False,
        revoked: bool = False,
    ) -> str:
        raw = f"raw-{uuid.uuid4().hex}"
        h = hashlib.sha256(raw.encode()).hexdigest()
        async with app_sm() as s:
            s.add(
                Token(
                    token_hash=h,
                    owner_label=owner,
                    scopes=list(scopes),
                    is_admin=is_admin,
                    revoked_at=datetime.now(timezone.utc) if revoked else None,
                )
            )
            await s.commit()
        inserted_hashes.append(h)
        return raw

    yield _make

    async with app_sm() as s:
        for h in inserted_hashes:
            await s.execute(
                text("DELETE FROM tokens WHERE token_hash = :h"), {"h": h}
            )
        await s.commit()


# ---- missing / malformed / unknown / revoked -> 401 -----------------------


async def test_no_auth_header_returns_401(client):
    r = await client.get("/whoami")
    assert r.status_code == 401


async def test_wrong_scheme_returns_401(client):
    r = await client.get("/whoami", headers={"Authorization": "Basic abc"})
    assert r.status_code == 401


async def test_unknown_token_returns_401(client):
    r = await client.get(
        "/whoami", headers={"Authorization": "Bearer not-a-real-token"}
    )
    assert r.status_code == 401


async def test_revoked_token_returns_401(client, make_token):
    raw = await make_token(revoked=True)
    r = await client.get(
        "/whoami", headers={"Authorization": f"Bearer {raw}"}
    )
    assert r.status_code == 401


# ---- valid token, happy path ---------------------------------------------


async def test_valid_token_returns_owner(client, make_token):
    raw = await make_token(owner="aashish")
    r = await client.get(
        "/whoami", headers={"Authorization": f"Bearer {raw}"}
    )
    assert r.status_code == 200
    body = r.json()
    assert body["owner"] == "aashish"
    assert set(body["scopes"]) == {"read", "download"}


# ---- scope checks -> 403 / 200 -------------------------------------------


async def test_missing_required_scope_returns_403(client, make_token):
    raw = await make_token(scopes=("read",))
    r = await client.get(
        "/needs-download", headers={"Authorization": f"Bearer {raw}"}
    )
    assert r.status_code == 403


async def test_required_scope_present_returns_200(client, make_token):
    raw = await make_token(scopes=("read", "download"))
    r = await client.get(
        "/needs-download", headers={"Authorization": f"Bearer {raw}"}
    )
    assert r.status_code == 200


async def test_multiple_required_scopes_partial_fails(client, make_token):
    raw = await make_token(scopes=("download",))
    r = await client.get(
        "/needs-read-and-download",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 403


async def test_multiple_required_scopes_all_pass(client, make_token):
    raw = await make_token(scopes=("read", "download"))
    r = await client.get(
        "/needs-read-and-download",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200


# ---- admin checks -> 403 / 200 -------------------------------------------


async def test_non_admin_blocked_from_admin_route(client, make_token):
    raw = await make_token(is_admin=False)
    r = await client.get(
        "/admin-only", headers={"Authorization": f"Bearer {raw}"}
    )
    assert r.status_code == 403


async def test_admin_allowed_on_admin_route(client, make_token):
    raw = await make_token(is_admin=True)
    r = await client.get(
        "/admin-only", headers={"Authorization": f"Bearer {raw}"}
    )
    assert r.status_code == 200


async def test_admin_route_still_requires_auth(client):
    r = await client.get("/admin-only")
    assert r.status_code == 401
