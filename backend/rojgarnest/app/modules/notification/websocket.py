# app/modules/notification/websocket.py - COMPLETE FIXED VERSION

import asyncio
import json
from fastapi import WebSocket, WebSocketDisconnect, Query
from jose import jwt, JWTError
import logging
from datetime import datetime
from bson import ObjectId

from app.core.config.settings import settings
from app.db.connection import get_db

logger = logging.getLogger(__name__)


class ConnectionManager:
    def __init__(self):
        self.user_connections: dict = {}
        self.role_connections: dict = {}
        self.all_connections: list = []
        self.welcome_sent: set = set()

    async def connect(self, websocket: WebSocket, user_id: str, user_role: str, user_email: str):
        try:
            await websocket.accept()
        except Exception as e:
            logger.error(f"Failed to accept websocket: {e}")
            return False

        websocket._pong_wait = 30
        
        self.user_connections[user_id] = websocket
        
        # Normalize role for storage
        if user_role == "custom_admin":
            user_role = "customadmin"
        
        if user_role not in self.role_connections:
            self.role_connections[user_role] = []
        if user_id not in self.role_connections[user_role]:
            self.role_connections[user_role].append(user_id)
        
        self.all_connections.append(websocket)
        
        is_first_time_ever = user_id not in self.welcome_sent
        
        logger.info(f"🔌 WebSocket connected: user_id={user_id}, role={user_role}, email={user_email}, first_time_ever={is_first_time_ever}")
        
        return is_first_time_ever

    def mark_welcome_sent(self, user_id: str):
        self.welcome_sent.add(user_id)

    def disconnect(self, user_id: str, user_role: str):
        self.user_connections.pop(user_id, None)
        
        if user_role in self.role_connections:
            if user_id in self.role_connections[user_role]:
                self.role_connections[user_role].remove(user_id)
        
        logger.info(f"🔌 WebSocket disconnected: user_id={user_id}")

    async def send_to_user(self, message: dict, user_id: str):
        if user_id in self.user_connections:
            try:
                await self.user_connections[user_id].send_json(message)
                logger.debug(f"📨 Sent to user {user_id}: {message.get('type')}")
                return True
            except Exception as e:
                logger.error(f"Failed to send to {user_id}: {e}")
        return False

    async def send_to_role(self, message: dict, role: str):
        # Normalize role
        role = role.lower()
        if role == "custom_admin":
            role = "customadmin"
            
        if role in self.role_connections:
            sent_count = 0
            for user_id in self.role_connections[role]:
                if await self.send_to_user(message, user_id):
                    sent_count += 1
            logger.info(f"📢 Sent to {sent_count} users with role {role}")
            return sent_count
        return 0

    async def send_to_admins(self, message: dict):
        sent_count = 0
        for role in ['admin', 'superadmin', 'customadmin']:
            sent_count += await self.send_to_role(message, role)
        return sent_count

    async def broadcast_to_all(self, message: dict):
        sent_count = 0
        for websocket in self.all_connections[:]:
            try:
                await websocket.send_json(message)
                sent_count += 1
            except Exception as e:
                logger.error(f"Broadcast failed: {e}")
                self.all_connections.remove(websocket)
        logger.info(f"📢 Broadcast to {sent_count} users")
        return sent_count


manager = ConnectionManager()


async def broadcast_notification(notification: dict):
    """Broadcast notification to specific user, role, or all"""
    user_id = notification.get("user_id")
    target_role = notification.get("target_role")
    
    # Don't broadcast if no target
    if not user_id and not target_role:
        return
    
    if user_id and user_id != "all":
        await manager.send_to_user(notification, user_id)
    elif target_role:
        await manager.send_to_role(notification, target_role)
    else:
        await manager.broadcast_to_all(notification)


async def verify_websocket_token(token: str):
    """Verify WebSocket token with better error handling"""
    try:
        if not token:
            logger.error("WebSocket token is empty")
            return None, None, None
        
        # Try to decode the token
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=["HS256"],
            options={"verify_exp": True}
        )
        
        user_id = payload.get("user_id")
        user_role = payload.get("role", "user")
        user_email = payload.get("email", "")
        
        # Normalize role
        if user_role == "custom_admin":
            user_role = "customadmin"
        
        if not user_id:
            logger.error("WebSocket token missing user_id")
            return None, None, None
        
        # Verify user exists in database
        db = get_db()
        
        # Try to find user by ObjectId or email
        user = None
        if ObjectId.is_valid(user_id):
            user = await db.auth.find_one({"_id": ObjectId(user_id)})
        else:
            user = await db.auth.find_one({"email": user_email})
        
        if not user:
            logger.error(f"WebSocket token user not found: {user_id}")
            return None, None, None
        
        if not user.get("is_active", True):
            logger.error(f"WebSocket token user inactive: {user_id}")
            return None, None, None
        
        # Get correct role from database
        db_role = user.get("role", "user")
        if db_role == "custom_admin":
            db_role = "customadmin"
        
        logger.info(f"✅ WebSocket token verified for user: {user_email} (role: {db_role})")
        return str(user["_id"]), db_role, user_email
        
    except jwt.ExpiredSignatureError:
        logger.error("WebSocket token expired")
        return None, None, None
    except jwt.JWTError as e:
        logger.error(f"WebSocket token verification failed: {e}")
        return None, None, None
    except Exception as e:
        logger.error(f"WebSocket token error: {e}")
        return None, None, None


async def websocket_endpoint(websocket: WebSocket, token: str = Query(...)):
    """WebSocket endpoint with improved token handling"""
    
    user_id, user_role, user_email = await verify_websocket_token(token)
    
    if not user_id:
        await websocket.close(code=1008, reason="Invalid authentication token")
        return
    
    is_first_time_ever = await manager.connect(websocket, user_id, user_role, user_email)
    
    if is_first_time_ever:
        await websocket.send_json({
            "type": "connected",
            "message": "Connected to RojgarNest notification service",
            "user_id": user_id,
            "user_role": user_role,
            "timestamp": datetime.utcnow().timestamp()
        })
        manager.mark_welcome_sent(user_id)
        logger.info(f"📨 Welcome message sent to user {user_id} (FIRST TIME ONLY)")
    else:
        await websocket.send_json({
            "type": "reconnected",
            "user_id": user_id,
            "user_role": user_role,
            "timestamp": datetime.utcnow().timestamp()
        })
        logger.info(f"🔄 Silent reconnect for user {user_id} (NO welcome message)")
    
    # Keepalive settings
    last_pong_time = datetime.utcnow().timestamp()
    ping_interval = 25
    pong_timeout = 45
    
    try:
        while True:
            try:
                data = await asyncio.wait_for(websocket.receive_text(), timeout=ping_interval + 15)
                
                if data == "ping":
                    await websocket.send_json({"type": "pong"})
                    last_pong_time = datetime.utcnow().timestamp()
                    
                elif data == "pong":
                    last_pong_time = datetime.utcnow().timestamp()
                    
                elif data.startswith("{"):
                    try:
                        msg_data = json.loads(data)
                        if msg_data.get("type") == "ping":
                            await websocket.send_json({"type": "pong"})
                            last_pong_time = datetime.utcnow().timestamp()
                        elif msg_data.get("type") == "get_unread":
                            from .service import central_notification
                            unread = await central_notification.get_unread_count(user_id)
                            await websocket.send_json({"type": "unread_count", "count": unread})
                    except:
                        pass
                        
            except asyncio.TimeoutError:
                current_time = datetime.utcnow().timestamp()
                time_since_last_pong = current_time - last_pong_time
                
                if time_since_last_pong > pong_timeout:
                    logger.warning(f"WebSocket keepalive timeout for user {user_id}, closing")
                    break
                    
                try:
                    await websocket.send_json({"type": "ping"})
                except:
                    break
                
    except WebSocketDisconnect:
        manager.disconnect(user_id, user_role)
    except Exception as e:
        logger.error(f"WebSocket error for {user_id}: {e}")
        manager.disconnect(user_id, user_role)


print("✅ WebSocket Manager Loaded - Fixed token verification")