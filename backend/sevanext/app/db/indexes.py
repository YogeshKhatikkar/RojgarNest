# app/db/indexes.py
# ✅ NO TTL INDEXES - DATA NEVER AUTO-DELETED
# ✅ Unified `applications` collection stores ALL applications
# ✅ Includes per-document index for scheme uploads

from typing import Dict, Any
from app.db.connection import get_db
import logging

logger = logging.getLogger(__name__)


async def create_index_safely(collection, keys, **kwargs):
    if "expireAfterSeconds" in kwargs:
        logger.warning(
            f"🚫 BLOCKED TTL index on '{collection.name}' for keys {keys}."
        )
        kwargs = {k: v for k, v in kwargs.items() if k != "expireAfterSeconds"}

    try:
        await collection.create_index(keys, **kwargs)
        return True
    except Exception as e:
        msg = str(e)
        if (
            "already exists" in msg
            or "IndexKeySpecsConflict" in msg
            or "IndexOptionsConflict" in msg
        ):
            return False
        elif "DuplicateKey" in msg or "E11000" in msg:
            logger.warning(f"⚠️ Duplicate key - skipping: {keys}")
            return False
        else:
            logger.warning(f"Index warning: {e}")
            return False


async def setup_all_indexes() -> Dict[str, Any]:
    db = get_db()

    logger.info("=" * 60)
    logger.info("📊 Setting up indexes (NO TTL - PERMANENT DATA)")
    logger.info("=" * 60)

    indexes_created = []

    # ==================== AUTH ====================
    await create_index_safely(db.auth, "email", unique=True)
    await create_index_safely(db.auth, "mobile", unique=True, sparse=True)
    await create_index_safely(db.auth, "created_at")
    await create_index_safely(db.auth, "role")
    await create_index_safely(db.auth, "is_active")
    await create_index_safely(db.auth, "failed_attempts")
    await create_index_safely(db.auth, "lock_until")
    indexes_created.append("auth")

    # ==================== SESSIONS ====================
    await create_index_safely(db.sessions, "user_id")
    await create_index_safely(db.sessions, "session_hash",
                              unique=True, sparse=True)
    await create_index_safely(db.sessions, "created_at")
    await create_index_safely(db.sessions, "ip")
    await create_index_safely(db.sessions, "device")
    await create_index_safely(db.sessions, "expires_at")
    await create_index_safely(db.sessions, [("user_id", 1), ("is_active", 1)])
    await create_index_safely(db.sessions, [("user_id", 1), ("is_archived", 1)])
    indexes_created.append("sessions")

    # ==================== PROFILE ====================
    await create_index_safely(db.profile, "email", unique=True)
    await create_index_safely(db.profile, "created_at")
    await create_index_safely(db.profile, "updated_at")
    await create_index_safely(db.profile, "category")
    await create_index_safely(db.profile, "disability.is_disabled")
    await create_index_safely(db.profile, "disability.category")
    await create_index_safely(db.profile, [("skills.name", 1)])
    indexes_created.append("profile")

    # ==================== JOBS ====================
    await create_index_safely(db.job, "status")
    await create_index_safely(db.job, "created_at")
    await create_index_safely(db.job, [("post_date", -1)])
    await create_index_safely(db.job, "organization")
    await create_index_safely(db.job, "job_type")
    await create_index_safely(db.job, "category")
    indexes_created.append("jobs")

    # ==================== APPLICATIONS ====================
    await create_index_safely(db.applications, "application_type")
    await create_index_safely(db.applications, "user_email")
    await create_index_safely(db.applications, "user_id")
    await create_index_safely(db.applications, "status")
    await create_index_safely(db.applications, "payment_verification_status")
    await create_index_safely(db.applications, "created_at")
    await create_index_safely(db.applications, "updated_at")

    await create_index_safely(db.applications, "job_id", sparse=True)
    await create_index_safely(db.applications, "service_id", sparse=True)
    await create_index_safely(db.applications, "scheme_id", sparse=True)
    await create_index_safely(db.applications, "application_id", sparse=True)

    # ✅ New — for direct document lookups per application
    await create_index_safely(db.applications, "documents.document_type",
                              sparse=True)

    await create_index_safely(
        db.applications, [("user_email", 1), ("application_type", 1)]
    )
    await create_index_safely(
        db.applications, [("user_email", 1), ("status", 1)]
    )
    await create_index_safely(
        db.applications, [("application_type", 1), ("status", 1)]
    )
    await create_index_safely(
        db.applications, [("job_id", 1), ("user_email", 1)]
    )
    await create_index_safely(
        db.applications,
        [("service_id", 1), ("sub_type_id", 1), ("user_email", 1)],
    )
    await create_index_safely(
        db.applications, [("scheme_id", 1), ("user_email", 1)]
    )
    await create_index_safely(
        db.applications, [("payment_verification_status", 1), ("status", 1)]
    )
    indexes_created.append("applications")

    # ==================== NOTIFICATIONS ====================
    await create_index_safely(db.notifications, "user_id")
    await create_index_safely(db.notifications, "created_at")
    await create_index_safely(db.notifications, [("user_id", 1), ("read", 1)])
    indexes_created.append("notifications")

    # ==================== SECURITY ====================
    await create_index_safely(db.security, "type")
    await create_index_safely(db.security, "ip_address")
    await create_index_safely(db.security, "created_at")
    await create_index_safely(db.security, "expires_at")
    await create_index_safely(db.security, "severity")
    await create_index_safely(db.security, [("ip_address", 1), ("type", 1)])
    await create_index_safely(db.security, [("user_id", 1), ("type", 1)])
    indexes_created.append("security")

    # ==================== AI INSIGHTS ====================
    await create_index_safely(db.ai_insights, "email")
    await create_index_safely(db.ai_insights, "type")
    await create_index_safely(db.ai_insights, "is_current")
    await create_index_safely(
        db.ai_insights, "analysis_hash", unique=True, sparse=True
    )
    await create_index_safely(db.ai_insights, "expires_at")
    await create_index_safely(
        db.ai_insights, [("email", 1), ("type", 1), ("is_current", 1)]
    )
    await create_index_safely(
        db.ai_insights, [("type", 1), ("status", 1), ("progress_percentage", -1)]
    )
    indexes_created.append("ai_insights")

    # ==================== RESUMES ====================
    await create_index_safely(db.resumes, "user_email")
    await create_index_safely(db.resumes, "created_at")
    await create_index_safely(db.resumes, "is_primary")
    indexes_created.append("resumes")

    # ==================== BACKUP ====================
    await create_index_safely(db.backup_records, "created_at")
    indexes_created.append("backup_records")

    logger.info("=" * 60)
    logger.info(f"✅ Index setup complete! ({len(indexes_created)} collections)")
    logger.info("✅ NO TTL INDEXES - ALL DATA IS PERMANENT")
    logger.info("=" * 60)

    return {
        "success": True,
        "collections_indexed": indexes_created,
        "total_collections": len(indexes_created),
        "ttl_indexes": 0,
        "data_is_permanent": True,
    }