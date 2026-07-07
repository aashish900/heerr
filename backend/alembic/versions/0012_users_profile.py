"""users profile columns — display_name, nickname, bio, avatar_data

Revision ID: 0012
Revises: 0011
Create Date: 2026-07-07
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0012"
down_revision = "0011"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("display_name", sa.Text, nullable=True))
    op.add_column("users", sa.Column("nickname", sa.Text, nullable=True))
    op.add_column("users", sa.Column("bio", sa.Text, nullable=True))
    op.add_column("users", sa.Column("avatar_data", sa.LargeBinary, nullable=True))


def downgrade() -> None:
    op.drop_column("users", "avatar_data")
    op.drop_column("users", "bio")
    op.drop_column("users", "nickname")
    op.drop_column("users", "display_name")
