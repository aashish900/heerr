from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import require_scope
from app.models import Token
from app.schemas.podcast import (
    PodcastChannelItem,
    PodcastSearchRequest,
    PodcastSearchResponse,
)
from app.services.podcastindex import (
    PodcastIndexClient,
    PodcastIndexError,
    PodcastIndexNotConfigured,
    get_podcastindex_client,
)

router = APIRouter(prefix="/podcasts", tags=["podcasts"])


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
