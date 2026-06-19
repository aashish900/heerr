import hashlib
import uuid

import pytest
import sqlalchemy as sa
from sqlalchemy import func, select, text

from app.models import Download, Job, Token, User
from app.services.jobs import find_download_for_song
from app.services.spotdl_runner import DownloadedFile, SpotdlError
from app.services.workers import run_job

# ---- shared local fixtures ------------------------------------------------


@pytest.fixture
async def token_id(app_sm):
    h = hashlib.sha256(f"raw-{uuid.uuid4()}".encode()).hexdigest()
    async with app_sm() as s:
        tok = Token(
            token_hash=h,
            user_id=sa.func.system_admin_user_id(),
            scopes=["read", "download"],
        )
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


async def _seed_queued_job(app_sm, token_id, source_url, source_type="song"):
    job = Job(
        source_url=source_url,
        source_type=source_type,
        state="queued",
        created_by_token_id=token_id,
        user_id=sa.func.system_admin_user_id(),
    )
    async with app_sm() as s:
        s.add(job)
        await s.commit()
        await s.refresh(job)
        return job.id


async def _count_downloads(app_sm, job_id):
    async with app_sm() as s:
        return (
            await s.execute(
                select(func.count()).select_from(Download).where(Download.job_id == job_id)
            )
        ).scalar_one()


# ---- happy paths ----------------------------------------------------------


async def test_run_job_track_happy_path_writes_download_row(
    app_sm, token_id, tmp_path, cleanup_jobs
):
    uri = "https://www.youtube.com/watch?v=t1"
    job_id = await _seed_queued_job(app_sm, token_id, uri)

    file_path = str(tmp_path / "song.mp3")
    captured: dict = {}

    async def fake_runner(source_url, output_dir):
        captured["uri"] = source_url
        captured["dir"] = output_dir
        return [DownloadedFile(path=file_path, size_bytes=12345)]

    await run_job(
        job_id,
        sm=app_sm,
        runner=fake_runner,
        output_dir=str(tmp_path),
    )

    assert captured["uri"] == uri
    assert captured["dir"] == str(tmp_path)

    async with app_sm() as s:
        j = await s.get(Job, job_id)
        assert j.state == "done"
        assert j.started_at is not None
        assert j.finished_at is not None
        assert j.error_msg is None

        dl = (await s.execute(select(Download).where(Download.job_id == job_id))).scalar_one()
        assert dl.source_url == uri
        assert dl.output_path == file_path
        assert dl.file_size_bytes == 12345


async def test_run_job_track_with_no_produced_files_marks_failed(
    app_sm, token_id, tmp_path, cleanup_jobs
):
    """spotDL exits 0 but produces no file — treat as failure, not silent done."""
    uri = "https://www.youtube.com/watch?v=noop"
    job_id = await _seed_queued_job(app_sm, token_id, uri)

    async def fake_runner(source_url, output_dir):
        return []

    await run_job(job_id, sm=app_sm, runner=fake_runner, output_dir=str(tmp_path))

    async with app_sm() as s:
        j = await s.get(Job, job_id)
        assert j.state == "failed"
        assert "no audio file" in j.error_msg
    assert await _count_downloads(app_sm, job_id) == 0


async def test_run_job_album_does_not_write_download_rows(app_sm, token_id, tmp_path, cleanup_jobs):
    """v1 limitation: album/playlist jobs produce files but no DB rows."""
    uri = "https://music.youtube.com/browse/al1"
    job_id = await _seed_queued_job(app_sm, token_id, uri, source_type="album")

    async def fake_runner(source_url, output_dir):
        return [
            DownloadedFile(path=str(tmp_path / "01.mp3"), size_bytes=100),
            DownloadedFile(path=str(tmp_path / "02.mp3"), size_bytes=200),
        ]

    await run_job(job_id, sm=app_sm, runner=fake_runner, output_dir=str(tmp_path))

    async with app_sm() as s:
        j = await s.get(Job, job_id)
        assert j.state == "done"
    assert await _count_downloads(app_sm, job_id) == 0


async def test_run_job_playlist_does_not_write_download_rows(
    app_sm, token_id, tmp_path, cleanup_jobs
):
    uri = "https://music.youtube.com/browse/pl1"
    job_id = await _seed_queued_job(app_sm, token_id, uri, source_type="playlist")

    async def fake_runner(source_url, output_dir):
        return [DownloadedFile(path=str(tmp_path / "a.mp3"), size_bytes=500)]

    await run_job(job_id, sm=app_sm, runner=fake_runner, output_dir=str(tmp_path))

    async with app_sm() as s:
        j = await s.get(Job, job_id)
        assert j.state == "done"
    assert await _count_downloads(app_sm, job_id) == 0


# ---- failure paths --------------------------------------------------------


async def test_run_job_spotdl_error_marks_failed_with_error_msg(
    app_sm, token_id, tmp_path, cleanup_jobs
):
    uri = "https://www.youtube.com/watch?v=bad"
    job_id = await _seed_queued_job(app_sm, token_id, uri)

    async def fake_runner(source_url, output_dir):
        raise SpotdlError(exit_code=1, stderr_tail="youtube unavailable")

    await run_job(job_id, sm=app_sm, runner=fake_runner, output_dir=str(tmp_path))

    async with app_sm() as s:
        j = await s.get(Job, job_id)
        assert j.state == "failed"
        assert j.finished_at is not None
        assert j.started_at is not None  # phase 1 ran before failure
        assert j.error_msg is not None
        assert "SpotdlError" in j.error_msg

    assert await _count_downloads(app_sm, job_id) == 0


async def test_run_job_generic_exception_marks_failed(app_sm, token_id, tmp_path, cleanup_jobs):
    uri = "https://www.youtube.com/watch?v=boom"
    job_id = await _seed_queued_job(app_sm, token_id, uri)

    async def fake_runner(source_url, output_dir):
        raise RuntimeError("unexpected crash")

    await run_job(job_id, sm=app_sm, runner=fake_runner, output_dir=str(tmp_path))

    async with app_sm() as s:
        j = await s.get(Job, job_id)
        assert j.state == "failed"
        assert "RuntimeError" in j.error_msg
        assert "unexpected crash" in j.error_msg
    assert await _count_downloads(app_sm, job_id) == 0


async def test_run_job_error_msg_truncated(app_sm, token_id, tmp_path, cleanup_jobs):
    """A spotDL error with a 100 KB stderr should not blow up the column."""
    uri = "https://www.youtube.com/watch?v=huge-err"
    job_id = await _seed_queued_job(app_sm, token_id, uri)

    huge = "x" * 100_000

    async def fake_runner(source_url, output_dir):
        raise SpotdlError(exit_code=1, stderr_tail=huge)

    await run_job(job_id, sm=app_sm, runner=fake_runner, output_dir=str(tmp_path))

    async with app_sm() as s:
        j = await s.get(Job, job_id)
        assert j.state == "failed"
        assert len(j.error_msg) <= 2000


# ---- edge cases -----------------------------------------------------------


async def test_run_job_missing_job_is_noop(app_sm, tmp_path):
    """Job was deleted between dispatch and run (rare race)."""
    runner_calls: list[str] = []

    async def fake_runner(source_url, output_dir):
        runner_calls.append(source_url)
        return []

    # Should not raise.
    await run_job(
        uuid.uuid4(),
        sm=app_sm,
        runner=fake_runner,
        output_dir=str(tmp_path),
    )
    assert runner_calls == []


async def test_run_job_non_queued_job_is_noop(app_sm, token_id, tmp_path, cleanup_jobs):
    """Job already running (e.g., duplicate dispatch). No double-run."""
    uri = "https://www.youtube.com/watch?v=running"
    job = Job(
        source_url=uri,
        source_type="song",
        state="running",  # not queued
        created_by_token_id=token_id,
        user_id=sa.func.system_admin_user_id(),
    )
    async with app_sm() as s:
        s.add(job)
        await s.commit()
        await s.refresh(job)
        job_id = job.id

    runner_calls: list[str] = []

    async def fake_runner(source_url, output_dir):
        runner_calls.append(source_url)
        return []

    await run_job(job_id, sm=app_sm, runner=fake_runner, output_dir=str(tmp_path))

    assert runner_calls == []  # never invoked

    async with app_sm() as s:
        j = await s.get(Job, job_id)
        assert j.state == "running"  # state unchanged


async def test_run_job_per_user_download_rows_for_shared_url(app_sm, tmp_path):
    """DEBT M3: two users downloading the same song each get their own Download
    row (composite unique on (user_id, source_url)), so each user's dedupe hint
    stays correct. Pre-M3 the second user's row was swallowed by the global
    ON CONFLICT (source_url) DO NOTHING, leaving their hint permanently wrong.
    """
    url = "https://www.youtube.com/watch?v=m3-shared"
    file_path = str(tmp_path / "shared.mp3")

    async def fake_runner(source_url, output_dir):
        return [DownloadedFile(path=file_path, size_bytes=42)]

    async with app_sm() as s:
        ua = User(navidrome_username=f"alice-{uuid.uuid4().hex[:8]}")
        ub = User(navidrome_username=f"bob-{uuid.uuid4().hex[:8]}")
        s.add_all([ua, ub])
        await s.flush()
        tok_a = Token(
            token_hash=hashlib.sha256(f"a-{uuid.uuid4()}".encode()).hexdigest(),
            scopes=["read", "download"],
            user_id=ua.id,
        )
        tok_b = Token(
            token_hash=hashlib.sha256(f"b-{uuid.uuid4()}".encode()).hexdigest(),
            scopes=["read", "download"],
            user_id=ub.id,
        )
        s.add_all([tok_a, tok_b])
        await s.flush()
        job_a = Job(
            source_url=url,
            source_type="song",
            state="queued",
            created_by_token_id=tok_a.id,
            user_id=ua.id,
        )
        job_b = Job(
            source_url=url,
            source_type="song",
            state="queued",
            created_by_token_id=tok_b.id,
            user_id=ub.id,
        )
        s.add_all([job_a, job_b])
        await s.commit()
        ua_id, ub_id = ua.id, ub.id
        tok_a_id, tok_b_id = tok_a.id, tok_b.id
        job_a_id, job_b_id = job_a.id, job_b.id

    try:
        await run_job(job_a_id, sm=app_sm, runner=fake_runner, output_dir=str(tmp_path))
        await run_job(job_b_id, sm=app_sm, runner=fake_runner, output_dir=str(tmp_path))

        async with app_sm() as s:
            rows = (
                (await s.execute(select(Download).where(Download.source_url == url)))
                .scalars()
                .all()
            )
            assert len(rows) == 2
            assert {r.user_id for r in rows} == {ua_id, ub_id}

            dl_a = await find_download_for_song(s, url, user_id=ua_id)
            dl_b = await find_download_for_song(s, url, user_id=ub_id)
            assert dl_a is not None and dl_a.user_id == ua_id
            assert dl_b is not None and dl_b.user_id == ub_id
    finally:
        async with app_sm() as s:
            await s.execute(text("DELETE FROM downloads"))
            await s.execute(text("DELETE FROM jobs"))
            for tid in (tok_a_id, tok_b_id):
                await s.execute(text("DELETE FROM tokens WHERE id = :i"), {"i": tid})
            for uid in (ua_id, ub_id):
                await s.execute(text("DELETE FROM users WHERE id = :i"), {"i": uid})
            await s.commit()


async def test_run_job_completes_after_creating_token_revoked(
    app_sm, token_id, tmp_path, cleanup_jobs
):
    """DEBT M4: revoking a token must not cancel in-flight jobs it created.

    Worker holds the job by id and does not recheck token validity. Pinning
    this contract so future auth changes do not silently break it.
    """
    uri = "https://www.youtube.com/watch?v=after-revoke"
    job_id = await _seed_queued_job(app_sm, token_id, uri)

    async with app_sm() as s:
        await s.execute(text("UPDATE tokens SET revoked_at = now() WHERE id = :i"), {"i": token_id})
        await s.commit()

    file_path = str(tmp_path / "post-revoke.mp3")

    async def fake_runner(source_url, output_dir):
        return [DownloadedFile(path=file_path, size_bytes=999)]

    await run_job(job_id, sm=app_sm, runner=fake_runner, output_dir=str(tmp_path))

    async with app_sm() as s:
        j = await s.get(Job, job_id)
        assert j.state == "done"
        assert j.error_msg is None
        dl = (await s.execute(select(Download).where(Download.job_id == job_id))).scalar_one()
        assert dl.output_path == file_path
