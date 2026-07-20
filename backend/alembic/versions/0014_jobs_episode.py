"""jobs.episode_id + widen source_type to allow 'episode' (#53 P5)

Revision ID: 0014
Revises: 0013
Create Date: 2026-07-20
"""

from __future__ import annotations

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "0014"
down_revision = "0013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_constraint("jobs_source_type_valid", "jobs", type_="check")
    op.create_check_constraint(
        "jobs_source_type_valid",
        "jobs",
        "source_type IN ('song','album','playlist','episode')",
    )

    op.add_column(
        "jobs",
        sa.Column("episode_id", postgresql.UUID(as_uuid=True), nullable=True),
    )
    op.create_foreign_key(
        "jobs_episode_id_fkey",
        "jobs",
        "podcast_episode",
        ["episode_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index("jobs_episode_idx", "jobs", ["episode_id"])


def downgrade() -> None:
    op.drop_index("jobs_episode_idx", table_name="jobs")
    op.drop_constraint("jobs_episode_id_fkey", "jobs", type_="foreignkey")
    op.drop_column("jobs", "episode_id")

    op.drop_constraint("jobs_source_type_valid", "jobs", type_="check")
    op.create_check_constraint(
        "jobs_source_type_valid",
        "jobs",
        "source_type IN ('song','album','playlist')",
    )
