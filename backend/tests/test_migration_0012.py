"""Migration 0012 — users profile columns (display_name, nickname, bio, avatar_data)."""

import uuid


def _mk_user(cur, name: str):
    cur.execute(
        "INSERT INTO users (navidrome_username) VALUES (%s) RETURNING id",
        (f"{name}-{uuid.uuid4().hex[:8]}",),
    )
    return cur.fetchone()[0]


def test_new_columns_default_to_null(db_conn):
    cur = db_conn.cursor()
    uid = _mk_user(cur, "new-user")
    cur.execute(
        "SELECT display_name, nickname, bio, avatar_data FROM users WHERE id = %s",
        (uid,),
    )
    row = cur.fetchone()
    assert row == (None, None, None, None)


def test_display_name_round_trips(db_conn):
    cur = db_conn.cursor()
    uid = _mk_user(cur, "dn-user")
    cur.execute(
        "UPDATE users SET display_name = %s WHERE id = %s",
        ("Alice", uid),
    )
    cur.execute("SELECT display_name FROM users WHERE id = %s", (uid,))
    assert cur.fetchone()[0] == "Alice"


def test_nickname_and_bio_round_trip(db_conn):
    cur = db_conn.cursor()
    uid = _mk_user(cur, "meta-user")
    cur.execute(
        "UPDATE users SET nickname = %s, bio = %s WHERE id = %s",
        ("ali", "Music lover", uid),
    )
    cur.execute("SELECT nickname, bio FROM users WHERE id = %s", (uid,))
    row = cur.fetchone()
    assert row == ("ali", "Music lover")


def test_avatar_data_stores_binary(db_conn):
    cur = db_conn.cursor()
    uid = _mk_user(cur, "avatar-user")
    payload = b"\x89PNG\r\nhello"
    cur.execute(
        "UPDATE users SET avatar_data = %s WHERE id = %s",
        (payload, uid),
    )
    cur.execute("SELECT avatar_data FROM users WHERE id = %s", (uid,))
    result = cur.fetchone()[0]
    assert bytes(result) == payload
