# app/modules/auth/service.py
# ============================================================
# ✅ EMAIL OTP: ALWAYS REAL (random 6-digit, sent via email)
# ✅ MOBILE OTP: Bypassed in DEV mode (use 123456), Real in PROD mode
# ✅ Terminal display of OTP status per channel
# ============================================================
# OTP behavior controlled from .env:
#   - MOBILE_OTP_BYPASS   → SMS/WhatsApp dev/prod switch
#     * true  → DEVELOPMENT MODE for SMS/WhatsApp
#               - Mobile OTP = DEV_OTP_CODE (123456)
#               - Email OTP = ALWAYS random 6-digit, ALWAYS sent for real
#               - Mobile verification accepts 123456 OR any 6-digit
#     * false → PRODUCTION MODE
#               - Both OTPs are random 6-digit
#               - Both SMS and Email sent for real
#   - DEV_OTP_CODE        → the dev MOBILE OTP value (default 123456)
#   - SMS_PROVIDER        → msg91 | twilio | fast2sms | brevo
#   - WHATSAPP_PROVIDER   → msg91 | twilio | meta | disabled
#   - EMAIL_PROVIDER      → smtp | brevo | sendgrid | mailgun
#   - NOTIFY_*_CHANNELS   → which channels get each notification type
# ============================================================

import secrets
from fastapi import HTTPException, Request, BackgroundTasks
from datetime import datetime, timedelta
from bson import ObjectId
from app.modules.auth.utils import generate_otp
from app.db.connection import get_db, connect_db

# ============================================================
# 📧📱💬 UNIFIED NOTIFICATION IMPORTS
# ============================================================
from app.core.services.email import send_email
from app.core.services.sms import send_mobile_otp

from app.core.services.notification_dispatcher import (
    dispatch_otp,
    dispatch_verification_success,
    dispatch_password_reset,
    dispatch_welcome,
)

from app.core.utils.logger import logger
from app.core.utils.otp_logger import otp_logger
from app.core.security import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    hash_pin,
    verify_pin,
    validate_password,
)
from jose import jwt, JWTError
from app.core.config.settings import settings
import hashlib
import hmac
import asyncio


# ============================================================
# ✅ OTP GENERATORS — SEPARATED FOR EMAIL AND MOBILE
# ============================================================
# 
# 📧 EMAIL OTP: ALWAYS random 6-digit, ALWAYS sent for real
#               (never uses DEV_OTP_CODE, never bypassed)
#
# 📱 MOBILE OTP:
#   MOBILE_OTP_BYPASS = true  → returns DEV_OTP_CODE (123456)
#   MOBILE_OTP_BYPASS = false → returns random 6-digit
#
# ============================================================

def get_mobile_otp() -> str:
    """
    Return the mobile OTP for the current mode.

    MOBILE_OTP_BYPASS = true  → return DEV_OTP_CODE from .env (default '123456')
    MOBILE_OTP_BYPASS = false → generate a real random 6-digit OTP
    """
    if settings.MOBILE_OTP_BYPASS:
        # DEVELOPMENT MODE - Use fixed OTP from .env for MOBILE only
        code = settings.dev_otp_value
        return code
    else:
        # PRODUCTION MODE - Generate random OTP
        otp = generate_otp()
        return otp


def get_email_otp() -> str:
    """
    Return the email OTP.

    ✅ EMAIL IS ALWAYS REAL - ALWAYS generates a random 6-digit OTP.
    ✅ This is NEVER bypassed, regardless of MOBILE_OTP_BYPASS setting.
    ✅ The OTP is stored as a hash in the database.
    ✅ The actual OTP is sent via email (always real).
    """
    otp = generate_otp()
    return otp


def is_valid_mobile_otp(user: dict, provided_otp: str, field_prefix: str = "mobile_otp") -> bool:
    """
    Validate the provided MOBILE OTP against the stored hash.

    MOBILE_OTP_BYPASS = true  → Accept DEV_OTP_CODE OR any 6-digit OTP
    MOBILE_OTP_BYPASS = false → Accept ONLY the real stored OTP

    `field_prefix` lets us reuse this for `reset_mobile_otp` too.
    """
    if not provided_otp:
        return False

    # ============================================================
    # DEVELOPMENT MODE - Accept dev OTP or any 6-digit OTP for MOBILE
    # ============================================================
    if settings.MOBILE_OTP_BYPASS:
        # Accept the dev OTP (default: 123456)
        if provided_otp == settings.dev_otp_value:
            logger.info("🔧 [DEV MODE] Mobile OTP verified via .env DEV_OTP_CODE")
            return True
        
        # Also accept any 6-digit OTP in dev mode for convenience
        if len(provided_otp) == 6 and provided_otp.isdigit():
            logger.info("🔧 [DEV MODE] Mobile OTP verified (any 6-digit accepted)")
            return True
        
        logger.warning(f"❌ [DEV MODE] Invalid OTP format: {provided_otp}")
        return False

    # ============================================================
    # PRODUCTION MODE - Only exact match with stored hash
    # ============================================================
    stored = user.get(field_prefix)
    ok = verify_hashed_otp(stored, provided_otp)
    if ok:
        logger.info("🔐 [PROD MODE] Mobile OTP verified (real OTP match)")
    else:
        logger.warning("❌ [PROD MODE] Mobile OTP mismatch")
    return ok


def is_valid_email_otp(user: dict, provided_otp: str, field_prefix: str = "email_otp") -> bool:
    """
    Validate the provided EMAIL OTP against the stored hash.

    ✅ EMAIL IS ALWAYS REAL - Only the real stored OTP works.
    ✅ DEV_OTP_CODE (123456) does NOT work for email even in dev mode.
    ✅ The email OTP is always a random 6-digit sent via email.
    """
    if not provided_otp:
        return False

    # ============================================================
    # EMAIL OTP IS ALWAYS REAL - Only exact match with stored hash
    # ============================================================
    stored = user.get(field_prefix)
    ok = verify_hashed_otp(stored, provided_otp)
    if ok:
        logger.info("✅ [EMAIL] Email OTP verified (real OTP match)")
    else:
        logger.warning("❌ [EMAIL] Email OTP mismatch")
    return ok


# ================= DATABASE HELPER (SAFE) =================
async def get_db_safe():
    """Get database connection safely."""
    db = get_db()
    if db is None:
        logger.warning("⚠️ Database not initialized! Attempting to connect...")
        try:
            await connect_db()
            db = get_db()
            if db is None:
                raise HTTPException(
                    status_code=500,
                    detail="Database connection failed after retry"
                )
        except Exception as e:
            logger.error(f"❌ Failed to connect to database: {e}")
            raise HTTPException(status_code=500, detail="Database connection failed")
    return db


# ================= OTP HELPERS =================
def hash_otp(otp: str) -> str:
    return hashlib.sha256(otp.encode()).hexdigest()


def verify_hashed_otp(stored: str, provided: str) -> bool:
    if not stored or not provided:
        return False
    return hmac.compare_digest(stored, hash_otp(provided.strip()))


# ================= ASYNC TASK WRAPPERS =================
def _run_async_dispatch_otp(
    email: str,
    mobile: str,
    email_otp: str,
    mobile_otp: str,
    purpose: str,
    user_name: str
):
    """
    Sync wrapper for dispatch_otp — used in BackgroundTasks.
    
    NOTE: Now passes BOTH email_otp and mobile_otp separately.
    """
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            loop.run_until_complete(
                dispatch_otp(
                    email=email,
                    mobile=mobile,
                    otp=email_otp,  # Default
                    purpose=purpose,
                    user_name=user_name,
                    email_otp=email_otp,
                    mobile_otp=mobile_otp,
                )
            )
        finally:
            loop.close()
    except Exception as e:
        logger.error(f"❌ dispatch_otp background task failed: {e}")


def _run_async_dispatch_verification(
    email: str, mobile: str, user_name: str, verified_field: str = "Email"
):
    """Sync wrapper for dispatch_verification_success."""
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            loop.run_until_complete(
                dispatch_verification_success(
                    email=email,
                    mobile=mobile,
                    user_name=user_name,
                    verified_field=verified_field,
                )
            )
        finally:
            loop.close()
    except Exception as e:
        logger.error(f"❌ dispatch_verification_success background task failed: {e}")


def _run_async_dispatch_welcome(email: str, mobile: str, user_name: str):
    """Sync wrapper for dispatch_welcome."""
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            loop.run_until_complete(
                dispatch_welcome(email=email, mobile=mobile, user_name=user_name)
            )
        finally:
            loop.close()
    except Exception as e:
        logger.error(f"❌ dispatch_welcome background task failed: {e}")


# ============================================================
# REGISTER
# ============================================================
async def register_user(data, background_tasks: BackgroundTasks, role: str = "user"):
    db = await get_db_safe()
    validate_password(data.password)

    email_lower = data.email.lower().strip()
    allowed_roles = ["user", "admin", "customadmin"]
    if role not in allowed_roles:
        role = "user"

    if await db.auth.find_one({"email": email_lower}):
        raise HTTPException(400, "Email already registered")
    if await db.auth.find_one({"mobile": data.mobile}):
        raise HTTPException(400, "Mobile already registered")

    # ============================================================
    # ✅ OTP GENERATION — SEPARATED FOR EMAIL AND MOBILE
    # ============================================================
    email_otp = get_email_otp()      # ✅ ALWAYS random
    mobile_otp = get_mobile_otp()    # 123456 in dev, random in prod

    # ✅ Log OTP generation to terminal
    mode = "DEVELOPMENT" if settings.MOBILE_OTP_BYPASS else "PRODUCTION"
    otp_logger.log_otp_generation(
        purpose="registration",
        email_otp=email_otp,
        mobile_otp=mobile_otp,
        mode=mode,
    )

    user_data = {
        "name": data.name.strip(),
        "email": email_lower,
        "mobile": data.mobile.strip(),
        "password": hash_password(data.password),
        "role": role,
        "is_email_verified": False,
        "is_mobile_verified": False,
        "email_otp": hash_otp(email_otp),
        "mobile_otp": hash_otp(mobile_otp),
        "email_otp_attempts": 0,
        "mobile_otp_attempts": 0,
        "email_otp_expiry": datetime.utcnow() + timedelta(minutes=10),
        "mobile_otp_expiry": datetime.utcnow() + timedelta(minutes=10),
        "failed_attempts": 0,
        "created_at": datetime.utcnow()
    }
    await db.auth.insert_one(user_data)

    # ============================================================
    # ✅ DISPATCH OTP with Terminal Display
    # ============================================================
    background_tasks.add_task(
        _run_async_dispatch_otp,
        data.email,
        data.mobile,
        email_otp,
        mobile_otp,
        "registration",
        data.name,
    )

    if settings.MOBILE_OTP_BYPASS:
        msg = f"Email OTP sent for real. Mobile verification uses DEV_OTP_CODE ({settings.dev_otp_value})."
    else:
        msg = "OTP sent successfully to email, mobile, and WhatsApp."

    return {"msg": msg, "role": role, "dev_mode": settings.MOBILE_OTP_BYPASS}


# ============================================================
# MPIN SETUP
# ============================================================
async def setup_mpin_service(data, current_user):
    db = await get_db_safe()
    logger.info(f"🔐 MPIN Setup Request - Email: {data.email}")

    user = await db.auth.find_one({"email": data.email})
    if not user:
        raise HTTPException(404, "User not found")

    if str(user["_id"]) != current_user.get("user_id"):
        raise HTTPException(403, "Unauthorized")

    if len(data.pin) != 6 or not data.pin.isdigit():
        raise HTTPException(400, "PIN must be 6 digits")

    result = await db.auth.update_one(
        {"email": data.email},
        {"$set": {"pin": hash_pin(data.pin), "is_pin_set": True, "pin_attempts": 0}}
    )

    if result.modified_count == 0:
        raise HTTPException(500, "Failed to set MPIN")

    logger.info(f"✅ MPIN set successfully for {data.email}")
    return {"msg": "MPIN setup successfully", "success": True}


# ============================================================
# ENABLE BIOMETRIC
# ============================================================
async def enable_biometric_service(data: dict, current_user):
    db = await get_db_safe()
    user = await db.auth.find_one({"email": data.get("email")})
    if not user or str(user["_id"]) != current_user.get("user_id"):
        raise HTTPException(403, "Unauthorized")

    await db.auth.update_one(
        {"email": data.get("email")},
        {"$set": {
            "is_biometric_enabled": True,
            "biometric_device_info": data.get("device_info")
        }}
    )
    return {"msg": "Biometric login enabled successfully"}


# ============================================================
# MPIN LOGIN
# ============================================================
async def login_pin(data, request: Request = None):
    db = await get_db_safe()
    user = await db.auth.find_one({"email": data.email})
    if not user:
        raise HTTPException(404, "User not found")

    if not user.get("is_pin_set"):
        raise HTTPException(400, "MPIN not set. Please setup MPIN first.")

    if user.get("pin_attempts", 0) >= 5:
        raise HTTPException(403, "Too many failed attempts. Account locked.")

    if not verify_pin(data.pin, user["pin"]):
        attempts = user.get("pin_attempts", 0) + 1
        update_data = {"pin_attempts": attempts}
        if attempts >= 5:
            update_data["lock_until"] = datetime.utcnow() + timedelta(minutes=30)
        await db.auth.update_one({"email": data.email}, {"$set": update_data})
        raise HTTPException(400, f"Invalid MPIN. {5 - attempts} attempts remaining.")

    # Location handling
    location_doc = None
    if hasattr(data, 'latitude') and data.latitude is not None and data.latitude != 0:
        from app.core.location.location_handler import location_handler
        location_data = await location_handler.get_location_name(data.latitude, data.longitude)
        location_doc = {
            "latitude": data.latitude,
            "longitude": data.longitude,
            "location_name": data.location_name or location_data.get(
                "location_name", f"{data.latitude}, {data.longitude}"
            ),
            "city": location_data.get("city", ""),
            "district": location_data.get("district", ""),
            "state": location_data.get("state", ""),
            "country": location_data.get("country", "India"),
            "last_updated": datetime.utcnow()
        }
        await db.auth.update_one(
            {"email": data.email},
            {"$set": {
                "current_location": location_doc,
                "last_location_update": datetime.utcnow()
            }}
        )
    else:
        location_doc = user.get("current_location")

    await db.auth.update_one(
        {"email": data.email},
        {"$set": {
            "pin_attempts": 0,
            "last_login": datetime.utcnow(),
            "last_login_ip": request.client.host if request else ""
        }}
    )

    profile = await db.profile.find_one({"email": data.email})
    mobile = user.get("mobile", "")
    if not mobile and profile:
        mobile = profile.get("phone", "")
    full_name = profile.get("full_name", "") if profile else ""
    if not full_name:
        full_name = user.get("name", "")

    access_token = create_access_token({
        "user_id": str(user["_id"]),
        "role": user["role"],
        "email": user["email"],
        "name": full_name
    })
    refresh_token = create_refresh_token({"user_id": str(user["_id"])})

    await db.sessions.insert_one({
        "user_id": str(user["_id"]),
        "user_email": user["email"],
        "session_hash": secrets.token_hex(32),
        "ip": request.client.host if request else "",
        "device": request.headers.get("user-agent", "Unknown") if request else "Unknown",
        "created_at": datetime.utcnow(),
        "expires_at": datetime.utcnow() + timedelta(days=3),
        "is_active": True
    })

    logger.info(f"✅ MPIN Login successful for {data.email}")

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "role": user["role"],
        "email": user["email"],
        "name": full_name,
        "mobile": mobile,
        "current_location": location_doc if location_doc else user.get("current_location")
    }


# ============================================================
# BIOMETRIC LOGIN
# ============================================================
async def biometric_login_service(data, request: Request):
    db = await get_db_safe()
    user = await db.auth.find_one({"email": data.email})
    if not user:
        raise HTTPException(404, "User not found")

    if not user.get("is_biometric_enabled"):
        raise HTTPException(
            400, "Biometric not enabled. Please enable it in settings."
        )

    location_doc = None
    if data.latitude is not None and data.longitude is not None and data.latitude != 0:
        from app.core.location.location_handler import location_handler
        location_data = await location_handler.get_location_name(
            data.latitude, data.longitude
        )
        location_doc = {
            "latitude": data.latitude,
            "longitude": data.longitude,
            "location_name": data.location_name or location_data.get(
                "location_name", f"{data.latitude}, {data.longitude}"
            ),
            "city": location_data.get("city", ""),
            "district": location_data.get("district", ""),
            "state": location_data.get("state", ""),
            "country": location_data.get("country", "India"),
            "last_updated": datetime.utcnow()
        }
        await db.auth.update_one(
            {"email": data.email},
            {"$set": {
                "current_location": location_doc,
                "last_location_update": datetime.utcnow()
            }}
        )
    else:
        location_doc = user.get("current_location")

    await db.auth.update_one(
        {"email": data.email},
        {"$set": {
            "last_login": datetime.utcnow(),
            "last_login_ip": request.client.host if request else ""
        }}
    )

    profile = await db.profile.find_one({"email": data.email})
    mobile = user.get("mobile", "")
    if not mobile and profile:
        mobile = profile.get("phone", "")
    full_name = profile.get("full_name", "") if profile else ""
    if not full_name:
        full_name = user.get("name", "")

    access_token = create_access_token({
        "user_id": str(user["_id"]),
        "role": user["role"],
        "email": user["email"],
        "name": full_name
    })
    refresh_token = create_refresh_token({"user_id": str(user["_id"])})

    await db.sessions.insert_one({
        "user_id": str(user["_id"]),
        "user_email": user["email"],
        "session_hash": secrets.token_hex(32),
        "ip": request.client.host if request else "",
        "device": request.headers.get("user-agent", "Unknown") if request else "Unknown",
        "created_at": datetime.utcnow(),
        "expires_at": datetime.utcnow() + timedelta(days=3),
        "is_active": True
    })

    logger.info(f"✅ Biometric Login successful for {data.email}")

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "role": user["role"],
        "email": user["email"],
        "name": full_name,
        "mobile": mobile,
        "current_location": location_doc if location_doc else user.get("current_location")
    }


# ============================================================
# SET PIN (LEGACY)
# ============================================================
async def set_pin(data):
    db = await get_db_safe()
    if len(data.pin) != 6 or not data.pin.isdigit():
        raise HTTPException(400, "PIN must be 6 digits")
    await db.auth.update_one(
        {"email": data.email},
        {"$set": {"pin": hash_pin(data.pin), "is_pin_set": True, "pin_attempts": 0}}
    )
    return {"msg": "PIN set"}


# ============================================================
# RESEND EMAIL OTP
# ============================================================
async def send_email_otp_service(email: str, background_tasks: BackgroundTasks):
    db = await get_db_safe()
    user = await db.auth.find_one({"email": email})
    if not user:
        raise HTTPException(404, "User not found")
    if user.get("last_otp_sent") and datetime.utcnow() < user["last_otp_sent"] + timedelta(seconds=30):
        raise HTTPException(429, "Wait 30 seconds before resending")

    # ✅ EMAIL OTP IS ALWAYS REAL - always random
    otp = get_email_otp()
    
    # Get current mobile OTP (keep existing if present)
    mobile_otp = get_mobile_otp()
    
    await db.auth.update_one(
        {"email": email},
        {"$set": {
            "email_otp": hash_otp(otp),
            "mobile_otp": hash_otp(mobile_otp),
            "email_otp_expiry": datetime.utcnow() + timedelta(minutes=10),
            "mobile_otp_expiry": datetime.utcnow() + timedelta(minutes=10),
            "email_otp_attempts": 0,
            "mobile_otp_attempts": 0,
            "last_otp_sent": datetime.utcnow()
        }}
    )

    mobile = user.get("mobile", "")
    
    # ✅ Log generation to terminal
    mode = "DEVELOPMENT" if settings.MOBILE_OTP_BYPASS else "PRODUCTION"
    otp_logger.log_otp_generation(
        purpose="email resend",
        email_otp=otp,
        mobile_otp=mobile_otp,
        mode=mode,
    )
    
    background_tasks.add_task(
        _run_async_dispatch_otp,
        email,
        mobile,
        otp,
        mobile_otp,
        "email verification",
        user.get("name", "User"),
    )

    logger.info(f"✅ Email OTP resent to {email} (ALWAYS REAL)")
    return {"msg": "OTP resent successfully to your email"}


# ============================================================
# RESEND MOBILE OTP
# ============================================================
async def send_mobile_otp_service(mobile: str, background_tasks: BackgroundTasks):
    db = await get_db_safe()
    user = await db.auth.find_one({"mobile": mobile})
    if not user:
        raise HTTPException(404, "User not found")
    if user.get("last_otp_sent") and datetime.utcnow() < user["last_otp_sent"] + timedelta(seconds=30):
        raise HTTPException(429, "Wait 30 seconds before resending")

    # ✅ MOBILE OTP: 123456 in dev, random in prod
    mobile_otp = get_mobile_otp()
    email_otp = get_email_otp()  # Also get a fresh email OTP

    await db.auth.update_one(
        {"mobile": mobile},
        {"$set": {
            "mobile_otp": hash_otp(mobile_otp),
            "email_otp": hash_otp(email_otp),
            "mobile_otp_expiry": datetime.utcnow() + timedelta(minutes=10),
            "email_otp_expiry": datetime.utcnow() + timedelta(minutes=10),
            "mobile_otp_attempts": 0,
            "email_otp_attempts": 0,
            "last_otp_sent": datetime.utcnow()
        }}
    )

    email = user.get("email", "")
    
    # ✅ Log generation to terminal
    mode = "DEVELOPMENT" if settings.MOBILE_OTP_BYPASS else "PRODUCTION"
    otp_logger.log_otp_generation(
        purpose="mobile resend",
        email_otp=email_otp,
        mobile_otp=mobile_otp,
        mode=mode,
    )
    
    background_tasks.add_task(
        _run_async_dispatch_otp,
        email,
        mobile,
        email_otp,
        mobile_otp,
        "mobile verification",
        user.get("name", "User"),
    )

    if settings.MOBILE_OTP_BYPASS:
        return {"msg": f"Mobile verification uses DEV_OTP_CODE ({settings.dev_otp_value})"}
    else:
        return {"msg": "Mobile OTP resent successfully"}


# ============================================================
# VERIFY EMAIL OTP
# ============================================================
async def verify_email_otp(data):
    db = await get_db_safe()
    user = await db.auth.find_one({"email": data.email})
    if not user:
        raise HTTPException(404, "User not found")
    if not user.get("email_otp_expiry") or datetime.utcnow() > user["email_otp_expiry"]:
        raise HTTPException(400, "OTP expired")
    if user.get("email_otp_attempts", 0) >= 5:
        raise HTTPException(429, "Too many attempts")
    
    # ✅ EMAIL OTP IS ALWAYS REAL - only accepts real OTP
    is_valid = is_valid_email_otp(user, data.otp, field_prefix="email_otp")
    
    if not is_valid:
        await db.auth.update_one(
            {"email": data.email},
            {"$inc": {"email_otp_attempts": 1}}
        )
        raise HTTPException(400, "Invalid OTP")
    
    await db.auth.update_one(
        {"email": data.email},
        {"$set": {
            "is_email_verified": True,
            "email_otp": None,
            "email_otp_expiry": None
        }}
    )
    return {"msg": "Email verified"}


# ============================================================
# VERIFY MOBILE OTP
# ============================================================
async def verify_mobile_otp(data):
    db = await get_db_safe()
    user = await db.auth.find_one({"mobile": data.mobile})
    if not user:
        raise HTTPException(404, "User not found")
    if not user.get("mobile_otp_expiry") or datetime.utcnow() > user["mobile_otp_expiry"]:
        raise HTTPException(400, "OTP expired")
    if user.get("mobile_otp_attempts", 0) >= 5:
        raise HTTPException(429, "Too many attempts")

    # ✅ MOBILE OTP: dev code OR real hash
    if not is_valid_mobile_otp(user, data.otp, field_prefix="mobile_otp"):
        await db.auth.update_one(
            {"mobile": data.mobile},
            {"$inc": {"mobile_otp_attempts": 1}}
        )
        raise HTTPException(400, "Invalid OTP")

    await db.auth.update_one(
        {"mobile": data.mobile},
        {"$set": {
            "is_mobile_verified": True,
            "mobile_otp": None,
            "mobile_otp_expiry": None,
            "mobile_otp_attempts": 0
        }}
    )
    return {"msg": "Mobile verified successfully"}


# ============================================================
# LOGIN (Email + Password) - COMPLETE FIXED WITH LOCK INFO
# ============================================================
async def login_user(data, request: Request):
    """
    Login with email and password.
    
    Returns lock info if account is locked:
    - lock_until: ISO timestamp when account unlocks
    - seconds_remaining: seconds until unlock
    - failed_attempts: current failed attempts count
    """
    db = await get_db_safe()
    email_lower = data.email.lower().strip()

    user = await db.auth.find_one({"email": email_lower})
    if not user:
        logger.warning(f"❌ Login failed: User not found - {email_lower}")
        raise HTTPException(
            status_code=400,
            detail="Invalid email or password"
        )

    # ============================================================
    # ✅ CHECK IF ACCOUNT IS LOCKED
    # ============================================================
    lock_until = user.get("lock_until")
    if lock_until:
        now = datetime.utcnow()
        
        # Ensure lock_until is timezone-naive
        if lock_until.tzinfo is not None:
            lock_until = lock_until.replace(tzinfo=None)
        
        if now < lock_until:
            # ✅ Account IS still locked
            seconds_remaining = int((lock_until - now).total_seconds())
            
            logger.warning(
                f"🔒 Login blocked - Account locked for {seconds_remaining}s "
                f"- {email_lower}"
            )
            
            # ✅ Return DETAILED lock info
            raise HTTPException(
                status_code=403,
                detail={
                    "code": "ACCOUNT_LOCKED",
                    "message": f"Account temporarily locked. Please try again after {seconds_remaining} seconds.",
                    "lock_until": lock_until.isoformat(),
                    "seconds_remaining": seconds_remaining,
                    "failed_attempts": user.get("failed_attempts", 0),
                    "email": email_lower,
                }
            )
        else:
            # ✅ Lock expired - auto-unlock
            logger.info(f"🔓 Auto-unlocking expired account: {email_lower}")
            await db.auth.update_one(
                {"email": email_lower},
                {
                    "$set": {
                        "failed_attempts": 0,
                        "lock_until": None,
                        "updated_at": datetime.utcnow()
                    }
                }
            )
            # Refresh user data
            user = await db.auth.find_one({"email": email_lower})
            if not user:
                raise HTTPException(status_code=400, detail="User not found")

    # ============================================================
    # ✅ CHECK EMAIL VERIFICATION
    # ============================================================
    if not user.get("is_email_verified", False):
        raise HTTPException(
            status_code=403,
            detail={
                "code": "EMAIL_NOT_VERIFIED",
                "message": "Please verify your email first. Check your inbox for OTP.",
                "email": email_lower,
            }
        )

    if not user.get("is_mobile_verified", False):
        raise HTTPException(
            status_code=403,
            detail={
                "code": "MOBILE_NOT_VERIFIED",
                "message": "Please verify your mobile number first.",
                "email": email_lower,
            }
        )

    # ============================================================
    # ✅ CHECK PASSWORD
    # ============================================================
    if not verify_password(data.password, user["password"]):
        attempts = user.get("failed_attempts", 0) + 1
        max_attempts = 5
        
        update_data = {
            "failed_attempts": attempts,
            "last_failed_login": datetime.utcnow()
        }
        
        # ✅ Lock account if max attempts exceeded
        if attempts >= max_attempts:
            lock_until_new = datetime.utcnow() + timedelta(minutes=30)
            update_data["lock_until"] = lock_until_new
            
            await db.auth.update_one(
                {"email": email_lower},
                {"$set": update_data}
            )
            
            logger.warning(
                f"🔒 Account LOCKED for 30 minutes: {email_lower} "
                f"(attempts: {attempts})"
            )
            
            raise HTTPException(
                status_code=403,
                detail={
                    "code": "ACCOUNT_LOCKED",
                    "message": f"Too many failed attempts. Account locked for 30 minutes.",
                    "lock_until": lock_until_new.isoformat(),
                    "seconds_remaining": 1800,  # 30 minutes in seconds
                    "failed_attempts": attempts,
                    "email": email_lower,
                }
            )
        
        await db.auth.update_one(
            {"email": email_lower},
            {"$set": update_data}
        )
        
        remaining = max_attempts - attempts
        logger.warning(
            f"❌ Wrong password for {email_lower}. "
            f"Attempts: {attempts}/{max_attempts}"
        )
        
        raise HTTPException(
            status_code=400,
            detail={
                "code": "INVALID_PASSWORD",
                "message": f"Invalid password. {remaining} attempts remaining.",
                "remaining_attempts": remaining,
                "failed_attempts": attempts,
            }
        )

    # ============================================================
    # ✅ SUCCESSFUL LOGIN
    # ============================================================
    user_role = user.get("role", "user")
    if user_role == "custom_admin":
        user_role = "customadmin"

    # Reset failed attempts and lock
    await db.auth.update_one(
        {"email": email_lower},
        {
            "$set": {
                "failed_attempts": 0,
                "lock_until": None,
                "last_login": datetime.utcnow(),
                "last_login_ip": request.client.host if request.client else "",
                "updated_at": datetime.utcnow()
            }
        }
    )

    profile = await db.profile.find_one({"email": email_lower})
    mobile = user.get("mobile", "")
    if not mobile and profile:
        mobile = profile.get("phone", "")
    full_name = profile.get("full_name", "") if profile else ""
    if not full_name:
        full_name = user.get("name", "")

    payload = {
        "user_id": str(user["_id"]),
        "role": user_role,
        "email": user["email"],
        "name": full_name
    }
    access = create_access_token(payload)
    refresh = create_refresh_token({"user_id": str(user["_id"])})

    await db.sessions.insert_one({
        "user_id": str(user["_id"]),
        "user_email": user["email"],
        "role": user_role,
        "session_hash": secrets.token_hex(32),
        "refresh_token": refresh,
        "ip": request.client.host if request.client else "",
        "device": request.headers.get("user-agent", "Unknown"),
        "created_at": datetime.utcnow(),
        "expires_at": datetime.utcnow() + timedelta(days=7),
        "is_active": True
    })

    logger.info(f"✅ Login successful for {email_lower}")

    return {
        "access_token": access,
        "refresh_token": refresh,
        "role": user_role,
        "email": user["email"],
        "name": full_name,
        "mobile": mobile
    }


# ============================================================
# REFRESH TOKEN
# ============================================================
async def refresh_access_token(data):
    try:
        payload = jwt.decode(
            data.refresh_token,
            settings.JWT_SECRET_KEY,
            algorithms=["HS256"]
        )
        if payload.get("type") != "refresh":
            raise HTTPException(401, "Invalid refresh token")
        user_id = payload.get("user_id")
        db = await get_db_safe()
        session = await db.sessions.find_one({
            "user_id": user_id,
            "refresh_token": data.refresh_token
        })
        if not session:
            raise HTTPException(401, "Session expired")
        user = await db.auth.find_one({"_id": ObjectId(user_id)})
        user_role = user.get("role", "user") if user else "user"
        new_access = create_access_token({
            "user_id": user_id,
            "role": user_role,
            "email": user.get("email") if user else None
        })
        return {"access_token": new_access}
    except JWTError:
        raise HTTPException(401, "Invalid refresh token")


# ============================================================
# FORGOT PASSWORD
# ============================================================
async def forgot_password(email: str, background_tasks: BackgroundTasks):
    db = await get_db_safe()
    email_lower = email.lower().strip()
    user = await db.auth.find_one({"email": email_lower})

    if not user:
        raise HTTPException(400, "Invalid email")

    user_mobile = user.get("mobile")
    if not user_mobile:
        profile = await db.profile.find_one({"email": email_lower})
        if profile:
            user_mobile = profile.get("phone") or profile.get("mobile")
            if user_mobile:
                await db.auth.update_one(
                    {"email": email_lower},
                    {"$set": {"mobile": user_mobile}}
                )

    # ============================================================
    # Generate OTPs
    # ============================================================
    email_otp = get_email_otp()  # ✅ ALWAYS random
    mobile_otp = get_mobile_otp() if user_mobile else ""  # 123456 in dev
    
    # ✅ Log generation to terminal
    mode = "DEVELOPMENT" if settings.MOBILE_OTP_BYPASS else "PRODUCTION"
    otp_logger.log_otp_generation(
        purpose="password reset",
        email_otp=email_otp,
        mobile_otp=mobile_otp or "N/A",
        mode=mode,
    )

    # Case: no mobile → email-only reset
    if not user_mobile:
        await db.auth.update_one(
            {"email": email_lower},
            {"$set": {
                "reset_email_otp": hash_otp(email_otp),
                "reset_email_verified": False,
                "reset_email_expiry": datetime.utcnow() + timedelta(minutes=10),
                "last_otp_sent": datetime.utcnow(),
                "reset_mobile_verified": True
            }}
        )

        background_tasks.add_task(
            _run_async_dispatch_otp,
            email_lower,
            "",
            email_otp,
            "",
            "password reset",
            user.get("name", "User"),
        )

        return {
            "msg": "Reset OTP sent to your email",
            "email": email_lower,
            "mobile": None,
            "mobile_missing": True
        }

    # Case: mobile present
    await db.auth.update_one(
        {"email": email_lower},
        {"$set": {
            "reset_email_otp": hash_otp(email_otp),
            "reset_mobile_otp": hash_otp(mobile_otp),
            "reset_email_verified": False,
            "reset_mobile_verified": False,
            "reset_email_expiry": datetime.utcnow() + timedelta(minutes=10),
            "reset_mobile_expiry": datetime.utcnow() + timedelta(minutes=10),
            "last_otp_sent": datetime.utcnow()
        }}
    )

    background_tasks.add_task(
        _run_async_dispatch_otp,
        email_lower,
        user_mobile,
        email_otp,
        mobile_otp,
        "password reset",
        user.get("name", "User"),
    )

    return {
        "msg": "Reset OTP sent to your email, mobile, and WhatsApp",
        "email": email_lower,
        "mobile": user_mobile,
        "mobile_missing": False
    }


# ============================================================
# RESEND RESET OTP
# ============================================================
async def resend_reset_email_otp_service(email: str, background_tasks: BackgroundTasks):
    db = await get_db_safe()
    user = await db.auth.find_one({"email": email})
    if not user:
        raise HTTPException(404, "User not found")
    if user.get("last_otp_sent") and datetime.utcnow() < user["last_otp_sent"] + timedelta(seconds=30):
        raise HTTPException(429, "Wait 30 seconds before resending")

    otp = get_email_otp()  # ✅ ALWAYS random
    
    await db.auth.update_one(
        {"email": email},
        {"$set": {
            "reset_email_otp": hash_otp(otp),
            "reset_email_expiry": datetime.utcnow() + timedelta(minutes=10),
            "reset_email_attempts": 0,
            "reset_email_verified": False,
            "last_otp_sent": datetime.utcnow()
        }}
    )

    mobile = user.get("mobile", "")
    
    # ✅ Log generation
    mode = "DEVELOPMENT" if settings.MOBILE_OTP_BYPASS else "PRODUCTION"
    otp_logger.log_otp_generation(
        purpose="reset email resend",
        email_otp=otp,
        mobile_otp="N/A (email only)",
        mode=mode,
    )
    
    background_tasks.add_task(
        _run_async_dispatch_otp,
        email,
        mobile,
        otp,
        "",
        "password reset",
        user.get("name", "User"),
    )

    return {"msg": "Reset OTP resent successfully"}


async def resend_reset_mobile_otp_service(mobile: str, background_tasks: BackgroundTasks):
    db = await get_db_safe()
    user = await db.auth.find_one({"mobile": mobile})
    if not user:
        raise HTTPException(404, "User not found")
    if user.get("last_otp_sent") and datetime.utcnow() < user["last_otp_sent"] + timedelta(seconds=30):
        raise HTTPException(429, "Wait 30 seconds before resending")

    otp = get_mobile_otp()  # ✅ 123456 in dev, random in prod
    email_otp = get_email_otp()
    
    await db.auth.update_one(
        {"mobile": mobile},
        {"$set": {
            "reset_mobile_otp": hash_otp(otp),
            "reset_email_otp": hash_otp(email_otp),
            "reset_mobile_expiry": datetime.utcnow() + timedelta(minutes=10),
            "reset_email_expiry": datetime.utcnow() + timedelta(minutes=10),
            "reset_mobile_attempts": 0,
            "reset_email_attempts": 0,
            "reset_mobile_verified": False,
            "reset_email_verified": False,
            "last_otp_sent": datetime.utcnow()
        }}
    )

    email = user.get("email", "")
    
    # ✅ Log generation
    mode = "DEVELOPMENT" if settings.MOBILE_OTP_BYPASS else "PRODUCTION"
    otp_logger.log_otp_generation(
        purpose="reset mobile resend",
        email_otp=email_otp,
        mobile_otp=otp,
        mode=mode,
    )
    
    background_tasks.add_task(
        _run_async_dispatch_otp,
        email,
        mobile,
        email_otp,
        otp,
        "password reset",
        user.get("name", "User"),
    )

    return {"msg": "Reset Mobile OTP resent successfully"}


# ============================================================
# VERIFY RESET EMAIL OTP - FIXED (Don't clear OTP)
# ============================================================
async def verify_reset_email_otp(data):
    db = await get_db_safe()
    user = await db.auth.find_one({"email": data.email})
    if not user:
        raise HTTPException(404, "User not found")
    
    # ✅ Check if already verified (allow re-verification)
    if user.get("reset_email_verified") == True:
        logger.info(f"✅ Email already verified for {data.email}")
        return {"msg": "Reset Email OTP already verified"}
    
    if not user.get("reset_email_expiry") or datetime.utcnow() > user["reset_email_expiry"]:
        raise HTTPException(400, "Reset Email OTP expired")
    if user.get("reset_email_attempts", 0) >= 5:
        raise HTTPException(429, "Too many attempts")

    is_valid = is_valid_email_otp(user, data.otp, field_prefix="reset_email_otp")

    if not is_valid:
        await db.auth.update_one(
            {"email": data.email},
            {"$inc": {"reset_email_attempts": 1}}
        )
        raise HTTPException(400, "Invalid Reset Email OTP")

    # ✅ FIXED: DON'T clear the OTP — just mark as verified
    # OTP will be cleared only after successful password reset
    await db.auth.update_one(
        {"email": data.email},
        {"$set": {
            "reset_email_verified": True,
            "reset_email_attempts": 0
            # ❌ REMOVED: "reset_email_otp": None
            # ❌ REMOVED: "reset_email_expiry": None
        }}
    )
    return {"msg": "Reset Email OTP verified"}


# ============================================================
# VERIFY RESET MOBILE OTP - FIXED (Don't clear OTP)
# ============================================================
async def verify_reset_mobile_otp(data):
    db = await get_db_safe()
    user = await db.auth.find_one({"mobile": data.mobile})

    if not user:
        user = await db.auth.find_one({"email": data.mobile})
        if not user:
            raise HTTPException(404, "User not found")

    # ✅ Check if already verified (allow re-verification)
    if user.get("reset_mobile_verified") == True:
        logger.info(f"✅ Mobile already verified")
        return {"msg": "Reset Mobile OTP already verified"}

    if not user.get("reset_mobile_expiry") or datetime.utcnow() > user["reset_mobile_expiry"]:
        raise HTTPException(400, "Reset Mobile OTP expired")
    if user.get("reset_mobile_attempts", 0) >= 5:
        raise HTTPException(429, "Too many attempts")

    if not is_valid_mobile_otp(user, data.otp, field_prefix="reset_mobile_otp"):
        await db.auth.update_one(
            {"_id": user["_id"]},
            {"$inc": {"reset_mobile_attempts": 1}}
        )
        raise HTTPException(400, "Invalid Reset Mobile OTP")

    # ✅ FIXED: DON'T clear the OTP — just mark as verified
    await db.auth.update_one(
        {"_id": user["_id"]},
        {"$set": {
            "reset_mobile_verified": True,
            "reset_mobile_attempts": 0
            # ❌ REMOVED: "reset_mobile_otp": None
            # ❌ REMOVED: "reset_mobile_expiry": None
        }}
    )
    return {"msg": "Reset Mobile OTP verified"}


# ============================================================
# RESET PASSWORD - FIXED (Clear OTPs after successful reset)
# ============================================================
async def reset_password(data):
    db = await get_db_safe()
    validate_password(data.new_password)
    user = await db.auth.find_one({"email": data.email})
    if not user:
        raise HTTPException(404, "User not found")

    email_verified = user.get("reset_email_verified", False)
    mobile_verified = user.get("reset_mobile_verified", False)

    user_mobile = user.get("mobile")
    if not user_mobile:
        profile = await db.profile.find_one({"email": data.email})
        if profile:
            user_mobile = profile.get("phone") or profile.get("mobile")

    if not user_mobile:
        if not email_verified:
            raise HTTPException(403, "Please verify email OTP first")
    else:
        if not email_verified or not mobile_verified:
            raise HTTPException(403, "Please verify both email and mobile OTP first")

    new_hashed = hash_password(data.new_password)
    if verify_password(data.new_password, user.get("password", "")):
        raise HTTPException(400, "New password cannot be same as old password")

    # ✅ NOW clear everything AFTER successful password reset
    result = await db.auth.update_one(
        {"email": data.email},
        {"$set": {
            "password": new_hashed,
            "reset_email_verified": False,
            "reset_mobile_verified": False,
            "reset_email_otp": None,
            "reset_mobile_otp": None,
            "reset_email_expiry": None,
            "reset_mobile_expiry": None,
            "reset_email_attempts": 0,
            "reset_mobile_attempts": 0,
            "failed_attempts": 0,
            "lock_until": None  # ✅ Also unlock account
        }}
    )

    if result.modified_count == 0:
        raise HTTPException(500, "Password reset failed. Please try again.")

    logger.info(f"✅ Password reset successful for {data.email}")
    return {"msg": "Password reset successful"}

# ============================================================
# LOGOUT
# ============================================================
async def logout_all(user):
    db = await get_db_safe()
    await db.sessions.delete_many({"user_id": user["user_id"]})
    return {"msg": "Logged out from all devices"}


# ============================================================
# ROLE MANAGEMENT (Superadmin only)
# ============================================================
async def get_user_role(email: str, current_user: dict):
    db = await get_db_safe()
    if current_user.get("role") != "superadmin":
        raise HTTPException(403, "Only superadmin can view user roles")
    user = await db.auth.find_one({"email": email})
    if not user:
        raise HTTPException(404, "User not found")
    return {
        "email": user["email"],
        "name": user["name"],
        "role": user.get("role", "user"),
        "is_active": user.get("is_active", True),
        "last_login": user.get("last_login").isoformat() if user.get("last_login") else None
    }


async def update_user_role(email: str, new_role: str, current_user: dict):
    db = await get_db_safe()
    if current_user.get("role") != "superadmin":
        raise HTTPException(403, "Only superadmin can update user roles")
    allowed_roles = ["user", "admin", "customadmin", "superadmin"]
    if new_role not in allowed_roles:
        raise HTTPException(400, f"Invalid role. Allowed: {allowed_roles}")
    if current_user.get("email") == email and new_role != "superadmin":
        raise HTTPException(403, "Superadmin cannot demote themselves")
    user = await db.auth.find_one({"email": email})
    if not user:
        raise HTTPException(404, "User not found")
    old_role = user.get("role", "user")
    await db.auth.update_one(
        {"email": email},
        {"$set": {
            "role": new_role,
            "role_updated_at": datetime.utcnow(),
            "role_updated_by": current_user.get("email")
        }}
    )
    logger.info(f"User {email} role changed from {old_role} to {new_role}")
    return {
        "email": email,
        "old_role": old_role,
        "new_role": new_role,
        "updated_by": current_user.get("email")
    }


async def get_all_users_roles(current_user: dict):
    db = await get_db_safe()
    if current_user.get("role") != "superadmin":
        raise HTTPException(403, "Only superadmin can view all users")
    users = await db.auth.find({}, {
        "_id": 1, "email": 1, "name": 1, "role": 1, "is_active": 1,
        "last_login": 1, "created_at": 1
    }).to_list(1000)
    return [
        {
            "id": str(u["_id"]),
            "email": u["email"],
            "name": u.get("name", ""),
            "role": u.get("role", "user"),
            "is_active": u.get("is_active", True),
            "last_login": u.get("last_login").isoformat() if u.get("last_login") else None,
            "created_at": u.get("created_at").isoformat() if u.get("created_at") else None
        }
        for u in users
    ]


async def send_verification_notification(email: str, user_id: str, name: str):
    from app.modules.notification.service import central_notification
    await central_notification.notify_user_verified(email, name, user_id)


# ============================================================
# 🎯 STARTUP DIAGNOSTIC
# ============================================================
print("=" * 70)
print("✅ Auth Service Loaded — EMAIL ALWAYS REAL, MOBILE .env-driven")
print("=" * 70)
print("🧪 OTP MODE CONFIGURATION")
print("=" * 70)
if settings.MOBILE_OTP_BYPASS:
    print("   🔧 MODE: DEVELOPMENT (MOBILE_OTP_BYPASS=true)")
    print("   ┌─────────────────────────────────────────────────────────┐")
    print("   │ 📧 EMAIL OTP: ALWAYS REAL (random 6-digit via email)   │")
    print("   │ 📱 MOBILE OTP: BYPASSED (use DEV_OTP_CODE)             │")
    print("   │ 💬 WHATSAPP OTP: BYPASSED                              │")
    print("   └─────────────────────────────────────────────────────────┘")
    print(f"   🔑 Dev Mobile OTP: {settings.dev_otp_value}")
    print("   ✅ Email OTP: Sent for real via email provider")
    print("   ⚠️  Mobile verification accepts: 123456 OR any 6-digit")
else:
    print("   🔐 MODE: PRODUCTION (MOBILE_OTP_BYPASS=false)")
    print("   ┌─────────────────────────────────────────────────────────┐")
    print("   │ 📧 EMAIL OTP: ALWAYS REAL (random 6-digit via email)   │")
    print("   │ 📱 MOBILE OTP: REAL (random 6-digit via SMS)           │")
    print("   │ 💬 WHATSAPP OTP: REAL                                  │")
    print("   └─────────────────────────────────────────────────────────┘")
    print("   ⚠️  123456: WILL NOT WORK for mobile")
print("=" * 70)
print(f"   📧 EMAIL_PROVIDER = {settings.EMAIL_PROVIDER}")
print(f"   📱 SMS_PROVIDER = {settings.SMS_PROVIDER}")
print(f"   💬 WHATSAPP_PROVIDER = {settings.WHATSAPP_PROVIDER}")
print("=" * 70)