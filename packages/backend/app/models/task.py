from beanie import Document
from pydantic import Field
from datetime import datetime
from typing import Literal
from enum import Enum


class TaskStatus(str, Enum):
    TODO = "todo"
    IN_PROGRESS = "in_progress"
    DONE = "done"


class Task(Document):
    user_id: str = Field(..., description="User ID from PostgreSQL")
    title: str = Field(..., min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=1000)
    status: TaskStatus = Field(default=TaskStatus.TODO)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "tasks"
        use_state_management = True

    class Config:
        json_schema_extra = {
            "example": {
                "user_id": "550e8400-e29b-41d4-a716-446655440000",
                "title": "Complete project",
                "description": "Finish the task management app",
                "status": "todo"
            }
        }
