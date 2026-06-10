"""replace spotify columns with source_url/source_type

Revision ID: 0003
Revises: 0002
Create Date: 2026-06-10
"""

from alembic import op
import sqlalchemy as sa

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # --- jobs table ---
    op.alter_column("jobs", "spotify_uri", new_column_name="source_url")
    op.alter_column("jobs", "spotify_type", new_column_name="source_type")

    # Migrate existing type values: 'track' → 'song'
    op.execute("UPDATE jobs SET source_type = 'song' WHERE source_type = 'track'")

    # Replace CHECK constraint
    op.drop_constraint("jobs_type_valid", "jobs", type_="check")
    op.create_check_constraint(
        "jobs_source_type_valid",
        "jobs",
        "source_type IN ('song','album','playlist')",
    )

    # Recreate partial unique index under the new column name
    op.drop_index("jobs_active_uri_idx", table_name="jobs")
    op.create_index(
        "jobs_active_source_url_idx",
        "jobs",
        ["source_url"],
        unique=True,
        postgresql_where=sa.text("state IN ('queued','running')"),
    )

    # --- downloads table ---
    op.alter_column("downloads", "spotify_track_uri", new_column_name="source_url")


def downgrade() -> None:
    op.alter_column("downloads", "source_url", new_column_name="spotify_track_uri")

    op.drop_index("jobs_active_source_url_idx", table_name="jobs")
    op.create_index(
        "jobs_active_uri_idx",
        "jobs",
        ["source_url"],
        unique=True,
        postgresql_where=sa.text("state IN ('queued','running')"),
    )

    op.drop_constraint("jobs_source_type_valid", "jobs", type_="check")
    op.create_check_constraint(
        "jobs_type_valid",
        "jobs",
        "spotify_type IN ('track','album','playlist')",
    )

    op.execute("UPDATE jobs SET source_type = 'track' WHERE source_type = 'song'")

    op.alter_column("jobs", "source_type", new_column_name="spotify_type")
    op.alter_column("jobs", "source_url", new_column_name="spotify_uri")
