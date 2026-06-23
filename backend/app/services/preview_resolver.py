"""K1: Resolve a YouTube Music watch URL to a streamable audio URL via yt-dlp.

For the stream-first preview feature: given a ``music.youtube.com/watch?v=<id>``
URL, use yt-dlp to extract the best *audio-only* format's direct ``googlevideo``
URL plus the HTTP headers yt-dlp wants attached to the media request. The result
is handed to ``GET /preview/stream`` (K2), which proxies the bytes to the device
over Tailscale. Nothing is persisted — previews are ephemeral.

Why resolve server-side rather than hand the device a bare ``yt-dlp -g`` URL:
``googlevideo`` URLs are signed to the *resolver's* egress IP, so the phone (a
different IP) would 403. Proxying means the backend is the only thing that ever
talks to ``googlevideo``, and the device stays on the tailnet.

Typed errors (caller maps to HTTP status in K2):
- ``PreviewUnsupported``  — not a previewable watch URL (album/playlist/browse) → 422
- ``PreviewUnavailable``  — video gone / private / region-locked / age-gated   → 404
- ``PreviewResolveError`` — any other extraction failure                       → 502
"""

from __future__ import annotations

import asyncio
import logging
import time
from collections.abc import Callable
from dataclasses import dataclass
from urllib.parse import parse_qs, urlparse

logger = logging.getLogger(__name__)

_DEFAULT_TTL_SECONDS = 300.0
_WATCH_HOSTS = {"music.youtube.com", "www.youtube.com", "youtube.com", "m.youtube.com"}
_DIRECT_PROTOCOLS = {"https", "http"}

# Map yt-dlp container ext -> a sensible Content-Type. Advisory only: the K2 proxy
# prefers the upstream googlevideo Content-Type and falls back to this.
_EXT_CONTENT_TYPE = {
    "webm": "audio/webm",
    "m4a": "audio/mp4",
    "mp4": "audio/mp4",
    "mp3": "audio/mpeg",
    "opus": "audio/ogg",
    "ogg": "audio/ogg",
}

# Substrings in a yt-dlp error that mean "this specific video can't be served"
# (a 404 to the client), as opposed to a transient/internal failure (a 502).
_UNAVAILABLE_MARKERS = (
    "unavailable",
    "private",
    "removed",
    "not available",
    "no longer available",
    "region",
    "geo",
    "age",
    "sign in to confirm",
)


class PreviewError(Exception):
    """Base class for preview-resolution failures."""


class PreviewUnsupported(PreviewError):
    """The source URL is not a previewable watch URL (e.g. an album/playlist)."""


class PreviewUnavailable(PreviewError):
    """The video exists in the URL but cannot be served (gone/region/age-gated)."""


class PreviewResolveError(PreviewError):
    """Extraction failed for a transient or unexpected reason."""


@dataclass(frozen=True)
class ResolvedPreview:
    video_id: str
    stream_url: str
    headers: dict[str, str]
    content_type: str | None
    expires_at: float  # epoch seconds — used for the cache and caller staleness


# Injection seam: tests pass a fake; production uses the lazy yt-dlp default.
_Extractor = Callable[[str], dict]

# Process-wide cache keyed by videoId. Tests inject their own dict to stay isolated.
_CACHE: dict[str, ResolvedPreview] = {}


def _extract_video_id(source_url: str) -> str:
    """Return the YouTube video id, or raise ``PreviewUnsupported``.

    Accepts ``/watch?v=<id>`` on any YouTube host and ``youtu.be/<id>``. Rejects
    ``/browse/<id>`` (albums/playlists) and anything else.
    """
    try:
        parsed = urlparse(source_url)
    except ValueError as exc:
        raise PreviewUnsupported(f"unparseable url: {source_url!r}") from exc

    host = (parsed.hostname or "").lower()
    if parsed.path == "/watch" and host in _WATCH_HOSTS:
        vid = parse_qs(parsed.query).get("v", [""])[0]
        if vid:
            return vid
    if host == "youtu.be":
        vid = parsed.path.lstrip("/")
        if vid:
            return vid
    raise PreviewUnsupported(f"not a previewable watch url: {source_url!r}")


def _select_audio(info: dict | None) -> dict:
    """Pick the best audio-only, directly-streamable format dict from yt-dlp info."""
    if not info:
        raise PreviewUnavailable("extractor returned no info")

    requested = info.get("requested_formats")
    if requested:
        fmt = requested[0]
    elif info.get("url"):
        fmt = info
    else:
        candidates = [
            f
            for f in (info.get("formats") or [])
            if f.get("acodec") not in (None, "none")
            and f.get("vcodec") in (None, "none")
            and f.get("url")
            and f.get("protocol") in _DIRECT_PROTOCOLS
        ]
        if not candidates:
            raise PreviewResolveError("no direct audio-only format available")
        fmt = max(candidates, key=lambda f: f.get("abr") or 0.0)

    if not fmt.get("url") or fmt.get("protocol") not in _DIRECT_PROTOCOLS:
        raise PreviewResolveError("selected format is not a direct http(s) stream")
    return fmt


def _ytdlp_extract(url: str) -> dict:
    """Default extractor — lazy-imports yt-dlp so tests need not install it."""
    import yt_dlp

    opts = {
        "format": "bestaudio/best",
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "noplaylist": True,
    }
    with yt_dlp.YoutubeDL(opts) as ydl:
        return ydl.extract_info(url, download=False)


async def resolve_preview(
    source_url: str,
    *,
    extractor: _Extractor = _ytdlp_extract,
    ttl_seconds: float = _DEFAULT_TTL_SECONDS,
    now: Callable[[], float] = time.time,
    cache: dict[str, ResolvedPreview] | None = None,
) -> ResolvedPreview:
    """Resolve a watch URL to a ``ResolvedPreview``.

    `extractor`, `now`, and `cache` are injection seams for tests. A fresh result
    is cached per ``videoId`` for `ttl_seconds`; repeated previews / client retries
    within the window reuse it and skip re-extraction.
    """
    video_id = _extract_video_id(source_url)
    store = _CACHE if cache is None else cache

    cached = store.get(video_id)
    if cached is not None and cached.expires_at > now():
        return cached

    canonical = f"https://music.youtube.com/watch?v={video_id}"
    try:
        info = await asyncio.to_thread(extractor, canonical)
    except PreviewError:
        raise
    except Exception as exc:
        message = str(exc)
        lowered = message.lower()
        if any(marker in lowered for marker in _UNAVAILABLE_MARKERS):
            logger.info("preview unavailable for %s: %s", video_id, message)
            raise PreviewUnavailable(message) from exc
        logger.warning("preview resolve failed for %s: %s", video_id, message)
        raise PreviewResolveError(message) from exc

    fmt = _select_audio(info)
    headers = {str(k): str(v) for k, v in (fmt.get("http_headers") or {}).items()}
    ext = str(fmt.get("ext") or "").lower()
    resolved = ResolvedPreview(
        video_id=video_id,
        stream_url=str(fmt["url"]),
        headers=headers,
        content_type=_EXT_CONTENT_TYPE.get(ext),
        expires_at=now() + ttl_seconds,
    )
    store[video_id] = resolved
    return resolved
