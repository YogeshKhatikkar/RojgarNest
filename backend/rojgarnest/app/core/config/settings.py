# app/core/config/settings.py
# ============================================================
# ✅ UNIVERSAL SETTINGS - Works with ANY SMS/WhatsApp provider
# ✅ FIXED: Added is_razorpay_test_mode + all Razorpay aliases
# ============================================================

from pydantic_settings import BaseSettings
from typing import List, Optional, Dict, Any
import os


class Settings(BaseSettings):
    # ============================================================
    # 🗄️ DATABASE
    # ============================================================
    MONGO_URI: str = "mongodb://localhost:27017/RojgarNest"
    DATABASE_NAME: str = "RojgarNest"
    ENVIRONMENT: str = "development"
    PORT: int = 8000

    # ============================================================
    # 🔐 SECURITY
    # ============================================================
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    SECRET_KEY: str = "change-me"
    SESSION_SECRET_KEY: str = "change-me"
    JWT_SECRET_KEY: str = "change-me"
    REDIS_URL: str = "redis://localhost:6379"
    ENCRYPTION_KEY: str = "change-me"
    SECRET_TOKEN: str = "change-me"

    # ============================================================
    # 🧪 OTP BYPASS
    # ============================================================
    MOBILE_OTP_BYPASS: bool = True
    DEV_OTP_CODE: str = "123456"

    # ============================================================
    # 📱 SMS PROVIDER
    # ============================================================
    SMS_PROVIDER: str = "twilio"
    SMS_FALLBACK_ENABLED: bool = True
    SMS_FALLBACK_ORDER: str = "twilio,msg91,fast2sms,brevo"

    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_PHONE: str = ""
    TWILIO_IS_TRIAL_ACCOUNT: bool = False
    TWILIO_WHATSAPP_NUMBER: str = ""
    TWILIO_WHATSAPP_CONTENT_SID: str = ""
    TWILIO_WHATSAPP_TEMPLATE_SID: str = ""

    MSG91_AUTH_KEY: str = ""
    MSG91_SENDER_ID: str = "RJGARN"
    MSG91_TEMPLATE_ID_OTP: str = ""
    MSG91_TEMPLATE_ID_VERIFY: str = ""
    MSG91_TEMPLATE_ID_ALERT: str = ""
    MSG91_ROUTE: str = "4"
    MSG91_COUNTRY: str = "91"
    MSG91_DLT_TE_ID: str = ""

    MSG91_WHATSAPP_API_KEY: str = ""
    MSG91_WHATSAPP_INTEGRATED_NUMBER: str = ""
    MSG91_WHATSAPP_TEMPLATE_OTP: str = ""
    MSG91_WHATSAPP_TEMPLATE_ALERT: str = ""
    MSG91_WHATSAPP_TEMPLATE_JOB: str = ""
    MSG91_WHATSAPP_TEMPLATE_STATUS: str = ""

    FAST2SMS_API_KEY: str = ""

    BREVO_API_KEY: str = ""
    BREVO_SMS_SENDER: str = "RojgarNest"
    BREVO_SMS_API_KEY: str = ""

    # ============================================================
    # 💬 WHATSAPP PROVIDER
    # ============================================================
    WHATSAPP_PROVIDER: str = "twilio"
    WHATSAPP_FALLBACK_TO_SMS: bool = True

    META_WA_PHONE_NUMBER_ID: str = ""
    META_WA_ACCESS_TOKEN: str = ""
    META_WA_BUSINESS_ACCOUNT_ID: str = ""
    META_WA_VERIFY_TOKEN: str = ""
    META_WA_TEMPLATE_OTP: str = ""
    META_WA_TEMPLATE_ALERT: str = ""

    # ============================================================
    # 🔔 NOTIFICATION CHANNELS
    # ============================================================
    NOTIFY_OTP_CHANNELS: str = "email,sms,whatsapp"
    NOTIFY_VERIFICATION_CHANNELS: str = "email,sms"
    NOTIFY_JOB_ALERT_CHANNELS: str = "email,whatsapp,inapp"
    NOTIFY_APPLICATION_STATUS_CHANNELS: str = "email,inapp"
    NOTIFY_PAYMENT_CHANNELS: str = "email,sms,inapp"
    NOTIFY_ADMIN_ALERT_CHANNELS: str = "email,inapp"
    NOTIFY_PASSWORD_RESET_CHANNELS: str = "email,sms,whatsapp"
    NOTIFY_WELCOME_CHANNELS: str = "email,inapp"

    # ============================================================
    # 📧 EMAIL PROVIDER
    # ============================================================
    EMAIL_PROVIDER: str = "smtp"
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM: str = ""
    SMTP_FROM_NAME: str = "RojgarNest"

    BREVO_SENDER_EMAIL: str = ""
    BREVO_SENDER_NAME: str = "RojgarNest"
    BREVO_SMTP_HOST: str = "smtp-relay.brevo.com"
    BREVO_SMTP_PORT: int = 587
    BREVO_SMTP_USER: str = ""
    BREVO_SMTP_PASSWORD: str = ""

    SENDGRID_API_KEY: str = ""
    SENDGRID_FROM_EMAIL: str = ""
    SENDGRID_FROM_NAME: str = "RojgarNest"

    MAILGUN_API_KEY: str = ""
    MAILGUN_DOMAIN: str = ""
    MAILGUN_FROM_EMAIL: str = ""
    MAILGUN_FROM_NAME: str = "RojgarNest"

    # ============================================================
    # 🌐 OTHER
    # ============================================================
    APP_BASE_URL: str = "http://localhost:8000"
    OPENAI_API_KEY: str = ""
    OPENAI_MODEL: str = "gpt-4o-mini"

    CLOUDINARY_URL: str = ""
    CLOUDINARY_CLOUD_NAME: str = ""
    CLOUDINARY_API_KEY: str = ""
    CLOUDINARY_API_SECRET: str = ""

    # ============================================================
    # 💳 RAZORPAY - ✅ FIXED WITH ALL ALIASES
    # ============================================================
    RAZORPAY_KEY_ID: str = ""
    RAZORPAY_KEY_SECRET: str = ""
    RAZORPAY_WEBHOOK_SECRET: str = ""
    
    # ✅ PRIMARY ATTRIBUTE (used by routes.py)
    RAZORPAY_TEST_MODE: bool = True
    
    # ✅ ALIASES — prevents AttributeError everywhere
    # (properties defined below)
    
    UPI_ID: str = ""

    # ============================================================
    # 🔧 HELPER METHODS
    # ============================================================
    def get_channels(self, notification_type: str) -> List[str]:
        mapping = {
            "otp": self.NOTIFY_OTP_CHANNELS,
            "verification": self.NOTIFY_VERIFICATION_CHANNELS,
            "job_alert": self.NOTIFY_JOB_ALERT_CHANNELS,
            "application_status": self.NOTIFY_APPLICATION_STATUS_CHANNELS,
            "payment": self.NOTIFY_PAYMENT_CHANNELS,
            "admin_alert": self.NOTIFY_ADMIN_ALERT_CHANNELS,
            "password_reset": self.NOTIFY_PASSWORD_RESET_CHANNELS,
            "welcome": self.NOTIFY_WELCOME_CHANNELS,
        }
        raw = mapping.get(notification_type, "email")
        return [c.strip().lower() for c in raw.split(",") if c.strip()]

    def get_channels_for(self, notification_type: str) -> List[str]:
        return self.get_channels(notification_type)

    # ============================================================
    # 🧪 OTP MODE HELPERS
    # ============================================================
    @property
    def is_otp_bypass_enabled(self) -> bool:
        return self.MOBILE_OTP_BYPASS is True

    @property
    def is_mobile_otp_bypassed(self) -> bool:
        return self.MOBILE_OTP_BYPASS is True

    @property
    def is_email_always_real(self) -> bool:
        return True

    @property
    def dev_otp_value(self) -> str:
        return self.DEV_OTP_CODE

    @property
    def otp_code(self) -> str:
        return self.DEV_OTP_CODE

    # ============================================================
    # 💳 RAZORPAY HELPERS — ✅ FIXED (all aliases point to RAZORPAY_TEST_MODE)
    # ============================================================
    @property
    def is_razorpay_test_mode(self) -> bool:
        """
        ✅ FIXED: This property was MISSING.
        routes.py accesses settings.is_razorpay_test_mode
        Now it returns the correct value.
        """
        return self.RAZORPAY_TEST_MODE

    @property
    def IS_RAZORPAY_TEST_MODE(self) -> bool:
        """Alias (uppercase) for compatibility"""
        return self.RAZORPAY_TEST_MODE

    @property
    def razorpay_test_mode(self) -> bool:
        """Alias (lowercase) for compatibility"""
        return self.RAZORPAY_TEST_MODE

    @property
    def is_razorpay_configured(self) -> bool:
        """Check if Razorpay credentials are set"""
        return bool(self.RAZORPAY_KEY_ID and self.RAZORPAY_KEY_SECRET)

    @property
    def razorpay_mode_string(self) -> str:
        """Returns 'TEST' or 'PRODUCTION' for display"""
        return "TEST" if self.RAZORPAY_TEST_MODE else "PRODUCTION"

    # ============================================================
    # 📱 UNIVERSAL PROVIDER DETECTION
    # ============================================================
    def is_provider_configured(self, provider: str) -> bool:
        provider = provider.lower().strip()
        if provider == "twilio":
            return bool(self.TWILIO_ACCOUNT_SID and self.TWILIO_AUTH_TOKEN and self.TWILIO_PHONE)
        elif provider == "msg91":
            return bool(self.MSG91_AUTH_KEY)
        elif provider == "fast2sms":
            return bool(self.FAST2SMS_API_KEY)
        elif provider == "brevo":
            return bool(self.BREVO_SMS_API_KEY or self.BREVO_API_KEY)
        return False

    def is_whatsapp_provider_configured(self, provider: str) -> bool:
        provider = provider.lower().strip()
        if provider == "twilio":
            return bool(self.TWILIO_ACCOUNT_SID and self.TWILIO_AUTH_TOKEN and self.TWILIO_WHATSAPP_NUMBER)
        elif provider == "msg91":
            return bool((self.MSG91_WHATSAPP_API_KEY or self.MSG91_AUTH_KEY) and self.MSG91_WHATSAPP_INTEGRATED_NUMBER)
        elif provider == "meta":
            return bool(self.META_WA_PHONE_NUMBER_ID and self.META_WA_ACCESS_TOKEN)
        elif provider == "disabled":
            return False
        return False

    @property
    def sms_fallback_providers(self) -> List[str]:
        order = [p.strip().lower() for p in self.SMS_FALLBACK_ORDER.split(",") if p.strip()]
        return order

    @property
    def active_sms_provider(self) -> str:
        if self.SMS_PROVIDER.lower() == "auto":
            for provider in self.sms_fallback_providers:
                if self.is_provider_configured(provider):
                    return provider
            return "none"
        provider = self.SMS_PROVIDER.lower().strip()
        if self.is_provider_configured(provider):
            return provider
        if self.SMS_FALLBACK_ENABLED:
            for fb_provider in self.sms_fallback_providers:
                if fb_provider != provider and self.is_provider_configured(fb_provider):
                    return fb_provider
        return "none"

    @property
    def active_whatsapp_provider(self) -> str:
        if self.WHATSAPP_PROVIDER.lower() == "auto":
            for provider in ["twilio", "msg91", "meta"]:
                if self.is_whatsapp_provider_configured(provider):
                    return provider
            return "disabled"
        provider = self.WHATSAPP_PROVIDER.lower().strip()
        if provider == "disabled":
            return "disabled"
        if self.is_whatsapp_provider_configured(provider):
            return provider
        for fb_provider in ["twilio", "msg91", "meta"]:
            if fb_provider != provider and self.is_whatsapp_provider_configured(fb_provider):
                return fb_provider
        return "disabled"

    @property
    def twilio_allowed_templates(self) -> List[str]:
        return [
            "sms_2fa", "sms_appointment_reminders",
            "sms_order_confirmation", "sms_delivery_updates",
            "sms_customer_support", "sms_marketing_promotions",
            "sms_event_notifications", "sms_account_alerts",
            "sms_feedback_surveys", "sms_internal_alerts",
        ]

    def is_valid_twilio_trial_template(self, template: str) -> bool:
        return template in self.twilio_allowed_templates

    # ============================================================
    # 🗄️ DATABASE HELPERS
    # ============================================================
    @property
    def SAFE_MONGO_URI(self) -> str:
        uri = self.MONGO_URI or "mongodb://localhost:27017/RojgarNest"
        if uri.startswith("mongodb+srv://"):
            if "retryWrites=" not in uri:
                separator = "&" if "?" in uri else "?"
                uri = f"{uri}{separator}retryWrites=true&w=majority"
        elif uri.startswith("mongodb://"):
            if "retryWrites=" not in uri:
                separator = "&" if "?" in uri else "?"
                uri = f"{uri}{separator}retryWrites=true&w=majority"
        return uri

    @property
    def IS_LOCAL_DB(self) -> bool:
        uri = (self.MONGO_URI or "").lower()
        return "localhost" in uri or "127.0.0.1" in uri

    @property
    def IS_ATLAS_DB(self) -> bool:
        uri = (self.MONGO_URI or "").lower()
        return uri.startswith("mongodb+srv://") or "mongodb.net" in uri

    @property
    def MONGO_OPTIONS(self) -> Dict[str, Any]:
        if self.IS_ATLAS_DB:
            return {
                "serverSelectionTimeoutMS": 30000,
                "connectTimeoutMS": 30000,
                "socketTimeoutMS": 30000,
                "tls": True,
                "tlsAllowInvalidCertificates": True,
                "tlsAllowInvalidHostnames": True,
                "retryWrites": True,
                "retryReads": True,
                "maxPoolSize": 100,
                "minPoolSize": 5,
            }
        return {
            "serverSelectionTimeoutMS": 5000,
            "connectTimeoutMS": 5000,
            "socketTimeoutMS": 10000,
            "retryWrites": True,
            "retryReads": True,
            "maxPoolSize": 50,
            "minPoolSize": 2,
        }

    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"


settings = Settings()

# ============================================================
# 🎯 STARTUP DIAGNOSTIC
# ============================================================
print("=" * 70)
print("🔧 RojgarNest SETTINGS LOADED")
print("=" * 70)
print(f"   Environment: {settings.ENVIRONMENT}")
print(f"   MOBILE_OTP_BYPASS: {settings.MOBILE_OTP_BYPASS}")
print(f"   📱 SMS Provider: {settings.SMS_PROVIDER} → Active: {settings.active_sms_provider}")
print(f"   💬 WhatsApp Provider: {settings.WHATSAPP_PROVIDER} → Active: {settings.active_whatsapp_provider}")
print(f"   📧 Email Provider: {settings.EMAIL_PROVIDER}")
print(f"   💳 Razorpay Mode: {settings.razorpay_mode_string}")
print(f"   💳 Razorpay Configured: {settings.is_razorpay_configured}")
print("-" * 70)
if settings.MOBILE_OTP_BYPASS:
    print(f"   🟢 MODE: DEVELOPMENT")
    print(f"      - SMS/WhatsApp: BYPASSED (use {settings.DEV_OTP_CODE})")
    print(f"      - Email: ALWAYS REAL")
else:
    print(f"   🔴 MODE: PRODUCTION")
    print(f"      - SMS/WhatsApp: REAL SEND")
    print(f"      - Email: ALWAYS REAL")
print("-" * 70)
print(f"   🗄️ Database: {'LOCAL' if settings.IS_LOCAL_DB else 'ATLAS' if settings.IS_ATLAS_DB else 'UNKNOWN'}")
print("=" * 70)