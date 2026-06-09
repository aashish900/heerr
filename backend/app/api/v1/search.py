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
from app.services.spotify import (
    SpotifyClient,
    SpotifyRateLimited,
    SpotifyResult,
    get_spotify_client,
)

router = APIRouter(tags=["search"])


async def _hydrate_hints(
    session: AsyncSession,
    items: list[SpotifyResult],
    type_: str,
) -> tuple[set[str], dict[str, str]]:
    """Return (downloaded_uris, active_job_id_by_uri)."""
    uris = [it.spotify_uri for it in items]
    if not uris:
        return set(), {}

    downloaded: set[str] = set()
    if type_ == "track":
        r = await session.execute(
            select(Download.spotify_track_uri).where(Download.spotify_track_uri.in_(uris))
        )
        downloaded = set(r.scalars().all())

    r = await session.execute(
        select(Job.spotify_uri, Job.id).where(
            Job.spotify_uri.in_(uris),
            Job.state.in_(["queued", "running"]),
        )
    )
    active = {row[0]: row[1] for row in r.all()}
    return downloaded, active


@router.post("/search", response_model=SearchResponse)
async def search(
    req: SearchRequest,
    session: AsyncSession = Depends(get_session),
    spotify: SpotifyClient = Depends(get_spotify_client),
    _token: Token = Depends(require_scope("read")),
) -> SearchResponse:
    try:
        if req.type == "track":
            sp_results = await spotify.search_tracks(req.query, req.limit)
        elif req.type == "album":
            sp_results = await spotify.search_albums(req.query, req.limit)
        else:
            sp_results = await spotify.search_playlists(req.query, req.limit)
    except SpotifyRateLimited as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="upstream rate limited",
            headers={"Retry-After": str(e.retry_after)},
        ) from e

    downloaded, active = await _hydrate_hints(session, sp_results, req.type)

    items = [
        SearchResultItem(
            spotify_uri=sp.spotify_uri,
            spotify_url=sp.spotify_url,
            title=sp.title,
            artist=sp.artist,
            album=sp.album,
            duration_ms=sp.duration_ms,
            cover_url=sp.cover_url,
            already_downloaded=sp.spotify_uri in downloaded,
            active_job_id=active.get(sp.spotify_uri),
        )
        for sp in sp_results
    ]
    return SearchResponse(results=items)
