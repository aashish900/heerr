"""users.settings JSONB for per-user recommendation config (DEBT M5)

Revision ID: 0011
Revises: 0010
Create Date: 2026-06-19
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0011"
down_revision = "0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Per-user recommendation settings (lastfm_username, listenbrainz_token, ...).
    # NOT NULL with a '{}' default so every existing and future row carries an
    # object, never NULL — readers can `.get(...)` without a None guard.
    op.add_column(
        "users",
        sa.Column(
            "settings",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "settings")
