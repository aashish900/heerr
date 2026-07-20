import pytest
from psycopg import errors as pg_errors

_FEED_URL = "https://example.com/feed.xml"
_ENCLOSURE_URL = "https://example.com/ep1.mp3"


def test_tables_present(db_conn):
    cur = db_conn.cursor()
    cur.execute(
        "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename IN "
        "('podcast_channel','podcast_episode','podcast_subscription','podcast_progress')"
    )
    names = {row[0] for row in cur.fetchall()}
    assert names == {
        "podcast_channel",
        "podcast_episode",
        "podcast_subscription",
        "podcast_progress",
    }


@pytest.fixture
def seed_channel(db_conn):
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO podcast_channel (feed_url, title) VALUES (%s, %s) RETURNING id",
        (_FEED_URL, "Test Show"),
    )
    return cur.fetchone()[0]


@pytest.fixture
def seed_episode(db_conn, seed_channel):
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO podcast_episode (channel_id, guid, title, enclosure_url) "
        "VALUES (%s, %s, %s, %s) RETURNING id",
        (seed_channel, "ep-1", "Episode 1", _ENCLOSURE_URL),
    )
    return cur.fetchone()[0]


def test_channel_feed_url_unique(db_conn, seed_channel):
    cur = db_conn.cursor()
    with pytest.raises(pg_errors.UniqueViolation):
        cur.execute(
            "INSERT INTO podcast_channel (feed_url, title) VALUES (%s, %s)",
            (_FEED_URL, "Duplicate Show"),
        )


def test_episode_guid_unique_per_channel(db_conn, seed_channel, seed_episode):
    cur = db_conn.cursor()
    with pytest.raises(pg_errors.UniqueViolation):
        cur.execute(
            "INSERT INTO podcast_episode (channel_id, guid, title, enclosure_url) "
            "VALUES (%s, %s, %s, %s)",
            (seed_channel, "ep-1", "Episode 1 Again", _ENCLOSURE_URL),
        )


def test_episode_channel_delete_cascades(db_conn, seed_channel, seed_episode):
    cur = db_conn.cursor()
    cur.execute("DELETE FROM podcast_channel WHERE id = %s", (seed_channel,))
    cur.execute("SELECT id FROM podcast_episode WHERE id = %s", (seed_episode,))
    assert cur.fetchone() is None


def test_subscription_unique_per_user_channel(db_conn, seed_channel):
    cur = db_conn.cursor()
    cur.execute("SELECT system_admin_user_id()")
    user_id = cur.fetchone()[0]
    cur.execute(
        "INSERT INTO podcast_subscription (user_id, channel_id) VALUES (%s, %s)",
        (user_id, seed_channel),
    )
    with pytest.raises(pg_errors.UniqueViolation):
        cur.execute(
            "INSERT INTO podcast_subscription (user_id, channel_id) VALUES (%s, %s)",
            (user_id, seed_channel),
        )


def test_subscription_user_delete_restricted(db_conn, seed_channel):
    cur = db_conn.cursor()
    cur.execute("SELECT system_admin_user_id()")
    user_id = cur.fetchone()[0]
    cur.execute(
        "INSERT INTO podcast_subscription (user_id, channel_id) VALUES (%s, %s)",
        (user_id, seed_channel),
    )
    with pytest.raises(pg_errors.ForeignKeyViolation):
        cur.execute("DELETE FROM users WHERE id = %s", (user_id,))


def test_progress_unique_per_user_episode(db_conn, seed_episode):
    cur = db_conn.cursor()
    cur.execute("SELECT system_admin_user_id()")
    user_id = cur.fetchone()[0]
    cur.execute(
        "INSERT INTO podcast_progress (user_id, episode_id) VALUES (%s, %s)",
        (user_id, seed_episode),
    )
    with pytest.raises(pg_errors.UniqueViolation):
        cur.execute(
            "INSERT INTO podcast_progress (user_id, episode_id) VALUES (%s, %s)",
            (user_id, seed_episode),
        )


def test_progress_episode_delete_cascades(db_conn, seed_channel, seed_episode):
    cur = db_conn.cursor()
    cur.execute("SELECT system_admin_user_id()")
    user_id = cur.fetchone()[0]
    cur.execute(
        "INSERT INTO podcast_progress (user_id, episode_id) VALUES (%s, %s) RETURNING id",
        (user_id, seed_episode),
    )
    progress_id = cur.fetchone()[0]
    cur.execute("DELETE FROM podcast_episode WHERE id = %s", (seed_episode,))
    cur.execute("SELECT id FROM podcast_progress WHERE id = %s", (progress_id,))
    assert cur.fetchone() is None


def test_progress_defaults(db_conn, seed_episode):
    cur = db_conn.cursor()
    cur.execute("SELECT system_admin_user_id()")
    user_id = cur.fetchone()[0]
    cur.execute(
        "INSERT INTO podcast_progress (user_id, episode_id) VALUES (%s, %s) "
        "RETURNING position_s, played",
        (user_id, seed_episode),
    )
    position_s, played = cur.fetchone()
    assert position_s == 0
    assert played is False
