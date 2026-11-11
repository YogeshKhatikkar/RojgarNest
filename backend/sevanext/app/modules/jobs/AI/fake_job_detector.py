# app/modules/jobs/AI/fake_job_detector.py - CREATE THIS FILE

import json
import logging
from typing import Dict, Any, List, Tuple
from datetime import datetime
from openai import AsyncOpenAI

from app.core.config.settings import settings

logger = logging.getLogger(__name__)


class FakeJobDetectorAI:
    """AI-Powered Fake/Scam Job Detection"""
    
    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None
    
    async def detect_fake_job(self, job_data: Dict) -> Tuple[bool, float, List[str]]:
        """Detect if job is fake/scam"""
        if not self.client:
            return self._rule_based_detection(job_data)
        
        try:
            prompt = f"""Analyze if this job posting is FAKE, SCAM, or LEGITIMATE:

JOB TITLE: {job_data.get('post_name', 'Unknown')}
COMPANY: {job_data.get('organization', 'Unknown')}
LOCATION: {job_data.get('location', 'Unknown')}
DESCRIPTION: {job_data.get('description', '')[:1500]}
SALARY: {job_data.get('salary_min', 'Not specified')}
JOB TYPE: {job_data.get('job_type', 'Unknown')}

Fake job indicators:
- Too good to be true salary
- No company website
- Vague description with grammar errors
- Asking for upfront payment
- Free email domains (gmail, yahoo)
- Unrealistic requirements

Return ONLY valid JSON:
{{
    "is_fake": true/false,
    "confidence_score": <0-100>,
    "red_flags": ["flag1", "flag2"],
    "reason": "explanation",
    "fake_type": "scam|spam|duplicate|misleading|legitimate"
}}"""
            
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
                max_tokens=500
            )
            
            result = json.loads(response.choices[0].message.content.strip())
            return (
                result.get("is_fake", False),
                result.get("confidence_score", 0),
                result.get("red_flags", [])
            )
            
        except Exception as e:
            logger.error(f"AI fake detection failed: {e}")
            return self._rule_based_detection(job_data)
    
    def _rule_based_detection(self, job_data: Dict) -> Tuple[bool, float, List[str]]:
        """Rule-based fallback detection"""
        red_flags = []
        confidence = 0
        
        desc = job_data.get('description', '').lower()
        title = job_data.get('post_name', '').lower()
        company = job_data.get('organization', '').lower()
        
        scam_keywords = ['work from home', 'data entry', 'investment', 'deposit', 
                        'registration fee', 'cryptocurrency', 'bitcoin']
        
        for keyword in scam_keywords:
            if keyword in desc or keyword in title:
                red_flags.append(f"Scam keyword: '{keyword}'")
                confidence += 15
        
        if '@gmail.com' in company or '@yahoo.com' in company:
            red_flags.append("Free email domain for company")
            confidence += 20
        
        if len(desc) < 100:
            red_flags.append("Very short description")
            confidence += 15
        
        is_fake = confidence >= 40
        return (is_fake, min(confidence, 100), red_flags)
    
    async def check_duplicate(self, job_data: Dict, db) -> Tuple[bool, float]:
        """Check if job is duplicate"""
        existing = await db.job.find_one({
            "post_name": job_data.get('post_name'),
            "organization": job_data.get('organization')
        })
        
        if existing:
            days_old = (datetime.utcnow() - existing.get('created_at', datetime.utcnow())).days
            if days_old < 30:
                return (True, 100 - (days_old * 2))
        
        return (False, 0)


fake_job_detector = FakeJobDetectorAI()