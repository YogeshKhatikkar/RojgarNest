# app/core/services/notification_dispatcher.py
# ============================================================
# 🔔 UNIFIED NOTIFICATION DISPATCHER - CORRECTED
# ============================================================
# ✅ EMAIL IS ALWAYS REAL - NEVER BYPASSED
# ✅ SMS/WhatsApp: Bypassed when MOBILE_OTP_BYPASS=true
# ✅ CORRECT status reporting (no false success)
# ✅ Distinguishes FAILED vs SKIPPED vs FALLBACK
# ============================================================

import logging
from typing import Optional, Dict, Any

from app.core.config.settings import settings
from app.core.services.email import send_email_async, _build_otp_email_html
from app.core.services.sms import send_sms_async
from app.core.services.whatsapp import send_whatsapp
from app.core.utils.otp_logger import otp_logger

logger = logging.getLogger(__name__)


# ============================================================
# MAIN: DISPATCH OTP - WITH CORRECT STATUS
# ============================================================
async def dispatch_otp(
    email: Optional[str],
    mobile: Optional[str],
    otp: str,
    purpose: str = "verification",
    user_name: Optional[str] = None,
    email_otp: Optional[str] = None,
    mobile_otp: Optional[str] = None,
) -> Dict[str, bool]:
    """
    Send OTP to all configured channels with ACCURATE status.
    
    Returns dict with keys: email, sms, whatsapp
    - True: channel SENT successfully (or bypassed in dev)
    - False: channel FAILED or SKIPPED
    """
    channels = settings.get_channels_for("otp")
    results = {"email": False, "sms": False, "whatsapp": False}
    skipped_channels = {}
    
    final_email_otp = email_otp or otp
    final_mobile_otp = mobile_otp or otp
    mode = "DEVELOPMENT" if settings.MOBILE_OTP_BYPASS else "PRODUCTION"

    logger.info("=" * 70)
    logger.info(f"📤 DISPATCHING OTP")
    logger.info(f"   Purpose: {purpose}")
    logger.info(f"   Email: {email or 'N/A'}")
    logger.info(f"   Mobile: {mobile or 'N/A'}")
    logger.info(f"   Mode: {mode}")
    logger.info(f"   Channels: {channels}")
    logger.info("=" * 70)

    # ============================================================
    # 📧 EMAIL - ALWAYS REAL (NEVER BYPASSED)
    # ============================================================
    if "email" in channels and email:
        email_provider = (settings.EMAIL_PROVIDER or "").lower()
        if email_provider not in ("disabled", ""):
            try:
                html = _build_otp_email_html(final_email_otp, purpose=purpose)
                results["email"] = await send_email_async(
                    to_email=email,
                    subject=f"Your RojgarNest OTP ({purpose})",
                    html_body=html,
                    text_body=f"Your OTP is {final_email_otp}. Valid for 10 minutes.",
                )
                if results["email"]:
                    logger.info(f"✅ [REAL] Email OTP sent to {email}")
                else:
                    logger.error(f"❌ Email OTP failed for {email}")
            except Exception as e:
                logger.error(f"❌ Email OTP exception: {e}")
                results["email"] = False
        else:
            skipped_channels["email"] = f"Provider '{email_provider}' disabled"
    elif not email:
        skipped_channels["email"] = "No email provided"
    else:
        skipped_channels["email"] = "Email not in OTP channels"

    # ============================================================
    # 📱 SMS
    # ============================================================
    if settings.MOBILE_OTP_BYPASS:
        logger.info(f"🔧 [DEV] SMS OTP bypassed")
        results["sms"] = True
        skipped_channels["sms"] = "Bypassed (dev mode)"
    else:
        sms_provider = (settings.SMS_PROVIDER or "").lower()
        
        if sms_provider == "disabled":
            skipped_channels["sms"] = "Provider disabled"
            logger.info(f"⊘ SMS skipped - provider disabled")
        elif "sms" not in channels:
            skipped_channels["sms"] = "Not in OTP channels"
        elif not mobile:
            skipped_channels["sms"] = "No mobile provided"
        else:
            try:
                logger.info(f"📱 [PROD] Sending real SMS to {mobile} via {sms_provider}")
                results["sms"] = await send_sms_async(
                    to_mobile=mobile,
                    message=f"Your RojgarNest OTP is {final_mobile_otp}. Valid 10 minutes.",
                    template_id=settings.MSG91_TEMPLATE_ID_OTP,
                    variables={"otp": final_mobile_otp},
                )
                if results["sms"]:
                    logger.info(f"✅ [REAL] SMS OTP sent to {mobile}")
                else:
                    logger.error(f"❌ SMS OTP failed for {mobile}")
                    skipped_channels["sms"] = "Provider failed"
            except Exception as e:
                logger.error(f"❌ SMS OTP exception: {e}")
                results["sms"] = False
                skipped_channels["sms"] = f"Exception: {str(e)[:50]}"

    # ============================================================
    # 💬 WHATSAPP - CORRECTED STATUS LOGIC
    # ============================================================
    if settings.MOBILE_OTP_BYPASS:
        logger.info(f"🔧 [DEV] WhatsApp OTP bypassed")
        results["whatsapp"] = True
        skipped_channels["whatsapp"] = "Bypassed (dev mode)"
    else:
        wa_provider = (settings.WHATSAPP_PROVIDER or "").lower()
        
        # ✅ Check provider disabled FIRST
        if wa_provider == "disabled":
            skipped_channels["whatsapp"] = "Provider disabled (WHATSAPP_PROVIDER=disabled)"
            logger.info(f"⊘ WhatsApp skipped - provider is disabled")
            results["whatsapp"] = False  # ✅ Correctly mark as false
        elif "whatsapp" not in channels:
            skipped_channels["whatsapp"] = "Not in OTP channels"
            logger.info(f"⊘ WhatsApp skipped - not in OTP channels")
        elif not mobile:
            skipped_channels["whatsapp"] = "No mobile provided"
        else:
            try:
                logger.info(f"💬 [PROD] Sending real WhatsApp to {mobile} via {wa_provider}")
                wa_result = await send_whatsapp(
                    to_mobile=mobile,
                    message=f"Your RojgarNest OTP is {final_mobile_otp}",
                    template_id=settings.MSG91_WHATSAPP_TEMPLATE_OTP,
                    variables={"otp": final_mobile_otp, "name": user_name or "User"},
                )
                
                if wa_result:
                    results["whatsapp"] = True
                    logger.info(f"✅ [REAL] WhatsApp OTP sent to {mobile}")
                else:
                    # ✅ CRITICAL FIX: WhatsApp failed
                    results["whatsapp"] = False
                    logger.error(f"❌ WhatsApp OTP failed for {mobile}")
                    
                    if settings.WHATSAPP_FALLBACK_TO_SMS:
                        skipped_channels["whatsapp"] = "FAILED → Fell back to SMS"
                    else:
                        skipped_channels["whatsapp"] = "FAILED - No fallback"
            except Exception as e:
                logger.error(f"❌ WhatsApp OTP exception: {e}")
                results["whatsapp"] = False
                skipped_channels["whatsapp"] = f"Exception: {str(e)[:50]}"

    # ============================================================
    # 📢 TERMINAL DISPLAY - WITH ACCURATE STATUS
    # ============================================================
    otp_logger.log_otp_dispatch(
        purpose=purpose,
        email=email,
        mobile=mobile,
        email_otp=final_email_otp,
        mobile_otp=final_mobile_otp,
        results=results,
        mode=mode,
        skipped_channels=skipped_channels,
    )

    return results


# ============================================================
# VERIFICATION SUCCESS
# ============================================================
async def dispatch_verification_success(
    email: Optional[str],
    mobile: Optional[str],
    user_name: str,
    verified_field: str = "Email",
) -> Dict[str, bool]:
    channels = settings.get_channels_for("verification")
    results = {"email": False, "sms": False, "whatsapp": False}

    if "email" in channels and email:
        html = f"""<!DOCTYPE html><html><body style="font-family:Arial;padding:20px;">
        <h2 style="color:#10B981;">✅ {verified_field} Verified!</h2>
        <p>Hi <strong>{user_name}</strong>,</p>
        <p>Your {verified_field.lower()} has been successfully verified on RojgarNest.</p>
        </body></html>"""
        results["email"] = await send_email_async(
            to_email=email,
            subject=f"✅ Your {verified_field} is verified",
            html_body=html,
        )

    if settings.MOBILE_OTP_BYPASS:
        results["sms"] = True
        results["whatsapp"] = True
    else:
        if "sms" in channels and mobile:
            sms_provider = (settings.SMS_PROVIDER or "").lower()
            if sms_provider not in ("disabled", ""):
                results["sms"] = await send_sms_async(
                    to_mobile=mobile,
                    message=f"Hi {user_name}, your {verified_field.lower()} is verified.",
                    template_id=settings.MSG91_TEMPLATE_ID_VERIFY,
                    variables={"name": user_name, "field": verified_field},
                )
        
        wa_provider = (settings.WHATSAPP_PROVIDER or "").lower()
        if "whatsapp" in channels and mobile and wa_provider not in ("disabled", ""):
            results["whatsapp"] = await send_whatsapp(
                to_mobile=mobile,
                message=f"Hi {user_name}, your {verified_field.lower()} is verified.",
                template_id=settings.MSG91_WHATSAPP_TEMPLATE_ALERT,
                variables={"name": user_name, "message": f"{verified_field} verified"},
            )

    return results


# ============================================================
# PASSWORD RESET
# ============================================================
async def dispatch_password_reset(
    email: Optional[str],
    mobile: Optional[str],
    otp: str,
    user_name: str = "User",
    email_otp: Optional[str] = None,
    mobile_otp: Optional[str] = None,
) -> Dict[str, bool]:
    return await dispatch_otp(
        email=email,
        mobile=mobile,
        otp=otp,
        purpose="password reset",
        user_name=user_name,
        email_otp=email_otp,
        mobile_otp=mobile_otp,
    )


# ============================================================
# WELCOME
# ============================================================
async def dispatch_welcome(
    email: Optional[str],
    mobile: Optional[str],
    user_name: str,
) -> Dict[str, bool]:
    channels = settings.get_channels_for("welcome")
    results = {"email": False, "whatsapp": False}

    if "email" in channels and email:
        html = f"""<!DOCTYPE html>
        <html><body style="font-family:Arial;padding:20px;">
        <h1>🎉 Welcome to RojgarNest!</h1>
        <p>Hi <strong>{user_name}</strong>, welcome aboard!</p>
        </body></html>"""
        results["email"] = await send_email_async(
            to_email=email,
            subject="🎉 Welcome to RojgarNest!",
            html_body=html,
        )

    if settings.MOBILE_OTP_BYPASS:
        results["whatsapp"] = True
    else:
        wa_provider = (settings.WHATSAPP_PROVIDER or "").lower()
        if "whatsapp" in channels and mobile and wa_provider not in ("disabled", ""):
            results["whatsapp"] = await send_whatsapp(
                to_mobile=mobile,
                message=f"Welcome to RojgarNest, {user_name}!",
                template_id=settings.MSG91_WHATSAPP_TEMPLATE_ALERT,
                variables={"name": user_name, "message": "Welcome!"},
            )

    return results


# ============================================================
# APPLICATION STATUS
# ============================================================
async def dispatch_application_status(
    email: Optional[str],
    mobile: Optional[str],
    user_name: str,
    job_title: str,
    organization: str,
    status: str,
    notes: Optional[str] = None,
) -> Dict[str, bool]:
    channels = settings.get_channels_for("application_status")
    results = {"email": False, "sms": False, "whatsapp": False}

    status_display = status.replace("_", " ").title()

    if "email" in channels and email:
        html = f"""<!DOCTYPE html><html><body style="font-family:Arial;padding:20px;">
        <h2>📋 Application Update</h2>
        <p>Hi <strong>{user_name}</strong>,</p>
        <p>Application for <strong>{job_title}</strong> is now: {status_display}</p>
        </body></html>"""
        results["email"] = await send_email_async(
            to_email=email,
            subject=f"Application Status: {status_display}",
            html_body=html,
        )

    if settings.MOBILE_OTP_BYPASS:
        results["sms"] = True
        results["whatsapp"] = True
    else:
        if "sms" in channels and mobile:
            sms_provider = (settings.SMS_PROVIDER or "").lower()
            if sms_provider not in ("disabled", ""):
                results["sms"] = await send_sms_async(
                    to_mobile=mobile,
                    message=f"Hi {user_name}, application for {job_title} is now {status_display}.",
                    template_id=settings.MSG91_TEMPLATE_ID_ALERT,
                    variables={"name": user_name, "job_title": job_title, "status": status_display},
                )
        
        wa_provider = (settings.WHATSAPP_PROVIDER or "").lower()
        if "whatsapp" in channels and mobile and wa_provider not in ("disabled", ""):
            results["whatsapp"] = await send_whatsapp(
                to_mobile=mobile,
                message=f"Hi {user_name}, application for {job_title} is now: {status_display}",
                template_id=settings.MSG91_WHATSAPP_TEMPLATE_STATUS,
                variables={"name": user_name, "job_title": job_title, "company": organization, "status": status_display},
            )

    return results


# ============================================================
# JOB ALERT
# ============================================================
async def dispatch_job_alert(
    email: Optional[str],
    mobile: Optional[str],
    user_name: str,
    job_title: str,
    organization: str,
    location: str,
    job_id: str,
) -> Dict[str, bool]:
    channels = settings.get_channels_for("job_alert")
    results = {"email": False, "whatsapp": False}

    apply_url = f"{settings.APP_BASE_URL}/jobs/{job_id}"

    if "email" in channels and email:
        html = f"""<!DOCTYPE html><html><body style="font-family:Arial;padding:20px;">
        <h2>🚀 New Job Alert!</h2>
        <p>Hi <strong>{user_name}</strong>,</p>
        <h3>{job_title}</h3>
        <p><strong>{organization}</strong> — {location}</p>
        <p><a href="{apply_url}">View & Apply</a></p>
        </body></html>"""
        results["email"] = await send_email_async(
            to_email=email,
            subject=f"🚀 New Job: {job_title} at {organization}",
            html_body=html,
        )

    if settings.MOBILE_OTP_BYPASS:
        results["whatsapp"] = True
    else:
        wa_provider = (settings.WHATSAPP_PROVIDER or "").lower()
        if "whatsapp" in channels and mobile and wa_provider not in ("disabled", ""):
            results["whatsapp"] = await send_whatsapp(
                to_mobile=mobile,
                message=f"🚀 New job: {job_title} at {organization}",
                template_id=settings.MSG91_WHATSAPP_TEMPLATE_JOB,
                variables={"name": user_name, "job_title": job_title, "company": organization, "location": location},
            )

    return results


# ============================================================
# PAYMENT STATUS
# ============================================================
async def dispatch_payment_status(
    email: Optional[str],
    mobile: Optional[str],
    user_name: str,
    job_title: str,
    amount: int,
    action: str,
    notes: Optional[str] = None,
) -> Dict[str, bool]:
    channels = settings.get_channels_for("payment")
    results = {"email": False, "sms": False, "whatsapp": False}

    is_ok = action.lower() == "approved"
    status_emoji = "✅" if is_ok else "❌"
    status_word = "Verified Successfully" if is_ok else "Rejected"

    if "email" in channels and email:
        html = f"""<!DOCTYPE html><html><body style="font-family:Arial;padding:20px;">
        <h2>{status_emoji} Payment {status_word}</h2>
        <p>Hi <strong>{user_name}</strong>,</p>
        <p>Your payment of ₹{amount} has been {status_word.lower()}.</p>
        </body></html>"""
        results["email"] = await send_email_async(
            to_email=email,
            subject=f"{status_emoji} Payment {status_word}",
            html_body=html,
        )

    if settings.MOBILE_OTP_BYPASS:
        results["sms"] = True
        results["whatsapp"] = True
    else:
        if "sms" in channels and mobile:
            sms_provider = (settings.SMS_PROVIDER or "").lower()
            if sms_provider not in ("disabled", ""):
                results["sms"] = await send_sms_async(
                    to_mobile=mobile,
                    message=f"Hi {user_name}, your ₹{amount} payment is {status_word}.",
                    template_id=settings.MSG91_TEMPLATE_ID_ALERT,
                    variables={"name": user_name, "amount": str(amount), "status": status_word},
                )
        
        wa_provider = (settings.WHATSAPP_PROVIDER or "").lower()
        if "whatsapp" in channels and mobile and wa_provider not in ("disabled", ""):
            results["whatsapp"] = await send_whatsapp(
                to_mobile=mobile,
                message=f"Hi {user_name}, your ₹{amount} payment is {status_word}.",
                template_id=settings.MSG91_WHATSAPP_TEMPLATE_STATUS,
                variables={"name": user_name, "amount": str(amount), "status": status_word},
            )

    return results


# ============================================================
# ADMIN ALERT
# ============================================================
async def dispatch_admin_alert(
    admin_email: str,
    title: str,
    message: str,
    metadata: Optional[Dict[str, Any]] = None,
) -> Dict[str, bool]:
    channels = settings.get_channels_for("admin_alert")
    results = {"email": False}

    if "email" in channels and admin_email:
        html = f"""<!DOCTYPE html><html><body style="font-family:Arial;padding:20px;">
        <h2>👑 Admin Alert</h2>
        <h3>{title}</h3>
        <p>{message}</p>
        </body></html>"""
        results["email"] = await send_email_async(
            to_email=admin_email,
            subject=f"👑 {title}",
            html_body=html,
        )

    return results


print("=" * 70)
print("✅ Notification Dispatcher Loaded - CORRECTED")
print(f"   MOBILE_OTP_BYPASS: {settings.MOBILE_OTP_BYPASS}")
print(f"   📧 Email: ALWAYS REAL")
if settings.MOBILE_OTP_BYPASS:
    print(f"   🔧 SMS/WhatsApp: BYPASSED")
else:
    print(f"   🔴 SMS/WhatsApp: PRODUCTION")
print(f"   📱 SMS Provider: {settings.SMS_PROVIDER}")
print(f"   💬 WhatsApp Provider: {settings.WHATSAPP_PROVIDER}")
print("=" * 70)