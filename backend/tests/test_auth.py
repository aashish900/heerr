import pytest
from fastapi import Depends, FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.deps import bearer_token, require_admin, require_scope
from app.db import get_session


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
