import psycopg
import pytest
from psycopg import errors as pg_errors

from alembic import command
from tests.migration_guard import _cfg


@pytest.fixture
def host_id(db_conn):
    cur = db_conn.cursor()
    cur.execute("SELECT system_admin_user_id()")
    return cur.fetchone()[0]


def _session(cur, host_id, code="ABC234", ended=False):
    cur.execute(
        "INSERT INTO jam_session (host_user_id, code, expires_at, ended_at) "
        "VALUES (%s, %s, now() + interval '12 hours', "
        "CASE WHEN %s THEN now() ELSE NULL END) RETURNING id",
        (host_id, code, ended),
    )
    return cur.fetchone()[0]


def test_active_code_unique(db_conn, host_id):
    cur = db_conn.cursor()
    _session(cur, host_id)
    with pytest.raises(pg_errors.UniqueViolation):
        _session(cur, host_id)


def test_ended_session_frees_code(db_conn, host_id):
    cur = db_conn.cursor()
    _session(cur, host_id, ended=True)
    _session(cur, host_id)  # must not raise


def test_command_kind_checked(db_conn, host_id):
    cur = db_conn.cursor()
    sid = _session(cur, host_id)
    with pytest.raises(pg_errors.CheckViolation):
        cur.execute(
            "INSERT INTO jam_command (session_id, sender_user_id, kind) VALUES (%s, %s, 'rewind')",
            (sid, host_id),
        )


def test_session_delete_cascades_commands(db_conn, host_id):
    cur = db_conn.cursor()
    sid = _session(cur, host_id)
    cur.execute(
        "INSERT INTO jam_command (session_id, sender_user_id, kind) VALUES (%s, %s, 'play') "
        "RETURNING id, payload",
        (sid, host_id),
    )
    cmd_id, payload = cur.fetchone()
    assert payload == {}
    cur.execute("DELETE FROM jam_session WHERE id = %s", (sid,))
    cur.execute("SELECT 1 FROM jam_command WHERE id = %s", (cmd_id,))
    assert cur.fetchone() is None


def test_downgrade_drops_tables_then_upgrade(pg_libpq_url):
    command.downgrade(_cfg(), "0014")
    try:
        with psycopg.connect(pg_libpq_url) as c, c.cursor() as cur:
            cur.execute(
                "SELECT count(*) FROM pg_tables WHERE tablename IN ('jam_session','jam_command')"
            )
            assert cur.fetchone()[0] == 0
    finally:
        command.upgrade(_cfg(), "head")
