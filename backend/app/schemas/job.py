from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel


class JobView(BaseModel):
    job_id: UUID
    spotify_uri: str
    spotify_type: Literal["track", "album", "playlist"]
    state: Literal["queued", "running", "done", "failed"]
    progress: None = None  # v1: always null per PLAN; reserved for future
    error: str | None
    output_path: str | None
    created_at: datetime
    started_at: datetime | None
    finished_at: datetime | None


class QueueResponse(BaseModel):
    active: list[JobView]
    recent: list[JobView]
