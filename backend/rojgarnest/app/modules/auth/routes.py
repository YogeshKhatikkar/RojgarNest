# app/modules/auth/routes.py - COMPLETE WITH ALL BIOMETRIC ENDPOINTS

from fastapi import APIRouter, Request, BackgroundTasks, Depends, HTTPException, Query, Body
from fastapi.responses import JSONResponse
from datetime import datetime, timedelta
from typing import Optional
from bson import ObjectId

from app.modules.auth.schema import (
    RegisterSchema, LoginSchema, EmailSchema, MobileSchema,
    EmailOTPVerifySchema, MobileOTPVerifySchema, SetPinSchema,
    PinLoginSchema, BiometricEnableSchema, BiometricLoginSchema,
    ResetPasswordSchema, RefreshSchema
)
from app.modules.auth.service import (
    register_user, login_user, verify_email_otp, verify_mobile_otp,
    send_email_otp_service, send_mobile_otp_service, forgot_password,
    reset_password, logout_all, setup_mpin_service, login_pin,
    refresh_access_token,
    verify_reset_email_otp, verify_reset_mobile_otp,
    resend_reset_email_otp_service, resend_reset_mobile_otp_service
)
from app.core.services.dependencies import get_current_user
from app.db.connection import get_db
from app.core.location.location_handler import location_handler
from app.core.security import create_access_token, create_refresh_token
from app.core.utils.logger import logger

router = APIRouter()

def serialize_dates(obj):
    if isinstance(obj, datetime):
        return obj.isoformat()
    if isinstance(obj, dict):
        return {k: serialize_dates(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [serialize_dates(item) for item in obj]
    return obj


# ==================== REGISTER ====================

@router.post("/register")
async def register(
    name: str = Body(...),
    email: str = Body(...),
    mobile: str = Body(...),
    password: str = Body(...),
    role: Optional[str] = Query("user"),
    latitude: Optional[float] = Body(None),
    longitude: Optional[float] = Body(None),
    location_name: Optional[str] = Body(None),
    background_tasks: BackgroundTasks = None
):
    """Register new user with location"""
    
    # Validate input
    if not name or not email or not mobile or not password:
        raise HTTPException(status_code=400, detail="All fields are required")
    
    if len(mobile) != 10 or not mobile.isdigit():
        raise HTTPException(status_code=400, detail="Mobile number must be 10 digits")
    
    if len(password) < 8:
        raise HTTPException(status_code=400, detail="Password must be at least 8 characters")

    try:
        data = RegisterSchema(name=name, email=email, mobile=mobile, password=password)
    except Exception as e:
        raise HTTPException(status_code=422, detail=str(e))

    result = await register_user(data, background_tasks, role)

    # Save location if provided
    if latitude is not None and longitude is not None:
        db = get_db()
        email_lower = data.email.lower().strip()
        location_data = await location_handler.get_location_name(latitude, longitude)
        location_doc = {
            "latitude": latitude,
            "longitude": longitude,
            "location_name": location_name or location_data.get("location_name", f"{latitude}, {longitude}"),
            "city": location_data.get("city", ""),
            "district": location_data.get("district", ""),
            "state": location_data.get("state", ""),
            "country": location_data.get("country", "India"),
            "last_updated": datetime.utcnow()
        }
        await db.auth.update_one(
            {"email": email_lower},
            {"$set": {"current_location": location_doc, "last_location_update": datetime.utcnow()}}
        )
        result["location_saved"] = True
        result["current_location"] = location_doc

    return JSONResponse(content=serialize_dates(result), status_code=201)


# ==================== EMAIL + PASSWORD LOGIN ====================

@router.post("/login")
async def login(
    request: Request,
    email: str = Body(...),
    password: str = Body(...),
    latitude: Optional[float] = Body(None),
    longitude: Optional[float] = Body(None),
    location_name: Optional[str] = Body(None),
    force_location_update: bool = Body(False)
):
    """Login with email and password"""
    
    if not email or not password:
        raise HTTPException(status_code=400, detail="Email and password are required")
    
    if len(password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")
    
    try:
        login_data = LoginSchema(email=email, password=password)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid email format: {str(e)}")
    
    try:
        login_result = await login_user(login_data, request)
    except HTTPException as e:
        # ✅ Pass detailed error through
        raise e
    except Exception as e:
        logger.error(f"Login error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error during login")

    # Update location if provided (only on successful login)
    if login_result.get("access_token") and latitude is not None and longitude is not None:
        try:
            db = get_db()
            email_lower = email.lower().strip()
            location_data = await location_handler.get_location_name(latitude, longitude)
            new_location_data = {
                "latitude": latitude,
                "longitude": longitude,
                "location_name": location_name or location_data.get("location_name", f"{latitude}, {longitude}"),
                "city": location_data.get("city", ""),
                "district": location_data.get("district", ""),
                "state": location_data.get("state", ""),
                "country": location_data.get("country", "India"),
                "last_updated": datetime.utcnow()
            }
            await db.auth.update_one(
                {"email": email_lower},
                {"$set": {"current_location": new_location_data, "last_location_update": datetime.utcnow()}}
            )
            login_result["location_updated"] = True
            login_result["current_location"] = new_location_data
        except Exception as loc_error:
            logger.warning(f"Location update failed during login: {loc_error}")
            # Don't fail login if location fails

    return JSONResponse(content=serialize_dates(login_result))


# ==================== MPIN ENDPOINTS ====================

@router.post("/set-pin")
async def set_mpin(
    data: SetPinSchema,
    current_user=Depends(get_current_user),
    db=Depends(get_db)
):
    """Set MPIN for the user"""
    logger.info(f"📝 Set-pin request received for email: {data.email}")
    
    user = await db.auth.find_one({"email": data.email})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if str(user["_id"]) != current_user.get("user_id"):
        raise HTTPException(status_code=403, detail="Unauthorized")
    
    if len(data.pin) != 6 or not data.pin.isdigit():
        raise HTTPException(status_code=400, detail="PIN must be 6 digits")
    
    from app.core.security import hash_pin
    result = await db.auth.update_one(
        {"email": data.email},
        {"$set": {
            "pin": hash_pin(data.pin),
            "is_pin_set": True,
            "pin_attempts": 0,
            "updated_at": datetime.utcnow()
        }}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=500, detail="Failed to set MPIN")
    
    logger.info(f"✅ MPIN set successfully for {data.email}")
    return {"msg": "MPIN setup successfully", "success": True}


@router.post("/login-pin")
async def login_with_pin(data: PinLoginSchema, request: Request):
    """Login with MPIN"""
    if not data.email or not data.pin:
        raise HTTPException(status_code=400, detail="Email and PIN are required")
    
    if len(data.pin) != 6:
        raise HTTPException(status_code=400, detail="PIN must be 6 digits")
    
    result = await login_pin(data, request)
    return JSONResponse(content=serialize_dates(result))


# ==================== LOCATION ENDPOINTS ====================

@router.get("/my-location")
async def get_user_location(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Get user's current location"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    user = await db.auth.find_one({"email": email})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    current_location = user.get("current_location")
    if not current_location:
        return {"success": True, "has_location": False, "message": "No location found"}
    return {
        "success": True,
        "has_location": True,
        "location": {
            "latitude": current_location.get("latitude"),
            "longitude": current_location.get("longitude"),
            "location_name": current_location.get("location_name"),
            "city": current_location.get("city", ""),
            "district": current_location.get("district", ""),
            "state": current_location.get("state", ""),
            "country": current_location.get("country", "India"),
            "last_updated": current_location.get("last_updated").isoformat() if current_location.get("last_updated") else None
        }
    }


@router.post("/update-location")
async def update_user_location(
    latitude: float = Body(...),
    longitude: float = Body(...),
    location_name: Optional[str] = Body(None),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Update user's current location"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    location_data = await location_handler.get_location_name(latitude, longitude)
    new_location_data = {
        "latitude": latitude,
        "longitude": longitude,
        "location_name": location_name or location_data.get("location_name", f"{latitude}, {longitude}"),
        "city": location_data.get("city", ""),
        "district": location_data.get("district", ""),
        "state": location_data.get("state", ""),
        "country": location_data.get("country", "India"),
        "last_updated": datetime.utcnow()
    }
    result = await db.auth.update_one(
        {"email": email},
        {"$set": {"current_location": new_location_data, "last_location_update": datetime.utcnow()}}
    )
    return {
        "success": result.modified_count > 0,
        "message": "Location updated successfully",
        "current_location": new_location_data
    }


# ==================== USER INFO ====================

@router.get("/me")
async def get_current_user_info(current_user=Depends(get_current_user)):
    """Get current user info"""
    db = get_db()
    user = await db.auth.find_one({"_id": ObjectId(current_user["user_id"])})
    if not user:
        raise HTTPException(404, "User not found")
    return {
        "email": user["email"],
        "mobile": user.get("mobile", ""),
        "name": user.get("name", ""),
        "role": user.get("role", "user"),
        "current_location": user.get("current_location"),
        "is_biometric_enabled": user.get("is_biometric_enabled", False),
        "biometric_type": user.get("biometric_type")
    }


@router.get("/my-role")
async def get_my_role(current_user=Depends(get_current_user)):
    """Get user's role"""
    return {"role": current_user.get("role", "user"), "email": current_user.get("email")}


# ==================== OTP VERIFICATION ====================

@router.post("/verify-email")
async def verify_email(data: EmailOTPVerifySchema):
    return await verify_email_otp(data)


@router.post("/verify-mobile")
async def verify_mobile(data: MobileOTPVerifySchema):
    return await verify_mobile_otp(data)


@router.post("/resend-email-otp")
async def resend_email_otp(data: EmailSchema, background_tasks: BackgroundTasks):
    return await send_email_otp_service(data.email, background_tasks)


@router.post("/resend-mobile-otp")
async def resend_mobile_otp(data: MobileSchema, background_tasks: BackgroundTasks):
    return await send_mobile_otp_service(data.mobile, background_tasks)


# ==================== FORGOT / RESET PASSWORD ====================

@router.post("/forgot-password")
async def forgot(data: EmailSchema, background_tasks: BackgroundTasks):
    return await forgot_password(data.email, background_tasks)


@router.post("/verify-reset-email")
async def verify_reset_email_endpoint(data: EmailOTPVerifySchema):
    """Verify email OTP for password reset"""
    return await verify_reset_email_otp(data)


@router.post("/verify-reset-mobile")
async def verify_reset_mobile_endpoint(data: MobileOTPVerifySchema):
    """Verify mobile OTP for password reset"""
    return await verify_reset_mobile_otp(data)


@router.post("/resend-reset-email-otp")
async def resend_reset_email_otp_endpoint(data: EmailSchema, background_tasks: BackgroundTasks):
    """Resend email OTP for password reset"""
    return await resend_reset_email_otp_service(data.email, background_tasks)


@router.post("/resend-reset-mobile-otp")
async def resend_reset_mobile_otp_endpoint(data: MobileSchema, background_tasks: BackgroundTasks):
    """Resend mobile OTP for password reset"""
    return await resend_reset_mobile_otp_service(data.mobile, background_tasks)


@router.post("/reset-password")
async def reset(data: ResetPasswordSchema):
    return await reset_password(data)


# ==================== LOGOUT ====================

@router.post("/logout")
async def logout(current_user=Depends(get_current_user)):
    """Logout user - DOES NOT DELETE BIOMETRIC DATA"""
    return await logout_all(current_user)


# ==================== ✅ BIOMETRIC ENDPOINTS ====================

@router.post("/enable-biometric")
async def enable_biometric(
    data: BiometricEnableSchema,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Enable biometric login for user
    ✅ Data is saved PERMANENTLY - NEVER deleted on logout
    """
    
    user = await db.auth.find_one({"email": data.email})
    if not user or str(user["_id"]) != current_user.get("user_id"):
        raise HTTPException(status_code=403, detail="Unauthorized")
    
    # ✅ Save biometric data permanently
    update_data = {
        "is_biometric_enabled": True,
        "biometric_device_info": data.device_info,
        "biometric_type": data.biometric_type or "fingerprint",
        "biometric_device_id": data.device_id,
        "biometric_enabled_at": datetime.utcnow(),
        "updated_at": datetime.utcnow()
    }
    
    result = await db.auth.update_one(
        {"email": data.email},
        {"$set": update_data}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=500, detail="Failed to enable biometric")
    
    logger.info(f"✅ Biometric enabled permanently for {data.email}")
    return {
        "success": True,
        "message": "Biometric login enabled successfully",
        "biometric_type": data.biometric_type or "fingerprint"
    }


@router.post("/disable-biometric")
async def disable_biometric(
    data: BiometricEnableSchema,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Disable biometric login
    ⚠️ ONLY called when user explicitly disables from settings
    """
    
    user = await db.auth.find_one({"email": data.email})
    if not user or str(user["_id"]) != current_user.get("user_id"):
        raise HTTPException(status_code=403, detail="Unauthorized")
    
    # ✅ ONLY DISABLE - DO NOT DELETE data
    result = await db.auth.update_one(
        {"email": data.email},
        {"$set": {
            "is_biometric_enabled": False,
            "updated_at": datetime.utcnow()
        }}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=500, detail="Failed to disable biometric")
    
    logger.info(f"❌ Biometric disabled for {data.email}")
    return {
        "success": True,
        "message": "Biometric login disabled successfully"
    }


@router.post("/biometric-login")
async def biometric_login(
    data: BiometricLoginSchema,
    request: Request,
    db=Depends(get_db)
):
    """
    Login using biometric authentication
    ✅ Reads PERMANENT biometric data
    """
    
    user = await db.auth.find_one({"email": data.email})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # ✅ Check if biometric is enabled
    if not user.get("is_biometric_enabled", False):
        raise HTTPException(
            status_code=400, 
            detail="Biometric not enabled. Please enable it in settings."
        )
    
    if not user.get("is_active", True):
        raise HTTPException(status_code=403, detail="Account is deactivated")
    
    # ✅ Update last login and biometric history
    await db.auth.update_one(
        {"email": data.email},
        {
            "$set": {
                "last_login": datetime.utcnow(),
                "last_login_ip": request.client.host if request else "",
                "last_biometric_login": datetime.utcnow()
            },
            "$push": {
                "biometric_login_history": {
                    "$each": [{
                        "timestamp": datetime.utcnow(),
                        "ip": request.client.host if request else "",
                        "device": data.device_info or "Unknown"
                    }],
                    "$slice": -10  # Keep only last 10
                }
            }
        }
    )
    
    # ✅ Get profile data
    profile = await db.profile.find_one({"email": data.email})
    
    mobile = user.get("mobile", "")
    if not mobile and profile:
        mobile = profile.get("phone", "")
    
    full_name = profile.get("full_name", "") if profile else ""
    if not full_name:
        full_name = user.get("name", "")
    
    # ✅ Create tokens
    access_token = create_access_token({
        "user_id": str(user["_id"]),
        "role": user.get("role", "user"),
        "email": user["email"],
        "name": full_name
    })
    
    refresh_token = create_refresh_token({"user_id": str(user["_id"])})
    
    # ✅ Handle location
    location_doc = None
    if data.latitude is not None and data.longitude is not None and data.latitude != 0:
        location_data = await location_handler.get_location_name(data.latitude, data.longitude)
        location_doc = {
            "latitude": data.latitude,
            "longitude": data.longitude,
            "location_name": data.location_name or location_data.get("location_name", f"{data.latitude}, {data.longitude}"),
            "city": location_data.get("city", ""),
            "district": location_data.get("district", ""),
            "state": location_data.get("state", ""),
            "country": location_data.get("country", "India"),
            "last_updated": datetime.utcnow()
        }
        await db.auth.update_one(
            {"email": data.email},
            {"$set": {"current_location": location_doc, "last_location_update": datetime.utcnow()}}
        )
    else:
        location_doc = user.get("current_location")
    
    # ✅ Store session
    import secrets
    session_data = {
        "user_id": str(user["_id"]),
        "user_email": user["email"],
        "session_hash": secrets.token_hex(32),
        "ip": request.client.host if request else "",
        "device": request.headers.get("user-agent", "Unknown") if request else "Unknown",
        "created_at": datetime.utcnow(),
        "expires_at": datetime.utcnow() + timedelta(days=3),
        "is_active": True
    }
    await db.sessions.insert_one(session_data)
    
    logger.info(f"✅ Biometric Login successful for {data.email}")
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "role": user.get("role", "user"),
        "email": user["email"],
        "name": full_name,
        "mobile": mobile,
        "current_location": location_doc if location_doc else user.get("current_location"),
        "biometric_type": user.get("biometric_type", "fingerprint"),
        "success": True
    }


# ==================== REFRESH TOKEN ====================

@router.post("/refresh")
async def refresh_token(data: RefreshSchema):
    return await refresh_access_token(data)


# ==================== TEST ====================

@router.get("/test")
async def test():
    return {"msg": "Auth routes working"}


print("✅ Auth Routes Loaded - All login types with PERMANENT biometric storage")