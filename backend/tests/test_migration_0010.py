"""Migration 0010 — downloads.user_id + per-user composite unique (DEBT M3)."""

import uuid

import pytest
from psycopg import errors as pg_errors


def _mk_user(cur, name: str):
    cur.execute(
        "INSERT INTO users (navidrome_username) VALUES (%s) RETURNING id",
        (f"{name}-{uuid.uuid4().hex[:8]}",),
    )
    return cur.fetchone()[0]


def _mk_token(cur, user_id):
    cur.execute(
        "INSERT INTO tokens (token_hash, scopes, user_id) VALUES (%s, %s, %s) RETURNING id",
        (f"hash-{uuid.uuid4()}", ["read", "download"], user_id),
    )
    return cur.fetchone()[0]


def _mk_job(cur, token_id, user_id, url: str):
    cur.execute(
        "INSERT INTO jobs (source_url, source_type, state, created_by_token_id, user_id) "
        "VALUES (%s, 'song', 'done', %s, %s) RETURNING id",
        (url, token_id, user_id),
    )
    return cur.fetchone()[0]


def test_downloads_user_id_not_null(db_conn, seed_token):
    """An INSERT into downloads without user_id is rejected."""
    cur = db_conn.cursor()
    cur.execute("SELECT system_admin_user_id()")
    sys_admin = cur.fetchone()[0]
    job_id = _mk_job(cur, seed_token, sys_admin, "https://www.youtube.com/watch?v=nn")
    with pytest.raises(pg_errors.NotNullViolation):
        cur.execute(
            "INSERT INTO downloads (source_url, job_id, output_path) VALUES (%s, %s, %s)",
            ("https://www.youtube.com/watch?v=nn", job_id, "/data/media/music/nn.mp3"),
        )


def test_downloads_user_id_fk_rejects_bogus(db_conn, seed_token):
    cur = db_conn.cursor()
    cur.execute("SELECT system_admin_user_id()")
    sys_admin = cur.fetchone()[0]
    job_id = _mk_job(cur, seed_token, sys_admin, "https://www.youtube.com/watch?v=fk")
    with pytest.raises(pg_errors.ForeignKeyViolation):
        cur.execute(
            "INSERT INTO downloads (source_url, job_id, user_id, output_path) "
            "VALUES (%s, %s, %s, %s)",
            ("https://www.youtube.com/watch?v=fk", job_id, str(uuid.uuid4()), "/x.mp3"),
        )


def test_same_user_same_url_violates(db_conn):
    """The per-user composite UNIQUE still blocks a user from duplicating a URL."""
    cur = db_conn.cursor()
    user = _mk_user(cur, "dup-user")
    token = _mk_token(cur, user)
    url = "https://www.youtube.com/watch?v=same"
    job_id = _mk_job(cur, token, user, url)
    cur.execute(
        "INSERT INTO downloads (source_url, job_id, user_id, output_path) "
        "VALUES (%s, %s, %s, %s)",
        (url, job_id, user, "/data/media/music/same.mp3"),
    )
    with pytest.raises(pg_errors.UniqueViolation):
        cur.execute(
            "INSERT INTO downloads (source_url, job_id, user_id, output_path) "
            "VALUES (%s, %s, %s, %s)",
            (url, job_id, user, "/data/media/music/same-dup.mp3"),
        )


def test_different_users_same_url_allowed(db_conn):
    """Core M3 fix: the dropped global UNIQUE lets two users own the same URL."""
    cur = db_conn.cursor()
    url = "https://www.youtube.com/watch?v=cross"
    user_a = _mk_user(cur, "alice")
    user_b = _mk_user(cur, "bob")
    tok_a = _mk_token(cur, user_a)
    tok_b = _mk_token(cur, user_b)
    job_a = _mk_job(cur, tok_a, user_a, url)
    job_b = _mk_job(cur, tok_b, user_b, url)

    cur.execute(
        "INSERT INTO downloads (source_url, job_id, user_id, output_path) "
        "VALUES (%s, %s, %s, %s)",
        (url, job_a, user_a, "/data/media/music/cross.mp3"),
    )
    # Same URL, different user — would have violated the old global UNIQUE.
    cur.execute(
        "INSERT INTO downloads (source_url, job_id, user_id, output_path) "
        "VALUES (%s, %s, %s, %s)",
        (url, job_b, user_b, "/data/media/music/cross.mp3"),
    )
    cur.execute(
        "SELECT count(*) FROM downloads WHERE source_url = %s",
        (url,),
    )
    assert cur.fetchone()[0] == 2
