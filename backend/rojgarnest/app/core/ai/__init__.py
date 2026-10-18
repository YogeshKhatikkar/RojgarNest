# app/core/ai/__init__.py
"""
AI & Machine Learning Module
"""

# Lazy imports to avoid circular dependencies
_ultra_ai_engine = None
_ultra_career_ai = None
_real_time_market_ai = None
_ai_career_service = None
_ai_service = None

def get_ultra_ai_engine():
    global _ultra_ai_engine
    if _ultra_ai_engine is None:
        from app.core.ai.ultra_ai_engine import ultra_ai_engine
        _ultra_ai_engine = ultra_ai_engine
    return _ultra_ai_engine

def get_ultra_career_ai():
    global _ultra_career_ai
    if _ultra_career_ai is None:
        from app.core.ai.ultra_career_ai import ultra_career_ai
        _ultra_career_ai = ultra_career_ai
    return _ultra_career_ai

def get_real_time_market_ai():
    global _real_time_market_ai
    if _real_time_market_ai is None:
        from app.core.ai.real_time_market_ai import real_time_market_ai
        _real_time_market_ai = real_time_market_ai
    return _real_time_market_ai

def get_ai_career_service():
    global _ai_career_service
    if _ai_career_service is None:
        from app.core.ai.ai_career_service import ai_career_service
        _ai_career_service = ai_career_service
    return _ai_career_service

def get_compute_ai_match():
    global _ai_service
    if _ai_service is None:
        from app.core.ai.ai_service import compute_ai_match
        _ai_service = compute_ai_match
    return _ai_service

# For backward compatibility
ultra_ai_engine = property(lambda self: get_ultra_ai_engine())
ultra_career_ai = property(lambda self: get_ultra_career_ai())
real_time_market_ai = property(lambda self: get_real_time_market_ai())

__all__ = [
    'get_ultra_ai_engine',
    'get_ultra_career_ai',
    'get_real_time_market_ai',
    'get_ai_career_service',
    'get_compute_ai_match',
    'ultra_ai_engine',
    'ultra_career_ai',
    'real_time_market_ai'
]