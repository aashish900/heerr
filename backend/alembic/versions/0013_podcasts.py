"""podcast schema — channels, episodes, subscriptions, progress (#53)

Revision ID: 0013
Revises: 0012
Create Date: 2026-07-20
"""

from __future__ import annotations

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "0013"
down_revision = "0012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "podcast_channel",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("feed_url", sa.Text(), nullable=False, unique=True),
        sa.Column("title", sa.Text(), nullable=False),
        sa.Column("author", sa.Text(), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("image_url", sa.Text(), nullable=True),
        sa.Column(
            "categories",
            postgresql.JSONB(),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
        sa.Column("last_fetched_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("http_etag", sa.Text(), nullable=True),
        sa.Column("http_last_modified", sa.Text(), nullable=True),
    )

    op.create_table(
        "podcast_episode",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("channel_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("guid", sa.Text(), nullable=False),
        sa.Column("title", sa.Text(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("published_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("duration_s", sa.Integer(), nullable=True),
        sa.Column("enclosure_url", sa.Text(), nullable=False),
        sa.Column("enclosure_type", sa.Text(), nullable=True),
        sa.Column("enclosure_bytes", sa.BigInteger(), nullable=True),
        sa.Column("image_url", sa.Text(), nullable=True),
        sa.Column("episode_no", sa.Integer(), nullable=True),
        sa.Column("season_no", sa.Integer(), nullable=True),
        sa.Column("downloaded_path", sa.Text(), nullable=True),
        sa.Column("downloaded_bytes", sa.BigInteger(), nullable=True),
        sa.Column("downloaded_at", sa.TIMESTAMP(timezone=True), nullable=True),
    )
    op.create_foreign_key(
        "podcast_episode_channel_id_fkey",
        "podcast_episode",
        "podcast_channel",
        ["channel_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_unique_constraint(
        "podcast_episode_channel_guid_key",
        "podcast_episode",
        ["channel_id", "guid"],
    )
    op.create_index(
        "podcast_episode_channel_published_idx",
        "podcast_episode",
        ["channel_id", sa.text("published_at DESC")],
    )

    op.create_table(
        "podcast_subscription",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("channel_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "subscribed_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )
    op.create_foreign_key(
        "podcast_subscription_user_id_fkey",
        "podcast_subscription",
        "users",
        ["user_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        "podcast_subscription_channel_id_fkey",
        "podcast_subscription",
        "podcast_channel",
        ["channel_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_unique_constraint(
        "podcast_subscription_user_channel_key",
        "podcast_subscription",
        ["user_id", "channel_id"],
    )
    op.create_index("podcast_subscription_user_idx", "podcast_subscription", ["user_id"])

    op.create_table(
        "podcast_progress",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("episode_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "position_s", sa.Integer(), nullable=False, server_default=sa.text("0")
        ),
        sa.Column(
            "played", sa.Boolean(), nullable=False, server_default=sa.text("false")
        ),
        sa.Column("last_played_at", sa.TIMESTAMP(timezone=True), nullable=True),
    )
    op.create_foreign_key(
        "podcast_progress_user_id_fkey",
        "podcast_progress",
        "users",
        ["user_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        "podcast_progress_episode_id_fkey",
        "podcast_progress",
        "podcast_episode",
        ["episode_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_unique_constraint(
        "podcast_progress_user_episode_key",
        "podcast_progress",
        ["user_id", "episode_id"],
    )
    op.create_index("podcast_progress_user_idx", "podcast_progress", ["user_id"])


def downgrade() -> None:
    op.drop_table("podcast_progress")
    op.drop_table("podcast_subscription")
    op.drop_table("podcast_episode")
    op.drop_table("podcast_channel")
