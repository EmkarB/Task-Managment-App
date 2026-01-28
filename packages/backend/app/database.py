from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from motor.motor_asyncio import AsyncIOMotorClient
from beanie import init_beanie
import redis.asyncio as redis
from typing import AsyncGenerator

from app.config import get_settings

settings = get_settings()


class Base(DeclarativeBase):
    pass


# postgres
engine = create_async_engine(
    settings.postgres_url,
    echo=False,
    pool_pre_ping=True,
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_postgres_session() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()


async def init_postgres():
    from app.models.user import User  # noqa
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


# mongodb
mongodb_client: AsyncIOMotorClient = None


async def init_mongodb():
    global mongodb_client
    from app.models.task import Task  # noqa
    
    mongodb_client = AsyncIOMotorClient(settings.mongodb_uri)
    database = mongodb_client.get_default_database()
    
    await init_beanie(
        database=database,
        document_models=[Task]
    )


async def close_mongodb():
    global mongodb_client
    if mongodb_client:
        mongodb_client.close()


# redis
redis_client: redis.Redis = None


async def init_redis():
    global redis_client
    redis_client = redis.Redis(
        host=settings.redis_host,
        port=settings.redis_port,
        decode_responses=True
    )
    await redis_client.ping()


async def close_redis():
    global redis_client
    if redis_client:
        await redis_client.close()


def get_redis() -> redis.Redis:
    return redis_client


# health checks
async def check_postgres() -> str:
    try:
        from sqlalchemy import text
        async with AsyncSessionLocal() as session:
            await session.execute(text("SELECT 1"))
        return "connected"
    except Exception:
        return "disconnected"


async def check_mongodb() -> str:
    try:
        if mongodb_client:
            await mongodb_client.admin.command("ping")
            return "connected"
        return "disconnected"
    except Exception:
        return "disconnected"


async def check_redis() -> str:
    try:
        if redis_client:
            await redis_client.ping()
            return "connected"
        return "disconnected"
    except Exception:
        return "disconnected"
