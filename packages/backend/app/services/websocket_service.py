import socketio
from typing import Optional
from app.services.auth_service import decode_access_token

sio = socketio.AsyncServer(
    async_mode="asgi",
    cors_allowed_origins="*"
)

# hangi user hangi socketlere bagli
user_connections: dict[str, set[str]] = {}


@sio.event
async def connect(sid: str, environ: dict, auth: Optional[dict] = None):
    token = None
    
    if auth and "token" in auth:
        token = auth["token"]
    else:
        # query stringden almaya calis
        query_string = environ.get("QUERY_STRING", "")
        params = dict(param.split("=") for param in query_string.split("&") if "=" in param)
        token = params.get("token")
    
    if not token:
        print(f"[WS] No token: {sid}")
        return False
    
    payload = decode_access_token(token)
    if not payload:
        print(f"[WS] Invalid token: {sid}")
        return False
    
    user_id = payload.get("sub")
    if not user_id:
        print(f"[WS] No user_id: {sid}")
        return False
    
    if user_id not in user_connections:
        user_connections[user_id] = set()
    user_connections[user_id].add(sid)
    
    await sio.enter_room(sid, f"user:{user_id}")
    
    async with sio.session(sid) as session:
        session["user_id"] = user_id
    
    print(f"[WS] Connected: {user_id}")
    return True


@sio.event
async def disconnect(sid: str):
    async with sio.session(sid) as session:
        user_id = session.get("user_id")
    
    if user_id and user_id in user_connections:
        user_connections[user_id].discard(sid)
        if not user_connections[user_id]:
            del user_connections[user_id]
    
    print(f"[WS] Disconnected: {sid}")


async def emit_task_event(user_id: str, event_type: str, task_id: str):
    import time
    
    event_data = {
        "type": event_type,
        "taskId": task_id,
        "timestamp": int(time.time())
    }
    
    room = f"user:{user_id}"
    await sio.emit("task:update", event_data, room=room)


async def emit_task_created(user_id: str, task_id: str):
    await emit_task_event(user_id, "task.created", task_id)


async def emit_task_updated(user_id: str, task_id: str):
    await emit_task_event(user_id, "task.updated", task_id)


async def emit_task_deleted(user_id: str, task_id: str):
    await emit_task_event(user_id, "task.deleted", task_id)
