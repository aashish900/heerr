import pytest

from app.services.recommenders.base import RecommendedTrack
from app.services.recommenders.rerank import is_alt_version, rerank


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


def test_duplicate_urls_kept_once():
    out = _go([_t("a", "X", 0.5), _t("a", "X", 0.9), _t("b", "Y", 0.1)])
    assert _urls(out) == ["a", "b"]
    assert out[0].score == 0.9


# --- RX7a: drop covers / alternate versions -------------------------------


@pytest.mark.parametrize(
    "title",
    [
        # Seen in the RX7 server smoke.
        "I Think They Call This Love (Cover)",
        "The Man Who Sold The World (Live)",
        "Kasoor (Acoustic)",
        "Until I Found You (Em Beihold Version)",
        # Seen in the RX4 related-shelf probe.
        "Radiohead - High & Dry (Live Cover)",
        "Teri Meri x Tum Hi Ho x Sanam Re | Bollywood Love Mashup \u2013 IndiTune",
        # Other common shapes.
        "Tum Hi Ho [Slowed + Reverb]",
        "Kesariya - Lofi Flip",
        "Blinding Lights (Remix)",
        "Creep - Acoustic Version",
        "Creep \u2013 Live at Glastonbury",  # en-dash qualifier
        "Song Title (Instrumental)",
        "Channa Mereya (Unplugged)",
        "Some Song (Sped Up)",
    ],
)
def test_alt_versions_detected(title):
    assert is_alt_version(title)


@pytest.mark.parametrize(
    "title",
    [
        "Live Forever",
        "Live While We're Young",
        "Cover Me Up",
        'Hua Hain Aaj Pehli Baar (From "Sanam Re") (feat. Armaan Malik & Palak Muchhal)',
        "Saiyaara (Movie: Saiyaara)",
        "Yellow",
        "Yeh Mausam Ki Baarish - Trending",
        'Gehra Hua (From "Dhurandhar")',
    ],
)
def test_originals_kept(title):
    assert not is_alt_version(title)


def test_rerank_drops_alt_versions():
    cands = [
        RecommendedTrack(title="Kasoor (Acoustic)", artist="X", source_url="u1", score=0.9),
        RecommendedTrack(title="Kasoor", artist="Y", source_url="u2", score=0.5),
    ]
    out = rerank(cands, excluded=set(), recently_shown=set(), limit=20)
    assert [t.source_url for t in out] == ["u2"]
