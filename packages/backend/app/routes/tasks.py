from fastapi import APIRouter, Depends, HTTPException, status, Response
from datetime import datetime
from bson import ObjectId

from app.models.user import User
from app.models.task import Task, TaskStatus
from app.schemas import (
    TaskCreate,
    TaskUpdate,
    TaskResponse,
    TaskListResponse
)
from app.services.auth_service import get_current_user
from app.services.cache_service import get_tasks_with_cache, invalidate_cache
from app.services.websocket_service import (
    emit_task_created,
    emit_task_updated,
    emit_task_deleted
)

router = APIRouter(prefix="/tasks", tags=["Tasks"])


@router.get("", response_model=TaskListResponse)
async def get_tasks(
    response: Response,
    current_user: User = Depends(get_current_user)
):
    user_id = str(current_user.id)
    
    tasks, cache_hit = await get_tasks_with_cache(user_id)
    
    response.headers["X-Cache"] = "HIT" if cache_hit else "MISS"
    
    return TaskListResponse(
        tasks=[TaskResponse(**task) for task in tasks],
        count=len(tasks)
    )


@router.post("", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
async def create_task(
    data: TaskCreate,
    current_user: User = Depends(get_current_user)
):
    user_id = str(current_user.id)
    
    task = Task(
        user_id=user_id,
        title=data.title,
        description=data.description,
        status=TaskStatus(data.status)
    )
    
    await task.insert()
    
    await invalidate_cache(user_id)
    await emit_task_created(user_id, str(task.id))
    
    return TaskResponse(
        id=str(task.id),
        user_id=task.user_id,
        title=task.title,
        description=task.description,
        status=task.status.value,
        created_at=task.created_at,
        updated_at=task.updated_at
    )


@router.patch("/{task_id}", response_model=TaskResponse)
async def update_task(
    task_id: str,
    data: TaskUpdate,
    current_user: User = Depends(get_current_user)
):
    user_id = str(current_user.id)
    
    try:
        object_id = ObjectId(task_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid task ID format"
        )
    
    task = await Task.get(object_id)
    
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found"
        )
    
    # baska birinin taskini update etmeye calisiyosa
    if task.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to update this task"
        )
    
    update_data = data.model_dump(exclude_unset=True)
    
    if "status" in update_data:
        update_data["status"] = TaskStatus(update_data["status"])
    
    update_data["updated_at"] = datetime.utcnow()
    
    for key, value in update_data.items():
        setattr(task, key, value)
    
    await task.save()
    
    await invalidate_cache(user_id)
    await emit_task_updated(user_id, str(task.id))
    
    return TaskResponse(
        id=str(task.id),
        user_id=task.user_id,
        title=task.title,
        description=task.description,
        status=task.status.value,
        created_at=task.created_at,
        updated_at=task.updated_at
    )


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_task(
    task_id: str,
    current_user: User = Depends(get_current_user)
):
    user_id = str(current_user.id)
    
    try:
        object_id = ObjectId(task_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid task ID format"
        )
    
    task = await Task.get(object_id)
    
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found"
        )
    
    if task.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to delete this task"
        )
    
    await task.delete()
    
    await invalidate_cache(user_id)
    await emit_task_deleted(user_id, task_id)
    
    return None
