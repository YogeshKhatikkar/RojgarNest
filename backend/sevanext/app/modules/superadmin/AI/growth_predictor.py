# app/modules/superadmin/AI/growth_predictor.py
"""SuperAdmin: AI Growth Prediction"""

import json
import logging
from typing import Dict, Any, List
from openai import AsyncOpenAI

from app.core.config.settings import settings

logger = logging.getLogger(__name__)


class GrowthPredictorAI:
    """Predict platform growth trends"""
    
    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None
    
    async def predict_growth(self, historical_metrics: List[Dict]) -> Dict[str, Any]:
        """Predict future growth based on historical data"""
        if not self.client or not historical_metrics:
            return self._fallback_growth_prediction()
        
        try:
            prompt = f"""Predict platform growth based on historical data:

HISTORICAL METRICS: {json.dumps(historical_metrics[:30])}

Return ONLY valid JSON:
{{
    "predicted_users_30d": <number>,
    "predicted_jobs_30d": <number>,
    "predicted_applications_30d": <number>,
    "growth_rate_percentage": <number>,
    "growth_trajectory": "exponential" | "linear" | "logarithmic" | "plateau",
    "confidence_score": <0-100>,
    "factors": ["factor1", "factor2"],
    "recommendations": ["rec1", "rec2"]
}}"""
            
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=600
            )
            
            return json.loads(response.choices[0].message.content.strip())
            
        except Exception as e:
            logger.error(f"Growth prediction failed: {e}")
            return self._fallback_growth_prediction()
    
    def _fallback_growth_prediction(self) -> Dict:
        return {
            "predicted_users_30d": 500,
            "predicted_jobs_30d": 100,
            "predicted_applications_30d": 1000,
            "growth_rate_percentage": 15,
            "growth_trajectory": "linear",
            "confidence_score": 60,
            "factors": ["Market demand", "Platform features"],
            "recommendations": ["Improve marketing", "Add more job sources"]
        }