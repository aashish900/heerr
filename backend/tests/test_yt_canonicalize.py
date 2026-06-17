"""N14: canonicalize_yt_url strips query params that break spotdl."""

import pytest

from app.services.spotdl_runner import canonicalize_yt_url


@pytest.mark.parametrize(
    "raw, expected",
    [
        (
            "https://music.youtube.com/watch?v=abc123&list=RDabc&index=2",
            "https://music.youtube.com/watch?v=abc123",
        ),
        (
            "https://www.youtube.com/watch?v=xyz&pp=ygUE&feature=share",
            "https://www.youtube.com/watch?v=xyz",
        ),
        (
            "https://music.youtube.com/watch?v=abc#fragment",
            "https://music.youtube.com/watch?v=abc",
        ),
        (
            "https://music.youtube.com/watch?v=abc",
            "https://music.youtube.com/watch?v=abc",
        ),
    ],
)
def test_strips_non_essential_params(raw, expected):
    assert canonicalize_yt_url(raw) == expected


def test_non_yt_url_passes_through():
    url = "https://example.com/song?list=42&v=skip"
    assert canonicalize_yt_url(url) == url
