from datetime import datetime
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


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
