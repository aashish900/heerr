import pytest

from app.services.recommenders.base import SeedTrack
from app.services.recommenders.ytmusic_engine import YTMusicEngine


class FakeYTMusic:
    def __init__(self) -> None:
        # videoId -> get_watch_playlist response
        self.watch_responses: dict[str, dict] = {}
        # query -> search response list
        self.search_responses: dict[str, list[dict]] = {}
        self.get_watch_playlist_calls: list[str] = []
        self.search_calls: list[tuple[str, str | None, int]] = []
        self.fail_watch_ids: set[str] = set()

    def get_watch_playlist(self, videoId: str, **kwargs: object) -> dict:
        self.get_watch_playlist_calls.append(videoId)
        if videoId in self.fail_watch_ids:
            raise RuntimeError(f"watch failure for {videoId}")
        return self.watch_responses.get(videoId, {"tracks": []})

    def search(
        self, query: str, filter: str | None = None, limit: int = 20
    ) -> list[dict]:
        self.search_calls.append((query, filter, limit))
        return self.search_responses.get(query, [])


def _track(video_id: str, title: str, artist: str) -> dict:
    return {
        "videoId": video_id,
        "title": title,
        "artists": [{"name": artist}],
    }


async def test_seed_with_watch_url_calls_get_watch_playlist():
    yt = FakeYTMusic()
    yt.watch_responses["SEED1"] = {
        "tracks": [
            _track("SEED1", "Seed Song", "Seed Artist"),
            _track("REC1", "Rec One", "Artist A"),
            _track("REC2", "Rec Two", "Artist B"),
        ]
    }
    engine = YTMusicEngine(yt=yt)

    seeds = [
        SeedTrack(
            title="Seed Song",
            artist="Seed Artist",
            source_url="https://music.youtube.com/watch?v=SEED1",
        )
    ]
    results = await engine.recommend(seeds, limit=20)

    assert yt.get_watch_playlist_calls == ["SEED1"]
    assert yt.search_calls == []
    # SEED1 (the seed itself) excluded, REC1 + REC2 returned
    assert [r.source_url for r in results] == [
        "https://music.youtube.com/watch?v=REC1",
        "https://music.youtube.com/watch?v=REC2",
    ]
    assert results[0].title == "Rec One"
    assert results[0].artist == "Artist A"
    assert results[0].score is None


async def test_seed_without_url_resolves_via_search_first():
    yt = FakeYTMusic()
    yt.search_responses["Artist X Title X"] = [
        {"videoId": "RESOLVED1", "title": "Title X", "artists": [{"name": "Artist X"}]}
    ]
    yt.watch_responses["RESOLVED1"] = {
        "tracks": [
            _track("RESOLVED1", "Title X", "Artist X"),
            _track("RECX", "Rec X", "Other"),
        ]
    }
    engine = YTMusicEngine(yt=yt)

    results = await engine.recommend(
        [SeedTrack(title="Title X", artist="Artist X")], limit=20
    )

    assert yt.search_calls == [("Artist X Title X", "songs", 1)]
    assert yt.get_watch_playlist_calls == ["RESOLVED1"]
    assert [r.source_url for r in results] == [
        "https://music.youtube.com/watch?v=RECX"
    ]


async def test_seed_without_url_no_search_match_skipped():
    yt = FakeYTMusic()
    # search returns empty for this query
    engine = YTMusicEngine(yt=yt)

    results = await engine.recommend(
        [SeedTrack(title="Unknown", artist="Nobody")], limit=20
    )

    assert yt.search_calls == [("Nobody Unknown", "songs", 1)]
    assert yt.get_watch_playlist_calls == []
    assert results == []


async def test_deduplicates_across_seeds():
    yt = FakeYTMusic()
    yt.watch_responses["S1"] = {
        "tracks": [
            _track("S1", "S1 Seed", "Seed1"),
            _track("DUP", "Dup Track", "Common"),
            _track("REC_A", "A", "Artist"),
        ]
    }
    yt.watch_responses["S2"] = {
        "tracks": [
            _track("S2", "S2 Seed", "Seed2"),
            _track("DUP", "Dup Track", "Common"),  # already seen via S1
            _track("REC_B", "B", "Artist"),
        ]
    }
    engine = YTMusicEngine(yt=yt)

    seeds = [
        SeedTrack(
            title="t1", artist="a1", source_url="https://music.youtube.com/watch?v=S1"
        ),
        SeedTrack(
            title="t2", artist="a2", source_url="https://music.youtube.com/watch?v=S2"
        ),
    ]
    results = await engine.recommend(seeds, limit=20)

    assert [r.source_url for r in results] == [
        "https://music.youtube.com/watch?v=DUP",
        "https://music.youtube.com/watch?v=REC_A",
        "https://music.youtube.com/watch?v=REC_B",
    ]


async def test_caps_at_limit():
    yt = FakeYTMusic()
    yt.watch_responses["S1"] = {
        "tracks": [_track("S1", "Seed", "Seed")]
        + [_track(f"REC{i}", f"T{i}", f"A{i}") for i in range(30)]
    }
    engine = YTMusicEngine(yt=yt)

    results = await engine.recommend(
        [
            SeedTrack(
                title="t",
                artist="a",
                source_url="https://music.youtube.com/watch?v=S1",
            )
        ],
        limit=5,
    )
    assert len(results) == 5
    assert results[0].source_url == "https://music.youtube.com/watch?v=REC0"
    assert results[4].source_url == "https://music.youtube.com/watch?v=REC4"


async def test_get_watch_playlist_failure_skips_seed_processes_next():
    yt = FakeYTMusic()
    yt.fail_watch_ids.add("BAD")
    yt.watch_responses["GOOD"] = {
        "tracks": [
            _track("GOOD", "Good Seed", "X"),
            _track("REC_OK", "Rec OK", "X"),
        ]
    }
    engine = YTMusicEngine(yt=yt)

    seeds = [
        SeedTrack(
            title="b",
            artist="b",
            source_url="https://music.youtube.com/watch?v=BAD",
        ),
        SeedTrack(
            title="g",
            artist="g",
            source_url="https://music.youtube.com/watch?v=GOOD",
        ),
    ]
    results = await engine.recommend(seeds, limit=20)
    assert [r.source_url for r in results] == [
        "https://music.youtube.com/watch?v=REC_OK"
    ]


async def test_search_failure_skips_seed_silently():
    yt = FakeYTMusic()

    def _boom(*a: object, **kw: object) -> list[dict]:
        raise RuntimeError("search down")

    yt.search = _boom  # type: ignore[method-assign]
    engine = YTMusicEngine(yt=yt)

    results = await engine.recommend(
        [SeedTrack(title="x", artist="y")], limit=20
    )
    assert results == []


async def test_tracks_missing_required_fields_skipped():
    yt = FakeYTMusic()
    yt.watch_responses["S1"] = {
        "tracks": [
            _track("S1", "Seed", "Seed"),
            {"videoId": "NO_TITLE", "title": "", "artists": [{"name": "A"}]},
            {"videoId": "NO_ARTIST", "title": "T", "artists": []},
            {"title": "no vid", "artists": [{"name": "A"}]},
            _track("KEEPER", "Keeper", "Keep Artist"),
        ]
    }
    engine = YTMusicEngine(yt=yt)
    results = await engine.recommend(
        [
            SeedTrack(
                title="t",
                artist="a",
                source_url="https://music.youtube.com/watch?v=S1",
            )
        ],
        limit=20,
    )
    assert [r.source_url for r in results] == [
        "https://music.youtube.com/watch?v=KEEPER"
    ]


async def test_empty_seeds_returns_empty():
    yt = FakeYTMusic()
    engine = YTMusicEngine(yt=yt)
    assert await engine.recommend([], limit=20) == []
    assert yt.search_calls == []
    assert yt.get_watch_playlist_calls == []


async def test_non_youtube_source_url_falls_back_to_search():
    yt = FakeYTMusic()
    yt.search_responses["Artist Title"] = [
        {"videoId": "RES1", "title": "Title", "artists": [{"name": "Artist"}]}
    ]
    yt.watch_responses["RES1"] = {
        "tracks": [
            _track("RES1", "Title", "Artist"),
            _track("RECY", "Y", "Y"),
        ]
    }
    engine = YTMusicEngine(yt=yt)
    seeds = [
        SeedTrack(
            title="Title",
            artist="Artist",
            source_url="https://open.spotify.com/track/whatever",
        )
    ]
    results = await engine.recommend(seeds, limit=20)
    assert yt.search_calls == [("Artist Title", "songs", 1)]
    assert [r.source_url for r in results] == [
        "https://music.youtube.com/watch?v=RECY"
    ]


# --- factory tests ----------------------------------------------------------


def test_factory_default_returns_ytmusic_engine(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.delenv("RECOMMENDATION_ENGINE", raising=False)
    from app.services.recommenders.factory import get_recommendation_engine

    engine = get_recommendation_engine()
    assert isinstance(engine, YTMusicEngine)


def test_factory_ytmusic_name_returns_ytmusic_engine(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "ytmusic")
    from app.services.recommenders.factory import get_recommendation_engine

    assert isinstance(get_recommendation_engine(), YTMusicEngine)


def test_factory_empty_value_raises(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "")
    from app.services.recommenders.factory import get_recommendation_engine

    with pytest.raises(RuntimeError, match="empty"):
        get_recommendation_engine()


def test_factory_unknown_name_raises(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "nope-engine")
    from app.services.recommenders.factory import get_recommendation_engine

    with pytest.raises(RuntimeError, match="nope-engine"):
        get_recommendation_engine()
