import logging
import time
import uuid
from collections.abc import Awaitable, Callable

from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.api.context import owner_label_var, request_id_var

logger = logging.getLogger("heerr.access")

_REQUEST_ID_HEADER = "x-request-id"


class RequestLoggingMiddleware:
    """Pure ASGI middleware: assigns X-Request-ID, emits one structured access
    log per request, and surfaces `owner_label` (set by the auth dependency).

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
        owner_label_var.set("-")

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
