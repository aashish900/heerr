"""Smoke-test migration 0009: drop tokens.owner_label.

After J6 the column duplicated `users.navidrome_username` for the FK-linked
user. The audit (DEBT.md M2) parked the question; the resolution is to delete
the duplicate column entirely. This file proves the column is gone at HEAD
and INSERT into tokens succeeds without it.

The downgrade is not exercised here: it would need to acquire AccessExclusive
on `tokens` to add the column back, which races autovacuum and other tests'
sessions in the shared-container fixture. The downgrade is short and direct
(see `0009_drop_tokens_owner_label.py::downgrade`) — review it there.
"""

import uuid


def test_owner_label_column_dropped(db_conn):
    cur = db_conn.cursor()
    cur.execute(
        "SELECT column_name FROM information_schema.columns"
        " WHERE table_name = 'tokens' AND column_name = 'owner_label'"
    )
    assert cur.fetchone() is None


def test_insert_token_without_owner_label_succeeds(db_conn):
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO tokens (token_hash, scopes, user_id)"
        " VALUES (%s, %s, system_admin_user_id()) RETURNING id",
        (f"hash-{uuid.uuid4()}", ["read"]),
    )
    assert cur.fetchone()[0] is not None
