from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class PodcastSearchRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    query: str = Field(..., min_length=1)
    limit: int = Field(default=20, ge=1, le=50)


class PodcastChannelItem(BaseModel):
    """A Podcast Index search result — not yet ingested, so no local id."""

    feed_url: str
    title: str
    author: str | None
    image_url: str | None
    description: str | None


class PodcastSearchResponse(BaseModel):
    results: list[PodcastChannelItem]


class SubscribeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    feed_url: str = Field(..., min_length=1)


class ChannelItem(BaseModel):
    """An ingested channel row — has a local id, unlike `PodcastChannelItem`."""

    id: UUID
    feed_url: str
    title: str
    author: str | None
    image_url: str | None
    description: str | None


class SubscriptionsResponse(BaseModel):
    channels: list[ChannelItem]


class EpisodeItem(BaseModel):
    id: UUID
    channel_id: UUID
    guid: str
    title: str
    description: str | None
    published_at: datetime | None
    duration_s: int | None
    enclosure_url: str
    enclosure_type: str | None
    image_url: str | None
    episode_no: int | None
    season_no: int | None
    downloaded: bool
    position_s: int
    played: bool


class EpisodeListResponse(BaseModel):
    episodes: list[EpisodeItem]
    total: int


class EpisodeDownloadResponse(BaseModel):
    job_id: UUID
    state: str
    deduped: bool
