import pytest
from sqlalchemy import text

from app import config, db


async def test_factories_round_trip(pg_async_url):
    engine = db.build_engine(pg_async_url)
    sm = db.build_sessionmaker(engine)
    try:
        async with sm() as session:
            result = await session.execute(text("SELECT 1"))
            assert result.scalar_one() == 1
    finally:
        await engine.dispose()


async def test_get_session_yields_commits_closes(monkeypatch, pg_async_url):
    monkeypatch.setenv("DATABASE_URL", pg_async_url)
    monkeypatch.setenv("SPOTIFY_CLIENT_ID", "x")
    monkeypatch.setenv("SPOTIFY_CLIENT_SECRET", "y")
    monkeypatch.setenv("MUSIC_OUTPUT_DIR", "/d")
    config.get_settings.cache_clear()
    db._engine.cache_clear()
    db._sessionmaker.cache_clear()

    agen = db.get_session()
    session = await agen.__anext__()
    result = await session.execute(text("SELECT 1"))
    assert result.scalar_one() == 1
    with pytest.raises(StopAsyncIteration):
        await agen.__anext__()

    # session should be closed after generator exhausts
    assert not session.in_transaction()

    await db._engine().dispose()
    db._engine.cache_clear()
    db._sessionmaker.cache_clear()
    config.get_settings.cache_clear()


async def test_get_session_rolls_back_on_exception(monkeypatch, pg_async_url):
    monkeypatch.setenv("DATABASE_URL", pg_async_url)
    monkeypatch.setenv("SPOTIFY_CLIENT_ID", "x")
    monkeypatch.setenv("SPOTIFY_CLIENT_SECRET", "y")
    monkeypatch.setenv("MUSIC_OUTPUT_DIR", "/d")
    config.get_settings.cache_clear()
    db._engine.cache_clear()
    db._sessionmaker.cache_clear()

    agen = db.get_session()
    session = await agen.__anext__()
    await session.execute(text("SELECT 1"))
    with pytest.raises(RuntimeError):
        await agen.athrow(RuntimeError("simulated handler failure"))

    assert not session.in_transaction()

    await db._engine().dispose()
    db._engine.cache_clear()
    db._sessionmaker.cache_clear()
    config.get_settings.cache_clear()
