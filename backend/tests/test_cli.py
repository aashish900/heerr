import hashlib
import uuid

import psycopg
import pytest
from typer.testing import CliRunner

runner = CliRunner()


@pytest.fixture
def cli_env(monkeypatch, pg_libpq_url, pg_async_url):
    monkeypatch.setenv("DATABASE_URL", pg_async_url)
    monkeypatch.setenv("SPOTIFY_CLIENT_ID", "x")
    monkeypatch.setenv("SPOTIFY_CLIENT_SECRET", "y")
    monkeypatch.setenv("MUSIC_OUTPUT_DIR", "/data")
    monkeypatch.setenv("NAVIDROME_URL", "http://navidrome.example:4533")
    from app import config

    config.get_settings.cache_clear()
    yield pg_libpq_url
    with psycopg.connect(pg_libpq_url) as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM tokens")
        conn.commit()
    config.get_settings.cache_clear()


@pytest.fixture
def cli_app():
    from app.cli import app

    return app


def _hash(raw: str) -> str:
    return hashlib.sha256(raw.encode()).hexdigest()


def _fetch_token(libpq_url: str, token_hash: str):
    with psycopg.connect(libpq_url) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, owner_label, scopes, is_admin, revoked_at "
                "FROM tokens WHERE token_hash = %s",
                (token_hash,),
            )
            return cur.fetchone()


def test_create_token_prints_raw_and_persists_hash(cli_env, cli_app):
    result = runner.invoke(
        cli_app,
        [
            "create-token",
            "--owner",
            "aashish",
            "--scopes",
            "read,download",
        ],
    )
    assert result.exit_code == 0, result.stdout
    raw = result.stdout.strip()
    assert raw, "expected raw token on stdout"

    h = _hash(raw)
    row = _fetch_token(cli_env, h)
    assert row is not None, "token row missing from DB"
    _id, owner, scopes, is_admin, revoked_at = row
    assert owner == "aashish"
    assert set(scopes) == {"read", "download"}
    assert is_admin is False
    assert revoked_at is None

    # raw token must not appear anywhere in the tokens table
    with psycopg.connect(cli_env) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT count(*) FROM tokens WHERE token_hash = %s", (raw,))
            assert cur.fetchone()[0] == 0


def test_create_token_admin_flag(cli_env, cli_app):
    result = runner.invoke(
        cli_app,
        [
            "create-token",
            "--owner",
            "admin1",
            "--scopes",
            "read,download",
            "--admin",
        ],
    )
    assert result.exit_code == 0
    raw = result.stdout.strip()
    row = _fetch_token(cli_env, _hash(raw))
    assert row is not None
    assert row[3] is True  # is_admin


def test_create_token_invalid_scope_fails(cli_env, cli_app):
    result = runner.invoke(
        cli_app,
        ["create-token", "--owner", "x", "--scopes", "bogus,read"],
    )
    # DB CHECK constraint should reject; CLI propagates non-zero exit
    assert result.exit_code != 0


def test_list_tokens_shows_rows(cli_env, cli_app):
    r1 = runner.invoke(cli_app, ["create-token", "--owner", "u1", "--scopes", "read"])
    assert r1.exit_code == 0
    r2 = runner.invoke(
        cli_app,
        [
            "create-token",
            "--owner",
            "u2",
            "--scopes",
            "read,download",
            "--admin",
        ],
    )
    assert r2.exit_code == 0

    result = runner.invoke(cli_app, ["list-tokens"])
    assert result.exit_code == 0
    assert "u1" in result.stdout
    assert "u2" in result.stdout


def test_list_tokens_does_not_leak_raw_or_hash(cli_env, cli_app):
    r1 = runner.invoke(cli_app, ["create-token", "--owner", "u", "--scopes", "read"])
    raw = r1.stdout.strip()
    h = _hash(raw)

    result = runner.invoke(cli_app, ["list-tokens"])
    assert result.exit_code == 0
    assert raw not in result.stdout
    assert h not in result.stdout


def test_revoke_token_sets_revoked_at(cli_env, cli_app):
    r = runner.invoke(cli_app, ["create-token", "--owner", "u", "--scopes", "read"])
    raw = r.stdout.strip()
    row = _fetch_token(cli_env, _hash(raw))
    token_id = str(row[0])

    result = runner.invoke(cli_app, ["revoke-token", token_id])
    assert result.exit_code == 0

    with psycopg.connect(cli_env) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT revoked_at FROM tokens WHERE id = %s", (token_id,))
            assert cur.fetchone()[0] is not None


def test_revoke_token_unknown_id_fails(cli_env, cli_app):
    result = runner.invoke(cli_app, ["revoke-token", str(uuid.uuid4())])
    assert result.exit_code != 0


def test_revoke_token_already_revoked_fails(cli_env, cli_app):
    r = runner.invoke(cli_app, ["create-token", "--owner", "u", "--scopes", "read"])
    raw = r.stdout.strip()
    row = _fetch_token(cli_env, _hash(raw))
    token_id = str(row[0])

    r2 = runner.invoke(cli_app, ["revoke-token", token_id])
    assert r2.exit_code == 0
    r3 = runner.invoke(cli_app, ["revoke-token", token_id])
    assert r3.exit_code != 0


def test_revoke_token_invalid_uuid_fails(cli_env, cli_app):
    result = runner.invoke(cli_app, ["revoke-token", "not-a-uuid"])
    assert result.exit_code != 0
