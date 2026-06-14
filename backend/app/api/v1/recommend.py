from fastapi import APIRouter, Depends

from app.api.deps import require_scope
from app.models import Token
from app.schemas.recommend import (
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
