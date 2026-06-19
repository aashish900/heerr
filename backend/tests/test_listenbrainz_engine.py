import pytest

from app.services.recommenders.base import SeedTrack
from app.services.recommenders.listenbrainz_engine import ListenBrainzEngine


class FakeListenBrainzClient:
    def __init__(self) -> None:
        self.username: str | None = "aashish"
        self.validate_calls = 0
        self.validate_raises: bool = False

        self.recommendations: list[dict] = []
        self.recommendation_calls: list[tuple[str, int]] = []
        self.recommendations_raise: bool = False

        self.metadata_response: dict[str, dict] = {}
        self.metadata_calls: list[list[str]] = []
        self.metadata_raises: bool = False

    async def validate_token(self) -> str | None:
        self.validate_calls += 1
        if self.validate_raises:
            raise RuntimeError("validate boom")
        return self.username

    async def get_user_recommendations(self, username: str, count: int) -> list[dict]:
        self.recommendation_calls.append((username, count))
        if self.recommendations_raise:
            raise RuntimeError("recs boom")
        return list(self.recommendations)

    async def get_recording_metadata(self, mbids: list[str]) -> dict[str, dict]:
        self.metadata_calls.append(list(mbids))
        if self.metadata_raises:
            raise RuntimeError("metadata boom")
        return {m: self.metadata_response[m] for m in mbids if m in self.metadata_response}


class FakeResolver:
    def __init__(self) -> None:
        self.map: dict[tuple[str, str], str | None] = {}
        self.calls: list[tuple[str, str]] = []

    async def resolve(self, artist: str, title: str) -> str | None:
        self.calls.append((artist, title))
        return self.map.get((artist, title))


def _mbid_item(mbid: str, score: float) -> dict:
    return {"recording_mbid": mbid, "score": score}


def _meta(name: str, artist: str) -> dict:
    return {
        "recording": {"name": name, "length": 1000},
        "artist": {"name": artist},
    }


def _yt(slug: str) -> str:
    return f"https://music.youtube.com/watch?v={slug}"


@pytest.fixture
def client() -> FakeListenBrainzClient:
    return FakeListenBrainzClient()


@pytest.fixture
def resolver() -> FakeResolver:
    return FakeResolver()


def _engine(client, resolver) -> ListenBrainzEngine:
    return ListenBrainzEngine(token="test-token", client=client, resolver=resolver)


# ---------------------------------------------------------------------------
# Engine behaviour
# ---------------------------------------------------------------------------


async def test_happy_path_returns_resolved_results_in_score_order(client, resolver):
    client.recommendations = [
        _mbid_item("MB1", 0.9),
        _mbid_item("MB2", 0.7),
    ]
    client.metadata_response = {
        "MB1": _meta("Title1", "Artist1"),
        "MB2": _meta("Title2", "Artist2"),
    }
    resolver.map = {
        ("Artist1", "Title1"): _yt("V1"),
        ("Artist2", "Title2"): _yt("V2"),
    }
    engine = _engine(client, resolver)

    results = await engine.recommend([], 20)
    assert [r.source_url for r in results] == [_yt("V1"), _yt("V2")]
    assert results[0].score == 0.9
    assert results[1].score == 0.7
    assert client.validate_calls == 1


async def test_client_seeds_are_ignored(client, resolver):
    # ListenBrainz drives results from user history; client seeds are
    # accepted but not used in v1.
    client.recommendations = [_mbid_item("MB1", 0.5)]
    client.metadata_response = {"MB1": _meta("T", "A")}
    resolver.map = {("A", "T"): _yt("X")}
    engine = _engine(client, resolver)

    seeds = [SeedTrack(title="ignored", artist="ignored")]
    results = await engine.recommend(seeds, 20)
    assert len(results) == 1
    # Recommendations endpoint was called with the resolved username,
    # not anything derived from the seed.
    assert client.recommendation_calls[0][0] == "aashish"


async def test_username_cached_across_calls(client, resolver):
    client.recommendations = []
    engine = _engine(client, resolver)

    await engine.recommend([], 20)
    await engine.recommend([], 20)
    assert client.validate_calls == 1


async def test_validate_token_failure_returns_empty(client, resolver):
    client.validate_raises = True
    engine = _engine(client, resolver)
    assert await engine.recommend([], 20) == []
    assert client.recommendation_calls == []


async def test_invalid_token_returns_empty(client, resolver):
    client.username = None  # validate_token says invalid
    engine = _engine(client, resolver)
    assert await engine.recommend([], 20) == []
    assert client.recommendation_calls == []


async def test_recommendations_endpoint_failure_returns_empty(client, resolver):
    client.recommendations_raise = True
    engine = _engine(client, resolver)
    assert await engine.recommend([], 20) == []
    assert client.metadata_calls == []


async def test_metadata_endpoint_failure_returns_empty(client, resolver):
    client.recommendations = [_mbid_item("MB1", 0.5)]
    client.metadata_raises = True
    engine = _engine(client, resolver)
    assert await engine.recommend([], 20) == []
    assert resolver.calls == []


async def test_empty_recommendations_returns_empty(client, resolver):
    client.recommendations = []
    engine = _engine(client, resolver)
    assert await engine.recommend([], 20) == []
    assert client.metadata_calls == []


async def test_unresolvable_results_skipped(client, resolver):
    client.recommendations = [
        _mbid_item("MB1", 0.9),
        _mbid_item("MB2", 0.7),
    ]
    client.metadata_response = {
        "MB1": _meta("T1", "A1"),
        "MB2": _meta("T2", "A2"),
    }
    resolver.map = {("A2", "T2"): _yt("V2")}  # MB1 unresolvable
    engine = _engine(client, resolver)

    results = await engine.recommend([], 20)
    assert [r.source_url for r in results] == [_yt("V2")]
    assert ("A1", "T1") in resolver.calls
    assert ("A2", "T2") in resolver.calls


async def test_limit_caps_results(client, resolver):
    client.recommendations = [_mbid_item(f"MB{i}", 1.0 - i * 0.01) for i in range(10)]
    client.metadata_response = {f"MB{i}": _meta(f"T{i}", f"A{i}") for i in range(10)}
    resolver.map = {(f"A{i}", f"T{i}"): _yt(f"V{i}") for i in range(10)}
    engine = _engine(client, resolver)

    results = await engine.recommend([], 3)
    assert len(results) == 3
    assert [r.title for r in results] == ["T0", "T1", "T2"]


async def test_metadata_missing_for_some_mbids_tolerated(client, resolver):
    client.recommendations = [
        _mbid_item("MB1", 0.9),
        _mbid_item("MB2", 0.7),
    ]
    client.metadata_response = {"MB1": _meta("T1", "A1")}  # MB2 absent
    resolver.map = {("A1", "T1"): _yt("V1")}
    engine = _engine(client, resolver)

    results = await engine.recommend([], 20)
    assert [r.source_url for r in results] == [_yt("V1")]


async def test_recommendation_item_missing_mbid_skipped(client, resolver):
    client.recommendations = [
        {"score": 0.9},  # no recording_mbid
        _mbid_item("MB1", 0.7),
    ]
    client.metadata_response = {"MB1": _meta("T", "A")}
    resolver.map = {("A", "T"): _yt("V")}
    engine = _engine(client, resolver)

    results = await engine.recommend([], 20)
    assert [r.source_url for r in results] == [_yt("V")]


async def test_probe_ok_when_valid_token(client, resolver):
    client.username = "aashish"
    engine = _engine(client, resolver)
    assert await engine.probe() is True


async def test_probe_false_when_validate_raises(client, resolver):
    client.validate_raises = True
    engine = _engine(client, resolver)
    assert await engine.probe() is False


async def test_probe_false_when_invalid_token(client, resolver):
    client.username = None
    engine = _engine(client, resolver)
    assert await engine.probe() is False


async def test_health_chain_single_element(client, resolver):
    engine = _engine(client, resolver)
    chain = await engine.health_chain()
    assert chain == [("listenbrainz", True)]


def test_engine_requires_token():
    with pytest.raises(RuntimeError, match="LISTENBRAINZ_USER_TOKEN"):
        ListenBrainzEngine(token="")


# ---------------------------------------------------------------------------
# Factory wiring
# ---------------------------------------------------------------------------


def test_factory_listenbrainz_without_token_raises(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "listenbrainz")
    monkeypatch.delenv("LISTENBRAINZ_USER_TOKEN", raising=False)
    from app.services.recommenders.factory import build_recommendation_engine

    with pytest.raises(RuntimeError, match="LISTENBRAINZ_USER_TOKEN"):
        build_recommendation_engine()


def test_factory_listenbrainz_with_token_returns_engine(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "listenbrainz")
    monkeypatch.setenv("LISTENBRAINZ_USER_TOKEN", "abc-token")
    from app.services.recommenders.factory import build_recommendation_engine

    engine = build_recommendation_engine()
    assert isinstance(engine, ListenBrainzEngine)


def test_factory_listenbrainz_in_chain(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "listenbrainz,ytmusic")
    monkeypatch.setenv("LISTENBRAINZ_USER_TOKEN", "abc-token")
    from app.services.recommenders.factory import build_recommendation_engine
    from app.services.recommenders.fallback_engine import FallbackEngine
    from app.services.recommenders.ytmusic_engine import YTMusicEngine

    engine = build_recommendation_engine()
    assert isinstance(engine, FallbackEngine)
    types = [type(e) for e in engine.engines]
    assert types == [ListenBrainzEngine, YTMusicEngine]
