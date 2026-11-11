# app/modules/admin/AI/candidate_scoring.py
"""Admin: AI Candidate Scoring"""

import json
import logging
from typing import Dict, Any, List
from datetime import datetime
from openai import AsyncOpenAI

from app.core.config.settings import settings

logger = logging.getLogger(__name__)


class CandidateScoringAI:
    """AI-powered candidate scoring"""
    
    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None
    
    async def score_candidate(self, application: Dict, job: Dict, profile: Dict) -> Dict[str, Any]:
        """Score a candidate against job requirements"""
        if not self.client:
            return self._fallback_score(application, profile)
        
        try:
            prompt = f"""Score this candidate:

JOB: {json.dumps({
    'title': job.get('post_name', ''),
    'required_skills': job.get('required_skills', [])
})}

CANDIDATE: {json.dumps({
    'skills': [s.get('name') for s in profile.get('skills', [])],
    'experience': len(profile.get('experience', []))
})}

Return ONLY JSON:
{{
    "total_score": <0-100>,
    "skill_match": <0-100>,
    "experience_match": <0-100>,
    "recommendation": "shortlist" | "interview" | "reject",
    "reasoning": "Brief explanation"
}}"""
            
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
                max_tokens=500
            )
            
            return json.loads(response.choices[0].message.content.strip())
            
        except Exception as e:
            logger.error(f"Candidate scoring failed: {e}")
            return self._fallback_score(application, profile)
    
    def _fallback_score(self, application: Dict, profile: Dict) -> Dict:
        return {
            "total_score": 65,
            "skill_match": 60,
            "experience_match": 50,
            "recommendation": "interview",
            "reasoning": "Manual review recommended"
        }