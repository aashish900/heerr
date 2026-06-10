from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class SearchRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    query: str = Field(..., min_length=1)
    type: Literal["song", "album", "playlist"]
    limit: int = Field(default=20, ge=1, le=50)


class SearchResultItem(BaseModel):
    source_url: str
    source_type: str
    title: str
    artist: str
    album: str | None
    duration_ms: int | None
    cover_url: str | None
    already_downloaded: bool
    active_job_id: UUID | None


class SearchResponse(BaseModel):
    results: list[SearchResultItem]
