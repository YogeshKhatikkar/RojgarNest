# app/core/ultra_career_ai.py - FIXED (methods inside class)
"""
WORLD'S MOST ADVANCED AI CAREER GUIDANCE SYSTEM
Features: Multi-dimensional analysis, Predictive modeling, Personalized learning, 
Real-time market intelligence, Lifetime career planning
"""

import asyncio
import json
import numpy as np
from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime, timedelta
from dataclasses import dataclass, field
from collections import defaultdict
import logging
from openai import AsyncOpenAI
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
import pandas as pd

from app.core.config.settings import settings
from app.db.connection import get_db
from app.core.utils.logger import logger
from app.models.ai_insights_model import AIInsightType

logger = logging.getLogger(__name__)


@dataclass
class CareerPath:
    """Complete career path with predictions"""
    role: str
    industry: str
    match_score: float
    required_skills: List[str]
    missing_skills: List[str]
    salary_range: Dict[str, str]
    growth_rate: float
    demand_level: str
    education_path: List[Dict]
    certification_path: List[Dict]
    timeline: Dict[str, Any]
    risks: List[str]
    opportunities: List[str]
    success_probability: float


class UltraCareerAI:
    """
    Revolutionary AI Career Guidance System with:
    - 360° User Profiling
    - Predictive Career Pathing  
    - Real-time Labor Market Intelligence
    - Personalized Learning Optimization
    - Lifetime Earnings Prediction
    - Success Probability Modeling
    """
    
    def __init__(self):
        self.client = None
        self.redis_client = None
        self.career_models = {}
        self.market_intelligence = {}
        self.learning_optimizer = {}
        self._initialize()
    
    def _initialize(self):
        """Initialize all AI components"""
        if settings.OPENAI_API_KEY:
            self.client = AsyncOpenAI(
                api_key=settings.OPENAI_API_KEY,
                timeout=60.0,
                max_retries=5
            )
            logger.info("✅ Ultra Career AI - OpenAI initialized")
        
        # Initialize advanced ML models
        self._init_advanced_models()
    
    def _init_advanced_models(self):
        """Initialize advanced ML models for career prediction"""
        self.career_models = {
            'success_predictor': GradientBoostingRegressor(
                n_estimators=200, 
                learning_rate=0.05,
                max_depth=5,
                random_state=42
            ),
            'salary_predictor': RandomForestRegressor(
                n_estimators=150,
                max_depth=10,
                random_state=42
            ),
            'career_clustering': KMeans(n_clusters=20, random_state=42)
        }
        logger.info("✅ Advanced Career ML Models initialized")
    
    # ==================== 360° USER PROFILING ====================
    
    async def comprehensive_user_analysis(self, user_id: str, email: str) -> Dict:
        """
        Complete 360-degree user analysis combining:
        - Educational background
        - Work experience
        - Skills assessment
        - Personality traits
        - Interests & passions
        - Learning style
        - Career aspirations
        - Life circumstances
        """
        db = get_db()
        
        # Get complete user profile
        profile = await db.profile.find_one({"email": email})
        auth_user = await db.auth.find_one({"email": email})
        
        if not profile:
            return await self._create_minimal_profile(email, auth_user)
        
        # Extract all user dimensions
        user_profile = {
            "basic_info": {
                "name": profile.get("full_name", ""),
                "age": self._calculate_age(profile.get("dob")),
                "location": profile.get("current_address", {}).get("city", ""),
                "education_level": self._get_education_level(profile.get("academic_records", [])),
                "work_status": profile.get("current_status", "unknown")
            },
            "education": self._analyze_education_background(profile.get("academic_records", [])),
            "experience": self._analyze_work_experience(profile.get("experience", [])),
            "skills": self._analyze_skills(profile.get("skills", [])),
            "interests": profile.get("domain_interests", []),
            "career_goals": profile.get("career_goals", []),
            "personality": await self._infer_personality_traits(profile),
            "learning_style": await self._detect_learning_style(profile),
            "life_circumstances": {
                "flexibility": profile.get("open_to_relocate", False),
                "financial_pressure": profile.get("family_annual_income", "medium"),
                "family_support": "unknown",
                "geographic_constraints": profile.get("preferred_locations", [])
            }
        }
        
        # Generate comprehensive analysis
        analysis = await self._deep_career_analysis(user_profile)
        
        # Store for future learning
        await self._store_user_analysis(email, analysis)
        
        return analysis
    
    async def _deep_career_analysis(self, user_profile: Dict) -> Dict:
        """Perform deep AI analysis of user's career potential"""
        
        if not self.client:
            return self._fallback_career_analysis(user_profile)
        
        try:
            prompt = f"""You are the world's most advanced career AI. Perform an ultra-deep analysis:

USER PROFILE:
{json.dumps(user_profile, indent=2)}

Analyze and return EXACT JSON structure with:
{{
    "career_summary": {{
        "current_position": "Current career stage",
        "strengths": ["strength1", "strength2", "strength3", "strength4", "strength5"],
        "hidden_talents": ["talent1", "talent2", "talent3"],
        "unique_advantages": ["advantage1", "advantage2"],
        "areas_for_improvement": ["area1", "area2", "area3"]
    }},
    "career_paths": [
        {{
            "role": "Job title",
            "industry": "Industry sector",
            "match_score": 0-100,
            "short_term_2_years": {{
                "position": "Entry level role",
                "salary_range": "Range",
                "skills_needed": ["skill1", "skill2"],
                "probability": 0-100,
                "actions": ["action1", "action2", "action3"]
            }},
            "medium_term_5_years": {{
                "position": "Mid level role",
                "salary_range": "Range",
                "skills_needed": ["skill1", "skill2"],
                "probability": 0-100,
                "milestones": ["milestone1", "milestone2"]
            }},
            "long_term_10_years": {{
                "position": "Senior/Leadership role",
                "salary_range": "Range",
                "skills_needed": ["skill1", "skill2"],
                "probability": 0-100,
                "achievements": ["achievement1", "achievement2"]
            }},
            "lifetime_earnings": {{
                "total_20_years": "Amount",
                "peak_earnings": "Amount at peak",
                "retirement_corpus": "Estimated corpus"
            }},
            "growth_potential": "high/medium/low",
            "job_market_demand": {{
                "current_demand": "high/medium/low",
                "future_projection": "increasing/stable/declining",
                "growth_rate_percentage": 0-100
            }},
            "required_education": ["education1", "education2"],
            "recommended_certifications": ["cert1", "cert2", "cert3"],
            "time_to_achieve": "X years",
            "success_probability": 0-100,
            "risks": ["risk1", "risk2"],
            "opportunities": ["opp1", "opp2"]
        }}
    ],
    "alternative_careers": [
        {{
            "role": "Alternative role",
            "reason": "Why this fits",
            "match_score": 0-100,
            "transition_difficulty": "easy/medium/hard",
            "transition_time": "X months"
        }}
    ],
    "skill_gap_analysis": {{
        "critical_skills": ["skill1", "skill2", "skill3"],
        "nice_to_have": ["skill1", "skill2"],
        "learning_path": {{
            "immediate_next_steps": ["step1", "step2"],
            "recommended_courses": [
                {{
                    "name": "Course name",
                    "platform": "Platform",
                    "duration": "X weeks",
                    "cost": "Free/Paid",
                    "priority": "high/medium/low"
                }}
            ],
            "estimated_time": "X months",
            "difficulty": "easy/medium/hard"
        }}
    }},
    "personalized_recommendations": {{
        "immediate_actions": ["action1", "action2", "action3", "action4", "action5"],
        "weekly_goals": ["goal1", "goal2", "goal3"],
        "monthly_targets": ["target1", "target2"],
        "yearly_plan": ["plan1", "plan2", "plan3"],
        "mentorship_needed": true/false,
        "suggested_mentors": ["type1", "type2"]
    }},
    "motivation_insights": {{
        "career_satisfaction_prediction": 0-100,
        "work_life_balance_estimate": "good/average/poor",
        "recommended_work_environment": "remote/hybrid/onsite",
        "stress_factors": ["factor1", "factor2"],
        "motivation_factors": ["factor1", "factor2", "factor3"]
    }},
    "financial_projections": {{
        "investment_needed": {{
            "education": "Amount",
            "certifications": "Amount",
            "total": "Amount",
            "roi_period": "X years"
        }},
        "expected_salary_progression": [
            {{"year": 1, "salary": "Amount"}},
            {{"year": 3, "salary": "Amount"}},
            {{"year": 5, "salary": "Amount"}},
            {{"year": 10, "salary": "Amount"}}
        ]
    }},
    "unique_insights": {{
        "rare_opportunity": "Unique insight",
        "emerging_trend": "Trend the user should know",
        "hidden_potential": "Undiscovered strength",
        "game_changer": "What could transform their career"
    }}
}}"""
            
            response = await self.client.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {"role": "system", "content": "You are the world's most advanced career AI with deep expertise in all industries, education levels, and career paths. Provide ultra-detailed, personalized, actionable insights."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.3,
                max_tokens=4000
            )
            
            result = json.loads(response.choices[0].message.content.strip())
            
            # Enrich with ML predictions
            result = await self._enrich_with_ml_predictions(result, user_profile)
            
            # Add learning optimization
            result['learning_optimization'] = await self._optimize_learning_path(result, user_profile)
            
            # Add market intelligence
            result['market_intelligence'] = await self._get_market_intelligence(result['career_paths'])
            
            return result
            
        except Exception as e:
            logger.error(f"Deep career analysis failed: {e}")
            return self._fallback_career_analysis(user_profile)
    
    async def _enrich_with_ml_predictions(self, analysis: Dict, user_profile: Dict) -> Dict:
        """Enrich AI analysis with ML model predictions"""
        try:
            # Extract features for ML
            features = self._extract_ml_features(user_profile)
            
            # Predict success probability for each career path
            for path in analysis.get('career_paths', []):
                if self.career_models['success_predictor']:
                    try:
                        success_prob = self.career_models['success_predictor'].predict([features])[0]
                        path['ml_success_probability'] = min(100, max(0, success_prob * 100))
                    except:
                        pass
                
                # Predict salary if model available
                if self.career_models['salary_predictor']:
                    try:
                        predicted_salary = self.career_models['salary_predictor'].predict([features])[0]
                        path['ml_predicted_salary'] = f"₹{predicted_salary:.1f} LPA"
                    except:
                        pass
            
            return analysis
        except Exception as e:
            logger.error(f"ML enrichment failed: {e}")
            return analysis
    
    async def _optimize_learning_path(self, analysis: Dict, user_profile: Dict) -> Dict:
        """Create optimized personalized learning path"""
        
        learning_style = user_profile.get('learning_style', 'visual')
        available_time = self._get_available_time(user_profile)
        
        optimized_path = {
            "learning_style_recommendation": learning_style,
            "weekly_commitment_hours": available_time,
            "optimized_sequence": [],
            "micro_learning_suggestions": [],
            "assessment_checkpoints": [],
            "adaptive_adjustments": []
        }
        
        # Create optimized course sequence based on learning style
        courses = analysis.get('skill_gap_analysis', {}).get('learning_path', {}).get('recommended_courses', [])
        
        for i, course in enumerate(courses[:5]):
            optimized_path['optimized_sequence'].append({
                "order": i + 1,
                "course": course.get('name'),
                "platform": course.get('platform'),
                "estimated_weeks": course.get('duration', '4 weeks'),
                "daily_commitment_minutes": self._calculate_daily_commitment(available_time, len(courses))
            })
        
        # Add micro-learning suggestions
        optimized_path['micro_learning_suggestions'] = [
            "Daily 15-minute skill practice",
            "Weekly industry news review",
            "Bi-weekly project implementation",
            "Monthly portfolio update"
        ]
        
        # Add assessment checkpoints
        optimized_path['assessment_checkpoints'] = [
            {"week": 2, "assessment": "Basic skills test", "action": "Review fundamentals"},
            {"week": 6, "assessment": "Project submission", "action": "Build something practical"},
            {"week": 12, "assessment": "Mock interview", "action": "Practice with peers"}
        ]
        
        return optimized_path
    
    async def _get_market_intelligence(self, career_paths: List[Dict]) -> Dict:
        """Get real-time market intelligence for career paths"""
        try:
            # In production, integrate with real job market APIs
            return {
                "top_growing_industries": [
                    {"industry": "AI/ML", "growth_rate": 35, "jobs_added": 50000},
                    {"industry": "Green Energy", "growth_rate": 28, "jobs_added": 35000},
                    {"industry": "Healthcare Tech", "growth_rate": 25, "jobs_added": 40000}
                ],
                "salary_trends": {
                    "increasing": ["Tech", "Data Science", "Cybersecurity"],
                    "stable": ["Finance", "Marketing", "Operations"],
                    "declining": ["Traditional Manufacturing", "Data Entry"]
                },
                "remote_opportunities": {
                    "high_demand": ["Software Development", "Digital Marketing", "Content Creation"],
                    "medium_demand": ["Customer Support", "Sales", "HR"],
                    "low_demand": ["Healthcare", "Manufacturing", "Retail"]
                },
                "emerging_skills": [
                    {"skill": "AI Integration", "demand_growth": 250},
                    {"skill": "Sustainability", "demand_growth": 180},
                    {"skill": "Data Analysis", "demand_growth": 150}
                ]
            }
        except:
            return {}
    
    # ==================== EDUCATED & NON-EDUCATED SUPPORT ====================
    
    async def analyze_educational_background(self, profile: Dict) -> Dict:
        """Specialized analysis for all education levels"""
        
        education_records = profile.get('academic_records', [])
        education_level = self._get_education_level(education_records)
        
        if education_level == 'no_formal':
            return await self._analyze_informal_education(profile)
        elif education_level == 'basic':
            return await self._analyze_basic_education(profile)
        elif education_level == 'intermediate':
            return await self._analyze_intermediate_education(profile)
        elif education_level == 'advanced':
            return await self._analyze_advanced_education(profile)
        else:
            return await self._analyze_professional_education(profile)
    
    async def _analyze_informal_education(self, profile: Dict) -> Dict:
        """Special analysis for users with informal/no formal education"""
        
        # Extract practical skills and experience
        practical_skills = profile.get('skills', [])
        work_experience = profile.get('experience', [])
        self_taught = profile.get('self_taught_skills', [])
        
        return {
            "education_level": "informal",
            "strengths": {
                "practical_experience": len(work_experience) > 0,
                "hands_on_skills": len(practical_skills) > 0,
                "learning_ability": "Proven through self-learning" if self_taught else "Potential to learn"
            },
            "recommended_paths": [
                {
                    "type": "vocational_training",
                    "roles": ["Electrician", "Plumber", "Carpenter", "Mechanic"],
                    "duration": "6-12 months",
                    "earning_potential": "₹15k-₹40k/month",
                    "growth_path": "Master craftsman → Supervisor → Business owner"
                },
                {
                    "type": "skill_based_employment",
                    "roles": ["Delivery Partner", "Security Guard", "Housekeeping", "Driver"],
                    "duration": "1-3 months training",
                    "earning_potential": "₹12k-₹25k/month",
                    "growth_path": "Entry → Senior → Team Lead"
                },
                {
                    "type": "entrepreneurship",
                    "roles": ["Small Business", "Service Provider", "Local Shop"],
                    "duration": "3-6 months preparation",
                    "earning_potential": "₹20k-₹50k/month",
                    "growth_path": "Start → Expand → Scale"
                }
            ],
            "upskill_opportunities": {
                "literacy_programs": "Improve reading/writing",
                "digital_literacy": "Basic computer skills",
                "financial_literacy": "Money management",
                "government_schemes": ["PMKVY", "DDUGKY", "NABARD"]
            },
            "success_stories": "Many successful entrepreneurs and skilled professionals started with practical experience"
        }
    
    async def _analyze_basic_education(self, profile: Dict) -> Dict:
        """Analysis for users with basic education (up to 10th/12th)"""
        
        return {
            "education_level": "basic",
            "opportunities": [
                {
                    "category": "Government Jobs",
                    "examples": ["Police Constable", "Forest Guard", "Patwari", "Clerk"],
                    "preparation": "6-12 months",
                    "salary_range": "₹25k-₹45k/month",
                    "stability": "High"
                },
                {
                    "category": "Diploma Courses",
                    "examples": ["Engineering Diploma", "Nursing", "Computer Applications"],
                    "duration": "2-3 years",
                    "salary_range": "₹20k-₹50k/month",
                    "career_progression": "Technician → Supervisor → Manager"
                },
                {
                    "category": "Skill Development",
                    "examples": ["Digital Marketing", "Web Design", "Data Entry", "Accounting"],
                    "duration": "3-6 months",
                    "salary_range": "₹15k-₹35k/month",
                    "remote_possible": True
                }
            ],
            "education_pathways": {
                "distance_learning": "Complete 12th through NIOS",
                "vocational_training": "ITI courses (2 years)",
                "certification_programs": "Short-term certifications in high-demand skills"
            },
            "recommended_first_step": "Complete 12th education while learning a vocational skill"
        }
    
    # ==================== SKILLS & EXPERIENCE ANALYSIS ====================
    
    async def analyze_skills_experience(self, profile: Dict) -> Dict:
        """Advanced skills and experience analysis"""
        
        skills = profile.get('skills', [])
        experience = profile.get('experience', [])
        certifications = profile.get('certifications', [])
        projects = profile.get('projects', [])
        
        # Calculate skill scores
        skill_categories = self._categorize_skills(skills)
        skill_levels = self._assess_skill_levels(skills)
        market_demand = await self._check_skill_demand(skill_categories)
        
        # Experience analysis
        experience_years = sum([self._calculate_exp_years(exp) for exp in experience])
        experience_quality = self._assess_experience_quality(experience)
        
        # Certification impact
        certification_value = self._calculate_certification_value(certifications)
        
        return {
            "skills_analysis": {
                "total_skills": len(skills),
                "skill_categories": skill_categories,
                "expert_skills": skill_levels['expert'],
                "intermediate_skills": skill_levels['intermediate'],
                "beginner_skills": skill_levels['beginner'],
                "market_demand_alignment": market_demand['alignment_score'],
                "high_demand_skills": market_demand['high_demand'],
                "missing_high_demand": market_demand['missing']
            },
            "experience_analysis": {
                "total_years": experience_years,
                "quality_score": experience_quality['score'],
                "industry_exposure": experience_quality['industries'],
                "role_progression": experience_quality['progression'],
                "leadership_indicators": experience_quality['leadership']
            },
            "certification_impact": {
                "value_score": certification_value['score'],
                "roi_estimate": certification_value['roi'],
                "recommended_next": certification_value['recommendations']
            },
            "project_portfolio": {
                "total_projects": len(projects),
                "complexity_score": self._assess_project_complexity(projects),
                "impact_areas": self._extract_project_impact(projects)
            },
            "skill_gap_analysis": await self._detailed_skill_gap_analysis(skills, market_demand['high_demand']),
            "learning_recommendations": await self._personalized_learning_recommendations(
                skill_levels, market_demand, experience_years
            )
        }
    
    # ==================== PERSONALIZED CAREER PATH PREDICTION ====================
    
    async def predict_career_path(self, user_profile: Dict, time_horizon: int = 10) -> Dict:
        """
        Predict detailed career path for X years with probabilities
        """
        
        current_role = user_profile.get('current_role', 'entry_level')
        skills = user_profile.get('skills', [])
        experience = user_profile.get('experience', [])
        education = user_profile.get('education', [])
        
        # Generate possible trajectories
        trajectories = await self._generate_career_trajectories(
            current_role, skills, experience, education
        )
        
        # Calculate probabilities for each trajectory
        for trajectory in trajectories:
            trajectory['probability'] = await self._calculate_trajectory_probability(
                trajectory, user_profile
            )
            trajectory['timeline'] = self._generate_timeline(trajectory, time_horizon)
            trajectory['skill_evolution'] = self._predict_skill_evolution(
                skills, trajectory, time_horizon
            )
        
        # Select best trajectories
        best_trajectories = sorted(trajectories, key=lambda x: x['probability'], reverse=True)[:3]
        
        return {
            "current_status": {
                "role": current_role,
                "level": self._determine_career_level(experience),
                "readiness_score": self._calculate_readiness_score(skills, experience)
            },
            "predicted_trajectories": best_trajectories,
            "recommended_path": best_trajectories[0] if best_trajectories else None,
            "alternative_paths": best_trajectories[1:],
            "key_milestones": self._identify_career_milestones(best_trajectories[0] if best_trajectories else {}),
            "risk_assessment": await self._assess_career_risks(user_profile, best_trajectories),
            "opportunity_analysis": await self._analyze_future_opportunities(best_trajectories)
        }
    
    async def _generate_career_trajectories(self, current_role: str, skills: List, 
                                            experience: List, education: List) -> List:
        """Generate possible career trajectories using AI"""
        
        if not self.client:
            return self._fallback_trajectories()
        
        try:
            prompt = f"""Generate 5 possible career trajectories for:

Current Role: {current_role}
Skills: {[s.get('name') for s in skills[:10]]}
Experience: {len(experience)} years
Education: {education}

Return JSON array of trajectories with:
{{
    "title": "Path title",
    "roles": ["Role1", "Role2", "Role3", "Role4"],
    "years": [0, 2, 5, 8],
    "estimated_salaries": ["Amount", "Amount", "Amount", "Amount"],
    "required_skills": ["skill1", "skill2"],
    "required_certifications": ["cert1", "cert2"],
    "transition_difficulty": "easy/medium/hard"
}}"""
            
            response = await self.client.chat.completions.create(
                model="gpt-4o",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.4,
                max_tokens=1500
            )
            
            return json.loads(response.choices[0].message.content.strip())
        except:
            return self._fallback_trajectories()
    
    # ==================== FINANCIAL & ROI PREDICTION ====================
    
    async def predict_financial_impact(self, career_path: Dict, user_profile: Dict) -> Dict:
        """
        Predict financial impact of following a career path
        """
        
        current_salary = user_profile.get('current_salary', 0)
        investment_needed = career_path.get('investment_needed', 0)
        
        salary_progression = career_path.get('salary_progression', [])
        
        # Calculate ROI
        total_earnings_increase = sum(salary_progression) - (current_salary * len(salary_progression))
        roi_percentage = (total_earnings_increase / investment_needed) * 100 if investment_needed > 0 else 0
        
        # Calculate break-even point
        monthly_increase = (salary_progression[0] - current_salary) if salary_progression else 0
        break_even_months = investment_needed / monthly_increase if monthly_increase > 0 else 999
        
        return {
            "investment_required": {
                "education": investment_needed * 0.6,
                "certifications": investment_needed * 0.3,
                "other_costs": investment_needed * 0.1,
                "total": investment_needed
            },
            "expected_returns": {
                "5_year_total": sum(salary_progression[:5]),
                "10_year_total": sum(salary_progression[:10]) if len(salary_progression) > 10 else sum(salary_progression),
                "lifetime_value": sum(salary_progression) * 2  # Simplified
            },
            "roi_analysis": {
                "roi_percentage": roi_percentage,
                "break_even_months": break_even_months,
                "net_gain": total_earnings_increase - investment_needed,
                "risk_adjusted_return": roi_percentage * 0.8  # Risk adjustment
            },
            "financial_milestones": [
                {"year": 1, "milestone": "Recoup investment", "target": break_even_months <= 12},
                {"year": 3, "milestone": "Double investment", "target": total_earnings_increase >= investment_needed * 2},
                {"year": 5, "milestone": "Financial independence progress", "target": "On track"}
            ],
            "recommendations": self._generate_financial_recommendations(roi_percentage, break_even_months)
        }
    
    # ==================== REAL-TIME MARKET INTELLIGENCE ====================
    
    async def get_market_intelligence(self, career_field: str = None) -> Dict:
        """Get real-time market intelligence"""
        
        # In production, integrate with:
        # - LinkedIn API
        # - Indeed API
        # - Government labor data
        # - Industry reports
        
        return {
            "job_market_summary": {
                "overall_health": "growing",
                "growth_rate": 8.5,
                "top_hiring_sectors": ["Technology", "Healthcare", "Green Energy", "E-commerce"],
                "remote_trend": "increasing",
                "salary_trend": "+12% year-over-year"
            },
            "in_demand_skills": {
                "technical": [
                    {"skill": "AI/ML", "growth": 45, "premium": 35},
                    {"skill": "Cloud Computing", "growth": 38, "premium": 30},
                    {"skill": "Data Science", "growth": 32, "premium": 28}
                ],
                "soft_skills": [
                    {"skill": "Communication", "growth": 25, "premium": 15},
                    {"skill": "Leadership", "growth": 22, "premium": 20},
                    {"skill": "Adaptability", "growth": 30, "premium": 18}
                ]
            },
            "emerging_roles": [
                {"role": "AI Ethics Officer", "growth": 280, "avg_salary": "₹25-40 LPA"},
                {"role": "Sustainability Manager", "growth": 190, "avg_salary": "₹18-30 LPA"},
                {"role": "Data Privacy Officer", "growth": 165, "avg_salary": "₹20-35 LPA"}
            ],
            "location_insights": {
                "india_hubs": [
                    {"city": "Bangalore", "tech_growth": 22, "avg_salary": "₹15-25 LPA"},
                    {"city": "Hyderabad", "tech_growth": 18, "avg_salary": "₹12-22 LPA"},
                    {"city": "Pune", "tech_growth": 16, "avg_salary": "₹10-20 LPA"}
                ],
                "remote_hotspots": ["Work from Anywhere", "Hybrid Models", "Distributed Teams"]
            },
            "future_outlook": {
                "next_2_years": "Strong growth in digital skills",
                "next_5_years": "AI augmentation of jobs",
                "next_10_years": "New job categories emerging"
            }
        }
    
    # ==================== PERSONALIZED LEARNING PLATFORM ====================
    
    async def generate_learning_plan(self, user_profile: Dict, career_path: Dict) -> Dict:
        """
        Generate ultra-personalized learning plan
        """
        
        skill_gaps = career_path.get('required_skills', [])
        current_skills = [s.get('name') for s in user_profile.get('skills', [])]
        missing_skills = [s for s in skill_gaps if s not in current_skills]
        
        learning_style = user_profile.get('learning_style', 'mixed')
        available_time = self._get_available_time(user_profile)
        
        # Create weekly schedule
        weekly_schedule = self._create_weekly_schedule(
            missing_skills, learning_style, available_time
        )
        
        # Find resources
        resources = await self._find_learning_resources(missing_skills)
        
        return {
            "learning_plan_summary": {
                "total_duration_weeks": len(missing_skills) * 4,
                "skills_to_learn": len(missing_skills),
                "estimated_hours": len(missing_skills) * 40,
                "difficulty_level": "intermediate" if len(missing_skills) > 5 else "beginner"
            },
            "weekly_schedule": weekly_schedule,
            "resources": resources,
            "assessment_plan": {
                "weekly_quizzes": True,
                "project_submissions": ["Portfolio project", "Case study"],
                "peer_reviews": True,
                "final_assessment": "Capstone project"
            },
            "motivation_strategy": {
                "daily_reminders": True,
                "progress_tracking": True,
                "reward_milestones": ["Complete 25%", "Complete 50%", "Complete 75%", "Complete 100%"],
                "community_support": "Join study groups"
            },
            "success_metrics": {
                "skill_mastery_target": 85,
                "project_completion_target": 100,
                "certification_target": "Relevant certifications"
            }
        }
    
    # ==================== UTILITY METHODS ====================
    
    def _calculate_age(self, dob: Optional[str]) -> int:
        if not dob:
            return 25
        try:
            birth = datetime.strptime(dob, "%Y-%m-%d")
            age = datetime.now().year - birth.year
            return age
        except:
            return 25
    
    def _get_education_level(self, education_records: List) -> str:
        if not education_records:
            return 'no_formal'
        
        highest_level = 0
        level_map = {
            'phd': 8, 'post_graduation': 7, 'graduation': 6,
            'diploma': 5, '12th': 4, '10th': 3, 'basic': 2
        }
        
        for edu in education_records:
            level = edu.get('level', '').lower()
            for key, value in level_map.items():
                if key in level:
                    highest_level = max(highest_level, value)
        
        if highest_level >= 7: return 'advanced'
        if highest_level >= 5: return 'intermediate'
        if highest_level >= 3: return 'basic'
        return 'no_formal'
    
    def _analyze_education_background(self, education_records: List) -> Dict:
        """Analyze education background in detail"""
        if not education_records:
            return {"level": "no_formal", "stream": "none", "percentage": 0}
        
        highest = education_records[0] if education_records else {}
        return {
            "level": highest.get('level', 'unknown'),
            "degree": highest.get('degree', ''),
            "stream": highest.get('stream', ''),
            "percentage": highest.get('cgpa_percentage', 0),
            "year_of_passing": highest.get('year_of_passing'),
            "institution": highest.get('institute', '')
        }
    
    def _analyze_work_experience(self, experience: List) -> Dict:
        """Analyze work experience"""
        if not experience:
            return {"total_years": 0, "industries": [], "roles": []}
        
        industries = list(set([exp.get('company', '') for exp in experience]))
        roles = [exp.get('role', '') for exp in experience]
        
        return {
            "total_years": len(experience),
            "industries": industries[:5],
            "roles": roles[:5],
            "has_leadership": any('lead' in role.lower() or 'manage' in role.lower() for role in roles)
        }
    
    def _analyze_skills(self, skills: List) -> Dict:
        """Analyze skills"""
        skill_names = [s.get('name', '') for s in skills]
        skill_levels = [s.get('level', 'beginner') for s in skills]
        
        return {
            "total": len(skills),
            "names": skill_names[:10],
            "expert_count": sum(1 for l in skill_levels if l == 'expert'),
            "advanced_count": sum(1 for l in skill_levels if l == 'advanced'),
            "intermediate_count": sum(1 for l in skill_levels if l == 'intermediate'),
            "beginner_count": sum(1 for l in skill_levels if l == 'beginner')
        }
    
    async def _infer_personality_traits(self, profile: Dict) -> Dict:
        """Infer personality from profile data"""
        # Simplified inference
        return {
            "openness": "medium",
            "conscientiousness": "high" if profile.get('projects') else "medium",
            "extraversion": "medium",
            "agreeableness": "high",
            "neuroticism": "low"
        }
    
    async def _detect_learning_style(self, profile: Dict) -> str:
        """Detect learning style from profile"""
        # Simplified detection
        if profile.get('skills') and len(profile.get('skills', [])) > 10:
            return "visual"
        elif profile.get('projects'):
            return "kinesthetic"
        else:
            return "mixed"
    
    def _get_available_time(self, profile: Dict) -> int:
        """Estimate available learning time per week"""
        # Simplified estimation
        return 15  # hours per week
    
    def _categorize_skills(self, skills: List) -> Dict:
        """Categorize skills by domain"""
        categories = defaultdict(list)
        for skill in skills:
            name = skill.get('name', '').lower()
            if any(tech in name for tech in ['python', 'java', 'javascript', 'react']):
                categories['technical'].append(name)
            elif any(soft in name for soft in ['communication', 'leadership', 'teamwork']):
                categories['soft'].append(name)
            else:
                categories['other'].append(name)
        return dict(categories)
    
    def _assess_skill_levels(self, skills: List) -> Dict:
        """Assess skill proficiency levels"""
        levels = {'expert': [], 'advanced': [], 'intermediate': [], 'beginner': []}
        for skill in skills:
            level = skill.get('level', 'beginner')
            if level in levels:
                levels[level].append(skill.get('name'))
        return levels
    
    async def _check_skill_demand(self, skill_categories: Dict) -> Dict:
        """Check market demand for skills"""
        # Simplified demand check
        high_demand = ['python', 'javascript', 'react', 'node', 'aws', 'docker']
        
        user_skills = []
        for skills in skill_categories.values():
            user_skills.extend(skills)
        
        user_skills_lower = [s.lower() for s in user_skills]
        matching_demand = [s for s in high_demand if s in user_skills_lower]
        missing_demand = [s for s in high_demand if s not in user_skills_lower]
        
        return {
            'alignment_score': (len(matching_demand) / len(high_demand)) * 100 if high_demand else 50,
            'high_demand': matching_demand,
            'missing': missing_demand
        }
    
    def _assess_experience_quality(self, experience: List) -> Dict:
        """Assess quality of experience"""
        score = min(100, len(experience) * 20)
        return {
            'score': score,
            'industries': list(set([exp.get('company', '') for exp in experience])),
            'progression': 'good' if len(experience) > 2 else 'basic',
            'leadership': any('lead' in exp.get('role', '').lower() for exp in experience)
        }
    
    def _calculate_certification_value(self, certifications: List) -> Dict:
        """Calculate certification value"""
        score = min(100, len(certifications) * 15)
        return {
            'score': score,
            'roi': 'high' if score > 60 else 'medium',
            'recommendations': ['Industry certifications'] if score < 50 else []
        }
    
    def _assess_project_complexity(self, projects: List) -> int:
        """Assess project complexity"""
        return min(100, len(projects) * 10)
    
    def _extract_project_impact(self, projects: List) -> List:
        """Extract project impact areas"""
        return [p.get('title', '') for p in projects[:3]]
    
    async def _detailed_skill_gap_analysis(self, skills: List, demand_skills: List) -> Dict:
        """Detailed skill gap analysis"""
        current_skills = [s.get('name', '').lower() for s in skills]
        
        return {
            "current_skills": current_skills[:10],
            "missing_critical": [s for s in demand_skills if s not in current_skills][:5],
            "gap_severity": "high" if len(demand_skills) > 5 else "medium",
            "estimated_fill_time": f"{len([s for s in demand_skills if s not in current_skills]) * 4} weeks"
        }
    
    async def _personalized_learning_recommendations(self, skill_levels: Dict, 
                                                    market_demand: Dict, experience_years: int) -> List:
        """Personalized learning recommendations"""
        recommendations = []
        
        if len(skill_levels['expert']) < 2:
            recommendations.append("Focus on becoming expert in your strongest skill")
        
        if market_demand['missing']:
            recommendations.append(f"Learn {', '.join(market_demand['missing'][:3])} - high market demand")
        
        if experience_years < 2:
            recommendations.append("Build practical projects to gain experience")
        
        return recommendations[:5]
    
    def _determine_career_level(self, experience: List) -> str:
        """Determine career level based on experience"""
        years = len(experience)
        if years >= 10: return 'expert'
        if years >= 5: return 'senior'
        if years >= 2: return 'mid'
        return 'entry'
    
    def _calculate_readiness_score(self, skills: List, experience: List) -> int:
        """Calculate career readiness score"""
        skill_score = min(50, len(skills) * 5)
        exp_score = min(50, len(experience) * 10)
        return skill_score + exp_score
    
    def _identify_career_milestones(self, trajectory: Dict) -> List:
        """Identify career milestones"""
        if not trajectory:
            return []
        
        return [
            {"year": 1, "goal": "Complete necessary certifications"},
            {"year": 2, "goal": f"Reach {trajectory.get('roles', [''])[1] if len(trajectory.get('roles', [])) > 1 else 'next level'}"},
            {"year": 3, "goal": "Build strong professional network"},
            {"year": 5, "goal": f"Target {trajectory.get('roles', [''])[2] if len(trajectory.get('roles', [])) > 2 else 'leadership role'}"}
        ]
    
    async def _assess_career_risks(self, user_profile: Dict, trajectories: List) -> Dict:
        """Assess career risks"""
        return {
            "market_risks": ["Automation", "Industry changes"],
            "personal_risks": ["Skill obsolescence", "Career stagnation"],
            "mitigation_strategies": ["Continuous learning", "Networking", "Diversify skills"],
            "risk_score": 30  # 0-100, lower is better
        }
    
    async def _analyze_future_opportunities(self, trajectories: List) -> Dict:
        """Analyze future opportunities"""
        return {
            "immediate_opportunities": ["Skill enhancement", "Networking events"],
            "future_trends": ["AI integration", "Remote work"],
            "growth_sectors": ["Technology", "Healthcare", "Green Energy"]
        }
    
    def _calculate_exp_years(self, experience: Dict) -> int:
        """Calculate years from experience entry"""
        # Simplified calculation
        return 1 if experience.get('start_date') else 0
    
    def _generate_timeline(self, trajectory: Dict, years: int) -> List:
        """Generate career timeline"""
        timeline = []
        roles = trajectory.get('roles', [])
        
        for i in range(min(years, len(roles))):
            timeline.append({
                "year": i + 1,
                "role": roles[i] if i < len(roles) else roles[-1],
                "salary": trajectory.get('estimated_salaries', [])[i] if i < len(trajectory.get('estimated_salaries', [])) else "₹0",
                "milestone": f"Complete {i+1} years in field"
            })
        
        return timeline
    
    def _predict_skill_evolution(self, current_skills: List, trajectory: Dict, years: int) -> Dict:
        """Predict skill evolution over time"""
        return {
            "skills_to_acquire": trajectory.get('required_skills', [])[:5],
            "mastery_timeline": {
                "year1": "Basic proficiency",
                "year3": "Working proficiency",
                "year5": "Advanced expertise"
            }
        }
    
    def _fallback_trajectories(self) -> List:
        """Fallback career trajectories"""
        return [
            {
                "title": "Technical Career Path",
                "roles": ["Junior Developer", "Senior Developer", "Tech Lead", "Architect"],
                "years": [0, 3, 6, 10],
                "estimated_salaries": ["₹5-8 LPA", "₹10-15 LPA", "₹18-25 LPA", "₹30-40 LPA"],
                "required_skills": ["Python", "System Design", "Leadership"],
                "required_certifications": ["Cloud Certification", "Architecture"],
                "transition_difficulty": "medium"
            },
            {
                "title": "Management Career Path",
                "roles": ["Team Lead", "Project Manager", "Program Manager", "Director"],
                "years": [0, 2, 5, 8],
                "estimated_salaries": ["₹8-12 LPA", "₹12-18 LPA", "₹20-30 LPA", "₹35-50 LPA"],
                "required_skills": ["Leadership", "Communication", "Strategic Planning"],
                "required_certifications": ["PMP", "MBA"],
                "transition_difficulty": "medium"
            }
        ]
    
    def _generate_financial_recommendations(self, roi_percentage: float, break_even_months: float) -> List:
        """Generate financial recommendations"""
        recommendations = []
        
        if roi_percentage > 200:
            recommendations.append("Excellent ROI - invest in this path")
        elif roi_percentage > 100:
            recommendations.append("Good ROI - recommended investment")
        else:
            recommendations.append("Consider cost-effective alternatives")
        
        if break_even_months > 24:
            recommendations.append("Long break-even period - ensure financial stability")
        
        recommendations.append("Build emergency fund before major investments")
        
        return recommendations
    
    def _create_weekly_schedule(self, skills: List, learning_style: str, hours: int) -> List:
        """Create weekly learning schedule"""
        schedule = []
        days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        
        for i, skill in enumerate(skills[:7]):
            schedule.append({
                "day": days[i % 7],
                "skill": skill,
                "hours": max(2, hours // len(skills[:7])),
                "activity": f"Learn {skill} through {'videos' if learning_style == 'visual' else 'practice'}",
                "resources": ["Online courses", "Documentation", "Practice exercises"]
            })
        
        return schedule
    
    async def _find_learning_resources(self, skills: List) -> List:
        """Find learning resources for skills"""
        resources = []
        
        for skill in skills[:5]:
            resources.append({
                "skill": skill,
                "courses": [
                    {"name": f"Complete {skill} Course", "platform": "Udemy", "duration": "20 hours"},
                    {"name": f"{skill} for Professionals", "platform": "Coursera", "duration": "30 hours"}
                ],
                "free_resources": [
                    f"YouTube tutorials for {skill}",
                    f"{skill} documentation",
                    f"Practice platforms for {skill}"
                ],
                "books": [f"{skill} Pocket Reference", f"Mastering {skill}"]
            })
        
        return resources
    
    def _fallback_career_analysis(self, user_profile: Dict) -> Dict:
        """Fallback career analysis when AI unavailable"""
        education_level = user_profile.get('basic_info', {}).get('education_level', 'basic')
        
        return {
            "career_summary": {
                "current_position": "Career exploration stage",
                "strengths": ["Willing to learn", "Basic skills", "Motivated"],
                "hidden_talents": ["Potential for growth", "Adaptability"],
                "unique_advantages": ["Ready to start career journey"],
                "areas_for_improvement": ["Complete profile for detailed analysis"]
            },
            "career_paths": [
                {
                    "role": "Skill Development First",
                    "industry": "Various",
                    "match_score": 70,
                    "short_term_2_years": {
                        "position": "Entry-level role",
                        "salary_range": "₹3-6 LPA",
                        "skills_needed": ["Communication", "Basic computer skills"],
                        "probability": 75
                    },
                    "medium_term_5_years": {
                        "position": "Specialized role",
                        "salary_range": "₹6-12 LPA",
                        "skills_needed": ["Domain expertise", "Certifications"],
                        "probability": 65
                    },
                    "long_term_10_years": {
                        "position": "Senior/Leadership",
                        "salary_range": "₹12-25 LPA",
                        "skills_needed": ["Leadership", "Strategic thinking"],
                        "probability": 55
                    },
                    "lifetime_earnings": {
                        "total_20_years": "₹1.5-3 Crore",
                        "peak_earnings": "₹25-35 LPA",
                        "retirement_corpus": "₹2-5 Crore"
                    },
                    "growth_potential": "medium",
                    "job_market_demand": {
                        "current_demand": "medium",
                        "future_projection": "stable",
                        "growth_rate_percentage": 8
                    },
                    "required_education": ["Complete profile", "Add skills"],
                    "recommended_certifications": ["Basic certifications", "Skill-based courses"],
                    "time_to_achieve": "2-5 years",
                    "success_probability": 65,
                    "risks": ["Competition", "Skill gaps"],
                    "opportunities": ["Growing job market"]
                }
            ],
            "alternative_careers": [
                {
                    "role": "Entrepreneurship",
                    "reason": "Self-employment opportunities",
                    "match_score": 60,
                    "transition_difficulty": "hard",
                    "transition_time": "12-24 months"
                }
            ],
            "skill_gap_analysis": {
                "critical_skills": ["Complete your profile", "Add technical skills", "Build communication"],
                "nice_to_have": ["Certifications", "Portfolio projects"],
                "learning_path": {
                    "immediate_next_steps": ["Complete your profile", "Add education details", "List your skills"],
                    "recommended_courses": [
                        {"name": "Career Development Fundamentals", "platform": "Coursera", "duration": "4 weeks", "cost": "Free", "priority": "high"}
                    ],
                    "estimated_time": "3-6 months",
                    "difficulty": "easy"
                }
            },
            "personalized_recommendations": {
                "immediate_actions": [
                    "Complete your profile with full details",
                    "Add your educational qualifications",
                    "List your professional skills",
                    "Add work experience if any",
                    "Specify your career interests"
                ],
                "weekly_goals": ["Update profile", "Learn 1 new skill", "Apply to 5 jobs"],
                "monthly_targets": ["Complete a certification", "Build a portfolio project"],
                "yearly_plan": ["Gain experience", "Advance skills", "Network professionally"],
                "mentorship_needed": True,
                "suggested_mentors": ["Industry professionals", "Career counselors"]
            },
            "unique_insights": {
                "rare_opportunity": "Complete your profile for personalized insights",
                "emerging_trend": "Digital skills are becoming essential",
                "hidden_potential": "Your profile will reveal unique strengths",
                "game_changer": "Invest in continuous learning"
            }
        }
    
    # ==================== STORAGE METHODS (MOVED INSIDE CLASS) ====================
    
    async def _store_user_analysis(self, email: str, analysis: Dict):
        """Store analysis for future learning using unified collection"""
        try:
            db = get_db()
            
            await db.ai_insights.update_one(
                {"email": email, "type": AIInsightType.CAREER_ANALYSIS},
                {
                    "$set": {
                        "type": AIInsightType.CAREER_ANALYSIS,
                        "email": email,
                        "data": analysis,
                        "updated_at": datetime.utcnow(),
                        "is_current": True,
                        "version": analysis.get('version', 1)
                    }
                },
                upsert=True
            )
            logger.info(f"✅ Career analysis stored for {email}")
        except Exception as e:
            logger.error(f"Failed to store analysis: {e}")
    
    async def _create_minimal_profile(self, email: str, auth_user: Dict) -> Dict:
        """Create minimal profile for new users"""
        return {
            "career_summary": {
                "current_position": "New User",
                "strengths": ["Ready to start career journey"],
                "areas_for_improvement": ["Complete your profile"]
            },
            "career_paths": [
                {
                    "role": "Complete Your Profile First",
                    "match_score": 100,
                    "short_term_2_years": {"position": "Profile Completion", "probability": 95},
                    "message": "Please complete your profile to get personalized career guidance"
                }
            ],
            "recommendations": {
                "immediate_actions": ["Complete your profile with education, skills, and experience"]
            }
        }
    
    # ==================== MISSING UTILITIES (MOVED INSIDE CLASS) ====================
    
    def _extract_ml_features(self, user_profile: Dict) -> List[float]:
        """Extract numerical features for ML models"""
        # Placeholder implementation
        return [0.0] * 10
    
    def _calculate_daily_commitment(self, available_hours: int, num_courses: int) -> int:
        """Calculate daily learning commitment in minutes"""
        if num_courses == 0:
            return 60
        return max(15, (available_hours * 60) // (num_courses * 7))
    
    async def _calculate_trajectory_probability(self, trajectory: Dict, user_profile: Dict) -> float:
        """Calculate probability of following a career trajectory"""
        # Placeholder
        return 0.7
    
    async def _analyze_intermediate_education(self, profile: Dict) -> Dict:
        """Placeholder for intermediate education analysis"""
        return {"education_level": "intermediate", "message": "Analysis not implemented"}
    
    async def _analyze_advanced_education(self, profile: Dict) -> Dict:
        """Placeholder for advanced education analysis"""
        return {"education_level": "advanced", "message": "Analysis not implemented"}
    
    async def _analyze_professional_education(self, profile: Dict) -> Dict:
        """Placeholder for professional education analysis"""
        return {"education_level": "professional", "message": "Analysis not implemented"}


# Initialize global instance
ultra_career_ai = UltraCareerAI()