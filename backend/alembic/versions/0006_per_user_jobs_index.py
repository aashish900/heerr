"""per-user partial unique index on jobs (drop global, create per-user)

Revision ID: 0006
Revises: 0005
Create Date: 2026-06-16
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_index("jobs_active_source_url_idx", table_name="jobs")
    op.create_index(
        "jobs_active_user_source_url_idx",
        "jobs",
        ["user_id", "source_url"],
        unique=True,
        postgresql_where=sa.text("state IN ('queued','running')"),
    )


def downgrade() -> None:
    op.drop_index("jobs_active_user_source_url_idx", table_name="jobs")
    op.create_index(
        "jobs_active_source_url_idx",
        "jobs",
        ["source_url"],
        unique=True,
        postgresql_where=sa.text("state IN ('queued','running')"),
    )
