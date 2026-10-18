# app/modules/user/AI/__init__.py
from .career_analysis import AICareerAnalyzer
from .job_matching import AIJobMatcher
from .skill_analyzer import AISkillAnalyzer
from .ai_routes import router as ai_router

__all__ = ['AICareerAnalyzer', 'AIJobMatcher', 'AISkillAnalyzer', 'ai_router']