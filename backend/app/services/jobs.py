from typing import cast
from uuid import UUID

from sqlalchemy import func, select, update
from sqlalchemy.engine import CursorResult
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Download, Job


class InvalidStateTransition(Exception):
    pass


async def find_active_for_url(
    session: AsyncSession,
    source_url: str,
    user_id: UUID | None = None,
) -> Job | None:
    """Return an active (queued|running) Job for the URL.

    When `user_id` is given the lookup is scoped to that user; otherwise it
    matches across every user (used by admin sanity checks).
    """
    stmt = select(Job).where(
        Job.source_url == source_url,
        Job.state.in_(["queued", "running"]),
    )
    if user_id is not None:
        stmt = stmt.where(Job.user_id == user_id)
    r = await session.execute(stmt)
    return r.scalar_one_or_none()


async def find_download_for_song(
    session: AsyncSession,
    source_url: str,
    user_id: UUID | None = None,
) -> Download | None:
    """Return a Download row for the URL.

    When `user_id` is given, only returns a Download whose owning Job belongs
    to that user — preserves per-user request-history isolation even though
    the file on disk is shared across the Navidrome library.
    """
    stmt = select(Download).where(Download.source_url == source_url)
    if user_id is not None:
        stmt = stmt.join(Job, Job.id == Download.job_id).where(Job.user_id == user_id)
    r = await session.execute(stmt)
    return r.scalar_one_or_none()


async def create_job_idempotent(
    session: AsyncSession,
    *,
    source_url: str,
    source_type: str,
    token_id: UUID,
    user_id: UUID | None = None,
    display_name: str | None = None,
) -> tuple[Job, bool]:
    """Return (job, deduped).

    deduped=True means an existing active (queued|running) job for the
    `(user_id, source_url)` pair was returned; deduped=False means a new row
    was inserted.

    Race protection: the partial unique index
    `jobs_active_user_source_url_idx` on `jobs(user_id, source_url) WHERE
    state IN ('queued','running')` makes concurrent duplicate inserts by the
    same user impossible at the DB level. The IntegrityError-then-refetch
    path converts the loser of a race into a clean `deduped=True` result.

    When `user_id` is None the row uses the `system_admin_user_id()` server
    default and dedupe is scoped against that synthetic user — the J2
    transitional path retained for callers that don't yet pass a user.
    """
    existing = await find_active_for_url(session, source_url, user_id=user_id)
    if existing is not None:
        return existing, True

    kwargs: dict[str, object] = {
        "source_url": source_url,
        "source_type": source_type,
        "state": "queued",
        "display_name": display_name,
        "created_by_token_id": token_id,
    }
    if user_id is not None:
        kwargs["user_id"] = user_id
    job = Job(**kwargs)
    session.add(job)
    try:
        async with session.begin_nested():
            await session.flush()
    except IntegrityError:
        existing = await find_active_for_url(session, source_url, user_id=user_id)
        if existing is None:
            raise
        return existing, True
    return job, False


async def mark_running(session: AsyncSession, job_id: UUID) -> None:
    result = cast(
        CursorResult,
        await session.execute(
            update(Job)
            .where(Job.id == job_id, Job.state == "queued")
            .values(state="running", started_at=func.now())
        ),
    )
    if result.rowcount == 0:
        raise InvalidStateTransition(f"job {job_id} is not in 'queued' state")


async def mark_done(session: AsyncSession, job_id: UUID) -> None:
    result = cast(
        CursorResult,
        await session.execute(
            update(Job)
            .where(Job.id == job_id, Job.state == "running")
            .values(state="done", finished_at=func.now())
        ),
    )
    if result.rowcount == 0:
        raise InvalidStateTransition(f"job {job_id} is not in 'running' state")


async def mark_failed(session: AsyncSession, job_id: UUID, error_msg: str) -> None:
    result = cast(
        CursorResult,
        await session.execute(
            update(Job)
            .where(Job.id == job_id, Job.state.in_(["queued", "running"]))
            .values(state="failed", finished_at=func.now(), error_msg=error_msg)
        ),
    )
    if result.rowcount == 0:
        raise InvalidStateTransition(f"job {job_id} is not in 'queued'/'running' state")


async def bump_attempt(session: AsyncSession, job_id: UUID) -> None:
    await session.execute(
        update(Job).where(Job.id == job_id).values(attempt_count=Job.attempt_count + 1)
    )
