from datetime import timedelta
from uuid import UUID

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy import func, select, union
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_scope
from app.db import get_session
from app.models import Job, RecFeedback, Token
from app.schemas.recommend import (
    DismissRequest,
    RecommendHealthResponse,
    RecommendRequest,
    RecommendResponse,
    RecommendResultItem,
)
from app.services.recommenders.base import RecommendationEngine, SeedTrack
from app.services.recommenders.factory import get_recommendation_engine
from app.services.recommenders.rerank import rerank
from app.services.recommenders.yt_resolver import cover_url_for_source_url

router = APIRouter(tags=["recommend"])

# Over-fetch so exclusions + the per-artist cap can still fill `limit`.
_OVERFETCH = 2
_OVERFETCH_CAP = 100
_SHOWN_WINDOW = timedelta(days=7)


async def _history(
    session: AsyncSession, user_id: UUID, urls: list[str]
) -> tuple[set[str], set[str]]:
    """(excluded, recently_shown) among `urls` for this user.

    Excluded = anything the user requested (non-failed job) or dismissed.
    """
    if not urls:
        return set(), set()
    excluded_q = union(
        select(Job.source_url).where(
            Job.user_id == user_id, Job.source_url.in_(urls), Job.state != "failed"
        ),
        select(RecFeedback.source_url).where(
            RecFeedback.user_id == user_id,
            RecFeedback.source_url.in_(urls),
            RecFeedback.dismissed_at.is_not(None),
        ),
    )
    shown_q = select(RecFeedback.source_url).where(
        RecFeedback.user_id == user_id,
        RecFeedback.source_url.in_(urls),
        RecFeedback.last_shown_at > func.now() - _SHOWN_WINDOW,
    )
    excluded = set((await session.execute(excluded_q)).scalars())
    shown = set((await session.execute(shown_q)).scalars())
    return excluded, shown


async def _mark_shown(session: AsyncSession, user_id: UUID, urls: list[str]) -> None:
    if not urls:
        return
    t = RecFeedback.__table__
    stmt = pg_insert(RecFeedback).values(
        [
            {"user_id": user_id, "source_url": u, "shown_count": 1, "last_shown_at": func.now()}
            for u in urls
        ]
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=["user_id", "source_url"],
        set_={"shown_count": t.c.shown_count + 1, "last_shown_at": func.now()},
    )
    await session.execute(stmt)


@router.post("/recommend", response_model=RecommendResponse)
async def recommend(
    req: RecommendRequest,
    engine: RecommendationEngine = Depends(get_recommendation_engine),
    tok: Token = Depends(require_scope("read")),
    session: AsyncSession = Depends(get_session),
) -> RecommendResponse:
    seeds = [
        SeedTrack(title=s.title, artist=s.artist, source_url=s.source_url, weight=s.weight)
        for s in req.seeds
    ]
    candidates = await engine.recommend(seeds, min(req.limit * _OVERFETCH, _OVERFETCH_CAP))
    # Dedupe by URL before the DB round-trip (engines in a fallback chain may repeat).
    urls = list(dict.fromkeys(c.source_url for c in candidates))
    excluded, recently_shown = await _history(session, tok.user_id, urls)
    results = rerank(candidates, excluded=excluded, recently_shown=recently_shown, limit=req.limit)
    await _mark_shown(session, tok.user_id, list(dict.fromkeys(r.source_url for r in results)))
    return RecommendResponse(
        results=[
            RecommendResultItem(
                title=r.title,
                artist=r.artist,
                source_url=r.source_url,
                score=r.score,
                cover_url=cover_url_for_source_url(r.source_url),
            )
            for r in results
        ]
    )


@router.post("/recommend/dismiss", status_code=status.HTTP_204_NO_CONTENT)
async def recommend_dismiss(
    req: DismissRequest,
    tok: Token = Depends(require_scope("read")),
    session: AsyncSession = Depends(get_session),
) -> Response:
    """Never recommend `source_url` to this user again. Idempotent."""
    stmt = pg_insert(RecFeedback).values(
        user_id=tok.user_id, source_url=req.source_url, dismissed_at=func.now()
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=["user_id", "source_url"], set_={"dismissed_at": func.now()}
    )
    await session.execute(stmt)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/recommend/health", response_model=RecommendHealthResponse)
async def recommend_health(
    engine: RecommendationEngine = Depends(get_recommendation_engine),
    _token: Token = Depends(require_scope("read")),
) -> RecommendHealthResponse:
    chain = await engine.health_chain()
    # `engine` reports the configured primary; `status` reflects the primary's
    # health; `fallback_active` is true when the primary is down AND a
    # downstream engine in the chain reports OK.
    primary_name, primary_ok = chain[0]
    fallback_ok = any(ok for _, ok in chain[1:])
    return RecommendHealthResponse(
        engine=primary_name,
        status="ok" if primary_ok else "degraded",
        fallback_active=(not primary_ok) and fallback_ok,
    )
