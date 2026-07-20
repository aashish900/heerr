from __future__ import annotations

from datetime import datetime
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class PodcastProgress(Base):
    __tablename__ = "podcast_progress"
    __table_args__ = (
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="RESTRICT",
            name="podcast_progress_user_id_fkey",
        ),
        sa.ForeignKeyConstraint(
            ["episode_id"],
            ["podcast_episode.id"],
            ondelete="CASCADE",
            name="podcast_progress_episode_id_fkey",
        ),
        sa.UniqueConstraint(
            "user_id",
            "episode_id",
            name="podcast_progress_user_episode_key",
        ),
        sa.Index("podcast_progress_user_idx", "user_id"),
    )

    id: Mapped[UUID] = mapped_column(
        postgresql.UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    )
    user_id: Mapped[UUID] = mapped_column(postgresql.UUID(as_uuid=True), nullable=False)
    episode_id: Mapped[UUID] = mapped_column(postgresql.UUID(as_uuid=True), nullable=False)
    position_s: Mapped[int] = mapped_column(sa.Integer, nullable=False, server_default=sa.text("0"))
    played: Mapped[bool] = mapped_column(
        sa.Boolean, nullable=False, server_default=sa.text("false")
    )
    last_played_at: Mapped[datetime | None] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=True
    )
