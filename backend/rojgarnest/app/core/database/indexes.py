# app/db/indexes.py - FIXED VERSION

from typing import Dict, Any, List
from datetime import datetime
from app.db.connection import get_db
import logging

logger = logging.getLogger(__name__)


async def create_index_safely(collection, keys, **kwargs):
    """Create index safely - ignore if already exists or duplicate key errors"""
    try:
        await collection.create_index(keys, **kwargs)
        return True
    except Exception as e:
        error_msg = str(e)
        if "already exists" in error_msg or "IndexKeySpecsConflict" in error_msg or "IndexOptionsConflict" in error_msg:
            logger.debug(f"Index already exists: {keys}")
            return False
        elif "DuplicateKey" in error_msg or "E11000" in error_msg:
            logger.warning(f"⚠️ Duplicate key found - skipping index: {keys}")
            logger.warning(f"   Error: {error_msg[:200]}")
            return False
        else:
            logger.warning(f"Index creation warning: {e}")
            return False


async def setup_all_indexes() -> Dict[str, Any]:
    """Create all indexes with safe error handling"""
    db = get_db()
    
    logger.info("=" * 60)
    logger.info("📊 Setting up indexes (unified collections)")
    logger.info("=" * 60)
    
    indexes_created = []
    
    # Auth indexes
    await create_index_safely(db.auth, "email", unique=True)
    await create_index_safely(db.auth, "mobile", unique=True, sparse=True)
    await create_index_safely(db.auth, "created_at")
    await create_index_safely(db.auth, "role")
    await create_index_safely(db.auth, "is_active")
    await create_index_safely(db.auth, "failed_attempts")
    await create_index_safely(db.auth, "lock_until")
    await create_index_safely(db.auth, "email_otp_expiry", expireAfterSeconds=0, sparse=True)
    await create_index_safely(db.auth, "mobile_otp_expiry", expireAfterSeconds=0, sparse=True)
    indexes_created.append("auth")
    
    # ================= UNIFIED SESSIONS =================
    await create_index_safely(db.sessions, "user_id")
    await create_index_safely(db.sessions, "session_hash", unique=True, sparse=True)
    await create_index_safely(db.sessions, "created_at", expireAfterSeconds=604800)
    await create_index_safely(db.sessions, "ip")
    await create_index_safely(db.sessions, "device")
    await create_index_safely(db.sessions, "expires_at", expireAfterSeconds=0)
    await create_index_safely(db.sessions, [("user_id", 1), ("is_active", 1)])
    await create_index_safely(db.sessions, [("user_id", 1), ("is_archived", 1)])
    indexes_created.append("sessions")
    
    # Profile
    await create_index_safely(db.profile, "email", unique=True)
    await create_index_safely(db.profile, "created_at")
    await create_index_safely(db.profile, "updated_at")
    await create_index_safely(db.profile, "category")
    await create_index_safely(db.profile, "disability.is_disabled")
    await create_index_safely(db.profile, "disability.category")
    await create_index_safely(db.profile, [("skills.name", 1)])
    indexes_created.append("profile")
    
    # Jobs
    await create_index_safely(db.job, "status")
    await create_index_safely(db.job, "created_at")
    await create_index_safely(db.job, [("post_date", -1)])
    await create_index_safely(db.job, "organization")
    await create_index_safely(db.job, "job_type")
    await create_index_safely(db.job, "category")
    indexes_created.append("jobs")
    
    # Applications
    await create_index_safely(db.applications, "job_id")
    await create_index_safely(db.applications, "applicant_email")
    await create_index_safely(db.applications, "status")
    await create_index_safely(db.applications, "match_score")
    await create_index_safely(db.applications, "applied_at")
    await create_index_safely(db.applications, "created_at")
    indexes_created.append("applications")
    
    # Notifications
    await create_index_safely(db.notifications, "user_id")
    await create_index_safely(db.notifications, "created_at")
    await create_index_safely(db.notifications, "created_at", expireAfterSeconds=2592000)
    await create_index_safely(db.notifications, [("user_id", 1), ("read", 1)])
    indexes_created.append("notifications")
    
    # ================= UNIFIED SECURITY =================
    await create_index_safely(db.security, "type")
    await create_index_safely(db.security, "ip_address")
    await create_index_safely(db.security, "created_at")
    await create_index_safely(db.security, "expires_at", expireAfterSeconds=0)
    await create_index_safely(db.security, "severity")
    await create_index_safely(db.security, [("ip_address", 1), ("type", 1)])
    await create_index_safely(db.security, [("user_id", 1), ("type", 1)])
    indexes_created.append("security")
    
    # ================= UNIFIED AI INSIGHTS =================
    await create_index_safely(db.ai_insights, "email")
    await create_index_safely(db.ai_insights, "type")
    await create_index_safely(db.ai_insights, "is_current")
    await create_index_safely(db.ai_insights, "analysis_hash", unique=True, sparse=True)
    await create_index_safely(db.ai_insights, "expires_at", expireAfterSeconds=0)
    await create_index_safely(db.ai_insights, [("email", 1), ("type", 1), ("is_current", 1)])
    await create_index_safely(db.ai_insights, [("type", 1), ("status", 1), ("progress_percentage", -1)])
    indexes_created.append("ai_insights")
    
    # Resumes
    await create_index_safely(db.resumes, "user_email")
    await create_index_safely(db.resumes, "created_at")
    await create_index_safely(db.resumes, "is_primary")
    indexes_created.append("resumes")
    
    # Backup records (keep for legacy)
    await create_index_safely(db.backup_records, "created_at")
    indexes_created.append("backup_records")
    
    logger.info("=" * 60)
    logger.info(f"✅ Index setup complete! ({len(indexes_created)} collections)")
    logger.info("=" * 60)
    
    return {
        "success": True,
        "collections_indexed": indexes_created,
        "total_collections": len(indexes_created)
    }