# app/modules/superadmin/schema.py - FIXED

from pydantic import BaseModel, Field, EmailStr
from typing import Optional, List, Dict, Any
from datetime import datetime


class UserFilterSchema(BaseModel):
    role: Optional[str] = Field(None, pattern="^(user|admin|superadmin)$")
    is_active: Optional[bool] = None
    limit: int = Field(50, ge=1, le=200)
    skip: int = 0


class PromoteToAdminSchema(BaseModel):
    email: EmailStr
    notes: Optional[str] = None


# ✅ FIXED: Removed "delete" from allowed actions
class BulkActionSchema(BaseModel):
    emails: List[EmailStr]
    action: str = Field(..., pattern="^(promote_to_admin|demote_to_user|deactivate)$")  # NO DELETE
    notes: Optional[str] = None


class AIPredictiveAnalytics(BaseModel):
    next_30_days_users: int
    next_30_days_jobs: int
    next_30_days_placements: int
    growth_trend: str


class AIAnomalyDetection(BaseModel):
    detected_issues: List[str]
    severity: str
    suggestion: str


class AISmartDashboardResponse(BaseModel):
    generated_at: datetime
    overview: Dict[str, Any]
    user_analytics: Dict[str, Any]
    job_analytics: Dict[str, Any]
    application_analytics: Dict[str, Any]
    ai_executive_summary: str
    predictive_analytics: AIPredictiveAnalytics
    anomaly_detection: AIAnomalyDetection
    recommendations: List[str]
    platform_health_score: int   # 0-100