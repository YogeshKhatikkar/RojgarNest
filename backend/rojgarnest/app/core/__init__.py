# app/core/__init__.py - FIXED VERSION
"""
RojgarNest Core Module
"""

from app.core.config.settings import settings
from app.core.utils.logger import logger
from app.core.middleware.response import ApiResponse

# Lazy imports for security (to avoid circular imports)
# Don't import these at module level - import them when needed

__all__ = [
    'settings',
    'logger',
    'ApiResponse',
    # Security (lazy loaded)
    'ip_blacklist',
    'encryption_manager',
    'DataProtector',
    'hash_password',
    'verify_password',
    'validate_password',
    'hash_pin',
    'verify_pin',
    'create_access_token',
    'create_refresh_token',
    # AI (lazy loaded)
    'ultra_ai_engine',
    'ultra_career_ai',
    'real_time_market_ai',
    'ai_career_service',
    'compute_ai_match'
]

# Lazy loading functions for security modules
def _get_ip_blacklist():
    from app.core.security.ip_blacklist import ip_blacklist
    return ip_blacklist

def _get_encryption_manager():
    from app.core.security.encryption import encryption_manager
    return encryption_manager

def _get_data_protector():
    from app.core.security.encryption import DataProtector
    return DataProtector

def _get_security():
    from app.core.security.security import (
        hash_password, verify_password, validate_password,
        hash_pin, verify_pin,
        create_access_token, create_refresh_token
    )
    return (hash_password, verify_password, validate_password,
            hash_pin, verify_pin,
            create_access_token, create_refresh_token)

# Lazy loading for AI modules
def _get_ultra_ai_engine():
    from app.core.ai.ultra_ai_engine import ultra_ai_engine
    return ultra_ai_engine

def _get_ultra_career_ai():
    from app.core.ai.ultra_career_ai import ultra_career_ai
    return ultra_career_ai

def _get_real_time_market_ai():
    from app.core.ai.real_time_market_ai import real_time_market_ai
    return real_time_market_ai

def _get_ai_career_service():
    from app.core.ai.ai_career_service import ai_career_service
    return ai_career_service

def _get_compute_ai_match():
    from app.core.ai.ai_service import compute_ai_match
    return compute_ai_match

# Property-style lazy getters
class _LazyLoader:
    def __init__(self, getter):
        self._getter = getter
        self._value = None
    
    def __getattr__(self, name):
        if self._value is None:
            self._value = self._getter()
        return getattr(self._value, name)
    
    def __call__(self, *args, **kwargs):
        if self._value is None:
            self._value = self._getter()
        return self._value(*args, **kwargs)

# Create lazy-loaded instances
ip_blacklist = _LazyLoader(_get_ip_blacklist)
encryption_manager = _LazyLoader(_get_encryption_manager)
DataProtector = _LazyLoader(_get_data_protector)
ultra_ai_engine = _LazyLoader(_get_ultra_ai_engine)
ultra_career_ai = _LazyLoader(_get_ultra_career_ai)
real_time_market_ai = _LazyLoader(_get_real_time_market_ai)
ai_career_service = _LazyLoader(_get_ai_career_service)

def compute_ai_match(job, profile):
    func = _get_compute_ai_match()
    return func(job, profile)

# Security functions - direct lazy loading
def hash_password(password):
    return _get_security()[0](password)

def verify_password(plain, hashed):
    return _get_security()[1](plain, hashed)

def validate_password(password):
    return _get_security()[2](password)

def hash_pin(pin):
    return _get_security()[3](pin)

def verify_pin(plain, hashed):
    return _get_security()[4](plain, hashed)

def create_access_token(data):
    return _get_security()[5](data)

def create_refresh_token(data):
    return _get_security()[6](data)