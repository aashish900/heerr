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
        sa.Index("downloads_job_idx", "job_id"),
    )

    id: Mapped[UUID] = mapped_column(
        postgresql.UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    )
    spotify_track_uri: Mapped[str] = mapped_column(
        sa.Text, nullable=False, unique=True
    )
    job_id: Mapped[UUID] = mapped_column(
        postgresql.UUID(as_uuid=True), nullable=False
    )
    output_path: Mapped[str] = mapped_column(sa.Text, nullable=False)
    file_size_bytes: Mapped[int | None] = mapped_column(
        sa.BigInteger, nullable=True
    )
    downloaded_at: Mapped[datetime] = mapped_column(
        sa.TIMESTAMP(timezone=True),
        nullable=False,
        server_default=sa.text("now()"),
    )
