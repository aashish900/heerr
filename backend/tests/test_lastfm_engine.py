import pytest

from app.services.recommenders.base import SeedTrack
from app.services.recommenders.lastfm_engine import LastFMEngine


class FakeLastFMClient:
    def __init__(self) -> None:
        self.track_similar_responses: dict[tuple[str, str], list[dict]] = {}
        self.artist_top_responses: dict[str, list[dict]] = {}
        self.user_top_response: list[dict] = []
        self.track_similar_calls: list[tuple[str, str, int]] = []
        self.artist_top_calls: list[tuple[str, int]] = []
        self.user_top_calls: list[tuple[str, str, int]] = []
        self.fail_track_similar_for: set[tuple[str, str]] = set()
        self.fail_user_top: bool = False

    async def track_get_similar(self, artist: str, title: str, limit: int) -> list[dict]:
        self.track_similar_calls.append((artist, title, limit))
        if (artist, title) in self.fail_track_similar_for:
            raise RuntimeError("track.getSimilar boom")
        return self.track_similar_responses.get((artist, title), [])

    async def artist_get_top_tracks(self, artist: str, limit: int) -> list[dict]:
        self.artist_top_calls.append((artist, limit))
        return self.artist_top_responses.get(artist, [])

    async def user_get_top_tracks(self, user: str, period: str, limit: int) -> list[dict]:
        self.user_top_calls.append((user, period, limit))
        if self.fail_user_top:
            raise RuntimeError("user.getTopTracks boom")
        return list(self.user_top_response)


class FakeResolver:
    def __init__(self) -> None:
        self.map: dict[tuple[str, str], str | None] = {}
        self.calls: list[tuple[str, str]] = []

    async def resolve(self, artist: str, title: str) -> str | None:
        self.calls.append((artist, title))
        return self.map.get((artist, title))


def _similar(name: str, artist: str, match: str) -> dict:
    return {"name": name, "artist": {"name": artist}, "match": match}


def _top(name: str, artist: str) -> dict:
    return {"name": name, "artist": {"name": artist}}


def _yt_url(slug: str) -> str:
    return f"https://music.youtube.com/watch?v={slug}"


@pytest.fixture
def client() -> FakeLastFMClient:
    return FakeLastFMClient()


@pytest.fixture
def resolver() -> FakeResolver:
    return FakeResolver()


def _engine(
    client: FakeLastFMClient, resolver: FakeResolver, username: str | None = None
) -> LastFMEngine:
    return LastFMEngine(api_key="test-key", username=username, client=client, resolver=resolver)


# ---------------------------------------------------------------------------
# Engine behaviour
# ---------------------------------------------------------------------------


async def test_track_similar_results_ranked_by_match_weight(client, resolver):
    client.track_similar_responses[("Seed Artist", "Seed Song")] = [
        _similar("Low", "ArtL", "0.20"),
        _similar("High", "ArtH", "0.90"),
        _similar("Mid", "ArtM", "0.60"),
    ]
    resolver.map = {
        ("ArtL", "Low"): _yt_url("L"),
        ("ArtH", "High"): _yt_url("H"),
        ("ArtM", "Mid"): _yt_url("M"),
    }
    engine = _engine(client, resolver)

    results = await engine.recommend([SeedTrack(title="Seed Song", artist="Seed Artist")], limit=20)

    assert [(r.title, r.score) for r in results] == [
        ("High", 0.9),
        ("Mid", 0.6),
        ("Low", 0.2),
    ]


async def test_artist_top_tracks_merged_at_lower_weight_than_similar(client, resolver):
    client.track_similar_responses[("A1", "T1")] = [
        _similar("SimSong", "SimArtist", "0.50"),
    ]
    client.artist_top_responses["A1"] = [
        _top("TopSong", "A1"),
    ]
    resolver.map = {
        ("SimArtist", "SimSong"): _yt_url("SIM"),
        ("A1", "TopSong"): _yt_url("TOP"),
    }
    engine = _engine(client, resolver)

    results = await engine.recommend([SeedTrack(title="T1", artist="A1")], limit=20)

    titles = [r.title for r in results]
    assert titles == ["SimSong", "TopSong"]  # higher match first
    assert results[0].score == 0.5
    assert 0.0 < results[1].score < 0.5  # baseline weight


async def test_seed_is_excluded_from_its_own_recommendations(client, resolver):
    client.track_similar_responses[("Artist", "Seed")] = [
        _similar("Seed", "Artist", "0.95"),  # the seed itself
        _similar("Other", "ArtO", "0.70"),
    ]
    resolver.map = {
        ("Artist", "Seed"): _yt_url("SEED"),
        ("ArtO", "Other"): _yt_url("OTHER"),
    }
    engine = _engine(client, resolver)

    results = await engine.recommend([SeedTrack(title="Seed", artist="Artist")], limit=20)
    assert [r.title for r in results] == ["Other"]


async def test_deduplicates_across_seeds_keeping_max_match(client, resolver):
    client.track_similar_responses[("A1", "T1")] = [
        _similar("Common", "Shared", "0.30"),
    ]
    client.track_similar_responses[("A2", "T2")] = [
        _similar("Common", "Shared", "0.80"),
    ]
    resolver.map = {("Shared", "Common"): _yt_url("C")}
    engine = _engine(client, resolver)

    results = await engine.recommend(
        [
            SeedTrack(title="T1", artist="A1"),
            SeedTrack(title="T2", artist="A2"),
        ],
        limit=20,
    )
    assert len(results) == 1
    assert results[0].score == 0.8


async def test_unresolvable_results_skipped(client, resolver):
    client.track_similar_responses[("A", "S")] = [
        _similar("Resolvable", "R", "0.50"),
        _similar("Unresolvable", "U", "0.40"),
    ]
    resolver.map = {("R", "Resolvable"): _yt_url("R")}  # U missing
    engine = _engine(client, resolver)

    results = await engine.recommend([SeedTrack(title="S", artist="A")], limit=20)
    assert [r.title for r in results] == ["Resolvable"]
    # Resolver was called for both
    assert ("R", "Resolvable") in resolver.calls
    assert ("U", "Unresolvable") in resolver.calls


async def test_limit_caps_results(client, resolver):
    client.track_similar_responses[("A", "S")] = [
        _similar(f"T{i}", f"Ar{i}", f"0.{99 - i}") for i in range(10)
    ]
    resolver.map = {(f"Ar{i}", f"T{i}"): _yt_url(f"V{i}") for i in range(10)}
    engine = _engine(client, resolver)

    results = await engine.recommend([SeedTrack(title="S", artist="A")], limit=3)
    assert len(results) == 3


async def test_username_augments_seeds_with_user_top_tracks(client, resolver):
    # No client-side seeds — must come from user history.
    client.user_top_response = [
        _top("UserSong1", "UserArtist1"),
        _top("UserSong2", "UserArtist2"),
    ]
    client.track_similar_responses[("UserArtist1", "UserSong1")] = [_similar("RecA", "RA", "0.70")]
    client.track_similar_responses[("UserArtist2", "UserSong2")] = [_similar("RecB", "RB", "0.60")]
    resolver.map = {
        ("RA", "RecA"): _yt_url("A"),
        ("RB", "RecB"): _yt_url("B"),
    }
    engine = _engine(client, resolver, username="aashish")

    results = await engine.recommend([], limit=20)
    assert client.user_top_calls == [("aashish", "1month", 10)]
    assert sorted(r.title for r in results) == ["RecA", "RecB"]


async def test_no_username_does_not_call_user_top_tracks(client, resolver):
    engine = _engine(client, resolver, username=None)
    await engine.recommend([SeedTrack(title="t", artist="a")], limit=20)
    assert client.user_top_calls == []


async def test_user_top_tracks_failure_does_not_kill_request(client, resolver):
    client.fail_user_top = True
    client.track_similar_responses[("A", "S")] = [_similar("R", "Ar", "0.50")]
    resolver.map = {("Ar", "R"): _yt_url("R")}
    engine = _engine(client, resolver, username="aashish")

    results = await engine.recommend([SeedTrack(title="S", artist="A")], limit=20)
    assert [r.title for r in results] == ["R"]


async def test_track_similar_exception_isolated_to_one_seed(client, resolver):
    client.fail_track_similar_for.add(("BadArtist", "BadSong"))
    client.track_similar_responses[("GoodArtist", "GoodSong")] = [
        _similar("RecOK", "OK", "0.50"),
    ]
    resolver.map = {("OK", "RecOK"): _yt_url("OK")}
    engine = _engine(client, resolver)

    results = await engine.recommend(
        [
            SeedTrack(title="BadSong", artist="BadArtist"),
            SeedTrack(title="GoodSong", artist="GoodArtist"),
        ],
        limit=20,
    )
    assert [r.title for r in results] == ["RecOK"]


async def test_empty_seeds_no_username_returns_empty(client, resolver):
    engine = _engine(client, resolver, username=None)
    results = await engine.recommend([], limit=20)
    assert results == []
    assert client.track_similar_calls == []
    assert client.artist_top_calls == []
    assert resolver.calls == []


async def test_malformed_lastfm_response_tolerated(client, resolver):
    client.track_similar_responses[("A", "S")] = [
        {},  # totally empty
        {"name": "NoArtist"},  # missing artist
        {"name": "BadMatch", "artist": {"name": "X"}, "match": "not-a-number"},
        _similar("Keeper", "K", "0.50"),
    ]
    resolver.map = {
        ("X", "BadMatch"): _yt_url("BM"),
        ("K", "Keeper"): _yt_url("KP"),
    }
    engine = _engine(client, resolver)

    results = await engine.recommend([SeedTrack(title="S", artist="A")], limit=20)
    # Keeper has higher match (0.5) than BadMatch (0.0). Both resolvable.
    assert [r.title for r in results] == ["Keeper", "BadMatch"]


async def test_engine_requires_api_key():
    with pytest.raises(RuntimeError, match="LASTFM_API_KEY"):
        LastFMEngine(api_key="")


# ---------------------------------------------------------------------------
# Factory wiring
# ---------------------------------------------------------------------------


def test_factory_lastfm_without_api_key_raises(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "lastfm")
    monkeypatch.delenv("LASTFM_API_KEY", raising=False)
    from app.services.recommenders.factory import get_recommendation_engine

    with pytest.raises(RuntimeError, match="LASTFM_API_KEY"):
        get_recommendation_engine()


def test_factory_lastfm_with_api_key_returns_engine(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "lastfm")
    monkeypatch.setenv("LASTFM_API_KEY", "abc123")
    monkeypatch.delenv("LASTFM_USERNAME", raising=False)
    from app.services.recommenders.factory import get_recommendation_engine

    engine = get_recommendation_engine()
    assert isinstance(engine, LastFMEngine)


def test_factory_lastfm_username_threaded_through(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "lastfm")
    monkeypatch.setenv("LASTFM_API_KEY", "abc123")
    monkeypatch.setenv("LASTFM_USERNAME", "aashish")
    from app.services.recommenders.factory import get_recommendation_engine

    engine = get_recommendation_engine()
    assert isinstance(engine, LastFMEngine)
    assert engine._username == "aashish"
