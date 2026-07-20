import uuid
from pathlib import Path

import httpx
import pytest

from app.services import podcast_download
from app.services.podcast_download import (
    EpisodeDownloadError,
    _guess_extension,
    download_episode,
)

_RealAsyncClient = httpx.AsyncClient


def _mock_client_factory(handler):
    def _factory(*args, **kwargs):
        return _RealAsyncClient(transport=httpx.MockTransport(handler))

    return _factory


# ---- _guess_extension --------------------------------------------------------


@pytest.mark.parametrize(
    "url,mime,expected",
    [
        ("https://example.com/ep.mp3", "audio/mpeg", ".mp3"),
        ("https://example.com/ep", "audio/mp4", ".m4a"),
        ("https://example.com/ep", "audio/x-m4a", ".m4a"),
        ("https://example.com/ep", None, ".mp3"),
        ("https://example.com/ep.ogg", None, ".ogg"),
        ("https://example.com/ep", "application/octet-stream", ".mp3"),
        ("https://example.com/ep;param=1", "audio/mpeg; charset=binary", ".mp3"),
    ],
)
def test_guess_extension(url, mime, expected):
    assert _guess_extension(url, mime) == expected


# ---- download_episode --------------------------------------------------------


async def test_download_episode_writes_file(monkeypatch, tmp_path):
    body = b"fake-audio-bytes" * 100

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=body)

    monkeypatch.setattr(podcast_download.httpx, "AsyncClient", _mock_client_factory(handler))

    episode_id = uuid.uuid4()
    result = await download_episode(
        "https://example.com/ep.mp3",
        str(tmp_path),
        episode_id=episode_id,
        enclosure_type="audio/mpeg",
    )

    assert result.path == str(tmp_path / f"{episode_id}.mp3")
    assert result.size_bytes == len(body)
    assert Path(result.path).read_bytes() == body
    # no leftover temp file
    assert list(tmp_path.glob(".*")) == []


async def test_download_episode_creates_output_dir(monkeypatch, tmp_path):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=b"x")

    monkeypatch.setattr(podcast_download.httpx, "AsyncClient", _mock_client_factory(handler))

    nested = tmp_path / "nested" / "podcasts"
    episode_id = uuid.uuid4()
    result = await download_episode(
        "https://example.com/ep.mp3",
        str(nested),
        episode_id=episode_id,
        enclosure_type="audio/mpeg",
    )
    assert Path(result.path).exists()


async def test_download_episode_http_error_raises_and_cleans_up(monkeypatch, tmp_path):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(404)

    monkeypatch.setattr(podcast_download.httpx, "AsyncClient", _mock_client_factory(handler))

    with pytest.raises(EpisodeDownloadError):
        await download_episode(
            "https://example.com/missing.mp3",
            str(tmp_path),
            episode_id=uuid.uuid4(),
            enclosure_type="audio/mpeg",
        )
    assert list(tmp_path.glob("*")) == []


async def test_download_episode_network_error_raises_and_cleans_up(monkeypatch, tmp_path):
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("no route to host")

    monkeypatch.setattr(podcast_download.httpx, "AsyncClient", _mock_client_factory(handler))

    with pytest.raises(EpisodeDownloadError):
        await download_episode(
            "https://example.com/ep.mp3",
            str(tmp_path),
            episode_id=uuid.uuid4(),
            enclosure_type="audio/mpeg",
        )
    assert list(tmp_path.glob("*")) == []
