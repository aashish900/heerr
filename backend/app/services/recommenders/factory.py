import os

from app.services.recommenders.base import (
    RecommendationEngine,
    RecommendedTrack,
    SeedTrack,
)


class _StubEngine:
    async def recommend(
        self, seeds: list[SeedTrack], limit: int
    ) -> list[RecommendedTrack]:
        return []


def _engine_name() -> str:
    return os.environ.get("RECOMMENDATION_ENGINE", "ytmusic").strip()


def get_recommendation_engine() -> RecommendationEngine:
    name = _engine_name()
    if name == "":
        raise RuntimeError("RECOMMENDATION_ENGINE is set but empty")
    # I1: every selection routes to the stub. Real engines land in I2+.
    return _StubEngine()
