from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_scope
from app.api.v1.status import to_view
from app.db import get_session
from app.models import Download, Job, Token
from app.schemas.job import JobView, QueueResponse

router = APIRouter(tags=["jobs"])

_RECENT_LIMIT = 20


@router.get("/queue", response_model=QueueResponse)
async def get_queue(
    session: AsyncSession = Depends(get_session),
    _tok: Token = Depends(require_scope("read")),
) -> QueueResponse:
    active_rows = (
        (
            await session.execute(
                select(Job)
                .where(Job.state.in_(["queued", "running"]))
                .order_by(Job.created_at.asc())
            )
        )
        .scalars()
        .all()
    )

    recent_rows = (
        (
            await session.execute(
                select(Job)
                .where(Job.state.in_(["done", "failed"]))
                .order_by(
                    Job.finished_at.desc().nulls_last(),
                    Job.created_at.desc(),
                )
                .limit(_RECENT_LIMIT)
            )
        )
        .scalars()
        .all()
    )

    # Batch-load song output paths in a single query.
    song_urls = [j.source_url for j in (*active_rows, *recent_rows) if j.source_type == "song"]
    paths: dict[str, str] = {}
    if song_urls:
        rows = (
            await session.execute(
                select(Download.source_url, Download.output_path).where(
                    Download.source_url.in_(song_urls)
                )
            )
        ).all()
        paths = {row[0]: row[1] for row in rows}

    def _view(j: Job) -> JobView:
        op = paths.get(j.source_url) if j.source_type == "song" else None
        return to_view(j, op)

    return QueueResponse(
        active=[_view(j) for j in active_rows],
        recent=[_view(j) for j in recent_rows],
    )
