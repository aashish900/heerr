"""Migration 0002 — add jobs.display_name."""

import uuid


def test_jobs_display_name_column_exists(db_conn):
    cur = db_conn.cursor()
    cur.execute(
        "SELECT column_name, data_type, is_nullable "
        "FROM information_schema.columns "
        "WHERE table_name = 'jobs' AND column_name = 'display_name'"
    )
    row = cur.fetchone()
    assert row is not None, "jobs.display_name column missing"
    name, dtype, is_nullable = row
    assert dtype == "text"
    assert is_nullable == "YES"


def test_jobs_display_name_accepts_text(db_conn, seed_token):
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO jobs (spotify_uri, spotify_type, state, "
        "display_name, created_by_token_id) "
        "VALUES (%s, %s, %s, %s, %s) RETURNING id",
        (
            f"spotify:track:disp-{uuid.uuid4()}",
            "track",
            "queued",
            "Bohemian Rhapsody — Queen",
            seed_token,
        ),
    )
    job_id = cur.fetchone()[0]
    cur.execute("SELECT display_name FROM jobs WHERE id = %s", (job_id,))
    assert cur.fetchone()[0] == "Bohemian Rhapsody — Queen"


def test_jobs_display_name_nullable(db_conn, seed_token):
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO jobs (spotify_uri, spotify_type, state, created_by_token_id) "
        "VALUES (%s, %s, %s, %s) RETURNING id",
        (
            f"spotify:track:nodisp-{uuid.uuid4()}",
            "track",
            "queued",
            seed_token,
        ),
    )
    job_id = cur.fetchone()[0]
    cur.execute("SELECT display_name FROM jobs WHERE id = %s", (job_id,))
    assert cur.fetchone()[0] is None
