from typing import cast
from uuid import UUID

from sqlalchemy import func, select, update
from sqlalchemy.engine import CursorResult
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Download, Job


class InvalidStateTransition(Exception):
    pass


async def find_active_for_uri(session: AsyncSession, spotify_uri: str) -> Job | None:
    r = await session.execute(
        select(Job).where(
            Job.spotify_uri == spotify_uri,
            Job.state.in_(["queued", "running"]),
        )
    )
    return r.scalar_one_or_none()


async def find_download_for_track(session: AsyncSession, spotify_track_uri: str) -> Download | None:
    r = await session.execute(
        select(Download).where(Download.spotify_track_uri == spotify_track_uri)
    )
    return r.scalar_one_or_none()


async def create_job_idempotent(
    session: AsyncSession,
    *,
    spotify_uri: str,
    spotify_type: str,
    token_id: UUID,
) -> tuple[Job, bool]:
    """Return (job, deduped).

    deduped=True means an existing active (queued|running) job for the URI
    was returned; deduped=False means a new row was inserted.

    Race protection: the partial unique index
    `jobs_active_uri_idx` on `jobs(spotify_uri) WHERE state IN
    ('queued','running')` makes concurrent duplicate inserts impossible at
    the DB level. The IntegrityError-then-refetch path below converts the
    loser of a race into a clean `deduped=True` result.
    """
    existing = await find_active_for_uri(session, spotify_uri)
    if existing is not None:
        return existing, True

    job = Job(
        spotify_uri=spotify_uri,
        spotify_type=spotify_type,
        state="queued",
        created_by_token_id=token_id,
    )
    session.add(job)
    try:
        async with session.begin_nested():
            await session.flush()
    except IntegrityError:
        existing = await find_active_for_uri(session, spotify_uri)
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
