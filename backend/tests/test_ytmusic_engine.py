import threading
import time

import pytest

from app.services.recommenders.base import SeedTrack
from app.services.recommenders.ytmusic_engine import YTMusicEngine


class FakeYTMusic:
    def __init__(self) -> None:
        # videoId -> get_watch_playlist response
        self.watch_responses: dict[str, dict] = {}
        # query -> search response list (keyed by (query, filter) when filter="artists")
        self.search_responses: dict[str, list[dict]] = {}
        self.artist_search_responses: dict[str, list[dict]] = {}
        # related browseId -> get_song_related shelves
        self.related_responses: dict[str, list] = {}
        # artist browseId -> get_artist response
        self.artist_responses: dict[str, dict] = {}
        self.get_watch_playlist_calls: list[str] = []
        self.search_calls: list[tuple[str, str | None, int]] = []
        self.related_calls: list[str] = []
        self.artist_calls: list[str] = []
        self.fail_watch_ids: set[str] = set()
        self.delay_s = 0.0
        self._lock = threading.Lock()
        self.in_flight = 0
        self.max_in_flight = 0

    def _enter(self) -> None:
        with self._lock:
            self.in_flight += 1
            self.max_in_flight = max(self.max_in_flight, self.in_flight)
        if self.delay_s:
            time.sleep(self.delay_s)

    def _exit(self) -> None:
        with self._lock:
            self.in_flight -= 1

    def get_watch_playlist(self, videoId: str, **kwargs: object) -> dict:
        self.get_watch_playlist_calls.append(videoId)
        self._enter()
        try:
            if videoId in self.fail_watch_ids:
                raise RuntimeError(f"watch failure for {videoId}")
            return self.watch_responses.get(videoId, {"tracks": []})
        finally:
            self._exit()

    def search(self, query: str, filter: str | None = None, limit: int = 20) -> list[dict]:
        self.search_calls.append((query, filter, limit))
        if filter == "artists":
            return self.artist_search_responses.get(query, [])
        return self.search_responses.get(query, [])

    def get_song_related(self, browseId: str) -> list:
        self.related_calls.append(browseId)
        return self.related_responses.get(browseId, [])

    def get_artist(self, channelId: str) -> dict:
        self.artist_calls.append(channelId)
        return self.artist_responses.get(channelId, {})


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
    # RX6: consensus score, rank-decayed within the seed's list.
    assert results[0].score == pytest.approx(1.0)
    assert results[1].score == pytest.approx(1 / 1.1)


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

    results = await engine.recommend([SeedTrack(title="Title X", artist="Artist X")], limit=20)

    assert yt.search_calls == [("Artist X Title X", "songs", 1)]
    assert yt.get_watch_playlist_calls == ["RESOLVED1"]
    assert [r.source_url for r in results] == ["https://music.youtube.com/watch?v=RECX"]


async def test_seed_without_url_no_search_match_skipped():
    yt = FakeYTMusic()
    # search returns empty for this query
    engine = YTMusicEngine(yt=yt)

    results = await engine.recommend([SeedTrack(title="Unknown", artist="Nobody")], limit=20)

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
        SeedTrack(title="t1", artist="a1", source_url="https://music.youtube.com/watch?v=S1"),
        SeedTrack(title="t2", artist="a2", source_url="https://music.youtube.com/watch?v=S2"),
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
    assert [r.source_url for r in results] == ["https://music.youtube.com/watch?v=REC_OK"]


async def test_search_failure_skips_seed_silently():
    yt = FakeYTMusic()

    def _boom(*a: object, **kw: object) -> list[dict]:
        raise RuntimeError("search down")

    yt.search = _boom  # type: ignore[method-assign]
    engine = YTMusicEngine(yt=yt)

    results = await engine.recommend([SeedTrack(title="x", artist="y")], limit=20)
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
    assert [r.source_url for r in results] == ["https://music.youtube.com/watch?v=KEEPER"]


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
    assert [r.source_url for r in results] == ["https://music.youtube.com/watch?v=RECY"]


# --- factory tests ----------------------------------------------------------


def test_factory_default_returns_ytmusic_engine(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.delenv("RECOMMENDATION_ENGINE", raising=False)
    from app.services.recommenders.factory import build_recommendation_engine

    engine = build_recommendation_engine()
    assert isinstance(engine, YTMusicEngine)


def test_factory_ytmusic_name_returns_ytmusic_engine(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "ytmusic")
    from app.services.recommenders.factory import build_recommendation_engine

    assert isinstance(build_recommendation_engine(), YTMusicEngine)


def test_factory_empty_value_raises(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "")
    from app.services.recommenders.factory import build_recommendation_engine

    with pytest.raises(RuntimeError, match="empty"):
        build_recommendation_engine()


def test_factory_unknown_name_raises(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("RECOMMENDATION_ENGINE", "nope-engine")
    from app.services.recommenders.factory import build_recommendation_engine

    with pytest.raises(RuntimeError, match="nope-engine"):
        build_recommendation_engine()


# --- RX6: concurrent multi-seed, related shelf, artist seeds, consensus ------


def _url(vid: str) -> str:
    return f"https://music.youtube.com/watch?v={vid}"


def _seed(vid: str, weight: float = 1.0) -> SeedTrack:
    return SeedTrack(title="t", artist="a", source_url=_url(vid), weight=weight)


def _vids(results) -> list[str]:
    return [r.source_url.rsplit("=", 1)[1] for r in results]


async def test_every_seed_contributes_even_when_first_fills_limit():
    # Pre-RX6 regression: seed 1's radio (25 tracks) filled limit=20 alone.
    yt = FakeYTMusic()
    for s in ("S1", "S2", "S3"):
        yt.watch_responses[s] = {
            "tracks": [_track(s, "seed", "x")]
            + [_track(f"{s}_{i}", f"T{i}", f"{s}-artist{i}") for i in range(25)]
        }
    engine = YTMusicEngine(yt=yt)

    results = await engine.recommend([_seed("S1"), _seed("S2"), _seed("S3")], limit=20)

    assert len(results) == 20
    assert {v.split("_")[0] for v in _vids(results)} == {"S1", "S2", "S3"}


async def test_consensus_track_outranks_single_seed_tracks():
    yt = FakeYTMusic()
    yt.watch_responses["S1"] = {
        "tracks": [_track("A1", "a1", "x"), _track("A2", "a2", "x"), _track("BOTH", "b", "y")]
    }
    yt.watch_responses["S2"] = {"tracks": [_track("B1", "b1", "z"), _track("BOTH", "b", "y")]}
    engine = YTMusicEngine(yt=yt)

    results = await engine.recommend([_seed("S1"), _seed("S2")], limit=20)

    assert _vids(results)[0] == "BOTH"
    assert results[0].score == pytest.approx(1 / 1.2 + 1 / 1.1)


async def test_higher_weight_seed_wins_at_same_rank():
    yt = FakeYTMusic()
    yt.watch_responses["LOW"] = {"tracks": [_track("FROM_LOW", "l", "x")]}
    yt.watch_responses["HIGH"] = {"tracks": [_track("FROM_HIGH", "h", "y")]}
    engine = YTMusicEngine(yt=yt)

    results = await engine.recommend([_seed("LOW", 0.4), _seed("HIGH", 1.0)], limit=20)

    assert _vids(results) == ["FROM_HIGH", "FROM_LOW"]
    assert results[1].score == pytest.approx(0.4)


async def test_seed_videos_never_recommended_even_via_other_seeds():
    yt = FakeYTMusic()
    yt.watch_responses["S1"] = {"tracks": [_track("S1", "s", "x"), _track("S2", "s2", "y")]}
    yt.watch_responses["S2"] = {"tracks": [_track("S2", "s2", "y"), _track("S1", "s", "x")]}
    engine = YTMusicEngine(yt=yt)

    assert await engine.recommend([_seed("S1"), _seed("S2")], limit=20) == []


async def test_related_shelf_you_might_also_like_only():
    yt = FakeYTMusic()
    yt.watch_responses["S1"] = {
        "tracks": [_track("S1", "seed", "x"), _track("RADIO", "r", "r")],
        "related": "MPTR1",
    }
    yt.related_responses["MPTR1"] = [
        {"title": "You might also like", "contents": [_track("LIKE", "l", "l")]},
        {"title": "Other performances", "contents": [_track("COVER", "seed cover", "c")]},
        {"title": "Similar artists", "contents": [{"title": "Artist", "browseId": "UC1"}]},
        {"title": "About the artist", "contents": "a string, not a list"},
    ]
    engine = YTMusicEngine(yt=yt)

    results = await engine.recommend([_seed("S1")], limit=20)

    assert yt.related_calls == ["MPTR1"]
    assert sorted(_vids(results)) == ["LIKE", "RADIO"]


async def test_related_and_radio_duplicate_counted_once_per_seed():
    yt = FakeYTMusic()
    yt.watch_responses["S1"] = {
        "tracks": [_track("S1", "seed", "x"), _track("DUP", "d", "d")],
        "related": "MPTR1",
    }
    yt.related_responses["MPTR1"] = [
        {"title": "You might also like", "contents": [_track("DUP", "d", "d")]}
    ]
    engine = YTMusicEngine(yt=yt)

    results = await engine.recommend([_seed("S1")], limit=20)

    assert _vids(results) == ["DUP"]
    assert results[0].score == pytest.approx(1.0)


async def test_missing_related_key_skips_get_song_related():
    yt = FakeYTMusic()
    yt.watch_responses["S1"] = {"tracks": [_track("R", "r", "r")]}
    engine = YTMusicEngine(yt=yt)

    await engine.recommend([_seed("S1")], limit=20)

    assert yt.related_calls == []


async def test_related_failure_keeps_radio():
    yt = FakeYTMusic()
    yt.watch_responses["S1"] = {"tracks": [_track("R", "r", "r")], "related": "MPTR1"}

    def _boom(browseId: str) -> list:
        raise RuntimeError("related down")

    yt.get_song_related = _boom  # type: ignore[method-assign]
    engine = YTMusicEngine(yt=yt)

    assert _vids(await engine.recommend([_seed("S1")], limit=20)) == ["R"]


async def test_artist_seed_uses_artist_top_songs():
    yt = FakeYTMusic()
    yt.artist_search_responses["Prateek Kuhad"] = [{"browseId": "UCPK", "artist": "Prateek Kuhad"}]
    yt.artist_responses["UCPK"] = {
        "songs": {
            "browseId": "VLx",
            "results": [_track("CO2", "Co2", "Prateek Kuhad"), _track("MUL", "Mulaqat", "PK")],
        }
    }
    engine = YTMusicEngine(yt=yt)

    results = await engine.recommend(
        [SeedTrack(title=None, artist="Prateek Kuhad", weight=0.7)], limit=20
    )

    assert yt.search_calls == [("Prateek Kuhad", "artists", 1)]
    assert yt.artist_calls == ["UCPK"]
    assert yt.get_watch_playlist_calls == []
    assert _vids(results) == ["CO2", "MUL"]
    assert results[0].score == pytest.approx(0.7)


async def test_artist_seed_unknown_artist_yields_nothing():
    yt = FakeYTMusic()
    engine = YTMusicEngine(yt=yt)

    assert await engine.recommend([SeedTrack(title=None, artist="Nobody")], limit=20) == []
    assert yt.artist_calls == []


async def test_artist_seed_failure_does_not_kill_song_seeds():
    yt = FakeYTMusic()
    yt.artist_search_responses["A"] = [{"browseId": "UCA"}]

    def _boom(channelId: str) -> dict:
        raise RuntimeError("artist down")

    yt.get_artist = _boom  # type: ignore[method-assign]
    yt.watch_responses["S1"] = {"tracks": [_track("R", "r", "r")]}
    engine = YTMusicEngine(yt=yt)

    results = await engine.recommend([SeedTrack(title=None, artist="A"), _seed("S1")], limit=20)

    assert _vids(results) == ["R"]


async def test_concurrency_capped_at_four():
    yt = FakeYTMusic()
    yt.delay_s = 0.02
    seeds = [_seed(f"S{i}") for i in range(10)]
    for i in range(10):
        yt.watch_responses[f"S{i}"] = {"tracks": [_track(f"R{i}", "r", f"a{i}")]}
    engine = YTMusicEngine(yt=yt)

    results = await engine.recommend(seeds, limit=20)

    assert len(results) == 10
    assert 1 < yt.max_in_flight <= 4
