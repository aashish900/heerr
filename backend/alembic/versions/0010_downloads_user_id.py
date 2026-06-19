"""downloads.user_id + per-user composite unique (DEBT M3)

Revision ID: 0010
Revises: 0009
Create Date: 2026-06-19
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0010"
down_revision = "0009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. add user_id, nullable for the backfill step
    op.add_column(
        "downloads",
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=True),
    )
    # 2. backfill from the owning job (jobs.user_id is NOT NULL post-0005)
    op.execute("UPDATE downloads d SET user_id = j.user_id FROM jobs j WHERE d.job_id = j.id")
    # 3. lock NOT NULL
    op.alter_column("downloads", "user_id", nullable=False)
    # 4. FK to users, matching the ON DELETE RESTRICT posture of the rest of the schema
    op.create_foreign_key(
        "downloads_user_id_fkey",
        "downloads",
        "users",
        ["user_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    # 5. drop the global UNIQUE on source_url. Its name predates the
    #    spotify_track_uri -> source_url column rename (migration 0003), which
    #    renamed only the column, not the constraint. Discover it dynamically so
    #    this migration is name-agnostic.
    op.execute(
        """
        DO $$
        DECLARE cname text;
        BEGIN
          SELECT conname INTO cname
            FROM pg_constraint
           WHERE conrelid = 'downloads'::regclass
             AND contype = 'u'
             AND conkey = ARRAY[
                   (SELECT attnum FROM pg_attribute
                     WHERE attrelid = 'downloads'::regclass
                       AND attname = 'source_url')
                 ];
          IF cname IS NOT NULL THEN
            EXECUTE 'ALTER TABLE downloads DROP CONSTRAINT ' || quote_ident(cname);
          END IF;
        END $$;
        """
    )
    # 6. per-user uniqueness: one download row per (user, source_url)
    op.create_unique_constraint(
        "downloads_user_source_url_key",
        "downloads",
        ["user_id", "source_url"],
    )


def downgrade() -> None:
    op.drop_constraint("downloads_user_source_url_key", "downloads", type_="unique")
    # Re-add the global unique under its original (pre-0003) name. This fails if
    # two users share a source_url — an inherent hazard of reverting a per-user
    # model to a global one; acceptable for a break-glass downgrade.
    op.create_unique_constraint(
        "downloads_spotify_track_uri_key",
        "downloads",
        ["source_url"],
    )
    op.drop_constraint("downloads_user_id_fkey", "downloads", type_="foreignkey")
    op.drop_column("downloads", "user_id")
