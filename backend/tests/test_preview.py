"""K2: GET /preview/stream proxy + query-or-header bearer auth.

The resolver and the upstream httpx client are both overridden, so these tests
never touch yt-dlp or the network. The DB (testcontainers) is real — auth resolves
a real token row minted via the `make_token` fixture.
"""

import httpx
import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.v1.preview import (
    get_preview_http_client,
    get_preview_resolver,
    preview_enabled_flag,
)
from app.api.v1.router import api_v1
from app.db import get_session
from app.services.preview_resolver import (
    PreviewResolveError,
    PreviewUnavailable,
    PreviewUnsupported,
    ResolvedPreview,
)

_WATCH = "https://music.youtube.com/watch?v=abc123"
_FAKE_STREAM = "https://fake.googlevideo.test/audio"
_REDIRECT_STREAM = "https://fake.googlevideo.test/redirect"
_BODY = bytes(range(256)) * 16  # 4096 deterministic bytes


def _ok_resolved(stream_url: str = _FAKE_STREAM) -> ResolvedPreview:
    return ResolvedPreview(
        video_id="abc123",
        stream_url=stream_url,
        headers={"User-Agent": "ytdlp/1"},
        content_type="audio/webm",
        expires_at=1e12,
    )


def _resolver_returning(resolved: ResolvedPreview):
    async def _r(source_url: str) -> ResolvedPreview:
        return resolved

    return _r


def _resolver_raising(exc: Exception):
    async def _r(source_url: str) -> ResolvedPreview:
        raise exc

    return _r


def _make_handler(seen: list[httpx.Request], *, audio_status: int = 200):
    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        url = str(request.url)
        if url == _REDIRECT_STREAM:
            return httpx.Response(302, headers={"location": _FAKE_STREAM})
        if url == _FAKE_STREAM:
            if audio_status >= 400:
                return httpx.Response(audio_status, text="gone")
            rng = request.headers.get("range")
            if rng:
                return httpx.Response(
                    206,
                    content=_BODY[:1024],
                    headers={
                        "content-type": "audio/webm",
                        "content-range": f"bytes 0-1023/{len(_BODY)}",
                        "accept-ranges": "bytes",
                    },
                )
            return httpx.Response(
                200,
                content=_BODY,
                headers={"content-type": "audio/webm", "accept-ranges": "bytes"},
            )
        return httpx.Response(404, text="unexpected url")

    return handler


def _build_app(app_sm, resolver, handler) -> FastAPI:
    app = FastAPI()

    async def override_get_session():
        async with app_sm() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    async def override_client():
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(handler), follow_redirects=True
        ) as c:
            yield c

    app.dependency_overrides[get_session] = override_get_session
    app.dependency_overrides[get_preview_resolver] = lambda: resolver
    app.dependency_overrides[get_preview_http_client] = override_client
    app.include_router(api_v1)
    return app


async def _client(app: FastAPI) -> AsyncClient:
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


# ----- auth ----------------------------------------------------------------


async def test_auth_via_header_streams_body(app_sm, make_token):
    raw = await make_token(scopes=("read",))
    seen: list[httpx.Request] = []
    app = _build_app(app_sm, _resolver_returning(_ok_resolved()), _make_handler(seen))
    async with await _client(app) as c:
        r = await c.get(
            "/api/v1/preview/stream",
            params={"source_url": _WATCH},
            headers={"Authorization": f"Bearer {raw}"},
        )
    assert r.status_code == 200
    assert r.content == _BODY
    assert r.headers["content-type"].startswith("audio/webm")
    # resolver-provided headers reach the upstream request.
    assert seen[-1].headers.get("user-agent") == "ytdlp/1"
    assert "range" not in {k.lower() for k in seen[-1].headers}


async def test_auth_via_query_token_streams_body(app_sm, make_token):
    raw = await make_token(scopes=("read",))
    seen: list[httpx.Request] = []
    app = _build_app(app_sm, _resolver_returning(_ok_resolved()), _make_handler(seen))
    async with await _client(app) as c:
        r = await c.get(
            "/api/v1/preview/stream",
            params={"source_url": _WATCH, "token": raw},
        )
    assert r.status_code == 200
    assert r.content == _BODY


async def test_missing_token_is_401(app_sm):
    seen: list[httpx.Request] = []
    app = _build_app(app_sm, _resolver_returning(_ok_resolved()), _make_handler(seen))
    async with await _client(app) as c:
        r = await c.get("/api/v1/preview/stream", params={"source_url": _WATCH})
    assert r.status_code == 401


async def test_wrong_scope_is_403(app_sm, make_token):
    raw = await make_token(scopes=("download",))  # no "read"
    seen: list[httpx.Request] = []
    app = _build_app(app_sm, _resolver_returning(_ok_resolved()), _make_handler(seen))
    async with await _client(app) as c:
        r = await c.get(
            "/api/v1/preview/stream",
            params={"source_url": _WATCH, "token": raw},
        )
    assert r.status_code == 403


# ----- proxy behaviour -----------------------------------------------------


async def test_range_is_forwarded_and_206_passes_through(app_sm, make_token):
    raw = await make_token(scopes=("read",))
    seen: list[httpx.Request] = []
    app = _build_app(app_sm, _resolver_returning(_ok_resolved()), _make_handler(seen))
    async with await _client(app) as c:
        r = await c.get(
            "/api/v1/preview/stream",
            params={"source_url": _WATCH, "token": raw},
            headers={"Range": "bytes=0-1023"},
        )
    assert r.status_code == 206
    assert r.content == _BODY[:1024]
    assert r.headers["content-range"] == f"bytes 0-1023/{len(_BODY)}"
    assert r.headers["accept-ranges"] == "bytes"
    assert seen[-1].headers.get("range") == "bytes=0-1023"


async def test_follows_upstream_redirect(app_sm, make_token):
    raw = await make_token(scopes=("read",))
    seen: list[httpx.Request] = []
    app = _build_app(
        app_sm, _resolver_returning(_ok_resolved(_REDIRECT_STREAM)), _make_handler(seen)
    )
    async with await _client(app) as c:
        r = await c.get(
            "/api/v1/preview/stream",
            params={"source_url": _WATCH, "token": raw},
        )
    assert r.status_code == 200
    assert r.content == _BODY
    assert [str(req.url) for req in seen] == [_REDIRECT_STREAM, _FAKE_STREAM]


async def test_upstream_error_status_maps_to_502(app_sm, make_token):
    raw = await make_token(scopes=("read",))
    seen: list[httpx.Request] = []
    app = _build_app(
        app_sm, _resolver_returning(_ok_resolved()), _make_handler(seen, audio_status=403)
    )
    async with await _client(app) as c:
        r = await c.get(
            "/api/v1/preview/stream",
            params={"source_url": _WATCH, "token": raw},
        )
    assert r.status_code == 502


# ----- kill switch ---------------------------------------------------------


async def test_disabled_returns_404_without_resolving(app_sm, make_token):
    raw = await make_token(scopes=("read",))
    seen: list[httpx.Request] = []
    resolver = _resolver_returning(_ok_resolved())
    app = _build_app(app_sm, resolver, _make_handler(seen))
    app.dependency_overrides[preview_enabled_flag] = lambda: False
    async with await _client(app) as c:
        r = await c.get(
            "/api/v1/preview/stream",
            params={"source_url": _WATCH, "token": raw},
        )
    assert r.status_code == 404
    assert seen == []  # never reached the resolver/proxy


# ----- resolver error mapping ----------------------------------------------


@pytest.mark.parametrize(
    ("exc", "expected"),
    [
        (PreviewUnsupported("album url"), 422),
        (PreviewUnavailable("region locked"), 404),
        (PreviewResolveError("boom"), 502),
    ],
)
async def test_resolver_errors_map_to_status(app_sm, make_token, exc, expected):
    raw = await make_token(scopes=("read",))
    seen: list[httpx.Request] = []
    app = _build_app(app_sm, _resolver_raising(exc), _make_handler(seen))
    async with await _client(app) as c:
        r = await c.get(
            "/api/v1/preview/stream",
            params={"source_url": _WATCH, "token": raw},
        )
    assert r.status_code == expected
    assert seen == []  # never reached the upstream proxy
