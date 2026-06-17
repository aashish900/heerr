import json
import logging

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.context import owner_label_var, request_id_var
from app.api.middleware import RequestLoggingMiddleware
from app.api.v1.router import api_v1
from app.db import get_session
from app.logging_config import JsonFormatter, _ContextFilter
from app.services.workers import get_enqueuer

# ---- JsonFormatter unit tests --------------------------------------------


def _make_record(msg: str = "hello", extras: dict | None = None) -> logging.LogRecord:
    rec = logging.LogRecord(
        name="t",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg=msg,
        args=(),
        exc_info=None,
    )
    for k, v in (extras or {}).items():
        setattr(rec, k, v)
    return rec


def test_json_formatter_emits_required_keys():
    fmt = JsonFormatter()
    payload = json.loads(fmt.format(_make_record()))

    for required in ("ts", "level", "logger", "msg", "request_id", "owner_label"):
        assert required in payload, f"missing key: {required}"
    assert payload["level"] == "INFO"
    assert payload["msg"] == "hello"


def test_json_formatter_carries_extras():
    fmt = JsonFormatter()
    rec = _make_record(extras={"path": "/foo", "status_code": 200})
    payload = json.loads(fmt.format(rec))

    assert payload["path"] == "/foo"
    assert payload["status_code"] == 200


def test_json_formatter_strips_forbidden_keys():
    """A caller-supplied extra=token=... must never reach the log line."""
    fmt = JsonFormatter()
    rec = _make_record(extras={"token": "raw-secret", "token_hash": "abc123"})
    payload = json.loads(fmt.format(rec))

    assert "token" not in payload
    assert "token_hash" not in payload
    assert "raw-secret" not in fmt.format(rec)
    assert "abc123" not in fmt.format(rec)


def test_context_filter_injects_contextvars():
    fmt = JsonFormatter()
    flt = _ContextFilter()

    token_rid = request_id_var.set("rid-xyz")
    token_owner = owner_label_var.set("alice")
    try:
        rec = _make_record()
        assert flt.filter(rec) is True
        payload = json.loads(fmt.format(rec))
    finally:
        request_id_var.reset(token_rid)
        owner_label_var.reset(token_owner)

    assert payload["request_id"] == "rid-xyz"
    assert payload["owner_label"] == "alice"


# ---- Middleware integration tests ----------------------------------------


class _ListHandler(logging.Handler):
    def __init__(self) -> None:
        super().__init__(level=logging.DEBUG)
        self.records: list[logging.LogRecord] = []

    def emit(self, record: logging.LogRecord) -> None:
        self.records.append(record)


@pytest.fixture
def access_log():
    """Attach a local handler to the root logger; tear down after the test.

    pytest's `caplog` fixture didn't reliably capture records emitted inside
    the Starlette `BaseHTTPMiddleware` task; using our own handler avoids the
    issue and we still test the JsonFormatter logic explicitly elsewhere.
    """
    handler = _ListHandler()
    root = logging.getLogger()
    prev_level = root.level
    root.addHandler(handler)
    root.setLevel(logging.DEBUG)
    try:
        yield handler
    finally:
        root.removeHandler(handler)
        root.setLevel(prev_level)


@pytest.fixture
def fake_enqueuer():
    calls: list = []

    def _noop(bg, job_id):
        calls.append(job_id)

    _noop.calls = calls
    return _noop


@pytest.fixture
async def middleware_app(app_sm, fake_enqueuer):
    """App with middleware installed but no global logging mutation."""
    app = FastAPI()
    app.add_middleware(RequestLoggingMiddleware)

    async def override_get_session():
        async with app_sm() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    app.dependency_overrides[get_session] = override_get_session
    app.dependency_overrides[get_enqueuer] = lambda: fake_enqueuer
    app.include_router(api_v1)
    return app


@pytest.fixture
async def client(middleware_app):
    transport = ASGITransport(app=middleware_app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


async def test_request_id_assigned_when_missing(client):
    r = await client.get("/api/v1/health")
    assert r.status_code == 200
    assert "x-request-id" in r.headers
    assert len(r.headers["x-request-id"]) >= 16  # uuid4 hex = 32 chars


async def test_request_id_echoed_when_present(client):
    r = await client.get("/api/v1/health", headers={"X-Request-ID": "rid-test-123"})
    assert r.headers["x-request-id"] == "rid-test-123"


async def test_access_log_emitted_per_request(client, access_log):
    await client.get("/api/v1/health")

    access = [r for r in access_log.records if r.name == "heerr.access"]
    assert len(access) == 1
    rec = access[0]
    assert rec.method == "GET"
    assert rec.path == "/api/v1/health"
    assert rec.status_code == 200
    assert isinstance(rec.duration_ms, float)


async def test_access_log_owner_label_dash_for_unauth(client, access_log):
    """Unauthenticated /health → owner_label sentinel '-' (never None)."""
    await client.get("/api/v1/health")

    rec = next(r for r in access_log.records if r.name == "heerr.access")
    flt = _ContextFilter()
    flt.filter(rec)
    assert rec.owner_label == "-"


async def test_access_log_owner_label_set_after_auth(client, access_log, make_token):
    """Authenticated GET /queue → owner_label == token owner.

    /queue is used (not /search) because /search hits a Spotify config that
    isn't loaded in this test setup; /queue only needs the auth dependency.
    """
    raw = await make_token(owner="alice-test")
    r = await client.get(
        "/api/v1/queue",
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200

    rec = next(r for r in access_log.records if r.name == "heerr.access")
    flt = _ContextFilter()
    flt.filter(rec)
    assert rec.owner_label == "alice-test"


async def test_admin_create_token_does_not_leak_raw_token_in_logs(client, access_log, make_token):
    """The raw token returned by POST /admin/tokens must never appear in logs."""
    admin_raw = await make_token(owner="admin", is_admin=True)

    r = await client.post(
        "/api/v1/admin/tokens",
        headers={"Authorization": f"Bearer {admin_raw}"},
        json={"owner_label": "newuser", "scopes": ["read"], "navidrome_username": "system-admin"},
    )
    assert r.status_code in (200, 201)
    raw_returned = r.json()["raw_token"]
    assert raw_returned  # sanity

    fmt = JsonFormatter()
    for rec in access_log.records:
        line = fmt.format(rec)
        assert raw_returned not in line, f"raw token leaked in log line: {line[:200]}"
