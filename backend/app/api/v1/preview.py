"""K2: GET /preview/stream — proxy a YouTube Music track's audio to the device.

Resolves the watch URL to a direct googlevideo audio URL (K1), then proxies the
bytes to the client over Tailscale. The backend is the only thing that talks to
googlevideo (its URLs are egress-IP-bound), and the device never leaves the tailnet.

- Range is forwarded both ways so ExoPlayer can seek (googlevideo answers 206).
- googlevideo 302-redirects to a CDN node, so the upstream client follows redirects.
- Auth rides in `?token=` because the audio player can't set headers (K3 redacts it).
- Nothing is persisted — previews are ephemeral.
"""

from __future__ import annotations

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
# Upstream response headers worth forwarding verbatim to the client.
_PASSTHROUGH_HEADERS = ("content-length", "content-range", "accept-ranges")

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

    upstream_headers = dict(resolved.headers)
    client_range = request.headers.get("range")
    if client_range:
        upstream_headers["Range"] = client_range

    upstream_req = client.build_request("GET", resolved.stream_url, headers=upstream_headers)
    try:
        upstream = await client.send(upstream_req, stream=True)
    except httpx.HTTPError as exc:
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY, detail=f"upstream fetch failed: {exc}"
        ) from exc

    if upstream.status_code not in _STREAMABLE_STATUS:
        code = upstream.status_code
        await upstream.aclose()
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            detail=f"upstream returned {code}",
        )

    async def _body() -> AsyncIterator[bytes]:
        try:
            # In production `stream=True` leaves the stream unread → iterate it.
            # A buffered upstream (already-read body) is yielded whole.
            if upstream.is_stream_consumed:
                yield upstream.content
            else:
                async for chunk in upstream.aiter_raw():
                    yield chunk
        finally:
            await upstream.aclose()

    out_headers = {k: upstream.headers[k] for k in _PASSTHROUGH_HEADERS if k in upstream.headers}
    media_type = upstream.headers.get("content-type") or resolved.content_type

    return StreamingResponse(
        _body(),
        status_code=upstream.status_code,
        headers=out_headers,
        media_type=media_type,
    )
