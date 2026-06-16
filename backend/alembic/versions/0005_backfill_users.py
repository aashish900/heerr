"""backfill users + lock user_id NOT NULL

Revision ID: 0005
Revises: 0004
Create Date: 2026-06-16
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Seed the two synthetic users. Idempotent so a downgrade+upgrade cycle
    #    does not crash on the unique(navidrome_username) constraint.
    op.execute(
        "INSERT INTO users (navidrome_username) VALUES ('legacy-admin'), ('system-admin')"
        " ON CONFLICT (navidrome_username) DO NOTHING"
    )

    # 2. Backfill pre-existing rows.
    #    - Tokens default to system-admin (CLI-minted assumption).
    #    - Jobs default to legacy-admin (pre-multi-user data has no real owner).
    op.execute(
        "UPDATE tokens SET user_id ="
        " (SELECT id FROM users WHERE navidrome_username = 'system-admin')"
        " WHERE user_id IS NULL"
    )
    op.execute(
        "UPDATE jobs SET user_id ="
        " (SELECT id FROM users WHERE navidrome_username = 'legacy-admin')"
        " WHERE user_id IS NULL"
    )

    # 3. Helper function so INSERTs that don't yet pass user_id resolve to
    #    system-admin. This is the transitional bridge between J2 (schema flip)
    #    and J6–J9 (app-layer wiring). Removed once the app sets user_id on
    #    every INSERT site (tracked in DEBT.md after J9).
    op.execute(
        "CREATE OR REPLACE FUNCTION system_admin_user_id() RETURNS uuid AS $$"
        " SELECT id FROM users WHERE navidrome_username = 'system-admin' LIMIT 1;"
        " $$ LANGUAGE SQL STABLE"
    )

    # 4. Apply DEFAULT and NOT NULL together so explicit NULL still fails.
    op.alter_column(
        "tokens",
        "user_id",
        nullable=False,
        server_default=sa.text("system_admin_user_id()"),
    )
    op.alter_column(
        "jobs",
        "user_id",
        nullable=False,
        server_default=sa.text("system_admin_user_id()"),
    )


def downgrade() -> None:
    # Reverse the NOT NULL + default; leave the seed users + backfilled rows alone
    # (removing the seed users would orphan referencing rows and lose data).
    op.alter_column("jobs", "user_id", nullable=True, server_default=None)
    op.alter_column("tokens", "user_id", nullable=True, server_default=None)
    op.execute("DROP FUNCTION IF EXISTS system_admin_user_id()")
