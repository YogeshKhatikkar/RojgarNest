# app/modules/superadmin/AI/anomaly_detection.py
"""SuperAdmin: AI Anomaly Detection"""

import json
import logging
from typing import Dict, Any, List
from openai import AsyncOpenAI

from app.core.config.settings import settings

logger = logging.getLogger(__name__)


class AnomalyDetectionAI:
    """Detect anomalies in platform data"""
    
    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None
    
    async def detect_anomalies(self, historical_data: List[Dict], current_data: Dict) -> Dict[str, Any]:
        """Detect anomalies by comparing with historical patterns"""
        if not self.client:
            return self._fallback_anomaly_detection(current_data)
        
        try:
            prompt = f"""Detect anomalies in platform data:

HISTORICAL PATTERN: {json.dumps(historical_data[:10]) if historical_data else "No historical data"}
CURRENT DATA: {json.dumps(current_data)}

Return ONLY valid JSON:
{{
    "has_anomalies": true/false,
    "anomalies": [
        {{
            "metric": "metric_name",
            "expected_value": <number>,
            "actual_value": <number>,
            "deviation_percentage": <number>,
            "severity": "low" | "medium" | "high" | "critical",
            "reason": "Possible reason"
        }}
    ],
    "overall_severity": "low" | "medium" | "high" | "critical",
    "recommended_actions": ["action1", "action2"]
}}"""
            
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
                max_tokens=800
            )
            
            return json.loads(response.choices[0].message.content.strip())
            
        except Exception as e:
            logger.error(f"Anomaly detection failed: {e}")
            return self._fallback_anomaly_detection(current_data)
    
    def _fallback_anomaly_detection(self, current_data: Dict) -> Dict:
        return {
            "has_anomalies": False,
            "anomalies": [],
            "overall_severity": "low",
            "recommended_actions": ["Monitor regularly"]
        }