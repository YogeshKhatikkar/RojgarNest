# app/modules/admin/AI/fraud_detection.py
"""Admin: AI Fraud Detection"""

import json
import logging
from typing import Dict, Any
from openai import AsyncOpenAI

from app.core.config.settings import settings

logger = logging.getLogger(__name__)


class FraudDetectionAI:
    """Detect fraudulent applications"""
    
    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None
    
    async def detect_fraud(self, application: Dict, profile: Dict) -> Dict[str, Any]:
        """Detect fraud indicators"""
        if not self.client:
            return self._fallback_detection(application)
        
        try:
            prompt = f"""Detect fraud in this application:

APPLICATION: {json.dumps({
    'cover_letter': application.get('cover_letter', '')[:200]
})}

Return ONLY JSON:
{{
    "fraud_score": <0-100>,
    "risk_level": "low" | "medium" | "high",
    "indicators": ["indicator1", "indicator2"],
    "recommendation": "approve" | "review" | "reject"
}}"""
            
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
                max_tokens=400
            )
            
            return json.loads(response.choices[0].message.content.strip())
            
        except Exception as e:
            logger.error(f"Fraud detection failed: {e}")
            return self._fallback_detection(application)
    
    def _fallback_detection(self, application: Dict) -> Dict:
        return {
            "fraud_score": 20,
            "risk_level": "low",
            "indicators": [],
            "recommendation": "approve"
        }