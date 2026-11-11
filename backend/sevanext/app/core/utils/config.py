# app/core/utils/config.py
"""
Application Configuration
"""

from pydantic_settings import BaseSettings
from typing import List, Optional
import json


class Settings(BaseSettings):
    # ================= CORE =================
    MONGO_URI: str = "mongodb://localhost:27017"
    DATABASE_NAME: str = "RojgarNest"
    ENVIRONMENT: str = "development"
    PORT: int = 8000

    # ================= SECURITY =================
    SECRET_KEY: str = "your-secret-key-change-in-production-minimum-32-chars"
    SESSION_SECRET_KEY: str = "your-session-secret-key-change-in-production"
    JWT_SECRET_KEY: str = "your-jwt-secret-key-change-in-production"
    ENCRYPTION_KEY: Optional[str] = None

    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # ================= REDIS =================
    REDIS_URL: Optional[str] = None

    # ================= SMTP =================
    SMTP_HOST: Optional[str] = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: Optional[str] = None
    SMTP_PASSWORD: Optional[str] = None
    SMTP_FROM: Optional[str] = None

    # ================= SMS =================
    TWILIO_ACCOUNT_SID: Optional[str] = None
    TWILIO_AUTH_TOKEN: Optional[str] = None
    TWILIO_PHONE: Optional[str] = None
    MOBILE_OTP_BYPASS: bool = True

    # ================= APP =================
    APP_BASE_URL: str = "http://localhost:8000"
    SECURE_FOLDER_PATH: str = "./secure"
    SECRET_TOKEN: Optional[str] = None

    # ================= APIs =================
    OPENAI_API_KEY: Optional[str] = None
    PROXY_POOL: Optional[str] = None
    CAPTCHA_API_KEY: Optional[str] = None
    DISABLE_AUTH: bool = False
    FAST2SMS_API_KEY: Optional[str] = None

    # Job APIs
    ADZUNA_APP_ID: Optional[str] = None
    ADZUNA_API_KEY: Optional[str] = None
    FREE_JOB_SEARCH_API_KEY: Optional[str] = None
    INFOTRIE_API_KEY: Optional[str] = None
    CORESIGNAL_API_KEY: Optional[str] = None

    # ================= CLOUDINARY =================
    CLOUDINARY_CLOUD_NAME: Optional[str] = None
    CLOUDINARY_API_KEY: Optional[str] = None
    CLOUDINARY_API_SECRET: Optional[str] = None

    # ================= BLOCKCHAIN =================
    WEB3_PROVIDER_URL: Optional[str] = None
    CONTRACT_ADDRESS: Optional[str] = None
    ISSUER_ADDRESS: Optional[str] = None

    # ================= STRIPE =================
    STRIPE_SECRET_KEY: Optional[str] = None
    STRIPE_PUBLISHABLE_KEY: Optional[str] = None

    # ================= CORS =================
    CORS_ORIGINS: List[str] = [
        "http://localhost",
        "http://127.0.0.1",
        "http://localhost:3000",
        "http://localhost:8000",
        "http://127.0.0.1:8000",
    ]

    class Config:
        env_file = ".env"
        extra = "ignore"
    
    def __init__(self, **data):
        super().__init__(**data)
        # Parse CORS_ORIGINS if it comes as string from env
        if isinstance(self.CORS_ORIGINS, str):
            try:
                self.CORS_ORIGINS = json.loads(self.CORS_ORIGINS)
            except:
                self.CORS_ORIGINS = [x.strip() for x in self.CORS_ORIGINS.split(",")]


# Create global settings instance
settings = Settings()