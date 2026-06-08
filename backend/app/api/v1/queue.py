from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_scope
from app.api.v1.status import to_view
from app.db import get_session
from app.models import Download, Job, Token
from app.schemas.job import QueueResponse

router = APIRouter(tags=["jobs"])

_RECENT_LIMIT = 20


@router.get("/queue", response_model=QueueResponse)
async def get_queue(
    session: AsyncSession = Depends(get_session),
    _tok: Token = Depends(require_scope("read")),
) -> QueueResponse:
    active_rows = (
        await session.execute(
            select(Job)
            .where(Job.state.in_(["queued", "running"]))
            .order_by(Job.created_at.asc())
        )
    ).scalars().all()

    recent_rows = (
        await session.execute(
            select(Job)
            .where(Job.state.in_(["done", "failed"]))
            .order_by(
                Job.finished_at.desc().nulls_last(),
                Job.created_at.desc(),
            )
            .limit(_RECENT_LIMIT)
        )
    ).scalars().all()

    # Batch-load track output paths in a single query.
    track_uris = [
        j.spotify_uri
        for j in (*active_rows, *recent_rows)
        if j.spotify_type == "track"
    ]
    paths: dict[str, str] = {}
    if track_uris:
        rows = (
            await session.execute(
                select(
                    Download.spotify_track_uri, Download.output_path
                ).where(Download.spotify_track_uri.in_(track_uris))
            )
        ).all()
        paths = {row[0]: row[1] for row in rows}

    def _view(j: Job):
        op = paths.get(j.spotify_uri) if j.spotify_type == "track" else None
        return to_view(j, op)

    return QueueResponse(
        active=[_view(j) for j in active_rows],
        recent=[_view(j) for j in recent_rows],
    )
