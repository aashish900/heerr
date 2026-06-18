"""drop tokens.owner_label

Revision ID: 0009
Revises: 0008
Create Date: 2026-06-18

After J6 the column is redundant — `tokens.owner_label` always equals
`users.navidrome_username` for the user the token is FK-linked to. Two
columns drift over time; the cure is to delete the duplicate.

The audit (DEBT.md M2) offered a repurpose-as-device-label alternative;
rejected because (a) it forces a `device_label` field through the login
contract before any consumer exists, (b) the access log loses per-user
identity unless we also add a separate `username` field — which is the
work we'd be avoiding by repurposing, and (c) a real "sessions" model
belongs in its own table once Phase S surfaces a need.
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0009"
down_revision = "0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_column("tokens", "owner_label")


def downgrade() -> None:
    op.add_column(
        "tokens",
        sa.Column("owner_label", sa.Text(), nullable=True),
    )
    op.execute(
        "UPDATE tokens SET owner_label = users.navidrome_username "
        "FROM users WHERE tokens.user_id = users.id"
    )
    op.alter_column("tokens", "owner_label", nullable=False)
