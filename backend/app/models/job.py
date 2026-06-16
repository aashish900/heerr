from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.user import User


class Job(Base):
    __tablename__ = "jobs"
    __table_args__ = (
        sa.ForeignKeyConstraint(
            ["created_by_token_id"],
            ["tokens.id"],
            ondelete="RESTRICT",
            name="jobs_created_by_token_id_fkey",
        ),
        sa.CheckConstraint(
            "state IN ('queued','running','done','failed')",
            name="jobs_state_valid",
        ),
        sa.CheckConstraint(
            "source_type IN ('song','album','playlist')",
            name="jobs_source_type_valid",
        ),
        sa.Index(
            "jobs_active_user_source_url_idx",
            "user_id",
            "source_url",
            unique=True,
            postgresql_where=sa.text("state IN ('queued','running')"),
        ),
        sa.Index(
            "jobs_state_created_idx",
            "state",
            sa.text("created_at DESC"),
        ),
        sa.Index("jobs_token_idx", "created_by_token_id"),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="RESTRICT",
            name="jobs_user_id_fkey",
        ),
        sa.Index("jobs_user_idx", "user_id"),
    )

    id: Mapped[UUID] = mapped_column(
        postgresql.UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    )
    source_url: Mapped[str] = mapped_column(sa.Text, nullable=False)
    source_type: Mapped[str] = mapped_column(sa.Text, nullable=False)
    state: Mapped[str] = mapped_column(sa.Text, nullable=False)
    display_name: Mapped[str | None] = mapped_column(sa.Text, nullable=True)
    error_msg: Mapped[str | None] = mapped_column(sa.Text, nullable=True)
    attempt_count: Mapped[int] = mapped_column(
        sa.Integer, nullable=False, server_default=sa.text("0")
    )
    created_by_token_id: Mapped[UUID] = mapped_column(postgresql.UUID(as_uuid=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True),
        nullable=False,
        server_default=sa.text("now()"),
    )
    started_at: Mapped[datetime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    finished_at: Mapped[datetime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    user_id: Mapped[UUID] = mapped_column(
        postgresql.UUID(as_uuid=True),
        nullable=False,
        server_default=sa.text("system_admin_user_id()"),
    )

    user: Mapped[User] = relationship(back_populates="jobs")
