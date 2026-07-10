import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.middleware import MaxBodySizeMiddleware, RequestLoggingMiddleware
from app.api.v1.router import api_v1
from app.config import get_settings
from app.db import _sessionmaker
from app.logging_config import setup_logging
from app.services.jobs import recover_orphaned_jobs
from app.services.spotdl_runner import log_spotdl_version

_log = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    get_settings()  # fail fast on misconfigured env before serving any requests (N13)
    async with _sessionmaker()() as session:
        try:
            recovered = await recover_orphaned_jobs(session)
            await session.commit()
        except Exception:
            await session.rollback()
            raise
    if recovered:
        _log.warning("orphaned jobs recovered at boot", extra={"count": recovered})
    else:
        _log.info("no orphaned jobs at boot")
    yield


def create_app() -> FastAPI:
    setup_logging()
    log_spotdl_version()
    app = FastAPI(
        title="heerr backend",
        version="4.7.0",
        openapi_url=None,
        docs_url=None,
        redoc_url=None,
        lifespan=lifespan,
    )
    app.add_middleware(RequestLoggingMiddleware)
    app.add_middleware(MaxBodySizeMiddleware)
    app.include_router(api_v1)
    _mount_admin_docs(app)
    return app


def _mount_admin_docs(app: FastAPI) -> None:
    """Mount admin-gated OpenAPI + Swagger UI under /api/v1.

    The default FastAPI docs are disabled (N8); these replacements require a
    heerr admin bearer token. The Swagger UI page inlines the spec so the
    browser does not need to make a second unauthenticated fetch for
    /openapi.json.
    """
    import json

    from fastapi import Depends, Request
    from fastapi.responses import HTMLResponse, JSONResponse

    from app.api.deps import require_admin
    from app.models import Token

    @app.get("/api/v1/openapi.json", include_in_schema=False)
    async def openapi_json(
        request: Request,
        _admin: Token = Depends(require_admin),
    ) -> JSONResponse:
        return JSONResponse(request.app.openapi())

    @app.get("/api/v1/docs", include_in_schema=False)
    async def swagger_ui(
        request: Request,
        _admin: Token = Depends(require_admin),
    ) -> HTMLResponse:
        spec_json = json.dumps(request.app.openapi())
        html = (
            "<!DOCTYPE html><html><head><title>heerr API</title>"
            '<link rel="stylesheet" '
            'href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui.css">'
            '</head><body><div id="swagger-ui"></div>'
            '<script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/'
            'swagger-ui-bundle.js"></script>'
            "<script>window.onload=()=>{SwaggerUIBundle({"
            f"spec:{spec_json},"
            'dom_id:"#swagger-ui"});};</script>'
            "</body></html>"
        )
        return HTMLResponse(html)


app = create_app()
