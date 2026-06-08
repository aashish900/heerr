from fastapi import FastAPI

from app.api.v1.router import api_v1


def create_app() -> FastAPI:
    app = FastAPI(
        title="heerr backend",
        version="0.1.0",
        openapi_url="/api/v1/openapi.json",
        docs_url="/api/v1/docs",
        redoc_url=None,
    )
    app.include_router(api_v1)
    return app


app = create_app()
