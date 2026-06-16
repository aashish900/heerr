"""J5: Navidrome Subsonic credential verify."""

import hashlib

import httpx
import pytest

from app.services.navidrome_auth import NavidromeUnreachable, verify_credentials

_BASE = "http://navidrome.test:4533"
_FIXED_SALT = "deadbeef12345678"


def _expected_token(password: str, salt: str = _FIXED_SALT) -> str:
    return hashlib.md5(f"{password}{salt}".encode()).hexdigest()


def _stub_client(handler: httpx.MockTransport) -> httpx.AsyncClient:
    return httpx.AsyncClient(transport=handler, timeout=5.0)


async def test_verify_returns_true_on_ok_status():
    seen: dict[str, object] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen["url"] = str(request.url)
        seen["params"] = dict(request.url.params)
        return httpx.Response(
            200,
            json={"subsonic-response": {"status": "ok", "version": "1.16.1"}},
        )

    async with _stub_client(httpx.MockTransport(handler)) as client:
        ok = await verify_credentials(
            base_url=_BASE,
            username="alice",
            password="pw",
            http=client,
            salt_source=lambda: _FIXED_SALT,
        )

    assert ok is True
    assert seen["url"].startswith(f"{_BASE}/rest/ping.view")
    params = seen["params"]
    assert params == {
        "u": "alice",
        "t": _expected_token("pw"),
        "s": _FIXED_SALT,
        "v": "1.16.1",
        "c": "heerr",
        "f": "json",
    }


async def test_verify_returns_false_on_failed_status():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={
                "subsonic-response": {
                    "status": "failed",
                    "error": {"code": 40, "message": "Wrong username or password."},
                }
            },
        )

    async with _stub_client(httpx.MockTransport(handler)) as client:
        ok = await verify_credentials(
            base_url=_BASE,
            username="alice",
            password="bad",
            http=client,
            salt_source=lambda: _FIXED_SALT,
        )
    assert ok is False


async def test_verify_returns_false_on_non_200():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500, text="upstream blew up")

    async with _stub_client(httpx.MockTransport(handler)) as client:
        ok = await verify_credentials(
            base_url=_BASE,
            username="alice",
            password="pw",
            http=client,
            salt_source=lambda: _FIXED_SALT,
        )
    assert ok is False


async def test_verify_returns_false_on_non_json_body():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, text="not json")

    async with _stub_client(httpx.MockTransport(handler)) as client:
        ok = await verify_credentials(
            base_url=_BASE,
            username="alice",
            password="pw",
            http=client,
            salt_source=lambda: _FIXED_SALT,
        )
    assert ok is False


async def test_verify_raises_unreachable_on_connect_error():
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("no route to host")

    async with _stub_client(httpx.MockTransport(handler)) as client:
        with pytest.raises(NavidromeUnreachable):
            await verify_credentials(
                base_url=_BASE,
                username="alice",
                password="pw",
                http=client,
                salt_source=lambda: _FIXED_SALT,
            )


async def test_verify_raises_unreachable_on_read_timeout():
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("slow")

    async with _stub_client(httpx.MockTransport(handler)) as client:
        with pytest.raises(NavidromeUnreachable):
            await verify_credentials(
                base_url=_BASE,
                username="alice",
                password="pw",
                http=client,
                salt_source=lambda: _FIXED_SALT,
            )


async def test_verify_strips_trailing_slash_on_base_url():
    seen: dict[str, str] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen["url"] = str(request.url)
        return httpx.Response(200, json={"subsonic-response": {"status": "ok"}})

    async with _stub_client(httpx.MockTransport(handler)) as client:
        await verify_credentials(
            base_url=f"{_BASE}/",
            username="alice",
            password="pw",
            http=client,
            salt_source=lambda: _FIXED_SALT,
        )
    # No "//rest/" doubling in the path.
    assert "//rest/" not in seen["url"]
    assert seen["url"].startswith(f"{_BASE}/rest/ping.view")
