from fastapi import FastAPI

from app.api.middleware import RequestLoggingMiddleware
from app.api.v1.router import api_v1
from app.logging_config import setup_logging


def create_app() -> FastAPI:
    setup_logging()
    app = FastAPI(
        title="heerr backend",
        version="2.0.0-rc1",
        openapi_url="/api/v1/openapi.json",
        docs_url="/api/v1/docs",
        redoc_url=None,
    )
    app.add_middleware(RequestLoggingMiddleware)
    app.include_router(api_v1)
    return app


app = create_app()
