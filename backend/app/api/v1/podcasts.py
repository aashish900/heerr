from typing import cast
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete as sa_delete
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.engine import CursorResult
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_scope
from app.db import get_session
from app.models import PodcastChannel, PodcastSubscription, Token
from app.schemas.podcast import (
    ChannelItem,
    PodcastChannelItem,
    PodcastSearchRequest,
    PodcastSearchResponse,
    SubscribeRequest,
    SubscriptionsResponse,
)
from app.services.feeds import FeedFetchError, ingest_feed
from app.services.podcastindex import (
    PodcastIndexClient,
    PodcastIndexError,
    PodcastIndexNotConfigured,
    get_podcastindex_client,
)

router = APIRouter(prefix="/podcasts", tags=["podcasts"])


def _channel_item(channel: PodcastChannel) -> ChannelItem:
    return ChannelItem(
        id=channel.id,
        feed_url=channel.feed_url,
        title=channel.title,
        author=channel.author,
        image_url=channel.image_url,
        description=channel.description,
    )


@router.post("/search", response_model=PodcastSearchResponse)
async def search_podcasts(
    req: PodcastSearchRequest,
    client: PodcastIndexClient = Depends(get_podcastindex_client),
    _tok: Token = Depends(require_scope("read")),
) -> PodcastSearchResponse:
    try:
        results = await client.search(req.query, req.limit)
    except PodcastIndexNotConfigured as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Podcast Index not configured: {e}",
        ) from e
    except PodcastIndexError as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Podcast Index error: {e}",
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
