from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base

# Mirrors the `jam_command_kind_valid` CHECK in migration 0015.
JAM_COMMAND_KINDS = ("play_songs", "enqueue", "play", "pause", "next", "prev", "seek")


class JamSession(Base):
    __tablename__ = "jam_session"
    __table_args__ = (
        sa.ForeignKeyConstraint(
            ["host_user_id"],
            ["users.id"],
            ondelete="RESTRICT",
            name="jam_session_host_user_id_fkey",
        ),
        sa.Index(
            "jam_session_active_code_key",
            "code",
            unique=True,
            postgresql_where=sa.text("ended_at IS NULL"),
        ),
        sa.Index(
            "jam_session_active_host_idx",
            "host_user_id",
            postgresql_where=sa.text("ended_at IS NULL"),
        ),
    )

    id: Mapped[UUID] = mapped_column(
        postgresql.UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    )
    host_user_id: Mapped[UUID] = mapped_column(postgresql.UUID(as_uuid=True), nullable=False)
    code: Mapped[str] = mapped_column(sa.Text, nullable=False)
    state: Mapped[dict[str, Any] | None] = mapped_column(postgresql.JSONB, nullable=True)
    state_at: Mapped[datetime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True),
        nullable=False,
        server_default=sa.text("now()"),
    )
    expires_at: Mapped[datetime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False)
    ended_at: Mapped[datetime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)


class JamCommand(Base):
    __tablename__ = "jam_command"
    __table_args__ = (
        sa.ForeignKeyConstraint(
            ["session_id"],
            ["jam_session.id"],
            ondelete="CASCADE",
            name="jam_command_session_id_fkey",
        ),
        sa.ForeignKeyConstraint(
            ["sender_user_id"],
            ["users.id"],
            ondelete="RESTRICT",
            name="jam_command_sender_user_id_fkey",
        ),
        sa.CheckConstraint(
            "kind IN (" + ",".join(f"'{k}'" for k in JAM_COMMAND_KINDS) + ")",
            name="jam_command_kind_valid",
        ),
        sa.Index("jam_command_session_idx", "session_id", "id"),
    )

    id: Mapped[int] = mapped_column(sa.BigInteger, primary_key=True)
    session_id: Mapped[UUID] = mapped_column(postgresql.UUID(as_uuid=True), nullable=False)
    sender_user_id: Mapped[UUID] = mapped_column(postgresql.UUID(as_uuid=True), nullable=False)
    kind: Mapped[str] = mapped_column(sa.Text, nullable=False)
    payload: Mapped[dict[str, Any]] = mapped_column(
        postgresql.JSONB, nullable=False, server_default=sa.text("'{}'::jsonb")
    )
    created_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True),
        nullable=False,
        server_default=sa.text("now()"),
    )
