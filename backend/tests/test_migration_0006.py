"""Smoke-test migration 0006: per-user partial unique index on jobs."""

import uuid

import pytest
from psycopg import errors as pg_errors


def _seed_user(db_conn, username: str | None = None) -> str:
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO users (navidrome_username) VALUES (%s) RETURNING id",
        (username or f"u-{uuid.uuid4().hex[:8]}",),
    )
    return cur.fetchone()[0]


def test_old_index_dropped(db_conn):
    cur = db_conn.cursor()
    cur.execute(
        "SELECT indexname FROM pg_indexes"
        " WHERE tablename = 'jobs' AND indexname = 'jobs_active_source_url_idx'"
    )
    assert cur.fetchone() is None


def test_new_per_user_index_exists(db_conn):
    cur = db_conn.cursor()
    cur.execute(
        "SELECT indexname FROM pg_indexes"
        " WHERE tablename = 'jobs' AND indexname = 'jobs_active_user_source_url_idx'"
    )
    assert cur.fetchone() is not None


def test_two_users_can_have_active_job_for_same_url(db_conn, seed_token):
    cur = db_conn.cursor()
    user_a = _seed_user(db_conn)
    user_b = _seed_user(db_conn)
    url = "https://www.youtube.com/watch?v=multi-user"
    cur.execute(
        "INSERT INTO jobs (source_url, source_type, state, created_by_token_id, user_id)"
        " VALUES (%s, %s, %s, %s, %s) RETURNING id",
        (url, "song", "queued", seed_token, user_a),
    )
    cur.fetchone()
    # Second user POSTing same URL: must succeed under the new per-user index.
    cur.execute(
        "INSERT INTO jobs (source_url, source_type, state, created_by_token_id, user_id)"
        " VALUES (%s, %s, %s, %s, %s) RETURNING id",
        (url, "song", "queued", seed_token, user_b),
    )
    cur.fetchone()


def test_same_user_blocked_from_duplicate_active_for_same_url(db_conn, seed_token):
    cur = db_conn.cursor()
    user = _seed_user(db_conn)
    url = "https://www.youtube.com/watch?v=same-user"
    cur.execute(
        "INSERT INTO jobs (source_url, source_type, state, created_by_token_id, user_id)"
        " VALUES (%s, %s, %s, %s, %s) RETURNING id",
        (url, "song", "queued", seed_token, user),
    )
    cur.fetchone()
    with pytest.raises(pg_errors.UniqueViolation):
        cur.execute(
            "INSERT INTO jobs (source_url, source_type, state, created_by_token_id, user_id)"
            " VALUES (%s, %s, %s, %s, %s)",
            (url, "song", "running", seed_token, user),
        )
