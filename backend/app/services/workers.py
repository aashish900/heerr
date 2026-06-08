import asyncio
from uuid import UUID

from fastapi import BackgroundTasks
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.db import _sessionmaker
from app.services.jobs import (
    InvalidStateTransition,
    mark_done,
    mark_failed,
    mark_running,
)


class JobEnqueuer:
    """Schedules a background task that runs a job through the state machine.

    F2 will replace `_simulate_work` with the real spotDL subprocess call.
    For now it's a no-op sleep so the queued -> running -> done path is
    exercised end-to-end via BackgroundTasks.
    """

    def __init__(self, sessionmaker: async_sessionmaker):
        self._sm = sessionmaker

    def __call__(self, bg: BackgroundTasks, job_id: UUID) -> None:
        bg.add_task(self._run, job_id)

    async def _run(self, job_id: UUID) -> None:
        try:
            async with self._sm() as s:
                await mark_running(s, job_id)
                await s.commit()
            await self._simulate_work()
            async with self._sm() as s:
                await mark_done(s, job_id)
                await s.commit()
        except Exception as e:  # noqa: BLE001
            try:
                async with self._sm() as s:
                    await mark_failed(s, job_id, str(e))
                    await s.commit()
            except InvalidStateTransition:
                pass

    async def _simulate_work(self) -> None:
        await asyncio.sleep(0.05)


def get_enqueuer() -> JobEnqueuer:
    return JobEnqueuer(_sessionmaker())
