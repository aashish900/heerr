import os

from app.services.recommenders.base import RecommendationEngine
from app.services.recommenders.fallback_engine import FallbackEngine
from app.services.recommenders.lastfm_engine import LastFMEngine
from app.services.recommenders.listenbrainz_engine import ListenBrainzEngine
from app.services.recommenders.ytmusic_engine import YTMusicEngine

_SUPPORTED = {"ytmusic", "lastfm", "listenbrainz"}


def _engine_name() -> str:
    return os.environ.get("RECOMMENDATION_ENGINE", "ytmusic").strip()


def _build_lastfm() -> LastFMEngine:
    api_key = os.environ.get("LASTFM_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("RECOMMENDATION_ENGINE=lastfm requires LASTFM_API_KEY")
    username = os.environ.get("LASTFM_USERNAME", "").strip() or None
    return LastFMEngine(api_key=api_key, username=username)


def _build_listenbrainz() -> ListenBrainzEngine:
    token = os.environ.get("LISTENBRAINZ_USER_TOKEN", "").strip()
    if not token:
        raise RuntimeError("RECOMMENDATION_ENGINE=listenbrainz requires LISTENBRAINZ_USER_TOKEN")
    return ListenBrainzEngine(token=token)


def _build_one(name: str) -> RecommendationEngine:
    if name == "ytmusic":
        return YTMusicEngine()
    if name == "lastfm":
        return _build_lastfm()
    if name == "listenbrainz":
        return _build_listenbrainz()
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
