from fastapi import APIRouter, Depends

from app.api.deps import require_scope
from app.models import Token
from app.schemas.recommend import (
    RecommendHealthResponse,
    RecommendRequest,
    RecommendResponse,
    RecommendResultItem,
)
from app.services.recommenders.base import RecommendationEngine, SeedTrack
from app.services.recommenders.factory import get_recommendation_engine

router = APIRouter(tags=["recommend"])


@router.post("/recommend", response_model=RecommendResponse)
async def recommend(
    req: RecommendRequest,
    engine: RecommendationEngine = Depends(get_recommendation_engine),
    _token: Token = Depends(require_scope("read")),
) -> RecommendResponse:
    seeds = [
        SeedTrack(title=s.title, artist=s.artist, source_url=s.source_url)
        for s in req.seeds
    ]
    results = await engine.recommend(seeds, req.limit)
    return RecommendResponse(
        results=[
            RecommendResultItem(
                title=r.title,
                artist=r.artist,
                source_url=r.source_url,
                score=r.score,
            )
            for r in results
        ]
    )


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
