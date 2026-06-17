from httpx import ASGITransport, AsyncClient

from app.main import create_app


async def test_health_returns_200_status_ok():
    transport = ASGITransport(app=create_app())
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        r = await c.get("/api/v1/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


async def test_health_ignores_auth_header():
    """Per PLAN: every endpoint except GET /health requires Bearer auth."""
    transport = ASGITransport(app=create_app())
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        r = await c.get(
            "/api/v1/health",
            headers={"Authorization": "Bearer nonsense"},
        )
    assert r.status_code == 200


async def test_openapi_served_at_versioned_path():
    transport = ASGITransport(app=create_app())
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        ok = await c.get("/api/v1/openapi.json")
        legacy = await c.get("/openapi.json")
    assert ok.status_code == 200
    assert ok.json()["info"]["title"]
    assert legacy.status_code == 404


async def test_module_level_app_exists():
    """`uvicorn app.main:app` needs a module-level `app` ASGI callable."""
    from app.main import app

    assert app is not None
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        r = await c.get("/api/v1/health")
    assert r.status_code == 200


async def test_ready_returns_200_when_db_reachable(app_sm):
    from app.db import get_session

    app = create_app()

    async def override_get_session():
        async with app_sm() as session:
            yield session

    app.dependency_overrides[get_session] = override_get_session
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        r = await c.get("/api/v1/ready")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


async def test_ready_returns_503_when_db_unreachable():
    from app.db import get_session

    app = create_app()

    async def broken_session():
        class _Bad:
            async def execute(self, *a, **k):
                raise RuntimeError("connection refused")

        yield _Bad()

    app.dependency_overrides[get_session] = broken_session
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        r = await c.get("/api/v1/ready")
    assert r.status_code == 503
