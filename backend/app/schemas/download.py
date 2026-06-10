from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, field_validator

_YT_WATCH = "https://www.youtube.com/watch?v="
_YTM_WATCH = "https://music.youtube.com/watch?v="
_YTM_BROWSE = "https://music.youtube.com/browse/"

_ALLOWED_PREFIXES = (_YT_WATCH, _YTM_WATCH, _YTM_BROWSE)


class DownloadRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    source_url: str
    source_type: Literal["song", "album", "playlist"]
    display_name: str | None = None

    @field_validator("source_url")
    @classmethod
    def _validate(cls, v: str) -> str:
        if any(v.startswith(p) and len(v) > len(p) for p in _ALLOWED_PREFIXES):
            return v
        raise ValueError("source_url must be a YouTube or YouTube Music URL")


class DownloadResponse(BaseModel):
    job_id: UUID
    state: str
    deduped: bool
