import json
from typing import Tuple
from app.database import get_redis
from app.config import get_settings
from app.models.task import Task

settings = get_settings()


def get_cache_key(user_id: str) -> str:
    return f"tasks:user:{user_id}"


async def get_cached_tasks(user_id: str) -> Tuple[list[dict] | None, bool]:
    redis = get_redis()
    cache_key = get_cache_key(user_id)
    
    cached = await redis.get(cache_key)
    
    if cached:
        tasks = json.loads(cached)
        return tasks, True
    
    return None, False


async def set_cached_tasks(user_id: str, tasks: list[dict]) -> None:
    redis = get_redis()
    cache_key = get_cache_key(user_id)
    
    await redis.setex(
        cache_key,
        settings.cache_ttl,
        json.dumps(tasks, default=str)
    )


async def invalidate_cache(user_id: str) -> None:
    redis = get_redis()
    cache_key = get_cache_key(user_id)
    await redis.delete(cache_key)


async def get_tasks_with_cache(user_id: str) -> Tuple[list[dict], bool]:
    # once cachee bak
    cached_tasks, cache_hit = await get_cached_tasks(user_id)
    
    if cache_hit and cached_tasks is not None:
        return cached_tasks, True
    
    # cachede yoksa mongodan cek
    tasks = await Task.find(Task.user_id == user_id).to_list()
    
    tasks_data = [
        {
            "id": str(task.id),
            "user_id": task.user_id,
            "title": task.title,
            "description": task.description,
            "status": task.status.value,
            "created_at": task.created_at.isoformat(),
            "updated_at": task.updated_at.isoformat()
        }
        for task in tasks
    ]
    
    await set_cached_tasks(user_id, tasks_data)
    
    return tasks_data, False
