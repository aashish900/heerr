from sqlalchemy import create_engine

import app.models  # noqa: F401  (registers all models on Base.metadata)
from alembic.autogenerate import compare_metadata
from alembic.runtime.migration import MigrationContext
from app.models.base import Base


def _include_object(obj, name, type_, reflected, compare_to):
    # alembic_version is owned by Alembic itself, not the app schema.
    return not (type_ == "table" and name == "alembic_version")


def test_orm_matches_migrated_schema(pg_libpq_url):
    sa_url = pg_libpq_url.replace("postgresql://", "postgresql+psycopg://", 1)
    engine = create_engine(sa_url)
    with engine.connect() as conn:
        mc = MigrationContext.configure(conn, opts={"include_object": _include_object})
        diffs = compare_metadata(mc, Base.metadata)
    assert diffs == [], f"Drift between ORM and migrated schema: {diffs}"
