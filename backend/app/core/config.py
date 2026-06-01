from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    xtream_base_url: str = ""
    xtream_username: str = ""
    xtream_password: str = ""
    database_url: str = "./data/cloudstream.db"
    port: int = 8000
    cors_origins: str = "*"
    debug: bool = False

    class Config:
        env_prefix = ""
        extra = "ignore"


@lru_cache
def get_settings() -> Settings:
    return Settings()
