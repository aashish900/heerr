import hashlib
import os
import uuid
from datetime import UTC, datetime
from pathlib import Path

import psycopg
import pytest
from sqlalchemy import text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from testcontainers.postgres import PostgresContainer

from alembic import command
from alembic.config import Config
from app.models import Token
from tests.migration_guard import verify_db_at_head_or_repair

BACKEND_DIR = Path(__file__).resolve().parent.parent
ALEMBIC_INI = BACKEND_DIR / "alembic.ini"


@pytest.fixture(autouse=True)
def _guard_db_at_head(request, monkeypatch):
    """T1: any test that runs `alembic downgrade` must leave the DB at head.

    Wraps `alembic.command.downgrade` to detect when a test moved the schema;
    on teardown, if a downgrade ran, asserts the DB is back at head (repairing
    it first so a single forgetful test cannot poison the rest of the session).
    Zero DB cost for the vast majority of tests, which never downgrade.
    """
    downgraded = {"flag": False}
    real_downgrade = command.downgrade

    def _tracked(*args, **kwargs):
        downgraded["flag"] = True
        return real_downgrade(*args, **kwargs)

    monkeypatch.setattr(command, "downgrade", _tracked)
    yield
    if downgraded["flag"]:
        verify_db_at_head_or_repair(request.node.nodeid)


@pytest.fixture(scope="session")
def pg_async_url(pg_libpq_url):
    return pg_libpq_url.replace("postgresql://", "postgresql+asyncpg://", 1)


@pytest.fixture(scope="session")
def pg_libpq_url():
    with PostgresContainer("pgvector/pgvector:pg17") as pg:
        host = pg.get_container_host_ip()
        port = pg.get_exposed_port(5432)
        libpq = f"postgresql://{pg.username}:{pg.password}" f"@{host}:{port}/{pg.dbname}"
        sa_url = f"postgresql+psycopg://{pg.username}:{pg.password}" f"@{host}:{port}/{pg.dbname}"
        os.environ["DATABASE_URL"] = sa_url
        os.environ.setdefault("MUSIC_OUTPUT_DIR", "/tmp/heerr-test-music")
        os.environ.setdefault("NAVIDROME_URL", "http://navidrome.test:4533")
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
    cur.execute("SELECT system_admin_user_id()")
    sys_admin = cur.fetchone()[0]
    cur.execute(
        "INSERT INTO tokens (token_hash, scopes, user_id) " "VALUES (%s, %s, %s) RETURNING id",
        (f"hash-{uuid.uuid4()}", ["read", "download"], sys_admin),
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
async def system_admin_user_id(app_sm):
    """UUID of the system-admin user seeded by migration 0005.

    Used by fixtures that need a valid `user_id` FK target without seeding a
    fresh user per test. Post-0008 the server default is gone, so callers
    must pass `user_id` explicitly.
    """
    async with app_sm() as s:
        r = await s.execute(text("SELECT system_admin_user_id()"))
        return r.scalar_one()


@pytest.fixture
async def make_token(app_sm, system_admin_user_id):
    """Async factory: returns the raw token string, cleans rows on teardown."""
    inserted_hashes: list[str] = []

    async def _make(
        scopes: tuple[str, ...] = ("read", "download"),
        is_admin: bool = False,
        revoked: bool = False,
        user_id: uuid.UUID | None = None,
    ) -> str:
        raw = f"raw-{uuid.uuid4().hex}"
        h = hashlib.sha256(raw.encode()).hexdigest()
        async with app_sm() as s:
            s.add(
                Token(
                    token_hash=h,
                    scopes=list(scopes),
                    is_admin=is_admin,
                    revoked_at=datetime.now(UTC) if revoked else None,
                    user_id=user_id or system_admin_user_id,
                )
            )
            await s.commit()
        inserted_hashes.append(h)
        return raw

    yield _make

    async with app_sm() as s:
        for h in inserted_hashes:
            await s.execute(text("DELETE FROM tokens WHERE token_hash = :h"), {"h": h})
        await s.commit()
