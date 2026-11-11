# app/modules/admin/schema.py
from pydantic import BaseModel, Field, EmailStr
from typing import Optional, List, Dict, Any
from datetime import datetime


class ApplicationFilterSchema(BaseModel):
    status: Optional[str] = Field(None, pattern="^(pending|shortlisted|interview|offered|rejected)$")
    min_match_score: Optional[float] = Field(None, ge=0, le=100)
    job_id: Optional[str] = None
    applicant_email: Optional[EmailStr] = None
    limit: int = Field(50, ge=1, le=200)
    sort_by: str = Field("match_score", pattern="^(match_score|applied_at)$")
    sort_order: str = Field("desc", pattern="^(asc|desc)$")


class AIMatchResponse(BaseModel):
    match_percentage: float = Field(..., ge=0, le=100)
    reason: str
    strengths: List[str]
    gaps: List[str]
    suggested_action: str = Field(..., pattern="^(strong_shortlist|shortlist|consider|reject)$")


class AIInsightsResponse(BaseModel):
    detailed_analysis: str
    key_strengths: List[str]
    improvement_areas: List[str]
    recommended_interview_questions: List[str]
    overall_recommendation: str


class SkillGapAnalysisResponse(BaseModel):
    missing_skills: List[str]
    strength_score: float
    gap_score: float
    improvement_plan: List[str]
    predicted_hire_success: float


class AutoShortlistSuggestion(BaseModel):
    application_id: str
    candidate_name: str
    match_percentage: float
    reason: str
    action: str


class LeaderboardResponse(BaseModel):
    rank: int
    application_id: str
    candidate_name: str
    job_title: str
    match_percentage: float
    predicted_hire_success: float


class BulkStatusUpdateSchema(BaseModel):
    application_ids: List[str]
    status: str = Field(..., pattern="^(pending|shortlisted|interview|offered|rejected)$")
    notes: Optional[str] = None