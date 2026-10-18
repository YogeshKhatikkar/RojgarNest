# app/core/security/__init__.py - FIXED
"""
Security & Authentication Module
"""

# Lazy imports to avoid circular dependencies
def __getattr__(name):
    if name == 'SecurityMiddleware':
        from app.core.security.security_middleware import SecurityMiddleware
        return SecurityMiddleware
    elif name == 'UltraSecureAuth':
        from app.core.security.security_middleware import UltraSecureAuth
        return UltraSecureAuth
    elif name == 'encryption_manager':
        from app.core.security.encryption import encryption_manager
        return encryption_manager
    elif name == 'DataProtector':
        from app.core.security.encryption import DataProtector
        return DataProtector
    elif name == 'ip_blacklist':
        from app.core.security.ip_blacklist import ip_blacklist
        return ip_blacklist
    elif name == 'rate_limiter':
        from app.core.security.rate_limiter import rate_limiter
        return rate_limiter
    elif name in ['hash_password', 'verify_password', 'validate_password', 'hash_pin', 'verify_pin', 'create_access_token', 'create_refresh_token']:
        from app.core.security.security import (
            hash_password, verify_password, validate_password,
            hash_pin, verify_pin,
            create_access_token, create_refresh_token
        )
        return locals()[name]
    raise AttributeError(f"module {__name__} has no attribute {name}")

__all__ = [
    'SecurityMiddleware',
    'UltraSecureAuth',
    'encryption_manager',
    'DataProtector',
    'ip_blacklist',
    'hash_password',
    'verify_password',
    'validate_password',
    'hash_pin',
    'verify_pin',
    'create_access_token',
    'create_refresh_token',
    'rate_limiter'
]