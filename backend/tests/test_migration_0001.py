import pytest
from psycopg import errors as pg_errors


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
            "INSERT INTO tokens (token_hash, owner_label, scopes) " "VALUES (%s, %s, %s)",
            ("hash-bad-scope", "owner", ["read", "bogus"]),
        )


def test_jobs_state_check_rejects_invalid(db_conn, seed_token):
    cur = db_conn.cursor()
    with pytest.raises(pg_errors.CheckViolation):
        cur.execute(
            "INSERT INTO jobs (spotify_uri, spotify_type, state, created_by_token_id) "
            "VALUES (%s, %s, %s, %s)",
            ("spotify:track:bad-state", "track", "weird", seed_token),
        )


def test_jobs_type_check_rejects_invalid(db_conn, seed_token):
    cur = db_conn.cursor()
    with pytest.raises(pg_errors.CheckViolation):
        cur.execute(
            "INSERT INTO jobs (spotify_uri, spotify_type, state, created_by_token_id) "
            "VALUES (%s, %s, %s, %s)",
            ("spotify:track:bad-type", "podcast", "queued", seed_token),
        )


def test_partial_unique_blocks_duplicate_active(db_conn, seed_token):
    """The done-when invariant: no two active jobs may share a spotify_uri."""
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO jobs (spotify_uri, spotify_type, state, created_by_token_id) "
        "VALUES (%s, %s, %s, %s)",
        ("spotify:track:dup", "track", "queued", seed_token),
    )
    with pytest.raises(pg_errors.UniqueViolation):
        cur.execute(
            "INSERT INTO jobs (spotify_uri, spotify_type, state, created_by_token_id) "
            "VALUES (%s, %s, %s, %s)",
            ("spotify:track:dup", "track", "running", seed_token),
        )


def test_partial_unique_allows_after_done(db_conn, seed_token):
    """The flip side: a completed job must not block re-queueing the same URI."""
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO jobs (spotify_uri, spotify_type, state, created_by_token_id) "
        "VALUES (%s, %s, %s, %s)",
        ("spotify:track:reuse", "track", "done", seed_token),
    )
    cur.execute(
        "INSERT INTO jobs (spotify_uri, spotify_type, state, created_by_token_id) "
        "VALUES (%s, %s, %s, %s)",
        ("spotify:track:reuse", "track", "queued", seed_token),
    )


def test_downloads_unique_track_uri(db_conn, seed_token):
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO jobs (spotify_uri, spotify_type, state, created_by_token_id) "
        "VALUES (%s, %s, %s, %s) RETURNING id",
        ("spotify:track:dl", "track", "done", seed_token),
    )
    job_id = cur.fetchone()[0]
    cur.execute(
        "INSERT INTO downloads (spotify_track_uri, job_id, output_path) " "VALUES (%s, %s, %s)",
        ("spotify:track:dl", job_id, "/data/media/music/dl.mp3"),
    )
    with pytest.raises(pg_errors.UniqueViolation):
        cur.execute(
            "INSERT INTO downloads (spotify_track_uri, job_id, output_path) " "VALUES (%s, %s, %s)",
            ("spotify:track:dl", job_id, "/data/media/music/dl-dup.mp3"),
        )


def test_fk_restrict_blocks_token_delete(db_conn, seed_token):
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO jobs (spotify_uri, spotify_type, state, created_by_token_id) "
        "VALUES (%s, %s, %s, %s)",
        ("spotify:track:fk", "track", "queued", seed_token),
    )
    with pytest.raises(pg_errors.ForeignKeyViolation):
        cur.execute("DELETE FROM tokens WHERE id = %s", (seed_token,))
