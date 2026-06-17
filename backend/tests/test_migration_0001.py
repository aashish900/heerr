import pytest
from psycopg import errors as pg_errors

_YT_URL = "https://www.youtube.com/watch?v=test"


def test_extensions_present(db_conn):
    cur = db_conn.cursor()
    cur.execute("SELECT extname FROM pg_extension WHERE extname IN ('pgcrypto', 'vector')")
    names = {row[0] for row in cur.fetchall()}
    assert names == {"pgcrypto", "vector"}


def test_tables_present(db_conn):
    cur = db_conn.cursor()
    cur.execute(
        "SELECT tablename FROM pg_tables "
        "WHERE schemaname='public' AND tablename IN ('tokens','jobs','downloads')"
    )
    names = {row[0] for row in cur.fetchall()}
    assert names == {"tokens", "jobs", "downloads"}


def test_tokens_scopes_check_rejects_invalid(db_conn):
    cur = db_conn.cursor()
    with pytest.raises(pg_errors.CheckViolation):
        cur.execute(
            "INSERT INTO tokens (token_hash, owner_label, scopes, user_id) VALUES (%s, %s, %s, system_admin_user_id())",
            ("hash-bad-scope", "owner", ["read", "bogus"]),
        )


def test_jobs_state_check_rejects_invalid(db_conn, seed_token):
    cur = db_conn.cursor()
    with pytest.raises(pg_errors.CheckViolation):
        cur.execute(
            "INSERT INTO jobs (source_url, source_type, state, created_by_token_id, user_id) "
            "VALUES (%s, %s, %s, %s, system_admin_user_id())",
            (_YT_URL, "song", "weird", seed_token),
        )


def test_jobs_type_check_rejects_invalid(db_conn, seed_token):
    cur = db_conn.cursor()
    with pytest.raises(pg_errors.CheckViolation):
        cur.execute(
            "INSERT INTO jobs (source_url, source_type, state, created_by_token_id, user_id) "
            "VALUES (%s, %s, %s, %s, system_admin_user_id())",
            (_YT_URL, "podcast", "queued", seed_token),
        )


def test_partial_unique_blocks_duplicate_active(db_conn, seed_token):
    """The done-when invariant: no two active jobs may share a source_url."""
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO jobs (source_url, source_type, state, created_by_token_id, user_id)"
        "VALUES (%s, %s, %s, %s, system_admin_user_id())",
        ("https://www.youtube.com/watch?v=dup", "song", "queued", seed_token),
    )
    with pytest.raises(pg_errors.UniqueViolation):
        cur.execute(
            "INSERT INTO jobs (source_url, source_type, state, created_by_token_id, user_id) "
            "VALUES (%s, %s, %s, %s, system_admin_user_id())",
            ("https://www.youtube.com/watch?v=dup", "song", "running", seed_token),
        )


def test_partial_unique_allows_after_done(db_conn, seed_token):
    """A completed job must not block re-queueing the same URL."""
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO jobs (source_url, source_type, state, created_by_token_id, user_id)"
        "VALUES (%s, %s, %s, %s, system_admin_user_id())",
        ("https://www.youtube.com/watch?v=reuse", "song", "done", seed_token),
    )
    cur.execute(
        "INSERT INTO jobs (source_url, source_type, state, created_by_token_id, user_id)"
        "VALUES (%s, %s, %s, %s, system_admin_user_id())",
        ("https://www.youtube.com/watch?v=reuse", "song", "queued", seed_token),
    )


def test_downloads_unique_source_url(db_conn, seed_token):
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO jobs (source_url, source_type, state, created_by_token_id, user_id)"
        "VALUES (%s, %s, %s, %s, system_admin_user_id()) RETURNING id",
        ("https://www.youtube.com/watch?v=dl", "song", "done", seed_token),
    )
    job_id = cur.fetchone()[0]
    cur.execute(
        "INSERT INTO downloads (source_url, job_id, output_path) VALUES (%s, %s, %s)",
        ("https://www.youtube.com/watch?v=dl", job_id, "/data/media/music/dl.mp3"),
    )
    with pytest.raises(pg_errors.UniqueViolation):
        cur.execute(
            "INSERT INTO downloads (source_url, job_id, output_path) VALUES (%s, %s, %s)",
            ("https://www.youtube.com/watch?v=dl", job_id, "/data/media/music/dl-dup.mp3"),
        )


def test_fk_restrict_blocks_token_delete(db_conn, seed_token):
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO jobs (source_url, source_type, state, created_by_token_id, user_id)"
        "VALUES (%s, %s, %s, %s, system_admin_user_id())",
        ("https://www.youtube.com/watch?v=fk", "song", "queued", seed_token),
    )
    with pytest.raises(pg_errors.ForeignKeyViolation):
        cur.execute("DELETE FROM tokens WHERE id = %s", (seed_token,))
