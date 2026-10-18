# app/core/ai_service.py
from app.core.config.settings import settings
from openai import AsyncOpenAI
from app.core.utils.logger import logger
import json

client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY) if settings.OPENAI_API_KEY else None

async def compute_ai_match(job: dict, profile: dict) -> dict:
    if not client:
        return {"match_percentage": 65, "reason": "AI disabled (no API key)"}

    try:
        prompt = f"""You are expert recruiter. Return ONLY valid JSON.
JOB: {json.dumps({k: job.get(k) for k in ['post_name','description','required_skills']})}
PROFILE: {json.dumps({k: profile.get(k) for k in ['skills','experience','academic_records']})}

{{
  "match_percentage": <0-100>,
  "reason": "short reason",
  "strengths": ["str1", "str2"],
  "gaps": ["gap1"]
}}"""

        resp = await client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.2,
            max_tokens=600
        )
        return json.loads(resp.choices[0].message.content.strip())
    except Exception as e:
        logger.error(f"AI Match failed: {e}")
        return {"match_percentage": 50, "reason": "AI error"}