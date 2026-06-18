import pytest
import sqlalchemy as sa
from fastapi import Depends, FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.deps import bearer_token, current_user, require_admin, require_scope
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
        return {"owner": tok.user.navidrome_username, "scopes": tok.scopes}

    @app.get("/needs-download")
    async def needs_download(tok=Depends(require_scope("download"))):
        return {"ok": True}

    @app.get("/needs-read-and-download")
    async def needs_both(tok=Depends(require_scope("read", "download"))):
        return {"ok": True}

    @app.get("/admin-only")
    async def admin_only(tok=Depends(require_admin)):
        return {"ok": True}

    @app.get("/whoami-user")
    async def whoami_user(user=Depends(current_user)):
        return {"navidrome_username": user.navidrome_username}

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
    r = await client.get("/whoami", headers={"Authorization": "Bearer not-a-real-token"})
    assert r.status_code == 401


async def test_revoked_token_returns_401(client, make_token):
    raw = await make_token(revoked=True)
    r = await client.get("/whoami", headers={"Authorization": f"Bearer {raw}"})
    assert r.status_code == 401


# ---- valid token, happy path ---------------------------------------------


async def test_valid_token_returns_owner(client, make_token):
    raw = await make_token()
    r = await client.get("/whoami", headers={"Authorization": f"Bearer {raw}"})
    assert r.status_code == 200
    body = r.json()
    assert body["owner"] == "system-admin"
    assert set(body["scopes"]) == {"read", "download"}


# ---- scope checks -> 403 / 200 -------------------------------------------


async def test_missing_required_scope_returns_403(client, make_token):
    raw = await make_token(scopes=("read",))
    r = await client.get("/needs-download", headers={"Authorization": f"Bearer {raw}"})
    assert r.status_code == 403


async def test_required_scope_present_returns_200(client, make_token):
    raw = await make_token(scopes=("read", "download"))
    r = await client.get("/needs-download", headers={"Authorization": f"Bearer {raw}"})
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
    r = await client.get("/admin-only", headers={"Authorization": f"Bearer {raw}"})
    assert r.status_code == 403


async def test_admin_allowed_on_admin_route(client, make_token):
    raw = await make_token(is_admin=True)
    r = await client.get("/admin-only", headers={"Authorization": f"Bearer {raw}"})
    assert r.status_code == 200


async def test_admin_route_still_requires_auth(client):
    r = await client.get("/admin-only")
    assert r.status_code == 401


# ---- J7: token resolves to user ------------------------------------------


async def test_cli_minted_token_resolves_to_system_admin(client, make_token):
    """Tokens minted without explicit user_id (CLI / pre-J6) use the system_admin
    server-default and must therefore resolve to the system-admin user."""
    raw = await make_token()
    r = await client.get("/whoami-user", headers={"Authorization": f"Bearer {raw}"})
    assert r.status_code == 200
    assert r.json()["navidrome_username"] == "system-admin"


async def test_login_minted_token_resolves_to_logged_in_user(app_sm, client):
    """A token minted by POST /auth/login is FK-linked to that user and
    current_user must reflect it."""
    import hashlib
    import secrets
    import uuid

    from app.models import Token, User

    username = f"alice-{uuid.uuid4().hex[:8]}"
    raw = f"raw-{secrets.token_urlsafe(16)}"
    async with app_sm() as s:
        user = User(navidrome_username=username)
        s.add(user)
        await s.flush()
        s.add(
            Token(
                token_hash=hashlib.sha256(raw.encode()).hexdigest(),
                scopes=["read", "download"],
                user_id=user.id,
            )
        )
        await s.commit()

    r = await client.get("/whoami-user", headers={"Authorization": f"Bearer {raw}"})
    assert r.status_code == 200
    assert r.json()["navidrome_username"] == username


# ---- N3: last_used_at bumped on every authenticated request ---------------


async def test_bearer_token_bumps_last_used_at(client, make_token, app_sm):
    """Every authenticated request stamps tokens.last_used_at = now()."""
    import hashlib
    from datetime import UTC, datetime

    from sqlalchemy import select

    from app.models import Token

    raw = await make_token()
    token_hash = hashlib.sha256(raw.encode()).hexdigest()

    # Pre-condition: brand-new token has NULL last_used_at.
    async with app_sm() as s:
        tok = (await s.execute(select(Token).where(Token.token_hash == token_hash))).scalar_one()
        assert tok.last_used_at is None

    before = datetime.now(UTC)
    r = await client.get("/whoami", headers={"Authorization": f"Bearer {raw}"})
    assert r.status_code == 200

    async with app_sm() as s:
        tok = (await s.execute(select(Token).where(Token.token_hash == token_hash))).scalar_one()
        assert tok.last_used_at is not None
        assert tok.last_used_at >= before


# ---- N9: dangling user → 401 (not 500) -----------------------------------


async def test_dangling_user_returns_401(client, app_sm):
    """Token row whose user_id FK points at a deleted user (race) → 401."""
    import hashlib
    import secrets

    from sqlalchemy import text

    from app.models import Token

    # Mint a token wired to system-admin first, then null out user_id to
    # simulate the corruption the N9 guard is for.
    raw = f"raw-{secrets.token_urlsafe(16)}"
    token_hash = hashlib.sha256(raw.encode()).hexdigest()
    async with app_sm() as s:
        s.add(
            Token(
                token_hash=token_hash,
                user_id=sa.func.system_admin_user_id(),
                scopes=["read", "download"],
            )
        )
        await s.commit()
        # Forcibly null the FK to reproduce data-corruption / mid-request race.
        await s.execute(text("ALTER TABLE tokens ALTER COLUMN user_id DROP NOT NULL"))
        await s.execute(
            text("UPDATE tokens SET user_id = NULL WHERE token_hash = :h"),
            {"h": token_hash},
        )
        await s.commit()

    try:
        r = await client.get("/whoami", headers={"Authorization": f"Bearer {raw}"})
        assert r.status_code == 401
        assert r.json()["detail"] == "session invalidated"
    finally:
        async with app_sm() as s:
            await s.execute(text("DELETE FROM tokens WHERE token_hash = :h"), {"h": token_hash})
            await s.execute(text("ALTER TABLE tokens ALTER COLUMN user_id SET NOT NULL"))
            await s.commit()
