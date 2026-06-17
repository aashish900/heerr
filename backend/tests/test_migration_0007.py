"""Smoke-test migration 0007: tokens.last_used_at column added."""


def test_last_used_at_column_exists(db_conn):
    cur = db_conn.cursor()
    cur.execute(
        "SELECT column_name, is_nullable, data_type FROM information_schema.columns"
        " WHERE table_name = 'tokens' AND column_name = 'last_used_at'"
    )
    row = cur.fetchone()
    assert row is not None
    assert row[1] == "YES"
    assert row[2].startswith("timestamp")
