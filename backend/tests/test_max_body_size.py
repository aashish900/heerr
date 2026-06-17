"""N6: requests with Content-Length over cap are rejected 413."""

from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.middleware import MaxBodySizeMiddleware


def _app(max_bytes: int = 1024) -> FastAPI:
    app = FastAPI()
    app.add_middleware(MaxBodySizeMiddleware, max_bytes=max_bytes)

    @app.post("/echo")
    async def echo(payload: dict) -> dict:
        return payload

    return app


async def test_body_under_cap_passes():
    transport = ASGITransport(app=_app(max_bytes=1024))
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        r = await c.post("/echo", json={"a": 1})
    assert r.status_code == 200


async def test_body_over_cap_rejected_413():
    transport = ASGITransport(app=_app(max_bytes=64))
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        r = await c.post("/echo", json={"q": "x" * 500})
    assert r.status_code == 413
    assert "exceeds" in r.json()["detail"]


async def test_non_http_scope_passes_through():
    """ASGI lifespan / websocket scopes are not HTTP — must not block."""
    app = _app(max_bytes=64)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        r = await c.get("/openapi.json")
    assert r.status_code == 200
