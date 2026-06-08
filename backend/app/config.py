from functools import lru_cache

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(extra="ignore")

    database_url: str
    spotify_client_id: str
    spotify_client_secret: SecretStr
    music_output_dir: str


@lru_cache
def get_settings() -> Settings:
    return Settings()
