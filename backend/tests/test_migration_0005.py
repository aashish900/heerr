"""Smoke-test migration 0005: seed users + backfill + NOT NULL + system_admin default."""

import uuid
from pathlib import Path

import pytest
from psycopg import errors as pg_errors

from alembic import command
from alembic.config import Config

BACKEND_DIR = Path(__file__).resolve().parent.parent
ALEMBIC_INI = BACKEND_DIR / "alembic.ini"


def _alembic_cfg() -> Config:
    return Config(str(ALEMBIC_INI))


def test_seed_users_exist(db_conn):
    cur = db_conn.cursor()
    cur.execute(
        "SELECT navidrome_username FROM users"
        " WHERE navidrome_username IN ('legacy-admin', 'system-admin')"
        " ORDER BY navidrome_username"
    )
    rows = [r[0] for r in cur.fetchall()]
    assert rows == ["legacy-admin", "system-admin"]


def test_system_admin_user_id_function_resolves(db_conn):
    cur = db_conn.cursor()
    cur.execute("SELECT system_admin_user_id()")
    fn_id = cur.fetchone()[0]
    cur.execute("SELECT id FROM users WHERE navidrome_username = 'system-admin'")
    expected = cur.fetchone()[0]
    assert fn_id == expected


def test_tokens_user_id_not_null_enforced(db_conn):
    cur = db_conn.cursor()
    with pytest.raises(pg_errors.NotNullViolation):
        cur.execute(
            "INSERT INTO tokens (token_hash, owner_label, scopes, user_id)"
            " VALUES (%s, %s, %s, NULL)",
            (f"hash-{uuid.uuid4()}", "t", ["read"]),
        )


def test_jobs_user_id_not_null_enforced(db_conn, seed_token):
    cur = db_conn.cursor()
    with pytest.raises(pg_errors.NotNullViolation):
        cur.execute(
            "INSERT INTO jobs"
            " (source_url, source_type, state, created_by_token_id, user_id)"
            " VALUES (%s, %s, %s, %s, NULL)",
            ("https://www.youtube.com/watch?v=ytJ2null", "song", "queued", seed_token),
        )


# NOTE: the J2 system_admin_user_id() server default tested here historically
# was dropped by migration 0008. The "INSERT without user_id silently picks up
# system-admin" tests now live in test_migration_0008.py (asserting the
# opposite — NotNullViolation, not silent route).


def test_backfill_assigns_seed_users_to_preexisting_rows(db_conn):
    """Downgrade to 0004, insert legacy rows without user_id, upgrade back, assert backfill."""
    # Drop down one revision to where user_id is nullable and has no default.
    command.downgrade(_alembic_cfg(), "0004")

    # Seed an "existing" token + job without user_id (simulating pre-multi-user state).
    with db_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO tokens (token_hash, owner_label, scopes)"
            " VALUES (%s, %s, %s) RETURNING id",
            (f"hash-{uuid.uuid4()}", "legacy", ["read", "download"]),
        )
        token_id = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO jobs (source_url, source_type, state, created_by_token_id)"
            " VALUES (%s, %s, %s, %s) RETURNING id",
            ("https://www.youtube.com/watch?v=ytJ2legacy", "song", "queued", token_id),
        )
        job_id = cur.fetchone()[0]
        db_conn.commit()

    # Re-run the J2 upgrade.
    command.upgrade(_alembic_cfg(), "head")

    with db_conn.cursor() as cur:
        cur.execute(
            "SELECT u.navidrome_username FROM tokens t"
            " JOIN users u ON u.id = t.user_id WHERE t.id = %s",
            (token_id,),
        )
        assert cur.fetchone()[0] == "system-admin"

        cur.execute(
            "SELECT u.navidrome_username FROM jobs j"
            " JOIN users u ON u.id = j.user_id WHERE j.id = %s",
            (job_id,),
        )
        assert cur.fetchone()[0] == "legacy-admin"

        # Clean up so the inserts don't pollute downstream tests in this session.
        cur.execute("DELETE FROM jobs WHERE id = %s", (job_id,))
        cur.execute("DELETE FROM tokens WHERE id = %s", (token_id,))
        db_conn.commit()


def test_seed_users_insert_is_idempotent(db_conn):
    """Downgrade and re-upgrade — seed users must not duplicate (unique violation would fail)."""
    command.downgrade(_alembic_cfg(), "0004")
    command.upgrade(_alembic_cfg(), "head")
    with db_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM users"
            " WHERE navidrome_username IN ('legacy-admin', 'system-admin')"
        )
        assert cur.fetchone()[0] == 2
