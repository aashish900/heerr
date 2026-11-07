from app.services.recommenders.base import RecommendedTrack
from app.services.recommenders.rerank import rerank


def _t(vid: str, artist: str = "A", score: float | None = 1.0) -> RecommendedTrack:
    return RecommendedTrack(
        title=f"t-{vid}",
        artist=artist,
        source_url=f"https://music.youtube.com/watch?v={vid}",
        score=score,
    )


def _urls(tracks: list[RecommendedTrack]) -> list[str]:
    return [t.source_url.rsplit("=", 1)[1] for t in tracks]


def _go(cands, *, excluded=(), shown=(), limit=20, per_artist=2):
    url = "https://music.youtube.com/watch?v={}".format
    return rerank(
        cands,
        excluded={url(v) for v in excluded},
        recently_shown={url(v) for v in shown},
        limit=limit,
        per_artist=per_artist,
    )


def test_empty_input():
    assert _go([]) == []


def test_sorts_by_score_desc():
    out = _go([_t("a", "X", 0.1), _t("b", "Y", 0.9), _t("c", "Z", 0.5)])
    assert _urls(out) == ["b", "c", "a"]


def test_excluded_urls_dropped():
    out = _go([_t("a", "X"), _t("b", "Y")], excluded=["a"])
    assert _urls(out) == ["b"]


def test_recently_shown_demoted_below_equal_unshown():
    out = _go([_t("a", "X", 1.0), _t("b", "Y", 1.0)], shown=["a"])
    assert _urls(out) == ["b", "a"]


def test_recently_shown_not_excluded():
    out = _go([_t("a", "X", 1.0)], shown=["a"])
    assert _urls(out) == ["a"]


def test_artist_cap_case_insensitive():
    out = _go(
        [
            _t("a", "Adele", 0.9),
            _t("b", "ADELE", 0.8),
            _t("c", " adele ", 0.7),
            _t("d", "Other", 0.1),
        ]
    )
    assert _urls(out) == ["a", "b", "d"]


def test_capped_at_limit():
    out = _go([_t(str(i), f"artist{i}") for i in range(10)], limit=3)
    assert len(out) == 3


def test_missing_scores_keep_input_order():
    out = _go([_t("a", "X", None), _t("b", "Y", None), _t("c", "Z", None)])
    assert _urls(out) == ["a", "b", "c"]


def test_missing_score_demoted_when_shown():
    out = _go([_t("a", "X", None), _t("b", "Y", None)], shown=["a"])
    assert _urls(out) == ["b", "a"]


def test_output_scores_reflect_demotion():
    out = _go([_t("a", "X", 1.0)], shown=["a"])
    assert out[0].score == 0.3
