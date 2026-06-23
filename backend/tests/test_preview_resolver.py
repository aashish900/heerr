"""K1: yt-dlp preview resolver service.

The extractor is injected, so these tests never touch the network or import yt-dlp.
"""

import pytest

from app.services.preview_resolver import (
    PreviewResolveError,
    PreviewUnavailable,
    PreviewUnsupported,
    ResolvedPreview,
    resolve_preview,
)

_WATCH = "https://music.youtube.com/watch?v=abc123"


def _info_single(url: str = "https://rr1.googlevideo.com/videoplayback?x=1") -> dict:
    """yt-dlp info shape when a single format is selected (top-level url)."""
    return {
        "id": "abc123",
        "url": url,
        "ext": "webm",
        "acodec": "opus",
        "vcodec": "none",
        "protocol": "https",
        "abr": 128.0,
        "http_headers": {"User-Agent": "ytdlp/1", "Accept": "*/*"},
    }


def _info_requested(url: str = "https://rr2.googlevideo.com/videoplayback?x=2") -> dict:
    """yt-dlp info shape using requested_formats (the common bestaudio case)."""
    return {
        "id": "abc123",
        "requested_formats": [
            {
                "url": url,
                "ext": "m4a",
                "acodec": "mp4a.40.2",
                "vcodec": "none",
                "protocol": "https",
                "abr": 160.0,
                "http_headers": {"User-Agent": "ytdlp/1"},
            }
        ],
    }


async def test_resolves_single_format_with_headers_and_content_type():
    cache: dict[str, ResolvedPreview] = {}
    got = await resolve_preview(
        _WATCH,
        extractor=lambda url: _info_single(),
        now=lambda: 1000.0,
        ttl_seconds=300.0,
        cache=cache,
    )
    assert got.video_id == "abc123"
    assert got.stream_url == "https://rr1.googlevideo.com/videoplayback?x=1"
    assert got.headers == {"User-Agent": "ytdlp/1", "Accept": "*/*"}
    assert got.content_type == "audio/webm"
    assert got.expires_at == 1300.0
    assert cache["abc123"] is got


async def test_resolves_requested_formats_shape():
    got = await resolve_preview(_WATCH, extractor=lambda url: _info_requested(), cache={})
    assert got.stream_url == "https://rr2.googlevideo.com/videoplayback?x=2"
    assert got.content_type == "audio/mp4"


async def test_canonicalises_url_to_music_watch_before_extracting():
    seen: dict[str, str] = {}

    def _extract(url: str) -> dict:
        seen["url"] = url
        return _info_single()

    # A youtu.be short link should still extract via the canonical music URL.
    await resolve_preview("https://youtu.be/abc123", extractor=_extract, cache={})
    assert seen["url"] == "https://music.youtube.com/watch?v=abc123"


async def test_cache_hit_avoids_second_extraction():
    calls = {"n": 0}

    def _extract(url: str) -> dict:
        calls["n"] += 1
        return _info_single()

    cache: dict[str, ResolvedPreview] = {}
    first = await resolve_preview(_WATCH, extractor=_extract, now=lambda: 0.0, cache=cache)
    second = await resolve_preview(_WATCH, extractor=_extract, now=lambda: 10.0, cache=cache)
    assert first is second
    assert calls["n"] == 1


async def test_cache_expiry_triggers_re_extraction():
    calls = {"n": 0}

    def _extract(url: str) -> dict:
        calls["n"] += 1
        return _info_single(f"https://rr.googlevideo.com/v?n={calls['n']}")

    clock = {"t": 0.0}
    cache: dict[str, ResolvedPreview] = {}
    await resolve_preview(
        _WATCH, extractor=_extract, now=lambda: clock["t"], ttl_seconds=300.0, cache=cache
    )
    clock["t"] = 301.0  # past TTL
    again = await resolve_preview(
        _WATCH, extractor=_extract, now=lambda: clock["t"], ttl_seconds=300.0, cache=cache
    )
    assert calls["n"] == 2
    assert again.stream_url.endswith("n=2")


@pytest.mark.parametrize(
    "url",
    [
        "https://music.youtube.com/browse/MPREb_abc",  # album/playlist
        "https://music.youtube.com/playlist?list=PL123",
        "https://example.com/watch?v=abc123",  # not a youtube host
        "https://music.youtube.com/watch",  # no v param
    ],
)
async def test_unsupported_urls_raise(url: str):
    with pytest.raises(PreviewUnsupported):
        await resolve_preview(url, extractor=lambda u: _info_single(), cache={})


async def test_extractor_unavailable_message_maps_to_unavailable():
    def _extract(url: str) -> dict:
        raise RuntimeError("ERROR: Video unavailable. This video is private.")

    with pytest.raises(PreviewUnavailable):
        await resolve_preview(_WATCH, extractor=_extract, cache={})


async def test_extractor_generic_error_maps_to_resolve_error():
    def _extract(url: str) -> dict:
        raise RuntimeError("connection reset by peer")

    with pytest.raises(PreviewResolveError):
        await resolve_preview(_WATCH, extractor=_extract, cache={})


async def test_no_direct_audio_format_raises_resolve_error():
    def _extract(url: str) -> dict:
        # Only an HLS manifest stream — not directly proxyable.
        return {
            "id": "abc123",
            "formats": [
                {
                    "url": "https://x/playlist.m3u8",
                    "acodec": "opus",
                    "vcodec": "none",
                    "protocol": "m3u8_native",
                }
            ],
        }

    with pytest.raises(PreviewResolveError):
        await resolve_preview(_WATCH, extractor=_extract, cache={})


async def test_empty_info_raises_unavailable():
    with pytest.raises(PreviewUnavailable):
        await resolve_preview(_WATCH, extractor=lambda u: None, cache={})  # type: ignore[arg-type,return-value]
