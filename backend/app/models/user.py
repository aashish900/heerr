from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING, Any
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.job import Job
    from app.models.token import Token


class User(Base):
    __tablename__ = "users"

    id: Mapped[UUID] = mapped_column(
        postgresql.UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    )
    navidrome_username: Mapped[str] = mapped_column(sa.Text, nullable=False, unique=True)
    created_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True),
        nullable=False,
        server_default=sa.text("now()"),
    )
    last_login_at: Mapped[datetime | None] = mapped_column(
        sa.TIMESTAMP(timezone=True), nullable=True
    )
    # Profile fields (migration 0012). All nullable — unset until the user
    # saves their profile for the first time.
    display_name: Mapped[str | None] = mapped_column(sa.Text, nullable=True)
    nickname: Mapped[str | None] = mapped_column(sa.Text, nullable=True)
    bio: Mapped[str | None] = mapped_column(sa.Text, nullable=True)
    avatar_data: Mapped[bytes | None] = mapped_column(sa.LargeBinary, nullable=True)

    # Per-user recommendation config (lastfm_username, listenbrainz_token, ...).
    # Always an object — NOT NULL with a '{}' server default (migration 0011).
    settings: Mapped[dict[str, Any]] = mapped_column(
        postgresql.JSONB,
        nullable=False,
        server_default=sa.text("'{}'::jsonb"),
    )

    tokens: Mapped[list[Token]] = relationship(back_populates="user")
    jobs: Mapped[list[Job]] = relationship(back_populates="user")
