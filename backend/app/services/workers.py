import logging
from collections.abc import Awaitable, Callable
from uuid import UUID

from fastapi import BackgroundTasks
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.config import get_settings
from app.db import _sessionmaker
from app.models import Download, Job
from app.services.jobs import (
    InvalidStateTransition,
    mark_done,
    mark_failed,
    mark_running,
)
from app.services.spotdl_runner import DownloadedFile, run_spotdl

logger = logging.getLogger(__name__)

SpotdlRunner = Callable[[str, str], Awaitable[list[DownloadedFile]]]

_ERROR_MSG_MAX = 2000


async def run_job(
    job_id: UUID,
    *,
    sm: async_sessionmaker,
    runner: SpotdlRunner,
    output_dir: str,
) -> None:
    """Drive a job through queued -> running -> (done | failed).

    On success, writes a single Download row for song jobs only — album/playlist
    jobs transition to done but the per-track file mapping is omitted in v1.
    """
    # Phase 1: load job + transition queued -> running
    async with sm() as s:
        job = await s.get(Job, job_id)
        if job is None:
            logger.warning("run_job: job %s missing", job_id)
            return
        source_url = job.source_url
        source_type = job.source_type
        user_id = job.user_id
        try:
            await mark_running(s, job_id)
        except InvalidStateTransition:
            logger.warning("run_job: job %s not in queued state; skipping", job_id)
            return
        await s.commit()

    # Phase 2: invoke spotDL
    try:
        files = await runner(source_url, output_dir)
    except Exception as e:
        msg = f"{type(e).__name__}: {e}"[-_ERROR_MSG_MAX:]
        await _safe_mark_failed(sm, job_id, msg)
        logger.exception("run_job: runner failed for %s", job_id)
        return

    # Phase 3: write Download row + transition running -> done
    try:
        async with sm() as s:
            if source_type == "song":
                if not files:
                    raise RuntimeError("spotdl exited 0 but produced no audio file")
                first = files[0]
                # ON CONFLICT DO NOTHING on (user_id, source_url): a row may
                # already exist for this user (e.g. a re-run/retry of a job they
                # previously completed). Download rows are now per-user — a
                # different user downloading the same shared file gets their own
                # row, which keeps their per-user dedupe hints correct.
                from sqlalchemy.dialects.postgresql import insert as pg_insert

                await s.execute(
                    pg_insert(Download)
                    .values(
                        source_url=source_url,
                        job_id=job_id,
                        user_id=user_id,
                        output_path=first.path,
                        file_size_bytes=first.size_bytes,
                    )
                    .on_conflict_do_nothing(index_elements=[Download.user_id, Download.source_url])
                )
            await mark_done(s, job_id)
            await s.commit()
    except Exception as e:
        msg = f"bookkeeping failed: {type(e).__name__}: {e}"[-_ERROR_MSG_MAX:]
        await _safe_mark_failed(sm, job_id, msg)
        logger.exception("run_job: post-download bookkeeping failed for %s", job_id)


async def _safe_mark_failed(sm: async_sessionmaker, job_id: UUID, msg: str) -> None:
    try:
        async with sm() as s:
            await mark_failed(s, job_id, msg)
            await s.commit()
    except InvalidStateTransition:
        logger.warning("_safe_mark_failed: job %s not in queued/running", job_id)
    except Exception:
        logger.exception("_safe_mark_failed: could not mark job %s failed", job_id)


class JobEnqueuer:
    """Schedules `run_job` to execute via FastAPI BackgroundTasks."""

    def __init__(
        self,
        sm: async_sessionmaker,
        runner: SpotdlRunner,
        output_dir: str,
    ):
        self._sm = sm
        self._runner = runner
        self._output_dir = output_dir

    def __call__(self, bg: BackgroundTasks, job_id: UUID) -> None:
        bg.add_task(
            run_job,
            job_id,
            sm=self._sm,
            runner=self._runner,
            output_dir=self._output_dir,
        )


def get_enqueuer() -> JobEnqueuer:
    settings = get_settings()
    return JobEnqueuer(
        sm=_sessionmaker(),
        runner=run_spotdl,
        output_dir=settings.music_output_dir,
    )
