import os

from fastapi import Depends

from app.api.deps import current_user
from app.models import User
from app.services.recommenders.base import RecommendationEngine
from app.services.recommenders.fallback_engine import FallbackEngine
from app.services.recommenders.lastfm_engine import LastFMEngine
from app.services.recommenders.listenbrainz_engine import ListenBrainzEngine
from app.services.recommenders.ytmusic_engine import YTMusicEngine

_SUPPORTED = {"ytmusic", "lastfm", "listenbrainz"}


def _engine_name() -> str:
    return os.environ.get("RECOMMENDATION_ENGINE", "ytmusic").strip()


def _build_lastfm(lastfm_username: str | None) -> LastFMEngine:
    # LASTFM_API_KEY is the operator's service key — global, not per-user.
    api_key = os.environ.get("LASTFM_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("RECOMMENDATION_ENGINE=lastfm requires LASTFM_API_KEY")
    # Username is per-user; fall back to the global env var for single-user deploys.
    username = lastfm_username or os.environ.get("LASTFM_USERNAME", "").strip() or None
    return LastFMEngine(api_key=api_key, username=username)


def _build_listenbrainz(listenbrainz_token: str | None) -> ListenBrainzEngine:
    # The token IS the user's ListenBrainz identity; prefer the per-user value,
    # fall back to the global env var for single-user deploys.
    token = listenbrainz_token or os.environ.get("LISTENBRAINZ_USER_TOKEN", "").strip()
    if not token:
        raise RuntimeError(
            "RECOMMENDATION_ENGINE=listenbrainz requires a LISTENBRAINZ_USER_TOKEN "
            "(per-user setting or global env var)"
        )
    return ListenBrainzEngine(token=token)


def _build_one(
    name: str,
    *,
    lastfm_username: str | None,
    listenbrainz_token: str | None,
) -> RecommendationEngine:
    if name == "ytmusic":
        return YTMusicEngine()
    if name == "lastfm":
        return _build_lastfm(lastfm_username)
    if name == "listenbrainz":
        return _build_listenbrainz(listenbrainz_token)
    raise RuntimeError(
        f"unsupported RECOMMENDATION_ENGINE={name!r}; supported: {sorted(_SUPPORTED)}"
    )


def build_recommendation_engine(
    *,
    lastfm_username: str | None = None,
    listenbrainz_token: str | None = None,
) -> RecommendationEngine:
    """Build the configured engine, threading per-user credentials.

    `RECOMMENDATION_ENGINE` and `LASTFM_API_KEY` are operator-global env vars.
    `lastfm_username` / `listenbrainz_token` are the requesting user's personal
    settings (each falls back to a global env var when unset).
    """
    raw = _engine_name()
    if raw == "":
        raise RuntimeError("RECOMMENDATION_ENGINE is set but empty")

    names = [n.strip() for n in raw.split(",") if n.strip()]
    if not names:
        raise RuntimeError("RECOMMENDATION_ENGINE is set but empty")

    if len(names) == 1:
        return _build_one(
            names[0],
            lastfm_username=lastfm_username,
            listenbrainz_token=listenbrainz_token,
        )

    return FallbackEngine(
        [
            _build_one(
                n,
                lastfm_username=lastfm_username,
                listenbrainz_token=listenbrainz_token,
            )
            for n in names
        ]
    )


async def get_recommendation_engine(
    user: User = Depends(current_user),
) -> RecommendationEngine:
    """FastAPI dependency: build the engine with the requesting user's settings."""
    settings = user.settings or {}
    return build_recommendation_engine(
        lastfm_username=settings.get("lastfm_username"),
        listenbrainz_token=settings.get("listenbrainz_token"),
    )
