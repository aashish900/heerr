import httpx
import pytest
from sqlalchemy import select

from app.models import PodcastChannel, PodcastEpisode
from app.services import feeds
from app.services.feeds import (
    FeedFetchError,
    _parse_duration,
    fetch_feed,
    ingest_feed,
)

_FEED_URL = "https://example.com/feed.xml"

_SAMPLE_RSS = """<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
<channel>
<title>Test Show</title>
<description>A show about tests</description>
<itunes:author>Test Author</itunes:author>
<image><url>https://example.com/art.jpg</url></image>
<item>
<title>Episode 1</title>
<guid>ep-1</guid>
<description>First episode</description>
<pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate>
<itunes:duration>1800</itunes:duration>
<enclosure url="https://example.com/ep1.mp3" type="audio/mpeg" length="123456"/>
<itunes:episode>1</itunes:episode>
<itunes:season>1</itunes:season>
</item>
<item>
<title>Episode 2</title>
<guid>ep-2</guid>
<description>Second episode</description>
<pubDate>Tue, 02 Jan 2024 00:00:00 GMT</pubDate>
<itunes:duration>25:00</itunes:duration>
<enclosure url="https://example.com/ep2.mp3" type="audio/mpeg" length="234567"/>
</item>
</channel>
</rss>
"""


_RealAsyncClient = httpx.AsyncClient


def _mock_client_factory(handler):
    def _factory(*args, **kwargs):
        return _RealAsyncClient(transport=httpx.MockTransport(handler))

    return _factory


# ---- _parse_duration --------------------------------------------------------


@pytest.mark.parametrize(
    "raw,expected",
    [
        (None, None),
        ("", None),
        ("1800", 1800),
        ("25:00", 1500),
        ("01:25:00", 5100),
        ("garbage", None),
    ],
)
def test_parse_duration(raw, expected):
    assert _parse_duration(raw) == expected


# ---- fetch_feed --------------------------------------------------------------


async def test_fetch_feed_parses_channel_and_episodes(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            content=_SAMPLE_RSS,
            headers={"etag": "abc123", "last-modified": "Wed, 01 Jan 2025 00:00:00 GMT"},
        )

    monkeypatch.setattr(feeds.httpx, "AsyncClient", _mock_client_factory(handler))

    parsed = await fetch_feed(_FEED_URL)
    assert parsed is not None
    assert parsed.title == "Test Show"
    assert parsed.author == "Test Author"
    assert parsed.description == "A show about tests"
    assert parsed.image_url == "https://example.com/art.jpg"
    assert parsed.etag == "abc123"
    assert len(parsed.episodes) == 2

    ep1, ep2 = parsed.episodes
    assert ep1.guid == "ep-1"
    assert ep1.duration_s == 1800
    assert ep1.enclosure_url == "https://example.com/ep1.mp3"
    assert ep1.enclosure_bytes == 123456
    assert ep1.episode_no == 1
    assert ep1.season_no == 1

    assert ep2.guid == "ep-2"
    assert ep2.duration_s == 1500
    assert ep2.episode_no is None


async def test_fetch_feed_304_returns_none(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers.get("if-none-match") == "cached-etag"
        return httpx.Response(304)

    monkeypatch.setattr(feeds.httpx, "AsyncClient", _mock_client_factory(handler))

    parsed = await fetch_feed(_FEED_URL, etag="cached-etag")
    assert parsed is None


async def test_fetch_feed_http_error_raises(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500)

    monkeypatch.setattr(feeds.httpx, "AsyncClient", _mock_client_factory(handler))

    with pytest.raises(FeedFetchError):
        await fetch_feed(_FEED_URL)


async def test_fetch_feed_network_error_raises(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("no route to host")

    monkeypatch.setattr(feeds.httpx, "AsyncClient", _mock_client_factory(handler))

    with pytest.raises(FeedFetchError):
        await fetch_feed(_FEED_URL)


async def test_fetch_feed_malformed_body_raises(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=b"not xml at all")

    monkeypatch.setattr(feeds.httpx, "AsyncClient", _mock_client_factory(handler))

    with pytest.raises(FeedFetchError):
        await fetch_feed(_FEED_URL)


# ---- ingest_feed (DB round trip) --------------------------------------------


async def test_ingest_feed_creates_channel_and_episodes(monkeypatch, app_sm):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=_SAMPLE_RSS, headers={"etag": "v1"})

    monkeypatch.setattr(feeds.httpx, "AsyncClient", _mock_client_factory(handler))

    async with app_sm() as s:
        channel = await ingest_feed(s, _FEED_URL)
        await s.commit()
        assert channel.title == "Test Show"
        assert channel.http_etag == "v1"

        eps = (
            (await s.execute(select(PodcastEpisode).where(PodcastEpisode.channel_id == channel.id)))
            .scalars()
            .all()
        )
        assert {e.guid for e in eps} == {"ep-1", "ep-2"}


async def test_ingest_feed_is_idempotent_on_resubscribe(monkeypatch, app_sm):
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=_SAMPLE_RSS, headers={"etag": "v1"})

    monkeypatch.setattr(feeds.httpx, "AsyncClient", _mock_client_factory(handler))

    async with app_sm() as s:
        c1 = await ingest_feed(s, _FEED_URL)
        await s.commit()
    async with app_sm() as s:
        c2 = await ingest_feed(s, _FEED_URL)
        await s.commit()
        assert c1.id == c2.id

        channels = (
            (await s.execute(select(PodcastChannel).where(PodcastChannel.feed_url == _FEED_URL)))
            .scalars()
            .all()
        )
        assert len(channels) == 1

        eps = (
            (await s.execute(select(PodcastEpisode).where(PodcastEpisode.channel_id == c2.id)))
            .scalars()
            .all()
        )
        assert len(eps) == 2


async def test_ingest_feed_304_leaves_episodes_untouched(monkeypatch, app_sm):
    def handler_200(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=_SAMPLE_RSS, headers={"etag": "v1"})

    monkeypatch.setattr(feeds.httpx, "AsyncClient", _mock_client_factory(handler_200))
    async with app_sm() as s:
        channel = await ingest_feed(s, _FEED_URL)
        await s.commit()
        channel_id = channel.id

    async with app_sm() as s:
        ep = (
            await s.execute(
                select(PodcastEpisode).where(
                    PodcastEpisode.channel_id == channel_id, PodcastEpisode.guid == "ep-1"
                )
            )
        ).scalar_one()
        ep.downloaded_path = "/data/media/podcasts/ep1.mp3"
        await s.commit()

    def handler_304(request: httpx.Request) -> httpx.Response:
        return httpx.Response(304)

    monkeypatch.setattr(feeds.httpx, "AsyncClient", _mock_client_factory(handler_304))
    async with app_sm() as s:
        channel = await ingest_feed(s, _FEED_URL)
        await s.commit()
        assert channel.id == channel_id
        assert channel.last_fetched_at is not None

    async with app_sm() as s:
        ep = (
            await s.execute(
                select(PodcastEpisode).where(
                    PodcastEpisode.channel_id == channel_id, PodcastEpisode.guid == "ep-1"
                )
            )
        ).scalar_one()
        assert ep.downloaded_path == "/data/media/podcasts/ep1.mp3"


async def test_ingest_feed_new_episode_added_existing_untouched(monkeypatch, app_sm):
    def handler_v1(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=_SAMPLE_RSS, headers={"etag": "v1"})

    monkeypatch.setattr(feeds.httpx, "AsyncClient", _mock_client_factory(handler_v1))
    async with app_sm() as s:
        channel = await ingest_feed(s, _FEED_URL)
        await s.commit()
        channel_id = channel.id

    async with app_sm() as s:
        ep = (
            await s.execute(
                select(PodcastEpisode).where(
                    PodcastEpisode.channel_id == channel_id, PodcastEpisode.guid == "ep-1"
                )
            )
        ).scalar_one()
        ep.downloaded_path = "/data/media/podcasts/ep1.mp3"
        await s.commit()

    rss_with_new_episode = _SAMPLE_RSS.replace(
        "</channel>",
        "<item><title>Episode 3</title><guid>ep-3</guid>"
        '<enclosure url="https://example.com/ep3.mp3" type="audio/mpeg"/></item>'
        "</channel>",
    )

    def handler_v2(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, content=rss_with_new_episode, headers={"etag": "v2"})

    monkeypatch.setattr(feeds.httpx, "AsyncClient", _mock_client_factory(handler_v2))
    async with app_sm() as s:
        await ingest_feed(s, _FEED_URL)
        await s.commit()

    async with app_sm() as s:
        eps = (
            (await s.execute(select(PodcastEpisode).where(PodcastEpisode.channel_id == channel_id)))
            .scalars()
            .all()
        )
        assert {e.guid for e in eps} == {"ep-1", "ep-2", "ep-3"}
        ep1 = next(e for e in eps if e.guid == "ep-1")
        assert ep1.downloaded_path == "/data/media/podcasts/ep1.mp3"
