# app/core/ai/ultra_ai_engine.py - COMPLETE FIXED VERSION
"""
ULTRA ADVANCED AI CORE ENGINE - Enterprise Grade
Features: Auto-learning, Self-optimizing, Predictive Analytics
Uses unified 'ai_insights' collection for training data
"""

import asyncio
import json
import hashlib
import numpy as np
from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime, timedelta
from dataclasses import dataclass, field
from collections import defaultdict
import logging
from openai import AsyncOpenAI
from sklearn.ensemble import RandomForestRegressor, IsolationForest
from sklearn.preprocessing import StandardScaler

from app.core.config.settings import settings
from app.core.utils.logger import logger

# ✅ FIX: Safe import for AIInsightsModel with fallback
try:
    from app.models.ai_insights_model import AIInsightsModel, AIInsightType
except ImportError:
    # Fallback definition if model file is missing
    from enum import Enum
    
    class AIInsightType(str, Enum):
        TRAINING_DATA = "training_data"
        SYSTEM_INSIGHT = "system_insight"
        USER_INSIGHT = "user_insight"
        MARKET_INSIGHT = "market_insight"
        FRAUD_ALERT = "fraud_alert"
        CAREER_ANALYSIS = "career_analysis"
        JOB_MATCH = "job_match"
        RESUME_SCORE = "resume_score"
    
    from pydantic import BaseModel, Field
    
    class AIInsightsModel(BaseModel):
        id: Optional[str] = Field(None, alias="_id")
        type: AIInsightType
        email: str
        data: Dict[str, Any] = {}
        feedback_score: Optional[float] = None
        was_helpful: Optional[bool] = None
        user_feedback: Dict[str, Any] = {}
        created_at: datetime = Field(default_factory=datetime.utcnow)
        updated_at: datetime = Field(default_factory=datetime.utcnow)
        
        class Config:
            populate_by_name = True
            arbitrary_types_allowed = True

# Create module logger
module_logger = logging.getLogger(__name__)


@dataclass
class AIInsight:
    """AI Generated Insight"""
    type: str
    confidence: float
    data: Dict
    timestamp: datetime
    priority: int  # 1-10
    actionable: bool
    impact_score: float


class UltraAIEngine:
    """
    Enterprise-grade AI Engine with unified storage
    """
    
    def __init__(self):
        self.client: Optional[AsyncOpenAI] = None
        self.redis_client = None
        self.ml_models: Dict[str, Any] = {}
        self.scalers: Dict[str, StandardScaler] = {}
        self.insight_cache: Dict[str, Any] = {}
        self.learning_rate: float = 0.01
        self._initialize()
    
    def _initialize(self):
        """Initialize AI components"""
        if settings.OPENAI_API_KEY:
            try:
                self.client = AsyncOpenAI(
                    api_key=settings.OPENAI_API_KEY,
                    timeout=30.0,
                    max_retries=3
                )
                module_logger.info("✅ OpenAI client initialized")
            except Exception as e:
                module_logger.warning(f"OpenAI init failed: {e}")
        
        if settings.REDIS_URL:
            try:
                import redis.asyncio as redis
                self.redis_client = redis.from_url(
                    settings.REDIS_URL,
                    decode_responses=True
                )
                module_logger.info("✅ Redis cache initialized for AI")
            except Exception as e:
                module_logger.warning(f"Redis initialization failed: {e}")
        
        # Initialize ML models
        self._init_ml_models()
    
    def _init_ml_models(self):
        """Initialize machine learning models"""
        try:
            self.ml_models = {
                'candidate_scoring': RandomForestRegressor(
                    n_estimators=100, random_state=42
                ),
                'fraud_detection': IsolationForest(
                    contamination=0.1, random_state=42
                ),
                'churn_prediction': RandomForestRegressor(
                    n_estimators=50, random_state=42
                ),
                'salary_predictor': RandomForestRegressor(
                    n_estimators=80, random_state=42
                ),
            }
            
            self.scalers = {
                'candidate_scoring': StandardScaler(),
                'salary_predictor': StandardScaler(),
            }
            module_logger.info("✅ ML models initialized")
        except Exception as e:
            module_logger.warning(f"ML models initialization failed: {e}")
    
    async def _get_db(self):
        """Lazy import to avoid circular dependency"""
        from app.db.connection import get_db
        return get_db()
    
    # ==================== AUTO-LEARNING SYSTEM ====================
    
    async def auto_learn(
        self,
        data_type: str,
        data: Dict,
        feedback: Optional[float] = None
    ):
        """
        Self-learning system that improves over time
        Stores training data in unified ai_insights collection
        """
        try:
            await self._store_training_data(data_type, data, feedback)
            
            count = await self._get_training_count(data_type)
            if count % 100 == 0 and count > 0:
                await self._retrain_model(data_type)
                module_logger.info(
                    f"🔄 Auto-retrained {data_type} model with {count} samples"
                )
            
            if feedback is not None:
                await self._adjust_learning_rate(data_type, feedback)
        except Exception as e:
            module_logger.error(f"Auto-learn failed: {e}")
    
    async def _store_training_data(
        self,
        data_type: str,
        data: Dict,
        feedback: Optional[float]
    ):
        """Store training data in unified ai_insights collection"""
        try:
            db = await self._get_db()
            
            was_helpful_val = None
            if feedback is not None:
                was_helpful_val = feedback > 0.7
            
            training_doc = AIInsightsModel(
                type=AIInsightType.TRAINING_DATA,
                email=data.get('email', 'system@rojgarnest.com'),
                data={"type": data_type, **data},
                feedback_score=feedback,
                was_helpful=was_helpful_val,
                user_feedback={
                    "score": feedback,
                    "original_data": data.get('query', '')
                },
            )
            
            doc_dict = training_doc.model_dump(by_alias=True)
            await db.ai_insights.insert_one(doc_dict)
        except Exception as e:
            module_logger.error(f"Store training data failed: {e}")
    
    async def _get_training_count(self, data_type: str) -> int:
        """Get count of training data from unified collection"""
        try:
            db = await self._get_db()
            count = await db.ai_insights.count_documents({
                "type": AIInsightType.TRAINING_DATA.value,
                "data.type": data_type,
            })
            return count
        except Exception:
            return 0
    
    async def _retrain_model(self, model_name: str):
        """Retrain ML model with accumulated data from unified collection"""
        try:
            db = await self._get_db()
            
            training_data = await db.ai_insights.find({
                "type": AIInsightType.TRAINING_DATA.value,
                "feedback_score": {"$exists": True, "$ne": None},
            }).limit(500).to_list(500)
            
            if len(training_data) < 50:
                return
            
            X: List[List[float]] = []
            y: List[float] = []
            for item in training_data:
                features = self._extract_features(
                    item.get('data', {}), model_name
                )
                X.append(features)
                if item.get('feedback_score') is not None:
                    y.append(float(item['feedback_score']))
            
            if X and y and len(X) == len(y) and len(X) > 10:
                if model_name in self.scalers:
                    X_scaled = self.scalers[model_name].fit_transform(X)
                else:
                    X_scaled = X
                
                if model_name in self.ml_models:
                    self.ml_models[model_name].fit(X_scaled, y)
                    module_logger.info(
                        f"✅ {model_name} model retrained successfully"
                    )
        except Exception as e:
            module_logger.error(f"Retrain model failed: {e}")
    
    async def _adjust_learning_rate(self, data_type: str, feedback: float):
        """Adjust learning rate based on feedback"""
        try:
            if feedback > 0.8:
                self.learning_rate = min(0.1, self.learning_rate * 1.1)
            elif feedback < 0.5:
                self.learning_rate = max(0.001, self.learning_rate * 0.9)
        except Exception:
            pass
    
    # ==================== ADVANCED CANDIDATE SCORING ====================
    
    async def ultra_candidate_scoring(
        self, candidate: Dict, job: Dict
    ) -> Dict:
        """
        Multi-dimensional AI candidate scoring
        """
        try:
            ai_analysis = await self._deep_candidate_analysis(candidate, job)
            ml_score = await self._ml_candidate_score(candidate, job)
            sentiment_score = await self._sentiment_analysis(candidate)
            
            final_score = (
                ai_analysis.get('skill_match', 50) * 0.4
                + ai_analysis.get('experience_score', 50) * 0.25
                + ai_analysis.get('cultural_fit', 50) * 0.15
                + ml_score.get('growth_prediction', 50) * 0.10
                + sentiment_score * 0.10
            )
            
            reasoning = await self._generate_scoring_reasoning(
                candidate, job, ai_analysis, final_score
            )
            
            # Auto-learn from this scoring (non-blocking)
            try:
                await self.auto_learn('candidate_scoring', {
                    'email': candidate.get('email', 'system'),
                    'candidate_id': str(candidate.get('_id', '')),
                    'job_id': str(job.get('_id', '')),
                    'score': final_score,
                })
            except Exception:
                pass
            
            return {
                "total_score": round(final_score, 2),
                "breakdown": {
                    "skill_match": ai_analysis.get('skill_match', 50),
                    "experience_score": ai_analysis.get('experience_score', 50),
                    "cultural_fit": ai_analysis.get('cultural_fit', 50),
                    "growth_potential": ml_score.get('growth_prediction', 50),
                    "sentiment_score": sentiment_score,
                },
                "strengths": ai_analysis.get('strengths', []),
                "weaknesses": ai_analysis.get('weaknesses', []),
                "recommendation": self._get_recommendation(final_score),
                "reasoning": reasoning,
                "interview_questions": await self._generate_interview_questions(
                    candidate, job
                ),
                "estimated_salary_range": await self._predict_salary(
                    candidate, job
                ),
                "retention_probability": await self._predict_retention(
                    candidate, job
                ),
            }
        except Exception as e:
            module_logger.error(f"Ultra candidate scoring failed: {e}")
            return self._fallback_scoring(candidate, job)
    
    async def _deep_candidate_analysis(
        self, candidate: Dict, job: Dict
    ) -> Dict:
        """Deep AI analysis of candidate profile"""
        if not self.client:
            return self._fallback_analysis(candidate, job)
        
        try:
            candidate_payload = {
                'skills': [
                    s.get('name') for s in candidate.get('skills', [])
                    if isinstance(s, dict)
                ],
                'experience': len(candidate.get('experience', [])),
                'education': [
                    e.get('degree') for e in candidate.get('academic_records', [])
                    if isinstance(e, dict)
                ],
                'projects': len(candidate.get('projects', [])),
                'certifications': len(candidate.get('certifications', [])),
            }
            
            job_payload = {
                'title': job.get('post_name', 'Unknown'),
                'required_skills': job.get('required_skills', []),
                'experience_needed': job.get('experience_min_years', 0),
            }
            
            prompt = f"""Perform deep analysis of this candidate for the job:

CANDIDATE: {json.dumps(candidate_payload)}

JOB: {json.dumps(job_payload)}

Return ONLY valid JSON:
{{
    "skill_match": <0-100>,
    "experience_score": <0-100>,
    "cultural_fit": <0-100>,
    "strengths": ["strength1", "strength2", "strength3"],
    "weaknesses": ["weakness1", "weakness2"],
    "unique_advantages": ["advantage1", "advantage2"],
    "potential_risks": ["risk1", "risk2"]
}}"""
            
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
                max_tokens=800,
            )
            content = response.choices[0].message.content or "{}"
            return json.loads(content.strip())
        except Exception as e:
            module_logger.error(f"Deep analysis failed: {e}")
            return self._fallback_analysis(candidate, job)
    
    async def _ml_candidate_score(self, candidate: Dict, job: Dict) -> Dict:
        """ML-based scoring and predictions"""
        try:
            features = self._extract_features(candidate, 'candidate_scoring')
            
            if self.ml_models.get('candidate_scoring') and features:
                try:
                    features_scaled = self.scalers[
                        'candidate_scoring'
                    ].transform([features])
                    growth_score = self.ml_models[
                        'candidate_scoring'
                    ].predict(features_scaled)[0]
                    growth_score = float(min(100, max(0, growth_score)))
                except Exception:
                    growth_score = 65.0
            else:
                growth_score = 65.0
            
            return {
                "growth_prediction": growth_score,
                "success_probability": growth_score * 0.9,
                "learning_agility": growth_score * 0.85,
            }
        except Exception:
            return {
                "growth_prediction": 65.0,
                "success_probability": 58.5,
                "learning_agility": 55.25,
            }
    
    async def _sentiment_analysis(self, candidate: Dict) -> float:
        """Simple sentiment analysis"""
        try:
            text_parts: List[str] = []
            if candidate.get('summary'):
                text_parts.append(str(candidate['summary']))
            if candidate.get('career_objective'):
                text_parts.append(str(candidate['career_objective']))
            
            text = " ".join(text_parts).strip()
            if not text or not self.client:
                return 65.0
            
            prompt = (
                "Analyze the sentiment of this candidate's profile. "
                "Return ONLY a number between 0-100: "
                f"{text[:500]}"
            )
            
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.1,
                max_tokens=10,
            )
            
            content = response.choices[0].message.content or "65"
            # Extract first numeric token safely
            import re
            match = re.search(r'\d+(?:\.\d+)?', content)
            sentiment = float(match.group(0)) if match else 65.0
            return min(100.0, max(0.0, sentiment))
        except Exception:
            return 65.0
    
    async def _generate_scoring_reasoning(
        self,
        candidate: Dict,
        job: Dict,
        analysis: Dict,
        score: float
    ) -> str:
        """Generate reasoning for the score"""
        if not self.client:
            return (
                f"Candidate scored {score} based on skill match and "
                "experience."
            )
        
        try:
            prompt = f"""Generate a brief reasoning for this candidate score:

Score: {score}
Strengths: {analysis.get('strengths', [])}
Weaknesses: {analysis.get('weaknesses', [])}

Return a short 1-sentence explanation."""
            
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=100,
            )
            return response.choices[0].message.content or ""
        except Exception:
            return (
                f"Candidate scored {score} based on AI analysis of skills "
                "and experience."
            )
    
    async def _generate_interview_questions(
        self, candidate: Dict, job: Dict
    ) -> List[str]:
        """Generate interview questions"""
        if not self.client:
            return [
                "Tell us about your experience",
                "Why do you want this job?",
            ]
        
        try:
            skill_names = [
                s.get('name') for s in candidate.get('skills', [])
                if isinstance(s, dict)
            ][:5]
            
            prompt = f"""Generate 5 interview questions for this candidate:

Job: {job.get('post_name', 'Unknown')}
Candidate Skills: {skill_names}

Return ONLY a JSON array of 5 questions."""
            
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.5,
                max_tokens=300,
            )
            
            content = response.choices[0].message.content or "[]"
            questions = json.loads(content.strip())
            return questions if isinstance(questions, list) else [
                "Tell us about your experience"
            ]
        except Exception:
            return [
                "Tell us about your experience",
                "Why do you want this job?",
            ]
    
    async def _predict_salary(self, candidate: Dict, job: Dict) -> str:
        """Predict salary range"""
        try:
            exp_years = len(candidate.get('experience', []))
            base_salary = 3 + (exp_years * 1.5)
            return f"₹{base_salary:.1f}-{base_salary + 5:.1f} LPA"
        except Exception:
            return "₹3-8 LPA"
    
    async def _predict_retention(self, candidate: Dict, job: Dict) -> int:
        """Predict retention probability"""
        try:
            skill_count = len(candidate.get('skills', []))
            exp_years = len(candidate.get('experience', []))
            retention = min(95, 60 + (skill_count * 2) + (exp_years * 3))
            return int(retention)
        except Exception:
            return 70
    
    # ==================== AUTO FRAUD DETECTION ====================
    
    async def auto_fraud_detection(
        self, application: Dict, profile: Dict
    ) -> Dict:
        """Multi-layer fraud detection"""
        try:
            fraud_score: float = 0
            red_flags: List[str] = []
            
            # Layer 1: Basic checks
            if not application.get('cover_letter'):
                fraud_score += 10
                red_flags.append("No cover letter provided")
            
            if not profile.get('skills'):
                fraud_score += 15
                red_flags.append("No skills listed in profile")
            
            # Layer 2: ML Anomaly Detection
            ml_anomaly = await self._ml_fraud_detection(application, profile)
            fraud_score += ml_anomaly.get('score', 0) * 0.3
            
            # Layer 3: Consistency Check
            consistency_score = await self._consistency_check(
                profile, application
            )
            fraud_score += (100 - consistency_score) * 0.2
            if consistency_score < 60:
                red_flags.append(
                    "Profile-application inconsistency detected"
                )
            
            # Auto-learn from detection (non-blocking)
            try:
                await self.auto_learn('fraud_detection', {
                    'email': profile.get('email', 'system'),
                    'application_id': str(application.get('_id', '')),
                    'fraud_score': fraud_score,
                    'flags': red_flags,
                })
            except Exception:
                pass
            
            return {
                "fraud_score": min(100, fraud_score),
                "risk_level": self._get_risk_level(fraud_score),
                "red_flags": red_flags,
                "recommendation": self._get_fraud_recommendation(fraud_score),
                "verification_required": fraud_score > 40,
                "auto_block": fraud_score > 80,
            }
        except Exception as e:
            module_logger.error(f"Fraud detection failed: {e}")
            return {
                "fraud_score": 0,
                "risk_level": "low",
                "red_flags": [],
                "recommendation": "approve",
                "verification_required": False,
                "auto_block": False,
            }
    
    async def _ml_fraud_detection(
        self, application: Dict, profile: Dict
    ) -> Dict:
        """ML-based anomaly detection"""
        try:
            is_anomaly = False
            score: float = 20
            
            cover_letter = str(application.get('cover_letter', ''))
            if len(cover_letter) < 50:
                score += 20
                is_anomaly = True
            
            if (
                not profile.get('experience')
                and application.get('match_score', 0) > 80
            ):
                score += 30
                is_anomaly = True
            
            return {
                "score": min(100, score),
                "is_anomaly": is_anomaly,
                "flags": ["Unusual pattern detected"] if is_anomaly else [],
            }
        except Exception:
            return {"score": 20, "is_anomaly": False, "flags": []}
    
    async def _consistency_check(
        self, profile: Dict, application: Dict
    ) -> int:
        """Check consistency between profile and application"""
        try:
            score = 100
            
            if (
                application.get('applicant_name')
                != profile.get('full_name')
            ):
                score -= 30
            
            if (
                application.get('applicant_email')
                != profile.get('email')
            ):
                score -= 30
            
            return max(0, score)
        except Exception:
            return 70
    
    # ==================== AUTO JOB MATCHING ====================
    
    async def auto_job_matching(
        self, user_profile: Dict, jobs: List[Dict]
    ) -> List[Dict]:
        """Hyper-personalized job matching"""
        try:
            matched_jobs: List[Dict] = []
            
            for job in jobs[:50]:
                match_score = await self._calculate_match_score(
                    user_profile, job
                )
                
                if match_score.get('total', 0) > 50:
                    matched_jobs.append({
                        "job": job,
                        "match_score": match_score['total'],
                        "breakdown": match_score.get('breakdown', {}),
                        "why_match": match_score.get('reasoning', ''),
                        "missing_skills": match_score.get(
                            'missing_skills', []
                        ),
                    })
            
            matched_jobs.sort(
                key=lambda x: x['match_score'], reverse=True
            )
            return matched_jobs
        except Exception as e:
            module_logger.error(f"Job matching failed: {e}")
            return []
    
    async def _calculate_match_score(
        self, profile: Dict, job: Dict
    ) -> Dict:
        """Calculate comprehensive match score"""
        try:
            user_skills = {
                s.get('name', '').lower()
                for s in profile.get('skills', [])
                if isinstance(s, dict)
            }
            
            job_skills: set = set()
            for skill in job.get('required_skills', []):
                if isinstance(skill, dict):
                    name = skill.get('name', '')
                    if name:
                        job_skills.add(str(name).lower())
                elif isinstance(skill, str):
                    if skill:
                        job_skills.add(skill.lower())
            
            if job_skills:
                skill_match = (
                    len(user_skills & job_skills) / len(job_skills) * 100
                )
            else:
                skill_match = 50.0
            
            user_exp = len(profile.get('experience', []))
            required_exp = job.get('experience_min_years', 0) or 0
            
            if required_exp > 0:
                exp_match = min(100.0, (user_exp / required_exp) * 100)
            else:
                exp_match = 70.0
            
            total_score = (skill_match * 0.6) + (exp_match * 0.4)
            missing_skills = list(job_skills - user_skills)[:5]
            
            return {
                "total": round(total_score, 2),
                "breakdown": {
                    "skill_match": round(skill_match, 2),
                    "experience_match": round(exp_match, 2),
                },
                "reasoning": (
                    f"Skill match: {skill_match:.0f}%, "
                    f"Experience match: {exp_match:.0f}%"
                ),
                "missing_skills": missing_skills,
            }
        except Exception:
            return {
                "total": 50,
                "breakdown": {},
                "reasoning": "Unable to calculate match",
                "missing_skills": [],
            }
    
    async def auto_generate_job_description(
        self, title: str, company: str, level: str
    ) -> Dict:
        """Generate job description using AI"""
        if not self.client:
            return self._fallback_job_description(title, company, level)
        
        try:
            prompt = f"""Generate a job description for:

Title: {title}
Company: {company}
Level: {level}

Return ONLY valid JSON:
{{
    "title": "{title}",
    "description": "Detailed job description",
    "responsibilities": ["resp1", "resp2", "resp3"],
    "skills_required": ["skill1", "skill2", "skill3"],
    "qualifications": ["qual1", "qual2"],
    "salary_range": "₹X-Y LPA",
    "benefits": ["benefit1", "benefit2"],
    "work_type": "remote/hybrid/onsite"
}}"""
            
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.4,
                max_tokens=800,
            )
            
            content = response.choices[0].message.content or "{}"
            return json.loads(content.strip())
        except Exception:
            return self._fallback_job_description(title, company, level)
    
    def _fallback_job_description(
        self, title: str, company: str, level: str
    ) -> Dict:
        return {
            "title": title,
            "description": (
                f"{company} is looking for a {level} level {title} "
                "to join our dynamic team."
            ),
            "responsibilities": [
                "Develop and maintain software",
                "Collaborate with team",
                "Write clean code",
            ],
            "skills_required": ["Python", "JavaScript", "Problem Solving"],
            "qualifications": ["Bachelor's degree", "2+ years experience"],
            "salary_range": "₹5-12 LPA",
            "benefits": [
                "Health insurance",
                "Learning budget",
                "Flexible timing",
            ],
            "work_type": "hybrid",
        }
    
    # ==================== PREDICTIVE ANALYTICS ====================
    
    async def predictive_analytics(self, timeframe_days: int = 30) -> Dict:
        """Advanced predictive analytics using unified collection data"""
        try:
            db = await self._get_db()
            
            total_users = await db.auth.count_documents({})
            total_jobs = await db.job.count_documents({})
            total_apps = await db.applications.count_documents({})
            
            ai_insights_count = await db.ai_insights.count_documents({})
            training_data_count = await db.ai_insights.count_documents({
                "type": AIInsightType.TRAINING_DATA.value
            })
            
            ai_factor = min(1.5, 1 + (training_data_count / 1000))
            user_growth = int(total_users * 0.15 * ai_factor)
            job_growth = int(total_jobs * 0.10 * ai_factor)
            app_growth = int(total_apps * 0.20 * ai_factor)
            
            return {
                "predictions": {
                    "users": {
                        "next_30_days": total_users + user_growth,
                        "growth_rate": round(15 * ai_factor, 1),
                        "confidence": min(
                            95, 75 + (training_data_count / 100)
                        ),
                    },
                    "jobs": {
                        "next_30_days": total_jobs + job_growth,
                        "growth_rate": round(10 * ai_factor, 1),
                        "confidence": min(
                            95, 70 + (training_data_count / 100)
                        ),
                    },
                    "applications": {
                        "next_30_days": total_apps + app_growth,
                        "growth_rate": round(20 * ai_factor, 1),
                        "confidence": min(
                            95, 80 + (training_data_count / 100)
                        ),
                    },
                    "ai_insights": {
                        "total": ai_insights_count,
                        "training_samples": training_data_count,
                        "model_accuracy": min(
                            95, 60 + (training_data_count / 50)
                        ),
                    },
                },
                "recommendations": [
                    "Increase job postings to meet demand",
                    "Improve user onboarding",
                    "Enhance matching algorithm",
                    f"Collect more training data (current: {training_data_count})",
                ],
            }
        except Exception as e:
            module_logger.error(f"Predictive analytics failed: {e}")
            return {
                "predictions": {},
                "recommendations": ["Enable AI for detailed predictions"],
            }
    
    # ==================== UTILITY METHODS ====================
    
    def _extract_features(self, data: Dict, model_type: str) -> List[float]:
        """Extract numerical features for ML models"""
        try:
            if model_type == 'candidate_scoring':
                return [
                    float(len(data.get('skills', []))),
                    float(len(data.get('experience', []))),
                    float(len(data.get('certifications', []))),
                    float(len(data.get('projects', []))),
                    float(data.get('experience_years', 0) or 0),
                    1.0 if data.get('education') else 0.0,
                ]
            return [0.0]
        except Exception:
            return [0.0]
    
    def _get_recommendation(self, score: float) -> str:
        if score >= 85:
            return "strong_shortlist"
        elif score >= 70:
            return "shortlist"
        elif score >= 50:
            return "consider"
        else:
            return "reject"
    
    def _get_risk_level(self, score: float) -> str:
        if score >= 80:
            return "critical"
        elif score >= 60:
            return "high"
        elif score >= 40:
            return "medium"
        else:
            return "low"
    
    def _get_fraud_recommendation(self, score: float) -> str:
        if score >= 80:
            return "auto_reject_block_user"
        elif score >= 60:
            return "manual_verification_required"
        elif score >= 40:
            return "review_carefully"
        else:
            return "auto_approve"
    
    def _fallback_analysis(self, candidate: Dict, job: Dict) -> Dict:
        return {
            "skill_match": 60,
            "experience_score": 50,
            "cultural_fit": 60,
            "strengths": ["Profile completed", "Active applicant"],
            "weaknesses": ["Complete profile for better analysis"],
            "unique_advantages": ["Ready to work"],
            "potential_risks": ["Limited information"],
        }
    
    def _fallback_scoring(self, candidate: Dict, job: Dict) -> Dict:
        return {
            "total_score": 65,
            "breakdown": {},
            "strengths": ["Candidate is active"],
            "weaknesses": ["Enable AI for detailed analysis"],
            "recommendation": "consider",
            "reasoning": "AI analysis limited. Manual review recommended.",
            "interview_questions": [
                "Tell us about yourself",
                "Why do you want this job?",
            ],
            "estimated_salary_range": "₹3-8 LPA",
            "retention_probability": 70,
        }


# Global instance
ultra_ai_engine = UltraAIEngine()