"""users table + nullable user_id FKs on tokens and jobs

Revision ID: 0004
Revises: 0003
Create Date: 2026-06-16
"""

from __future__ import annotations

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("navidrome_username", sa.Text(), nullable=False, unique=True),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column("last_login_at", sa.TIMESTAMP(timezone=True), nullable=True),
    )

    op.add_column(
        "tokens",
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=True),
    )
    op.create_foreign_key(
        "tokens_user_id_fkey",
        "tokens",
        "users",
        ["user_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_index("tokens_user_idx", "tokens", ["user_id"])

    op.add_column(
        "jobs",
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=True),
    )
    op.create_foreign_key(
        "jobs_user_id_fkey",
        "jobs",
        "users",
        ["user_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_index("jobs_user_idx", "jobs", ["user_id"])


def downgrade() -> None:
    op.drop_index("jobs_user_idx", table_name="jobs")
    op.drop_constraint("jobs_user_id_fkey", "jobs", type_="foreignkey")
    op.drop_column("jobs", "user_id")

    op.drop_index("tokens_user_idx", table_name="tokens")
    op.drop_constraint("tokens_user_id_fkey", "tokens", type_="foreignkey")
    op.drop_column("tokens", "user_id")

    op.drop_table("users")
