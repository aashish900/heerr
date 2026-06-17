from fastapi import FastAPI

from app.api.middleware import RequestLoggingMiddleware
from app.api.v1.router import api_v1
from app.logging_config import setup_logging
from app.services.spotdl_runner import log_spotdl_version


def create_app() -> FastAPI:
    setup_logging()
    log_spotdl_version()
    app = FastAPI(
        title="heerr backend",
        version="3.0.0",
        openapi_url="/api/v1/openapi.json",
        docs_url="/api/v1/docs",
        redoc_url=None,
    )
    app.add_middleware(RequestLoggingMiddleware)
    app.include_router(api_v1)
    return app


app = create_app()
