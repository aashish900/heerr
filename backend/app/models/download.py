from datetime import datetime
from uuid import UUID

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Download(Base):
    __tablename__ = "downloads"
    __table_args__ = (
        sa.ForeignKeyConstraint(
            ["job_id"],
            ["jobs.id"],
            ondelete="RESTRICT",
            name="downloads_job_id_fkey",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="RESTRICT",
            name="downloads_user_id_fkey",
        ),
        sa.UniqueConstraint(
            "user_id",
            "source_url",
            name="downloads_user_source_url_key",
        ),
        sa.Index("downloads_job_idx", "job_id"),
    )

    id: Mapped[UUID] = mapped_column(
        postgresql.UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    )
    source_url: Mapped[str] = mapped_column(sa.Text, nullable=False)
    job_id: Mapped[UUID] = mapped_column(postgresql.UUID(as_uuid=True), nullable=False)
    user_id: Mapped[UUID] = mapped_column(postgresql.UUID(as_uuid=True), nullable=False)
    output_path: Mapped[str] = mapped_column(sa.Text, nullable=False)
    file_size_bytes: Mapped[int | None] = mapped_column(sa.BigInteger, nullable=True)
    downloaded_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True),
        nullable=False,
        server_default=sa.text("now()"),
    )
