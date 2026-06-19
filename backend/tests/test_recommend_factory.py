"""Per-user credential threading in build_recommendation_engine (DEBT M5)."""

import pytest

from app.services.recommenders.factory import build_recommendation_engine
from app.services.recommenders.fallback_engine import FallbackEngine
from app.services.recommenders.lastfm_engine import LastFMEngine
from app.services.recommenders.listenbrainz_engine import ListenBrainzEngine
from app.services.recommenders.ytmusic_engine import YTMusicEngine

_ENV_VARS = (
    "RECOMMENDATION_ENGINE",
    "LASTFM_API_KEY",
    "LASTFM_USERNAME",
    "LISTENBRAINZ_USER_TOKEN",
)


@pytest.fixture(autouse=True)
def _clean_env(monkeypatch):
    for var in _ENV_VARS:
        monkeypatch.delenv(var, raising=False)


def test_default_engine_is_ytmusic(monkeypatch):
    assert isinstance(build_recommendation_engine(), YTMusicEngine)


def test_lastfm_prefers_per_user_username(monkeypatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "lastfm")
    monkeypatch.setenv("LASTFM_API_KEY", "key")
    monkeypatch.setenv("LASTFM_USERNAME", "global-user")
    engine = build_recommendation_engine(lastfm_username="alice")
    assert isinstance(engine, LastFMEngine)
    assert engine._username == "alice"


def test_lastfm_falls_back_to_env_username(monkeypatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "lastfm")
    monkeypatch.setenv("LASTFM_API_KEY", "key")
    monkeypatch.setenv("LASTFM_USERNAME", "global-user")
    engine = build_recommendation_engine(lastfm_username=None)
    assert isinstance(engine, LastFMEngine)
    assert engine._username == "global-user"


def test_lastfm_requires_api_key(monkeypatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "lastfm")
    with pytest.raises(RuntimeError, match="LASTFM_API_KEY"):
        build_recommendation_engine(lastfm_username="alice")


def test_listenbrainz_per_user_token_builds(monkeypatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "listenbrainz")
    # No global env token — only the per-user value. Building proves it is used.
    engine = build_recommendation_engine(listenbrainz_token="user-tok")
    assert isinstance(engine, ListenBrainzEngine)


def test_listenbrainz_requires_a_token(monkeypatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "listenbrainz")
    with pytest.raises(RuntimeError, match="LISTENBRAINZ_USER_TOKEN"):
        build_recommendation_engine(listenbrainz_token=None)


def test_fallback_chain_builds(monkeypatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "listenbrainz,ytmusic")
    engine = build_recommendation_engine(listenbrainz_token="user-tok")
    assert isinstance(engine, FallbackEngine)
