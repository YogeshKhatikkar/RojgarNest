# app/models/notification_model.py - COMPLETE FIXED VERSION
# ✅ NO TTL - Notifications are PERMANENT

from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional, Literal


class NotificationModel(BaseModel):
    """
    Notification model.
    ✅ NO TTL - Notifications are PERMANENT
    """

    user_id: Optional[str] = None
    type: Literal["new_job", "application_update", "system", "otp"] = "new_job"
    title: str
    message: str
    related_id: Optional[str] = None
    read: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)

    model_config = {
        "collection": "notifications",
        "arbitrary_types_allowed": True,
        "json_encoders": {
            datetime: lambda v: v.isoformat()
        }
    }


print("✅ Notification Model Loaded - NO TTL")