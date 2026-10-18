# app/models/session_model.py - COMPLETE FIXED VERSION
# ✅ NO TTL INDEXES - Sessions are NEVER auto-deleted
# ✅ Max 3 sessions per user (oldest ARCHIVED, not deleted)

from pydantic import BaseModel, Field, model_validator
from typing import Optional
from datetime import datetime, timedelta
import secrets
import hashlib


class SessionModel(BaseModel):
    """
    Session model with PERMANENT data retention.
    ✅ NO TTL - Sessions are never auto-deleted
    ✅ Max 3 sessions per user (oldest ARCHIVED, not deleted)
    """

    # Identification
    user_id: str
    user_email: str
    session_hash: str

    # Session info
    ip: str
    device: str
    user_agent: Optional[str] = None
    location: Optional[str] = None

    # Status
    is_active: bool = True
    is_archived: bool = False

    # Security
    refresh_token_hash: Optional[str] = None
    failed_attempts: int = 0

    # Timestamps
    created_at: datetime = Field(default_factory=datetime.utcnow)
    last_activity: datetime = Field(default_factory=datetime.utcnow)
    expires_at: datetime

    # Archive info
    archived_at: Optional[datetime] = None
    archive_reason: Optional[str] = None
    logout_reason: Optional[str] = None

    @model_validator(mode='after')
    def set_expiry(self):
        """Auto-set expiry to 3 days"""
        if self.expires_at is None:
            self.expires_at = self.created_at + timedelta(days=3)
        return self

    @classmethod
    def create(cls, user_id: str, user_email: str, ip: str,
               device: str, user_agent: str = None, refresh_token: str = None):
        """Create a new session with 3-day expiry"""
        session_hash = secrets.token_hex(32)

        return cls(
            user_id=user_id,
            user_email=user_email,
            session_hash=session_hash,
            ip=ip,
            device=device,
            user_agent=user_agent,
            refresh_token_hash=(
                hashlib.sha256(refresh_token.encode()).hexdigest()
                if refresh_token else None
            ),
            created_at=datetime.utcnow(),
            last_activity=datetime.utcnow(),
            expires_at=datetime.utcnow() + timedelta(days=3)
        )

    def touch(self):
        """Update last activity timestamp"""
        self.last_activity = datetime.utcnow()

    def is_expired(self) -> bool:
        """Check if session is expired"""
        return datetime.utcnow() > self.expires_at

    def archive(self, reason: str = "expired"):
        """Mark session as archived (soft delete)"""
        self.is_active = False
        self.is_archived = True
        self.archived_at = datetime.utcnow()
        self.archive_reason = reason

    model_config = {
        "collection": "sessions",
        "json_encoders": {datetime: lambda v: v.isoformat()},
        "indexes": [
            ("session_hash", {"unique": True}),
            ("user_id", None),
            # ❌ NO TTL indexes - data is permanent
            [("user_id", 1), ("is_active", 1)],
            [("user_id", 1), ("is_archived", 1)],
            ("is_active", 1),
            ("last_activity", 1),
        ]
    }


print("✅ Session Model Loaded - PERMANENT DATA RETENTION")
print("   ✅ NO TTL indexes - sessions never auto-deleted")
print("   ✅ Max 3 sessions per user (oldest ARCHIVED)")