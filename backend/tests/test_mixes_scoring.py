"""MX2 — pure mix scoring: taste profile, playlist affinity, pick, track score."""

import pytest

from app.services.recommenders.base import SeedTrack
from app.services.recommenders.mixes import (
    PICK,
    POOL,
    pick_playlists,
    playlist_affinity,
    score_tracks,
    taste_profile,
)


def _t(vid: str, *artists: str, title: str | None = None) -> dict:
    return {"videoId": vid, "title": title or f"t-{vid}", "artists": [{"name": a} for a in artists]}


# --- taste_profile ---------------------------------------------------------


def test_taste_profile_lowercases_trims_and_keeps_max_weight():
    taste = taste_profile(
        [
            SeedTrack(title="Co2", artist=" Prateek Kuhad ", weight=1.0),
            SeedTrack(title=None, artist="prateek kuhad", weight=0.7),
            SeedTrack(title=None, artist="The Local Train", weight=0.4),
            SeedTrack(title="X", artist="THE LOCAL TRAIN", weight=0.7),
        ]
    )
    assert taste == {"prateek kuhad": 1.0, "the local train": 0.7}


def test_taste_profile_empty():
    assert taste_profile([]) == {}


# --- playlist_affinity -----------------------------------------------------


def test_affinity_is_weighted_share_matching_any_listed_artist():
    taste = {"arijit singh": 1.0, "anuv jain": 0.5}
    tracks = [
        _t("a", "Shashwat Sachdev", "Arijit Singh"),  # second artist matches → 1.0
        _t("b", "Anuv Jain"),  # 0.5
        _t("c", "Someone Else"),  # 0
        _t("d", "Another"),  # 0
    ]
    assert playlist_affinity(tracks, taste) == pytest.approx((1.0 + 0.5) / 4)


def test_affinity_takes_best_artist_per_track_once():
    taste = {"a": 0.4, "b": 1.0}
    assert playlist_affinity([_t("x", "A", "B")], taste) == pytest.approx(1.0)


def test_affinity_of_empty_playlist_is_zero():
    assert playlist_affinity([], {"a": 1.0}) == 0.0


def test_affinity_ignores_malformed_items():
    taste = {"a": 1.0}
    tracks = [_t("x", "A"), {"title": "no vid", "artists": [{"name": "A"}]}, "junk"]
    assert playlist_affinity(tracks, taste) == pytest.approx(1.0)


# --- pick_playlists --------------------------------------------------------


def _playlists(affinities: list[float]) -> list[tuple[str, float]]:
    return [(f"p{i}", a) for i, a in enumerate(affinities)]


def test_pick_takes_top_pool_by_affinity_then_rotates_pick_by_variant():
    assert (POOL, PICK) == (8, 4)
    # 10 playlists; affinities make p9..p2 the top 8 (p1/p0 lowest).
    scored = _playlists([0.01, 0.02, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8])
    v0, personalized = pick_playlists(scored, variant=0)
    v1, _ = pick_playlists(scored, variant=1)
    v2, _ = pick_playlists(scored, variant=2)

    assert personalized is True
    assert [p for p, _ in v0] == ["p9", "p8", "p7", "p6"]
    assert [p for p, _ in v1] == ["p5", "p4", "p3", "p2"]
    assert v2 == v0  # wraps around the pool of 8


def test_pick_ties_keep_ytm_order():
    scored = _playlists([0.5, 0.5, 0.5, 0.5, 0.5])
    chosen, _ = pick_playlists(scored, variant=0)
    assert [p for p, _ in chosen] == ["p0", "p1", "p2", "p3"]


def test_pick_with_no_overlap_falls_back_to_ytm_order_unpersonalized():
    scored = _playlists([0.0] * 10)
    chosen, personalized = pick_playlists(scored, variant=0)
    assert personalized is False
    assert [p for p, _ in chosen] == ["p0", "p1", "p2", "p3"]


def test_pick_with_fewer_playlists_than_pick():
    chosen, _ = pick_playlists(_playlists([0.3, 0.1]), variant=0)
    assert [p for p, _ in chosen] == ["p0", "p1"]
    again, _ = pick_playlists(_playlists([0.3, 0.1]), variant=1)
    assert sorted(p for p, _ in again) == ["p0", "p1"]  # no duplicates


def test_pick_with_no_playlists():
    assert pick_playlists([], variant=0) == ([], False)


# --- score_tracks ----------------------------------------------------------


def _ids(tracks) -> list[str]:
    return [t.source_url.rsplit("=", 1)[1] for t in tracks]


def test_score_decays_with_position_and_scales_with_affinity():
    chosen = [(0.0, [_t("a", "X"), _t("b", "Y")])]
    out = score_tracks(chosen, taste={})
    assert _ids(out) == ["a", "b"]
    assert out[0].score == pytest.approx(0.5)
    assert out[1].score == pytest.approx(0.5 / 1.02)

    richer = score_tracks([(0.5, [_t("a", "X")])], taste={})
    assert richer[0].score == pytest.approx(1.0)


def test_taste_bonus_added_once_even_across_playlists():
    taste = {"anuv jain": 0.7}
    chosen = [(0.0, [_t("a", "Anuv Jain")]), (0.0, [_t("a", "Anuv Jain")])]
    out = score_tracks(chosen, taste)
    assert out[0].score == pytest.approx(0.5 + 0.5 + 0.7)


def test_track_in_several_playlists_outranks_single_listing():
    chosen = [
        (0.0, [_t("solo", "X"), _t("both", "Y")]),
        (0.0, [_t("both", "Y")]),
    ]
    assert _ids(score_tracks(chosen, taste={}))[0] == "both"


def test_taste_artist_outranks_stranger_at_same_position():
    chosen = [(0.0, [_t("stranger", "Nobody")]), (0.0, [_t("fav", "Prateek Kuhad")])]
    out = score_tracks(chosen, taste={"prateek kuhad": 1.0})
    assert _ids(out) == ["fav", "stranger"]


def test_output_shape_and_malformed_items_skipped():
    chosen = [
        (
            0.0,
            [
                _t("ok", "Lord Huron", title="Your Other Life"),
                {"videoId": "noartist", "title": "T", "artists": []},
                {"videoId": "notitle", "title": "", "artists": [{"name": "A"}]},
                {"title": "novid", "artists": [{"name": "A"}]},
            ],
        )
    ]
    out = score_tracks(chosen, taste={})
    assert len(out) == 1
    t = out[0]
    assert (t.title, t.artist) == ("Your Other Life", "Lord Huron")
    assert t.source_url == "https://music.youtube.com/watch?v=ok"
