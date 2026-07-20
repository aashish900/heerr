import hashlib
import uuid

import pytest
import sqlalchemy as sa
from sqlalchemy import text

from app.models import Job, PodcastChannel, PodcastEpisode, Token
from app.services.podcast_download import DownloadedEpisode, EpisodeDownloadError
from app.services.workers import run_podcast_episode_job

_FEED_URL = "https://example.com/feed.xml"
_ENCLOSURE_URL = "https://example.com/ep1.mp3"


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
async def cleanup(app_sm):
    yield
    async with app_sm() as s:
        await s.execute(text("DELETE FROM jobs"))
        await s.execute(text("DELETE FROM podcast_episode"))
        await s.execute(text("DELETE FROM podcast_channel"))
        await s.commit()


@pytest.fixture
async def episode_id(app_sm, cleanup):
    async with app_sm() as s:
        channel = PodcastChannel(feed_url=_FEED_URL, title="Test Show")
        s.add(channel)
        await s.flush()
        episode = PodcastEpisode(
            channel_id=channel.id,
            guid="ep-1",
            title="Episode 1",
            enclosure_url=_ENCLOSURE_URL,
            enclosure_type="audio/mpeg",
        )
        s.add(episode)
        await s.commit()
        return episode.id


async def _seed_queued_episode_job(app_sm, token_id, episode_id):
    job = Job(
        source_url=_ENCLOSURE_URL,
        source_type="episode",
        state="queued",
        created_by_token_id=token_id,
        user_id=sa.func.system_admin_user_id(),
        episode_id=episode_id,
    )
    async with app_sm() as s:
        s.add(job)
        await s.commit()
        await s.refresh(job)
        return job.id


async def test_happy_path_marks_done_and_updates_episode(app_sm, token_id, episode_id, tmp_path):
    job_id = await _seed_queued_episode_job(app_sm, token_id, episode_id)
    file_path = str(tmp_path / f"{episode_id}.mp3")
    captured: dict = {}

    async def fake_downloader(enclosure_url, output_dir, *, episode_id, enclosure_type):
        captured["url"] = enclosure_url
        captured["dir"] = output_dir
        captured["episode_id"] = episode_id
        captured["type"] = enclosure_type
        return DownloadedEpisode(path=file_path, size_bytes=999)

    await run_podcast_episode_job(
        job_id, sm=app_sm, downloader=fake_downloader, output_dir=str(tmp_path)
    )

    assert captured["url"] == _ENCLOSURE_URL
    assert captured["type"] == "audio/mpeg"

    async with app_sm() as s:
        job = await s.get(Job, job_id)
        assert job.state == "done"
        ep = await s.get(PodcastEpisode, episode_id)
        assert ep.downloaded_path == file_path
        assert ep.downloaded_bytes == 999
        assert ep.downloaded_at is not None


async def test_download_failure_marks_job_failed(app_sm, token_id, episode_id, tmp_path):
    job_id = await _seed_queued_episode_job(app_sm, token_id, episode_id)

    async def failing_downloader(*args, **kwargs):
        raise EpisodeDownloadError("upstream 500")

    await run_podcast_episode_job(
        job_id, sm=app_sm, downloader=failing_downloader, output_dir=str(tmp_path)
    )

    async with app_sm() as s:
        job = await s.get(Job, job_id)
        assert job.state == "failed"
        assert "upstream 500" in job.error_msg
        ep = await s.get(PodcastEpisode, episode_id)
        assert ep.downloaded_path is None


async def test_missing_job_is_a_noop(app_sm, tmp_path):
    async def unused_downloader(*args, **kwargs):
        raise AssertionError("should not be called")

    await run_podcast_episode_job(
        uuid.uuid4(), sm=app_sm, downloader=unused_downloader, output_dir=str(tmp_path)
    )


async def test_non_queued_job_is_skipped(app_sm, token_id, episode_id, tmp_path):
    job_id = await _seed_queued_episode_job(app_sm, token_id, episode_id)
    async with app_sm() as s:
        job = await s.get(Job, job_id)
        job.state = "done"
        await s.commit()

    async def unused_downloader(*args, **kwargs):
        raise AssertionError("should not be called")

    await run_podcast_episode_job(
        job_id, sm=app_sm, downloader=unused_downloader, output_dir=str(tmp_path)
    )

    async with app_sm() as s:
        job = await s.get(Job, job_id)
        assert job.state == "done"


async def test_job_without_episode_id_is_a_noop(app_sm, token_id, tmp_path, cleanup):
    job = Job(
        source_url=_ENCLOSURE_URL,
        source_type="episode",
        state="queued",
        created_by_token_id=token_id,
        user_id=sa.func.system_admin_user_id(),
        episode_id=None,
    )
    # episode_id is None here because the FK is ON DELETE SET NULL; simulate
    # the "episode vanished mid-flight" case by pointing directly at a job
    # whose episode_id references nothing (impossible via FK normally, so
    # instead we assert the job-missing-episode_id early-return path).
    async with app_sm() as s:
        s.add(job)
        await s.commit()
        await s.refresh(job)
        job_id = job.id

    async def unused_downloader(*args, **kwargs):
        raise AssertionError("should not be called")

    await run_podcast_episode_job(
        job_id, sm=app_sm, downloader=unused_downloader, output_dir=str(tmp_path)
    )

    async with app_sm() as s:
        job = await s.get(Job, job_id)
        # episode_id was None, so this job is treated as "not an episode job"
        # and left untouched (queued) rather than failed.
        assert job.state == "queued"
