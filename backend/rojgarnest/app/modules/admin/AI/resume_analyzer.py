# app/modules/admin/AI/resume_analyzer.py
"""Admin: AI Resume Analyzer"""

import json
import logging
from typing import Dict, Any
from openai import AsyncOpenAI

from app.core.config.settings import settings

logger = logging.getLogger(__name__)


class ResumeAnalyzerAI:
    """Analyze resumes with AI"""
    
    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None
    
    async def analyze_resume(self, resume_text: str, job_requirements: Dict) -> Dict[str, Any]:
        """Analyze resume content"""
        if not self.client or not resume_text:
            return self._fallback_analysis(resume_text)
        
        try:
            prompt = f"""Analyze this resume:

RESUME: {resume_text[:1000]}

Return ONLY JSON:
{{
    "extracted_skills": ["skill1", "skill2"],
    "years_experience": <number>,
    "ats_score": <0-100>,
    "recommendation": "strong" | "maybe" | "weak",
    "summary": "Brief summary"
}}"""
            
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
                max_tokens=500
            )
            
            return json.loads(response.choices[0].message.content.strip())
            
        except Exception as e:
            logger.error(f"Resume analysis failed: {e}")
            return self._fallback_analysis(resume_text)
    
    def _fallback_analysis(self, resume_text: str) -> Dict:
        return {
            "extracted_skills": ["Communication", "Teamwork"],
            "years_experience": 0,
            "ats_score": 50,
            "recommendation": "maybe",
            "summary": "Manual review recommended"
        }