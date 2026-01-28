import os
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # db ayarlari
    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_db: str = "taskdb"
    postgres_user: str = "taskuser"
    postgres_password: str = "taskpass"

    mongodb_uri: str = "mongodb://localhost:27017/taskdb"

    redis_host: str = "localhost"
    redis_port: int = 6379

    # jwt
    jwt_secret: str = "super-secret-jwt-key-change-in-production"
    jwt_expires_in: str = "7d"
    jwt_algorithm: str = "HS256"

    cache_ttl: int = 300  # 5 dk

    @property
    def postgres_url(self) -> str:
        return f"postgresql+asyncpg://{self.postgres_user}:{self.postgres_password}@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"

    @property
    def postgres_url_sync(self) -> str:
        return f"postgresql://{self.postgres_user}:{self.postgres_password}@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"

    class Config:
        env_file = ".env"
        case_sensitive = False


@lru_cache()
def get_settings() -> Settings:
    return Settings()
