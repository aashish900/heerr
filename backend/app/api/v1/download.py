from fastapi import APIRouter, BackgroundTasks, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_scope
from app.db import get_session
from app.models import Token
from app.schemas.download import DownloadRequest, DownloadResponse
from app.services.jobs import create_job_idempotent, find_download_for_song
from app.services.workers import JobEnqueuer, get_enqueuer

router = APIRouter(tags=["download"])


@router.post(
    "/download",
    status_code=status.HTTP_202_ACCEPTED,
    response_model=DownloadResponse,
)
async def download(
    req: DownloadRequest,
    bg: BackgroundTasks,
    session: AsyncSession = Depends(get_session),
    enqueue: JobEnqueuer = Depends(get_enqueuer),
    tok: Token = Depends(require_scope("download")),
) -> DownloadResponse:
    if req.source_type == "song":
        existing_dl = await find_download_for_song(session, req.source_url, user_id=tok.user_id)
        if existing_dl is not None:
            return DownloadResponse(
                job_id=existing_dl.job_id,
                state="done",
                deduped=True,
            )

    job, deduped = await create_job_idempotent(
        session,
        source_url=req.source_url,
        source_type=req.source_type,
        token_id=tok.id,
        user_id=tok.user_id,
        display_name=req.display_name,
    )
    # Commit before enqueuing: BackgroundTasks run before the get_session
    # dependency commits on teardown, so run_job would find no row otherwise.
    await session.commit()
    if not deduped:
        enqueue(bg, job.id)

    return DownloadResponse(job_id=job.id, state=job.state, deduped=deduped)
