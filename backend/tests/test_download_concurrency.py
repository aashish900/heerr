"""MX1 — downloads run at most N at a time (`DOWNLOAD_CONCURRENCY`).

Each test injects its own `slots` semaphore, mirroring how `runner` /
`downloader` are injected, so it does not depend on the process-wide default.
A job waiting for a slot must stay `queued` (the Queue screen tells the truth).
"""

import asyncio
import hashlib
import uuid

import pytest
import sqlalchemy as sa
from pydantic import ValidationError
from sqlalchemy import select, text

from app.config import Settings
from app.models import Job, PodcastChannel, PodcastEpisode, Token
from app.services.podcast_download import DownloadedEpisode
from app.services.spotdl_runner import DownloadedFile
from app.services.workers import run_job, run_podcast_episode_job


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
        await s.execute(text("DELETE FROM downloads"))
        await s.execute(text("DELETE FROM jobs"))
        await s.execute(text("DELETE FROM podcast_episode"))
        await s.execute(text("DELETE FROM podcast_channel"))
        await s.execute(text("DELETE FROM tokens WHERE id = :i"), {"i": tid})
        await s.commit()


async def _queued_song(app_sm, token_id, n: int) -> uuid.UUID:
    async with app_sm() as s:
        job = Job(
            source_url=f"https://www.youtube.com/watch?v=mx1-{n}",
            source_type="song",
            state="queued",
            created_by_token_id=token_id,
            user_id=sa.func.system_admin_user_id(),
        )
        s.add(job)
        await s.commit()
        await s.refresh(job)
        return job.id


async def _states(app_sm, ids) -> list[str]:
    async with app_sm() as s:
        rows = (await s.execute(select(Job.id, Job.state).where(Job.id.in_(ids)))).all()
    by_id = dict(rows)
    return [by_id[i] for i in ids]


async def _wait_for(pred, timeout=5.0):
    async def loop():
        while not pred():
            await asyncio.sleep(0.01)

    await asyncio.wait_for(loop(), timeout)


async def test_at_most_n_songs_run_at_once_and_waiters_stay_queued(app_sm, token_id, tmp_path):
    ids = [await _queued_song(app_sm, token_id, n) for n in range(5)]
    release = asyncio.Event()
    live = {"now": 0, "max": 0}

    async def runner(source_url, output_dir):
        live["now"] += 1
        live["max"] = max(live["max"], live["now"])
        await release.wait()
        live["now"] -= 1
        return [DownloadedFile(path=str(tmp_path / f"{source_url[-5:]}.mp3"), size_bytes=1)]

    slots = asyncio.Semaphore(2)
    tasks = [
        asyncio.create_task(
            run_job(j, sm=app_sm, runner=runner, output_dir=str(tmp_path), slots=slots)
        )
        for j in ids
    ]
    await _wait_for(lambda: live["now"] == 2)
    await asyncio.sleep(0.05)  # give the other three every chance to (wrongly) start

    states = await _states(app_sm, ids)
    assert states.count("running") == 2
    assert states.count("queued") == 3

    release.set()
    await asyncio.gather(*tasks)
    assert live["max"] == 2
    assert await _states(app_sm, ids) == ["done"] * 5


async def test_failed_download_frees_its_slot(app_sm, token_id, tmp_path):
    bad, good = await _queued_song(app_sm, token_id, 1), await _queued_song(app_sm, token_id, 2)

    async def runner(source_url, output_dir):
        if source_url.endswith("mx1-1"):
            raise RuntimeError("spotdl exploded")
        return [DownloadedFile(path=str(tmp_path / "ok.mp3"), size_bytes=1)]

    slots = asyncio.Semaphore(1)
    await asyncio.wait_for(
        asyncio.gather(
            run_job(bad, sm=app_sm, runner=runner, output_dir=str(tmp_path), slots=slots),
            run_job(good, sm=app_sm, runner=runner, output_dir=str(tmp_path), slots=slots),
        ),
        timeout=5,
    )
    assert await _states(app_sm, [bad, good]) == ["failed", "done"]


async def test_episode_download_waits_for_a_slot(app_sm, token_id, tmp_path):
    async with app_sm() as s:
        ch = PodcastChannel(feed_url="https://example.com/mx1.xml", title="MX1 Show")
        s.add(ch)
        await s.flush()
        ep = PodcastEpisode(
            channel_id=ch.id,
            guid="mx1-ep",
            title="Ep",
            enclosure_url="https://example.com/mx1.mp3",
            enclosure_type="audio/mpeg",
        )
        s.add(ep)
        await s.flush()
        job = Job(
            source_url=ep.enclosure_url,
            source_type="episode",
            state="queued",
            created_by_token_id=token_id,
            user_id=sa.func.system_admin_user_id(),
            episode_id=ep.id,
        )
        s.add(job)
        await s.commit()
        job_id = job.id

    called = asyncio.Event()

    async def downloader(url, output_dir, *, episode_id, enclosure_type):
        called.set()
        return DownloadedEpisode(path=str(tmp_path / "ep.mp3"), size_bytes=1)

    slots = asyncio.Semaphore(1)
    await slots.acquire()  # someone else holds the only slot
    task = asyncio.create_task(
        run_podcast_episode_job(
            job_id, sm=app_sm, downloader=downloader, output_dir=str(tmp_path), slots=slots
        )
    )
    await asyncio.sleep(0.05)
    assert not called.is_set()
    assert await _states(app_sm, [job_id]) == ["queued"]

    slots.release()
    await asyncio.wait_for(task, 5)
    assert called.is_set()
    assert await _states(app_sm, [job_id]) == ["done"]


def test_download_concurrency_setting_defaults_to_2_and_must_be_positive(monkeypatch):
    monkeypatch.delenv("DOWNLOAD_CONCURRENCY", raising=False)
    base = {
        "database_url": "postgresql://x/y",
        "music_output_dir": "/m",
        "navidrome_url": "http://n",
    }
    assert Settings(**base).download_concurrency == 2
    assert Settings(**base, download_concurrency=4).download_concurrency == 4
    with pytest.raises(ValidationError):
        Settings(**base, download_concurrency=0)
