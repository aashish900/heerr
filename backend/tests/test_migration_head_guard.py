"""T1 — the head-guard detects a downgrade-without-upgrade and repairs it.

The autouse `_guard_db_at_head` fixture (conftest.py) is the actual protection;
these tests pin its detection + repair logic so a future change can't silently
neuter it.
"""

import pytest

from alembic import command
from tests.migration_guard import (
    _cfg,
    alembic_head,
    db_revision,
    verify_db_at_head_or_repair,
)


def test_session_starts_at_head(pg_libpq_url):
    assert db_revision() == alembic_head()


def test_downgrade_is_detectable_then_restored(pg_libpq_url):
    """A downgrade moves the DB below head; the helpers observe it."""
    head = alembic_head()
    command.downgrade(_cfg(), "0004")
    try:
        assert db_revision() == "0004"
        assert db_revision() != head
    finally:
        command.upgrade(_cfg(), "head")
    assert db_revision() == head


def test_guard_trips_and_auto_repairs(pg_libpq_url):
    """verify_db_at_head_or_repair raises when below head AND restores head."""
    head = alembic_head()
    command.downgrade(_cfg(), "0004")

    with pytest.raises(AssertionError, match="left the DB at '0004'"):
        verify_db_at_head_or_repair("synthetic::forgot_to_upgrade")

    # The guard must have repaired the schema before raising, so this test (and
    # everything after it) sees head — no manual upgrade needed here.
    assert db_revision() == head


def test_guard_is_silent_when_at_head(pg_libpq_url):
    """No raise, no side effects when the DB is already at head."""
    assert db_revision() == alembic_head()
    verify_db_at_head_or_repair("synthetic::clean")  # must not raise
    assert db_revision() == alembic_head()
