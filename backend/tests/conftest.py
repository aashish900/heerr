import hashlib
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path

import psycopg
import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from testcontainers.postgres import PostgresContainer

from app.models import Token

BACKEND_DIR = Path(__file__).resolve().parent.parent
ALEMBIC_INI = BACKEND_DIR / "alembic.ini"


@pytest.fixture(scope="session")
def pg_async_url(pg_libpq_url):
    return pg_libpq_url.replace(
        "postgresql://", "postgresql+asyncpg://", 1
    )


@pytest.fixture(scope="session")
def pg_libpq_url():
    with PostgresContainer("pgvector/pgvector:pg17") as pg:
        host = pg.get_container_host_ip()
        port = pg.get_exposed_port(5432)
        libpq = (
            f"postgresql://{pg.username}:{pg.password}"
            f"@{host}:{port}/{pg.dbname}"
        )
        sa_url = (
            f"postgresql+psycopg://{pg.username}:{pg.password}"
            f"@{host}:{port}/{pg.dbname}"
        )
        os.environ["DATABASE_URL"] = sa_url
        cfg = Config(str(ALEMBIC_INI))
        command.upgrade(cfg, "head")
        yield libpq


@pytest.fixture
def db_conn(pg_libpq_url):
    conn = psycopg.connect(pg_libpq_url)
    try:
        yield conn
    finally:
        conn.rollback()
        conn.close()


@pytest.fixture
def seed_token(db_conn):
    cur = db_conn.cursor()
    cur.execute(
        "INSERT INTO tokens (token_hash, owner_label, scopes) "
        "VALUES (%s, %s, %s) RETURNING id",
        (f"hash-{uuid.uuid4()}", "test", ["read", "download"]),
    )
    return cur.fetchone()[0]


# ----- shared FastAPI-test fixtures ----------------------------------------


@pytest.fixture
async def app_engine(pg_async_url):
    engine = create_async_engine(pg_async_url, pool_pre_ping=True)
    yield engine
    await engine.dispose()


@pytest.fixture
async def app_sm(app_engine):
    return async_sessionmaker(app_engine, expire_on_commit=False)


@pytest.fixture
async def make_token(app_sm):
    """Async factory: returns the raw token string, cleans rows on teardown."""
    inserted_hashes: list[str] = []

    async def _make(
        owner: str = "test",
        scopes: tuple[str, ...] = ("read", "download"),
        is_admin: bool = False,
        revoked: bool = False,
    ) -> str:
        raw = f"raw-{uuid.uuid4().hex}"
        h = hashlib.sha256(raw.encode()).hexdigest()
        async with app_sm() as s:
            s.add(
                Token(
                    token_hash=h,
                    owner_label=owner,
                    scopes=list(scopes),
                    is_admin=is_admin,
                    revoked_at=datetime.now(timezone.utc) if revoked else None,
                )
            )
            await s.commit()
        inserted_hashes.append(h)
        return raw

    yield _make

    async with app_sm() as s:
        for h in inserted_hashes:
            await s.execute(
                text("DELETE FROM tokens WHERE token_hash = :h"), {"h": h}
            )
        await s.commit()
