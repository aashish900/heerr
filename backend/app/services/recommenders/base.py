from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True)
class SeedTrack:
    title: str
    artist: str
    source_url: str | None = None


@dataclass(frozen=True)
class RecommendedTrack:
    title: str
    artist: str
    source_url: str
    score: float | None = None


class RecommendationEngine(Protocol):
    async def recommend(
        self, seeds: list[SeedTrack], limit: int
    ) -> list[RecommendedTrack]: ...
