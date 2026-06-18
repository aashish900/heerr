import logging
import time
import uuid
from collections.abc import Awaitable, Callable

from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.api.context import request_id_var, username_var

logger = logging.getLogger("heerr.access")

_REQUEST_ID_HEADER = "x-request-id"


class RequestLoggingMiddleware:
    """Pure ASGI middleware: assigns X-Request-ID, emits one structured access
    log per request, and surfaces `username` (set by the auth dependency).

    Note: implemented as a pure ASGI middleware (not Starlette's
    BaseHTTPMiddleware) so that ContextVar mutations made by downstream
    dependencies are visible here. BaseHTTPMiddleware runs the inner app in a
    child task; ContextVar writes in child tasks do not propagate back.
    """

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        headers = dict(scope.get("headers") or [])
        incoming = headers.get(_REQUEST_ID_HEADER.encode())
        request_id = incoming.decode() if incoming else uuid.uuid4().hex
        request_id_var.set(request_id)
        username_var.set("-")

        start = time.perf_counter()
        status_code = 500

        async def send_wrapper(message: Message) -> None:
            nonlocal status_code
            if message["type"] == "http.response.start":
                status_code = message["status"]
                # Inject X-Request-ID into response headers.
                response_headers = list(message.get("headers") or [])
                response_headers.append((_REQUEST_ID_HEADER.encode(), request_id.encode()))
                message["headers"] = response_headers
            await send(message)

        try:
            await self.app(scope, receive, send_wrapper)
        finally:
            duration_ms = round((time.perf_counter() - start) * 1000, 2)
            method = scope.get("method", "-")
            path = scope.get("path", "-")
            client = scope.get("client")
            client_host = client[0] if client else "-"
            logger.info(
                "request",
                extra={
                    "method": method,
                    "path": path,
                    "status_code": status_code,
                    "duration_ms": duration_ms,
                    "client": client_host,
                },
            )


# Kept for type-checking compatibility with `add_middleware`. Unused but
# imported by tests / callers that wanted the explicit dispatch signature.
DispatchFunc = Callable[[Scope, Receive, Send], Awaitable[None]]


# 1 MiB — well above the largest legitimate /search or /download body
# (small JSON), well below memory-pressure territory for the worker.
_DEFAULT_MAX_BODY_BYTES = 1 * 1024 * 1024


class MaxBodySizeMiddleware:
    """Reject HTTP requests whose Content-Length exceeds `max_bytes`.

    Pure ASGI middleware. Sits in front of FastAPI's body parsing so a 10 MB
    POST body never makes it into worker memory. Only inspects the declared
    Content-Length; chunked / unspecified bodies pass through and are bounded
    by the application's own parsers.
    """

    def __init__(self, app: ASGIApp, max_bytes: int = _DEFAULT_MAX_BODY_BYTES) -> None:
        self.app = app
        self.max_bytes = max_bytes

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        for name, value in scope.get("headers") or []:
            if name == b"content-length":
                try:
                    declared = int(value)
                except ValueError:
                    break
                if declared > self.max_bytes:
                    await _send_413(send, self.max_bytes)
                    return
                break

        await self.app(scope, receive, send)


async def _send_413(send: Send, max_bytes: int) -> None:
    body = f'{{"detail":"request body exceeds {max_bytes} bytes"}}'.encode()
    await send(
        {
            "type": "http.response.start",
            "status": 413,
            "headers": [
                (b"content-type", b"application/json"),
                (b"content-length", str(len(body)).encode()),
            ],
        }
    )
    await send({"type": "http.response.body", "body": body})
