# app/modules/user/AI/skill_analyzer.py
"""User Dashboard: AI Skill Gap Analysis"""
import json
import logging
from typing import Dict, Any, List

from app.core.config.settings import settings
from openai import AsyncOpenAI

logger = logging.getLogger(__name__)


class AISkillAnalyzer:
    """Analyze skill gaps between user profile and job requirements"""
    
    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None
    
    async def analyze_skill_gaps(self, profile: Dict[str, Any], jobs: List[Dict]) -> Dict[str, Any]:
        """Analyze skill gaps between user and job market"""
        if not self.client or not jobs:
            return self._get_fallback_analysis(profile)
        
        try:
            user_skills = [s.get('name', '') for s in profile.get('skills', [])]
            
            # Extract required skills from jobs
            required_skills = set()
            for job in jobs[:10]:  # Limit to 10 jobs
                for skill in job.get('required_skills', []):
                    if isinstance(skill, dict):
                        required_skills.add(skill.get('name', ''))
                    else:
                        required_skills.add(str(skill))
            
            missing_skills = list(required_skills - set(user_skills))
            
            prompt = f"""Analyze skill gaps for job seeker:

User Skills: {', '.join(user_skills) if user_skills else 'None'}
Required Skills from Jobs: {', '.join(missing_skills[:20]) if missing_skills else 'None'}

Return ONLY valid JSON:
{{
  "current_skills_summary": "Brief summary of current skills",
  "missing_skills": ["skill1", "skill2", "skill3"],
  "priority_skills": ["skill1", "skill2"],
  "learning_recommendations": ["recommendation1", "recommendation2"],
  "estimated_learning_time": "X months",
  "skill_score": <0-100>
}}"""

            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=800
            )
            
            result = json.loads(response.choices[0].message.content.strip())
            return result
            
        except Exception as e:
            logger.error(f"Skill gap analysis failed: {e}")
            return self._get_fallback_analysis(profile)
    
    def _get_fallback_analysis(self, profile: Dict) -> Dict:
        skills = [s.get('name', '') for s in profile.get('skills', [])]
        skills_count = len(skills)
        
        return {
            "current_skills_summary": f"You have {skills_count} skills listed. Add more to get better recommendations.",
            "missing_skills": ["Communication", "Problem Solving", "Teamwork"] if skills_count < 5 else [],
            "priority_skills": ["Complete your profile", "Add more technical skills"],
            "learning_recommendations": [
                "Complete your profile with education and experience",
                "Add 5+ skills relevant to your career",
                "Consider online certifications"
            ],
            "estimated_learning_time": "2-3 months",
            "skill_score": min(100, skills_count * 10)
        }


print("✅ AISkillAnalyzer loaded")