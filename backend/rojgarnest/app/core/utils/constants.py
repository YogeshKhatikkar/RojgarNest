# app/core/utils/constants.py
"""
Application Constants
"""

# User Roles
USER_ROLES = {
    'USER': 'user',
    'ADMIN': 'admin',
    'SUPER_ADMIN': 'superadmin'
}

# Job Types
JOB_TYPES = {
    'PRIVATE': 'private',
    'GOVERNMENT': 'government',
    'REMOTE': 'remote',
    'HYBRID': 'hybrid',
    'INTERNSHIP': 'internship'
}

# Notification Types
NOTIFICATION_TYPES = {
    'NEW_JOB': 'new_job',
    'APPLICATION_UPDATE': 'application_update',
    'SYSTEM': 'system',
    'OTP': 'otp'
}

# HTTP Status Codes
HTTP_STATUS = {
    'OK': 200,
    'CREATED': 201,
    'BAD_REQUEST': 400,
    'UNAUTHORIZED': 401,
    'FORBIDDEN': 403,
    'NOT_FOUND': 404,
    'TOO_MANY_REQUESTS': 429,
    'INTERNAL_ERROR': 500
}

# Cache TTL (seconds)
CACHE_TTL = {
    'SHORT': 300,      # 5 minutes
    'MEDIUM': 1800,    # 30 minutes
    'LONG': 3600,      # 1 hour
    'DAY': 86400       # 24 hours
}