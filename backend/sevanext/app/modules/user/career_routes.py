# app/modules/user/career_routes.py - WITH CACHING USING UNIFIED AI INSIGHTS
"""
Ultra-Advanced Career Guidance API Routes
World's most comprehensive career guidance system
Uses unified ai_insights collection for caching
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional, Dict, Any
from datetime import datetime, timedelta  # ✅ ADDED timedelta here
from app.core.services.dependencies import get_current_user
from app.db.connection import get_db
from app.core.ai.ultra_career_ai import ultra_career_ai
import logging

# Import AI Insight types for unified collection
from app.models.ai_insights_model import AIInsightType

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/comprehensive-analysis")
async def comprehensive_career_analysis(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
    force_refresh: bool = Query(False, description="Force refresh AI analysis (ignore cache)")
):
    """
    WORLD'S MOST ADVANCED CAREER ANALYSIS
    - 360° User Profiling
    - Multi-dimensional Career Path Prediction
    - 2, 5, 10 Year Projections
    - Financial ROI Analysis
    - Personalized Learning Plans
    - Uses unified ai_insights collection for caching
    """
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    user_id = current_user.get("user_id")
    
    # Check for existing cached analysis in unified ai_insights collection
    if not force_refresh:
        existing = await db.ai_insights.find_one({
            "email": email,
            "type": AIInsightType.CAREER_ANALYSIS,
            "is_current": True,
            "created_at": {"$gte": datetime.utcnow() - timedelta(days=7)}  # Cache valid for 7 days
        })
        
        if existing and existing.get('data'):
            return {
                "success": True,
                "data": existing['data'],
                "cached": True,
                "analysis_id": str(existing["_id"]),
                "generated_at": existing["created_at"].isoformat(),
                "message": "Cached analysis retrieved (use force_refresh=true to regenerate)"
            }
    
    # Get fresh analysis from AI
    analysis = await ultra_career_ai.comprehensive_user_analysis(user_id, email)
    
    # Store in unified ai_insights collection
    from app.db.career_data_manager import career_data_manager
    await career_data_manager.save_career_analysis(email, user_id, analysis)
    
    return {
        "success": True,
        "data": analysis,
        "cached": False,
        "timestamp": datetime.utcnow().isoformat(),
        "message": "Ultra-comprehensive career analysis generated and cached"
    }


@router.get("/career-paths/{time_horizon}")
async def get_career_paths(
    time_horizon: int,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Get detailed career paths with timeline predictions"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    if time_horizon < 1 or time_horizon > 20:
        raise HTTPException(status_code=400, detail="Time horizon must be between 1 and 20 years")
    
    profile = await db.profile.find_one({"email": email})
    if not profile:
        raise HTTPException(status_code=404, detail="Please complete your profile first")
    
    career_paths = await ultra_career_ai.predict_career_path(profile, time_horizon)
    
    return {
        "success": True,
        "time_horizon_years": time_horizon,
        "career_paths": career_paths,
        "message": f"Career paths projected for {time_horizon} years"
    }


@router.get("/skill-gap-detailed")
async def detailed_skill_gap_analysis(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Ultra-detailed skill gap analysis with learning recommendations"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    profile = await db.profile.find_one({"email": email})
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    skills_analysis = await ultra_career_ai.analyze_skills_experience(profile)
    
    return {
        "success": True,
        "analysis": skills_analysis,
        "message": "Detailed skill gap analysis completed"
    }


@router.get("/market-intelligence")
async def real_time_market_intelligence(
    career_field: Optional[str] = Query(None, description="Specific career field"),
    current_user: dict = Depends(get_current_user)
):
    """Real-time job market intelligence and trends"""
    
    intelligence = await ultra_career_ai.get_market_intelligence(career_field)
    
    return {
        "success": True,
        "data": intelligence,
        "timestamp": datetime.utcnow().isoformat(),
        "message": "Real-time market intelligence retrieved"
    }


@router.get("/learning-plan")
async def personalized_learning_plan(
    career_path_index: int = Query(0, ge=0, description="Which career path to optimize for"),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Generate ultra-personalized learning plan and store in unified collection"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    user_id = current_user.get("user_id")
    
    profile = await db.profile.find_one({"email": email})
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    # Get career paths first
    career_paths = await ultra_career_ai.predict_career_path(profile, 5)
    
    if not career_paths.get('recommended_path') and career_path_index >= len(career_paths.get('predicted_trajectories', [])):
        raise HTTPException(status_code=404, detail="Career path not found")
    
    selected_path = career_paths.get('recommended_path') or career_paths['predicted_trajectories'][career_path_index]
    
    # Generate learning plan
    learning_plan = await ultra_career_ai.generate_learning_plan(profile, selected_path)
    
    # Store learning plan in unified ai_insights collection
    from app.db.career_data_manager import career_data_manager
    await career_data_manager.save_learning_path(
        user_email=email,
        user_id=user_id,
        career_path_id=selected_path.get('title'),
        learning_plan=learning_plan
    )
    
    return {
        "success": True,
        "career_path": selected_path.get('title'),
        "learning_plan": learning_plan,
        "stored_in_cache": True,
        "message": "Personalized learning plan generated and cached"
    }


@router.get("/financial-projection")
async def career_financial_projection(
    career_path_index: int = Query(0, ge=0),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Detailed financial ROI analysis for career path"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    profile = await db.profile.find_one({"email": email})
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    # Get career paths
    career_paths = await ultra_career_ai.predict_career_path(profile, 10)
    
    if not career_paths.get('recommended_path') and career_path_index >= len(career_paths.get('predicted_trajectories', [])):
        raise HTTPException(status_code=404, detail="Career path not found")
    
    selected_path = career_paths.get('recommended_path') or career_paths['predicted_trajectories'][career_path_index]
    
    # Get financial impact
    financial = await ultra_career_ai.predict_financial_impact(selected_path, profile)
    
    return {
        "success": True,
        "career_path": selected_path.get('title'),
        "financial_analysis": financial,
        "message": "Financial projection completed"
    }


@router.get("/compare-careers")
async def compare_career_paths(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Compare multiple career paths side-by-side"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    profile = await db.profile.find_one({"email": email})
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    # Get all career paths
    career_paths = await ultra_career_ai.predict_career_path(profile, 10)
    
    comparison = []
    for path in career_paths.get('predicted_trajectories', []):
        comparison.append({
            "title": path.get('title'),
            "match_score": path.get('probability', 0),
            "roles": path.get('roles', [])[:3],
            "salary_progression": path.get('estimated_salaries', []),
            "investment_needed": path.get('investment_needed', 50000),
            "roi_estimate": "High" if path.get('probability', 0) > 70 else "Medium",
            "difficulty": path.get('transition_difficulty', 'medium'),
            "time_to_success": len(path.get('roles', [])) * 2
        })
    
    return {
        "success": True,
        "career_options": comparison,
        "total_options": len(comparison),
        "message": "Career paths comparison ready"
    }


@router.get("/education-specific")
async def education_specific_guidance(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Specialized guidance based on education level"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    profile = await db.profile.find_one({"email": email})
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    guidance = await ultra_career_ai.analyze_educational_background(profile)
    
    return {
        "success": True,
        "education_level": guidance.get('education_level'),
        "guidance": guidance,
        "message": "Education-specific career guidance prepared"
    }


@router.get("/quick-insights")
async def quick_career_insights(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Quick career insights for dashboard (uses cached data when available)"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    # Try to get cached analysis first
    cached = await db.ai_insights.find_one({
        "email": email,
        "type": AIInsightType.CAREER_ANALYSIS,
        "is_current": True
    })
    
    if cached and cached.get('data'):
        analysis = cached['data']
        is_cached = True
    else:
        # Get fresh analysis
        analysis = await ultra_career_ai.comprehensive_user_analysis(
            current_user.get("user_id"), 
            email
        )
        is_cached = False
    
    # Extract quick insights
    quick_insights = {
        "top_career_match": analysis.get('career_paths', [{}])[0].get('role', 'Not available'),
        "match_score": analysis.get('career_paths', [{}])[0].get('match_score', 0),
        "immediate_actions": analysis.get('personalized_recommendations', {}).get('immediate_actions', [])[:3],
        "skill_gaps_count": len(analysis.get('skill_gap_analysis', {}).get('critical_skills', [])),
        "growth_potential": analysis.get('career_paths', [{}])[0].get('growth_potential', 'medium'),
        "success_probability": analysis.get('career_paths', [{}])[0].get('success_probability', 50)
    }
    
    return {
        "success": True,
        "quick_insights": quick_insights,
        "from_cache": is_cached,
        "message": "Quick career insights ready"
    }


@router.get("/career-timeline")
async def get_career_timeline(
    years: int = Query(10, ge=1, le=20, description="Years to project"),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Get detailed career timeline with milestones"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    profile = await db.profile.find_one({"email": email})
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    # Get career path
    career_paths = await ultra_career_ai.predict_career_path(profile, years)
    selected_path = career_paths.get('recommended_path', {})
    
    # Generate timeline
    timeline = []
    current_year = datetime.now().year
    
    for i in range(0, years + 1, 2):  # Every 2 years
        year_data = {
            "year": current_year + i,
            "years_from_now": i,
            "milestone": selected_path.get('roles', [])[i//2] if i//2 < len(selected_path.get('roles', [])) else "Career Growth",
            "expected_salary": selected_path.get('estimated_salaries', [])[i//2] if i//2 < len(selected_path.get('estimated_salaries', [])) else "Increasing",
            "skills_to_develop": selected_path.get('required_skills', [])[:3] if i < 5 else [],
            "recommended_actions": [
                "Continuous learning",
                "Network building",
                "Skill enhancement"
            ]
        }
        timeline.append(year_data)
    
    return {
        "success": True,
        "timeline": timeline,
        "message": f"Career timeline for next {years} years"
    }


@router.get("/skill-recommendations")
async def get_skill_recommendations(
    category: Optional[str] = Query(None, description="technical/soft/leadership"),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Get personalized skill recommendations"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    profile = await db.profile.find_one({"email": email})
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    # Get skills analysis
    skills_analysis = await ultra_career_ai.analyze_skills_experience(profile)
    
    # Filter by category
    all_recommendations = skills_analysis.get('learning_recommendations', [])
    
    if category:
        category_keywords = {
            'technical': ['python', 'java', 'javascript', 'aws', 'docker', 'sql', 'api', 'react', 'node', 'flutter'],
            'soft': ['communication', 'leadership', 'teamwork', 'problem solving', 'time management', 'adaptability'],
            'leadership': ['management', 'strategy', 'decision making', 'mentoring', 'project management', 'planning']
        }
        
        keywords = category_keywords.get(category.lower(), [])
        filtered = [rec for rec in all_recommendations if any(keyword in rec.lower() for keyword in keywords)]
        recommendations = filtered if filtered else all_recommendations[:5]
    else:
        recommendations = all_recommendations
    
    return {
        "success": True,
        "category": category or "all",
        "recommendations": recommendations[:10],
        "total": len(recommendations),
        "message": f"Skill recommendations for {category or 'all'} categories"
    }


# ==================== CLEAR CACHE ENDPOINT ====================
@router.post("/clear-cache")
async def clear_career_cache(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Clear cached career analysis for current user"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    result = await db.ai_insights.update_many(
        {"email": email, "type": AIInsightType.CAREER_ANALYSIS, "is_current": True},
        {"$set": {"is_current": False}}
    )
    
    return {
        "success": True,
        "cleared_count": result.modified_count,
        "message": "Career cache cleared. Next analysis will generate fresh insights."
    }


# ==================== EXPORT HEALTH CHECK ====================
@router.get("/health")
async def career_ai_health(db=Depends(get_db)):
    """Check Career AI system health with unified collection stats"""
    
    # Get unified collection stats
    ai_insights_count = await db.ai_insights.count_documents({})
    
    return {
        "status": "healthy",
        "ai_engine": "UltraCareerAI",
        "features": [
            "360° Profiling",
            "Predictive Pathing",
            "Market Intelligence",
            "Learning Optimization",
            "Financial Analysis",
            "Multi-level Education Support",
            "Career Timeline",
            "Skill Recommendations",
            "Unified AI Insights Storage"
        ],
        "endpoints_available": [
            "/career/comprehensive-analysis",
            "/career/career-paths/{time_horizon}",
            "/career/skill-gap-detailed",
            "/career/market-intelligence",
            "/career/learning-plan",
            "/career/financial-projection",
            "/career/compare-careers",
            "/career/education-specific",
            "/career/quick-insights",
            "/career/career-timeline",
            "/career/skill-recommendations",
            "/career/clear-cache"
        ],
        "unified_collection_stats": {
            "ai_insights_total": ai_insights_count
        },
        "ready": True
    }


print("✅ Ultra Career Guidance Routes loaded - Using Unified AI Insights Collection!")