"""jobs.display_name — human-readable label for queue UI

Revision ID: 0002
Revises: 0001
Create Date: 2026-06-10
"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "jobs",
        sa.Column("display_name", sa.Text(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("jobs", "display_name")
