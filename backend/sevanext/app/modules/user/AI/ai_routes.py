# app/modules/user/AI/ai_routes.py
"""
User AI Routes - Comprehensive Real-time Analysis
Accessed via /api/v1/user/ai/*
Fully updated for real-time data access and detailed profile analysis
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional, Dict, Any, List
from datetime import datetime, timedelta
import logging
import json

from app.core.services.dependencies import get_current_user
from app.db.connection import get_db
from app.core.ai.ultra_ai_engine import ultra_ai_engine
from app.core.ai.ultra_career_ai import ultra_career_ai
from app.core.ai.real_time_market_ai import real_time_market_ai
from app.models.ai_insights_model import AIInsightType

logger = logging.getLogger(__name__)

# Create AI router for user module
router = APIRouter(prefix="/ai", tags=["User AI Services"])


@router.get("/career-analysis")
async def user_career_analysis(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
    force_refresh: bool = Query(False, description="Force refresh AI analysis")
):
    """
    COMPREHENSIVE CAREER ANALYSIS
    - Full 360° user profiling
    - Real-time market data integration
    - Skill gap analysis with market demand
    - Personalized career recommendations
    - Growth projections
    - Uses unified ai_insights collection for caching
    """
    email = current_user.get("email")
    user_id = current_user.get("user_id")
    
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    # Check for cached analysis (7 days cache)
    if not force_refresh:
        cached = await db.ai_insights.find_one({
            "email": email,
            "type": AIInsightType.CAREER_ANALYSIS,
            "is_current": True,
            "created_at": {"$gte": datetime.utcnow() - timedelta(days=7)}
        })
        
        if cached and cached.get('data'):
            return {
                "success": True,
                "data": cached['data'],
                "cached": True,
                "analysis_id": str(cached["_id"]),
                "generated_at": cached["created_at"].isoformat(),
                "message": "Cached analysis retrieved"
            }
    
    # Get fresh profile
    profile = await db.profile.find_one({"email": email})
    
    if not profile:
        return _get_fallback_career_analysis({})
    
    try:
        # Get comprehensive analysis from UltraCareerAI
        analysis = await ultra_career_ai.comprehensive_user_analysis(user_id, email)
        
        # Get real-time market data for user's skills
        user_skills = [s.get('name', '') for s in profile.get('skills', [])]
        market_data = {}
        for skill in user_skills[:10]:
            market_data[skill] = await real_time_market_ai.predict_future_demand(skill, 6)
        
        # Add market insights to analysis
        analysis['real_time_market_insights'] = market_data
        
        # Store in unified collection
        from app.db.career_data_manager import career_data_manager
        await career_data_manager.save_career_analysis(email, user_id, analysis)
        
        return {
            "success": True,
            "data": analysis,
            "cached": False,
            "timestamp": datetime.utcnow().isoformat(),
            "message": "Fresh comprehensive analysis generated"
        }
        
    except Exception as e:
        logger.error(f"Career analysis error: {e}")
        return _get_fallback_career_analysis(profile)


@router.get("/job-recommendations")
async def user_job_recommendations(
    limit: int = Query(10, ge=1, le=50),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    AI-POWERED JOB RECOMMENDATIONS
    - Real-time job matching
    - Skill-based recommendations
    - Location-aware suggestions
    - Market demand integration
    """
    email = current_user.get("email")
    
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    profile = await db.profile.find_one({"email": email})
    
    if not profile:
        return {
            "success": True,
            "data": [],
            "message": "Complete your profile for job recommendations"
        }
    
    # Get user's location for nearby jobs
    user_location = None
    user = await db.auth.find_one({"email": email})
    if user and user.get("current_location"):
        loc = user["current_location"]
        user_location = {
            "latitude": loc.get("latitude"),
            "longitude": loc.get("longitude")
        }
    
    # Get jobs with filters
    query = {"status": "open"}
    user_skills = [s.get('name', '').lower() for s in profile.get('skills', [])]
    
    if user_skills:
        query["required_skills.name"] = {"$in": user_skills}
    
    jobs = await db.job.find(query).limit(limit * 2).to_list(limit * 2)
    
    if not jobs:
        # Fallback: get all open jobs
        jobs = await db.job.find({"status": "open"}).limit(limit).to_list(limit)
    
    # Enhance each job with match scores
    recommendations = []
    user_exp = len(profile.get('experience', []))
    user_edu = len(profile.get('academic_records', []))
    
    for job in jobs:
        job_skills = []
        for skill in job.get('required_skills', []):
            if isinstance(skill, dict):
                job_skills.append(skill.get('name', '').lower())
            elif isinstance(skill, str):
                job_skills.append(skill.lower())
        
        # Calculate match scores
        if job_skills and user_skills:
            matching_skills = set(user_skills) & set(job_skills)
            skill_match = (len(matching_skills) / len(job_skills)) * 100
        else:
            skill_match = 50
            matching_skills = set()
        
        req_exp = job.get('experience_min_years', 0)
        exp_match = min(100, (user_exp / max(1, req_exp)) * 100) if req_exp > 0 else 70
        
        # Calculate total match
        total_match = (skill_match * 0.6 + exp_match * 0.3 + min(100, user_edu * 10) * 0.1)
        
        # Calculate distance if location available
        distance_km = None
        if user_location and user_location.get("latitude"):
            job_loc = job.get("job_location", {})
            job_lat = job_loc.get("latitude")
            job_lon = job_loc.get("longitude")
            
            if job_lat and job_lon:
                from app.core.location.distance_calculator import DistanceCalculator
                dist_m = DistanceCalculator.calculate_distance(
                    user_location["latitude"],
                    user_location["longitude"],
                    job_lat,
                    job_lon
                )
                distance_km = round(dist_m / 1000, 2)
        
        recommendations.append({
            "job_id": str(job['_id']),
            "title": job.get('post_name', 'Job Opportunity'),
            "organization": job.get('organization', 'Company'),
            "location": job.get('location', 'India'),
            "job_type": job.get('job_type', 'private'),
            "match_score": round(total_match),
            "skill_match": round(skill_match),
            "experience_match": round(exp_match),
            "matching_skills": list(matching_skills)[:5],
            "missing_skills": list(set(job_skills) - set(user_skills))[:5] if job_skills else [],
            "distance_km": distance_km,
            "salary_range": _format_salary(job.get('salary_min'), job.get('salary_max')),
            "required_skills": job_skills[:5],
            "has_application_fees": job.get('has_application_fees', False),
            "application_fees": job.get('application_fees', {}),
            "post_date": job.get('post_date', ''),
            "last_date": job.get('last_date', ''),
            "description_preview": job.get('description', '')[:200] + '...' if job.get('description') else ''
        })
    
    # Sort by match score
    recommendations.sort(key=lambda x: x['match_score'], reverse=True)
    
    # Get personalized skill gap analysis
    skill_gap = await _analyze_skill_gap(user_skills, jobs)
    
    return {
        "success": True,
        "data": recommendations[:limit],
        "total": len(recommendations),
        "skill_gap_analysis": skill_gap,
        "user_summary": {
            "skills_count": len(user_skills),
            "experience_count": user_exp,
            "education_count": user_edu,
            "profile_completion": _calculate_completion(profile)
        },
        "message": f"Found {len(recommendations)} matching jobs"
    }


@router.get("/skill-gap-analysis")
async def user_skill_gap(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    DETAILED SKILL GAP ANALYSIS
    - Compare user skills with market demand
    - Identify missing high-demand skills
    - Priority learning recommendations
    - Estimated learning timeline
    """
    email = current_user.get("email")
    
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    profile = await db.profile.find_one({"email": email})
    
    if not profile:
        return {
            "success": True,
            "current_skills": [],
            "missing_skills": ["Complete your profile to see skill gaps"],
            "market_demand_skills": [],
            "improvement_priorities": ["Complete your profile", "Add education", "Add skills"],
            "recommended_courses": [],
            "estimated_learning_time": "3-6 months",
            "skill_score": 0
        }
    
    user_skills = [s.get('name', '').lower() for s in profile.get('skills', [])]
    
    # Get real-time market skills
    market_skills = await real_time_market_ai.get_hot_skills(30)
    market_skill_names = [s.get('skill', '').lower() for s in market_skills]
    
    # Get required skills from jobs
    jobs = await db.job.find({"status": "open"}).limit(100).to_list(100)
    job_skills = {}
    
    for job in jobs:
        for skill in job.get('required_skills', []):
            skill_name = skill.get('name', '').lower() if isinstance(skill, dict) else str(skill).lower()
            if skill_name:
                job_skills[skill_name] = job_skills.get(skill_name, 0) + 1
    
    # Sort by frequency
    sorted_job_skills = sorted(job_skills.items(), key=lambda x: x[1], reverse=True)
    
    # Identify missing skills
    missing_skills = []
    for skill, count in sorted_job_skills[:20]:
        if skill not in user_skills:
            missing_skills.append({
                "skill": skill,
                "demand_count": count,
                "priority": "high" if count > 10 else "medium" if count > 5 else "low"
            })
    
    # Get high-demand missing skills
    high_demand_missing = [s for s in missing_skills if s['priority'] == 'high']
    
    # Calculate skill score
    total_skill_count = len(set(job_skills.keys()))
    if total_skill_count > 0:
        skill_score = min(100, int((len(user_skills) / total_skill_count) * 100))
    else:
        skill_score = 0
    
    # Get market insights for missing skills
    skill_predictions = {}
    for skill in high_demand_missing[:10]:
        prediction = await real_time_market_ai.predict_future_demand(skill['skill'], 6)
        skill_predictions[skill['skill']] = prediction
    
    return {
        "success": True,
        "current_skills": [{"name": s, "level": "intermediate"} for s in user_skills[:20]],
        "current_skills_count": len(user_skills),
        "market_demand_skills": [{"skill": s, "count": c} for s, c in sorted_job_skills[:20]],
        "missing_skills": missing_skills[:15],
        "high_demand_missing": high_demand_missing[:10],
        "skill_predictions": skill_predictions,
        "improvement_priorities": [s['skill'] for s in high_demand_missing[:5]],
        "recommended_courses": _generate_course_recommendations(high_demand_missing[:5]),
        "estimated_learning_time": f"{len(high_demand_missing) * 4}-{len(high_demand_missing) * 8} weeks",
        "skill_score": skill_score,
        "market_alignment": min(100, int((len(set(user_skills) & set(market_skill_names)) / max(1, len(market_skill_names))) * 100)),
        "timestamp": datetime.utcnow().isoformat()
    }


@router.get("/profile-analysis")
async def user_profile_analysis(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
    include_market_data: bool = Query(True, description="Include real-time market data")
):
    """
    COMPLETE USER PROFILE ANALYSIS
    - All profile sections with scores
    - Career readiness assessment
    - Market alignment
    - Personalized improvement suggestions
    - Real-time data integration
    """
    email = current_user.get("email")
    
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    profile = await db.profile.find_one({"email": email})
    
    if not profile:
        return {
            "success": True,
            "profile_complete": False,
            "message": "Complete your profile for detailed analysis"
        }
    
    # Get user auth data for location
    user = await db.auth.find_one({"email": email})
    
    # Analyze all sections
    analysis = {
        "success": True,
        "profile_complete": True,
        "user_info": _analyze_user_info(profile, user),
        "education": _analyze_education(profile),
        "experience": _analyze_experience(profile),
        "skills": _analyze_skills(profile),
        "career": _analyze_career(profile),
        "completion_score": _calculate_completion(profile),
        "strengths": [],
        "weaknesses": [],
        "recommendations": []
    }
    
    # Add market data if requested
    if include_market_data and profile.get('skills'):
        user_skills = [s.get('name', '') for s in profile.get('skills', [])]
        market_insights = {}
        
        for skill in user_skills[:10]:
            market_insights[skill] = await real_time_market_ai.predict_future_demand(skill, 6)
        
        analysis['market_insights'] = market_insights
        
        # Add market alignment score
        hot_skills = await real_time_market_ai.get_hot_skills(20)
        hot_skill_names = [h.get('skill', '').lower() for h in hot_skills]
        user_skill_names = [s.lower() for s in user_skills]
        
        alignment = len(set(hot_skill_names) & set(user_skill_names))
        analysis['market_alignment_score'] = min(100, int((alignment / max(1, len(hot_skill_names))) * 100))
    
    # Generate strengths and weaknesses
    analysis['strengths'] = _get_strengths(analysis)
    analysis['weaknesses'] = _get_weaknesses(analysis)
    analysis['recommendations'] = _get_recommendations(analysis)
    
    return analysis


@router.get("/all-insights")
async def user_all_insights(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
    force_refresh: bool = Query(False, description="Refresh all data")
):
    """
    GET ALL AI INSIGHTS IN ONE REQUEST
    - Career analysis
    - Job recommendations
    - Skill gap analysis
    - Profile analysis
    - Market intelligence
    """
    email = current_user.get("email")
    
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    # Run all analyses in parallel
    import asyncio
    
    results = await asyncio.gather(
        user_career_analysis(current_user, db, force_refresh),
        user_job_recommendations(5, current_user, db),
        user_skill_gap(current_user, db),
        user_profile_analysis(current_user, db, True),
        _get_market_intelligence(current_user, db),
        return_exceptions=True
    )
    
    # Process results
    career_analysis = results[0] if not isinstance(results[0], Exception) else {"error": str(results[0])}
    job_recommendations = results[1] if not isinstance(results[1], Exception) else {"data": []}
    skill_gap = results[2] if not isinstance(results[2], Exception) else {}
    profile_analysis = results[3] if not isinstance(results[3], Exception) else {}
    market_intelligence = results[4] if not isinstance(results[4], Exception) else {}
    
    # Get profile data
    profile = await db.profile.find_one({"email": email})
    
    return {
        "success": True,
        "timestamp": datetime.utcnow().isoformat(),
        "career_analysis": career_analysis,
        "job_recommendations": job_recommendations,
        "skill_gap_analysis": skill_gap,
        "profile_analysis": profile_analysis,
        "market_intelligence": market_intelligence,
        "user_profile_summary": {
            "skills_count": len(profile.get('skills', [])) if profile else 0,
            "experience_count": len(profile.get('experience', [])) if profile else 0,
            "education_count": len(profile.get('academic_records', [])) if profile else 0,
            "profile_completion": _calculate_completion(profile) if profile else 0
        },
        "message": "All insights generated successfully"
    }


@router.post("/career-roadmap")
async def user_career_roadmap(
    target_career: str = Query(..., description="Target career role"),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    GENERATE CAREER ROADMAP
    - Step-by-step career path
    - Skill acquisition timeline
    - Salary progression
    - Milestones
    - Market demand integration
    """
    email = current_user.get("email")
    
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    profile = await db.profile.find_one({"email": email})
    user_skills = [s.get('name', '').lower() for s in profile.get('skills', [])] if profile else []
    
    # Get market demand for target career
    market_demand = await real_time_market_ai.predict_future_demand(target_career, 12)
    
    # Career path data with market integration
    career_path_data = await _get_career_path_data(target_career)
    
    # Calculate skill gaps
    required_skills = set(career_path_data.get('skills', []))
    missing_skills = required_skills - set(user_skills)
    
    # Generate milestones with realistic timelines
    milestones = []
    current_year = datetime.now().year
    
    for i, level in enumerate(["entry_level", "mid_level", "senior_level", "expert_level"]):
        role = career_path_data.get(level)
        if role:
            milestones.append({
                "milestone": f"Reach {role} position",
                "target_year": current_year + i * 2,
                "estimated_salary": career_path_data.get('salary_ranges', {}).get(level, '₹6-12 LPA'),
                "skills_needed": career_path_data.get('level_skills', {}).get(level, [])
            })
    
    return {
        "success": True,
        "target_career": target_career,
        "career_path": {
            "entry_level": career_path_data.get("entry_level"),
            "mid_level": career_path_data.get("mid_level"),
            "senior_level": career_path_data.get("senior_level"),
            "expert_level": career_path_data.get("expert_level"),
            "estimated_timeline": f"{len(missing_skills) * 3}-{len(missing_skills) * 6} months",
            "market_demand": market_demand.get('growth_percentage', 0)
        },
        "skills_to_acquire": [
            {
                "skill": skill,
                "priority": "high" if i < 3 else "medium" if i < 6 else "low",
                "estimated_time": "2-3 months" if i < 3 else "4-6 months",
                "learning_resources": _get_learning_resources(skill)
            }
            for i, skill in enumerate(missing_skills)
        ][:10],
        "certifications": career_path_data.get("certifications", []),
        "milestones": milestones,
        "salary_progression": career_path_data.get("salary_progression", []),
        "completion_percentage": round(((len(required_skills) - len(missing_skills)) / max(1, len(required_skills))) * 100),
        "market_demand_score": market_demand.get('current_demand', 50),
        "recommended_actions": [
            f"Learn {skill}" for skill in list(missing_skills)[:3]
        ] + ["Update your resume", "Network with professionals in the field"]
    }


@router.get("/refresh-cache")
async def refresh_ai_cache(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Clear all AI cache for the current user"""
    email = current_user.get("email")
    
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    # Mark all career analyses as not current
    result = await db.ai_insights.update_many(
        {"email": email, "type": AIInsightType.CAREER_ANALYSIS, "is_current": True},
        {"$set": {"is_current": False}}
    )
    
    return {
        "success": True,
        "cleared_count": result.modified_count,
        "message": "AI cache cleared. Fresh analysis will be generated on next request."
    }


@router.get("/health")
async def ai_health(
    db=Depends(get_db)
):
    """Check AI system health"""
    
    ai_insights_count = await db.ai_insights.count_documents({})
    
    return {
        "status": "healthy",
        "ai_engines": [
            "UltraCareerAI",
            "RealTimeMarketAI",
            "UltraAIEngine"
        ],
        "features": [
            "360° Career Analysis",
            "Real-time Job Matching",
            "Skill Gap Analysis",
            "Market Intelligence",
            "Personalized Learning",
            "Financial Projection",
            "Career Roadmap"
        ],
        "endpoints_available": [
            "/ai/career-analysis",
            "/ai/job-recommendations",
            "/ai/skill-gap-analysis",
            "/ai/profile-analysis",
            "/ai/all-insights",
            "/ai/career-roadmap",
            "/ai/refresh-cache"
        ],
        "unified_collection_stats": {
            "ai_insights_total": ai_insights_count
        },
        "ready": True
    }


# ==================== HELPER FUNCTIONS ====================

def _format_salary(min_sal, max_sal) -> str:
    if min_sal and max_sal:
        return f"₹{min_sal//100000}-{max_sal//100000} LPA"
    elif min_sal:
        return f"From ₹{min_sal//100000} LPA"
    elif max_sal:
        return f"Up to ₹{max_sal//100000} LPA"
    return "Salary not disclosed"

def _calculate_completion(profile: Dict) -> int:
    fields = ['full_name', 'email', 'phone', 'dob']
    filled = sum(1 for f in fields if profile.get(f))
    sections = ['academic_records', 'experience', 'skills']
    filled += sum(1 for s in sections if profile.get(s))
    total = len(fields) + len(sections)
    return min(100, int((filled / total) * 100)) if total > 0 else 0

def _get_fallback_career_analysis(profile: Dict) -> Dict:
    completion = _calculate_completion(profile)
    exp_years = len(profile.get('experience', []))
    skills_count = len(profile.get('skills', []))
    
    return {
        "success": True,
        "data": {
            "career_summary": {
                "current_level": "entry" if exp_years < 2 else "mid" if exp_years < 5 else "senior",
                "overall_score": max(30, min(80, completion)),
                "strengths": ["Profile created", "Ready to learn", "Active user"],
                "weaknesses": ["Complete your profile for better insights", "Add more skills"]
            },
            "overall_score": completion,
            "profile_completion_percentage": completion,
            "experience_years": exp_years,
            "skill_score": min(100, skills_count * 10),
            "education_score": min(100, len(profile.get('academic_records', [])) * 25),
            "growth_projection": {
                "next_6_months": min(100, completion + 15),
                "next_1_year": min(100, completion + 25),
                "next_3_years": min(100, completion + 45),
                "next_5_years": min(100, completion + 60)
            },
            "action_plan": {
                "next_steps": [
                    "Complete your profile information",
                    "Add your educational qualifications",
                    "List your professional skills",
                    "Add work experience if any",
                    "Explore job opportunities"
                ],
                "timeline": "1-3 months",
                "priority_actions": ["Complete profile", "Add skills"]
            },
            "ai_recommendations": {
                "personalized_message": "Complete your profile to unlock personalized career guidance!",
                "quick_wins": ["Add your education", "List your skills", "Complete your profile"],
                "resources": ["Job listings", "Career articles", "Skill courses"],
                "learning_platforms": ["Coursera", "Udemy", "LinkedIn Learning", "edX"]
            }
        },
        "cached": False,
        "message": "Analysis generated with available data"
    }

async def _analyze_skill_gap(user_skills: List[str], jobs: List[Dict]) -> Dict:
    job_skills = {}
    for job in jobs:
        for skill in job.get('required_skills', []):
            skill_name = skill.get('name', '').lower() if isinstance(skill, dict) else str(skill).lower()
            if skill_name:
                job_skills[skill_name] = job_skills.get(skill_name, 0) + 1
    
    sorted_skills = sorted(job_skills.items(), key=lambda x: x[1], reverse=True)
    
    missing = []
    for skill, count in sorted_skills[:10]:
        if skill not in user_skills:
            missing.append({"skill": skill, "demand_count": count})
    
    return {
        "missing_skills": missing,
        "total_market_skills": len(job_skills),
        "user_skills_count": len(user_skills)
    }

def _generate_course_recommendations(skills: List[Dict]) -> List[Dict]:
    courses = []
    for skill in skills[:5]:
        courses.append({
            "name": f"Complete {skill['skill'].title()} Course",
            "platform": "Coursera" if "data" in skill['skill'] else "Udemy",
            "duration": "4-6 weeks",
            "cost": "₹2,000-₹5,000",
            "priority": skill.get('priority', 'medium')
        })
    return courses

def _get_learning_resources(skill: str) -> List[Dict]:
    return [
        {"type": "course", "name": f"{skill.title()} Masterclass", "platform": "Udemy"},
        {"type": "course", "name": f"{skill.title()} Professional", "platform": "Coursera"},
        {"type": "practice", "name": f"{skill.title()} Practice Problems", "platform": "HackerRank"}
    ]

def _analyze_user_info(profile: Dict, user: Dict) -> Dict:
    return {
        "name": profile.get('full_name', ''),
        "email": profile.get('email', ''),
        "phone": profile.get('phone', '') or (user.get('mobile', '') if user else ''),
        "gender": profile.get('gender', ''),
        "category": profile.get('category', ''),
        "location": profile.get('current_address', {}).get('city', ''),
        "has_disability": profile.get('disability', {}).get('is_disabled', False),
        "profile_created": profile.get('created_at')
    }

def _analyze_education(profile: Dict) -> Dict:
    education = profile.get('academic_records', [])
    highest = education[0] if education else {}
    
    return {
        "highest_degree": highest.get('degree', ''),
        "highest_level": highest.get('level', ''),
        "institute": highest.get('institute', ''),
        "year_of_passing": highest.get('year_of_passing'),
        "total_records": len(education),
        "education_score": min(100, len(education) * 25)
    }

def _analyze_experience(profile: Dict) -> Dict:
    experience = profile.get('experience', [])
    total_years = len(experience)
    
    current = None
    for exp in experience:
        if not exp.get('end_date'):
            current = exp
            break
    
    return {
        "total_years": total_years,
        "total_companies": len(set(e.get('company', '') for e in experience)),
        "current_role": current.get('role', '') if current else '',
        "current_company": current.get('company', '') if current else '',
        "has_leadership": any('lead' in e.get('role', '').lower() or 'manage' in e.get('role', '').lower() for e in experience),
        "experience_score": min(100, total_years * 20)
    }

def _analyze_skills(profile: Dict) -> Dict:
    skills = profile.get('skills', [])
    
    levels = {'expert': 0, 'advanced': 0, 'intermediate': 0, 'beginner': 0}
    skill_names = []
    
    for skill in skills:
        level = skill.get('level', 'beginner')
        levels[level] = levels.get(level, 0) + 1
        skill_names.append(skill.get('name', ''))
    
    return {
        "total_skills": len(skills),
        "levels": levels,
        "skill_names": skill_names[:10],
        "top_skills": [s.get('name', '') for s in skills if s.get('level') in ['expert', 'advanced']][:5],
        "skill_score": min(100, len(skills) * 10)
    }

def _analyze_career(profile: Dict) -> Dict:
    return {
        "career_goals": profile.get('career_goals', []),
        "domain_interests": profile.get('domain_interests', []),
        "current_status": profile.get('current_status', ''),
        "is_fresher": profile.get('is_fresher', True),
        "is_educated": profile.get('is_educated', True),
        "actively_looking": profile.get('actively_looking_for_job', False)
    }

def _get_strengths(analysis: Dict) -> List[str]:
    strengths = []
    
    if analysis.get('skills', {}).get('total_skills', 0) >= 10:
        strengths.append("Strong skill portfolio with 10+ skills")
    elif analysis.get('skills', {}).get('total_skills', 0) >= 5:
        strengths.append("Good skill foundation")
    
    if analysis.get('experience', {}).get('total_years', 0) >= 3:
        strengths.append("Significant work experience")
    elif analysis.get('experience', {}).get('total_years', 0) >= 1:
        strengths.append("Relevant work experience")
    
    if analysis.get('education', {}).get('total_records', 0) >= 2:
        strengths.append("Strong educational background")
    
    if analysis.get('career', {}).get('career_goals'):
        strengths.append("Clear career goals defined")
    
    if not strengths:
        strengths.append("Ready to start career journey")
    
    return strengths[:3]

def _get_weaknesses(analysis: Dict) -> List[str]:
    weaknesses = []
    
    if analysis.get('skills', {}).get('total_skills', 0) < 5:
        weaknesses.append("Add more skills to improve profile")
    
    if analysis.get('experience', {}).get('total_years', 0) < 1:
        weaknesses.append("Gain practical experience")
    
    if analysis.get('education', {}).get('total_records', 0) < 1:
        weaknesses.append("Add educational qualifications")
    
    if not analysis.get('career', {}).get('career_goals'):
        weaknesses.append("Define career goals")
    
    if analysis.get('completion_score', 0) < 70:
        weaknesses.append("Complete your profile for better opportunities")
    
    return weaknesses[:3]

def _get_recommendations(analysis: Dict) -> List[str]:
    recommendations = []
    
    if analysis.get('skills', {}).get('total_skills', 0) < 5:
        recommendations.append("Add 5+ relevant skills to your profile")
    
    if analysis.get('experience', {}).get('total_years', 0) < 1:
        recommendations.append("Consider internships or entry-level positions")
    
    if not analysis.get('career', {}).get('career_goals'):
        recommendations.append("Set clear career goals")
    
    if analysis.get('skills', {}).get('levels', {}).get('expert', 0) < 2:
        recommendations.append("Focus on becoming expert in your strongest skill")
    
    if analysis.get('completion_score', 0) < 70:
        recommendations.append("Complete your profile for better job matching")
    
    if analysis.get('market_alignment_score', 0) < 50:
        recommendations.append("Learn skills that are in high demand in the market")
    
    return recommendations[:5]

async def _get_career_path_data(target_career: str) -> Dict:
    career_data = {
        "software engineer": {
            "entry_level": "Junior Developer",
            "mid_level": "Software Engineer",
            "senior_level": "Senior Software Engineer",
            "expert_level": "Tech Lead/Architect",
            "skills": ["Python", "JavaScript", "Data Structures", "System Design", "Databases"],
            "certifications": ["AWS Certified Developer", "System Design"],
            "salary_ranges": {
                "entry_level": "₹4-8 LPA",
                "mid_level": "₹8-15 LPA",
                "senior_level": "₹15-25 LPA",
                "expert_level": "₹25-40 LPA"
            },
            "salary_progression": [
                {"level": "Entry", "range": "₹4-8 LPA", "timeframe": "0-2 years"},
                {"level": "Mid", "range": "₹8-15 LPA", "timeframe": "2-5 years"},
                {"level": "Senior", "range": "₹15-25 LPA", "timeframe": "5-8 years"},
                {"level": "Expert", "range": "₹25-40 LPA", "timeframe": "8+ years"}
            ],
            "level_skills": {
                "entry_level": ["Python", "JavaScript", "Git"],
                "mid_level": ["System Design", "Database Design", "API Development"],
                "senior_level": ["Architecture", "Team Leadership", "Project Management"],
                "expert_level": ["Strategic Planning", "Technical Architecture", "Mentoring"]
            }
        },
        "data scientist": {
            "entry_level": "Junior Data Analyst",
            "mid_level": "Data Scientist",
            "senior_level": "Senior Data Scientist",
            "expert_level": "ML Engineer/Lead",
            "skills": ["Python", "SQL", "Statistics", "Machine Learning", "Data Visualization"],
            "certifications": ["Data Science Professional", "ML Certification"],
            "salary_ranges": {
                "entry_level": "₹5-10 LPA",
                "mid_level": "₹10-18 LPA",
                "senior_level": "₹18-28 LPA",
                "expert_level": "₹28-45 LPA"
            },
            "salary_progression": [
                {"level": "Entry", "range": "₹5-10 LPA", "timeframe": "0-2 years"},
                {"level": "Mid", "range": "₹10-18 LPA", "timeframe": "2-5 years"},
                {"level": "Senior", "range": "₹18-28 LPA", "timeframe": "5-8 years"},
                {"level": "Expert", "range": "₹28-45 LPA", "timeframe": "8+ years"}
            ],
            "level_skills": {
                "entry_level": ["Python", "SQL", "Statistics"],
                "mid_level": ["Machine Learning", "Data Visualization", "Feature Engineering"],
                "senior_level": ["Deep Learning", "NLP", "Big Data"],
                "expert_level": ["ML Architecture", "Research", "Strategy"]
            }
        },
        "full stack developer": {
            "entry_level": "Junior Full Stack",
            "mid_level": "Full Stack Developer",
            "senior_level": "Senior Full Stack",
            "expert_level": "Technical Lead",
            "skills": ["React", "Node.js", "MongoDB", "REST APIs", "Git"],
            "certifications": ["Full Stack Certification", "Cloud Certification"],
            "salary_ranges": {
                "entry_level": "₹4-8 LPA",
                "mid_level": "₹8-16 LPA",
                "senior_level": "₹16-26 LPA",
                "expert_level": "₹26-42 LPA"
            },
            "salary_progression": [
                {"level": "Entry", "range": "₹4-8 LPA", "timeframe": "0-2 years"},
                {"level": "Mid", "range": "₹8-16 LPA", "timeframe": "2-5 years"},
                {"level": "Senior", "range": "₹16-26 LPA", "timeframe": "5-8 years"},
                {"level": "Expert", "range": "₹26-42 LPA", "timeframe": "8+ years"}
            ],
            "level_skills": {
                "entry_level": ["React", "Node.js", "Git"],
                "mid_level": ["Database Design", "API Development", "Cloud"],
                "senior_level": ["Architecture", "DevOps", "Performance Optimization"],
                "expert_level": ["System Architecture", "Team Leadership", "Technical Strategy"]
            }
        }
    }
    
    # Find matching career path
    career_key = target_career.lower()
    for key, data in career_data.items():
        if key in career_key or career_key in key:
            return data
    
    # Default fallback
    return career_data["software engineer"]

async def _get_market_intelligence(current_user: dict, db) -> Dict:
    """Get market intelligence for the user"""
    email = current_user.get("email")
    
    if not email:
        return {}
    
    profile = await db.profile.find_one({"email": email})
    user_skills = [s.get('name', '') for s in profile.get('skills', [])] if profile else []
    
    # Get hot skills
    hot_skills = await real_time_market_ai.get_hot_skills(15)
    
    # Get emerging trends
    trends = await real_time_market_ai.get_emerging_trends()
    
    # Get live market data
    market_data = await real_time_market_ai.get_live_market_data()
    
    # Check user's skills against market demand
    user_skill_demand = {}
    for skill in user_skills[:10]:
        demand = await real_time_market_ai.predict_future_demand(skill, 6)
        user_skill_demand[skill] = demand
    
    return {
        "hot_skills": hot_skills[:10],
        "emerging_trends": trends[:3],
        "market_summary": {
            "total_live_jobs": market_data.get('total_live_jobs', 0),
            "market_health": market_data.get('market_health', {}),
            "top_employers": market_data.get('top_employers', [])[:5]
        },
        "user_skills_demand": user_skill_demand,
        "timestamp": datetime.utcnow().isoformat()
    }


@router.get("/real-time-analysis")
async def real_time_user_analysis(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    REAL-TIME USER ANALYSIS
    - Live profile analysis
    - Current market alignment
    - Immediate actionable insights
    - Real-time skill demand tracking
    """
    email = current_user.get("email")
    
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    profile = await db.profile.find_one({"email": email})
    
    if not profile:
        return {
            "success": True,
            "message": "Complete your profile for real-time analysis"
        }
    
    user_skills = [s.get('name', '') for s in profile.get('skills', [])]
    
    # Get real-time market data for user's skills
    skill_analysis = {}
    total_growth = 0
    
    for skill in user_skills[:10]:
        market_data = await real_time_market_ai.predict_future_demand(skill, 6)
        skill_analysis[skill] = market_data
        total_growth += market_data.get('growth_percentage', 0)
    
    # Get hot skills in market
    hot_skills = await real_time_market_ai.get_hot_skills(10)
    hot_skill_names = [h['skill'].lower() for h in hot_skills]
    
    # Find overlapping skills
    user_skill_names = [s.lower() for s in user_skills]
    overlapping = set(user_skill_names) & set(hot_skill_names)
    
    # Find missing hot skills
    missing_hot = set(hot_skill_names) - set(user_skill_names)
    
    avg_growth = total_growth / max(1, len(user_skills))
    
    return {
        "success": True,
        "real_time_analysis": {
            "skill_market_health": avg_growth,
            "hot_skills_match": {
                "matching": list(overlapping),
                "missing": list(missing_hot)[:5]
            },
            "skill_insights": skill_analysis,
            "market_opportunities": [
                f"Learn {skill} - {skill_analysis.get(skill, {}).get('growth_percentage', 0):.0f}% demand growth"
                for skill in list(missing_hot)[:5]
            ],
            "recommendations": [
                "Focus on high-demand skills",
                "Update your profile with new skills",
                "Apply to jobs matching your skills"
            ]
        },
        "timestamp": datetime.utcnow().isoformat()
    }

print("✅ User AI Routes Loaded - Real-time Data & Full Analysis")