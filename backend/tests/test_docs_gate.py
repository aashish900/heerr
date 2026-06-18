"""DEBT N8: OpenAPI + Swagger UI must require an admin bearer token."""

import pytest
from httpx import ASGITransport, AsyncClient

from app.db import get_session
from app.main import create_app


@pytest.fixture
async def gated_app(app_sm):
    app = create_app()

    async def override_get_session():
        async with app_sm() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    app.dependency_overrides[get_session] = override_get_session
    return app


@pytest.fixture
async def client(gated_app):
    transport = ASGITransport(app=gated_app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


async def test_default_docs_routes_disabled(client):
    # FastAPI's default mounts are gone — only the gated /api/v1/* versions exist.
    for path in ("/docs", "/redoc", "/openapi.json"):
        r = await client.get(path)
        assert r.status_code == 404, f"{path} should not exist, got {r.status_code}"


async def test_openapi_json_requires_auth(client):
    r = await client.get("/api/v1/openapi.json")
    assert r.status_code == 401


async def test_openapi_json_rejects_non_admin(client, make_token):
    raw = await make_token(is_admin=False)
    r = await client.get(
        "/api/v1/openapi.json",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 403


async def test_openapi_json_admin_returns_spec(client, make_token):
    raw = await make_token(is_admin=True)
    r = await client.get(
        "/api/v1/openapi.json",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body.get("openapi", "").startswith("3.")
    assert body["info"]["title"] == "heerr backend"


async def test_swagger_ui_requires_auth(client):
    r = await client.get("/api/v1/docs")
    assert r.status_code == 401


async def test_swagger_ui_rejects_non_admin(client, make_token):
    raw = await make_token(is_admin=False)
    r = await client.get(
        "/api/v1/docs",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 403


async def test_swagger_ui_admin_returns_html(client, make_token):
    raw = await make_token(is_admin=True)
    r = await client.get(
        "/api/v1/docs",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200
    assert "text/html" in r.headers["content-type"]
    assert "SwaggerUIBundle" in r.text
