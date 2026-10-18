# app/modules/user/AI/job_matching.py
"""User Dashboard: AI Job Matching"""
import json
import logging
from typing import Dict, Any, List

from app.core.config.settings import settings
from app.core.utils.logger import logger
from openai import AsyncOpenAI

logger = logging.getLogger(__name__)


class AIJobMatcher:
    """AI-powered job recommendations for user dashboard"""
    
    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None
    
    async def compute_match(self, job: dict, profile: dict) -> dict:
        """Compute AI match percentage between job and user profile"""
        if not self.client:
            return {"match_percentage": 65, "reason": "AI disabled (no API key)"}
        
        try:
            prompt = f"""You are expert recruiter. Return ONLY valid JSON.
    JOB: {json.dumps({k: job.get(k) for k in ['post_name','description','required_skills']})}
    PROFILE: {json.dumps({k: profile.get(k) for k in ['skills','experience','academic_records']})}
    
    {{
      "match_percentage": <0-100>,
      "reason": "short reason",
      "strengths": ["str1", "str2"],
      "gaps": ["gap1"]
    }}"""
            
            resp = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
                max_tokens=600
            )
            return json.loads(resp.choices[0].message.content.strip())
        except Exception as e:
            logger.error(f"AI Match failed: {e}")
            return {"match_percentage": 50, "reason": "AI error"}
    
    async def get_recommendations(self, profile: Dict, limit: int = 10) -> List[Dict]:
        """Get job recommendations based on profile"""
        skills = [s.get('name', '').lower() for s in profile.get('skills', [])]
        experience_years = len(profile.get('experience', []))
        education_level = self._get_education_level(profile.get('academic_records', []))
        
        recommendations = []
        
        # Government job recommendations
        if education_level >= 3:
            recommendations.extend([
                {
                    "title": "SSC CGL",
                    "type": "government",
                    "match_score": 75,
                    "reason": "Good for graduates with basic aptitude skills",
                    "salary_range": "₹5L - ₹8L",
                    "required_skills": ["Aptitude", "Reasoning", "English"]
                },
                {
                    "title": "Bank PO (IBPS)",
                    "type": "government",
                    "match_score": 70,
                    "reason": "Suitable for graduates with good numerical ability",
                    "salary_range": "₹6L - ₹10L",
                    "required_skills": ["Quantitative Aptitude", "Banking Awareness", "English"]
                }
            ])
        
        # Private job recommendations based on skills
        tech_skills = ['python', 'java', 'javascript', 'react', 'flutter', 'sql', 'aws', 'docker']
        if any(skill in str(skills) for skill in tech_skills):
            recommendations.append({
                "title": "Software Developer",
                "type": "private",
                "match_score": 85,
                "reason": "Matches your technical skills",
                "salary_range": "₹5L - ₹15L",
                "required_skills": tech_skills[:5]
            })
        
        # Add generic recommendations if no matches found
        if not recommendations:
            recommendations.append({
                "title": "Complete Your Profile",
                "type": "general",
                "match_score": 50,
                "reason": "Add more details for better job matches",
                "salary_range": "Not specified",
                "required_skills": ["Complete profile", "Add skills", "Add experience"]
            })
        
        return recommendations[:limit]
    
    def _get_education_level(self, education_records: List) -> int:
        levels = {
            'phd': 7,
            'post graduation': 6,
            'graduation': 5,
            'diploma': 4,
            '12th': 3,
            '10th': 2
        }
        max_level = 0
        for edu in education_records:
            level = edu.get('level', '').lower()
            for key, value in levels.items():
                if key in level:
                    max_level = max(max_level, value)
        return max_level


print("✅ AIJobMatcher loaded")