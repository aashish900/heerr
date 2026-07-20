from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel


class JobView(BaseModel):
    job_id: UUID
    source_url: str
    source_type: Literal["song", "album", "playlist", "episode"]
    state: Literal["queued", "running", "done", "failed"]
    display_name: str | None
    progress: None = None  # v1: always null per PLAN; reserved for future
    error: str | None
    output_path: str | None
    created_at: datetime
    started_at: datetime | None
    finished_at: datetime | None
    # `source_type == "episode"` jobs carry the originating episode id so a
    # client can re-dispatch a failed download via
    # `POST /podcasts/episodes/{episode_id}/download` — the song-download
    # retry path (`POST /download` with `source_url`/`source_type`) doesn't
    # apply to episodes, whose enclosure URL isn't a YouTube Music URL.
    # Always null for song/album/playlist jobs.
    episode_id: UUID | None = None


class QueueResponse(BaseModel):
    active: list[JobView]
    recent: list[JobView]
