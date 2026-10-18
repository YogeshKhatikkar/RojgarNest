# app/core/services/mobile_api.py
"""
Optimized API for Mobile Apps (Reduced payload, faster response)
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional
from datetime import datetime, timedelta
from bson import ObjectId  # ✅ Add this import

from app.core.services.dependencies import get_current_user
from app.db.connection import get_db
from app.core.utils.logger import logger

router = APIRouter(prefix="/mobile", tags=["Mobile API"])


@router.get("/feed")
async def get_mobile_feed(
    last_sync: Optional[str] = None,
    limit: int = Query(20, ge=1, le=50),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Optimized mobile feed - lightweight response"""
    
    email = current_user.get("email")
    
    # Get only what changed since last sync
    sync_time = datetime.fromisoformat(last_sync) if last_sync else datetime.utcnow() - timedelta(days=7)
    
    # Fetch in parallel using asyncio.gather
    import asyncio
    profile, new_jobs, app_updates, notifications = await asyncio.gather(
        db.profile.find_one({"email": email}),
        db.job.find({"created_at": {"$gt": sync_time}, "status": "open"})
            .sort("created_at", -1).limit(limit).to_list(limit),
        db.applications.find({"applicant_email": email, "updated_at": {"$gt": sync_time}})
            .sort("updated_at", -1).limit(10).to_list(10),
        db.notifications.find({"user_email": email, "created_at": {"$gt": sync_time}})
            .sort("created_at", -1).limit(20).to_list(20)
    )
    
    # Prepare minimal response (smaller payload for mobile)
    return {
        "success": True,
        "profile_summary": {
            "name": profile.get("full_name") if profile else None,
            "profile_completion": profile.get("profile_completion_percentage", 0) if profile else 0
        },
        "new_jobs": [
            {
                "id": str(j["_id"]),
                "title": j.get("post_name", ""),
                "company": j.get("organization", ""),
                "location": j.get("location", ""),
                "posted": j.get("post_date", "")
            }
            for j in new_jobs
        ],
        "updates": [
            {
                "type": "application",
                "job_id": str(a.get("job_id", "")),
                "status": a.get("status", ""),
                "updated": a["updated_at"].isoformat() if a.get("updated_at") else None
            }
            for a in app_updates
        ],
        "notifications": [
            {
                "id": str(n["_id"]),
                "title": n.get("title", ""),
                "message": n.get("message", ""),
                "read": n.get("read", False),
                "time": n["created_at"].isoformat() if n.get("created_at") else None
            }
            for n in notifications
        ],
        "sync_token": datetime.utcnow().isoformat()
    }


@router.get("/offline-data")
async def get_offline_data(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Data bundle for offline mode"""
    
    email = current_user.get("email")
    
    # Get essential data for offline use
    profile = await db.profile.find_one({"email": email})
    
    # Get saved jobs
    user = await db.auth.find_one({"email": email})
    saved_job_ids = user.get("saved_jobs", []) if user else []
    
    saved_jobs_data = []
    for job_id in saved_job_ids[:50]:  # Limit for offline
        if ObjectId.is_valid(job_id):
            job = await db.job.find_one({"_id": ObjectId(job_id)})
            if job:
                saved_jobs_data.append({
                    "id": str(job["_id"]),
                    "title": job.get("post_name", ""),
                    "company": job.get("organization", ""),
                    "location": job.get("location", "")
                })
    
    return {
        "success": True,
        "profile": {
            "name": profile.get("full_name") if profile else None,
            "skills": [s.get("name") for s in profile.get("skills", [])[:20]] if profile else [],
            "education": [
                {
                    "degree": e.get("degree"),
                    "institute": e.get("institute"),
                    "year": e.get("year_of_passing")
                }
                for e in profile.get("academic_records", [])[:5] if profile
            ] if profile else []
        },
        "saved_jobs": saved_jobs_data,
        "app_version": "5.0.0",
        "offline_capable": True
    }


print("✅ Mobile API routes loaded")