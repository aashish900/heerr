import os

from app.services.recommenders.base import RecommendationEngine
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


def get_recommendation_engine() -> RecommendationEngine:
    name = _engine_name()
    if name == "":
        raise RuntimeError("RECOMMENDATION_ENGINE is set but empty")
    if name == "ytmusic":
        return YTMusicEngine()
    if name == "lastfm":
        return _build_lastfm()
    raise RuntimeError(
        f"unsupported RECOMMENDATION_ENGINE={name!r}; supported: {sorted(_SUPPORTED)}"
    )
