"""P3: RSS feed ingest — fetch, parse, and upsert podcast channels/episodes.

Refresh policy is on-demand only (subscribe / open-channel / manual refresh) —
no background scheduler (backend/CLAUDE.md: "no Celery until outgrown"). A
conditional GET (If-None-Match / If-Modified-Since) short-circuits unchanged
feeds without re-parsing.
"""

from __future__ import annotations

import asyncio
from calendar import timegm
from dataclasses import dataclass
from datetime import UTC, datetime
from time import struct_time
from typing import Any

import feedparser
import httpx
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import PodcastChannel, PodcastEpisode

# Some feeds carry thousands of entries; cap ingestion to the newest N so a
# single subscribe/refresh doesn't balloon the table or the request.
_MAX_EPISODES = 300
_FETCH_TIMEOUT_S = 15.0
_USER_AGENT = "heerr/1.0 (+podcast ingest)"


class FeedFetchError(Exception):
    pass


@dataclass(frozen=True)
class ParsedEpisode:
    guid: str
    title: str
    description: str | None
    published_at: datetime | None
    duration_s: int | None
    enclosure_url: str
    enclosure_type: str | None
    enclosure_bytes: int | None
    image_url: str | None
    episode_no: int | None
    season_no: int | None


@dataclass(frozen=True)
class ParsedFeed:
    title: str
    author: str | None
    description: str | None
    image_url: str | None
    categories: list[str]
    etag: str | None
    last_modified: str | None
    episodes: list[ParsedEpisode]


def _struct_time_to_dt(st: struct_time | None) -> datetime | None:
    if st is None:
        return None
    return datetime.fromtimestamp(timegm(st), tz=UTC)


def _parse_duration(raw: str | None) -> int | None:
    """`itunes:duration` is either plain seconds or `[HH:]MM:SS`."""
    if not raw:
        return None
    raw = raw.strip()
    if raw.isdigit():
        return int(raw)
    try:
        parts = [int(p) for p in raw.split(":")]
    except ValueError:
        return None
    seconds = 0
    for p in parts:
        seconds = seconds * 60 + p
    return seconds


def _parse_episode(entry: dict[str, Any]) -> ParsedEpisode | None:
    guid = entry.get("id") or entry.get("link")
    enclosures: list[dict[str, Any]] = entry.get("enclosures") or []
    audio_enclosure = next(
        (e for e in enclosures if (e.get("type") or "").startswith("audio")),
        enclosures[0] if enclosures else None,
    )
    if not guid or not audio_enclosure or not audio_enclosure.get("href"):
        return None

    image: dict[str, Any] = entry.get("image") or {}
    length_raw = audio_enclosure.get("length")
    try:
        enclosure_bytes = int(length_raw) if length_raw else None
    except (TypeError, ValueError):
        enclosure_bytes = None
    try:
        episode_no = int(entry["itunes_episode"]) if entry.get("itunes_episode") else None
    except (TypeError, ValueError):
        episode_no = None
    try:
        season_no = int(entry["itunes_season"]) if entry.get("itunes_season") else None
    except (TypeError, ValueError):
        season_no = None

    return ParsedEpisode(
        guid=guid,
        title=entry.get("title", ""),
        description=entry.get("summary"),
        published_at=_struct_time_to_dt(entry.get("published_parsed")),
        duration_s=_parse_duration(entry.get("itunes_duration")),
        enclosure_url=audio_enclosure["href"],
        enclosure_type=audio_enclosure.get("type"),
        enclosure_bytes=enclosure_bytes,
        image_url=image.get("href"),
        episode_no=episode_no,
        season_no=season_no,
    )


async def fetch_feed(
    feed_url: str,
    *,
    etag: str | None = None,
    last_modified: str | None = None,
) -> ParsedFeed | None:
    """Fetch + parse a feed. Returns None on a 304 (caller treats as a no-op)."""
    headers = {"User-Agent": _USER_AGENT}
    if etag:
        headers["If-None-Match"] = etag
    if last_modified:
        headers["If-Modified-Since"] = last_modified

    try:
        async with httpx.AsyncClient(timeout=_FETCH_TIMEOUT_S, follow_redirects=True) as client:
            resp = await client.get(feed_url, headers=headers)
    except httpx.HTTPError as exc:
        raise FeedFetchError(str(exc)) from exc

    if resp.status_code == 304:
        return None
    if resp.status_code >= 400:
        raise FeedFetchError(f"HTTP {resp.status_code} fetching {feed_url}")

    parsed = await asyncio.to_thread(feedparser.parse, resp.content)
    if parsed.bozo and not parsed.entries:
        raise FeedFetchError(f"unparseable feed: {parsed.get('bozo_exception')}")

    feed: dict[str, Any] = parsed.feed
    image: dict[str, Any] = feed.get("image") or {}
    authors: list[dict[str, Any]] = feed.get("authors") or [{}]
    author = feed.get("author") or authors[0].get("name")
    categories = [t["term"] for t in (feed.get("tags") or []) if t.get("term")]
    episodes = [
        ep
        for ep in (_parse_episode(entry) for entry in parsed.entries[:_MAX_EPISODES])
        if ep is not None
    ]

    return ParsedFeed(
        title=feed.get("title", feed_url),
        author=author,
        description=feed.get("subtitle") or feed.get("description"),
        image_url=image.get("href"),
        categories=categories,
        etag=resp.headers.get("etag"),
        last_modified=resp.headers.get("last-modified"),
        episodes=episodes,
    )


async def ingest_feed(session: AsyncSession, feed_url: str) -> PodcastChannel:
    """Fetch + upsert a channel and its episodes. Idempotent; safe to call repeatedly.

    An already-known channel uses a conditional GET, so an unchanged feed costs
    one cheap round trip and no re-parse. New episodes are inserted; existing
    ones (which may already carry download state) are left untouched.
    """
    existing = await session.scalar(
        select(PodcastChannel).where(PodcastChannel.feed_url == feed_url)
    )

    parsed = await fetch_feed(
        feed_url,
        etag=existing.http_etag if existing else None,
        last_modified=existing.http_last_modified if existing else None,
    )
    if parsed is None:
        # A 304 is only possible when we sent a cached etag/last-modified,
        # which only happens when `existing` was found above.
        assert existing is not None
        existing.last_fetched_at = datetime.now(UTC)
        await session.flush()
        return existing

    values = {
        "feed_url": feed_url,
        "title": parsed.title,
        "author": parsed.author,
        "description": parsed.description,
        "image_url": parsed.image_url,
        "categories": parsed.categories,
        "last_fetched_at": datetime.now(UTC),
        "http_etag": parsed.etag,
        "http_last_modified": parsed.last_modified,
    }
    channel_stmt = (
        pg_insert(PodcastChannel)
        .values(**values)
        .on_conflict_do_update(index_elements=["feed_url"], set_=values)
        .returning(PodcastChannel.id)
    )
    channel_id = (await session.execute(channel_stmt)).scalar_one()

    if parsed.episodes:
        episode_rows = [
            {
                "channel_id": channel_id,
                "guid": ep.guid,
                "title": ep.title,
                "description": ep.description,
                "published_at": ep.published_at,
                "duration_s": ep.duration_s,
                "enclosure_url": ep.enclosure_url,
                "enclosure_type": ep.enclosure_type,
                "enclosure_bytes": ep.enclosure_bytes,
                "image_url": ep.image_url,
                "episode_no": ep.episode_no,
                "season_no": ep.season_no,
            }
            for ep in parsed.episodes
        ]
        episode_stmt = (
            pg_insert(PodcastEpisode)
            .values(episode_rows)
            .on_conflict_do_nothing(index_elements=["channel_id", "guid"])
        )
        await session.execute(episode_stmt)

    await session.flush()
    channel = await session.get(PodcastChannel, channel_id)
    assert channel is not None
    return channel
