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
    name: str

    async def recommend(self, seeds: list[SeedTrack], limit: int) -> list[RecommendedTrack]: ...

    async def probe(self) -> bool:
        """Lightweight liveness probe. Should return True if the engine can
        currently serve recommendations; False otherwise. Implementations must
        not raise — catch and convert to False."""
        ...

    async def health_chain(self) -> list[tuple[str, bool]]:
        """Returns `(engine_name, ok)` tuples in priority order. Single engines
        yield a 1-element list; `FallbackEngine` yields N elements covering
        every engine in the chain."""
        ...
