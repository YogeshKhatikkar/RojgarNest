# app/modules/jobs/AI/ai_routes.py
"""
Jobs AI Routes - Real-time Analysis & Matching
Accessed via /api/v1/jobs/ai/*
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional, Dict, List
from bson import ObjectId
from datetime import datetime
import logging

from app.core.services.dependencies import get_current_user
from app.db.connection import get_db
from app.core.ai.ultra_ai_engine import ultra_ai_engine
from app.core.ai.real_time_market_ai import real_time_market_ai

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["Jobs AI Services"])


@router.get("/match-score")
async def jobs_match_score(
    job_id: str = Query(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    AI-POWERED JOB MATCH SCORE
    - Real-time skill matching
    - Experience alignment
    - Education fit
    - Market demand integration
    - Detailed breakdown
    """
    if not ObjectId.is_valid(job_id):
        raise HTTPException(status_code=400, detail="Invalid job ID")
    
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    # Get job details
    job = await db.job.find_one({"_id": ObjectId(job_id)})
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    # Get user profile
    profile = await db.profile.find_one({"email": email})
    if not profile:
        return {
            "success": True,
            "match_score": 0,
            "skill_match": 0,
            "experience_match": 0,
            "education_match": 0,
            "reason": "Complete your profile for accurate matching",
            "recommendation": "complete_profile",
            "matching_skills": [],
            "missing_skills": [],
            "job_title": job.get('post_name', '')
        }
    
    # Extract skills
    user_skills = [s.get('name', '').lower() for s in profile.get('skills', [])]
    
    job_skills = []
    for skill in job.get('required_skills', []):
        if isinstance(skill, dict):
            job_skills.append(skill.get('name', '').lower())
        elif isinstance(skill, str):
            job_skills.append(skill.lower())
    
    # Calculate matches
    if job_skills and user_skills:
        matching_skills = set(user_skills) & set(job_skills)
        skill_match = (len(matching_skills) / len(job_skills)) * 100
    else:
        skill_match = 50
        matching_skills = set()
    
    # Experience match
    user_exp = len(profile.get('experience', []))
    req_exp = job.get('experience_min_years', 0)
    exp_match = min(100, (user_exp / max(1, req_exp)) * 100) if req_exp > 0 else 70
    
    # Education match
    user_edu = len(profile.get('academic_records', []))
    edu_match = min(100, user_edu * 30) if user_edu > 0 else 20
    
    # Total match
    total_match = (skill_match * 0.5 + exp_match * 0.3 + edu_match * 0.2)
    
    # Get market demand for this job
    market_demand = await real_time_market_ai.predict_future_demand(job.get('post_name', ''), 6)
    
    # Get user location
    user_location = None
    user = await db.auth.find_one({"email": email})
    if user and user.get('current_location'):
        loc = user['current_location']
        user_location = {
            "latitude": loc.get('latitude'),
            "longitude": loc.get('longitude')
        }
    
    # Calculate distance if location available
    distance_km = None
    if user_location and user_location.get('latitude'):
        job_loc = job.get('job_location', {})
        job_lat = job_loc.get('latitude')
        job_lon = job_loc.get('longitude')
        
        if job_lat and job_lon:
            from app.core.location.distance_calculator import DistanceCalculator
            dist_m = DistanceCalculator.calculate_distance(
                user_location["latitude"],
                user_location["longitude"],
                job_lat,
                job_lon
            )
            distance_km = round(dist_m / 1000, 2)
    
    # Determine recommendation
    if total_match >= 85:
        recommendation = "highly_recommended"
    elif total_match >= 70:
        recommendation = "recommended"
    elif total_match >= 50:
        recommendation = "consider"
    else:
        recommendation = "not_recommended"
    
    return {
        "success": True,
        "match_score": round(total_match),
        "skill_match": round(skill_match),
        "experience_match": round(exp_match),
        "education_match": round(edu_match),
        "market_demand": market_demand.get('growth_percentage', 0),
        "matching_skills": list(matching_skills)[:5],
        "missing_skills": list(set(job_skills) - set(user_skills))[:5] if job_skills else [],
        "missing_skills_count": len(set(job_skills) - set(user_skills)) if job_skills else 0,
        "recommendation": recommendation,
        "job_title": job.get('post_name', ''),
        "organization": job.get('organization', ''),
        "location": job.get('location', ''),
        "distance_km": distance_km,
        "job_type": job.get('job_type', ''),
        "has_application_fees": job.get('has_application_fees', False),
        "application_fees": job.get('application_fees', {}),
        "applied": await _has_applied(job_id, email, db),
        "saved": await _is_saved(job_id, email, db),
        "timestamp": datetime.utcnow().isoformat()
    }


@router.get("/batch-match")
async def jobs_batch_match(
    job_ids: str = Query(..., description="Comma-separated job IDs"),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    BATCH JOB MATCH SCORING
    - Match scores for multiple jobs
    - Fast processing for job listings
    - Real-time skill matching
    """
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    # Parse job IDs
    job_id_list = [jid.strip() for jid in job_ids.split(',') if jid.strip()]
    valid_ids = [jid for jid in job_id_list if ObjectId.is_valid(jid)]
    
    if not valid_ids:
        return {
            "success": True,
            "matches": [],
            "total": 0,
            "message": "No valid job IDs provided"
        }
    
    # Get profile once
    profile = await db.profile.find_one({"email": email})
    
    if not profile:
        return {
            "success": True,
            "matches": [],
            "total": 0,
            "message": "Complete your profile for job matching"
        }
    
    # Get jobs
    jobs = await db.job.find({"_id": {"$in": [ObjectId(jid) for jid in valid_ids]}}).to_list(100)
    
    if not jobs:
        return {
            "success": True,
            "matches": [],
            "total": 0,
            "message": "No jobs found"
        }
    
    # Compute match for each job
    results = []
    user_skills = [s.get('name', '').lower() for s in profile.get('skills', [])]
    user_exp = len(profile.get('experience', []))
    user_edu = len(profile.get('academic_records', []))
    
    for job in jobs:
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
        
        req_exp = job.get('experience_min_years', 0)
        exp_match = min(100, (user_exp / max(1, req_exp)) * 100) if req_exp > 0 else 70
        edu_match = min(100, user_edu * 30) if user_edu > 0 else 20
        
        total_match = (skill_match * 0.5 + exp_match * 0.3 + edu_match * 0.2)
        
        results.append({
            "job_id": str(job['_id']),
            "title": job.get('post_name', ''),
            "organization": job.get('organization', ''),
            "match_score": round(total_match),
            "skill_match": round(skill_match),
            "experience_match": round(exp_match),
            "matching_skills": list(matching_skills)[:3],
            "location": job.get('location', ''),
            "job_type": job.get('job_type', ''),
            "posted_date": job.get('post_date', ''),
            "has_application_fees": job.get('has_application_fees', False)
        })
    
    # Sort by match score
    results.sort(key=lambda x: x['match_score'], reverse=True)
    
    return {
        "success": True,
        "matches": results,
        "total": len(results),
        "user_summary": {
            "skills_count": len(user_skills),
            "experience_count": user_exp,
            "education_count": user_edu
        },
        "timestamp": datetime.utcnow().isoformat()
    }


@router.get("/parse-description")
async def jobs_parse_description(
    job_id: str = Query(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    AI-POWERED JOB DESCRIPTION PARSING
    - Extract key information
    - Skills identification
    - Experience requirements
    - Education requirements
    - Salary predictions
    """
    if not ObjectId.is_valid(job_id):
        raise HTTPException(status_code=400, detail="Invalid job ID")
    
    job = await db.job.find_one({"_id": ObjectId(job_id)})
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    description = job.get('description', '')
    
    # Extract key information using AI
    import re
    
    # Extract skills from description
    skill_keywords = [
        'python', 'java', 'javascript', 'react', 'node', 'aws', 'docker',
        'kubernetes', 'sql', 'mongodb', 'flutter', 'django', 'flask',
        'machine learning', 'data science', 'ai', 'tensorflow', 'pytorch',
        'git', 'ci/cd', 'devops', 'agile', 'scrum', 'rest api'
    ]
    
    found_skills = []
    for skill in skill_keywords:
        if skill in description.lower():
            found_skills.append(skill)
    
    # Extract experience
    exp_pattern = r'(\d+)[\s-]*years?'
    exp_matches = re.findall(exp_pattern, description.lower())
    min_exp = int(exp_matches[0]) if exp_matches else 0
    
    # Extract education
    edu_patterns = ['bachelor', 'master', 'phd', 'graduate', 'diploma', 'b.tech', 'm.tech', 'b.sc', 'm.sc']
    found_education = [edu for edu in edu_patterns if edu in description.lower()]
    
    # Get market salary prediction
    salary_prediction = await _predict_salary(job)
    
    return {
        "success": True,
        "job_title": job.get('post_name', ''),
        "organization": job.get('organization', ''),
        "extracted_skills": found_skills[:10],
        "extracted_skills_count": len(found_skills),
        "min_experience_years": min_exp,
        "education_requirements": found_education[:3],
        "description_length": len(description),
        "has_benefits": "benefit" in description.lower(),
        "work_type": "remote" if "remote" in description.lower() else "hybrid" if "hybrid" in description.lower() else "onsite",
        "salary_prediction": salary_prediction,
        "job_type": job.get('job_type', ''),
        "location": job.get('location', ''),
        "last_date": job.get('last_date', ''),
        "has_application_fees": job.get('has_application_fees', False),
        "application_fees": job.get('application_fees', {}),
        "timestamp": datetime.utcnow().isoformat()
    }


@router.get("/salary-prediction")
async def jobs_salary_prediction(
    job_id: str = Query(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    AI-POWERED SALARY PREDICTION
    - Market-based salary estimation
    - Experience-adjusted predictions
    - Location-adjusted predictions
    - Confidence scoring
    """
    if not ObjectId.is_valid(job_id):
        raise HTTPException(status_code=400, detail="Invalid job ID")
    
    job = await db.job.find_one({"_id": ObjectId(job_id)})
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    # Get user profile for personalized salary
    email = current_user.get("email")
    profile = None
    if email:
        profile = await db.profile.find_one({"email": email})
    
    # Get market data
    market_data = await real_time_market_ai.get_live_market_data(job.get('post_name', ''))
    
    # Calculate salary based on job and user
    job_title = job.get('post_name', '')
    req_exp = job.get('experience_min_years', 0)
    
    # Get user experience if available
    user_exp = len(profile.get('experience', [])) if profile else 0
    
    # Base salary by job type
    base_salary = {
        'software engineer': 8,
        'data scientist': 10,
        'full stack developer': 9,
        'devops engineer': 9,
        'product manager': 12,
        'project manager': 10,
        'business analyst': 7,
        'marketing manager': 8,
        'sales manager': 8,
        'hr manager': 7,
        'finance manager': 9,
        'operations manager': 8,
        'customer support': 4,
        'administrative': 3,
        'others': 5
    }
    
    # Find base salary
    base = 5  # Default
    for key, value in base_salary.items():
        if key in job_title.lower():
            base = value
            break
    
    # Experience multiplier
    exp_multiplier = min(3, 1 + (max(req_exp, user_exp) * 0.15))
    
    # Location adjustment
    location = job.get('location', 'India').lower()
    location_multiplier = 1.3 if 'bangalore' in location or 'mumbai' in location else 1.1 if 'delhi' in location or 'hyderabad' in location else 1.0
    
    # Calculate estimated salary
    estimated_salary = base * exp_multiplier * location_multiplier
    
    # Determine confidence
    confidence = 80 if req_exp > 0 else 60
    
    return {
        "success": True,
        "job_title": job_title,
        "organization": job.get('organization', ''),
        "location": job.get('location', ''),
        "estimated_salary_lpa": round(estimated_salary, 1),
        "salary_range_lpa": f"₹{round(estimated_salary * 0.85, 1)}-{round(estimated_salary * 1.15, 1)} LPA",
        "base_salary_lpa": base,
        "experience_multiplier": round(exp_multiplier, 2),
        "location_multiplier": location_multiplier,
        "required_experience_years": req_exp,
        "user_experience_years": user_exp,
        "confidence_score": confidence,
        "market_trend": market_data.get('market_health', {}).get('overall_score', 70),
        "market_benchmark": f"₹{round(estimated_salary * 0.9, 1)}-{round(estimated_salary * 1.2, 1)} LPA",
        "currency": "INR",
        "timestamp": datetime.utcnow().isoformat()
    }


@router.get("/market-insights")
async def jobs_market_insights(
    job_id: str = Query(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    MARKET INSIGHTS FOR A JOB
    - Job market demand
    - Competition analysis
    - Hiring trends
    - Skill demand
    """
    if not ObjectId.is_valid(job_id):
        raise HTTPException(status_code=400, detail="Invalid job ID")
    
    job = await db.job.find_one({"_id": ObjectId(job_id)})
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    job_title = job.get('post_name', '')
    
    # Get market data
    market_data = await real_time_market_ai.get_live_market_data(job_title)
    demand_prediction = await real_time_market_ai.predict_future_demand(job_title, 6)
    
    # Get hot skills
    hot_skills = await real_time_market_ai.get_hot_skills(10)
    
    # Get similar jobs count
    similar_jobs = await db.job.count_documents({
        "post_name": {"$regex": job_title, "$options": "i"},
        "status": "open",
        "_id": {"$ne": ObjectId(job_id)}
    })
    
    # Calculate competition score
    applications_count = await db.applications.count_documents({"job_id": job_id})
    competition_score = min(100, (applications_count / 50) * 100) if applications_count > 0 else 10
    
    return {
        "success": True,
        "job_title": job_title,
        "market_demand": {
            "current_demand": demand_prediction.get('current_demand', 50),
            "predicted_growth": demand_prediction.get('growth_percentage', 0),
            "trend": demand_prediction.get('trend', 'stable')
        },
        "competition": {
            "applications_count": applications_count,
            "similar_jobs_count": similar_jobs,
            "competition_score": round(competition_score),
            "level": "high" if competition_score > 70 else "medium" if competition_score > 40 else "low"
        },
        "hiring_trends": {
            "active_companies": len(set([j.get('organization', '') for j in await db.job.find({"status": "open"}).to_list(50)])),
            "top_hiring_industries": market_data.get('top_employers', [])[:3]
        },
        "skill_demand": {
            "hot_skills": hot_skills[:5],
            "required_skills": job.get('required_skills', [])[:5]
        },
        "timestamp": datetime.utcnow().isoformat()
    }


@router.get("/recommend-skill")
async def jobs_recommend_skills(
    job_id: str = Query(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    RECOMMEND SKILLS TO LEARN FOR A JOB
    - Identify skill gaps
    - Recommend learning resources
    - Priority-based suggestions
    """
    if not ObjectId.is_valid(job_id):
        raise HTTPException(status_code=400, detail="Invalid job ID")
    
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    job = await db.job.find_one({"_id": ObjectId(job_id)})
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    profile = await db.profile.find_one({"email": email})
    if not profile:
        return {
            "success": True,
            "recommended_skills": [
                {"skill": "Complete your profile", "priority": "high", "reason": "Profile not found"}
            ],
            "message": "Complete your profile to get skill recommendations"
        }
    
    user_skills = [s.get('name', '').lower() for s in profile.get('skills', [])]
    
    job_skills = []
    for skill in job.get('required_skills', []):
        if isinstance(skill, dict):
            job_skills.append(skill.get('name', '').lower())
        elif isinstance(skill, str):
            job_skills.append(skill.lower())
    
    # Find missing skills
    missing_skills = []
    for skill in job_skills:
        if skill not in user_skills:
            # Check if skill is in market demand
            market_demand = await real_time_market_ai.predict_future_demand(skill, 6)
            missing_skills.append({
                "skill": skill,
                "priority": "high" if market_demand.get('growth_percentage', 0) > 20 else "medium",
                "market_growth": market_demand.get('growth_percentage', 0),
                "reason": "Required for this position" if market_demand.get('growth_percentage', 0) < 10 else "High demand in market"
            })
    
    # Sort by priority
    missing_skills.sort(key=lambda x: 0 if x['priority'] == 'high' else 1)
    
    return {
        "success": True,
        "job_title": job.get('post_name', ''),
        "recommended_skills": missing_skills[:10],
        "current_skills_count": len(user_skills),
        "required_skills_count": len(job_skills),
        "gap_count": len(missing_skills),
        "recommendations": [
            f"Learn {s['skill']} - {s['reason']}" for s in missing_skills[:5]
        ],
        "learning_resources": [
            {
                "skill": s['skill'],
                "resources": [
                    f"{s['skill'].title()} Course on Coursera",
                    f"{s['skill'].title()} Tutorial on YouTube"
                ]
            }
            for s in missing_skills[:3]
        ],
        "timestamp": datetime.utcnow().isoformat()
    }


@router.get("/health")
async def ai_health(current_user: dict = Depends(get_current_user)):
    """
    CHECK JOB AI SYSTEM HEALTH
    """
    return {
        "status": "healthy",
        "features": [
            "Job Match Scoring",
            "Batch Job Matching",
            "Description Parsing",
            "Salary Prediction",
            "Market Insights",
            "Skill Recommendations"
        ],
        "endpoints_available": [
            "/ai/match-score",
            "/ai/batch-match",
            "/ai/parse-description",
            "/ai/salary-prediction",
            "/ai/market-insights",
            "/ai/recommend-skill"
        ],
        "ready": True
    }


# ==================== HELPER FUNCTIONS ====================

async def _has_applied(job_id: str, email: str, db) -> bool:
    """Check if user has applied to a job"""
    app = await db.applications.find_one({
        "job_id": job_id,
        "applicant_email": email,
        "status": {"$ne": "saved"}
    })
    return app is not None

async def _is_saved(job_id: str, email: str, db) -> bool:
    """Check if user has saved a job"""
    app = await db.applications.find_one({
        "job_id": job_id,
        "applicant_email": email,
        "status": "saved"
    })
    return app is not None

async def _predict_salary(job: Dict) -> Dict:
    """Predict salary for a job"""
    job_title = job.get('post_name', '')
    
    base_salary = {
        'software engineer': 8,
        'data scientist': 10,
        'full stack developer': 9,
        'devops engineer': 9,
        'product manager': 12,
        'project manager': 10,
        'business analyst': 7,
        'marketing manager': 8,
        'sales manager': 8,
        'hr manager': 7,
        'finance manager': 9,
        'operations manager': 8,
        'customer support': 4,
        'administrative': 3,
        'others': 5
    }
    
    base = 5
    for key, value in base_salary.items():
        if key in job_title.lower():
            base = value
            break
    
    req_exp = job.get('experience_min_years', 0)
    exp_multiplier = min(3, 1 + (req_exp * 0.15))
    
    estimated = base * exp_multiplier
    
    return {
        "min_lpa": round(estimated * 0.85, 1),
        "max_lpa": round(estimated * 1.15, 1),
        "average_lpa": round(estimated, 1),
        "currency": "INR",
        "confidence": 75
    }


print("✅ Jobs AI Routes Loaded - Real-time Analysis & Matching")