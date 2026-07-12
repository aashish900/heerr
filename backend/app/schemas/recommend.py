from pydantic import BaseModel, ConfigDict, Field


class RecommendSeed(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str = Field(..., min_length=1)
    artist: str = Field(..., min_length=1)
    source_url: str | None = None


class RecommendRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    seeds: list[RecommendSeed] = Field(default_factory=list)
    limit: int = Field(default=20, ge=1, le=50)


class RecommendResultItem(BaseModel):
    title: str
    artist: str
    source_url: str
    score: float | None = None
    # Server-resolved public cover-art URL for the result (derived from the
    # watch URL's video id). Null when the source URL carries no video id
    # (e.g. album browse URLs) — clients fall back to a placeholder.
    cover_url: str | None = None


class RecommendResponse(BaseModel):
    results: list[RecommendResultItem]


class RecommendHealthResponse(BaseModel):
    engine: str
    status: str  # "ok" | "degraded"
    fallback_active: bool
