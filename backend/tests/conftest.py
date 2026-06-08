import os
import uuid
from pathlib import Path

import psycopg
import pytest
from alembic import command
from alembic.config import Config
from testcontainers.postgres import PostgresContainer

BACKEND_DIR = Path(__file__).resolve().parent.parent
ALEMBIC_INI = BACKEND_DIR / "alembic.ini"


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
