from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_scope
from app.db import get_session
from app.models import Job, Token
from app.schemas.job import JobView
from app.services.jobs import find_download_for_song

router = APIRouter(tags=["jobs"])


def to_view(job: Job, output_path: str | None) -> JobView:
    return JobView(
        job_id=job.id,
        source_url=job.source_url,
        source_type=job.source_type,
        state=job.state,
        display_name=job.display_name,
        progress=None,
        error=job.error_msg,
        output_path=output_path,
        created_at=job.created_at,
        started_at=job.started_at,
        finished_at=job.finished_at,
        episode_id=job.episode_id,
    )


@router.get("/status/{job_id}", response_model=JobView)
async def get_status(
    job_id: UUID,
    session: AsyncSession = Depends(get_session),
    tok: Token = Depends(require_scope("read")),
) -> JobView:
    job = await session.get(Job, job_id)
    # Hide cross-user job existence behind a 404 — don't leak that the id is real.
    if job is None or (not tok.is_admin and job.user_id != tok.user_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"job {job_id} not found",
        )
    output_path: str | None = None
    if job.source_type == "song":
        dl = await find_download_for_song(session, job.source_url, user_id=job.user_id)
        if dl is not None:
            output_path = dl.output_path
    return to_view(job, output_path)
