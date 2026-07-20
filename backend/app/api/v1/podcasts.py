import os
from datetime import UTC, datetime
from pathlib import Path
from typing import cast
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, Request, status
from fastapi.responses import StreamingResponse
from sqlalchemy import and_, func, select
from sqlalchemy import delete as sa_delete
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.engine import CursorResult
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_scope, require_scope_query_or_header
from app.db import get_session
from app.models import PodcastChannel, PodcastEpisode, PodcastProgress, PodcastSubscription, Token
from app.schemas.podcast import (
    ChannelItem,
    EpisodeDownloadResponse,
    EpisodeItem,
    EpisodeListResponse,
    EpisodeProgressRequest,
    EpisodeProgressResponse,
    PodcastChannelItem,
    PodcastSearchRequest,
    PodcastSearchResponse,
    SubscribeRequest,
    SubscriptionsResponse,
)
from app.services.feeds import FeedFetchError, ingest_feed
from app.services.jobs import create_job_idempotent
from app.services.podcast_search import (
    PodcastSearchClient,
    PodcastSearchError,
    get_podcast_search_client,
)
from app.services.range_file import InvalidRangeError, iter_file_range, parse_range
from app.services.workers import PodcastJobEnqueuer, get_podcast_enqueuer

router = APIRouter(prefix="/podcasts", tags=["podcasts"])

_AUDIO_CONTENT_TYPES = {
    ".mp3": "audio/mpeg",
    ".m4a": "audio/mp4",
    ".aac": "audio/aac",
    ".ogg": "audio/ogg",
    ".opus": "audio/opus",
    ".wav": "audio/wav",
}


def _channel_item(channel: PodcastChannel) -> ChannelItem:
    return ChannelItem(
        id=channel.id,
        feed_url=channel.feed_url,
        title=channel.title,
        author=channel.author,
        image_url=channel.image_url,
        description=channel.description,
    )


def _episode_item(episode: PodcastEpisode, progress: PodcastProgress | None) -> EpisodeItem:
    return EpisodeItem(
        id=episode.id,
        channel_id=episode.channel_id,
        guid=episode.guid,
        title=episode.title,
        description=episode.description,
        published_at=episode.published_at,
        duration_s=episode.duration_s,
        enclosure_url=episode.enclosure_url,
        enclosure_type=episode.enclosure_type,
        image_url=episode.image_url,
        episode_no=episode.episode_no,
        season_no=episode.season_no,
        downloaded=episode.downloaded_path is not None,
        position_s=progress.position_s if progress else 0,
        played=progress.played if progress else False,
    )


@router.post("/search", response_model=PodcastSearchResponse)
async def search_podcasts(
    req: PodcastSearchRequest,
    client: PodcastSearchClient = Depends(get_podcast_search_client),
    _tok: Token = Depends(require_scope("read")),
) -> PodcastSearchResponse:
    try:
        results = await client.search(req.query, req.limit)
    except PodcastSearchError as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"podcast search error: {e}",
        ) from e

    items = [
        PodcastChannelItem(
            feed_url=r.feed_url,
            title=r.title,
            author=r.author,
            image_url=r.image_url,
            description=r.description,
        )
        for r in results
    ]
    return PodcastSearchResponse(results=items)


@router.post("/subscribe", response_model=ChannelItem)
async def subscribe(
    req: SubscribeRequest,
    session: AsyncSession = Depends(get_session),
    tok: Token = Depends(require_scope("read")),
) -> ChannelItem:
    try:
        channel = await ingest_feed(session, req.feed_url)
    except FeedFetchError as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"feed error: {e}",
        ) from e

    sub_stmt = (
        pg_insert(PodcastSubscription)
        .values(user_id=tok.user_id, channel_id=channel.id)
        .on_conflict_do_nothing(index_elements=["user_id", "channel_id"])
    )
    await session.execute(sub_stmt)
    return _channel_item(channel)


@router.delete("/subscribe/{channel_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unsubscribe(
    channel_id: UUID,
    session: AsyncSession = Depends(get_session),
    tok: Token = Depends(require_scope("read")),
) -> None:
    result = cast(
        CursorResult,
        await session.execute(
            sa_delete(PodcastSubscription).where(
                PodcastSubscription.user_id == tok.user_id,
                PodcastSubscription.channel_id == channel_id,
            )
        ),
    )
    if result.rowcount == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="not subscribed to this channel",
        )


@router.get("/subscriptions", response_model=SubscriptionsResponse)
async def list_subscriptions(
    session: AsyncSession = Depends(get_session),
    tok: Token = Depends(require_scope("read")),
) -> SubscriptionsResponse:
    result = await session.execute(
        select(PodcastChannel)
        .join(PodcastSubscription, PodcastSubscription.channel_id == PodcastChannel.id)
        .where(PodcastSubscription.user_id == tok.user_id)
        .order_by(PodcastSubscription.subscribed_at.desc())
    )
    channels = result.scalars().all()
    return SubscriptionsResponse(channels=[_channel_item(c) for c in channels])


@router.get("/channels/{channel_id}/episodes", response_model=EpisodeListResponse)
async def list_episodes(
    channel_id: UUID,
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_session),
    tok: Token = Depends(require_scope("read")),
) -> EpisodeListResponse:
    channel = await session.get(PodcastChannel, channel_id)
    if channel is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="channel not found")

    total = await session.scalar(
        select(func.count())
        .select_from(PodcastEpisode)
        .where(PodcastEpisode.channel_id == channel_id)
    )

    result = await session.execute(
        select(PodcastEpisode, PodcastProgress)
        .outerjoin(
            PodcastProgress,
            and_(
                PodcastProgress.episode_id == PodcastEpisode.id,
                PodcastProgress.user_id == tok.user_id,
            ),
        )
        .where(PodcastEpisode.channel_id == channel_id)
        .order_by(PodcastEpisode.published_at.desc().nulls_last())
        .limit(limit)
        .offset(offset)
    )
    episodes = [_episode_item(ep, progress) for ep, progress in result.all()]
    return EpisodeListResponse(episodes=episodes, total=total or 0)


@router.post("/channels/{channel_id}/refresh", response_model=ChannelItem)
async def refresh_channel(
    channel_id: UUID,
    session: AsyncSession = Depends(get_session),
    _tok: Token = Depends(require_scope("read")),
) -> ChannelItem:
    channel = await session.get(PodcastChannel, channel_id)
    if channel is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="channel not found")
    try:
        channel = await ingest_feed(session, channel.feed_url)
    except FeedFetchError as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"feed error: {e}",
        ) from e
    return _channel_item(channel)


@router.post(
    "/episodes/{episode_id}/download",
    status_code=status.HTTP_202_ACCEPTED,
    response_model=EpisodeDownloadResponse,
)
async def download_episode_endpoint(
    episode_id: UUID,
    bg: BackgroundTasks,
    session: AsyncSession = Depends(get_session),
    enqueue: PodcastJobEnqueuer = Depends(get_podcast_enqueuer),
    tok: Token = Depends(require_scope("download")),
) -> EpisodeDownloadResponse:
    episode = await session.get(PodcastEpisode, episode_id)
    if episode is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="episode not found")

    job, deduped = await create_job_idempotent(
        session,
        source_url=episode.enclosure_url,
        source_type="episode",
        token_id=tok.id,
        user_id=tok.user_id,
        display_name=episode.title,
        episode_id=episode.id,
    )
    # Commit before enqueuing: BackgroundTasks run before the get_session
    # dependency commits on teardown, so the worker would find no row otherwise
    # (same ordering constraint as POST /download).
    await session.commit()
    if not deduped:
        enqueue(bg, job.id)

    return EpisodeDownloadResponse(job_id=job.id, state=job.state, deduped=deduped)


@router.get("/episodes/{episode_id}/audio")
async def stream_episode_audio(
    episode_id: UUID,
    request: Request,
    session: AsyncSession = Depends(get_session),
    _tok: Token = Depends(require_scope_query_or_header("read")),
) -> StreamingResponse:
    """Serve a downloaded episode's audio with HTTP Range support (seek/resume).

    Not-yet-downloaded episodes are NOT proxied here — `EpisodeItem.enclosure_url`
    (already public) is what the client streams on-demand instead (see
    backend/docs/PODCASTS.md 2.5: no backend proxy for already-public URLs).
    """
    episode = await session.get(PodcastEpisode, episode_id)
    if episode is None or episode.downloaded_path is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="episode not downloaded — stream via its enclosure_url instead",
        )
    if not os.path.exists(episode.downloaded_path):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="downloaded file missing on disk",
        )

    file_size = os.path.getsize(episode.downloaded_path)
    media_type = _AUDIO_CONTENT_TYPES.get(
        Path(episode.downloaded_path).suffix.lower(), "application/octet-stream"
    )

    try:
        rng = parse_range(request.headers.get("range"), file_size)
    except InvalidRangeError as exc:
        raise HTTPException(
            status_code=status.HTTP_416_RANGE_NOT_SATISFIABLE,
            detail=str(exc),
            headers={"Content-Range": f"bytes */{file_size}"},
        ) from exc

    start, end = rng if rng is not None else (0, file_size - 1)
    headers = {
        "Accept-Ranges": "bytes",
        "Content-Length": str(end - start + 1),
    }
    if rng is not None:
        headers["Content-Range"] = f"bytes {start}-{end}/{file_size}"

    return StreamingResponse(
        iter_file_range(episode.downloaded_path, start, end),
        status_code=status.HTTP_206_PARTIAL_CONTENT if rng is not None else status.HTTP_200_OK,
        media_type=media_type,
        headers=headers,
    )


@router.put("/episodes/{episode_id}/progress", response_model=EpisodeProgressResponse)
async def update_episode_progress(
    episode_id: UUID,
    req: EpisodeProgressRequest,
    session: AsyncSession = Depends(get_session),
    tok: Token = Depends(require_scope("read")),
) -> EpisodeProgressResponse:
    episode = await session.get(PodcastEpisode, episode_id)
    if episode is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="episode not found")

    values = {
        "user_id": tok.user_id,
        "episode_id": episode_id,
        "position_s": req.position_s,
        "played": req.played,
        "last_played_at": datetime.now(UTC),
    }
    stmt = (
        pg_insert(PodcastProgress)
        .values(**values)
        .on_conflict_do_update(index_elements=["user_id", "episode_id"], set_=values)
    )
    await session.execute(stmt)

    return EpisodeProgressResponse(
        episode_id=episode_id, position_s=req.position_s, played=req.played
    )
