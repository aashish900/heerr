from fastapi import APIRouter

from app.api.v1 import download, health, queue, search, status

api_v1 = APIRouter(prefix="/api/v1")
api_v1.include_router(health.router)
api_v1.include_router(search.router)
api_v1.include_router(download.router)
api_v1.include_router(status.router)
api_v1.include_router(queue.router)
