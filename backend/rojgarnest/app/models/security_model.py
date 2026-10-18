# app/models/security_model.py - COMPLETE FIXED VERSION
# ✅ NO TTL INDEXES - Security logs are PERMANENT

from pydantic import BaseModel, Field, model_validator
from typing import Optional, Dict, Any
from datetime import datetime, timedelta
from enum import Enum


class SecurityType(str, Enum):
    IP_BLACKLIST = "ip_blacklist"
    SECURITY_LOG = "security_log"


class Severity(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class SecurityModel(BaseModel):
    """
    Single collection for all security data.
    ✅ NO TTL - Security logs are PERMANENT
    """

    # Type
    type: SecurityType

    # Common fields
    ip_address: str
    user_id: Optional[str] = None
    user_email: Optional[str] = None

    # IP Blacklist fields
    reason: Optional[str] = None
    permanent: bool = False
    attempts: int = 0
    # ✅ For reference only - NOT a TTL index
    expires_at: Optional[datetime] = None

    # Security Log fields
    event_type: Optional[str] = None
    severity: Severity = Severity.MEDIUM
    details: Optional[Dict[str, Any]] = None
    action_taken: Optional[str] = None

    # Timestamp
    created_at: datetime = Field(default_factory=datetime.utcnow)

    @model_validator(mode='after')
    def set_blacklist_expiry(self):
        """Set expiry for temporary blacklist entries"""
        if (
            self.type == SecurityType.IP_BLACKLIST
            and not self.permanent
            and self.expires_at is None
        ):
            self.expires_at = datetime.utcnow() + timedelta(hours=24)
        return self

    @classmethod
    def create_blacklist(cls, ip: str, reason: str, permanent: bool = False,
                         hours: int = 24):
        """Create IP blacklist entry"""
        return cls(
            type=SecurityType.IP_BLACKLIST,
            ip_address=ip,
            reason=reason,
            permanent=permanent,
            expires_at=(
                None if permanent
                else datetime.utcnow() + timedelta(hours=hours)
            )
        )

    @classmethod
    def create_log(cls, ip: str, event_type: str, severity: Severity,
                   details: Dict = None, user_id: str = None):
        """Create security log entry"""
        return cls(
            type=SecurityType.SECURITY_LOG,
            ip_address=ip,
            user_id=user_id,
            event_type=event_type,
            severity=severity,
            details=details
        )

    def is_active_blacklist(self) -> bool:
        """Check if blacklist entry is still active"""
        if self.type != SecurityType.IP_BLACKLIST:
            return False
        if self.permanent:
            return True
        return self.expires_at and datetime.utcnow() < self.expires_at

    model_config = {
        "collection": "security",
        "json_encoders": {datetime: lambda v: v.isoformat()},
        "indexes": [
            ("type", None),
            ("ip_address", None),
            ("created_at", None),
            # ❌ NO TTL - expires_at is NOT indexed with expireAfterSeconds
            ("severity", None),
            [("ip_address", 1), ("type", 1)],
            [("user_id", 1), ("type", 1)]
        ]
    }


print("✅ Security Model Loaded - NO TTL")