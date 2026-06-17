import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.middleware import MaxBodySizeMiddleware, RequestLoggingMiddleware
from app.api.v1.router import api_v1
from app.db import get_session
from app.logging_config import setup_logging
from app.services.jobs import recover_orphaned_jobs
from app.services.spotdl_runner import log_spotdl_version

_log = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    async for session in get_session():
        recovered = await recover_orphaned_jobs(session)
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
        version="3.0.0",
        openapi_url="/api/v1/openapi.json",
        docs_url="/api/v1/docs",
        redoc_url=None,
        lifespan=lifespan,
    )
    app.add_middleware(RequestLoggingMiddleware)
    app.add_middleware(MaxBodySizeMiddleware)
    app.include_router(api_v1)
    return app


app = create_app()
