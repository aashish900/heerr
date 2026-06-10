import asyncio
import hashlib
import uuid

import pytest
from sqlalchemy import select, text

from app.models import Download, Job, Token
from app.services.jobs import (
    InvalidStateTransition,
    bump_attempt,
    create_job_idempotent,
    find_active_for_url,
    find_download_for_song,
    mark_done,
    mark_failed,
    mark_running,
)


@pytest.fixture
async def token_id(app_sm):
    h = hashlib.sha256(f"raw-{uuid.uuid4()}".encode()).hexdigest()
    async with app_sm() as s:
        tok = Token(token_hash=h, owner_label="test", scopes=["read", "download"])
        s.add(tok)
        await s.commit()
        await s.refresh(tok)
        tid = tok.id
    yield tid
    async with app_sm() as s:
        await s.execute(text("DELETE FROM tokens WHERE id = :i"), {"i": tid})
        await s.commit()


@pytest.fixture
async def cleanup_jobs(app_sm):
    yield
    async with app_sm() as s:
        await s.execute(text("DELETE FROM downloads"))
        await s.execute(text("DELETE FROM jobs"))
        await s.commit()


# ---- create_job_idempotent ------------------------------------------------


async def test_create_inserts_new_job(app_sm, token_id, cleanup_jobs):
    async with app_sm() as s:
        job, deduped = await create_job_idempotent(
            s,
            source_url="https://www.youtube.com/watch?v=a",
            source_type="song",
            token_id=token_id,
        )
        await s.commit()
    assert deduped is False
    assert job.state == "queued"
    assert job.source_url == "https://www.youtube.com/watch?v=a"
    assert job.source_type == "song"
    assert job.created_by_token_id == token_id
    assert job.attempt_count == 0
    assert job.display_name is None


async def test_create_stores_display_name(app_sm, token_id, cleanup_jobs):
    async with app_sm() as s:
        job, deduped = await create_job_idempotent(
            s,
            source_url="https://www.youtube.com/watch?v=disp-new",
            source_type="song",
            token_id=token_id,
            display_name="Bohemian Rhapsody — Queen",
        )
        await s.commit()
        job_id = job.id

    async with app_sm() as s:
        row = (await s.execute(select(Job).where(Job.id == job_id))).scalar_one()
        assert row.display_name == "Bohemian Rhapsody — Queen"


async def test_create_dedupe_keeps_existing_display_name(app_sm, token_id, cleanup_jobs):
    """Re-dispatching an active URI does not overwrite the original label."""
    async with app_sm() as s:
        first, _ = await create_job_idempotent(
            s,
            source_url="https://www.youtube.com/watch?v=disp-dup",
            source_type="song",
            token_id=token_id,
            display_name="Original Name",
        )
        await s.commit()
        first_id = first.id

    async with app_sm() as s:
        second, deduped = await create_job_idempotent(
            s,
            source_url="https://www.youtube.com/watch?v=disp-dup",
            source_type="song",
            token_id=token_id,
            display_name="Other Name",
        )
    assert deduped is True
    assert second.id == first_id
    assert second.display_name == "Original Name"


async def test_create_dedupes_when_active_exists(app_sm, token_id, cleanup_jobs):
    async with app_sm() as s:
        first, _ = await create_job_idempotent(
            s,
            source_url="https://www.youtube.com/watch?v=b",
            source_type="song",
            token_id=token_id,
        )
        await s.commit()
        first_id = first.id

    async with app_sm() as s:
        second, deduped = await create_job_idempotent(
            s,
            source_url="https://www.youtube.com/watch?v=b",
            source_type="song",
            token_id=token_id,
        )
    assert deduped is True
    assert second.id == first_id


async def test_create_allows_requeue_after_done(app_sm, token_id, cleanup_jobs):
    async with app_sm() as s:
        first, _ = await create_job_idempotent(
            s,
            source_url="https://www.youtube.com/watch?v=c",
            source_type="song",
            token_id=token_id,
        )
        await s.commit()
        first_id = first.id

    async with app_sm() as s:
        await mark_running(s, first_id)
        await mark_done(s, first_id)
        await s.commit()

    async with app_sm() as s:
        second, deduped = await create_job_idempotent(
            s,
            source_url="https://www.youtube.com/watch?v=c",
            source_type="song",
            token_id=token_id,
        )
        await s.commit()
    assert deduped is False
    assert second.id != first_id
    assert second.state == "queued"


async def test_create_concurrent_inserts_dedupe_via_partial_unique_index(
    app_sm, token_id, cleanup_jobs
):
    """The partial-unique-index ensures only one of two parallel creates wins."""
    uri = "https://www.youtube.com/watch?v=race"

    async def _one():
        async with app_sm() as s:
            job, deduped = await create_job_idempotent(
                s,
                source_url=uri,
                source_type="song",
                token_id=token_id,
            )
            await s.commit()
            return job.id, deduped

    results = await asyncio.gather(_one(), _one())
    ids = {r[0] for r in results}
    dedupe_flags = [r[1] for r in results]
    assert len(ids) == 1, "both creates should resolve to the same job id"
    assert dedupe_flags.count(False) == 1 and dedupe_flags.count(True) == 1


# ---- mark_running ---------------------------------------------------------


async def test_mark_running_sets_state_and_started_at(app_sm, token_id, cleanup_jobs):
    async with app_sm() as s:
        job, _ = await create_job_idempotent(
            s,
            source_url="https://www.youtube.com/watch?v=r1",
            source_type="song",
            token_id=token_id,
        )
        await s.commit()
        job_id = job.id

    async with app_sm() as s:
        await mark_running(s, job_id)
        await s.commit()

    async with app_sm() as s:
        row = (await s.execute(select(Job).where(Job.id == job_id))).scalar_one()
        assert row.state == "running"
        assert row.started_at is not None


async def test_mark_running_rejects_non_queued(app_sm, token_id, cleanup_jobs):
    async with app_sm() as s:
        job, _ = await create_job_idempotent(
            s,
            source_url="https://www.youtube.com/watch?v=r2",
            source_type="song",
            token_id=token_id,
        )
        await s.commit()
        await mark_running(s, job.id)
        await s.commit()

    async with app_sm() as s:
        with pytest.raises(InvalidStateTransition):
            await mark_running(s, job.id)


# ---- mark_done ------------------------------------------------------------


async def test_mark_done_sets_state_and_finished_at(app_sm, token_id, cleanup_jobs):
    async with app_sm() as s:
        job, _ = await create_job_idempotent(
            s,
            source_url="https://www.youtube.com/watch?v=d1",
            source_type="song",
            token_id=token_id,
        )
        await s.commit()
        job_id = job.id

    async with app_sm() as s:
        await mark_running(s, job_id)
        await mark_done(s, job_id)
        await s.commit()

    async with app_sm() as s:
        row = (await s.execute(select(Job).where(Job.id == job_id))).scalar_one()
        assert row.state == "done"
        assert row.finished_at is not None


async def test_mark_done_rejects_queued(app_sm, token_id, cleanup_jobs):
    async with app_sm() as s:
        job, _ = await create_job_idempotent(
            s,
            source_url="https://www.youtube.com/watch?v=d2",
            source_type="song",
            token_id=token_id,
        )
        await s.commit()

    async with app_sm() as s:
        with pytest.raises(InvalidStateTransition):
            await mark_done(s, job.id)


# ---- mark_failed ----------------------------------------------------------


async def test_mark_failed_from_queued(app_sm, token_id, cleanup_jobs):
    async with app_sm() as s:
        job, _ = await create_job_idempotent(
            s,
            source_url="https://www.youtube.com/watch?v=f1",
            source_type="song",
            token_id=token_id,
        )
        await s.commit()
        job_id = job.id

    async with app_sm() as s:
        await mark_failed(s, job_id, "validation died")
        await s.commit()

    async with app_sm() as s:
        row = (await s.execute(select(Job).where(Job.id == job_id))).scalar_one()
        assert row.state == "failed"
        assert row.finished_at is not None
        assert row.error_msg == "validation died"


async def test_mark_failed_from_running(app_sm, token_id, cleanup_jobs):
    async with app_sm() as s:
        job, _ = await create_job_idempotent(
            s,
            source_url="https://www.youtube.com/watch?v=f2",
            source_type="song",
            token_id=token_id,
        )
        await s.commit()
        await mark_running(s, job.id)
        await s.commit()

    async with app_sm() as s:
        await mark_failed(s, job.id, "spotdl crashed")
        await s.commit()

    async with app_sm() as s:
        row = (await s.execute(select(Job).where(Job.id == job.id))).scalar_one()
        assert row.state == "failed"
        assert row.error_msg == "spotdl crashed"


async def test_mark_failed_rejects_done(app_sm, token_id, cleanup_jobs):
    async with app_sm() as s:
        job, _ = await create_job_idempotent(
            s,
            source_url="https://www.youtube.com/watch?v=f3",
            source_type="song",
            token_id=token_id,
        )
        await s.commit()
        await mark_running(s, job.id)
        await mark_done(s, job.id)
        await s.commit()

    async with app_sm() as s:
        with pytest.raises(InvalidStateTransition):
            await mark_failed(s, job.id, "too late")


# ---- bump_attempt ---------------------------------------------------------


async def test_bump_attempt_increments(app_sm, token_id, cleanup_jobs):
    async with app_sm() as s:
        job, _ = await create_job_idempotent(
            s,
            source_url="https://www.youtube.com/watch?v=b1",
            source_type="song",
            token_id=token_id,
        )
        await s.commit()
        job_id = job.id

    async with app_sm() as s:
        await bump_attempt(s, job_id)
        await bump_attempt(s, job_id)
        await s.commit()

    async with app_sm() as s:
        row = (await s.execute(select(Job).where(Job.id == job_id))).scalar_one()
        assert row.attempt_count == 2


# ---- finders --------------------------------------------------------------


async def test_find_active_for_url_returns_active(app_sm, token_id, cleanup_jobs):
    async with app_sm() as s:
        job, _ = await create_job_idempotent(
            s,
            source_url="https://www.youtube.com/watch?v=find-a",
            source_type="song",
            token_id=token_id,
        )
        await s.commit()

    async with app_sm() as s:
        found = await find_active_for_url(s, "https://www.youtube.com/watch?v=find-a")
    assert found is not None
    assert found.id == job.id


async def test_find_active_for_url_returns_none_after_done(app_sm, token_id, cleanup_jobs):
    async with app_sm() as s:
        job, _ = await create_job_idempotent(
            s,
            source_url="https://www.youtube.com/watch?v=find-b",
            source_type="song",
            token_id=token_id,
        )
        await s.commit()
        await mark_running(s, job.id)
        await mark_done(s, job.id)
        await s.commit()

    async with app_sm() as s:
        found = await find_active_for_url(s, "https://www.youtube.com/watch?v=find-b")
    assert found is None


async def test_find_download_for_song_returns_download(app_sm, token_id, cleanup_jobs):
    async with app_sm() as s:
        job, _ = await create_job_idempotent(
            s,
            source_url="https://www.youtube.com/watch?v=find-dl",
            source_type="song",
            token_id=token_id,
        )
        await s.commit()
        s.add(
            Download(
                source_url="https://www.youtube.com/watch?v=find-dl",
                job_id=job.id,
                output_path="/data/media/music/x.mp3",
            )
        )
        await s.commit()

    async with app_sm() as s:
        dl = await find_download_for_song(s, "https://www.youtube.com/watch?v=find-dl")
    assert dl is not None
    assert dl.output_path == "/data/media/music/x.mp3"


async def test_find_download_for_song_returns_none(app_sm, cleanup_jobs):
    async with app_sm() as s:
        dl = await find_download_for_song(s, "https://www.youtube.com/watch?v=missing")
    assert dl is None
