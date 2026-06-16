from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(extra="ignore")

    database_url: str
    music_output_dir: str
    navidrome_url: str


@lru_cache
def get_settings() -> Settings:
    return Settings()
