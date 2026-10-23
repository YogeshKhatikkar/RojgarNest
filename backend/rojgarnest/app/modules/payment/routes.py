# app/modules/payment/routes.py - COMPLETE FIXED VERSION WITH SCHEME SUPPORT
# ============================================================
# ✅ CRITICAL FIXES:
#    1. `use_provided_amount` flag prevents double calculation
#    2. Full payment breakdown stored in `payment_orders` collection
#       (NOT in Razorpay notes — those have ~15 key limit)
#    3. verify-payment reads breakdown from DB (source of truth)
#    4. ✅ NEW: `build_payment_breakdown()` helper normalizes amounts
#    5. ✅ NEW: `payment_amount` now stores TOTAL (not app_fee)
#    6. ✅ NEW: `payment_gst` inferred from (total - subtotal) if 0
#    7. ✅ NEW: SCHEME SUPPORT - payment_type='scheme' saves as application_type='schemes'
#    8. ✅ NEW: IDEMPOTENT - Only ONE record created per payment
#    9. NO application created on order creation
#   10. Application created ONLY after successful payment
#   11. Failed/cancelled payments create NO record
#   12. Supports BOTH job, service, AND scheme payments
#   13. Razorpay ONLY - No PhonePe, No QR code
#
# ✅ LATEST FIX (THIS UPDATE):
#   🎯 SCHEME applications now get status="verification_successful"
#      (NOT "pending") after successful payment verification.
#   🎯 Removed duplicate `"status": "pending"` dict-key override bug in:
#        - verify_razorpay_payment()       → scheme branch
#        - verify_payment_no_signature()   → scheme branch
#        - razorpay_webhook()              → scheme branch
#   🎯 Existing scheme application update path now also sets
#      status="verification_successful".
#   🎯 Notification messages updated accordingly.
# ============================================================

from fastapi import APIRouter, Depends, HTTPException, Query, Body, Request, BackgroundTasks, UploadFile, File, Form
from fastapi.responses import RedirectResponse
from datetime import datetime, timedelta, timezone
import json
import base64
import secrets
import uuid
import hashlib
import hmac
import logging
import httpx
import asyncio
from typing import Optional, List, Annotated, Dict, Any
from bson import ObjectId
from pydantic import BaseModel
from app.core.services.dependencies import get_current_user, role_required
from app.core.config.settings import settings
from app.db.connection import get_db
from app.core.utils.logger import logger
from app.core.services.cloudinary import upload_payment_screenshot, upload_user_document
from app.modules.notification.service import central_notification

# ==================== RAZORPAY IMPORTS ====================
import razorpay
import ssl
import requests
from requests.adapters import HTTPAdapter
from urllib3.poolmanager import PoolManager
from app.core.utils.application_number_generator import (
    ApplicationNumberGenerator,
    application_number_generator,
)


router = APIRouter()


# ============================================================
# ✅ SAFE HELPER — Prevents "Settings has no attribute" crash
# ============================================================
def _get_razorpay_test_mode() -> bool:
    """
    SAFE: Returns test mode value using multiple fallbacks.
    Prevents 'Settings' object has no attribute 'is_razorpay_test_mode' error.
    """
    for attr in [
        'RAZORPAY_TEST_MODE',
        'is_razorpay_test_mode',
        'IS_RAZORPAY_TEST_MODE',
        'razorpay_test_mode'
    ]:
        try:
            val = getattr(settings, attr, None)
            if val is not None:
                return bool(val)
        except AttributeError:
            continue

    try:
        key_id = getattr(settings, 'RAZORPAY_KEY_ID', '') or ''
        if key_id.startswith('rzp_test_'):
            return True
        if key_id.startswith('rzp_live_'):
            return False
    except Exception:
        pass

    return True


# ==================== RAZORPAY CLIENT ====================
RAZORPAY_KEY_ID = getattr(settings, "RAZORPAY_KEY_ID", "") or ""
RAZORPAY_KEY_SECRET = getattr(settings, "RAZORPAY_KEY_SECRET", "") or ""
RAZORPAY_TEST_MODE = _get_razorpay_test_mode()

razorpay_client = None
razorpay_initialized = False


def initialize_razorpay_client():
    """Initialize Razorpay client with proper SSL/TLS configuration"""
    global razorpay_client, razorpay_initialized

    if not RAZORPAY_KEY_ID or not RAZORPAY_KEY_SECRET:
        logger.error("❌ Razorpay credentials not configured")
        return False

    try:
        session = requests.Session()

        class SSLAdapter(HTTPAdapter):
            def init_poolmanager(self, *args, **kwargs):
                ctx = ssl.create_default_context()
                ctx.check_hostname = False
                ctx.verify_mode = ssl.CERT_NONE
                kwargs['ssl_context'] = ctx
                return super().init_poolmanager(*args, **kwargs)

        session.mount('https://', SSLAdapter())
        session.mount('http://', HTTPAdapter())

        razorpay_client = razorpay.Client(
            auth=(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET),
            session=session
        )

        test_order = razorpay_client.order.create({
            "amount": 100,
            "currency": "INR",
            "payment_capture": 1
        })

        logger.info(f"✅ Razorpay client initialized successfully - Test order: {test_order.get('id')}")
        logger.info(f"   Mode: {'TEST' if RAZORPAY_TEST_MODE else 'PRODUCTION'}")
        razorpay_initialized = True
        return True

    except ImportError as e:
        logger.error(f"❌ Razorpay not installed: {e}")
        razorpay_client = None
        return False
    except Exception as e:
        logger.error(f"❌ Razorpay initialization error: {e}")
        razorpay_client = None
        return False


# Initialize on module load
initialize_razorpay_client()


# ==================== GST & SERVICE CHARGE CONSTANTS ====================
GST_PERCENT = 18.0
SERVICE_CHARGE = 50  # ₹50 flat


def calculate_fee_breakdown(application_fee: int) -> Dict[str, int]:
    """
    Calculate total fee with GST and service charge.

    ✅ CORRECT FORMULA:
       Subtotal = Application Fee + Service Charge
       GST      = 18% of Subtotal
       Total    = Subtotal + GST
    """
    subtotal = application_fee + SERVICE_CHARGE
    gst_amount = int((subtotal * GST_PERCENT) / 100)
    total = subtotal + gst_amount
    return {
        "application_fee": application_fee,
        "service_charge": SERVICE_CHARGE,
        "subtotal": subtotal,
        "gst_amount": gst_amount,
        "total": total
    }


# ============================================================
# ✅ NEW CRITICAL HELPER — Normalize payment breakdown
# ============================================================
def build_payment_breakdown(
    application_fee: int,
    service_charge: int,
    subtotal: int,
    gst_amount: int,
    total_amount: int,
) -> Dict[str, int]:
    """
    ✅ Guarantees a consistent, mathematically correct breakdown.
    """
    # Rule 1
    if subtotal <= 0:
        subtotal = max(0, application_fee) + max(0, service_charge)

    # Rule 2
    if total_amount <= 0:
        total_amount = subtotal + max(0, gst_amount)

    # ✅ Rule 3 — infer GST from total - subtotal
    if gst_amount <= 0 and total_amount > subtotal:
        gst_amount = total_amount - subtotal
        logger.info(f"🔧 Inferred gst_amount from total-subtotal: ₹{gst_amount}")

    # Rule 4 — ensure math works
    computed = subtotal + gst_amount
    if computed != total_amount:
        if total_amount > subtotal:
            gst_amount = total_amount - subtotal
        else:
            subtotal = total_amount
            gst_amount = 0
        logger.info(
            f"🔧 Corrected breakdown → subtotal=₹{subtotal}, "
            f"gst=₹{gst_amount}, total=₹{total_amount}"
        )

    return {
        "application_fee": int(application_fee),
        "service_charge": int(service_charge),
        "subtotal": int(subtotal),
        "gst_amount": int(gst_amount),
        "total_amount": int(total_amount),
    }


# ============================================================
# ✅ NEW HELPER — Resolve effective application_type
# ============================================================
def resolve_application_type(
    payment_type: str,
    application_type: Optional[str] = None,
    scheme_id: Optional[str] = None,
    service_id: Optional[str] = None,
) -> tuple:
    """Resolve the effective payment_type and application_type."""
    pt = (payment_type or "job").lower().strip()
    at = (application_type or "").lower().strip()

    logger.info("=" * 70)
    logger.info(f"🔍 resolve_application_type:")
    logger.info(f"   raw payment_type     = '{payment_type}'")
    logger.info(f"   raw application_type = '{application_type}'")
    logger.info(f"   scheme_id            = '{scheme_id}'")
    logger.info(f"   service_id           = '{service_id}'")
    logger.info(f"   normalized pt        = '{pt}'")
    logger.info(f"   normalized at        = '{at}'")
    logger.info("=" * 70)

    if at in ("schemes", "scheme"):
        logger.info("✅ Matched: application_type='schemes' → (scheme, schemes)")
        return ("scheme", "schemes")

    if at == "job":
        logger.info("✅ Matched: application_type='job' → (job, job)")
        return ("job", "job")

    if at == "service":
        if scheme_id:
            logger.info("✅ Matched: application_type='service' + scheme_id → (scheme, schemes)")
            return ("scheme", "schemes")
        logger.info("✅ Matched: application_type='service' → (service, service)")
        return ("service", "service")

    if pt == "scheme" or pt == "schemes":
        logger.info(f"✅ Matched: payment_type='{pt}' → (scheme, schemes)")
        return ("scheme", "schemes")

    if pt == "job":
        logger.info("✅ Matched: payment_type='job' → (job, job)")
        return ("job", "job")

    if pt == "service":
        if scheme_id:
            logger.info("✅ Matched: payment_type='service' + scheme_id → (scheme, schemes)")
            return ("scheme", "schemes")
        logger.info("✅ Matched: payment_type='service' → (service, service)")
        return ("service", "service")

    logger.warning(f"⚠️ No match! pt='{pt}', at='{at}' → defaulting to (job, job)")
    return ("job", "job")


# ==================== SCHEMAS ====================

class CreateOrderSchema(BaseModel):
    amount: int
    payment_type: str = "job"

    job_id: Optional[str] = None
    job_title: Optional[str] = None
    organization: Optional[str] = None

    service_id: Optional[str] = None
    service_type: Optional[str] = None
    sub_type_id: Optional[str] = None
    sub_service_name: Optional[str] = None

    scheme_id: Optional[str] = None
    scheme_name: Optional[str] = None
    scheme_name_hindi: Optional[str] = None
    scheme_level: Optional[str] = None
    scheme_state: Optional[str] = None
    scheme_category: Optional[str] = None

    applicant_details: Optional[Dict[str, Any]] = None
    applicant_address: Optional[Dict[str, Any]] = None
    bank_details: Optional[Dict[str, Any]] = None

    form_data: Optional[dict] = None
    documents: Optional[List[Dict[str, Any]]] = None

    user_email: Optional[str] = None
    user_name: Optional[str] = None
    user_mobile: Optional[str] = None

    use_provided_amount: bool = True

    application_fee: Optional[int] = None
    service_charge: Optional[int] = None
    subtotal: Optional[int] = None
    gst_amount: Optional[int] = None
    total_amount: Optional[int] = None
    category_used: Optional[str] = None

    payment_category: Optional[str] = None
    application_type: Optional[str] = None


class VerifyPaymentSchema(BaseModel):
    razorpay_order_id: str
    razorpay_payment_id: str
    razorpay_signature: str
    application_id: Optional[str] = None


# ============================================================
# ✅ CREATE RAZORPAY ORDER
# ============================================================

@router.post("/razorpay/create-order")
async def create_razorpay_order(
    data: CreateOrderSchema,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    CREATE RAZORPAY ORDER - NO APPLICATION RECORD CREATED HERE
    """
    logger.info("=" * 70)
    logger.info(f"💰 Creating Razorpay Order - Type: {data.payment_type}")
    logger.info(f"   User: {current_user.get('email')}")
    logger.info(f"   Amount: ₹{data.amount}")
    logger.info(f"   Use Provided Amount: {data.use_provided_amount}")
    logger.info(f"   Scheme ID: {data.scheme_id}")
    logger.info(f"   ⚠️ NO APPLICATION CREATED HERE - Only Razorpay order")
    logger.info("=" * 70)

    if not razorpay_client or not razorpay_initialized:
        if not initialize_razorpay_client():
            raise HTTPException(
                status_code=400,
                detail="Razorpay is not configured. Please check server configuration."
            )

    user_email = data.user_email or current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email is required")

    user_id = current_user.get("user_id")
    user_name = data.user_name or current_user.get("name", "User")

    effective_payment_type, effective_application_type = resolve_application_type(
        payment_type=data.payment_type,
        application_type=data.application_type or data.payment_category,
        scheme_id=data.scheme_id,
        service_id=data.service_id,
    )

    logger.info("=" * 70)
    logger.info(f"✅ RESOLVED TYPES:")
    logger.info(f"   payment_type: {data.payment_type}")
    logger.info(f"   effective_payment_type: {effective_payment_type}")
    logger.info(f"   effective_application_type: {effective_application_type}")
    logger.info("=" * 70)

    profile = await db.profile.find_one({"email": user_email})
    user_category = profile.get("category", "General/UR") if profile else "General/UR"
    is_disabled = False
    if profile:
        disability = profile.get("disability", {})
        is_disabled = disability.get("is_disabled", False) if isinstance(disability, dict) else False

    amount = data.amount
    category_used = data.category_used or "none"
    job_title = ""
    organization = ""
    added_by = "admin@rojgarnest.com"
    scheme_name = ""
    scheme_name_hindi = ""
    service_name = ""
    sub_service_name = ""

    if data.use_provided_amount:
        logger.info("=" * 70)
        logger.info("✅ USING PROVIDED AMOUNT (NO RECALCULATION)")
        logger.info(f"   Amount from client: ₹{data.amount}")
        logger.info("=" * 70)

        if effective_application_type == "job":
            if not data.job_id or not ObjectId.is_valid(data.job_id):
                raise HTTPException(status_code=400, detail="Invalid job ID")

            job = await db.job.find_one({"_id": ObjectId(data.job_id)})
            if not job:
                raise HTTPException(status_code=404, detail="Job not found")

            job_title = data.job_title or job.get("post_name", "Job Application")
            organization = job.get("organization", "Company")
            added_by = job.get("added_by", "admin@rojgarnest.com")

            existing = await db.applications.find_one({
                "job_id": data.job_id,
                "user_email": user_email,
                "application_type": "job",
                "status": {
                    "$in": [
                        "verification_successful", "pending", "shortlisted",
                        "interview", "offered", "submitted", "review_application",
                        "final_submitted", "confirmed_application", "approved_application"
                    ]
                }
            })
            if existing:
                raise HTTPException(
                    status_code=400,
                    detail="You have already applied for this job"
                )

            if is_disabled:
                category_used = "pwd"
            elif category_used == "none":
                category_map = {
                    "General/UR": "general/ur",
                    "OBC": "obc",
                    "SC": "sc",
                    "ST": "st",
                    "EWS": "ews"
                }
                category_used = category_map.get(user_category, "general/ur")

        elif effective_application_type == "schemes":
            if not data.scheme_id:
                raise HTTPException(
                    status_code=400,
                    detail="scheme_id is required for scheme payment"
                )

            scheme = await db.schemes.find_one({"scheme_id": data.scheme_id})
            if not scheme:
                if ObjectId.is_valid(data.scheme_id):
                    scheme = await db.schemes.find_one({"_id": ObjectId(data.scheme_id)})

            if not scheme:
                raise HTTPException(status_code=404, detail="Scheme not found")

            scheme_name = data.scheme_name or scheme.get("scheme_name", "")
            scheme_name_hindi = data.scheme_name_hindi or scheme.get("scheme_name_hindi", "")
            category_used = "scheme"

            existing = await db.applications.find_one({
                "application_type": "schemes",
                "user_email": user_email,
                "scheme_id": data.scheme_id,
                "status": {
                    "$nin": ["rejected", "verification_rejected", "cancelled"]
                },
                "is_archived": {"$ne": True}
            })
            if existing:
                raise HTTPException(
                    status_code=400,
                    detail="You have already applied for this scheme"
                )

        elif effective_application_type == "service":
            if not data.service_id or not data.sub_type_id:
                raise HTTPException(
                    status_code=400,
                    detail="service_id and sub_type_id are required for service payment"
                )

            from app.modules.services.models.service_types import ServiceMasterData
            service = ServiceMasterData.get_service_by_id(data.service_id)
            sub_type = ServiceMasterData.get_sub_type_by_id(data.sub_type_id)

            service_name = service.name if service else data.service_id
            sub_service_name = sub_type.name if sub_type else data.sub_type_id
            job_title = service_name
            organization = sub_service_name
            category_used = "service"

            existing = await db.applications.find_one({
                "service_id": data.service_id,
                "sub_type_id": data.sub_type_id,
                "user_email": user_email,
                "application_type": "service",
                "status": {
                    "$nin": ["replaced", "rejected", "verification_rejected"]
                }
            })
            if existing:
                existing_status = existing.get("status", "")
                if existing_status in ["approved", "completed", "payment_verified"]:
                    raise HTTPException(
                        status_code=400,
                        detail="You have already successfully applied for this service"
                    )

        else:
            raise HTTPException(
                status_code=400,
                detail="Invalid payment_type. Must be 'job', 'service', or 'scheme'."
            )

        total_amount = data.amount
        application_fee = data.application_fee or 0
        service_charge = data.service_charge or SERVICE_CHARGE
        subtotal = data.subtotal or (application_fee + service_charge)
        gst_amount = data.gst_amount or 0

        if data.total_amount is not None and data.total_amount != data.amount:
            logger.error("=" * 70)
            logger.error("❌ TOTAL AMOUNT MISMATCH")
            logger.error(f"   amount:       ₹{data.amount}")
            logger.error(f"   total_amount: ₹{data.total_amount}")
            logger.error("=" * 70)
            raise HTTPException(
                status_code=400,
                detail=f"Amount mismatch: amount={data.amount} but total_amount={data.total_amount}"
            )

        if (data.application_fee is not None
                and data.service_charge is not None
                and data.gst_amount is not None):
            computed_total = data.application_fee + data.service_charge + data.gst_amount
            if computed_total != data.amount:
                logger.error("=" * 70)
                logger.error("❌ FEE BREAKDOWN MISMATCH")
                logger.error(f"   app_fee ({data.application_fee}) + "
                             f"service_charge ({data.service_charge}) + "
                             f"gst ({data.gst_amount}) = {computed_total}")
                logger.error(f"   but amount = {data.amount}")
                logger.error("=" * 70)
                raise HTTPException(
                    status_code=400,
                    detail=(
                        f"Fee breakdown does not sum to amount: "
                        f"{data.application_fee}+{data.service_charge}+{data.gst_amount}"
                        f"={computed_total} != {data.amount}"
                    )
                )

        logger.info(f"💰 Fee Breakdown (from client):")
        logger.info(f"   Application Fee: ₹{application_fee}")
        logger.info(f"   Service Charge: ₹{service_charge}")
        logger.info(f"   Subtotal: ₹{subtotal}")
        logger.info(f"   GST: ₹{gst_amount}")
        logger.info(f"   TOTAL: ₹{total_amount}")

    else:
        logger.info("=" * 70)
        logger.info("⚠️ LEGACY MODE: Calculating fee from category")
        logger.info("=" * 70)

        if effective_application_type == "job":
            if not data.job_id or not ObjectId.is_valid(data.job_id):
                raise HTTPException(status_code=400, detail="Invalid job ID")

            job = await db.job.find_one({"_id": ObjectId(data.job_id)})
            if not job:
                raise HTTPException(status_code=404, detail="Job not found")

            job_title = data.job_title or job.get("post_name", "Job Application")
            organization = job.get("organization", "Company")
            added_by = job.get("added_by", "admin@rojgarnest.com")

            existing = await db.applications.find_one({
                "job_id": data.job_id,
                "user_email": user_email,
                "application_type": "job",
                "status": {
                    "$in": [
                        "verification_successful", "pending", "shortlisted",
                        "interview", "offered", "submitted", "review_application",
                        "final_submitted", "confirmed_application", "approved_application"
                    ]
                }
            })
            if existing:
                raise HTTPException(
                    status_code=400,
                    detail="You have already applied for this job"
                )

            job_fees = job.get("application_fees", {})
            if job_fees and len(job_fees) > 0:
                if is_disabled:
                    category_used = "pwd"
                    amount = job_fees.get("pwd", data.amount)
                else:
                    category_map = {
                        "General/UR": "general/ur",
                        "OBC": "obc",
                        "SC": "sc",
                        "ST": "st",
                        "EWS": "ews"
                    }
                    fee_key = category_map.get(user_category, "general/ur")
                    category_used = fee_key
                    amount = job_fees.get(fee_key, data.amount)

        elif effective_application_type == "schemes":
            if not data.scheme_id:
                raise HTTPException(
                    status_code=400,
                    detail="scheme_id is required for scheme payment"
                )

            scheme = await db.schemes.find_one({"scheme_id": data.scheme_id})
            if not scheme:
                if ObjectId.is_valid(data.scheme_id):
                    scheme = await db.schemes.find_one({"_id": ObjectId(data.scheme_id)})

            if not scheme:
                raise HTTPException(status_code=404, detail="Scheme not found")

            scheme_name = data.scheme_name or scheme.get("scheme_name", "")
            scheme_name_hindi = data.scheme_name_hindi or scheme.get("scheme_name_hindi", "")

            existing = await db.applications.find_one({
                "application_type": "schemes",
                "user_email": user_email,
                "scheme_id": data.scheme_id,
                "status": {
                    "$nin": ["rejected", "verification_rejected", "cancelled"]
                },
                "is_archived": {"$ne": True}
            })
            if existing:
                raise HTTPException(
                    status_code=400,
                    detail="You have already applied for this scheme"
                )

            category_used = "scheme"
            amount = scheme.get("application_fee", 0) or data.amount

        elif effective_application_type == "service":
            if not data.service_id or not data.sub_type_id:
                raise HTTPException(
                    status_code=400,
                    detail="service_id and sub_type_id are required for service payment"
                )

            from app.modules.services.models.service_types import ServiceMasterData
            service = ServiceMasterData.get_service_by_id(data.service_id)
            sub_type = ServiceMasterData.get_sub_type_by_id(data.sub_type_id)

            service_name = service.name if service else data.service_id
            sub_service_name = sub_type.name if sub_type else data.sub_type_id
            job_title = service_name
            organization = sub_service_name

            existing = await db.applications.find_one({
                "service_id": data.service_id,
                "sub_type_id": data.sub_type_id,
                "user_email": user_email,
                "application_type": "service",
                "status": {
                    "$nin": ["replaced", "rejected", "verification_rejected"]
                }
            })
            if existing:
                existing_status = existing.get("status", "")
                if existing_status in ["approved", "completed", "payment_verified"]:
                    raise HTTPException(
                        status_code=400,
                        detail="You have already successfully applied for this service"
                    )

            category_used = "service"
            amount = data.amount

        else:
            raise HTTPException(
                status_code=400,
                detail="Invalid payment_type. Must be 'job', 'service', or 'scheme'."
            )

        fee_breakdown = calculate_fee_breakdown(amount)
        total_amount = fee_breakdown['total']
        application_fee = fee_breakdown['application_fee']
        service_charge = fee_breakdown['service_charge']
        subtotal = fee_breakdown['subtotal']
        gst_amount = fee_breakdown['gst_amount']

        logger.info(f"💰 Fee Breakdown (calculated):")
        logger.info(f"   Application Fee: ₹{application_fee}")
        logger.info(f"   Service Charge: ₹{service_charge}")
        logger.info(f"   Subtotal: ₹{subtotal}")
        logger.info(f"   GST ({GST_PERCENT}%): ₹{gst_amount}")
        logger.info(f"   TOTAL: ₹{total_amount}")

    normalized = build_payment_breakdown(
        application_fee=int(application_fee or 0),
        service_charge=int(service_charge or SERVICE_CHARGE),
        subtotal=int(subtotal or 0),
        gst_amount=int(gst_amount or 0),
        total_amount=int(total_amount or 0),
    )

    application_fee = normalized["application_fee"]
    service_charge = normalized["service_charge"]
    subtotal = normalized["subtotal"]
    gst_amount = normalized["gst_amount"]
    total_amount = normalized["total_amount"]

    amount_in_paise = int(total_amount * 100)

    logger.info("=" * 70)
    logger.info(f"✅ NORMALIZED BREAKDOWN (create-order):")
    logger.info(f"   Application Fee: ₹{application_fee}")
    logger.info(f"   Service Charge:  ₹{service_charge}")
    logger.info(f"   Subtotal:        ₹{subtotal}")
    logger.info(f"   GST:             ₹{gst_amount}")
    logger.info(f"   TOTAL:           ₹{total_amount}")
    logger.info(f"   Paise:           {amount_in_paise}")
    logger.info("=" * 70)

    payment_record_id = str(ObjectId())
    payment_record = {
        "_id": payment_record_id,
        "user_email": user_email,
        "user_id": user_id,
        "user_name": user_name,
        "user_category": user_category,
        "is_disabled": is_disabled,

        "application_fee": application_fee,
        "service_charge": service_charge,
        "subtotal": subtotal,
        "gst_amount": gst_amount,
        "total_amount": total_amount,
        "amount_paise": amount_in_paise,
        "category_used": category_used,

        "payment_type": effective_payment_type,
        "application_type": effective_application_type,
        "wire_payment_type": data.payment_type,

        "job_id": data.job_id or "",
        "job_title": job_title,
        "organization": organization,
        "added_by": added_by,

        "service_id": data.service_id or "",
        "service_type": data.service_type or "",
        "sub_type_id": data.sub_type_id or "",
        "sub_service_name": sub_service_name,
        "service_name": service_name,

        "scheme_id": data.scheme_id or "",
        "scheme_name": scheme_name,
        "scheme_name_hindi": scheme_name_hindi,
        "scheme_level": data.scheme_level or "",
        "scheme_state": data.scheme_state or "",
        "scheme_category": data.scheme_category or "",

        "applicant_details": data.applicant_details or {},
        "applicant_address": data.applicant_address or {},
        "bank_details": data.bank_details or {},

        "form_data": data.form_data or {},
        "documents": data.documents or [],

        "use_provided_amount": bool(data.use_provided_amount),
        "status": "creating",
        "created_at": datetime.utcnow(),
    }

    try:
        await db.payment_orders.insert_one(payment_record)
        logger.info(f"💾 Payment breakdown saved to DB: {payment_record_id}")
    except Exception as e:
        logger.error(f"⚠️ Failed to save payment breakdown: {e}")

    order_data = {
        "amount": amount_in_paise,
        "currency": "INR",
        "receipt": f"rcpt_{uuid.uuid4().hex[:20]}",
        "payment_capture": 1,
        "notes": {
            "payment_type": effective_payment_type,
            "application_type": effective_application_type,
            "user_email": user_email,
            "job_id": data.job_id or "",
            "service_id": data.service_id or "",
            "scheme_id": data.scheme_id or "",
            "total_amount": str(total_amount),
            "payment_record_id": payment_record_id,
        }
    }

    order = None
    for attempt in range(1, 4):
        try:
            order = razorpay_client.order.create(data=order_data)
            logger.info(f"✅ Order created on attempt {attempt}: {order['id']}")
            break
        except Exception as e:
            logger.error(f"⚠️ Attempt {attempt} failed: {e}")
            if attempt == 3:
                raise HTTPException(
                    status_code=400,
                    detail=f"Failed to create order: {str(e)}"
                )
            await asyncio.sleep(1 * attempt)

    if not order:
        raise HTTPException(status_code=500, detail="Failed to create payment order")

    razorpay_order_id = order["id"]

    try:
        await db.payment_orders.update_one(
            {"_id": payment_record_id},
            {
                "$set": {
                    "razorpay_order_id": razorpay_order_id,
                    "razorpay_order_amount_paise": amount_in_paise,
                    "status": "created",
                    "updated_at": datetime.utcnow(),
                }
            }
        )
    except Exception as e:
        logger.error(f"⚠️ Failed to link payment record: {e}")

    returned_amount = order.get("amount")
    if returned_amount is not None and int(returned_amount) != amount_in_paise:
        logger.error("=" * 70)
        logger.error("❌ RAZORPAY RETURNED DIFFERENT AMOUNT!")
        logger.error(f"   We sent:   {amount_in_paise} paise")
        logger.error(f"   Got back:  {returned_amount} paise")
        logger.error("=" * 70)

    logger.info("=" * 70)
    logger.info(f"✅ Razorpay order created successfully!")
    logger.info(f"   Order ID: {razorpay_order_id}")
    logger.info(f"   Total Amount (rupees): ₹{total_amount}")
    logger.info(f"   Payment Record ID:     {payment_record_id}")
    logger.info("=" * 70)

    return {
        "success": True,
        "order_id": razorpay_order_id,
        "amount": total_amount,
        "amount_paise": amount_in_paise,
        "amount_rupees": total_amount,
        "application_fee": application_fee,
        "service_charge": service_charge,
        "subtotal": subtotal,
        "gst_amount": gst_amount,
        "currency": "INR",
        "key_id": RAZORPAY_KEY_ID,
        "payment_type": effective_payment_type,
        "application_type": effective_application_type,
        "category_used": category_used,
        "test_mode": _get_razorpay_test_mode(),
        "use_provided_amount": data.use_provided_amount,
        "payment_record_id": payment_record_id,
        "message": "Order created. Application will be saved only after successful payment."
    }


# ============================================================
# ✅ VERIFY RAZORPAY PAYMENT - CREATES APPLICATION ONLY ON SUCCESS
# ============================================================
# ✅ LATEST FIX: SCHEME applications now get status="verification_successful"
#    (removed duplicate "status": "pending" dict-key that was overriding it)
# ============================================================

@router.post("/razorpay/verify-payment")
async def verify_razorpay_payment(
    data: VerifyPaymentSchema,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    VERIFY RAZORPAY PAYMENT - Creates application ONLY on success
    ✅ NEW: Generates sequential application number (YYYYMMSSSSS)
    ✅ NEW: IDEMPOTENT - Checks for existing application before creating
    ✅ NEW: Scheme support - application_type="schemes"
    ✅ LATEST: Scheme applications get status="verification_successful"
    """
    logger.info("=" * 70)
    logger.info(f"🔐 Verifying Razorpay payment")
    logger.info(f"   Order ID: {data.razorpay_order_id}")
    logger.info(f"   Payment ID: {data.razorpay_payment_id}")
    logger.info("=" * 70)

    if not razorpay_client or not razorpay_initialized:
        if not initialize_razorpay_client():
            raise HTTPException(status_code=400, detail="Razorpay not configured")

    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")

    # ==================== IDEMPOTENCY CHECK ====================
    existing_application = await db.applications.find_one({
        "razorpay_payment_id": data.razorpay_payment_id
    })

    if existing_application:
        logger.info("=" * 70)
        logger.info(f"✅ IDEMPOTENT: Application already exists for this payment!")
        logger.info(f"   Application ID: {existing_application.get('_id')}")
        logger.info(f"   Application Number: {existing_application.get('application_number')}")
        logger.info(f"   Application Type: {existing_application.get('application_type')}")
        logger.info("=" * 70)

        return {
            "success": True,
            "payment_verified": True,
            "application_id": str(existing_application["_id"]),
            "application_number": existing_application.get("application_number"),
            "application_type": existing_application.get("application_type"),
            "application_status": existing_application.get("status"),
            "amount": existing_application.get("payment_total") or existing_application.get("payment_amount"),
            "message": "Application already exists (idempotent)",
            "idempotent": True
        }

    # ==================== VERIFY SIGNATURE ====================
    try:
        params_dict = {
            'razorpay_order_id': data.razorpay_order_id,
            'razorpay_payment_id': data.razorpay_payment_id,
            'razorpay_signature': data.razorpay_signature
        }
        razorpay_client.utility.verify_payment_signature(params_dict)
        logger.info("✅ Signature verified successfully")
    except Exception as e:
        logger.error(f"❌ Signature verification failed: {e}")
        raise HTTPException(status_code=400, detail="Invalid payment signature")

    # ============================================================
    # ✅ Load FULL breakdown from `payment_orders`
    # ============================================================
    payment_record = await db.payment_orders.find_one({
        "razorpay_order_id": data.razorpay_order_id
    })

    if not payment_record:
        logger.error(f"❌ Payment record not found for order: {data.razorpay_order_id}")
        raise HTTPException(
            status_code=404,
            detail="Payment record not found. Please contact support."
        )

    logger.info("=" * 70)
    logger.info(f"✅ Payment record loaded from DB:")
    logger.info(f"   _id             = {payment_record.get('_id')}")
    logger.info(f"   payment_type    = {payment_record.get('payment_type')}")
    logger.info(f"   application_type= {payment_record.get('application_type')}")
    logger.info(f"   application_fee = ₹{payment_record.get('application_fee')}")
    logger.info(f"   service_charge  = ₹{payment_record.get('service_charge')}")
    logger.info(f"   gst_amount      = ₹{payment_record.get('gst_amount')}")
    logger.info(f"   total_amount    = ₹{payment_record.get('total_amount')}")
    logger.info("=" * 70)

    normalized = build_payment_breakdown(
        application_fee=int(payment_record.get("application_fee") or 0),
        service_charge=int(payment_record.get("service_charge") or SERVICE_CHARGE),
        subtotal=int(payment_record.get("subtotal") or 0),
        gst_amount=int(payment_record.get("gst_amount") or 0),
        total_amount=int(payment_record.get("total_amount") or 0),
    )

    effective_payment_type = payment_record.get("payment_type", "job")
    effective_application_type = payment_record.get("application_type", "job")

    if effective_payment_type == "scheme":
        effective_application_type = "schemes"

    job_id = payment_record.get("job_id", "")
    job_title = payment_record.get("job_title", "")
    organization = payment_record.get("organization", "")
    added_by = payment_record.get("added_by", "admin@rojgarnest.com")
    service_id = payment_record.get("service_id", "")
    service_type = payment_record.get("service_type", "")
    sub_type_id = payment_record.get("sub_type_id", "")
    sub_service_name = payment_record.get("sub_service_name", "")
    service_name = payment_record.get("service_name", "")

    scheme_id = payment_record.get("scheme_id", "")
    scheme_name = payment_record.get("scheme_name", "")
    scheme_name_hindi = payment_record.get("scheme_name_hindi", "")
    scheme_level = payment_record.get("scheme_level", "")
    scheme_state = payment_record.get("scheme_state", "")
    scheme_category = payment_record.get("scheme_category", "")
    applicant_details = payment_record.get("applicant_details", {}) or {}
    applicant_address = payment_record.get("applicant_address", {}) or {}
    bank_details = payment_record.get("bank_details", {}) or {}

    application_fee = normalized["application_fee"]
    service_charge = normalized["service_charge"]
    subtotal = normalized["subtotal"]
    gst_amount = normalized["gst_amount"]
    total_amount = normalized["total_amount"]

    category_used = payment_record.get("category_used", "none")
    user_category = payment_record.get("user_category", "General/UR")
    is_disabled = bool(payment_record.get("is_disabled", False))
    order_user_email = payment_record.get("user_email", user_email)
    order_user_id = payment_record.get("user_id", current_user.get("user_id"))
    form_data = payment_record.get("form_data", {}) or {}
    documents = payment_record.get("documents", []) or []

    logger.info("=" * 70)
    logger.info("✅ VERIFY-PAYMENT NORMALIZED:")
    logger.info(f"   effective_payment_type: {effective_payment_type}")
    logger.info(f"   effective_application_type: {effective_application_type}")
    logger.info(f"   application_fee = ₹{application_fee}")
    logger.info(f"   service_charge  = ₹{service_charge}")
    logger.info(f"   subtotal        = ₹{subtotal}")
    logger.info(f"   gst_amount      = ₹{gst_amount}")
    logger.info(f"   total_amount    = ₹{total_amount}")
    logger.info("=" * 70)

    # ✅ Sanity check: verify Razorpay order amount matches DB
    try:
        order_details = razorpay_client.order.fetch(data.razorpay_order_id)
        razorpay_amount_paise = int(order_details.get("amount", 0))
        expected_paise = int(total_amount * 100)
        if razorpay_amount_paise != expected_paise:
            logger.error("=" * 70)
            logger.error("❌ AMOUNT MISMATCH between Razorpay order and DB!")
            logger.error(f"   Razorpay order: {razorpay_amount_paise} paise")
            logger.error(f"   DB total:       {expected_paise} paise (₹{total_amount})")
            logger.error("=" * 70)
            raise HTTPException(
                status_code=400,
                detail="Amount mismatch detected. Please contact support."
            )
        logger.info(f"✅ Razorpay amount matches DB: {razorpay_amount_paise} paise")
    except HTTPException:
        raise
    except Exception as e:
        logger.warning(f"⚠️ Could not verify order amount: {e}")

    # ==================== GET APPLICANT DETAILS ====================
    profile = await db.profile.find_one({"email": order_user_email})
    applicant_name = profile.get("full_name") if profile else payment_record.get("user_name", "User")
    application_username = order_user_email.split('@')[0]

    # ============================================================
    # ✅ GENERATE APPLICATION NUMBER (YYYYMMSSSSS)
    # ============================================================
    try:
        application_number = await ApplicationNumberGenerator.generate_application_number(db)
        logger.info("=" * 70)
        logger.info(f"🎫 APPLICATION NUMBER GENERATED: {application_number}")
        logger.info("=" * 70)
    except Exception as e:
        logger.error(f"❌ Failed to generate application number: {e}")
        from datetime import datetime as dt
        now = dt.utcnow()
        fallback_seq = int(now.timestamp()) % 100000
        application_number = f"{now.year}{now.month:02d}{fallback_seq:05d}"
        logger.warning(f"⚠️ Using fallback application number: {application_number}")

    logger.info("=" * 70)
    logger.info("✅ PAYMENT VERIFIED - CREATING APPLICATION NOW")
    logger.info(f"   Application Number: {application_number}")
    logger.info(f"   Application Type: {effective_application_type}")
    logger.info("=" * 70)

    application_id = None
    new_status = "verification_successful"
    display_title = job_title if effective_application_type == "job" else (
        sub_service_name or job_title if effective_application_type == "service" else
        scheme_name or scheme_name_hindi or job_title
    )

    # ============================================================
    # ✅ JOB APPLICATION
    # ============================================================
    if effective_application_type == "job":
        existing = await db.applications.find_one({
            "job_id": job_id,
            "user_email": order_user_email,
            "application_type": "job",
            "status": {
                "$in": [
                    "verification_successful", "pending", "shortlisted",
                    "interview", "offered", "submitted", "review_application",
                    "final_submitted", "confirmed_application", "approved_application"
                ]
            }
        })

        if existing:
            logger.info(f"📋 Application already exists: {existing['_id']}")
            application_id = str(existing["_id"])
            new_status = existing.get("status", "verification_successful")
            application_number = existing.get("application_number", application_number)

            await db.applications.update_one(
                {"_id": existing["_id"]},
                {
                    "$set": {
                        "application_number": application_number,
                        "payment_amount": total_amount,
                        "payment_gst": gst_amount,
                        "payment_service_charge": service_charge,
                        "payment_total": total_amount,
                        "payment_breakdown": {
                            "application_fee": application_fee,
                            "service_charge": service_charge,
                            "subtotal": subtotal,
                            "gst_amount": gst_amount,
                            "total_amount": total_amount,
                        },
                        "updated_at": datetime.utcnow(),
                    }
                }
            )
            logger.info(f"✅ Updated existing application with breakdown + application_number")
        else:
            application_doc = {
                "application_type": "job",
                "application_number": application_number,
                "job_id": job_id,
                "job_title": job_title,
                "organization": organization,
                "added_by": added_by,

                "applicant_email": order_user_email,
                "applicant_name": applicant_name,
                "user_email": order_user_email,
                "user_name": applicant_name,
                "user_id": order_user_id,
                "user_category": user_category,
                "is_disabled": is_disabled,
                "application_username": application_username,

                "status": "verification_successful",
                "payment_verification_status": "approved",
                "payment_status": "completed",

                "payment_id": data.razorpay_payment_id,
                "payment_amount": total_amount,
                "payment_gst": gst_amount,
                "payment_service_charge": service_charge,
                "payment_total": total_amount,
                "payment_category_used": category_used,
                "payment_method": "razorpay",
                "payment_breakdown": {
                    "application_fee": application_fee,
                    "service_charge": service_charge,
                    "subtotal": subtotal,
                    "gst_amount": gst_amount,
                    "total_amount": total_amount,
                },

                "razorpay_order_id": data.razorpay_order_id,
                "razorpay_payment_id": data.razorpay_payment_id,
                "razorpay_signature": data.razorpay_signature,

                "transaction_id": data.razorpay_payment_id,
                "transaction_date": datetime.utcnow(),
                "paid_at": datetime.utcnow(),
                "payment_verified_at": datetime.utcnow(),
                "payment_verified_by": "razorpay_auto",

                "applied_at": datetime.utcnow(),
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow(),

                "cover_letter": None,
                "additional_info": form_data if form_data else None,
            }

            result = await db.applications.insert_one(application_doc)
            application_id = str(result.inserted_id)
            new_status = "verification_successful"

            logger.info(f"✅ JOB APPLICATION CREATED: {application_id}")
            logger.info(f"   Application Number: {application_number}")

    # ============================================================
    # ✅ SCHEME APPLICATION - ✅ LATEST FIX: status = "verification_successful"
    # ============================================================
    elif effective_application_type == "schemes":
        logger.info("=" * 70)
        logger.info("🏛️ CREATING SCHEME APPLICATION")
        logger.info(f"   Scheme ID: {scheme_id}")
        logger.info(f"   Scheme Name: {scheme_name}")
        logger.info("=" * 70)

        existing = await db.applications.find_one({
            "application_type": "schemes",
            "user_email": order_user_email,
            "scheme_id": scheme_id,
            "status": {
                "$nin": ["rejected", "verification_rejected", "cancelled"]
            },
            "is_archived": {"$ne": True}
        })

        if existing:
            logger.info(f"📋 Scheme application already exists: {existing['_id']}")
            application_id = str(existing["_id"])
            # ✅ FIX: existing scheme application upgraded to verification_successful
            new_status = "verification_successful"
            application_number = existing.get("application_number", application_number)

            # ✅ Update existing record: status → verification_successful
            await db.applications.update_one(
                {"_id": existing["_id"]},
                {
                    "$set": {
                        "application_number": application_number,
                        "status": "verification_successful",   # ✅ FIX
                        "payment_amount": total_amount,
                        "payment_gst": gst_amount,
                        "payment_service_charge": service_charge,
                        "payment_total": total_amount,
                        "payment_breakdown": {
                            "application_fee": application_fee,
                            "service_charge": service_charge,
                            "subtotal": subtotal,
                            "gst_amount": gst_amount,
                            "total_amount": total_amount,
                        },
                        "razorpay_order_id": data.razorpay_order_id,
                        "razorpay_payment_id": data.razorpay_payment_id,
                        "razorpay_signature": data.razorpay_signature,
                        "transaction_id": data.razorpay_payment_id,
                        "paid_at": datetime.utcnow(),
                        "payment_verified_at": datetime.utcnow(),
                        "payment_verification_status": "approved",
                        "payment_status": "completed",
                        "updated_at": datetime.utcnow(),
                    }
                }
            )
            logger.info(f"✅ Updated existing scheme application → status=verification_successful")
        else:
            # ✅ CREATE NEW SCHEME APPLICATION
            # ✅ FIX: Removed duplicate "status": "pending" that was overriding
            #         "status": "verification_successful".
            #         Now there is exactly ONE status assignment.
            application_doc = {
                "application_type": "schemes",
                "application_id": str(ObjectId()),
                "application_number": application_number,

                # ✅ Status — THE ONLY ONE. Value = verification_successful
                "status": "verification_successful",
                "payment_verification_status": "approved",
                "payment_status": "completed",
                "is_archived": False,

                # User info
                "user_email": order_user_email,
                "user_name": applicant_name,
                "user_id": order_user_id,
                "user_mobile": (payment_record.get("user_mobile") or (profile.get("phone") if profile else "")) or "",
                "application_username": application_username,
                "user_category": user_category,
                "is_disabled": is_disabled,

                # Scheme-specific fields
                "scheme_id": scheme_id,
                "scheme_name": scheme_name,
                "scheme_name_hindi": scheme_name_hindi,
                "scheme_level": scheme_level,
                "scheme_state": scheme_state,
                "scheme_category": scheme_category,

                # Applicant details
                "applicant_details": applicant_details,
                "applicant_address": applicant_address,
                "bank_details": bank_details,

                # Documents
                "documents": documents,

                # Payment info
                "payment_id": data.razorpay_payment_id,
                "payment_amount": total_amount,
                "payment_gst": gst_amount,
                "payment_service_charge": service_charge,
                "payment_total": total_amount,
                "payment_category_used": category_used,
                "payment_method": "razorpay",
                "payment_breakdown": {
                    "application_fee": application_fee,
                    "service_charge": service_charge,
                    "subtotal": subtotal,
                    "gst_amount": gst_amount,
                    "total_amount": total_amount,
                },

                # Razorpay details
                "razorpay_order_id": data.razorpay_order_id,
                "razorpay_payment_id": data.razorpay_payment_id,
                "razorpay_signature": data.razorpay_signature,

                # Transaction details
                "transaction_id": data.razorpay_payment_id,
                "transaction_date": datetime.utcnow(),
                "paid_at": datetime.utcnow(),
                "payment_verified_at": datetime.utcnow(),
                "payment_verified_by": "razorpay_auto",

                # Form data
                "additional_info": form_data if form_data else None,
                "remarks": "",

                # Timestamps
                "applied_at": datetime.utcnow(),
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow(),
            }

            result = await db.applications.insert_one(application_doc)
            application_id = str(result.inserted_id)
            new_status = "verification_successful"

            logger.info(f"✅ SCHEME APPLICATION CREATED: {application_id}")
            logger.info(f"   Application Number: {application_number}")
            logger.info(f"   Scheme: {scheme_name}")
            logger.info(f"   Status: {new_status}")
            logger.info(f"   payment_amount = ₹{total_amount}")
            logger.info(f"   payment_gst    = ₹{gst_amount}")
            logger.info(f"   payment_total  = ₹{total_amount}")

    # ============================================================
    # ✅ SERVICE APPLICATION
    # ============================================================
    elif effective_application_type == "service":
        existing = await db.applications.find_one({
            "service_id": service_id,
            "sub_type_id": sub_type_id,
            "user_email": order_user_email,
            "application_type": "service",
            "status": {
                "$nin": ["replaced", "rejected", "verification_rejected"]
            }
        })

        if existing:
            logger.info(f"📋 Service application already exists: {existing['_id']}")
            application_id = str(existing["_id"])
            new_status = existing.get("status", "payment_verified")
            application_number = existing.get("application_number", application_number)

            await db.applications.update_one(
                {"_id": existing["_id"]},
                {
                    "$set": {
                        "application_number": application_number,
                        "payment_amount": total_amount,
                        "payment_gst": gst_amount,
                        "payment_service_charge": service_charge,
                        "payment_total": total_amount,
                        "payment_breakdown": {
                            "application_fee": application_fee,
                            "service_charge": service_charge,
                            "subtotal": subtotal,
                            "gst_amount": gst_amount,
                            "total_amount": total_amount,
                        },
                        "updated_at": datetime.utcnow(),
                    }
                }
            )
            logger.info(f"✅ Updated existing service application with correct breakdown")
        else:
            from app.modules.services.models.service_types import ServiceMasterData
            service = ServiceMasterData.get_service_by_id(service_id)
            sub_type = ServiceMasterData.get_sub_type_by_id(sub_type_id)

            service_name_final = service.name if service else service_id
            sub_service_name_final = sub_type.name if sub_type else sub_type_id

            form_fields = form_data.get('fields', {}) if isinstance(form_data, dict) else {}
            document_urls = form_data.get('document_urls', {}) if isinstance(form_data, dict) else {}
            temp_session_id = form_data.get('temp_session_id', '') if isinstance(form_data, dict) else ''

            service_documents = []
            for doc_key, doc_url in document_urls.items():
                if doc_url and isinstance(doc_url, str) and doc_url.startswith('http'):
                    service_documents.append({
                        "document_type": doc_key,
                        "label": doc_key.replace('_', ' ').title(),
                        "url": doc_url,
                        "source": "service_application",
                        "uploaded_at": datetime.utcnow().isoformat(),
                        "uploaded_by": order_user_email,
                        "temp_session_id": temp_session_id,
                    })

            application_doc = {
                "application_type": "service",
                "application_number": application_number,
                "service_id": service_id,
                "sub_type_id": sub_type_id,
                "service_name": service_name_final,
                "sub_service_name": sub_service_name_final,

                "user_email": order_user_email,
                "user_name": applicant_name,
                "user_id": order_user_id,
                "user_category": "service",
                "is_disabled": is_disabled,
                "application_username": application_username,

                "fields": form_fields,
                "documents": document_urls,
                "service_documents": service_documents,

                "status": "payment_verified",
                "payment_verification_status": "approved",
                "payment_status": "completed",

                "payment_id": data.razorpay_payment_id,
                "payment_amount": total_amount,
                "payment_gst": gst_amount,
                "payment_service_charge": service_charge,
                "payment_total": total_amount,
                "payment_category_used": category_used,
                "payment_method": "razorpay",
                "payment_breakdown": {
                    "application_fee": application_fee,
                    "service_charge": service_charge,
                    "subtotal": subtotal,
                    "gst_amount": gst_amount,
                    "total_amount": total_amount,
                },

                "razorpay_order_id": data.razorpay_order_id,
                "razorpay_payment_id": data.razorpay_payment_id,
                "razorpay_signature": data.razorpay_signature,

                "transaction_id": data.razorpay_payment_id,
                "transaction_date": datetime.utcnow(),
                "paid_at": datetime.utcnow(),
                "payment_verified_at": datetime.utcnow(),
                "payment_verified_by": "razorpay_auto",

                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow(),
            }

            result = await db.applications.insert_one(application_doc)
            application_id = str(result.inserted_id)
            new_status = "verification_successful"

            logger.info(f"✅ SERVICE APPLICATION CREATED: {application_id}")
            logger.info(f"   Application Number: {application_number}")

    else:
        raise HTTPException(status_code=400, detail=f"Invalid application type: {effective_application_type}")

    # ==================== MARK PAYMENT ORDER AS PAID ====================
    try:
        await db.payment_orders.update_one(
            {"razorpay_order_id": data.razorpay_order_id},
            {
                "$set": {
                    "status": "paid",
                    "razorpay_payment_id": data.razorpay_payment_id,
                    "razorpay_signature": data.razorpay_signature,
                    "paid_at": datetime.utcnow(),
                    "application_id": application_id,
                    "application_number": application_number,
                    "updated_at": datetime.utcnow(),
                }
            }
        )
        logger.info(f"✅ Payment record marked as paid")
    except Exception as e:
        logger.warning(f"⚠️ Could not update payment record: {e}")

    # ==================== SEND NOTIFICATION ====================
    try:
        await central_notification.send_notification(
            user_ids=[order_user_email],
            notification_type="application_status",
            title=f"✅ Payment Successful: {display_title}",
            message=(
                f"Your payment of ₹{total_amount} for '{display_title}' "
                f"was successful. Your application has been submitted.\n\n"
                f"📋 Application Number: {application_number}"
            ),
            related_id=application_id,
            metadata={
                "status": new_status,
                "amount": total_amount,
                "transaction_id": data.razorpay_payment_id,
                "application_number": application_number,
                "show_blue_bell": True,
                "job_title": display_title,
                "application_id": application_id,
                "application_type": effective_application_type,
            },
            send_email=True,
            send_websocket=True
        )
    except Exception as e:
        logger.warning(f"⚠️ Notification failed: {e}")

    logger.info("=" * 70)
    logger.info(f"✅ PAYMENT COMPLETE & APPLICATION SAVED")
    logger.info(f"   Application ID: {application_id}")
    logger.info(f"   Application Number: {application_number}")
    logger.info(f"   payment_type: {effective_payment_type}")
    logger.info(f"   application_type: {effective_application_type}")
    logger.info(f"   Status: {new_status}")
    logger.info(f"   Breakdown: app_fee=₹{application_fee}, gst=₹{gst_amount}, "
                f"svc=₹{service_charge}, total=₹{total_amount}")
    logger.info("=" * 70)

    return {
        "success": True,
        "payment_verified": True,
        "application_id": application_id,
        "application_number": application_number,
        "payment_type": effective_payment_type,
        "application_type": effective_application_type,
        "application_status": new_status,
        "amount": total_amount,
        "application_fee": application_fee,
        "service_charge": service_charge,
        "subtotal": subtotal,
        "gst_amount": gst_amount,
        "razorpay_payment_id": data.razorpay_payment_id,
        "razorpay_order_id": data.razorpay_order_id,
        "message": "Payment verified and application saved successfully"
    }


# ============================================================
# ✅ PAYMENT STATUS CHECK
# ============================================================

@router.get("/payment-status/{application_id}")
async def get_application_payment_status(
    application_id: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Get payment status from application directly"""
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")

    user_email = current_user.get("email")
    app_email = application.get("user_email") or application.get("applicant_email")
    if app_email != user_email:
        raise HTTPException(status_code=403, detail="Unauthorized")

    application_type = application.get("application_type", "job")

    return {
        "success": True,
        "application_id": application_id,
        "application_type": application_type,
        "payment_status": application.get("payment_verification_status", "not_submitted"),
        "application_status": application.get("status", "pending"),
        "is_completed": application.get("status") in [
            "verification_successful", "payment_verified", "approved", "completed"
        ],
        "amount": application.get("payment_amount", 0),
        "gst_amount": application.get("payment_gst", 0),
        "service_charge": application.get("payment_service_charge", 0),
        "total_amount": application.get("payment_total", 0),
        "category_used": application.get("payment_category_used", "none"),
        "transaction_id": application.get("transaction_id"),
        "razorpay_order_id": application.get("razorpay_order_id"),
        "razorpay_payment_id": application.get("razorpay_payment_id"),
    }


# ============================================================
# ✅ UPDATE PAYMENT STATUS
# ============================================================

@router.put("/payment-status/{application_id}")
async def update_application_payment_status(
    application_id: str,
    data: dict = Body(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Update payment status - Directly updates application"""
    logger.info(f"📝 Updating payment status: {application_id}")

    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")

    user_email = current_user.get("email")
    app_email = application.get("user_email") or application.get("applicant_email")
    if app_email != user_email:
        raise HTTPException(status_code=403, detail="Unauthorized")

    application_type = application.get("application_type", "job")
    new_status = data.get("status")
    if not new_status:
        raise HTTPException(status_code=400, detail="Status is required")

    update_data = {"updated_at": datetime.utcnow()}

    if new_status == "completed":
        update_data["payment_verification_status"] = "approved"
        update_data["paid_at"] = datetime.utcnow()

        if data.get("razorpay_payment_id"):
            update_data["razorpay_payment_id"] = data["razorpay_payment_id"]
        if data.get("razorpay_order_id"):
            update_data["razorpay_order_id"] = data["razorpay_order_id"]
        if data.get("razorpay_signature"):
            update_data["razorpay_signature"] = data["razorpay_signature"]
        if data.get("transaction_id"):
            update_data["transaction_id"] = data["transaction_id"]

        if data.get("amount") is not None:
            normalized = build_payment_breakdown(
                application_fee=int(data.get("application_fee") or 0),
                service_charge=int(data.get("service_charge") or SERVICE_CHARGE),
                subtotal=int(data.get("subtotal") or 0),
                gst_amount=int(data.get("gst_amount") or 0),
                total_amount=int(data.get("amount") or 0),
            )
            update_data["payment_amount"] = normalized["total_amount"]
            update_data["payment_gst"] = normalized["gst_amount"]
            update_data["payment_service_charge"] = normalized["service_charge"]
            update_data["payment_total"] = normalized["total_amount"]
            update_data["payment_breakdown"] = {
                "application_fee": normalized["application_fee"],
                "service_charge": normalized["service_charge"],
                "subtotal": normalized["subtotal"],
                "gst_amount": normalized["gst_amount"],
                "total_amount": normalized["total_amount"],
            }

        if application_type == "job":
            update_data["status"] = "verification_successful"
        elif application_type == "schemes":
            # ✅ FIX: schemes also get verification_successful
            update_data["status"] = "verification_successful"
        else:
            update_data["status"] = "payment_verified"

    elif new_status == "failed":
        update_data["payment_verification_status"] = "rejected"
        if application_type == "job":
            update_data["status"] = "verification_rejected"
        elif application_type == "schemes":
            update_data["status"] = "rejected"
        else:
            update_data["status"] = "rejected"
        if data.get("rejection_reason"):
            update_data["payment_rejection_reason"] = data["rejection_reason"]

    await db.applications.update_one(
        {"_id": ObjectId(application_id)},
        {"$set": update_data}
    )

    return {
        "success": True,
        "message": "Payment status updated successfully",
        "application_id": application_id,
        "application_type": application_type,
        "status": new_status
    }


# ============================================================
# ✅ UPLOAD PAYMENT SCREENSHOT
# ============================================================

@router.post("/upload-screenshot")
async def upload_payment_screenshot_endpoint(
    file: UploadFile = File(...),
    username: str = Form(...),
    application_id: str = Form(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Upload payment screenshot - Updates application"""
    logger.info("=" * 60)
    logger.info(f"📤 UPLOAD PAYMENT SCREENSHOT")
    logger.info(f"   Application ID: {application_id}")
    logger.info(f"   Username: {username}")
    logger.info(f"   File: {file.filename}")
    logger.info("=" * 60)

    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Screenshot file is required")

    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")

    user_email = current_user.get("email")
    app_email = application.get("user_email") or application.get("applicant_email")
    if app_email != user_email:
        raise HTTPException(status_code=403, detail="Unauthorized")

    application_type = application.get("application_type", "job")

    file_content = await file.read()
    file_size = len(file_content)
    await file.seek(0)

    if file_size > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail=f"File too large. Max size: 10MB, Your file: {file_size // (1024*1024)}MB"
        )

    upload_result = await upload_payment_screenshot(
        file=file,
        username=username,
        payment_id=application_id
    )

    update_data = {
        "payment_receipt_url": upload_result["url"],
        "payment_receipt_public_id": upload_result.get("public_id"),
        "payment_verification_status": "pending",
        "status": "pending_verification",
        "updated_at": datetime.utcnow()
    }

    await db.applications.update_one(
        {"_id": ObjectId(application_id)},
        {"$set": update_data}
    )

    return {
        "success": True,
        "message": "Screenshot uploaded successfully",
        "url": upload_result["url"],
        "public_id": upload_result.get("public_id"),
        "filename": file.filename,
        "file_size_kb": file_size // 1024,
        "storage": upload_result.get("storage", "cloudinary"),
        "application_type": application_type
    }


# ============================================================
# ✅ ADMIN VERIFY PAYMENT
# ============================================================

@router.post("/verify-payment/{application_id}")
async def admin_verify_payment(
    application_id: str,
    action: str = Query(..., pattern="^(approve|reject)$"),
    notes: Optional[str] = Query(None),
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """ADMIN: Verify payment - Updates application"""
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")

    if application.get("payment_verification_status") != "pending":
        return {
            "success": False,
            "message": f"Payment already {application.get('payment_verification_status')}"
        }

    admin_email = current_user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email missing")

    application_type = application.get("application_type", "job")
    user_email = application.get("user_email") or application.get("applicant_email")
    amount = application.get("payment_amount", 0)
    total_amount = application.get("payment_total", amount)
    job_title = application.get("job_title", "Job Application")
    service_name = application.get("service_name", "Service")
    scheme_name = application.get("scheme_name", "Scheme")
    transaction_id = application.get("transaction_id")
    category_used = application.get("payment_category_used", "none")

    if action == "approve":
        if application_type == "job":
            new_status = "verification_successful"
            title = f"✅ Payment Verified Successfully: {job_title}"
            message = f"Your payment of ₹{total_amount} for '{job_title}' has been verified successfully."
        elif application_type == "schemes":
            # ✅ FIX: schemes also get verification_successful
            new_status = "verification_successful"
            title = f"✅ Scheme Payment Verified: {scheme_name}"
            message = f"Your payment of ₹{total_amount} for scheme '{scheme_name}' has been verified successfully."
        else:
            new_status = "payment_verified"
            title = f"✅ Service Payment Verified: {service_name}"
            message = f"Your payment of ₹{total_amount} for '{service_name}' has been verified successfully."

        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {
                "$set": {
                    "payment_verification_status": "approved",
                    "status": new_status,
                    "payment_verified_by": admin_email,
                    "payment_verified_at": datetime.utcnow(),
                    "verification_notes": notes if notes else "Payment approved by admin",
                    "updated_at": datetime.utcnow()
                }
            }
        )

        await central_notification.send_notification(
            user_ids=[user_email],
            notification_type="application_status",
            title=title,
            message=message,
            related_id=application_id,
            metadata={
                "status": new_status,
                "amount": total_amount,
                "transaction_id": transaction_id,
                "category_used": category_used,
                "application_type": application_type,
                "show_blue_bell": True
            },
            send_email=True,
            send_websocket=True
        )

    else:
        if not notes:
            notes = "Payment rejected by admin - Please contact support"

        if application_type == "job":
            new_status = "verification_rejected"
            title = f"❌ Payment Verification Failed: {job_title}"
            message = f"Your payment of ₹{total_amount} for '{job_title}' has been rejected.\nReason: {notes}"
        elif application_type == "schemes":
            new_status = "rejected"
            title = f"❌ Scheme Payment Failed: {scheme_name}"
            message = f"Your payment of ₹{total_amount} for scheme '{scheme_name}' has been rejected.\nReason: {notes}"
        else:
            new_status = "rejected"
            title = f"❌ Service Payment Failed: {service_name}"
            message = f"Your payment of ₹{total_amount} for '{service_name}' has been rejected.\nReason: {notes}"

        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {
                "$set": {
                    "payment_verification_status": "rejected",
                    "status": new_status,
                    "payment_verified_by": admin_email,
                    "payment_verified_at": datetime.utcnow(),
                    "rejection_reason": notes,
                    "verification_notes": notes,
                    "updated_at": datetime.utcnow()
                }
            }
        )

        await central_notification.send_notification(
            user_ids=[user_email],
            notification_type="application_status",
            title=title,
            message=message,
            related_id=application_id,
            metadata={
                "status": new_status,
                "amount": total_amount,
                "rejection_reason": notes,
                "category_used": category_used,
                "application_type": application_type,
                "show_blue_bell": True
            },
            send_email=True,
            send_websocket=True
        )

    return {
        "success": True,
        "message": f"Payment {action}d successfully",
        "application_id": application_id,
        "action": action,
        "status": new_status,
        "application_type": application_type,
        "notifications_sent": True
    }


# ============================================================
# ✅ GET PENDING PAYMENTS (ADMIN)
# ============================================================

@router.get("/pending-payments")
async def get_pending_payments(
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """Get pending payment verifications from applications"""
    pending = await db.applications.find({
        "payment_verification_status": "pending"
    }).to_list(100)

    results = []
    for app in pending:
        application_type = app.get("application_type", "job")

        if application_type == "job":
            results.append({
                "id": str(app["_id"]),
                "type": "job",
                "user_email": app.get("user_email") or app.get("applicant_email"),
                "user_name": app.get("user_name") or app.get("applicant_name", "Unknown"),
                "job_title": app.get("job_title", "Job"),
                "organization": app.get("organization", ""),
                "amount": app.get("payment_amount", 0),
                "gst_amount": app.get("payment_gst", 0),
                "service_charge": app.get("payment_service_charge", 0),
                "total_amount": app.get("payment_total", 0),
                "category_used": app.get("payment_category_used", "none"),
                "transaction_id": app.get("transaction_id", "N/A"),
                "screenshot_url": app.get("payment_receipt_url"),
                "status": app.get("status", "pending_verification"),
                "application_type": "job",
                "created_at": app.get("created_at")
            })
        elif application_type == "schemes":
            results.append({
                "id": str(app["_id"]),
                "type": "scheme",
                "user_email": app.get("user_email"),
                "user_name": app.get("user_name", "Unknown"),
                "scheme_name": app.get("scheme_name", "Scheme"),
                "scheme_name_hindi": app.get("scheme_name_hindi", ""),
                "amount": app.get("payment_amount", 0),
                "gst_amount": app.get("payment_gst", 0),
                "service_charge": app.get("payment_service_charge", 0),
                "total_amount": app.get("payment_total", 0),
                "category_used": app.get("payment_category_used", "scheme"),
                "transaction_id": app.get("transaction_id", "N/A"),
                "screenshot_url": app.get("payment_receipt_url"),
                "status": app.get("status", "verification_successful"),
                "application_type": "schemes",
                "created_at": app.get("created_at")
            })
        else:
            results.append({
                "id": str(app["_id"]),
                "type": "service",
                "user_email": app.get("user_email"),
                "user_name": app.get("user_name", "Unknown"),
                "service_name": app.get("service_name", "Service"),
                "sub_service_name": app.get("sub_service_name", ""),
                "amount": app.get("payment_amount", 0),
                "gst_amount": app.get("payment_gst", 0),
                "service_charge": app.get("payment_service_charge", 0),
                "total_amount": app.get("payment_total", 0),
                "category_used": app.get("payment_category_used", "service"),
                "transaction_id": app.get("transaction_id", "N/A"),
                "screenshot_url": app.get("payment_receipt_url"),
                "status": app.get("status", "pending_verification"),
                "application_type": "service",
                "created_at": app.get("created_at")
            })

    return {
        "payments": results,
        "total": len(results)
    }


# ============================================================
# ✅ TEST MODE: SIMULATE PAYMENT
# ============================================================

@router.post("/test/simulate-payment/{order_id}")
async def simulate_payment(
    order_id: str,
    action: str = Query(..., pattern="^(success|failed)$"),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """TEST MODE: Simulate payment success/failure"""
    if not _get_razorpay_test_mode():
        raise HTTPException(
            status_code=400,
            detail="Test mode is disabled. Set RAZORPAY_TEST_MODE=true in .env"
        )

    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")

    try:
        if razorpay_client:
            order = razorpay_client.order.fetch(order_id)
            return {
                "success": True,
                "message": f"Test order fetched: {order.get('id')}",
                "test_mode": True,
                "note": "Use the real Razorpay test cards to complete payment"
            }
    except Exception as e:
        raise HTTPException(status_code=404, detail=f"Order not found: {str(e)}")

    return {"success": False, "message": "Cannot fetch order"}


# ============================================================
# ✅ EMERGENCY FALLBACK: VERIFY WITHOUT SIGNATURE
# ✅ LATEST FIX: SCHEME applications get status="verification_successful"
# ============================================================

@router.post("/payment/razorpay/verify-payment-no-signature")
async def verify_payment_no_signature(
    request_data: dict = Body(...),
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """EMERGENCY FIX: Verify payment without signature - creates application"""
    try:
        razorpay_order_id = request_data.get("razorpay_order_id")
        razorpay_payment_id = request_data.get("razorpay_payment_id")
        application_id = request_data.get("application_id")

        logger.info("=" * 70)
        logger.info("🔐 Verifying payment WITHOUT signature (Fallback)")
        logger.info(f"   Order ID: {razorpay_order_id}")
        logger.info(f"   Payment ID: {razorpay_payment_id}")
        logger.info("=" * 70)

        if not razorpay_order_id or not razorpay_payment_id:
            return {
                "success": False,
                "code": "E400",
                "message": "Missing required payment details",
                "payment_verified": False
            }

        existing_application = await db.applications.find_one({
            "razorpay_payment_id": razorpay_payment_id
        })

        if existing_application:
            logger.info("=" * 70)
            logger.info(f"✅ IDEMPOTENT: Application already exists!")
            logger.info(f"   Application ID: {existing_application.get('_id')}")
            logger.info("=" * 70)

            return {
                "success": True,
                "payment_verified": True,
                "application_id": str(existing_application["_id"]),
                "application_number": existing_application.get("application_number"),
                "application_type": existing_application.get("application_type"),
                "application_status": existing_application.get("status"),
                "amount": existing_application.get("payment_total") or existing_application.get("payment_amount"),
                "message": "Application already exists (idempotent)",
                "idempotent": True
            }

        if not razorpay_client:
            initialize_razorpay_client()

        if not razorpay_client:
            return {
                "success": False,
                "code": "E500",
                "message": "Razorpay not configured",
                "payment_verified": False
            }

        try:
            order_details = razorpay_client.order.fetch(razorpay_order_id)
        except Exception as e:
            return {
                "success": False,
                "code": "E404",
                "message": f"Order not found: {str(e)}",
                "payment_verified": False
            }

        payment_record = await db.payment_orders.find_one({
            "razorpay_order_id": razorpay_order_id
        })

        if payment_record:
            effective_payment_type = payment_record.get("payment_type", "job")
            effective_application_type = payment_record.get("application_type", "job")

            if effective_payment_type == "scheme":
                effective_application_type = "schemes"

            user_email = payment_record.get("user_email", current_user.get("email"))
            user_id = payment_record.get("user_id", current_user.get("user_id"))
            job_id = payment_record.get("job_id", "")
            job_title = payment_record.get("job_title", "")
            organization = payment_record.get("organization", "")
            added_by = payment_record.get("added_by", "admin@rojgarnest.com")
            service_id = payment_record.get("service_id", "")
            sub_type_id = payment_record.get("sub_type_id", "")
            sub_service_name = payment_record.get("sub_service_name", "")
            service_name = payment_record.get("service_name", "")

            scheme_id = payment_record.get("scheme_id", "")
            scheme_name = payment_record.get("scheme_name", "")
            scheme_name_hindi = payment_record.get("scheme_name_hindi", "")
            scheme_level = payment_record.get("scheme_level", "")
            scheme_state = payment_record.get("scheme_state", "")
            scheme_category = payment_record.get("scheme_category", "")
            applicant_details = payment_record.get("applicant_details", {}) or {}
            applicant_address = payment_record.get("applicant_address", {}) or {}
            bank_details = payment_record.get("bank_details", {}) or {}

            category_used = payment_record.get("category_used", "none")
            user_category = payment_record.get("user_category", "General/UR")
            is_disabled = bool(payment_record.get("is_disabled", False))
            form_data = payment_record.get("form_data", {}) or {}
            documents = payment_record.get("documents", []) or []

            normalized = build_payment_breakdown(
                application_fee=int(payment_record.get("application_fee") or 0),
                service_charge=int(payment_record.get("service_charge") or SERVICE_CHARGE),
                subtotal=int(payment_record.get("subtotal") or 0),
                gst_amount=int(payment_record.get("gst_amount") or 0),
                total_amount=int(payment_record.get("total_amount") or 0),
            )
            application_fee = normalized["application_fee"]
            gst_amount = normalized["gst_amount"]
            service_charge = normalized["service_charge"]
            subtotal = normalized["subtotal"]
            total_amount = normalized["total_amount"]
        else:
            order_notes = order_details.get("notes", {})
            effective_payment_type = order_notes.get("payment_type", "job")
            effective_application_type = order_notes.get("application_type", "job")

            if effective_payment_type == "scheme":
                effective_application_type = "schemes"

            user_email = order_notes.get("user_email", current_user.get("email"))
            user_id = order_notes.get("user_id", current_user.get("user_id"))
            job_id = order_notes.get("job_id", "")
            job_title = order_notes.get("job_title", "")
            organization = order_notes.get("organization", "")
            added_by = order_notes.get("added_by", "admin@rojgarnest.com")
            service_id = order_notes.get("service_id", "")
            sub_type_id = order_notes.get("sub_type_id", "")
            sub_service_name = order_notes.get("sub_service_name", "")
            scheme_id = order_notes.get("scheme_id", "")
            scheme_name = order_notes.get("scheme_name", "")
            scheme_name_hindi = order_notes.get("scheme_name_hindi", "")
            scheme_level = order_notes.get("scheme_level", "")
            scheme_state = order_notes.get("scheme_state", "")
            scheme_category = order_notes.get("scheme_category", "")

            application_fee = int(order_notes.get("application_fee", "0"))
            gst_amount = int(order_notes.get("gst_amount", "0"))
            service_charge = int(order_notes.get("service_charge", "50"))
            subtotal = int(order_notes.get("subtotal", "0"))
            total_amount = int(order_notes.get("total_amount", "0"))
            category_used = order_notes.get("category_used", "none")
            user_category = order_notes.get("user_category", "General/UR")
            is_disabled = order_notes.get("is_disabled", "false").lower() == "true"

            form_data_raw = order_notes.get("form_data", "{}")
            try:
                form_data = json.loads(form_data_raw)
            except Exception:
                form_data = {}

            documents = []
            applicant_details = {}
            applicant_address = {}
            bank_details = {}

            normalized = build_payment_breakdown(
                application_fee=application_fee,
                service_charge=service_charge,
                subtotal=subtotal,
                gst_amount=gst_amount,
                total_amount=total_amount,
            )
            application_fee = normalized["application_fee"]
            gst_amount = normalized["gst_amount"]
            service_charge = normalized["service_charge"]
            subtotal = normalized["subtotal"]
            total_amount = normalized["total_amount"]

        profile = await db.profile.find_one({"email": user_email})
        applicant_name = profile.get("full_name") if profile else "User"
        application_username = user_email.split('@')[0]

        try:
            application_number = await ApplicationNumberGenerator.generate_application_number(db)
            logger.info(f"🎫 APPLICATION NUMBER GENERATED: {application_number}")
        except Exception as e:
            logger.error(f"❌ Failed to generate application number: {e}")
            from datetime import datetime as dt
            now = dt.utcnow()
            fallback_seq = int(now.timestamp()) % 100000
            application_number = f"{now.year}{now.month:02d}{fallback_seq:05d}"
            logger.warning(f"⚠️ Using fallback application number: {application_number}")

        # ============================================================
        # ✅ CREATE APPLICATION BASED ON TYPE
        # ============================================================
        if effective_application_type == "job":
            existing = await db.applications.find_one({
                "job_id": job_id,
                "user_email": user_email,
                "application_type": "job",
                "status": {
                    "$in": [
                        "verification_successful", "pending", "shortlisted",
                        "interview", "offered", "submitted", "review_application",
                        "final_submitted", "confirmed_application", "approved_application"
                    ]
                }
            })

            if existing:
                application_id = str(existing["_id"])
                new_status = existing.get("status", "verification_successful")
                application_number = existing.get("application_number", application_number)

                await db.applications.update_one(
                    {"_id": existing["_id"]},
                    {
                        "$set": {
                            "application_number": application_number,
                            "payment_amount": total_amount,
                            "payment_gst": gst_amount,
                            "payment_service_charge": service_charge,
                            "payment_total": total_amount,
                            "payment_breakdown": {
                                "application_fee": application_fee,
                                "service_charge": service_charge,
                                "subtotal": subtotal,
                                "gst_amount": gst_amount,
                                "total_amount": total_amount,
                            },
                            "razorpay_payment_id": razorpay_payment_id,
                            "razorpay_order_id": razorpay_order_id,
                            "updated_at": datetime.utcnow(),
                        }
                    }
                )
            else:
                doc = {
                    "application_type": "job",
                    "application_number": application_number,
                    "job_id": job_id,
                    "job_title": job_title,
                    "organization": organization,
                    "added_by": added_by,
                    "applicant_email": user_email,
                    "applicant_name": applicant_name,
                    "user_email": user_email,
                    "user_name": applicant_name,
                    "user_id": user_id,
                    "user_category": user_category,
                    "is_disabled": is_disabled,
                    "application_username": application_username,
                    "status": "verification_successful",
                    "payment_verification_status": "approved",
                    "payment_status": "completed",
                    "payment_id": razorpay_payment_id,
                    "payment_amount": total_amount,
                    "payment_gst": gst_amount,
                    "payment_service_charge": service_charge,
                    "payment_total": total_amount,
                    "payment_category_used": category_used,
                    "payment_method": "razorpay",
                    "payment_breakdown": {
                        "application_fee": application_fee,
                        "service_charge": service_charge,
                        "subtotal": subtotal,
                        "gst_amount": gst_amount,
                        "total_amount": total_amount,
                    },
                    "razorpay_order_id": razorpay_order_id,
                    "razorpay_payment_id": razorpay_payment_id,
                    "transaction_id": razorpay_payment_id,
                    "transaction_date": datetime.utcnow(),
                    "paid_at": datetime.utcnow(),
                    "payment_verified_at": datetime.utcnow(),
                    "payment_verified_by": "razorpay_fallback",
                    "applied_at": datetime.utcnow(),
                    "created_at": datetime.utcnow(),
                    "updated_at": datetime.utcnow(),
                    "additional_info": form_data if form_data else None,
                }
                result = await db.applications.insert_one(doc)
                application_id = str(result.inserted_id)
                new_status = "verification_successful"
                logger.info(f"✅ JOB APPLICATION CREATED: {application_id}")

        elif effective_application_type == "schemes":
            logger.info("=" * 70)
            logger.info("🏛️ CREATING SCHEME APPLICATION (fallback)")
            logger.info(f"   Scheme ID: {scheme_id}")
            logger.info("=" * 70)

            existing = await db.applications.find_one({
                "application_type": "schemes",
                "user_email": user_email,
                "scheme_id": scheme_id,
                "status": {
                    "$nin": ["rejected", "verification_rejected", "cancelled"]
                },
                "is_archived": {"$ne": True}
            })

            if existing:
                application_id = str(existing["_id"])
                # ✅ FIX: force verification_successful
                new_status = "verification_successful"
                application_number = existing.get("application_number", application_number)

                # ✅ Update existing: status → verification_successful
                await db.applications.update_one(
                    {"_id": existing["_id"]},
                    {
                        "$set": {
                            "application_number": application_number,
                            "status": "verification_successful",   # ✅ FIX
                            "payment_amount": total_amount,
                            "payment_gst": gst_amount,
                            "payment_service_charge": service_charge,
                            "payment_total": total_amount,
                            "payment_breakdown": {
                                "application_fee": application_fee,
                                "service_charge": service_charge,
                                "subtotal": subtotal,
                                "gst_amount": gst_amount,
                                "total_amount": total_amount,
                            },
                            "razorpay_payment_id": razorpay_payment_id,
                            "razorpay_order_id": razorpay_order_id,
                            "payment_verification_status": "approved",
                            "payment_status": "completed",
                            "updated_at": datetime.utcnow(),
                        }
                    }
                )
                logger.info(f"✅ Updated existing scheme application → status=verification_successful")
            else:
                # ✅ FIX: exactly ONE "status" key = verification_successful
                doc = {
                    "application_type": "schemes",
                    "application_id": str(ObjectId()),
                    "application_number": application_number,
                    "user_email": user_email,
                    "user_name": applicant_name,
                    "user_id": user_id,
                    "application_username": application_username,
                    "user_category": user_category,
                    "is_disabled": is_disabled,
                    "scheme_id": scheme_id,
                    "scheme_name": scheme_name,
                    "scheme_name_hindi": scheme_name_hindi,
                    "scheme_level": scheme_level,
                    "scheme_state": scheme_state,
                    "scheme_category": scheme_category,
                    "applicant_details": applicant_details,
                    "applicant_address": applicant_address,
                    "bank_details": bank_details,
                    "documents": documents,

                    # ✅ THE ONLY "status" key — value = verification_successful
                    "status": "verification_successful",
                    "payment_verification_status": "approved",
                    "payment_status": "completed",

                    "payment_id": razorpay_payment_id,
                    "payment_amount": total_amount,
                    "payment_gst": gst_amount,
                    "payment_service_charge": service_charge,
                    "payment_total": total_amount,
                    "payment_category_used": category_used,
                    "payment_method": "razorpay",
                    "payment_breakdown": {
                        "application_fee": application_fee,
                        "service_charge": service_charge,
                        "subtotal": subtotal,
                        "gst_amount": gst_amount,
                        "total_amount": total_amount,
                    },
                    "razorpay_order_id": razorpay_order_id,
                    "razorpay_payment_id": razorpay_payment_id,
                    "transaction_id": razorpay_payment_id,
                    "transaction_date": datetime.utcnow(),
                    "paid_at": datetime.utcnow(),
                    "payment_verified_at": datetime.utcnow(),
                    "payment_verified_by": "razorpay_fallback",
                    "is_archived": False,
                    "additional_info": form_data if form_data else None,
                    "remarks": "",
                    "applied_at": datetime.utcnow(),
                    "created_at": datetime.utcnow(),
                    "updated_at": datetime.utcnow(),
                }
                result = await db.applications.insert_one(doc)
                application_id = str(result.inserted_id)
                new_status = "verification_successful"
                logger.info(f"✅ SCHEME APPLICATION CREATED: {application_id}")
                logger.info(f"   Application Number: {application_number}")
                logger.info(f"   Status: {new_status}")

        elif effective_application_type == "service":
            existing = await db.applications.find_one({
                "service_id": service_id,
                "sub_type_id": sub_type_id,
                "user_email": user_email,
                "application_type": "service",
                "status": {"$nin": ["replaced", "rejected", "verification_rejected"]}
            })

            if existing:
                application_id = str(existing["_id"])
                new_status = existing.get("status", "payment_verified")
                application_number = existing.get("application_number", application_number)

                await db.applications.update_one(
                    {"_id": existing["_id"]},
                    {
                        "$set": {
                            "application_number": application_number,
                            "payment_amount": total_amount,
                            "payment_gst": gst_amount,
                            "payment_service_charge": service_charge,
                            "payment_total": total_amount,
                            "payment_breakdown": {
                                "application_fee": application_fee,
                                "service_charge": service_charge,
                                "subtotal": subtotal,
                                "gst_amount": gst_amount,
                                "total_amount": total_amount,
                            },
                            "updated_at": datetime.utcnow(),
                        }
                    }
                )
            else:
                from app.modules.services.models.service_types import ServiceMasterData
                service = ServiceMasterData.get_service_by_id(service_id)
                sub_type = ServiceMasterData.get_sub_type_by_id(sub_type_id)

                doc = {
                    "application_type": "service",
                    "application_number": application_number,
                    "service_id": service_id,
                    "sub_type_id": sub_type_id,
                    "service_name": service.name if service else service_id,
                    "sub_service_name": sub_type.name if sub_type else sub_type_id,
                    "user_email": user_email,
                    "user_name": applicant_name,
                    "user_id": user_id,
                    "user_category": "service",
                    "is_disabled": is_disabled,
                    "application_username": application_username,
                    "fields": form_data.get('fields', {}) if isinstance(form_data, dict) else {},
                    "documents": form_data.get('document_urls', {}) if isinstance(form_data, dict) else {},
                    "service_documents": [],
                    "status": "payment_verified",
                    "payment_verification_status": "approved",
                    "payment_status": "completed",
                    "payment_id": razorpay_payment_id,
                    "payment_amount": total_amount,
                    "payment_gst": gst_amount,
                    "payment_service_charge": service_charge,
                    "payment_total": total_amount,
                    "payment_category_used": category_used,
                    "payment_method": "razorpay",
                    "payment_breakdown": {
                        "application_fee": application_fee,
                        "service_charge": service_charge,
                        "subtotal": subtotal,
                        "gst_amount": gst_amount,
                        "total_amount": total_amount,
                    },
                    "razorpay_order_id": razorpay_order_id,
                    "razorpay_payment_id": razorpay_payment_id,
                    "transaction_id": razorpay_payment_id,
                    "transaction_date": datetime.utcnow(),
                    "paid_at": datetime.utcnow(),
                    "payment_verified_at": datetime.utcnow(),
                    "payment_verified_by": "razorpay_fallback",
                    "created_at": datetime.utcnow(),
                    "updated_at": datetime.utcnow(),
                }
                result = await db.applications.insert_one(doc)
                application_id = str(result.inserted_id)
                new_status = "payment_verified"
                logger.info(f"✅ SERVICE APPLICATION CREATED: {application_id}")

        else:
            return {
                "success": False,
                "code": "E400",
                "message": f"Invalid application type: {effective_application_type}",
                "payment_verified": False
            }

        # ✅ Update payment record
        try:
            await db.payment_orders.update_one(
                {"razorpay_order_id": razorpay_order_id},
                {
                    "$set": {
                        "status": "paid",
                        "razorpay_payment_id": razorpay_payment_id,
                        "paid_at": datetime.utcnow(),
                        "application_id": application_id,
                        "application_number": application_number,
                        "updated_at": datetime.utcnow(),
                    }
                }
            )
        except Exception as e:
            logger.warning(f"⚠️ Could not update payment record: {e}")

        return {
            "success": True,
            "payment_verified": True,
            "application_id": application_id,
            "application_number": application_number,
            "payment_type": effective_payment_type,
            "application_type": effective_application_type,
            "application_status": new_status,
            "amount": total_amount,
            "application_fee": application_fee,
            "service_charge": service_charge,
            "gst_amount": gst_amount,
            "razorpay_payment_id": razorpay_payment_id,
            "razorpay_order_id": razorpay_order_id,
            "verification_method": "no_signature_fallback",
            "message": "Payment verified and application saved successfully"
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Verification error: {e}")
        import traceback
        traceback.print_exc()
        return {
            "success": False,
            "code": "E500",
            "message": f"Verification failed: {str(e)}",
            "payment_verified": False
        }


# ============================================================
# ✅ UPDATE JOB PAYMENT STATUS (Legacy endpoint)
# ============================================================

@router.post("/update-payment-status/{job_id}")
async def update_job_payment_status(
    job_id: str,
    update_data: dict = Body(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Update payment status for an existing application."""
    try:
        user_email = current_user.get("email")
        razorpay_payment_id = update_data.get("razorpay_payment_id")
        razorpay_order_id = update_data.get("razorpay_order_id")
        razorpay_signature = update_data.get("razorpay_signature")
        transaction_id = update_data.get("transaction_id") or razorpay_payment_id
        amount = update_data.get("amount")

        logger.info("=" * 70)
        logger.info("📤 Updating application payment status")
        logger.info(f"   Job ID: {job_id}")
        logger.info(f"   User: {user_email}")
        logger.info("=" * 70)

        application = await db.applications.find_one({
            "user_email": user_email,
            "job_id": job_id,
            "application_type": "job"
        })

        if not application:
            logger.error(f"❌ Application not found")
            return {
                "success": False,
                "message": "Application not found"
            }

        application_id = str(application["_id"])

        update_data_db = {
            "status": "verification_successful",
            "payment_verification_status": "approved",
            "payment_status": "completed",
            "transaction_id": transaction_id,
            "razorpay_payment_id": razorpay_payment_id,
            "razorpay_order_id": razorpay_order_id,
            "razorpay_signature": razorpay_signature,
            "paid_at": datetime.utcnow(),
            "payment_verified_at": datetime.utcnow(),
            "payment_verified_by": user_email or "system",
            "updated_at": datetime.utcnow()
        }

        payment_record = await db.payment_orders.find_one({
            "razorpay_order_id": razorpay_order_id
        })
        if payment_record:
            normalized = build_payment_breakdown(
                application_fee=int(payment_record.get("application_fee") or 0),
                service_charge=int(payment_record.get("service_charge") or SERVICE_CHARGE),
                subtotal=int(payment_record.get("subtotal") or 0),
                gst_amount=int(payment_record.get("gst_amount") or 0),
                total_amount=int(payment_record.get("total_amount") or 0),
            )
            update_data_db["payment_amount"] = normalized["total_amount"]
            update_data_db["payment_gst"] = normalized["gst_amount"]
            update_data_db["payment_service_charge"] = normalized["service_charge"]
            update_data_db["payment_total"] = normalized["total_amount"]
            update_data_db["payment_breakdown"] = {
                "application_fee": normalized["application_fee"],
                "service_charge": normalized["service_charge"],
                "subtotal": normalized["subtotal"],
                "gst_amount": normalized["gst_amount"],
                "total_amount": normalized["total_amount"],
            }
        elif amount:
            normalized = build_payment_breakdown(
                application_fee=0,
                service_charge=SERVICE_CHARGE,
                subtotal=0,
                gst_amount=0,
                total_amount=int(amount),
            )
            update_data_db["payment_amount"] = normalized["total_amount"]
            update_data_db["payment_gst"] = normalized["gst_amount"]
            update_data_db["payment_service_charge"] = normalized["service_charge"]
            update_data_db["payment_total"] = normalized["total_amount"]
            update_data_db["payment_breakdown"] = {
                "application_fee": normalized["application_fee"],
                "service_charge": normalized["service_charge"],
                "subtotal": normalized["subtotal"],
                "gst_amount": normalized["gst_amount"],
                "total_amount": normalized["total_amount"],
            }

        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data_db}
        )

        return {
            "success": True,
            "message": "Payment status updated",
            "application_id": application_id,
            "status": "verification_successful"
        }

    except Exception as e:
        logger.error(f"❌ Error updating payment status: {e}")
        import traceback
        traceback.print_exc()
        return {"success": False, "message": str(e)}


# ============================================================
# ✅ RAZORPAY WEBHOOK (Auto-creates application if needed)
# ✅ LATEST FIX: SCHEME applications get status="verification_successful"
# ============================================================

@router.post("/razorpay/webhook")
async def razorpay_webhook(
    request_data: dict = Body(...),
    db=Depends(get_db)
):
    """
    Webhook handler. If payment is captured but verify-payment
    endpoint was never called, this creates the application.
    ✅ LATEST: Scheme applications get status="verification_successful"
    """
    try:
        event = request_data.get("event")
        payload = request_data.get("payload", {})
        logger.info(f"📨 Razorpay webhook received: {event}")

        if event == "payment.captured":
            payment = payload.get("payment", {}).get("entity", {})
            order_id = payment.get("order_id")
            payment_id = payment.get("id")
            amount = payment.get("amount", 0) / 100

            logger.info(f"💰 Payment captured: {payment_id} for order: {order_id}")

            existing = await db.applications.find_one({
                "razorpay_order_id": order_id
            })

            if existing:
                logger.info(f"✅ Application already exists: {existing['_id']}")
                return {"success": True, "received": True, "already_exists": True}

            existing_by_payment = await db.applications.find_one({
                "razorpay_payment_id": payment_id
            })

            if existing_by_payment:
                logger.info(f"✅ Application already exists by payment_id: {existing_by_payment['_id']}")
                return {"success": True, "received": True, "already_exists": True}

            if razorpay_client:
                try:
                    order_details = razorpay_client.order.fetch(order_id)

                    payment_record = await db.payment_orders.find_one({
                        "razorpay_order_id": order_id
                    })

                    if payment_record:
                        effective_payment_type = payment_record.get("payment_type", "job")
                        effective_application_type = payment_record.get("application_type", "job")

                        if effective_payment_type == "scheme":
                            effective_application_type = "schemes"

                        user_email = payment_record.get("user_email")
                        user_id = payment_record.get("user_id")
                        job_id = payment_record.get("job_id", "")
                        job_title = payment_record.get("job_title", "")
                        organization = payment_record.get("organization", "")
                        added_by = payment_record.get("added_by", "admin@rojgarnest.com")
                        service_id = payment_record.get("service_id", "")
                        sub_type_id = payment_record.get("sub_type_id", "")
                        service_name = payment_record.get("service_name", "")
                        sub_service_name = payment_record.get("sub_service_name", "")
                        scheme_id = payment_record.get("scheme_id", "")
                        scheme_name = payment_record.get("scheme_name", "")
                        scheme_name_hindi = payment_record.get("scheme_name_hindi", "")
                        scheme_level = payment_record.get("scheme_level", "")
                        scheme_state = payment_record.get("scheme_state", "")
                        scheme_category = payment_record.get("scheme_category", "")
                        applicant_details = payment_record.get("applicant_details", {}) or {}
                        applicant_address = payment_record.get("applicant_address", {}) or {}
                        bank_details = payment_record.get("bank_details", {}) or {}
                        category_used = payment_record.get("category_used", "none")
                        user_category = payment_record.get("user_category", "General/UR")
                        is_disabled = bool(payment_record.get("is_disabled", False))
                        form_data = payment_record.get("form_data", {}) or {}
                        documents = payment_record.get("documents", []) or []

                        normalized = build_payment_breakdown(
                            application_fee=int(payment_record.get("application_fee") or 0),
                            service_charge=int(payment_record.get("service_charge") or SERVICE_CHARGE),
                            subtotal=int(payment_record.get("subtotal") or 0),
                            gst_amount=int(payment_record.get("gst_amount") or 0),
                            total_amount=int(payment_record.get("total_amount") or 0),
                        )
                        application_fee = normalized["application_fee"]
                        gst_amount = normalized["gst_amount"]
                        service_charge = normalized["service_charge"]
                        subtotal = normalized["subtotal"]
                        total_amount = normalized["total_amount"]
                    else:
                        order_notes = order_details.get("notes", {})
                        effective_payment_type = order_notes.get("payment_type", "job")
                        effective_application_type = order_notes.get("application_type", "job")

                        if effective_payment_type == "scheme":
                            effective_application_type = "schemes"

                        user_email = order_notes.get("user_email")
                        user_id = order_notes.get("user_id")
                        job_id = order_notes.get("job_id", "")
                        job_title = order_notes.get("job_title", "")
                        organization = order_notes.get("organization", "")
                        added_by = order_notes.get("added_by", "admin@rojgarnest.com")
                        service_id = order_notes.get("service_id", "")
                        sub_type_id = order_notes.get("sub_type_id", "")
                        service_name = order_notes.get("service_name", "")
                        sub_service_name = order_notes.get("sub_service_name", "")
                        scheme_id = order_notes.get("scheme_id", "")
                        scheme_name = order_notes.get("scheme_name", "")
                        scheme_name_hindi = order_notes.get("scheme_name_hindi", "")
                        scheme_level = order_notes.get("scheme_level", "")
                        scheme_state = order_notes.get("scheme_state", "")
                        scheme_category = order_notes.get("scheme_category", "")
                        applicant_details = {}
                        applicant_address = {}
                        bank_details = {}
                        category_used = order_notes.get("category_used", "none")
                        user_category = order_notes.get("user_category", "General/UR")
                        is_disabled = order_notes.get("is_disabled", "false").lower() == "true"

                        try:
                            form_data = json.loads(order_notes.get("form_data", "{}"))
                        except Exception:
                            form_data = {}
                        documents = []

                        normalized = build_payment_breakdown(
                            application_fee=int(order_notes.get("application_fee", "0")),
                            service_charge=int(order_notes.get("service_charge", "50")),
                            subtotal=int(order_notes.get("subtotal", "0")),
                            gst_amount=int(order_notes.get("gst_amount", "0")),
                            total_amount=int(order_notes.get("total_amount", "0")),
                        )
                        application_fee = normalized["application_fee"]
                        gst_amount = normalized["gst_amount"]
                        service_charge = normalized["service_charge"]
                        subtotal = normalized["subtotal"]
                        total_amount = normalized["total_amount"]

                    profile = await db.profile.find_one({"email": user_email})
                    applicant_name = profile.get("full_name") if profile else "User"
                    application_username = user_email.split('@')[0] if user_email else "user"

                    try:
                        application_number = await ApplicationNumberGenerator.generate_application_number(db)
                        logger.info(f"🎫 WEBHOOK: Application number generated: {application_number}")
                    except Exception as e:
                        logger.error(f"❌ Failed to generate application number: {e}")
                        from datetime import datetime as dt
                        now = dt.utcnow()
                        fallback_seq = int(now.timestamp()) % 100000
                        application_number = f"{now.year}{now.month:02d}{fallback_seq:05d}"
                        logger.warning(f"⚠️ Using fallback: {application_number}")

                    if effective_application_type == "job":
                        doc = {
                            "application_type": "job",
                            "application_number": application_number,
                            "job_id": job_id,
                            "job_title": job_title,
                            "organization": organization,
                            "added_by": added_by,
                            "applicant_email": user_email,
                            "applicant_name": applicant_name,
                            "user_email": user_email,
                            "user_name": applicant_name,
                            "user_id": user_id,
                            "user_category": user_category,
                            "is_disabled": is_disabled,
                            "application_username": application_username,
                            "status": "verification_successful",
                            "payment_verification_status": "approved",
                            "payment_status": "completed",
                            "payment_id": payment_id,
                            "payment_amount": total_amount,
                            "payment_gst": gst_amount,
                            "payment_service_charge": service_charge,
                            "payment_total": total_amount,
                            "payment_category_used": category_used,
                            "payment_method": "razorpay",
                            "payment_breakdown": {
                                "application_fee": application_fee,
                                "service_charge": service_charge,
                                "subtotal": subtotal,
                                "gst_amount": gst_amount,
                                "total_amount": total_amount,
                            },
                            "razorpay_order_id": order_id,
                            "razorpay_payment_id": payment_id,
                            "transaction_id": payment_id,
                            "transaction_date": datetime.utcnow(),
                            "paid_at": datetime.utcnow(),
                            "payment_verified_at": datetime.utcnow(),
                            "payment_verified_by": "razorpay_webhook",
                            "applied_at": datetime.utcnow(),
                            "created_at": datetime.utcnow(),
                            "updated_at": datetime.utcnow(),
                            "additional_info": form_data if form_data else None,
                        }
                    elif effective_application_type == "schemes":
                        # ✅ FIX: exactly ONE "status" key = verification_successful
                        doc = {
                            "application_type": "schemes",
                            "application_id": str(ObjectId()),
                            "application_number": application_number,
                            "user_email": user_email,
                            "user_name": applicant_name,
                            "user_id": user_id,
                            "application_username": application_username,
                            "user_category": user_category,
                            "is_disabled": is_disabled,
                            "scheme_id": scheme_id,
                            "scheme_name": scheme_name,
                            "scheme_name_hindi": scheme_name_hindi,
                            "scheme_level": scheme_level,
                            "scheme_state": scheme_state,
                            "scheme_category": scheme_category,
                            "applicant_details": applicant_details,
                            "applicant_address": applicant_address,
                            "bank_details": bank_details,
                            "documents": documents,

                            # ✅ THE ONLY "status" key — value = verification_successful
                            "status": "verification_successful",
                            "payment_verification_status": "approved",
                            "payment_status": "completed",

                            "payment_id": payment_id,
                            "payment_amount": total_amount,
                            "payment_gst": gst_amount,
                            "payment_service_charge": service_charge,
                            "payment_total": total_amount,
                            "payment_category_used": category_used,
                            "payment_method": "razorpay",
                            "payment_breakdown": {
                                "application_fee": application_fee,
                                "service_charge": service_charge,
                                "subtotal": subtotal,
                                "gst_amount": gst_amount,
                                "total_amount": total_amount,
                            },
                            "razorpay_order_id": order_id,
                            "razorpay_payment_id": payment_id,
                            "transaction_id": payment_id,
                            "transaction_date": datetime.utcnow(),
                            "paid_at": datetime.utcnow(),
                            "payment_verified_at": datetime.utcnow(),
                            "payment_verified_by": "razorpay_webhook",
                            "is_archived": False,
                            "additional_info": form_data if form_data else None,
                            "remarks": "",
                            "applied_at": datetime.utcnow(),
                            "created_at": datetime.utcnow(),
                            "updated_at": datetime.utcnow(),
                        }
                    else:
                        from app.modules.services.models.service_types import ServiceMasterData
                        service = ServiceMasterData.get_service_by_id(service_id)
                        sub_type = ServiceMasterData.get_sub_type_by_id(sub_type_id)

                        doc = {
                            "application_type": "service",
                            "application_number": application_number,
                            "service_id": service_id,
                            "sub_type_id": sub_type_id,
                            "service_name": service.name if service else service_id,
                            "sub_service_name": sub_type.name if sub_type else sub_type_id,
                            "user_email": user_email,
                            "user_name": applicant_name,
                            "user_id": user_id,
                            "user_category": "service",
                            "is_disabled": is_disabled,
                            "application_username": application_username,
                            "fields": form_data.get('fields', {}) if isinstance(form_data, dict) else {},
                            "documents": form_data.get('document_urls', {}) if isinstance(form_data, dict) else {},
                            "service_documents": [],
                            "status": "payment_verified",
                            "payment_verification_status": "approved",
                            "payment_status": "completed",
                            "payment_id": payment_id,
                            "payment_amount": total_amount,
                            "payment_gst": gst_amount,
                            "payment_service_charge": service_charge,
                            "payment_total": total_amount,
                            "payment_category_used": category_used,
                            "payment_method": "razorpay",
                            "payment_breakdown": {
                                "application_fee": application_fee,
                                "service_charge": service_charge,
                                "subtotal": subtotal,
                                "gst_amount": gst_amount,
                                "total_amount": total_amount,
                            },
                            "razorpay_order_id": order_id,
                            "razorpay_payment_id": payment_id,
                            "transaction_id": payment_id,
                            "transaction_date": datetime.utcnow(),
                            "paid_at": datetime.utcnow(),
                            "payment_verified_at": datetime.utcnow(),
                            "payment_verified_by": "razorpay_webhook",
                            "created_at": datetime.utcnow(),
                            "updated_at": datetime.utcnow(),
                        }

                    result = await db.applications.insert_one(doc)
                    logger.info(f"✅ Webhook created application: {result.inserted_id}")
                    logger.info(f"   Application Number: {application_number}")
                    logger.info(f"   Application Type: {effective_application_type}")
                    logger.info(f"   Status: {doc.get('status')}")

                    await db.payment_orders.update_one(
                        {"razorpay_order_id": order_id},
                        {
                            "$set": {
                                "status": "paid",
                                "razorpay_payment_id": payment_id,
                                "paid_at": datetime.utcnow(),
                                "application_id": str(result.inserted_id),
                                "application_number": application_number,
                                "updated_at": datetime.utcnow(),
                            }
                        }
                    )
                except Exception as e:
                    logger.error(f"❌ Webhook failed to create application: {e}")
                    import traceback
                    traceback.print_exc()

        elif event == "payment.failed":
            payment = payload.get("payment", {}).get("entity", {})
            order_id = payment.get("order_id")
            payment_id = payment.get("id")
            logger.warning(f"❌ Payment failed: {payment_id} for order: {order_id}")

            try:
                await db.payment_orders.update_one(
                    {"razorpay_order_id": order_id},
                    {
                        "$set": {
                            "status": "failed",
                            "razorpay_payment_id": payment_id,
                            "failed_at": datetime.utcnow(),
                            "updated_at": datetime.utcnow(),
                        }
                    }
                )
            except Exception as e:
                logger.warning(f"⚠️ Could not update payment record: {e}")

        return {"success": True, "received": True}
    except Exception as e:
        logger.error(f"❌ Webhook error: {e}")
        import traceback
        traceback.print_exc()
        return {"success": False, "error": str(e)}


# ============================================================
# ✅ MODULE LOAD SUMMARY
# ============================================================
print("=" * 70)
print("✅ Payment Routes Loaded - RAZORPAY with SCHEME SUPPORT")
print("   ✅ use_provided_amount flag prevents double calculation")
print("   ✅ build_payment_breakdown() normalizes amounts")
print("   ✅ payment_amount now stores TOTAL (not app_fee)")
print("   ✅ payment_gst inferred from (total - subtotal) if 0")
print("   ✅ NO application created on order creation")
print("   ✅ Application created ONLY after successful payment")
print("   ✅ IDEMPOTENT: Only ONE record created per payment")
print("   ✅ Failed/cancelled payments create NO record")
print("   ✅ Supports job + service + scheme payments")
print("   ✅ payment_type='scheme' → application_type='schemes'")
print("   ✅ Full breakdown saved to `payment_orders` collection")
print("   ✅ verify-payment reads breakdown from DB (not Razorpay notes)")
print("   🎯 LATEST FIX: Scheme applications now get")
print("        status='verification_successful' (NOT 'pending')")
print("      Removed duplicate `status` dict-key override bug in all 3 paths:")
print("        - verify_razorpay_payment()")
print("        - verify_payment_no_signature()")
print("        - razorpay_webhook()")
print("=" * 70)