import os

from app.services.recommenders.base import RecommendationEngine
from app.services.recommenders.fallback_engine import FallbackEngine
from app.services.recommenders.lastfm_engine import LastFMEngine
from app.services.recommenders.ytmusic_engine import YTMusicEngine

_SUPPORTED = {"ytmusic", "lastfm"}


def _engine_name() -> str:
    return os.environ.get("RECOMMENDATION_ENGINE", "ytmusic").strip()


def _build_lastfm() -> LastFMEngine:
    api_key = os.environ.get("LASTFM_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError(
            "RECOMMENDATION_ENGINE=lastfm requires LASTFM_API_KEY"
        )
    username = os.environ.get("LASTFM_USERNAME", "").strip() or None
    return LastFMEngine(api_key=api_key, username=username)


def _build_one(name: str) -> RecommendationEngine:
    if name == "ytmusic":
        return YTMusicEngine()
    if name == "lastfm":
        return _build_lastfm()
    raise RuntimeError(
        f"unsupported RECOMMENDATION_ENGINE={name!r}; supported: {sorted(_SUPPORTED)}"
    )


def get_recommendation_engine() -> RecommendationEngine:
    raw = _engine_name()
    if raw == "":
        raise RuntimeError("RECOMMENDATION_ENGINE is set but empty")

    names = [n.strip() for n in raw.split(",") if n.strip()]
    if not names:
        raise RuntimeError("RECOMMENDATION_ENGINE is set but empty")

    if len(names) == 1:
        return _build_one(names[0])

    return FallbackEngine([_build_one(n) for n in names])
