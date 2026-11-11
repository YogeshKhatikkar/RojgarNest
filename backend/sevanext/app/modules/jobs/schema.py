# app/modules/jobs/schema.py
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from app.models.job_model import JobModel


class JobCreateSchema(JobModel):
    """Full job creation - inherits all validation from JobModel"""
    pass


class JobUpdateSchema(BaseModel):
    """Partial update - only fields admin can change"""
    post_name: Optional[str] = None
    location: Optional[str] = None
    job_type: Optional[str] = None
    salary_min: Optional[int] = None
    salary_max: Optional[int] = None
    description: Optional[str] = None
    last_date: Optional[str] = None
    status: Optional[str] = Field(None, pattern="^(open|closed|filled)$")
    category: Optional[str] = None

    # ✅ NEW: color_type
    color_type: Optional[str] = Field(
        None,
        pattern="^(blue|green|red|orange|purple|teal|pink|indigo|amber|cyan|grey|gray|white)$"
    )

    is_featured: Optional[bool] = None
    is_urgent: Optional[bool] = None
    total_posts: Optional[int] = None
    apply_with_us_url: Optional[str] = None
    has_apply_with_us: Optional[bool] = None

    model_config = {"extra": "ignore"}


class JobListResponse(BaseModel):
    jobs: List[Dict[str, Any]]
    total: int
    page: int
    limit: int


class ApplicationCreateSchema(BaseModel):
    job_id: str
    resume_url: Optional[str] = None
    cover_letter: Optional[str] = None
    additional_info: Optional[Dict[str, Any]] = None


class ApplicationStatusUpdateSchema(BaseModel):
    status: str = Field(..., pattern="^(pending|shortlisted|interview|offered|rejected|submitted)$")
    notes: Optional[str] = None


class RecommendedJobResponse(BaseModel):
    jobs: List[Dict[str, Any]]
    total: int
    message: str = "Recommended based on your profile"