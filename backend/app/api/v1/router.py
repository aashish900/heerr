from fastapi import APIRouter

from app.api.v1 import admin, auth, download, health, queue, recommend, search, status

api_v1 = APIRouter(prefix="/api/v1")
api_v1.include_router(health.router)
api_v1.include_router(auth.router)
api_v1.include_router(search.router)
api_v1.include_router(download.router)
api_v1.include_router(status.router)
api_v1.include_router(queue.router)
api_v1.include_router(recommend.router)
api_v1.include_router(admin.router)
