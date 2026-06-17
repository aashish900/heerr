import pytest
from pydantic import ValidationError

from app.config import Settings

REQUIRED_ENV = {
    "DATABASE_URL": "postgresql+asyncpg://u:p@h/d",
    "MUSIC_OUTPUT_DIR": "/data/media/music",
    "NAVIDROME_URL": "http://navidrome.example:4533",
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
    assert s.music_output_dir == REQUIRED_ENV["MUSIC_OUTPUT_DIR"]
    assert s.navidrome_url == REQUIRED_ENV["NAVIDROME_URL"]


@pytest.mark.parametrize("missing", list(REQUIRED_ENV))
def test_missing_required_raises(monkeypatch, missing):
    for k, v in REQUIRED_ENV.items():
        if k != missing:
            monkeypatch.setenv(k, v)
    with pytest.raises(ValidationError) as exc:
        Settings()
    assert missing.lower() in str(exc.value).lower()


def test_extra_env_vars_ignored(monkeypatch):
    for k, v in REQUIRED_ENV.items():
        monkeypatch.setenv(k, v)
    monkeypatch.setenv("SPOTIFY_CLIENT_ID", "leftover")
    monkeypatch.setenv("SPOTIFY_CLIENT_SECRET", "leftover")
    s = Settings()
    assert s.database_url == REQUIRED_ENV["DATABASE_URL"]


# ---- N13: NAVIDROME_URL must be a parseable http(s) URL --------------------


@pytest.mark.parametrize(
    "bad",
    [
        "",
        "not-a-url",
        "ftp://navidrome.example",
        "navidrome.example:4533",
        "http://",
    ],
)
def test_invalid_navidrome_url_raises(monkeypatch, bad):
    for k, v in REQUIRED_ENV.items():
        monkeypatch.setenv(k, v)
    monkeypatch.setenv("NAVIDROME_URL", bad)
    with pytest.raises(ValidationError) as exc:
        Settings()
    assert "navidrome_url" in str(exc.value).lower()
