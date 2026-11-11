# app/modules/notification/AI/ai_routes.py
from fastapi import APIRouter, Depends, Query
from datetime import datetime, timedelta
import logging

from app.core.services.dependencies import get_current_user
from app.db.connection import get_db

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["Notification AI Services"])


@router.get("/smart-notifications")
async def smart_notifications(
    limit: int = Query(20, ge=1, le=100),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """AI-powered smart notification prioritization"""
    user_id = current_user.get("user_id")
    
    if not user_id:
        return {"notifications": [], "priority_score": 0}
    
    notifications = await db.notifications.find(
        {"user_id": user_id}
    ).sort("created_at", -1).limit(limit).to_list(limit)
    
    for notif in notifications:
        priority = 50
        
        if not notif.get("read", False):
            priority += 30
        
        if notif.get("type") == "application_update":
            priority += 20
        
        created_at = notif.get("created_at")
        if created_at:
            hours_ago = (datetime.utcnow() - created_at).total_seconds() / 3600
            if hours_ago < 24:
                priority += 20
            elif hours_ago < 72:
                priority += 10
        
        notif["priority_score"] = min(100, priority)
        notif["_id"] = str(notif["_id"])
    
    notifications.sort(key=lambda x: x.get("priority_score", 0), reverse=True)
    
    return {
        "notifications": notifications[:limit],
        "total": len(notifications),
        "ai_prioritized": True
    }


@router.get("/insights")
async def notification_insights(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """AI insights about user notification behavior"""
    user_id = current_user.get("user_id")
    
    if not user_id:
        return {"error": "User not found"}
    
    last_30_days = datetime.utcnow() - timedelta(days=30)
    notifications = await db.notifications.find({
        "user_id": user_id,
        "created_at": {"$gte": last_30_days}
    }).to_list(1000)
    
    total = len(notifications)
    read_count = sum(1 for n in notifications if n.get("read", False))
    unread_count = total - read_count
    
    engagement_rate = (read_count / total * 100) if total > 0 else 0
    
    type_counts = {}
    for notif in notifications:
        notif_type = notif.get("type", "unknown")
        type_counts[notif_type] = type_counts.get(notif_type, 0) + 1
    
    return {
        "total_notifications_30d": total,
        "read_count": read_count,
        "unread_count": unread_count,
        "engagement_rate": round(engagement_rate, 1),
        "notification_breakdown": type_counts,
        "suggestion": "You have unread notifications" if unread_count > 0 else "Great! You're up to date"
    }


print("✅ Notification AI Routes Loaded")