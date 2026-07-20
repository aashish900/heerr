from pydantic import BaseModel, ConfigDict, Field


class PodcastSearchRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    query: str = Field(..., min_length=1)
    limit: int = Field(default=20, ge=1, le=50)


class PodcastChannelItem(BaseModel):
    feed_url: str
    title: str
    author: str | None
    image_url: str | None
    description: str | None


class PodcastSearchResponse(BaseModel):
    results: list[PodcastChannelItem]
