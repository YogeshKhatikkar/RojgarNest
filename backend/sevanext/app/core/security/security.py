# app/core/security.py

from passlib.context import CryptContext
from datetime import datetime, timedelta
from jose import jwt
from app.core.config.settings import settings  
import re
from fastapi import HTTPException

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ================= PASSWORD =================
def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def validate_password(password: str):
    if len(password) < 8:
        raise HTTPException(status_code=400, detail="Password must be at least 8 characters long")
    if not re.search(r"[A-Z]", password):
        raise HTTPException(status_code=400, detail="Password must contain at least 1 uppercase letter")
    if not re.search(r"[a-z]", password):
        raise HTTPException(status_code=400, detail="Password must contain at least 1 lowercase letter")
    if not re.search(r"[0-9]", password):
        raise HTTPException(status_code=400, detail="Password must contain at least 1 number")
    if not re.search(r"[!@#$%^&*(),.?\":{}|<>]", password):
        raise HTTPException(status_code=400, detail="Password must contain at least 1 special character")
    return True


# ================= PIN =================
def hash_pin(pin: str):
    return pwd_context.hash(pin)


def verify_pin(plain: str, hashed: str):
    return pwd_context.verify(plain, hashed)


# ================= TOKENS =================
# app/core/security.py

def create_access_token(data: dict):
    """Create access token with longer expiry for development"""
    to_encode = data.copy()
    
    # ================= DEVELOPMENT MODE =================
    if settings.ENVIRONMENT == "development" or settings.ACCESS_TOKEN_EXPIRE_MINUTES < 60:
        expire_minutes = 1440          # 24 hours for development
    else:
        expire_minutes = settings.ACCESS_TOKEN_EXPIRE_MINUTES
    
    expire = datetime.utcnow() + timedelta(minutes=expire_minutes)

    to_encode.update({
        "exp": expire, 
        "type": "access",
        "iat": datetime.utcnow()   # Issued at time (good practice)
    })
    
    return jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm="HS256")

def create_refresh_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire, "type": "refresh"})
    return jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm="HS256")