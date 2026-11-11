# app/modules/auth/schema.py - COMPLETE WITH BIOMETRIC SCHEMAS

from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional


class RegisterSchema(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    email: EmailStr
    mobile: str = Field(..., min_length=10, max_length=15)
    password: str = Field(..., min_length=8)

    @field_validator('password')
    @classmethod
    def validate_password_complexity(cls, v: str) -> str:
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain at least one number')
        if not any(c in '!@#$%^&*(),.?":{}|<>' for c in v):
            raise ValueError('Password must contain at least one special character')
        return v


class LoginSchema(BaseModel):
    email: EmailStr
    password: str


class LoginRequestSchema(BaseModel):
    email: EmailStr
    password: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    location_name: Optional[str] = None


class EmailSchema(BaseModel):
    email: EmailStr


class MobileSchema(BaseModel):
    mobile: str


class EmailOTPVerifySchema(BaseModel):
    email: EmailStr
    otp: str


class MobileOTPVerifySchema(BaseModel):
    mobile: str
    otp: str


class SetPinSchema(BaseModel):
    email: EmailStr
    pin: str = Field(..., min_length=6, max_length=6, pattern=r'^\d{6}$')


class PinLoginSchema(BaseModel):
    email: EmailStr
    pin: str = Field(..., min_length=6, max_length=6, pattern=r'^\d{6}$')
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    location_name: Optional[str] = None


# ==================== ✅ BIOMETRIC SCHEMAS ====================

class BiometricEnableSchema(BaseModel):
    """Schema for enabling/disabling biometric login"""
    email: EmailStr
    device_info: Optional[str] = Field(
        default=None,
        description="Device information (model, OS version)"
    )
    device_id: Optional[str] = Field(
        default=None,
        description="Unique device identifier"
    )
    biometric_type: Optional[str] = Field(
        default="fingerprint",
        pattern="^(fingerprint|face|iris|none)$",
        description="Type of biometric"
    )
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    location_name: Optional[str] = None


class BiometricLoginSchema(BaseModel):
    """Schema for biometric login"""
    email: EmailStr
    device_info: Optional[str] = None
    device_id: Optional[str] = None
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    location_name: Optional[str] = None


class ResetPasswordSchema(BaseModel):
    email: EmailStr
    new_password: str = Field(..., min_length=8)

    @field_validator('new_password')
    @classmethod
    def validate_new_password(cls, v: str) -> str:
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain at least one number')
        if not any(c in '!@#$%^&*(),.?":{}|<>' for c in v):
            raise ValueError('Password must contain at least one special character')
        return v


class RefreshSchema(BaseModel):
    refresh_token: str


class RoleUpdateSchema(BaseModel):
    email: EmailStr
    role: str = Field(..., pattern="^(user|admin|customadmin|superadmin)$")


class UserRoleResponseSchema(BaseModel):
    email: str
    name: str
    role: str
    is_active: bool
    last_login: Optional[str] = None