# app/core/security/__init__.py - FIXED
"""
Security & Authentication Module
"""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError

from app.core.config.settings import settings

security_scheme = HTTPBearer(auto_error=False)


# ============================================================
# ✅ NEW: get_current_admin_user
# Used by admin/routes.py, customadmin/routes.py, superadmin/routes.py
# Accepts any admin-level role (admin, customadmin, superadmin)
# ============================================================
async def get_current_admin_user(
    credentials: HTTPAuthorizationCredentials = Depends(security_scheme),
):
    """
    Dependency that returns the current authenticated admin user.

    Accepted roles:
        admin, customadmin, custom_admin, superadmin
    """
    if not credentials or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authorization token",
        )

    token = credentials.credentials
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=["HS256"],
        )
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid or expired token: {e}",
        )

    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type",
        )

    role = (payload.get("role") or "").lower()
    if role == "custom_admin":
        role = "customadmin"

    allowed = {"admin", "customadmin", "superadmin"}
    if role not in allowed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Admin access required. Your role: {role}",
        )

    return {
        "user_id": payload.get("user_id"),
        "email": payload.get("email"),
        "name": payload.get("name"),
        "role": role,
    }

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
    'rate_limiter',
    'get_current_admin_user',
]