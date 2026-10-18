# app/models/auth_model.py - COMPLETE FIXED VERSION
# ✅ Biometric fields added - NEVER DELETED ON LOGOUT

from pydantic import BaseModel, EmailStr, Field, field_validator
from datetime import datetime
from typing import Optional, Dict, Any, List
from bson import ObjectId


class UserLocation(BaseModel):
    """User current location - stored in auth table"""
    latitude: float = Field(default=0.0, ge=-90, le=90)
    longitude: float = Field(default=0.0, ge=-180, le=180)
    location_name: str = Field(default="")
    city: Optional[str] = None
    district: Optional[str] = None
    state: Optional[str] = None
    country: str = "India"
    last_updated: datetime = Field(default_factory=datetime.utcnow)


class AuthModel(BaseModel):
    """User Authentication Model - Stores user's current location & biometric data"""
    
    # ==================== BASIC INFORMATION ====================
    name: str = Field(..., min_length=2, max_length=100)
    email: EmailStr
    phone: Optional[str] = Field(None, pattern=r'^\d{10}$')
    password: str
    
    # ==================== ROLE & STATUS ====================
    role: str = Field(default="user", pattern="^(user|admin|customadmin|superadmin)$")
    is_active: bool = True
    is_verified: bool = False
    
    # ==================== EMAIL & MOBILE VERIFICATION ====================
    is_email_verified: bool = False
    is_mobile_verified: bool = False
    email_otp: Optional[str] = None
    mobile_otp: Optional[str] = None
    email_otp_expiry: Optional[datetime] = None
    mobile_otp_expiry: Optional[datetime] = None
    email_otp_attempts: int = 0
    mobile_otp_attempts: int = 0
    
    # ==================== SECURITY FEATURES ====================
    pin: Optional[str] = None
    pin_attempts: int = 0
    is_pin_set: bool = False
    
    # ==================== ✅ BIOMETRIC FIELDS (PERMANENT) ====================
    is_biometric_enabled: bool = Field(default=False, description="Fingerprint login enabled")
    biometric_type: Optional[str] = Field(
        default=None,
        pattern="^(fingerprint|face|iris|none)$",
        description="Type of biometric used"
    )
    biometric_device_info: Optional[str] = Field(
        default=None,
        description="Device information for biometric"
    )
    biometric_device_id: Optional[str] = Field(
        default=None,
        description="Unique device ID for biometric"
    )
    biometric_enabled_at: Optional[datetime] = Field(
        default=None,
        description="When biometric was first enabled"
    )
    biometric_public_key: Optional[str] = Field(
        default=None,
        description="For future encryption"
    )
    biometric_login_history: List[Dict[str, Any]] = Field(
        default_factory=list,
        max_length=10,
        description="Last 10 biometric login attempts"
    )
    last_biometric_login: Optional[datetime] = Field(
        default=None,
        description="Last successful biometric login"
    )
    
    # ==================== PASSWORD RESET ====================
    reset_email_otp: Optional[str] = None
    reset_mobile_otp: Optional[str] = None
    reset_email_verified: bool = False
    reset_mobile_verified: bool = False
    reset_email_expiry: Optional[datetime] = None
    reset_mobile_expiry: Optional[datetime] = None
    reset_email_attempts: int = 0
    reset_mobile_attempts: int = 0
    
    # ==================== SESSION & SECURITY ====================
    failed_attempts: int = 0
    lock_until: Optional[datetime] = None
    last_login: Optional[datetime] = None
    last_login_ip: Optional[str] = None
    device_info: Optional[str] = None
    last_otp_sent: Optional[datetime] = None
    
    # ==================== LOCATION ====================
    current_location: Optional[UserLocation] = None
    last_location_update: Optional[datetime] = None
    
    # ==================== TIMESTAMPS ====================
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    role_updated_at: Optional[datetime] = None
    role_updated_by: Optional[str] = None
    
    @field_validator('email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        return v.lower().strip()
    
    @field_validator('phone')
    @classmethod
    def validate_phone(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            v = v.strip()
            if not v.isdigit() or len(v) != 10:
                raise ValueError('Phone number must be 10 digits')
        return v
    
    class Config:
        collection = "auth"
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }
        arbitrary_types_allowed = True