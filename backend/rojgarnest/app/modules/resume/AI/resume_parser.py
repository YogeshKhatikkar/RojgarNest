# app/modules/resume/AI/resume_parser.py
"""Resume: AI Resume Parser"""

import json
import logging
from typing import Dict, Any
from fastapi import UploadFile
from openai import AsyncOpenAI
from app.core.config.settings import settings

logger = logging.getLogger(__name__)


class ResumeParserAI:
    """Parse resume content using AI"""
    
    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None
    
    async def parse_resume_content(self, file: UploadFile) -> Dict[str, Any]:
        """Parse resume file and extract structured data"""
        if not self.client:
            return self._fallback_parsing()
        
        try:
            # In production, extract text from PDF/DOC
            # For now, use filename as placeholder
            content = f"Resume file: {file.filename}"
            
            prompt = f"""Parse this resume and extract structured data. Return ONLY valid JSON.

RESUME CONTENT: {content[:2000]}

{{
  "skills": ["skill1", "skill2", "skill3"],
  "experience_years": <number>,
  "education": [
    {{
      "degree": "degree_name",
      "institution": "institution_name",
      "year": <year>
    }}
  ],
  "certifications": ["cert1", "cert2"],
  "languages": ["lang1", "lang2"],
  "summary": "Brief professional summary",
  "ats_score": <0-100>
}}"""
            
            response = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
                max_tokens=800
            )
            
            return json.loads(response.choices[0].message.content.strip())
            
        except Exception as e:
            logger.error(f"Resume parsing failed: {e}")
            return self._fallback_parsing()
    
    def _fallback_parsing(self) -> Dict:
        return {
            "skills": ["Communication", "Teamwork", "Problem Solving"],
            "experience_years": 0,
            "education": [{"degree": "Graduate", "institution": "University", "year": 2020}],
            "certifications": [],
            "languages": ["English"],
            "summary": "Motivated professional seeking opportunities",
            "ats_score": 50
        }