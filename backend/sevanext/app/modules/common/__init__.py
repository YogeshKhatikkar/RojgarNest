# backend/rojgarnest/app/modules/common/__init__.py
from .ai_client import get_ai_client
from .prompts import PROMPT_TEMPLATES

__all__ = ['get_ai_client', 'PROMPT_TEMPLATES']