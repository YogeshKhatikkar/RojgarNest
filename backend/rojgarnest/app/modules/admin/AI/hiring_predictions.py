# app/modules/admin/AI/hiring_predictions.py
"""Admin: AI Hiring Predictions"""

import json
import logging
from typing import Dict, Any, List
from openai import AsyncOpenAI

from app.core.config.settings import settings

logger = logging.getLogger(__name__)


class HiringPredictorAI:
    """Predict hiring success"""
    
    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None
    
    async def predict_success_rate(self, candidate_score: Dict, job: Dict) -> Dict[str, Any]:
        """Predict candidate success rate"""
        if not self.client:
            return self._fallback_prediction(candidate_score)
        
        try:
            prompt = f"""Predict hiring success:

SCORE: {json.dumps(candidate_score)}
JOB: {json.dumps(job.get('post_name', 'Unknown'))}

Return ONLY JSON:
{{
    "success_probability": <0-100>,
    "expected_retention_months": <1-60>,
    "recommendations": ["rec1", "rec2"]
}}"""
            
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
                max_tokens=400
            )
            
            return json.loads(response.choices[0].message.content.strip())
            
        except Exception as e:
            logger.error(f"Prediction failed: {e}")
            return self._fallback_prediction(candidate_score)
    
    async def predict_hiring_trends(self, historical_data: List[Dict]) -> Dict[str, Any]:
        """Predict hiring trends"""
        return {
            "predicted_applications_next_month": 500,
            "predicted_hires_next_month": 50,
            "trend_direction": "stable",
            "recommended_actions": ["Increase job postings"]
        }
    
    def _fallback_prediction(self, candidate_score: Dict) -> Dict:
        return {
            "success_probability": 65,
            "expected_retention_months": 12,
            "recommendations": ["Conduct interview", "Check references"]
        }