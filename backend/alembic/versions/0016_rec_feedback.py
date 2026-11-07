"""rec_feedback: per-user shown/dismissed state for recommendations (RX2)

Revision ID: 0016
Revises: 0015
Create Date: 2026-11-07
"""

from __future__ import annotations

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "0016"
down_revision = "0015"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "rec_feedback",
        sa.Column("user_id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("source_url", sa.Text, primary_key=True),
        sa.Column("shown_count", sa.Integer, nullable=False, server_default=sa.text("0")),
        sa.Column("last_shown_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("dismissed_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
            name="rec_feedback_user_id_fkey",
        ),
    )


def downgrade() -> None:
    op.drop_table("rec_feedback")
