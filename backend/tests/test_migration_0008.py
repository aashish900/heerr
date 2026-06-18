"""Smoke-test migration 0008 + T4 regression: dropping the
`system_admin_user_id()` server default on tokens.user_id and jobs.user_id.

These tests are the regression guard the M1 ADR called for: any future code
path that forgets to set `user_id` on a tokens/jobs INSERT now blows up loudly
with a NOT NULL violation, instead of silently routing to the synthetic
`system-admin` user.
"""

import uuid

import pytest
from psycopg import errors as pg_errors


def test_tokens_user_id_default_dropped(db_conn):
    cur = db_conn.cursor()
    cur.execute(
        "SELECT column_default FROM information_schema.columns"
        " WHERE table_name = 'tokens' AND column_name = 'user_id'"
    )
    assert cur.fetchone()[0] is None


def test_jobs_user_id_default_dropped(db_conn):
    cur = db_conn.cursor()
    cur.execute(
        "SELECT column_default FROM information_schema.columns"
        " WHERE table_name = 'jobs' AND column_name = 'user_id'"
    )
    assert cur.fetchone()[0] is None


def test_system_admin_user_id_function_still_exists(db_conn):
    """0008 drops the column DEFAULT but the helper function stays — it's still
    useful for operator one-off lookups."""
    cur = db_conn.cursor()
    cur.execute("SELECT system_admin_user_id()")
    assert cur.fetchone()[0] is not None


def test_insert_token_without_user_id_raises_not_null(db_conn):
    """T4: an INSERT into tokens that forgets user_id must fail loudly."""
    cur = db_conn.cursor()
    with pytest.raises(pg_errors.NotNullViolation):
        cur.execute(
            "INSERT INTO tokens (token_hash, scopes)" " VALUES (%s, %s)",
            (f"hash-{uuid.uuid4()}", ["read"]),
        )


def test_insert_job_without_user_id_raises_not_null(db_conn, seed_token):
    """T4: an INSERT into jobs that forgets user_id must fail loudly."""
    cur = db_conn.cursor()
    with pytest.raises(pg_errors.NotNullViolation):
        cur.execute(
            "INSERT INTO jobs (source_url, source_type, state, created_by_token_id)"
            " VALUES (%s, %s, %s, %s)",
            ("https://www.youtube.com/watch?v=ytJ2nouser", "song", "queued", seed_token),
        )
