import os

from app.services.recommenders.base import RecommendationEngine
from app.services.recommenders.ytmusic_engine import YTMusicEngine

_SUPPORTED = {"ytmusic"}


def _engine_name() -> str:
    return os.environ.get("RECOMMENDATION_ENGINE", "ytmusic").strip()


def get_recommendation_engine() -> RecommendationEngine:
    name = _engine_name()
    if name == "":
        raise RuntimeError("RECOMMENDATION_ENGINE is set but empty")
    if name == "ytmusic":
        return YTMusicEngine()
    raise RuntimeError(
        f"unsupported RECOMMENDATION_ENGINE={name!r}; supported: {sorted(_SUPPORTED)}"
    )
