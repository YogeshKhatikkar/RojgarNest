# app/modules/superadmin/AI/platform_analytics.py
"""SuperAdmin: Advanced Platform Analytics"""

import json
import logging
from typing import Dict, Any, List
from datetime import datetime, timedelta
from openai import AsyncOpenAI
from app.core.config.settings import settings

logger = logging.getLogger(__name__)


class PlatformAnalyticsAI:
    """Advanced AI analytics for platform performance"""
    
    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None
    
    async def analyze_platform_health(self, metrics: Dict) -> Dict[str, Any]:
        """Analyze overall platform health"""
        if not self.client:
            return self._fallback_health_analysis(metrics)
        
        try:
            prompt = f"""Analyze platform health metrics:

METRICS: {json.dumps(metrics)}

Return ONLY valid JSON:
{{
    "health_score": <0-100>,
    "performance_rating": "excellent" | "good" | "average" | "poor" | "critical",
    "strengths": ["strength1", "strength2"],
    "weaknesses": ["weakness1", "weakness2"],
    "critical_issues": ["issue1", "issue2"],
    "recommendations": ["rec1", "rec2", "rec3"],
    "summary": "Brief platform health summary"
}}"""
            
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=800
            )
            
            return json.loads(response.choices[0].message.content.strip())
            
        except Exception as e:
            logger.error(f"Platform health analysis failed: {e}")
            return self._fallback_health_analysis(metrics)
    
    def _fallback_health_analysis(self, metrics: Dict) -> Dict:
        score = 70
        return {
            "health_score": score,
            "performance_rating": "good" if score > 70 else "average",
            "strengths": ["Platform is operational"],
            "weaknesses": ["Complete AI setup for full insights"],
            "critical_issues": [],
            "recommendations": ["Configure OpenAI API key", "Monitor user engagement"],
            "summary": "Platform is operating normally. AI insights will improve with API configuration."
        }