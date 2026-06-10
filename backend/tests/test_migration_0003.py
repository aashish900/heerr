"""Smoke-test migration 0003: spotify_* columns renamed to source_*."""

import pytest
from psycopg import errors as pg_errors


def test_jobs_has_source_url_and_source_type(db_conn):
    cur = db_conn.cursor()
    cur.execute("SELECT source_url, source_type FROM jobs LIMIT 0")


def test_jobs_no_spotify_uri_column(db_conn):
    cur = db_conn.cursor()
    with pytest.raises(pg_errors.UndefinedColumn):
        cur.execute("SELECT spotify_uri FROM jobs LIMIT 0")


def test_downloads_has_source_url_column(db_conn):
    cur = db_conn.cursor()
    cur.execute("SELECT source_url FROM downloads LIMIT 0")


def test_source_type_check_accepts_song(db_conn, seed_token):
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO jobs (source_url, source_type, state, created_by_token_id)"
        " VALUES (%s, %s, %s, %s) RETURNING id",
        ("https://www.youtube.com/watch?v=yt0003", "song", "queued", seed_token),
    )
    job_id = cur.fetchone()[0]
    cur.execute("DELETE FROM jobs WHERE id = %s", (job_id,))


def test_source_type_check_rejects_track(db_conn, seed_token):
    cur = db_conn.cursor()
    with pytest.raises(pg_errors.CheckViolation):
        cur.execute(
            "INSERT INTO jobs (source_url, source_type, state, created_by_token_id)"
            " VALUES (%s, %s, %s, %s)",
            ("https://www.youtube.com/watch?v=yt0003b", "track", "queued", seed_token),
        )
