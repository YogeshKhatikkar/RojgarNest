# app/modules/notification/schema.py
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime


class NotificationResponse(BaseModel):
    message: str
    users_notified: int = 0
    job_title: Optional[str] = None


class NotificationCreateSchema(BaseModel):
    user_id: str
    type: str = "system"  # new_job, application_update, system
    title: str
    message: str
    related_id: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


class NotificationUpdateSchema(BaseModel):
    read: Optional[bool] = None
    title: Optional[str] = None
    message: Optional[str] = None


class NotificationResponseSchema(BaseModel):
    id: str
    user_id: str
    type: str
    title: str
    message: str
    related_id: Optional[str] = None
    read: bool
    created_at: datetime
    metadata: Optional[Dict[str, Any]] = None