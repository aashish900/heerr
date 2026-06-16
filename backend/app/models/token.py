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


class Token(Base):
    __tablename__ = "tokens"
    __table_args__ = (
        sa.CheckConstraint(
            "scopes <@ ARRAY['read','download']::text[]",
            name="tokens_scopes_valid",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="RESTRICT",
            name="tokens_user_id_fkey",
        ),
        sa.Index("tokens_user_idx", "user_id"),
    )

    id: Mapped[UUID] = mapped_column(
        postgresql.UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    )
    token_hash: Mapped[str] = mapped_column(sa.Text, nullable=False, unique=True)
    owner_label: Mapped[str] = mapped_column(sa.Text, nullable=False)
    scopes: Mapped[list[str]] = mapped_column(postgresql.ARRAY(sa.Text()), nullable=False)
    is_admin: Mapped[bool] = mapped_column(
        sa.Boolean, nullable=False, server_default=sa.text("false")
    )
    created_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True),
        nullable=False,
        server_default=sa.text("now()"),
    )
    revoked_at: Mapped[datetime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    user_id: Mapped[UUID] = mapped_column(
        postgresql.UUID(as_uuid=True),
        nullable=False,
        server_default=sa.text("system_admin_user_id()"),
    )

    user: Mapped[User] = relationship(back_populates="tokens")
