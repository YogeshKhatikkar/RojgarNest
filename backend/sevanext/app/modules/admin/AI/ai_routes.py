# app/modules/admin/AI/ai_routes.py
"""
Admin AI Routes - Accessed via /api/v1/admin/ai/*
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional, Dict, Any
from bson import ObjectId
import logging

from app.core.services.dependencies import get_current_user, role_required
from app.db.connection import get_db

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["Admin AI Services"])


@router.get("/candidate-scoring")
async def admin_candidate_scoring(
    application_id: str = Query(...),
    current_user: dict = Depends(role_required("admin")),
    db=Depends(get_db)
):
    """AI-powered candidate scoring"""
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    profile = await db.profile.find_one({"email": application.get("applicant_email")})
    job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))}) if application.get("job_id") else None
    
    if not profile or not job:
        return {"error": "Profile or job not found"}
    
    user_skills = [s.get('name', '').lower() for s in profile.get('skills', [])]
    job_skills = []
    for skill in job.get('required_skills', []):
        if isinstance(skill, dict):
            job_skills.append(skill.get('name', '').lower())
        elif isinstance(skill, str):
            job_skills.append(skill.lower())
    
    if job_skills and user_skills:
        matching_skills = set(user_skills) & set(job_skills)
        skill_match = (len(matching_skills) / len(job_skills)) * 100
    else:
        skill_match = 50
        matching_skills = set()
    
    user_exp = len(profile.get('experience', []))
    req_exp = job.get('experience_min_years', 0)
    exp_match = min(100, (user_exp / max(1, req_exp)) * 100) if req_exp > 0 else 70
    
    total_score = (skill_match * 0.6 + exp_match * 0.4)
    
    return {
        "candidate_name": profile.get('full_name', 'N/A'),
        "candidate_email": application.get("applicant_email"),
        "job_title": job.get('post_name', 'N/A'),
        "total_score": round(total_score),
        "skill_match": round(skill_match),
        "experience_match": round(exp_match),
        "recommendation": "strong_shortlist" if total_score >= 85 else "shortlist" if total_score >= 70 else "consider" if total_score >= 50 else "reject",
        "strengths": list(matching_skills)[:3] if job_skills else [],
        "gaps": list(set(job_skills) - set(user_skills))[:3] if job_skills else []
    }


@router.get("/fraud-detection")
async def admin_fraud_detection(
    application_id: str = Query(...),
    current_user: dict = Depends(role_required("admin")),
    db=Depends(get_db)
):
    """AI-powered fraud detection"""
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    fraud_score = 0
    red_flags = []
    
    if not application.get('cover_letter'):
        fraud_score += 15
        red_flags.append("No cover letter provided")
    
    profile = await db.profile.find_one({"email": application.get("applicant_email")})
    if profile and not profile.get('skills'):
        fraud_score += 20
        red_flags.append("No skills listed in profile")
    
    if application.get('match_score', 0) > 90 and profile and not profile.get('experience'):
        fraud_score += 25
        red_flags.append("High match score with no experience - unusual pattern")
    
    if not profile:
        fraud_score += 30
        red_flags.append("Profile not found")
    
    risk_level = "low"
    if fraud_score >= 60:
        risk_level = "high"
    elif fraud_score >= 30:
        risk_level = "medium"
    
    return {
        "fraud_score": round(fraud_score),
        "risk_level": risk_level,
        "red_flags": red_flags,
        "recommendation": "reject" if fraud_score >= 60 else "review" if fraud_score >= 30 else "approve"
    }


@router.get("/hiring-trends")
async def admin_hiring_trends(
    days: int = Query(30, ge=1, le=365),
    current_user: dict = Depends(role_required("admin")),
    db=Depends(get_db)
):
    """AI-powered hiring trends prediction"""
    from datetime import datetime, timedelta
    start_date = datetime.utcnow() - timedelta(days=days)
    
    applications = await db.applications.find({"created_at": {"$gte": start_date}}).to_list(1000)
    
    total_apps = len(applications)
    avg_daily = total_apps / days if days > 0 else 0
    
    # Get top job categories
    job_categories = {}
    for app in applications:
        job = await db.job.find_one({"_id": ObjectId(app.get("job_id"))}) if app.get("job_id") else None
        if job:
            category = job.get('category', 'Other')
            job_categories[category] = job_categories.get(category, 0) + 1
    
    top_categories = sorted(job_categories.items(), key=lambda x: x[1], reverse=True)[:5]
    
    return {
        "total_applications": total_apps,
        "average_daily_applications": round(avg_daily, 1),
        "trend_direction": "increasing" if avg_daily > 10 else "stable" if avg_daily > 5 else "decreasing",
        "predicted_next_30_days": round(avg_daily * 30),
        "top_job_categories": [{"category": cat, "count": count} for cat, count in top_categories]
    }


@router.get("/applications/ranked")
async def admin_ranked_applications(
    job_id: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    current_user: dict = Depends(role_required("admin")),
    db=Depends(get_db)
):
    """Get AI-ranked applications"""
    query = {}
    if job_id and ObjectId.is_valid(job_id):
        query["job_id"] = job_id
    
    applications = await db.applications.find(query).sort("match_score", -1).limit(limit).to_list(limit)
    
    ranked_apps = []
    for app in applications:
        ranked_apps.append({
            "application_id": str(app["_id"]),
            "candidate_name": app.get("applicant_name", "N/A"),
            "candidate_email": app.get("applicant_email", "N/A"),
            "job_title": app.get("job_title", "N/A"),
            "match_score": app.get("match_score", 0),
            "status": app.get("status", "pending"),
            "applied_at": app.get("applied_at").isoformat() if app.get("applied_at") else None
        })
    
    return {
        "ranked_applications": ranked_apps,
        "total": len(ranked_apps),
        "ai_ranked": True
    }