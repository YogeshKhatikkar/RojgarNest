# app/modules/chat/websocket.py
"""
Real-time Chat between Recruiters and Candidates
"""

from fastapi import WebSocket, WebSocketDisconnect, Depends, Query, APIRouter, HTTPException
from typing import Dict, List
import json
from datetime import datetime
from jose import jwt

from app.core.services.dependencies import get_current_user
from app.core.utils.config import settings
from app.db.connection import get_db
from app.core.utils.logger import logger

router = APIRouter(prefix="/chat", tags=["Chat"])


class ConnectionManager:
    """WebSocket connection manager"""
    
    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {}
        self.private_connections: Dict[str, WebSocket] = {}
    
    async def connect(self, websocket: WebSocket, user_id: str, user_role: str):
        await websocket.accept()
        
        if user_role == "candidate":
            if user_id not in self.active_connections:
                self.active_connections[user_id] = []
            self.active_connections[user_id].append(websocket)
            logger.info(f"Candidate {user_id} connected")
        else:
            self.private_connections[user_id] = websocket
            logger.info(f"Recruiter {user_id} connected")
    
    def disconnect(self, user_id: str, websocket: WebSocket, user_role: str):
        if user_role == "candidate":
            if user_id in self.active_connections:
                if websocket in self.active_connections[user_id]:
                    self.active_connections[user_id].remove(websocket)
                if not self.active_connections[user_id]:
                    del self.active_connections[user_id]
        else:
            self.private_connections.pop(user_id, None)
        logger.info(f"User {user_id} disconnected")
    
    async def send_personal_message(self, message: dict, user_id: str):
        if user_id in self.private_connections:
            try:
                await self.private_connections[user_id].send_json(message)
                return True
            except:
                pass
        return False
    
    async def broadcast_to_candidate(self, message: dict, candidate_id: str):
        if candidate_id in self.active_connections:
            for connection in self.active_connections[candidate_id]:
                try:
                    await connection.send_json(message)
                except:
                    pass
            return True
        return False


manager = ConnectionManager()


@router.websocket("/ws/{receiver_id}")
async def websocket_chat(
    websocket: WebSocket,
    receiver_id: str,
    token: str = Query(...),
):
    """WebSocket endpoint for real-time chat"""
    
    db = get_db()
    
    # Verify user from token
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=["HS256"])
        user_id = payload.get("user_id")
        user_role = payload.get("role", "candidate")
        
        if not user_id:
            await websocket.close(code=1008, reason="Invalid token")
            return
    except Exception as e:
        await websocket.close(code=1008, reason=f"Authentication failed: {str(e)}")
        return
    
    await manager.connect(websocket, user_id, user_role)
    
    try:
        while True:
            data = await websocket.receive_text()
            message_data = json.loads(data)
            
            # Store message in database
            message_doc = {
                "from_user": user_id,
                "to_user": receiver_id,
                "from_role": user_role,
                "message": message_data.get("message", ""),
                "message_type": message_data.get("type", "text"),
                "timestamp": datetime.utcnow(),
                "read": False
            }
            await db.chat_messages.insert_one(message_doc)
            
            # Send to receiver
            message_to_send = {
                "from": user_id,
                "from_role": user_role,
                "message": message_data.get("message"),
                "type": message_data.get("type", "text"),
                "timestamp": datetime.utcnow().isoformat()
            }
            
            # Try to send to receiver
            sent = await manager.send_personal_message(message_to_send, receiver_id)
            
            # If receiver is candidate, also try broadcast
            if not sent:
                await manager.broadcast_to_candidate(message_to_send, receiver_id)
            
    except WebSocketDisconnect:
        manager.disconnect(user_id, websocket, user_role)
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        manager.disconnect(user_id, websocket, user_role)


@router.get("/messages/{other_user_id}")
async def get_messages(
    other_user_id: str,
    limit: int = Query(50, ge=1, le=200),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Get chat history with another user"""
    
    user_id = current_user.get("user_id")
    
    messages = await db.chat_messages.find({
        "$or": [
            {"from_user": user_id, "to_user": other_user_id},
            {"from_user": other_user_id, "to_user": user_id}
        ]
    }).sort("timestamp", -1).limit(limit).to_list(limit)
    
    # Mark messages as read
    await db.chat_messages.update_many(
        {"to_user": user_id, "from_user": other_user_id, "read": False},
        {"$set": {"read": True}}
    )
    
    # Convert to list and reverse for chronological order
    messages_list = []
    for msg in reversed(messages):
        messages_list.append({
            "id": str(msg["_id"]),
            "from_user": msg["from_user"],
            "to_user": msg["to_user"],
            "message": msg["message"],
            "timestamp": msg["timestamp"].isoformat(),
            "read": msg.get("read", False)
        })
    
    return {
        "success": True,
        "messages": messages_list,
        "total": len(messages_list)
    }


@router.get("/unread-count")
async def get_unread_count(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Get unread message count"""
    
    user_id = current_user.get("user_id")
    
    count = await db.chat_messages.count_documents({
        "to_user": user_id,
        "read": False
    })
    
    return {
        "success": True,
        "unread_count": count
    }


print("✅ Chat module loaded")