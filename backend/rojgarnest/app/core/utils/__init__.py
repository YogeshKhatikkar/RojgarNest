# app/core/utils/__init__.py - COMPLETE VERSION
"""
Utility Functions Module
"""

from app.core.utils.logger import logger
from app.core.utils.config import settings
from app.core.utils.constants import USER_ROLES, JOB_TYPES, NOTIFICATION_TYPES, HTTP_STATUS, CACHE_TTL
from app.core.utils.helpers import generate_otp, format_date, clean_text
from app.core.utils.validators import validate_email, validate_phone, validate_password
from app.core.utils.decorators import log_execution_time, retry_on_failure
from app.core.utils.exceptions import (
    CustomException,
    NotFoundException,
    ValidationException,
    UnauthorizedException,
    ForbiddenException
)

__all__ = [
    'logger',
    'settings',
    'USER_ROLES',
    'JOB_TYPES',
    'NOTIFICATION_TYPES',
    'HTTP_STATUS',
    'CACHE_TTL',
    'generate_otp',
    'format_date',
    'clean_text',
    'validate_email',
    'validate_phone',
    'validate_password',
    'log_execution_time',
    'retry_on_failure',
    'CustomException',
    'NotFoundException',
    'ValidationException',
    'UnauthorizedException',
    'ForbiddenException'
]