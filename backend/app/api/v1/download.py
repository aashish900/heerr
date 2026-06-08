from fastapi import APIRouter, BackgroundTasks, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_scope
from app.db import get_session
from app.models import Token
from app.schemas.download import DownloadRequest, DownloadResponse
from app.services.jobs import create_job_idempotent, find_download_for_track
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
    type_ = req.parsed_type()

    if type_ == "track":
        existing_dl = await find_download_for_track(session, req.spotify_uri)
        if existing_dl is not None:
            return DownloadResponse(
                job_id=existing_dl.job_id,
                state="done",
                deduped=True,
            )

    job, deduped = await create_job_idempotent(
        session,
        spotify_uri=req.spotify_uri,
        spotify_type=type_,
        token_id=tok.id,
    )
    if not deduped:
        enqueue(bg, job.id)

    return DownloadResponse(
        job_id=job.id, state=job.state, deduped=deduped
    )
