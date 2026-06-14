import logging

import pytest

from app.services.recommenders.base import RecommendedTrack, SeedTrack
from app.services.recommenders.fallback_engine import FallbackEngine


class FakeEngine:
    def __init__(
        self,
        name: str,
        results: list[RecommendedTrack] | None = None,
        recommend_raises: bool = False,
        probe_ok: bool = True,
    ) -> None:
        self.name = name
        self._results = results or []
        self._recommend_raises = recommend_raises
        self._probe_ok = probe_ok
        self.recommend_calls = 0
        self.probe_calls = 0

    async def recommend(self, seeds: list[SeedTrack], limit: int) -> list[RecommendedTrack]:
        self.recommend_calls += 1
        if self._recommend_raises:
            raise RuntimeError(f"{self.name} down")
        return list(self._results)

    async def probe(self) -> bool:
        self.probe_calls += 1
        return self._probe_ok

    async def health_chain(self) -> list[tuple[str, bool]]:
        return [(self.name, await self.probe())]


_REC = RecommendedTrack(
    title="x", artist="y", source_url="https://music.youtube.com/watch?v=x", score=0.5
)


def test_fallback_engine_requires_at_least_one_engine():
    with pytest.raises(ValueError):
        FallbackEngine([])


async def test_primary_success_returns_primary_results_no_secondary_call():
    primary = FakeEngine("primary", results=[_REC])
    secondary = FakeEngine("secondary", results=[])
    engine = FallbackEngine([primary, secondary])

    results = await engine.recommend([], 20)
    assert results == [_REC]
    assert primary.recommend_calls == 1
    assert secondary.recommend_calls == 0


async def test_primary_empty_results_not_a_fallback_trigger():
    primary = FakeEngine("primary", results=[])
    secondary = FakeEngine("secondary", results=[_REC])
    engine = FallbackEngine([primary, secondary])

    results = await engine.recommend([], 20)
    # primary returned [] without raising — that's the final answer.
    assert results == []
    assert primary.recommend_calls == 1
    assert secondary.recommend_calls == 0


async def test_primary_exception_falls_back_to_secondary(caplog):
    primary = FakeEngine("primary", recommend_raises=True)
    secondary = FakeEngine("secondary", results=[_REC])
    engine = FallbackEngine([primary, secondary])

    with caplog.at_level(logging.WARNING):
        results = await engine.recommend([], 20)
    assert results == [_REC]
    assert primary.recommend_calls == 1
    assert secondary.recommend_calls == 1
    assert any("primary" in r.getMessage() and "down" in r.getMessage() for r in caplog.records)


async def test_all_engines_fail_returns_empty(caplog):
    primary = FakeEngine("primary", recommend_raises=True)
    secondary = FakeEngine("secondary", recommend_raises=True)
    engine = FallbackEngine([primary, secondary])

    with caplog.at_level(logging.WARNING):
        results = await engine.recommend([], 20)
    assert results == []
    assert primary.recommend_calls == 1
    assert secondary.recommend_calls == 1


async def test_third_engine_used_when_first_two_fail():
    e1 = FakeEngine("e1", recommend_raises=True)
    e2 = FakeEngine("e2", recommend_raises=True)
    e3 = FakeEngine("e3", results=[_REC])
    engine = FallbackEngine([e1, e2, e3])

    results = await engine.recommend([], 20)
    assert results == [_REC]
    assert e1.recommend_calls == e2.recommend_calls == e3.recommend_calls == 1


async def test_health_chain_reports_each_engine_in_order():
    e1 = FakeEngine("e1", probe_ok=False)
    e2 = FakeEngine("e2", probe_ok=True)
    engine = FallbackEngine([e1, e2])

    chain = await engine.health_chain()
    assert chain == [("e1", False), ("e2", True)]


async def test_probe_true_if_any_engine_probes_ok():
    e1 = FakeEngine("e1", probe_ok=False)
    e2 = FakeEngine("e2", probe_ok=True)
    engine = FallbackEngine([e1, e2])

    assert await engine.probe() is True


async def test_probe_false_if_all_engines_probe_fail():
    e1 = FakeEngine("e1", probe_ok=False)
    e2 = FakeEngine("e2", probe_ok=False)
    engine = FallbackEngine([e1, e2])

    assert await engine.probe() is False


async def test_name_joins_engine_names():
    e1 = FakeEngine("lastfm")
    e2 = FakeEngine("ytmusic")
    engine = FallbackEngine([e1, e2])
    assert engine.name == "lastfm,ytmusic"


# ---------------------------------------------------------------------------
# Factory: comma-separated chain parsing
# ---------------------------------------------------------------------------


def test_factory_single_name_returns_single_engine(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "ytmusic")
    from app.services.recommenders.factory import get_recommendation_engine
    from app.services.recommenders.ytmusic_engine import YTMusicEngine

    engine = get_recommendation_engine()
    assert isinstance(engine, YTMusicEngine)
    assert not isinstance(engine, FallbackEngine)


def test_factory_two_name_chain_returns_fallback_engine(
    monkeypatch: pytest.MonkeyPatch,
):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "lastfm,ytmusic")
    monkeypatch.setenv("LASTFM_API_KEY", "abc")
    from app.services.recommenders.factory import get_recommendation_engine
    from app.services.recommenders.lastfm_engine import LastFMEngine
    from app.services.recommenders.ytmusic_engine import YTMusicEngine

    engine = get_recommendation_engine()
    assert isinstance(engine, FallbackEngine)
    assert [type(e) for e in engine.engines] == [LastFMEngine, YTMusicEngine]
    assert engine.name == "lastfm,ytmusic"


def test_factory_tolerates_whitespace_in_chain(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", " ytmusic , lastfm ")
    monkeypatch.setenv("LASTFM_API_KEY", "abc")
    from app.services.recommenders.factory import get_recommendation_engine

    engine = get_recommendation_engine()
    assert isinstance(engine, FallbackEngine)
    assert [e.name for e in engine.engines] == ["ytmusic", "lastfm"]


def test_factory_unknown_name_in_chain_raises(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "ytmusic,nope")
    from app.services.recommenders.factory import get_recommendation_engine

    with pytest.raises(RuntimeError, match="nope"):
        get_recommendation_engine()


def test_factory_only_commas_raises(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", ",,,")
    from app.services.recommenders.factory import get_recommendation_engine

    with pytest.raises(RuntimeError, match="empty"):
        get_recommendation_engine()
