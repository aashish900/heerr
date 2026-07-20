from __future__ import annotations

from datetime import datetime
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class PodcastSubscription(Base):
    __tablename__ = "podcast_subscription"
    __table_args__ = (
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="RESTRICT",
            name="podcast_subscription_user_id_fkey",
        ),
        sa.ForeignKeyConstraint(
            ["channel_id"],
            ["podcast_channel.id"],
            ondelete="CASCADE",
            name="podcast_subscription_channel_id_fkey",
        ),
        sa.UniqueConstraint(
            "user_id",
            "channel_id",
            name="podcast_subscription_user_channel_key",
        ),
        sa.Index("podcast_subscription_user_idx", "user_id"),
    )

    id: Mapped[UUID] = mapped_column(
        postgresql.UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    )
    user_id: Mapped[UUID] = mapped_column(postgresql.UUID(as_uuid=True), nullable=False)
    channel_id: Mapped[UUID] = mapped_column(postgresql.UUID(as_uuid=True), nullable=False)
    subscribed_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True),
        nullable=False,
        server_default=sa.text("now()"),
    )
