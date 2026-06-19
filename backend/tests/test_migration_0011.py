"""Migration 0011 — users.settings JSONB for per-user recommendation config (DEBT M5)."""

import json
import uuid

import pytest
from psycopg import errors as pg_errors


def _mk_user(cur, name: str):
    cur.execute(
        "INSERT INTO users (navidrome_username) VALUES (%s) RETURNING id, settings",
        (f"{name}-{uuid.uuid4().hex[:8]}",),
    )
    return cur.fetchone()


def test_settings_defaults_to_empty_object(db_conn):
    cur = db_conn.cursor()
    _id, settings = _mk_user(cur, "default-user")
    assert settings == {}


def test_settings_not_null(db_conn):
    cur = db_conn.cursor()
    with pytest.raises(pg_errors.NotNullViolation):
        cur.execute(
            "INSERT INTO users (navidrome_username, settings) VALUES (%s, NULL)",
            (f"null-user-{uuid.uuid4().hex[:8]}",),
        )


def test_settings_round_trips_jsonb(db_conn):
    cur = db_conn.cursor()
    payload = {"lastfm_username": "alice", "listenbrainz_token": "tok-123"}
    cur.execute(
        "INSERT INTO users (navidrome_username, settings) VALUES (%s, %s) RETURNING settings",
        (f"jsonb-user-{uuid.uuid4().hex[:8]}", json.dumps(payload)),
    )
    assert cur.fetchone()[0] == payload
