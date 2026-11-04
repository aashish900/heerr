"""K2: GET /preview/stream — proxy a YouTube Music track's audio to the device.

Resolves the watch URL to a direct googlevideo audio URL (K1), then proxies the
bytes to the client over Tailscale. The backend is the only thing that talks to
googlevideo (its URLs are egress-IP-bound), and the device never leaves the tailnet.

- googlevideo 403s any fetch without a *bounded* Range (open-ended `bytes=N-` and
  no Range both fail, `bytes=N-M` works), so the client's Range is translated into
  bounded `_CHUNK`-sized upstream fetches stitched into one response. Seeks still work.
- googlevideo 302-redirects to a CDN node, so the upstream client follows redirects.
- Auth rides in `?token=` because the audio player can't set headers (K3 redacts it).
- Nothing is persisted — previews are ephemeral.
"""

from __future__ import annotations

import re
from collections.abc import AsyncIterator, Awaitable, Callable

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import StreamingResponse

from app.api.deps import require_scope_query_or_header
from app.config import Settings, get_settings
from app.models import Token
from app.services.preview_resolver import (
    PreviewResolveError,
    PreviewUnavailable,
    PreviewUnsupported,
    ResolvedPreview,
    resolve_preview,
)

router = APIRouter(tags=["preview"])

# Connect/write are bounded; read is unbounded — an audio stream legitimately
# trickles for the length of the track.
_UPSTREAM_TIMEOUT = httpx.Timeout(connect=10.0, read=None, write=10.0, pool=10.0)
_STREAMABLE_STATUS = {status.HTTP_200_OK, status.HTTP_206_PARTIAL_CONTENT}
# Upstream fetch size; yt-dlp itself chunks googlevideo at 10 MiB.
_CHUNK = 4 * 1024 * 1024
_RANGE_RE = re.compile(r"bytes=(\d+)-(\d*)$")

PreviewResolver = Callable[[str], Awaitable[ResolvedPreview]]


def get_preview_resolver(settings: Settings = Depends(get_settings)) -> PreviewResolver:
    """DI seam: the resolver callable (tests override with a fake).

    Binds the cache TTL from config so a deploy can tune re-resolution cadence.
    """

    async def _resolve(source_url: str) -> ResolvedPreview:
        return await resolve_preview(source_url, ttl_seconds=settings.preview_cache_ttl_s)

    return _resolve


def preview_enabled_flag(settings: Settings = Depends(get_settings)) -> bool:
    """DI seam for the kill switch (tests override to force-disable)."""
    return settings.preview_enabled


async def get_preview_http_client() -> AsyncIterator[httpx.AsyncClient]:
    """DI seam: a redirect-following httpx client (tests override with MockTransport).

    Yielded (not returned) so FastAPI closes it after the StreamingResponse body
    has finished streaming.
    """
    async with httpx.AsyncClient(follow_redirects=True, timeout=_UPSTREAM_TIMEOUT) as client:
        yield client


async def _open_chunk(
    client: httpx.AsyncClient, resolved: ResolvedPreview, start: int, end: int
) -> httpx.Response:
    """Open a streamed, bounded-Range upstream fetch; map failures to 502."""
    headers = {**resolved.headers, "Range": f"bytes={start}-{end}"}
    req = client.build_request("GET", resolved.stream_url, headers=headers)
    try:
        upstream = await client.send(req, stream=True)
    except httpx.HTTPError as exc:
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY, detail=f"upstream fetch failed: {exc}"
        ) from exc
    if upstream.status_code != status.HTTP_206_PARTIAL_CONTENT:
        code = upstream.status_code
        await upstream.aclose()
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, detail=f"upstream returned {code}")
    return upstream


@router.get("/preview/stream")
async def preview_stream(
    request: Request,
    source_url: str = Query(..., description="A music.youtube.com/watch?v=<id> URL"),
    _tok: Token = Depends(require_scope_query_or_header("read")),
    enabled: bool = Depends(preview_enabled_flag),
    resolver: PreviewResolver = Depends(get_preview_resolver),
    client: httpx.AsyncClient = Depends(get_preview_http_client),
) -> StreamingResponse:
    if not enabled:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="preview is disabled")
    try:
        resolved = await resolver(source_url)
    except PreviewUnsupported as exc:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)) from exc
    except PreviewUnavailable as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except PreviewResolveError as exc:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    m = _RANGE_RE.match(request.headers.get("range", ""))
    start = int(m[1]) if m else 0
    want_end = int(m[2]) if m and m[2] else None

    first = await _open_chunk(
        client,
        resolved,
        start,
        start + _CHUNK - 1 if want_end is None else min(want_end, start + _CHUNK - 1),
    )
    try:
        total = int(first.headers["content-range"].rsplit("/", 1)[1])
    except (KeyError, ValueError) as exc:
        await first.aclose()
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY, detail="upstream gave no total size"
        ) from exc
    if start >= total:
        await first.aclose()
        raise HTTPException(status.HTTP_416_RANGE_NOT_SATISFIABLE, detail="range past end")
    end = total - 1 if want_end is None else min(want_end, total - 1)

    async def _body() -> AsyncIterator[bytes]:
        up, pos = first, start
        while True:
            try:
                # In production `stream=True` leaves the stream unread → iterate it.
                # A buffered upstream (already-read body) is yielded whole.
                if up.is_stream_consumed:
                    yield up.content
                else:
                    async for chunk in up.aiter_raw():
                        yield chunk
            finally:
                await up.aclose()
            pos += _CHUNK
            if pos > end:
                return
            up = await _open_chunk(client, resolved, pos, min(pos + _CHUNK - 1, end))

    out_headers = {"accept-ranges": "bytes", "content-length": str(end - start + 1)}
    if m:
        out_headers["content-range"] = f"bytes {start}-{end}/{total}"
    return StreamingResponse(
        _body(),
        status_code=206 if m else 200,
        headers=out_headers,
        media_type=first.headers.get("content-type") or resolved.content_type,
    )
