from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime


class ResumeUploadResponse(BaseModel):
    resume_id: str
    filename: str
    parsed_data: Dict[str, Any]
    ats_score: int
    message: str


class ATSOptimizationResponse(BaseModel):
    current_ats_score: int
    match_percentage: int
    job_title: str
    suggestions: List[str]
    optimization_suggestions: Dict[str, Any]


class ResumeListResponse(BaseModel):
    resumes: List[Dict[str, Any]]
    total: int