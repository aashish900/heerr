from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class PodcastChannel(Base):
    __tablename__ = "podcast_channel"

    id: Mapped[UUID] = mapped_column(
        postgresql.UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    )
    feed_url: Mapped[str] = mapped_column(sa.Text, nullable=False, unique=True)
    title: Mapped[str] = mapped_column(sa.Text, nullable=False)
    author: Mapped[str | None] = mapped_column(sa.Text, nullable=True)
    description: Mapped[str | None] = mapped_column(sa.Text, nullable=True)
    image_url: Mapped[str | None] = mapped_column(sa.Text, nullable=True)
    categories: Mapped[list[Any]] = mapped_column(
        postgresql.JSONB,
        nullable=False,
        server_default=sa.text("'[]'::jsonb"),
    )
    last_fetched_at: Mapped[datetime | None] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=True
    )
    http_etag: Mapped[str | None] = mapped_column(sa.Text, nullable=True)
    http_last_modified: Mapped[str | None] = mapped_column(sa.Text, nullable=True)
