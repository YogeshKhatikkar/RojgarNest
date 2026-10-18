# app/modules/resume/AI/resume_enhancer.py
# ============================================================
# AI RESUME ENHANCER — standalone bullet/summary/achievement rewriter
# ============================================================

import json
import logging
from typing import Dict, Any, List, Optional

from openai import AsyncOpenAI
from app.core.config.settings import settings

module_logger = logging.getLogger(__name__)


class ResumeEnhancer:
    """Enhance individual resume pieces on demand."""

    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None

    async def enhance_bullet_points(
        self,
        raw_bullets: List[str],
        role: str = "",
        job_description: Optional[str] = None,
        count: int = 5,
    ) -> List[str]:
        if not self.client or not raw_bullets:
            return raw_bullets[:count]

        try:
            prompt = f"""Rewrite these raw bullet points into ATS-optimized achievements.

ROLE: {role or "Professional"}
JOB DESCRIPTION: {(job_description or "")[:1500]}

RAW BULLETS:
{json.dumps(raw_bullets, indent=2)}

Rules:
- Start each bullet with a STRONG action verb (Led, Built, Optimized, Delivered…).
- Add measurable numbers where plausible (%, ₹, users, projects).
- 1–2 lines each, max 25 words.
- Return EXACTLY {count} bullets as a JSON array of strings.
"""
            resp = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "Return only a JSON array of strings."},
                    {"role": "user", "content": prompt},
                ],
                temperature=0.5,
                max_tokens=800,
            )
            text = resp.choices[0].message.content.strip()
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]
            return json.loads(text.strip())[:count]
        except Exception as e:
            module_logger.error(f"enhance_bullet_points failed: {e}")
            return raw_bullets[:count]

    async def enhance_summary(
        self,
        base_summary: str,
        role: str,
        skills: List[str],
        years_experience: int,
        job_description: Optional[str] = None,
    ) -> str:
        if not self.client:
            return base_summary

        try:
            prompt = f"""Rewrite this resume summary into a powerful 3–4 sentence ATS-optimized paragraph.

ROLE: {role}
YEARS: {years_experience}
SKILLS: {skills[:15]}
JOB DESCRIPTION: {(job_description or "")[:1000]}
EXISTING SUMMARY: {base_summary or "(none)"}

Rules:
- 50–90 words.
- Mention role + years + 3–5 key skills + one measurable achievement area.
- Natural language, no buzzword overload.
- Return plain text only.
"""
            resp = await self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.5,
                max_tokens=300,
            )
            return resp.choices[0].message.content.strip()
        except Exception as e:
            module_logger.error(f"enhance_summary failed: {e}")
            return base_summary


resume_enhancer = ResumeEnhancer()