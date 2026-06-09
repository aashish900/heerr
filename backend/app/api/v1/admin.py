import hashlib
import secrets
from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_admin
from app.api.v1.status import to_view
from app.db import get_session
from app.models import Job, Token
from app.schemas.job import JobView
from app.schemas.token import (
    CreateTokenRequest,
    CreateTokenResponse,
    TokenView,
)
from app.services.jobs import find_active_for_uri
from app.services.workers import JobEnqueuer, get_enqueuer

router = APIRouter(prefix="/admin", tags=["admin"])


# ---- tokens ---------------------------------------------------------------


@router.post(
    "/tokens",
    response_model=CreateTokenResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_token(
    req: CreateTokenRequest,
    session: AsyncSession = Depends(get_session),
    _admin: Token = Depends(require_admin),
) -> CreateTokenResponse:
    raw = secrets.token_urlsafe(32)
    h = hashlib.sha256(raw.encode()).hexdigest()
    tok = Token(
        token_hash=h,
        owner_label=req.owner_label,
        scopes=req.scopes,
        is_admin=req.is_admin,
    )
    session.add(tok)
    await session.flush()
    return CreateTokenResponse(
        id=tok.id,
        raw_token=raw,
        owner_label=tok.owner_label,
        scopes=list(tok.scopes),
        is_admin=tok.is_admin,
        created_at=tok.created_at,
    )


@router.get("/tokens", response_model=list[TokenView])
async def list_tokens(
    session: AsyncSession = Depends(get_session),
    _admin: Token = Depends(require_admin),
) -> list[TokenView]:
    rows = (await session.execute(select(Token).order_by(Token.created_at.asc()))).scalars().all()
    return [
        TokenView(
            id=t.id,
            owner_label=t.owner_label,
            scopes=list(t.scopes),
            is_admin=t.is_admin,
            created_at=t.created_at,
            revoked_at=t.revoked_at,
        )
        for t in rows
    ]


@router.post(
    "/tokens/{token_id}/revoke",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def revoke_token(
    token_id: UUID,
    session: AsyncSession = Depends(get_session),
    _admin: Token = Depends(require_admin),
) -> None:
    tok = await session.get(Token, token_id)
    if tok is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"token {token_id} not found",
        )
    if tok.revoked_at is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="token already revoked",
        )
    tok.revoked_at = datetime.now(UTC)


# ---- jobs -----------------------------------------------------------------


@router.post("/jobs/{job_id}/retry", response_model=JobView)
async def retry_job(
    job_id: UUID,
    bg: BackgroundTasks,
    session: AsyncSession = Depends(get_session),
    enqueue: JobEnqueuer = Depends(get_enqueuer),
    _admin: Token = Depends(require_admin),
) -> JobView:
    job = await session.get(Job, job_id)
    if job is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"job {job_id} not found",
        )
    if job.state != "failed":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"can only retry failed jobs (current state: {job.state})",
        )
    other = await find_active_for_uri(session, job.spotify_uri)
    if other is not None and other.id != job.id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"another active job exists for {job.spotify_uri}",
        )
    job.state = "queued"
    job.error_msg = None
    job.started_at = None
    job.finished_at = None
    job.attempt_count = job.attempt_count + 1
    await session.flush()
    enqueue(bg, job.id)
    return to_view(job, None)
