import psycopg
import pytest
from psycopg import errors as pg_errors

from alembic import command
from tests.migration_guard import _cfg

URL = "https://music.youtube.com/watch?v=abc"


@pytest.fixture
def user_id(db_conn):
    cur = db_conn.cursor()
    cur.execute("INSERT INTO users (navidrome_username) VALUES ('rx2-user') RETURNING id")
    return cur.fetchone()[0]


def test_defaults(db_conn, user_id):
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO rec_feedback (user_id, source_url) VALUES (%s, %s) "
        "RETURNING shown_count, last_shown_at, dismissed_at",
        (user_id, URL),
    )
    assert cur.fetchone() == (0, None, None)


def test_one_row_per_user_and_url(db_conn, user_id):
    cur = db_conn.cursor()
    cur.execute("INSERT INTO rec_feedback (user_id, source_url) VALUES (%s, %s)", (user_id, URL))
    with pytest.raises(pg_errors.UniqueViolation):
        cur.execute(
            "INSERT INTO rec_feedback (user_id, source_url) VALUES (%s, %s)", (user_id, URL)
        )


def test_same_url_for_different_users(db_conn, user_id):
    cur = db_conn.cursor()
    cur.execute("SELECT system_admin_user_id()")
    admin = cur.fetchone()[0]
    cur.execute("INSERT INTO rec_feedback (user_id, source_url) VALUES (%s, %s)", (user_id, URL))
    cur.execute("INSERT INTO rec_feedback (user_id, source_url) VALUES (%s, %s)", (admin, URL))


def test_user_delete_cascades(db_conn, user_id):
    cur = db_conn.cursor()
    cur.execute("INSERT INTO rec_feedback (user_id, source_url) VALUES (%s, %s)", (user_id, URL))
    cur.execute("DELETE FROM users WHERE id = %s", (user_id,))
    cur.execute("SELECT count(*) FROM rec_feedback WHERE user_id = %s", (user_id,))
    assert cur.fetchone()[0] == 0


def test_unknown_user_rejected(db_conn):
    cur = db_conn.cursor()
    with pytest.raises(pg_errors.ForeignKeyViolation):
        cur.execute(
            "INSERT INTO rec_feedback (user_id, source_url) VALUES (gen_random_uuid(), %s)",
            (URL,),
        )


def test_downgrade_drops_table_then_upgrade(pg_libpq_url):
    command.downgrade(_cfg(), "0015")
    try:
        with psycopg.connect(pg_libpq_url) as c, c.cursor() as cur:
            cur.execute("SELECT count(*) FROM pg_tables WHERE tablename = 'rec_feedback'")
            assert cur.fetchone()[0] == 0
    finally:
        command.upgrade(_cfg(), "head")
