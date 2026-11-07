from pydantic import BaseModel, ConfigDict, Field


class RecommendSeed(BaseModel):
    model_config = ConfigDict(extra="forbid")

    # None ⇒ artist seed ("more like this artist"); RX5.
    title: str | None = Field(default=None, min_length=1)
    artist: str = Field(..., min_length=1)
    source_url: str | None = None
    weight: float = Field(default=1.0, ge=0.0, le=1.0)


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


class DismissRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    source_url: str = Field(..., min_length=1)


class MixVibeItem(BaseModel):
    id: str
    title: str


class MixRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    seeds: list[RecommendSeed] = Field(default_factory=list)
    limit: int = Field(default=50, ge=1, le=50)
    # Regenerate: rotates which of the best-matching mood playlists are used.
    variant: int = Field(default=0, ge=0)


class MixResponse(BaseModel):
    id: str
    title: str
    # False when none of the mood's playlists overlap the user's artists and the
    # mix is YouTube Music's own top picks for the mood.
    personalized: bool
    results: list[RecommendResultItem]
