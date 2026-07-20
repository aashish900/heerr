from __future__ import annotations

from datetime import datetime
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class PodcastEpisode(Base):
    __tablename__ = "podcast_episode"
    __table_args__ = (
        sa.ForeignKeyConstraint(
            ["channel_id"],
            ["podcast_channel.id"],
            ondelete="CASCADE",
            name="podcast_episode_channel_id_fkey",
        ),
        sa.UniqueConstraint(
            "channel_id",
            "guid",
            name="podcast_episode_channel_guid_key",
        ),
        sa.Index(
            "podcast_episode_channel_published_idx",
            "channel_id",
            sa.text("published_at DESC"),
        ),
    )

    id: Mapped[UUID] = mapped_column(
        postgresql.UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    )
    channel_id: Mapped[UUID] = mapped_column(postgresql.UUID(as_uuid=True), nullable=False)
    guid: Mapped[str] = mapped_column(sa.Text, nullable=False)
    title: Mapped[str] = mapped_column(sa.Text, nullable=False)
    description: Mapped[str | None] = mapped_column(sa.Text, nullable=True)
    published_at: Mapped[datetime | None] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=True
    )
    duration_s: Mapped[int | None] = mapped_column(sa.Integer, nullable=True)
    enclosure_url: Mapped[str] = mapped_column(sa.Text, nullable=False)
    enclosure_type: Mapped[str | None] = mapped_column(sa.Text, nullable=True)
    enclosure_bytes: Mapped[int | None] = mapped_column(sa.BigInteger, nullable=True)
    image_url: Mapped[str | None] = mapped_column(sa.Text, nullable=True)
    episode_no: Mapped[int | None] = mapped_column(sa.Integer, nullable=True)
    season_no: Mapped[int | None] = mapped_column(sa.Integer, nullable=True)
    downloaded_path: Mapped[str | None] = mapped_column(sa.Text, nullable=True)
    downloaded_bytes: Mapped[int | None] = mapped_column(sa.BigInteger, nullable=True)
    downloaded_at: Mapped[datetime | None] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=True
    )
