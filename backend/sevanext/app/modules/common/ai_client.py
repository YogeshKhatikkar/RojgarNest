# backend/rojgarnest/app/modules/common/ai_client.py
"""Shared AI Client for all modules"""
from openai import AsyncOpenAI
from app.core.config.settings import settings

_ai_client = None

def get_ai_client():
    global _ai_client
    if _ai_client is None and settings.OPENAI_API_KEY:
        _ai_client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)
    return _ai_client