# app/modules/notification/routes.py - COMPLETE WORKING VERSION

from fastapi import APIRouter, BackgroundTasks, Depends, Query, Body, HTTPException, WebSocket, WebSocketDisconnect
from app.core.services.dependencies import get_current_user
from app.modules.notification.service import central_notification
from app.modules.notification.schema import NotificationResponse
from app.db.connection import get_db
import datetime
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


# ====================== TEST ENDPOINTS ======================

@router.post("/test/create")
async def create_test_notification(
    user=Depends(get_current_user),
    db=Depends(get_db)
):
    """Create a test notification for current user"""
    user_id = user.get("user_id")
    user_email = user.get("email")
    
    notification = {
        "user_id": user_id,
        "user_email": user_email,
        "type": "test_notification",
        "title": "🔔 Test Notification",
        "message": "This is a test notification to verify the bell icon is working!",
        "read": False,
        "created_at": datetime.datetime.utcnow(),
        "metadata": {"test": True}
    }
    
    result = await db.notifications.insert_one(notification)
    
    return {
        "success": True,
        "message": "Test notification created",
        "notification_id": str(result.inserted_id)
    }


@router.get("/debug/notifications")
async def debug_notifications(
    user=Depends(get_current_user),
    db=Depends(get_db)
):
    """Debug endpoint to see all notifications for user"""
    user_id = user.get("user_id")
    user_email = user.get("email")
    
    # Get all notifications
    notifications = await db.notifications.find({
        "$or": [
            {"user_id": user_id},
            {"user_email": user_email}
        ]
    }).sort("created_at", -1).to_list(50)
    
    total = len(notifications)
    unread_count = sum(1 for n in notifications if not n.get("read", False))
    
    for n in notifications:
        n["_id"] = str(n["_id"])
        if n.get("created_at"):
            n["created_at"] = n["created_at"].isoformat()
    
    return {
        "user_id": user_id,
        "user_email": user_email,
        "total_notifications": total,
        "unread_count": unread_count,
        "notifications": notifications[:20]
    }


# ====================== USER NOTIFICATION ENDPOINTS ======================

@router.get("/my-notifications")
async def get_my_notifications(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    unread_only: bool = Query(False),
    user=Depends(get_current_user),
    db=Depends(get_db)
):
    """Get user's notifications (Bell icon data)"""
    user_id = user.get("user_id")
    user_email = user.get("email")
    
    query = {
        "$or": [
            {"user_id": user_id},
            {"user_email": user_email}
        ]
    }
    
    if unread_only:
        query["read"] = False
    
    notifications = await db.notifications.find(query)\
        .sort("created_at", -1)\
        .skip(skip)\
        .limit(limit)\
        .to_list(limit)
    
    total = await db.notifications.count_documents(query)
    unread_count = await db.notifications.count_documents({
        "$or": [
            {"user_id": user_id},
            {"user_email": user_email}
        ],
        "read": False
    })
    
    for notif in notifications:
        notif["_id"] = str(notif["_id"])
        if notif.get("created_at"):
            notif["created_at"] = notif["created_at"].isoformat()
    
    return {
        "success": True,
        "notifications": notifications,
        "total": total,
        "unread_count": unread_count,
        "skip": skip,
        "limit": limit
    }


@router.get("/unread-count")
async def get_unread_count_endpoint(
    user=Depends(get_current_user),
    db=Depends(get_db)
):
    """Get unread notification count for bell badge"""
    user_id = user.get("user_id")
    user_email = user.get("email")
    
    count = await db.notifications.count_documents({
        "$or": [
            {"user_id": user_id},
            {"user_email": user_email}
        ],
        "read": False
    })
    
    logger.info(f"🔔 Unread count for user {user_email}: {count}")
    
    return {
        "success": True,
        "unread_count": count
    }


@router.post("/mark-read/{notification_id}")
async def mark_notification_read_endpoint(
    notification_id: str,
    user=Depends(get_current_user),
    db=Depends(get_db)
):
    """Mark a single notification as read"""
    from bson import ObjectId
    
    user_id = user.get("user_id")
    user_email = user.get("email")
    
    if not ObjectId.is_valid(notification_id):
        raise HTTPException(status_code=400, detail="Invalid notification ID")
    
    result = await db.notifications.update_one(
        {
            "_id": ObjectId(notification_id),
            "$or": [
                {"user_id": user_id},
                {"user_email": user_email}
            ]
        },
        {"$set": {"read": True, "read_at": datetime.datetime.utcnow()}}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="Notification not found")
    
    return {"success": True, "message": "Notification marked as read"}


@router.post("/mark-all-read")
async def mark_all_notifications_read(
    user=Depends(get_current_user),
    db=Depends(get_db)
):
    """Mark all notifications as read"""
    user_id = user.get("user_id")
    user_email = user.get("email")
    
    result = await db.notifications.update_many(
        {
            "$or": [
                {"user_id": user_id},
                {"user_email": user_email}
            ],
            "read": False
        },
        {"$set": {"read": True, "read_at": datetime.datetime.utcnow()}}
    )
    
    return {"success": True, "message": f"Marked {result.modified_count} notifications as read"}


@router.post("/admin/broadcast")
async def broadcast_to_all_users(
    title: str = Body(...),
    message: str = Body(...),
    user=Depends(get_current_user),
    db=Depends(get_db)
):
    """Admin broadcast notification to all users"""
    user_role = user.get("role", "").lower()
    if user_role not in ["admin", "superadmin", "customadmin"]:
        raise HTTPException(status_code=403, detail="Admin access required")
    
    # Get all active users
    users = await db.auth.find({"is_active": True}).to_list(length=10000)
    
    notifications = []
    for u in users:
        notifications.append({
            "user_id": str(u["_id"]),
            "user_email": u.get("email"),
            "type": "admin_broadcast",
            "title": f"📢 {title}",
            "message": message,
            "read": False,
            "created_at": datetime.datetime.utcnow(),
            "metadata": {"broadcast_by": user.get("email")}
        })
    
    if notifications:
        await db.notifications.insert_many(notifications)
    
    return {"success": True, "message": f"Broadcast sent to {len(notifications)} users"}


print("✅ Notification Routes Loaded")