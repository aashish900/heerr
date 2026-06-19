"""T2 — integration coverage for concurrent `run_job` invocations.

The other worker tests drive `run_job` one call at a time. These exercise the
real cross-session races against Postgres:

  1. N workers for N users on the *same* URL run at once — each must land its
     own per-user `downloads` row (composite unique on `(user_id, source_url)`),
     none clobbering another.
  2. The *same* job dispatched twice concurrently must run the spotDL runner
     exactly once — the atomic `mark_running` guard (UPDATE ... WHERE
     state='queued') lets one worker win and the other bail before phase 2.
"""

import asyncio
import hashlib
import uuid

from sqlalchemy import func, select, text

from app.models import Download, Job, Token, User
from app.services.spotdl_runner import DownloadedFile
from app.services.workers import run_job


async def _seed_user_with_queued_job(
    s, url: str, suffix: str
) -> tuple[uuid.UUID, uuid.UUID, uuid.UUID]:
    u = User(navidrome_username=f"conc-{suffix}-{uuid.uuid4().hex[:8]}")
    s.add(u)
    await s.flush()
    tok = Token(
        token_hash=hashlib.sha256(f"{suffix}-{uuid.uuid4()}".encode()).hexdigest(),
        scopes=["read", "download"],
        user_id=u.id,
    )
    s.add(tok)
    await s.flush()
    job = Job(
        source_url=url,
        source_type="song",
        state="queued",
        created_by_token_id=tok.id,
        user_id=u.id,
    )
    s.add(job)
    await s.flush()
    return u.id, tok.id, job.id


async def _purge(app_sm, user_ids: list[uuid.UUID], token_ids: list[uuid.UUID]) -> None:
    async with app_sm() as s:
        await s.execute(text("DELETE FROM downloads"))
        await s.execute(text("DELETE FROM jobs"))
        for tid in token_ids:
            await s.execute(text("DELETE FROM tokens WHERE id = :i"), {"i": tid})
        for uid in user_ids:
            await s.execute(text("DELETE FROM users WHERE id = :i"), {"i": uid})
        await s.commit()


async def test_concurrent_run_job_distinct_users_same_url(app_sm, tmp_path):
    """Five workers, five users, one shared URL, run concurrently — each user
    ends with their own `downloads` row and the runner fires once per job."""
    url = "https://www.youtube.com/watch?v=conc-multi"
    file_path = str(tmp_path / "shared.mp3")
    n = 5
    calls = {"n": 0}

    async def fake_runner(source_url, output_dir):
        calls["n"] += 1
        # Yield control so the phase-3 Download inserts genuinely overlap.
        await asyncio.sleep(0.02)
        return [DownloadedFile(path=file_path, size_bytes=10)]

    user_ids: list[uuid.UUID] = []
    token_ids: list[uuid.UUID] = []
    job_ids: list[uuid.UUID] = []
    async with app_sm() as s:
        for i in range(n):
            uid, tid, jid = await _seed_user_with_queued_job(s, url, f"m{i}")
            user_ids.append(uid)
            token_ids.append(tid)
            job_ids.append(jid)
        await s.commit()

    try:
        await asyncio.gather(
            *(
                run_job(jid, sm=app_sm, runner=fake_runner, output_dir=str(tmp_path))
                for jid in job_ids
            )
        )

        async with app_sm() as s:
            states = (await s.execute(select(Job.state).where(Job.id.in_(job_ids)))).scalars().all()
            assert states == ["done"] * n

            rows = (
                (await s.execute(select(Download).where(Download.source_url == url)))
                .scalars()
                .all()
            )
            assert len(rows) == n
            assert {r.user_id for r in rows} == set(user_ids)

        assert calls["n"] == n
    finally:
        await _purge(app_sm, user_ids, token_ids)


async def test_concurrent_duplicate_dispatch_runs_runner_once(app_sm, tmp_path):
    """Same job_id dispatched twice at once: exactly one worker runs the runner
    and writes the row; the loser bails at `mark_running` (InvalidStateTransition)."""
    url = "https://www.youtube.com/watch?v=conc-dup"
    file_path = str(tmp_path / "dup.mp3")
    calls = {"n": 0}

    async def fake_runner(source_url, output_dir):
        calls["n"] += 1
        await asyncio.sleep(0.02)
        return [DownloadedFile(path=file_path, size_bytes=7)]

    async with app_sm() as s:
        uid, tid, jid = await _seed_user_with_queued_job(s, url, "dup")
        await s.commit()

    try:
        await asyncio.gather(
            run_job(jid, sm=app_sm, runner=fake_runner, output_dir=str(tmp_path)),
            run_job(jid, sm=app_sm, runner=fake_runner, output_dir=str(tmp_path)),
        )

        async with app_sm() as s:
            j = await s.get(Job, jid)
            assert j.state == "done"
            count = (
                await s.execute(
                    select(func.count()).select_from(Download).where(Download.job_id == jid)
                )
            ).scalar_one()
            assert count == 1

        # The decisive assertion: the duplicate dispatch did not double-run spotDL.
        assert calls["n"] == 1
    finally:
        await _purge(app_sm, [uid], [tid])
