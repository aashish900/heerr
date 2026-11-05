"""jam_session + jam_command: guest-to-host remote control relay (JM1)

Revision ID: 0015
Revises: 0014
Create Date: 2026-11-05
"""

from __future__ import annotations

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "0015"
down_revision = "0014"
branch_labels = None
depends_on = None

JAM_COMMAND_KINDS = ("play_songs", "enqueue", "play", "pause", "next", "prev", "seek")


def upgrade() -> None:
    op.create_table(
        "jam_session",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("host_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("code", sa.Text, nullable=False),
        sa.Column("state", postgresql.JSONB, nullable=True),
        sa.Column("state_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column("expires_at", sa.TIMESTAMP(timezone=True), nullable=False),
        sa.Column("ended_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(
            ["host_user_id"],
            ["users.id"],
            ondelete="RESTRICT",
            name="jam_session_host_user_id_fkey",
        ),
    )
    # A code is only reserved while its session is live; ended rows free it.
    op.create_index(
        "jam_session_active_code_key",
        "jam_session",
        ["code"],
        unique=True,
        postgresql_where=sa.text("ended_at IS NULL"),
    )
    op.create_index(
        "jam_session_active_host_idx",
        "jam_session",
        ["host_user_id"],
        postgresql_where=sa.text("ended_at IS NULL"),
    )

    op.create_table(
        "jam_command",
        sa.Column("id", sa.BigInteger, primary_key=True),
        sa.Column("session_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("sender_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("kind", sa.Text, nullable=False),
        sa.Column(
            "payload",
            postgresql.JSONB,
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.ForeignKeyConstraint(
            ["session_id"],
            ["jam_session.id"],
            ondelete="CASCADE",
            name="jam_command_session_id_fkey",
        ),
        sa.ForeignKeyConstraint(
            ["sender_user_id"],
            ["users.id"],
            ondelete="RESTRICT",
            name="jam_command_sender_user_id_fkey",
        ),
        sa.CheckConstraint(
            "kind IN (" + ",".join(f"'{k}'" for k in JAM_COMMAND_KINDS) + ")",
            name="jam_command_kind_valid",
        ),
    )
    op.create_index("jam_command_session_idx", "jam_command", ["session_id", "id"])


def downgrade() -> None:
    op.drop_index("jam_command_session_idx", table_name="jam_command")
    op.drop_table("jam_command")
    op.drop_index("jam_session_active_host_idx", table_name="jam_session")
    op.drop_index("jam_session_active_code_key", table_name="jam_session")
    op.drop_table("jam_session")
