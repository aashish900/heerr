import pytest

from app.config import Settings
from app.services.podcastindex import PodcastIndexClient, PodcastIndexNotConfigured

_REQUIRED_ENV = {
    "DATABASE_URL": "postgresql+asyncpg://u:p@h/d",
    "MUSIC_OUTPUT_DIR": "/data/media/music",
    "NAVIDROME_URL": "http://navidrome.example:4533",
}


def _settings(**overrides) -> Settings:
    return Settings(**_REQUIRED_ENV, **overrides)


async def test_search_raises_when_not_configured():
    client = PodcastIndexClient(_settings())
    with pytest.raises(PodcastIndexNotConfigured):
        await client.search("news", 10)


async def test_search_raises_when_only_key_set():
    client = PodcastIndexClient(_settings(podcastindex_key="k"))
    with pytest.raises(PodcastIndexNotConfigured):
        await client.search("news", 10)


def test_auth_headers_shape():
    client = PodcastIndexClient(_settings(podcastindex_key="k", podcastindex_secret="s"))
    headers = client._auth_headers()
    assert headers["X-Auth-Key"] == "k"
    assert headers["X-Auth-Date"].isdigit()
    assert len(headers["Authorization"]) == 40  # sha1 hex digest
    assert headers["User-Agent"]
