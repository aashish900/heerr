from functools import lru_cache
from urllib.parse import urlparse

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(extra="ignore")

    database_url: str
    music_output_dir: str
    navidrome_url: str

    @field_validator("navidrome_url")
    @classmethod
    def _validate_navidrome_url(cls, v: str) -> str:
        parsed = urlparse(v)
        if parsed.scheme not in ("http", "https") or not parsed.netloc:
            raise ValueError(f"navidrome_url must be a parseable http(s) URL, got {v!r}")
        return v


@lru_cache
def get_settings() -> Settings:
    return Settings()
