"""schema v1 — tokens, jobs, downloads

Revision ID: 0001
Revises:
Create Date: 2026-06-08
"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    op.create_table(
        "tokens",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("token_hash", sa.Text(), nullable=False, unique=True),
        sa.Column("owner_label", sa.Text(), nullable=False),
        sa.Column(
            "scopes",
            postgresql.ARRAY(sa.Text()),
            nullable=False,
        ),
        sa.Column(
            "is_admin",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column("revoked_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.CheckConstraint(
            "scopes <@ ARRAY['read','download']::text[]",
            name="tokens_scopes_valid",
        ),
    )

    op.create_table(
        "jobs",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("spotify_uri", sa.Text(), nullable=False),
        sa.Column("spotify_type", sa.Text(), nullable=False),
        sa.Column("state", sa.Text(), nullable=False),
        sa.Column("error_msg", sa.Text(), nullable=True),
        sa.Column(
            "attempt_count",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("0"),
        ),
        sa.Column(
            "created_by_token_id",
            postgresql.UUID(as_uuid=True),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column("started_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("finished_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(
            ["created_by_token_id"],
            ["tokens.id"],
            ondelete="RESTRICT",
            name="jobs_created_by_token_id_fkey",
        ),
        sa.CheckConstraint(
            "state IN ('queued','running','done','failed')",
            name="jobs_state_valid",
        ),
        sa.CheckConstraint(
            "spotify_type IN ('track','album','playlist')",
            name="jobs_type_valid",
        ),
    )
    op.create_index(
        "jobs_active_uri_idx",
        "jobs",
        ["spotify_uri"],
        unique=True,
        postgresql_where=sa.text("state IN ('queued','running')"),
    )
    op.create_index(
        "jobs_state_created_idx",
        "jobs",
        ["state", sa.text("created_at DESC")],
    )
    op.create_index("jobs_token_idx", "jobs", ["created_by_token_id"])

    op.create_table(
        "downloads",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("spotify_track_uri", sa.Text(), nullable=False, unique=True),
        sa.Column("job_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("output_path", sa.Text(), nullable=False),
        sa.Column("file_size_bytes", sa.BigInteger(), nullable=True),
        sa.Column(
            "downloaded_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.ForeignKeyConstraint(
            ["job_id"],
            ["jobs.id"],
            ondelete="RESTRICT",
            name="downloads_job_id_fkey",
        ),
    )
    op.create_index("downloads_job_idx", "downloads", ["job_id"])


def downgrade() -> None:
    op.drop_index("downloads_job_idx", table_name="downloads")
    op.drop_table("downloads")
    op.drop_index("jobs_token_idx", table_name="jobs")
    op.drop_index("jobs_state_created_idx", table_name="jobs")
    op.drop_index("jobs_active_uri_idx", table_name="jobs")
    op.drop_table("jobs")
    op.drop_table("tokens")
    op.execute("DROP EXTENSION IF EXISTS vector")
    op.execute("DROP EXTENSION IF EXISTS pgcrypto")
