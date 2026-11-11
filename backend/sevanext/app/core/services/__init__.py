# app/core/services/__init__.py
"""
Business Services Module
Exposes unified multi-provider email, SMS, WhatsApp services.
"""

# Email
from app.core.services.email import (
    send_email,
    send_html_email,
    send_email_async,
    get_email_service,
)

# SMS
from app.core.services.sms import (
    send_mobile_otp,
    send_sms_async,
    get_sms_service,
)

# WhatsApp
from app.core.services.whatsapp import (
    send_whatsapp,
    send_whatsapp_sync,
    get_whatsapp_service,
)

# Notification dispatcher (high-level)
from app.core.services.notification_dispatcher import (
    dispatch_otp,
    dispatch_verification_success,
    dispatch_password_reset,
    dispatch_welcome,
    dispatch_application_status,
    dispatch_job_alert,
    dispatch_payment_status,
    dispatch_admin_alert,
)

# Other services (unchanged)
from app.core.services.cloudinary import upload_to_cloudinary
from app.core.services.dependencies import get_current_user, role_required

__all__ = [
    # Email
    'send_email',
    'send_html_email',
    'send_email_async',
    'get_email_service',
    # SMS
    'send_mobile_otp',
    'send_sms_async',
    'get_sms_service',
    # WhatsApp
    'send_whatsapp',
    'send_whatsapp_sync',
    'get_whatsapp_service',
    # Dispatcher
    'dispatch_otp',
    'dispatch_verification_success',
    'dispatch_password_reset',
    'dispatch_welcome',
    'dispatch_application_status',
    'dispatch_job_alert',
    'dispatch_payment_status',
    'dispatch_admin_alert',
    # Other
    'upload_to_cloudinary',
    'get_current_user',
    'role_required',
]