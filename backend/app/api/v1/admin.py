import hashlib
import secrets
from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_admin
from app.api.v1.status import to_view
from app.db import get_session
from app.models import Job, Token, User
from app.schemas.job import JobView
from app.schemas.token import (
    CreateTokenRequest,
    CreateTokenResponse,
    TokenView,
)
from app.schemas.user import CreateUserRequest, UserView
from app.services.jobs import find_active_for_url
from app.services.workers import JobEnqueuer, get_enqueuer

router = APIRouter(prefix="/admin", tags=["admin"])


# ---- users ----------------------------------------------------------------


@router.post(
    "/users",
    response_model=UserView,
)
async def create_or_get_user(
    req: CreateUserRequest,
    session: AsyncSession = Depends(get_session),
    _admin: Token = Depends(require_admin),
) -> UserView:
    """Idempotent pre-create of a heerr `users` row.

    Lets the operator mint a token for a user before that user logs in for
    the first time. Re-issuing the same `navidrome_username` returns the
    existing row (200 OK, not 409) so scripts can be re-run safely.
    """
    existing = (
        await session.execute(select(User).where(User.navidrome_username == req.navidrome_username))
    ).scalar_one_or_none()
    if existing is not None:
        return UserView(
            id=existing.id,
            navidrome_username=existing.navidrome_username,
            created_at=existing.created_at,
            last_login_at=existing.last_login_at,
        )
    user = User(navidrome_username=req.navidrome_username)
    session.add(user)
    await session.flush()
    return UserView(
        id=user.id,
        navidrome_username=user.navidrome_username,
        created_at=user.created_at,
        last_login_at=user.last_login_at,
    )


@router.get("/users", response_model=list[UserView])
async def list_users(
    session: AsyncSession = Depends(get_session),
    _admin: Token = Depends(require_admin),
) -> list[UserView]:
    rows = (await session.execute(select(User).order_by(User.created_at.asc()))).scalars().all()
    return [
        UserView(
            id=u.id,
            navidrome_username=u.navidrome_username,
            created_at=u.created_at,
            last_login_at=u.last_login_at,
        )
        for u in rows
    ]


@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(
    user_id: UUID,
    session: AsyncSession = Depends(get_session),
    _admin: Token = Depends(require_admin),
) -> None:
    user = await session.get(User, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"user {user_id} not found",
        )
    if user.navidrome_username == "system-admin":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="cannot delete the synthetic system-admin user",
        )
    token_count = (
        await session.execute(
            select(func.count()).select_from(Token).where(Token.user_id == user.id)
        )
    ).scalar_one()
    job_count = (
        await session.execute(select(func.count()).select_from(Job).where(Job.user_id == user.id))
    ).scalar_one()
    if token_count or job_count:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                f"user has {token_count} token(s) and {job_count} job(s); "
                "revoke tokens and clear jobs before deletion"
            ),
        )
    await session.delete(user)
    try:
        await session.flush()
    except IntegrityError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="user has dependent rows that prevent deletion",
        ) from exc


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
    target = (
        await session.execute(select(User).where(User.navidrome_username == req.navidrome_username))
    ).scalar_one_or_none()
    if target is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"unknown navidrome_username: {req.navidrome_username}",
        )
    raw = secrets.token_urlsafe(32)
    h = hashlib.sha256(raw.encode()).hexdigest()
    tok = Token(
        token_hash=h,
        owner_label=req.owner_label,
        scopes=req.scopes,
        is_admin=req.is_admin,
        user_id=target.id,
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


@router.get("/jobs", response_model=list[JobView])
async def list_jobs(
    state: str | None = None,
    user: str | None = None,
    limit: int = 100,
    session: AsyncSession = Depends(get_session),
    _admin: Token = Depends(require_admin),
) -> list[JobView]:
    """Operator job listing with optional filters.

    `state` filters by job state (`queued|running|done|failed`).
    `user` filters by `navidrome_username` (404 if the user does not exist).
    `limit` caps the result set (1-500, default 100).
    """
    if limit < 1 or limit > 500:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="limit must be between 1 and 500",
        )
    if state is not None and state not in ("queued", "running", "done", "failed"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"invalid state: {state}",
        )
    stmt = select(Job)
    if user is not None:
        target = (
            await session.execute(select(User).where(User.navidrome_username == user))
        ).scalar_one_or_none()
        if target is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"unknown navidrome_username: {user}",
            )
        stmt = stmt.where(Job.user_id == target.id)
    if state is not None:
        stmt = stmt.where(Job.state == state)
    stmt = stmt.order_by(Job.created_at.desc()).limit(limit)
    jobs = (await session.execute(stmt)).scalars().all()
    return [to_view(j, None) for j in jobs]


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
    other = await find_active_for_url(session, job.source_url)
    if other is not None and other.id != job.id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"another active job exists for {job.source_url}",
        )
    job.state = "queued"
    job.error_msg = None
    job.started_at = None
    job.finished_at = None
    job.attempt_count = job.attempt_count + 1
    await session.flush()
    enqueue(bg, job.id)
    return to_view(job, None)
