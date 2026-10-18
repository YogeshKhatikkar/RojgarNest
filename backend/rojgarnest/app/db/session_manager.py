# app/db/session_manager.py - COMPLETE FIXED VERSION
# ✅ CRITICAL: Sessions are NEVER auto-deleted
# ✅ Max 3 sessions per user - oldest ARCHIVED not deleted
# ✅ Only explicit logout archives sessions (never deletes)

from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List
from bson import ObjectId
import logging

from app.db.connection import get_db
from app.models.session_model import SessionModel
from app.models.profile_model import SessionInfo

logger = logging.getLogger(__name__)


class SessionManager:
    """
    Smart Session Management with PERMANENT data retention.

    ✅ MAX 3 ACTIVE SESSIONS PER USER
    ✅ When limit exceeded, oldest session is ARCHIVED (not deleted)
    ✅ Sessions are NEVER auto-deleted
    ✅ Only explicit logout archives sessions
    """

    def __init__(self):
        self.max_active_sessions = 3
        self.session_timeout_days = 3
        self.inactive_timeout_hours = 24

    async def create_session(self, user_id: str, user_email: str,
                             request_info: Dict) -> Dict:
        """Create new session with strict limits"""
        db = get_db()

        # Get current active sessions count for this user
        active_sessions = await db.sessions.find({
            "user_id": user_id,
            "is_active": True
        }).to_list(100)

        active_count = len(active_sessions)

        # ✅ If already 3 or more active sessions, ARCHIVE the oldest ones
        if active_count >= self.max_active_sessions:
            to_archive_count = active_count - self.max_active_sessions + 1

            oldest_sessions = await db.sessions.find(
                {"user_id": user_id, "is_active": True}
            ).sort("created_at", 1).limit(to_archive_count).to_list(to_archive_count)

            for old_session in oldest_sessions:
                # ✅ ARCHIVE instead of DELETE
                await db.sessions.update_one(
                    {"_id": old_session["_id"]},
                    {"$set": {
                        "is_active": False,
                        "is_archived": True,
                        "archived_at": datetime.utcnow(),
                        "archive_reason": "max_sessions_exceeded"
                    }}
                )
                logger.info(
                    f"📦 Archived old session for user {user_id} "
                    f"(max {self.max_active_sessions} limit reached)"
                )

                # Remove from user profile active sessions
                await db.profile.update_one(
                    {"email": user_email},
                    {"$pull": {"active_sessions": {"session_id": str(old_session["_id"])}}}
                )

        # Create new session
        session = SessionModel.create(
            user_id=user_id,
            user_email=user_email,
            ip=request_info.get('ip', ''),
            device=request_info.get('device', 'Unknown'),
            user_agent=request_info.get('user_agent', ''),
            refresh_token=request_info.get('refresh_token')
        )
        session.location = request_info.get('location', 'Unknown')

        result = await db.sessions.insert_one(session.model_dump(by_alias=True))
        session_id = str(result.inserted_id)

        # Update user profile with active session info
        session_info = SessionInfo(
            session_id=session_id,
            session_hash=session.session_hash[:16],
            device=request_info.get('device', 'Unknown'),
            login_time=datetime.utcnow(),
            ip=request_info.get('ip', '')
        )

        await db.profile.update_one(
            {"email": user_email},
            {
                "$push": {
                    "active_sessions": {
                        "$each": [session_info.model_dump()],
                        "$slice": -self.max_active_sessions
                    }
                }
            },
            upsert=True
        )

        logger.info(f"✅ Session created for {user_email}")

        return {
            "session_id": session_id,
            "session_hash": session.session_hash,
            "expires_at": session.expires_at.isoformat()
        }

    async def archive_expired_sessions(self) -> Dict:
        """
        ✅ ARCHIVE expired sessions - DO NOT DELETE.
        Data is preserved for audit purposes.
        """
        db = get_db()
        now = datetime.utcnow()

        results = {
            "archived_count": 0,
            "total_processed": 0
        }

        # ✅ ARCHIVE (not delete) expired sessions
        expired_result = await db.sessions.update_many(
            {
                "expires_at": {"$lt": now},
                "is_archived": {"$ne": True}
            },
            {"$set": {
                "is_active": False,
                "is_archived": True,
                "archived_at": now,
                "archive_reason": "expired"
            }}
        )
        results["archived_count"] = expired_result.modified_count

        if results["archived_count"] > 0:
            logger.info(f"📦 Archived {results['archived_count']} expired sessions")

        results["total_processed"] = results["archived_count"]
        return results

    async def validate_session(self, session_id: str, session_hash: str) -> Optional[Dict]:
        """Validate if session is still active and not expired"""
        db = get_db()

        if not ObjectId.is_valid(session_id):
            return None

        session = await db.sessions.find_one({
            "_id": ObjectId(session_id),
            "session_hash": session_hash,
            "is_active": True,
            "expires_at": {"$gt": datetime.utcnow()}
        })

        if session:
            await db.sessions.update_one(
                {"_id": session["_id"]},
                {"$set": {"last_activity": datetime.utcnow()}}
            )

            return {
                "user_id": session["user_id"],
                "user_email": session["user_email"],
                "session_id": str(session["_id"]),
                "created_at": session["created_at"],
                "expires_at": session["expires_at"]
            }

        return None

    async def logout_session(self, session_id: str, user_id: str) -> Dict:
        """
        Logout specific session.
        ✅ ARCHIVES the session (does not delete).
        """
        db = get_db()

        if not ObjectId.is_valid(session_id):
            return {"message": "Invalid session ID"}

        # ✅ ARCHIVE instead of DELETE
        result = await db.sessions.update_one(
            {"_id": ObjectId(session_id), "user_id": user_id},
            {"$set": {
                "is_active": False,
                "is_archived": True,
                "archived_at": datetime.utcnow(),
                "archive_reason": "user_logout"
            }}
        )

        if result.modified_count > 0:
            await db.profile.update_one(
                {"user_id": user_id},
                {"$pull": {"active_sessions": {"session_id": session_id}}}
            )
            logger.info(f"🔓 User {user_id} logged out from session {session_id}")
            return {"message": "Logged out successfully", "session_id": session_id}

        return {"message": "Session not found"}

    async def logout_all_devices(self, user_email: str, user_id: str,
                                 keep_current_session_id: Optional[str] = None) -> Dict:
        """
        Logout from all devices.
        ✅ ARCHIVES sessions (does not delete).
        """
        db = get_db()

        query = {"user_email": user_email, "is_active": True}
        if keep_current_session_id:
            query["_id"] = {"$ne": ObjectId(keep_current_session_id)}

        # ✅ ARCHIVE instead of DELETE
        result = await db.sessions.update_many(
            query,
            {"$set": {
                "is_active": False,
                "is_archived": True,
                "archived_at": datetime.utcnow(),
                "archive_reason": "logout_all_devices"
            }}
        )

        await db.profile.update_one(
            {"email": user_email},
            {"$set": {"active_sessions": []}}
        )

        logger.info(
            f"🔓 User {user_email} logged out from {result.modified_count} devices"
        )

        return {
            "message": f"Logged out from {result.modified_count} devices",
            "devices_logged_out": result.modified_count
        }

    async def get_user_sessions(self, user_id: str) -> List[Dict]:
        """Get all active sessions for a user"""
        db = get_db()

        sessions = await db.sessions.find(
            {"user_id": user_id, "is_active": True}
        ).sort("created_at", -1).to_list(100)

        return [
            {
                "session_id": str(s["_id"]),
                "device": s.get("device", "Unknown"),
                "ip": s.get("ip", "Unknown"),
                "location": s.get("location", "Unknown"),
                "created_at": s["created_at"].isoformat(),
                "last_activity": s["last_activity"].isoformat(),
                "expires_at": s["expires_at"].isoformat()
            }
            for s in sessions
        ]

    async def get_session_stats(self) -> Dict:
        """Get session statistics for monitoring"""
        db = get_db()

        total_sessions = await db.sessions.count_documents({})
        total_active = await db.sessions.count_documents({"is_active": True})
        total_archived = await db.sessions.count_documents({"is_archived": True})

        unique_users = len(await db.sessions.distinct("user_id", {"is_active": True}))

        return {
            "total_sessions": total_sessions,
            "total_active_sessions": total_active,
            "total_archived_sessions": total_archived,
            "unique_users_active": unique_users,
            "max_sessions_per_user": self.max_active_sessions,
            "session_timeout_days": self.session_timeout_days,
            "data_retention": "PERMANENT",
            "health_status": (
                "good" if total_active < 100
                else "warning" if total_active < 500
                else "critical"
            )
        }

    async def enforce_session_limit_for_user(self, user_id: str, user_email: str) -> int:
        """
        Enforce max 3 sessions limit for a specific user.
        ✅ ARCHIVES old sessions (does not delete).
        """
        db = get_db()

        sessions = await db.sessions.find(
            {"user_id": user_id, "is_active": True}
        ).sort("created_at", 1).to_list(100)

        session_count = len(sessions)
        archived_count = 0

        if session_count > self.max_active_sessions:
            to_archive = sessions[:session_count - self.max_active_sessions]

            for session in to_archive:
                # ✅ ARCHIVE instead of DELETE
                await db.sessions.update_one(
                    {"_id": session["_id"]},
                    {"$set": {
                        "is_active": False,
                        "is_archived": True,
                        "archived_at": datetime.utcnow(),
                        "archive_reason": "session_limit_enforced"
                    }}
                )
                archived_count += 1

                await db.profile.update_one(
                    {"email": user_email},
                    {"$pull": {"active_sessions": {"session_id": str(session["_id"])}}}
                )

            logger.info(
                f"📦 Enforced session limit for {user_email}: "
                f"archived {archived_count} old sessions"
            )

        return archived_count


# Global instance
session_manager = SessionManager()

print("=" * 60)
print("✅ Session Manager Loaded - PERMANENT DATA RETENTION")
print(f"   ✅ Max sessions per user: {session_manager.max_active_sessions}")
print(f"   ✅ Session timeout: {session_manager.session_timeout_days} days")
print("   ✅ Sessions are ARCHIVED (not deleted) when limit exceeded")
print("   ✅ Sessions are ARCHIVED (not deleted) on logout")
print("   ✅ NO automatic deletion of any session data")
print("=" * 60)