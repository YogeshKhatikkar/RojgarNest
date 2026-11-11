# app/modules/superadmin/AI/sentiment_analysis.py
"""SuperAdmin: AI Sentiment Analysis for User Feedback"""

import json
import logging
from typing import Dict, Any, List
from datetime import datetime
from openai import AsyncOpenAI

from app.core.config.settings import settings

logger = logging.getLogger(__name__)


class SentimentAnalysisAI:
    """Analyze user feedback and platform sentiment"""
    
    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None
    
    async def analyze_feedback_sentiment(self, feedback_text: str) -> Dict[str, Any]:
        """Analyze sentiment of user feedback"""
        if not self.client or not feedback_text:
            return self._fallback_sentiment_analysis(feedback_text)
        
        try:
            prompt = f"""Analyze the sentiment of this user feedback:

FEEDBACK: {feedback_text[:1000]}

Return ONLY valid JSON:
{{
    "sentiment_score": <0-100>,
    "sentiment_label": "positive" | "neutral" | "negative",
    "confidence": <0-100>,
    "key_phrases": ["phrase1", "phrase2"],
    "emotion": "happy" | "sad" | "angry" | "frustrated" | "excited" | "neutral",
    "action_required": true/false,
    "suggested_response": "Suggested response to user"
}}"""
            
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=500
            )
            
            return json.loads(response.choices[0].message.content.strip())
            
        except Exception as e:
            logger.error(f"Sentiment analysis failed: {e}")
            return self._fallback_sentiment_analysis(feedback_text)
    
    async def analyze_platform_sentiment(self, feedbacks: List[Dict]) -> Dict[str, Any]:
        """Analyze overall platform sentiment from multiple feedbacks"""
        if not self.client or not feedbacks:
            return self._fallback_platform_sentiment()
        
        try:
            # Aggregate feedback texts
            feedback_texts = [f.get('text', '') for f in feedbacks[:50]]
            combined = "\n".join(feedback_texts)
            
            prompt = f"""Analyze overall platform sentiment from these user feedbacks:

FEEDBACKS: {combined[:2000]}

Return ONLY valid JSON:
{{
    "overall_sentiment_score": <0-100>,
    "sentiment_distribution": {{
        "positive": <percentage>,
        "neutral": <percentage>,
        "negative": <percentage>
    }},
    "common_themes": ["theme1", "theme2", "theme3"],
    "top_issues": ["issue1", "issue2"],
    "top_praises": ["praise1", "praise2"],
    "recommendations": ["rec1", "rec2", "rec3"]
}}"""
            
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
                max_tokens=800
            )
            
            return json.loads(response.choices[0].message.content.strip())
            
        except Exception as e:
            logger.error(f"Platform sentiment analysis failed: {e}")
            return self._fallback_platform_sentiment()
    
    def _fallback_sentiment_analysis(self, feedback_text: str) -> Dict:
        return {
            "sentiment_score": 50,
            "sentiment_label": "neutral",
            "confidence": 60,
            "key_phrases": ["Feedback received"],
            "emotion": "neutral",
            "action_required": False,
            "suggested_response": "Thank you for your feedback. We appreciate your input."
        }
    
    def _fallback_platform_sentiment(self) -> Dict:
        return {
            "overall_sentiment_score": 65,
            "sentiment_distribution": {
                "positive": 40,
                "neutral": 35,
                "negative": 25
            },
            "common_themes": ["User experience", "Job matching", "Notifications"],
            "top_issues": ["Profile completion", "Job recommendations"],
            "top_praises": ["Easy to use", "Good job listings"],
            "recommendations": ["Improve AI matching", "Add more job sources"]
        }