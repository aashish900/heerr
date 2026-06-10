from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel


class JobView(BaseModel):
    job_id: UUID
    source_url: str
    source_type: Literal["song", "album", "playlist"]
    state: Literal["queued", "running", "done", "failed"]
    display_name: str | None
    progress: None = None  # v1: always null per PLAN; reserved for future
    error: str | None
    output_path: str | None
    created_at: datetime
    started_at: datetime | None
    finished_at: datetime | None


class QueueResponse(BaseModel):
    active: list[JobView]
    recent: list[JobView]
