"""MX3 — YouTube Music mood fetch + 24h cache behind `MixBuilder`.

The fake mirrors the shapes recorded live on 2026-11-07 (ytmusicapi 1.12.1):
categories = {section: [{title, params}]}, mood playlists = [{playlistId, title}],
playlist = {tracks: [{videoId, title, artists: [{name}]}]}.
"""

import threading
import time

import pytest

from app.services.recommenders.base import SeedTrack
from app.services.recommenders.mixes import (
    CANDIDATE_PLAYLISTS,
    VIBES,
    MixBuilder,
    MoodNotFound,
)


def _t(vid: str, artist: str) -> dict:
    return {"videoId": vid, "title": f"t-{vid}", "artists": [{"name": artist}]}


class FakeYT:
    def __init__(self, n_playlists: int = 30) -> None:
        self.categories = {
            "Moods & moments": [
                {"title": "Chill", "params": "P_CHILL"},
                {"title": "Party", "params": "P_PARTY"},
            ],
            "Genres": [{"title": "Hindi", "params": "P_HINDI"}],
        }
        self.mood_playlists = {
            "P_CHILL": [
                {"playlistId": f"pl{i}", "title": f"Chill {i}"} for i in range(n_playlists)
            ],
            "P_PARTY": [{"playlistId": "party0", "title": "Party 0"}],
        }
        # Every playlist: 3 stranger tracks; pl5 also carries the user's artist.
        self.tracks = {
            f"pl{i}": [_t(f"pl{i}-{j}", f"Stranger {i}-{j}") for j in range(3)]
            for i in range(n_playlists)
        }
        if "pl5" in self.tracks:
            self.tracks["pl5"] = [_t("fav-1", "Prateek Kuhad")] + self.tracks["pl5"]
        self.tracks["party0"] = [_t("party-1", "DJ")]
        self.fail: set[str] = set()
        self.calls = {"categories": 0, "moods": 0, "playlist": 0}
        self.playlist_ids: list[str] = []
        self.delay_s = 0.0
        self._lock = threading.Lock()
        self.in_flight = 0
        self.max_in_flight = 0

    def get_mood_categories(self) -> dict:
        self.calls["categories"] += 1
        return self.categories

    def get_mood_playlists(self, params: str) -> list:
        self.calls["moods"] += 1
        return self.mood_playlists.get(params, [])

    def get_playlist(self, playlistId: str, limit: int = 100) -> dict:
        with self._lock:
            self.calls["playlist"] += 1
            self.playlist_ids.append(playlistId)
            self.in_flight += 1
            self.max_in_flight = max(self.max_in_flight, self.in_flight)
        try:
            if self.delay_s:
                time.sleep(self.delay_s)
            if playlistId in self.fail:
                raise RuntimeError(f"boom {playlistId}")
            return {"tracks": self.tracks.get(playlistId, [])}
        finally:
            with self._lock:
                self.in_flight -= 1


class Clock:
    def __init__(self) -> None:
        self.t = 1000.0

    def __call__(self) -> float:
        return self.t


SEEDS = [SeedTrack(title="Co2", artist="Prateek Kuhad", weight=1.0)]


def test_vibes_are_the_planned_eight_in_order():
    assert [(v.id, v.title, v.mood) for v in VIBES] == [
        ("chill", "Chill Mix", "Chill"),
        ("feel-good", "Feel Good Mix", "Feel good"),
        ("party", "Party Mix", "Party"),
        ("romance", "Romance Mix", "Romance"),
        ("heartbreak", "Heartbreak Mix", "Sad"),
        ("workout", "Workout Mix", "Workout"),
        ("focus", "Focus Mix", "Focus"),
        ("sleep", "Sleep Mix", "Sleep"),
    ]


async def test_build_fetches_first_24_playlists_with_at_most_4_in_flight():
    yt = FakeYT(n_playlists=30)
    yt.delay_s = 0.02
    mix = await MixBuilder(yt=yt).build("chill", SEEDS, variant=0)

    assert sorted(yt.playlist_ids) == sorted(f"pl{i}" for i in range(CANDIDATE_PLAYLISTS))
    assert 1 < yt.max_in_flight <= 4
    assert (mix.vibe_id, mix.title) == ("chill", "Chill Mix")


async def test_build_personalizes_toward_the_users_artist():
    mix = await MixBuilder(yt=FakeYT()).build("chill", SEEDS, variant=0)
    assert mix.personalized is True
    assert mix.tracks[0].artist == "Prateek Kuhad"


async def test_no_overlap_is_unpersonalized_but_still_a_mix():
    seeds = [SeedTrack(title=None, artist="Nobody Known", weight=1.0)]
    mix = await MixBuilder(yt=FakeYT()).build("chill", seeds, variant=0)
    assert mix.personalized is False
    assert mix.tracks  # YTM's own top playlists


async def test_variant_changes_the_mix():
    builder = MixBuilder(yt=FakeYT())
    a = await builder.build("chill", SEEDS, variant=0)
    b = await builder.build("chill", SEEDS, variant=1)
    assert {t.source_url for t in a.tracks} != {t.source_url for t in b.tracks}


async def test_missing_mood_raises_mood_not_found():
    # "heartbreak" maps to YTM "Sad", which this fake catalogue doesn't have.
    with pytest.raises(MoodNotFound):
        await MixBuilder(yt=FakeYT()).build("heartbreak", SEEDS, variant=0)


async def test_unknown_vibe_raises_key_error():
    with pytest.raises(KeyError):
        await MixBuilder(yt=FakeYT()).build("polka", SEEDS, variant=0)


async def test_failing_playlist_is_skipped():
    yt = FakeYT()
    yt.fail = {"pl5"}  # the one with the user's artist
    mix = await MixBuilder(yt=yt).build("chill", SEEDS, variant=0)
    assert all(t.artist != "Prateek Kuhad" for t in mix.tracks)
    assert mix.tracks


async def test_playlists_without_an_id_are_skipped():
    yt = FakeYT(n_playlists=2)
    yt.mood_playlists["P_CHILL"].insert(0, {"title": "no id"})
    await MixBuilder(yt=yt).build("chill", SEEDS, variant=0)
    assert sorted(yt.playlist_ids) == ["pl0", "pl1"]


async def test_second_build_within_ttl_makes_no_ytm_calls():
    yt = FakeYT()
    clock = Clock()
    builder = MixBuilder(yt=yt, now=clock)
    await builder.build("chill", SEEDS, variant=0)
    before = dict(yt.calls)

    clock.t += 23 * 3600
    await builder.build("chill", SEEDS, variant=1)  # other variant: still cached
    assert yt.calls == before


async def test_expired_cache_refetches():
    yt = FakeYT()
    clock = Clock()
    builder = MixBuilder(yt=yt, now=clock)
    await builder.build("chill", SEEDS, variant=0)
    first = dict(yt.calls)

    clock.t += 24 * 3600 + 1
    await builder.build("chill", SEEDS, variant=0)
    assert yt.calls["categories"] == first["categories"] + 1
    assert yt.calls["moods"] == first["moods"] + 1
    assert yt.calls["playlist"] == first["playlist"] * 2


async def test_failed_playlist_is_not_cached():
    yt = FakeYT()
    yt.fail = {"pl5"}
    builder = MixBuilder(yt=yt)
    await builder.build("chill", SEEDS, variant=0)
    yt.fail = set()
    mix = await builder.build("chill", SEEDS, variant=0)
    assert mix.tracks[0].artist == "Prateek Kuhad"  # pl5 retried and used
