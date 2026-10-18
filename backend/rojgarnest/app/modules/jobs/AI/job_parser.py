# app/modules/jobs/AI/job_parser.py
"""Jobs: AI Job Description Parser"""
import json
import logging
from typing import Dict, Any, List
from openai import AsyncOpenAI

from app.core.config.settings import settings
logger = logging.getLogger(__name__)


class JobParserAI:
    """Parse and extract structured data from job descriptions"""
    
    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None
    
    async def parse_job_description(self, description: str) -> Dict[str, Any]:
        """Extract structured information from job description"""
        if not self.client or not description:
            return self._fallback_parsing(description)
        
        try:
            prompt = f"""Parse this job description and extract key information:

DESCRIPTION: {description[:3000]}

Return ONLY valid JSON:
{{
  "required_skills": ["skill1", "skill2", "skill3"],
  "nice_to_have_skills": ["skill1", "skill2"],
  "min_experience_years": <number>,
  "education_requirements": ["requirement1", "requirement2"],
  "responsibilities": ["resp1", "resp2", "resp3"],
  "benefits": ["benefit1", "benefit2"],
  "work_type": "remote" | "hybrid" | "onsite",
  "job_level": "entry" | "mid" | "senior" | "lead"
}}"""
            
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
                max_tokens=800
            )
            
            return json.loads(response.choices[0].message.content.strip())
            
        except Exception as e:
            logger.error(f"Job parsing failed: {e}")
            return self._fallback_parsing(description)
    
    def _fallback_parsing(self, description: str) -> Dict:
        return {
            "required_skills": ["Communication", "Teamwork"],
            "nice_to_have_skills": [],
            "min_experience_years": 0,
            "education_requirements": ["Graduate"],
            "responsibilities": ["Perform assigned duties", "Collaborate with team"],
            "benefits": ["Competitive salary", "Growth opportunities"],
            "work_type": "hybrid",
            "job_level": "mid"
        }