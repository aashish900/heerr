import asyncio
import logging

from app.services.recommenders.base import (
    RecommendationEngine,
    RecommendedTrack,
    SeedTrack,
)

logger = logging.getLogger(__name__)


class FallbackEngine:
    """Tries each wrapped engine left-to-right. Any exception from `recommend`
    falls back to the next engine; an empty result (without exception) is the
    final answer.

    `health_chain` probes every engine in parallel and returns a list of
    `(name, ok)` tuples in chain order; `probe` returns True if any engine in
    the chain reports OK.
    """

    def __init__(self, engines: list[RecommendationEngine]) -> None:
        if not engines:
            raise ValueError("FallbackEngine requires at least one engine")
        self._engines = engines
        self.name = ",".join(e.name for e in engines)

    @property
    def engines(self) -> list[RecommendationEngine]:
        return list(self._engines)

    async def recommend(self, seeds: list[SeedTrack], limit: int) -> list[RecommendedTrack]:
        for engine in self._engines:
            try:
                return await engine.recommend(seeds, limit)
            except Exception as exc:
                logger.warning(
                    "recommendation engine %s failed, falling back: %s",
                    engine.name,
                    exc,
                )
                continue
        return []

    async def probe(self) -> bool:
        chain = await self.health_chain()
        return any(ok for _, ok in chain)

    async def health_chain(self) -> list[tuple[str, bool]]:
        probes = await asyncio.gather(*(e.probe() for e in self._engines))
        return [(e.name, ok) for e, ok in zip(self._engines, probes, strict=True)]
