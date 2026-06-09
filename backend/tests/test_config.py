import pytest
from pydantic import ValidationError

from app.config import Settings

REQUIRED_ENV = {
    "DATABASE_URL": "postgresql+asyncpg://u:p@h/d",
    "SPOTIFY_CLIENT_ID": "cid",
    "SPOTIFY_CLIENT_SECRET": "csecret",
    "MUSIC_OUTPUT_DIR": "/data/media/music",
}


@pytest.fixture(autouse=True)
def _clean_env(monkeypatch, tmp_path):
    monkeypatch.chdir(tmp_path)
    for key in REQUIRED_ENV:
        monkeypatch.delenv(key, raising=False)


def test_loads_from_env(monkeypatch):
    for k, v in REQUIRED_ENV.items():
        monkeypatch.setenv(k, v)
    s = Settings()
    assert s.database_url == REQUIRED_ENV["DATABASE_URL"]
    assert s.spotify_client_id == REQUIRED_ENV["SPOTIFY_CLIENT_ID"]
    assert s.spotify_client_secret.get_secret_value() == REQUIRED_ENV["SPOTIFY_CLIENT_SECRET"]
    assert s.music_output_dir == REQUIRED_ENV["MUSIC_OUTPUT_DIR"]


@pytest.mark.parametrize("missing", list(REQUIRED_ENV))
def test_missing_required_raises(monkeypatch, missing):
    for k, v in REQUIRED_ENV.items():
        if k != missing:
            monkeypatch.setenv(k, v)
    with pytest.raises(ValidationError) as exc:
        Settings()
    assert missing.lower() in str(exc.value).lower()


def test_secret_str_redacted_in_repr(monkeypatch):
    for k, v in REQUIRED_ENV.items():
        monkeypatch.setenv(k, v)
    s = Settings()
    assert REQUIRED_ENV["SPOTIFY_CLIENT_SECRET"] not in repr(s)
    assert REQUIRED_ENV["SPOTIFY_CLIENT_SECRET"] not in str(s)
