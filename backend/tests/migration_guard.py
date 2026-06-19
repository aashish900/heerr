"""Helpers for the T1 head-guard (see `_guard_db_at_head` in conftest.py).

`test_models_match_schema` only checks ORM/schema parity at session start, so a
test that runs `alembic downgrade` and forgets to upgrade back would silently
leave the shared session DB below head and poison every downstream test. These
helpers detect that and repair it.
"""

from __future__ import annotations

import os
from pathlib import Path

import psycopg

from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory

BACKEND_DIR = Path(__file__).resolve().parent.parent
ALEMBIC_INI = BACKEND_DIR / "alembic.ini"


def _cfg() -> Config:
    return Config(str(ALEMBIC_INI))


def alembic_head() -> str:
    head = ScriptDirectory.from_config(_cfg()).get_current_head()
    assert head is not None, "alembic has no head revision"
    return head


def db_revision() -> str | None:
    """Current schema revision recorded in `alembic_version`, or None if empty."""
    libpq = os.environ["DATABASE_URL"].replace("+psycopg", "").replace("+asyncpg", "")
    with psycopg.connect(libpq) as conn, conn.cursor() as cur:
        cur.execute("SELECT version_num FROM alembic_version")
        row = cur.fetchone()
    return row[0] if row else None


def verify_db_at_head_or_repair(node_id: str) -> None:
    """Assert the DB is at alembic head; upgrade-repair and raise if it is not.

    Called by the autouse `_guard_db_at_head` fixture after any test that ran
    `alembic downgrade`. Repairs to head *before* raising so the rest of the
    session is not corrupted by one forgetful test.
    """
    head = alembic_head()
    current = db_revision()
    if current != head:
        command.upgrade(_cfg(), "head")
        raise AssertionError(
            f"{node_id} ran an alembic downgrade and left the DB at {current!r}, "
            f"not head {head!r}. Auto-repaired to head so downstream tests are not "
            f"poisoned — but the test itself must upgrade back to head before it ends."
        )
