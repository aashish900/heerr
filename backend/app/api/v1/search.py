from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_scope
from app.db import get_session
from app.models import Download, Job, Token
from app.schemas.search import (
    SearchRequest,
    SearchResponse,
    SearchResultItem,
)
from app.services.ytmusic import (
    YTMusicClient,
    YTMusicError,
    YTMusicResult,
    get_ytmusic_client,
)

router = APIRouter(tags=["search"])


async def _hydrate_hints(
    session: AsyncSession,
    items: list[YTMusicResult],
    user_id: UUID,
) -> tuple[set[str], dict[str, str]]:
    """Return (downloaded_urls, active_job_id_by_url) — both scoped to `user_id`.

    Dedupe hints reflect *this user's* request history. The file on disk may
    exist for another user — the Subsonic library surfaces it independently;
    the heerr hint here is "did you request this through heerr."
    """
    urls = [it.source_url for it in items]
    if not urls:
        return set(), {}

    downloaded: set[str] = set()
    song_urls = [it.source_url for it in items if it.source_type == "song"]
    if song_urls:
        r = await session.execute(
            select(Download.source_url)
            .join(Job, Job.id == Download.job_id)
            .where(
                Download.source_url.in_(song_urls),
                Job.user_id == user_id,
            )
        )
        downloaded = set(r.scalars().all())

    r = await session.execute(
        select(Job.source_url, Job.id).where(
            Job.source_url.in_(urls),
            Job.state.in_(["queued", "running"]),
            Job.user_id == user_id,
        )
    )
    active = {row[0]: row[1] for row in r.all()}
    return downloaded, active


@router.post("/search", response_model=SearchResponse)
async def search(
    req: SearchRequest,
    session: AsyncSession = Depends(get_session),
    ytmusic: YTMusicClient = Depends(get_ytmusic_client),
    tok: Token = Depends(require_scope("read")),
) -> SearchResponse:
    try:
        yt_results = await ytmusic.search(req.query, req.type, req.limit)
    except YTMusicError as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"YouTube Music error: {e}",
        ) from e

    downloaded, active = await _hydrate_hints(session, yt_results, tok.user_id)

    items = [
        SearchResultItem(
            source_url=yt.source_url,
            source_type=yt.source_type,
            title=yt.title,
            artist=yt.artist,
            album=yt.album,
            duration_ms=yt.duration_ms,
            cover_url=yt.cover_url,
            already_downloaded=yt.source_url in downloaded,
            active_job_id=active.get(yt.source_url),
        )
        for yt in yt_results
    ]
    return SearchResponse(results=items)
