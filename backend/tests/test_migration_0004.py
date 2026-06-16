"""Smoke-test migration 0004: users table + nullable user_id FKs on tokens and jobs."""

import uuid

import pytest
from psycopg import errors as pg_errors


def test_users_table_exists(db_conn):
    cur = db_conn.cursor()
    cur.execute("SELECT id, navidrome_username, created_at, last_login_at FROM users LIMIT 0")


def test_users_navidrome_username_unique(db_conn):
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO users (navidrome_username) VALUES (%s) RETURNING id",
        ("alice",),
    )
    cur.fetchone()
    with pytest.raises(pg_errors.UniqueViolation):
        cur.execute("INSERT INTO users (navidrome_username) VALUES (%s)", ("alice",))


def test_tokens_has_nullable_user_id(db_conn):
    cur = db_conn.cursor()
    cur.execute("SELECT user_id FROM tokens LIMIT 0")
    # Insert without user_id must still work (nullable in 0004; J2 will flip to NOT NULL)
    cur.execute(
        "INSERT INTO tokens (token_hash, owner_label, scopes) VALUES (%s, %s, %s) RETURNING id",
        (f"hash-{uuid.uuid4()}", "no-user", ["read"]),
    )
    cur.fetchone()


def test_jobs_has_nullable_user_id(db_conn):
    cur = db_conn.cursor()
    cur.execute("SELECT user_id FROM jobs LIMIT 0")


def test_tokens_user_id_fk_rejects_bogus(db_conn, seed_token):
    cur = db_conn.cursor()
    bogus = uuid.uuid4()
    with pytest.raises(pg_errors.ForeignKeyViolation):
        cur.execute(
            "UPDATE tokens SET user_id = %s WHERE id = %s",
            (bogus, seed_token),
        )


def test_jobs_user_id_fk_rejects_bogus(db_conn, seed_token):
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO jobs (source_url, source_type, state, created_by_token_id)"
        " VALUES (%s, %s, %s, %s) RETURNING id",
        ("https://www.youtube.com/watch?v=yt0004", "song", "queued", seed_token),
    )
    job_id = cur.fetchone()[0]
    bogus = uuid.uuid4()
    with pytest.raises(pg_errors.ForeignKeyViolation):
        cur.execute("UPDATE jobs SET user_id = %s WHERE id = %s", (bogus, job_id))


def test_tokens_user_id_fk_accepts_real_user(db_conn, seed_token):
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO users (navidrome_username) VALUES (%s) RETURNING id",
        (f"u-{uuid.uuid4().hex[:8]}",),
    )
    user_id = cur.fetchone()[0]
    cur.execute("UPDATE tokens SET user_id = %s WHERE id = %s", (user_id, seed_token))
    cur.execute("SELECT user_id FROM tokens WHERE id = %s", (seed_token,))
    assert cur.fetchone()[0] == user_id


def test_users_on_delete_restrict_from_tokens(db_conn, seed_token):
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO users (navidrome_username) VALUES (%s) RETURNING id",
        (f"u-{uuid.uuid4().hex[:8]}",),
    )
    user_id = cur.fetchone()[0]
    cur.execute("UPDATE tokens SET user_id = %s WHERE id = %s", (user_id, seed_token))
    with pytest.raises(pg_errors.ForeignKeyViolation):
        cur.execute("DELETE FROM users WHERE id = %s", (user_id,))
