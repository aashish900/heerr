"""drop system_admin_user_id() server default on tokens.user_id and jobs.user_id

Revision ID: 0008
Revises: 0007
Create Date: 2026-06-17

After Phase J shipped (3.0.0) every INSERT site in the app now passes
`user_id` explicitly. The transitional `system_admin_user_id()` server default
on `tokens.user_id` and `jobs.user_id` (migration 0005) is no longer needed
and is actively harmful: it silently routes any future code path that forgets
to set `user_id` to the synthetic system-admin user.

This migration drops the default on both columns. The `system_admin_user_id()`
function itself stays in the DB — it is still useful as a one-off lookup for
operator scripts.
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "tokens",
        "user_id",
        server_default=None,
    )
    op.alter_column(
        "jobs",
        "user_id",
        server_default=None,
    )


def downgrade() -> None:
    op.alter_column(
        "tokens",
        "user_id",
        server_default=sa.text("system_admin_user_id()"),
    )
    op.alter_column(
        "jobs",
        "user_id",
        server_default=sa.text("system_admin_user_id()"),
    )
