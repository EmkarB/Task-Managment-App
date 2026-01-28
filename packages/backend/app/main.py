from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import socketio

from app.database import (
    init_postgres,
    init_mongodb,
    init_redis,
    close_mongodb,
    close_redis,
    check_postgres,
    check_mongodb,
    check_redis
)
from app.routes.auth import router as auth_router
from app.routes.tasks import router as tasks_router
from app.services.websocket_service import sio
from app.schemas import HealthResponse


@asynccontextmanager
async def lifespan(app: FastAPI):
    print("Starting up...")
    
    await init_postgres()
    await init_mongodb()
    await init_redis()
    
    print("All services ready")
    
    yield
    
    print("Shutting down...")
    await close_mongodb()
    await close_redis()


app = FastAPI(
    title="Task Management API",
    description="Task management with real-time updates",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(tasks_router)


@app.get("/health", response_model=HealthResponse, tags=["Health"])
async def health_check():
    postgres_status = await check_postgres()
    mongodb_status = await check_mongodb()
    redis_status = await check_redis()
    
    all_healthy = all(
        status == "connected" 
        for status in [postgres_status, mongodb_status, redis_status]
    )
    
    return HealthResponse(
        status="healthy" if all_healthy else "unhealthy",
        postgres=postgres_status,
        mongodb=mongodb_status,
        redis=redis_status
    )


socket_app = socketio.ASGIApp(sio, other_asgi_app=app)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:socket_app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
