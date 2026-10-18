# app/modules/jobs/AI/salary_predictor.py
"""Jobs: AI Salary Predictor"""
import json
import logging
from typing import Dict, Any
from openai import AsyncOpenAI

from app.core.config.settings import settings

logger = logging.getLogger(__name__)


class SalaryPredictorAI:
    """Predict salary ranges based on job requirements"""
    
    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None
    
    async def predict_salary(self, job_data: Dict) -> Dict[str, Any]:
        """Predict salary range for a job"""
        if not self.client:
            return self._fallback_salary_prediction(job_data)
        
        try:
            prompt = f"""Predict salary range for this job in Indian Rupees (LPA):

JOB: {json.dumps({
    'title': job_data.get('post_name', ''),
    'skills': job_data.get('required_skills', []),
    'experience': job_data.get('experience_min_years', 0),
    'location': job_data.get('location', 'India'),
    'type': job_data.get('job_type', 'private')
})}

Return ONLY valid JSON:
{{
  "min_salary_lpa": <number>,
  "max_salary_lpa": <number>,
  "median_salary_lpa": <number>,
  "currency": "INR",
  "confidence_score": <0-100>,
  "market_trend": "above_average" | "average" | "below_average",
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
            logger.error(f"Salary prediction failed: {e}")
            return self._fallback_salary_prediction(job_data)
    
    def _fallback_salary_prediction(self, job_data: Dict) -> Dict:
        experience = job_data.get('experience_min_years', 0)
        base_salary = 3 + (experience * 1.5)
        
        return {
            "min_salary_lpa": round(base_salary, 1),
            "max_salary_lpa": round(base_salary + 5, 1),
            "median_salary_lpa": round(base_salary + 2.5, 1),
            "currency": "INR",
            "confidence_score": 60,
            "market_trend": "average",
            "reasoning": "Based on experience level and market standards"
        }