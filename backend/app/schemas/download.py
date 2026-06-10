from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, field_validator

_YOUTUBE_WATCH = "https://www.youtube.com/watch?v="
_YTM_BROWSE = "https://music.youtube.com/browse/"


class DownloadRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    source_url: str
    source_type: Literal["song", "album", "playlist"]
    display_name: str | None = None

    @field_validator("source_url")
    @classmethod
    def _validate(cls, v: str) -> str:
        if v.startswith(_YOUTUBE_WATCH) and len(v) > len(_YOUTUBE_WATCH):
            return v
        if v.startswith(_YTM_BROWSE) and len(v) > len(_YTM_BROWSE):
            return v
        raise ValueError("source_url must be a YouTube watch URL or YouTube Music browse URL")


class DownloadResponse(BaseModel):
    job_id: UUID
    state: str
    deduped: bool
