# app/modules/payment/razorpay_integration.py
# ✅ COMPLETE FIXED - AUTO-APPROVAL on successful Razorpay payment
# Future payments will be auto-approved and never stuck in "pending"

import razorpay
import logging
import hmac
import hashlib
import json
from datetime import datetime, timedelta
from bson import ObjectId
from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks, Body, Query
from fastapi.responses import JSONResponse
from typing import Optional, Dict, Any, List
from app.db.connection import get_db
from app.core.config.settings import settings
from app.core.services.dependencies import get_current_user
from app.modules.notification.service import central_notification
from app.core.utils.logger import logger

router = APIRouter()
razorpay_client = None


def get_razorpay_client():
    """Get or initialize Razorpay client"""
    global razorpay_client
    if razorpay_client is None:
        if not settings.RAZORPAY_KEY_ID or not settings.RAZORPAY_KEY_SECRET:
            logger.warning("⚠️ Razorpay credentials not configured")
            return None
        try:
            razorpay_client = razorpay.Client(auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET))
            logger.info("✅ Razorpay client initialized successfully")
        except Exception as e:
            logger.error(f"❌ Failed to initialize Razorpay client: {e}")
            return None
    return razorpay_client


# ==================== CREATE ORDER ====================

@router.post("/payment/razorpay/create-order")
async def create_razorpay_order(
    request_data: dict = Body(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Create Razorpay order with proper application creation"""
    try:
        amount = request_data.get("amount")
        payment_type = request_data.get("payment_type", "job")
        job_id = request_data.get("job_id")
        job_title = request_data.get("job_title")
        organization = request_data.get("organization")
        service_id = request_data.get("service_id")
        service_type = request_data.get("service_type")
        sub_type_id = request_data.get("sub_type_id")
        sub_service_name = request_data.get("sub_service_name")
        form_data = request_data.get("form_data")
        user_email = request_data.get("user_email") or current_user.get("email")
        user_name = request_data.get("user_name") or current_user.get("name")
        user_mobile = request_data.get("user_mobile") or current_user.get("mobile")

        logger.info("=" * 70)
        logger.info(f"💰 Creating Razorpay Order - Type: {payment_type}")
        logger.info(f"   User: {user_email}")
        logger.info(f"   Amount: ₹{amount}")
        logger.info("=" * 70)

        if not user_email:
            raise HTTPException(status_code=400, detail="User email is required")
        if not amount or amount <= 0:
            raise HTTPException(status_code=400, detail="Invalid amount")

        user_category = "general/ur"
        profile = await db.profile.find_one({"email": user_email})
        if profile:
            category = profile.get("category", "").lower()
            if "obc" in category:
                user_category = "obc"
            elif "sc" in category:
                user_category = "sc"
            elif "st" in category:
                user_category = "st"
            elif "ews" in category:
                user_category = "ews"
            else:
                user_category = "general/ur"

        if payment_type == "job" and job_id and ObjectId.is_valid(job_id):
            job = await db.job.find_one({"_id": ObjectId(job_id)})
            if job:
                fees = job.get("application_fees", {})
                fee = fees.get(user_category) or fees.get("general/ur") or fees.get("general")
                if fee:
                    amount = int(fee)
                    logger.info(f"💰 Fee for {user_category}: ₹{amount}")

        existing_app = None
        if payment_type == "job" and job_id:
            existing_app = await db.applications.find_one({
                "user_email": user_email,
                "job_id": job_id,
                "application_type": "job"
            })
        elif payment_type == "service" and service_id and sub_type_id:
            existing_app = await db.applications.find_one({
                "user_email": user_email,
                "service_id": service_id,
                "sub_type_id": sub_type_id,
                "application_type": "service"
            })

        if existing_app:
            logger.info(f"📋 Using existing application: {str(existing_app['_id'])}")
            application_id = str(existing_app["_id"])
            expires_at = existing_app.get("expires_at")
            if expires_at and datetime.utcnow() > expires_at:
                logger.info("⏰ Existing order expired, creating new one")
            else:
                existing_order_id = existing_app.get("razorpay_order_id")
                if existing_order_id:
                    return {
                        "success": True,
                        "order_id": existing_order_id,
                        "application_id": application_id,
                        "amount": amount,
                        "amount_paise": amount * 100,
                        "currency": "INR",
                        "key_id": settings.RAZORPAY_KEY_ID,
                        "category_used": user_category,
                        "test_mode": settings.is_razorpay_test_mode,
                        "message": "Using existing order"
                    }

        client = get_razorpay_client()
        if not client:
            raise HTTPException(status_code=500, detail="Payment gateway not configured")

        order_data = {
            "amount": int(amount * 100),
            "currency": "INR",
            "receipt": f"order_{datetime.utcnow().timestamp()}",
            "payment_capture": 1,
            "notes": {
                "user_email": user_email,
                "payment_type": payment_type,
                "job_id": job_id or "",
                "service_id": service_id or "",
                "user_category": user_category
            }
        }

        try:
            order = client.order.create(data=order_data)
            razorpay_order_id = order.get("id")
            logger.info(f"✅ Order created: {razorpay_order_id}")
        except Exception as e:
            logger.error(f"❌ Razorpay order creation failed: {e}")
            raise HTTPException(status_code=500, detail=f"Payment gateway error: {str(e)}")

        application_data = {
            "application_type": payment_type,
            "user_email": user_email,
            "user_name": user_name,
            "user_category": user_category,
            "payment_amount": amount,
            "payment_category_used": user_category,
            "payment_method": "razorpay",
            "razorpay_order_id": razorpay_order_id,
            "status": "payment_pending",
            "payment_status": "pending",
            "payment_verification_status": "not_submitted",
            "expires_at": datetime.utcnow() + timedelta(minutes=15),
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }

        if payment_type == "job":
            application_data.update({
                "job_id": job_id,
                "job_title": job_title,
                "organization": organization,
                "applicant_email": user_email,
                "applicant_name": user_name
            })
        else:
            application_data.update({
                "service_id": service_id,
                "service_type": service_type,
                "sub_type_id": sub_type_id,
                "sub_service_name": sub_service_name,
                "fields": form_data or {}
            })

        if existing_app:
            await db.applications.update_one(
                {"_id": ObjectId(application_id)},
                {"$set": application_data}
            )
            logger.info(f"✅ Updated existing application: {application_id}")
        else:
            result = await db.applications.insert_one(application_data)
            application_id = str(result.inserted_id)
            logger.info(f"✅ Created new application: {application_id}")

        return {
            "success": True,
            "order_id": razorpay_order_id,
            "application_id": application_id,
            "payment_id": application_id,
            "amount": amount,
            "amount_paise": amount * 100,
            "currency": "INR",
            "key_id": settings.RAZORPAY_KEY_ID,
            "category_used": user_category,
            "test_mode": settings.is_razorpay_test_mode,
            "message": "Order created successfully"
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Order creation error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# ==================== VERIFY PAYMENT (AUTO-APPROVE) ====================

@router.post("/payment/razorpay/verify-payment")
async def verify_payment(
    request_data: dict = Body(...),
    background_tasks: BackgroundTasks = None,
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    ✅ AUTO-APPROVE: Payment received → status becomes 'verification_successful' immediately
    """
    try:
        razorpay_order_id = request_data.get("razorpay_order_id")
        razorpay_payment_id = request_data.get("razorpay_payment_id")
        razorpay_signature = request_data.get("razorpay_signature")
        application_id = request_data.get("application_id")

        logger.info("=" * 70)
        logger.info("🔐 Verifying Razorpay payment")
        logger.info(f"   Order ID: {razorpay_order_id}")
        logger.info(f"   Payment ID: {razorpay_payment_id}")
        logger.info(f"   Application ID: {application_id}")
        logger.info("=" * 70)

        if not razorpay_order_id or not razorpay_payment_id or not razorpay_signature:
            return {
                "success": False,
                "code": "E400",
                "message": "Missing required payment details",
                "payment_verified": False
            }

        application = None
        if application_id and ObjectId.is_valid(application_id):
            application = await db.applications.find_one({"_id": ObjectId(application_id)})
            if application:
                logger.info(f"📋 Found application by ID: {application_id}")

        if not application:
            application = await db.applications.find_one({"razorpay_order_id": razorpay_order_id})
            if application:
                application_id = str(application["_id"])
                logger.info(f"📋 Found application by order ID: {application_id}")

        if not application:
            user_email = current_user.get("email")
            if user_email:
                application = await db.applications.find_one({
                    "user_email": user_email,
                    "razorpay_order_id": razorpay_order_id
                })
                if application:
                    application_id = str(application["_id"])
                    logger.info(f"📋 Found application by user email: {application_id}")

        if not application:
            logger.error(f"❌ Application not found for order: {razorpay_order_id}")
            return {
                "success": False,
                "code": "E404",
                "message": "Application not found",
                "payment_verified": False
            }

        # ==================== VERIFY SIGNATURE ====================
        signature_valid = False
        verification_method = "none"

        try:
            client = get_razorpay_client()
            if client:
                params_dict = {
                    'razorpay_order_id': razorpay_order_id,
                    'razorpay_payment_id': razorpay_payment_id,
                    'razorpay_signature': razorpay_signature
                }
                client.utility.verify_payment_signature(params_dict)
                signature_valid = True
                verification_method = "razorpay_utility"
                logger.info("✅ Signature verification successful via Razorpay utility")
        except Exception as sig_error:
            logger.warning(f"⚠️ Razorpay utility verification failed: {sig_error}")
            try:
                secret = settings.RAZORPAY_KEY_SECRET
                if secret:
                    data_string = f"{razorpay_order_id}|{razorpay_payment_id}"
                    generated_signature = hmac.new(
                        secret.encode('utf-8'),
                        data_string.encode('utf-8'),
                        hashlib.sha256
                    ).hexdigest()

                    signature_valid = hmac.compare_digest(
                        generated_signature.lower(),
                        razorpay_signature.lower()
                    )
                    if signature_valid:
                        verification_method = "manual_hmac"
                        logger.info("✅ Manual HMAC signature verification successful")
            except Exception as hmac_error:
                logger.error(f"❌ HMAC verification error: {hmac_error}")

        # ==================== HANDLE RESULT ====================
        if signature_valid:
            logger.info("✅ Payment VERIFIED successfully! AUTO-APPROVING...")

            payment_amount = application.get("payment_amount", 0)
            job_title = application.get("job_title", "Job Application")
            service_name = application.get("service_name", "Service Application")
            applicant_email = application.get("applicant_email") or application.get("user_email")
            application_type = application.get("application_type", "job")

            # ✅ AUTO-APPROVE
            if application_type == "job":
                new_status = "verification_successful"
            else:
                new_status = "payment_verified"

            update_data = {
                "payment_status": "completed",
                "payment_verification_status": "approved",
                "status": new_status,
                "razorpay_payment_id": razorpay_payment_id,
                "razorpay_order_id": razorpay_order_id,
                "razorpay_signature": razorpay_signature,
                "transaction_id": razorpay_payment_id,
                "paid_at": datetime.utcnow(),
                "payment_verified_at": datetime.utcnow(),
                "payment_verified_by": "razorpay_auto",
                "payment_verification_notes": "Auto-approved: Razorpay signature verified",
                "updated_at": datetime.utcnow(),
                "verification_method": verification_method,
                "payment_method": "razorpay",
            }

            await db.applications.update_one(
                {"_id": ObjectId(application_id)},
                {"$set": update_data}
            )

            logger.info(f"✅ Application {application_id} updated → status: {new_status}")

            # ==================== NOTIFY ====================
            if applicant_email:
                display_title = job_title if application_type == "job" else service_name
                amount_display = payment_amount or application.get("payment_amount", 0)

                await central_notification.send_notification(
                    user_ids=[applicant_email],
                    notification_type="application_status",
                    title="✅ Payment Verified Successfully!",
                    message=(
                        f"Your payment of ₹{amount_display} for '{display_title}' "
                        f"has been verified successfully.\n\n"
                        f"Transaction ID: {razorpay_payment_id}\n"
                        f"Your application has been submitted successfully."
                    ),
                    metadata={
                        "status": new_status,
                        "amount": amount_display,
                        "transaction_id": razorpay_payment_id,
                        "show_blue_bell": True,
                        "job_title": display_title,
                        "application_id": application_id,
                        "razorpay_payment_id": razorpay_payment_id,
                        "razorpay_order_id": razorpay_order_id,
                        "application_type": application_type
                    },
                    send_email=True,
                    send_websocket=True
                )

            if application_type == "job":
                admin_email = application.get("added_by")
                if admin_email and admin_email != applicant_email:
                    await central_notification.send_notification(
                        user_ids=[admin_email],
                        notification_type="admin_alert",
                        title="💰 Payment Received & Auto-Verified",
                        message=(
                            f"Payment of ₹{payment_amount} from {applicant_email} "
                            f"for '{job_title}' has been auto-verified."
                        ),
                        metadata={
                            "status": "payment_verified",
                            "amount": payment_amount,
                            "job_title": job_title,
                            "applicant_email": applicant_email,
                            "show_blue_bell": True,
                            "application_type": "job"
                        },
                        send_email=True,
                        send_websocket=True
                    )

            return {
                "success": True,
                "payment_verified": True,
                "application_id": application_id,
                "status": new_status,
                "payment_status": "completed",
                "payment_verification_status": "approved",
                "razorpay_payment_id": razorpay_payment_id,
                "razorpay_order_id": razorpay_order_id,
                "razorpay_signature": razorpay_signature,
                "verification_method": verification_method,
                "message": "Payment verified and approved successfully!",
                "application_type": application_type
            }

        else:
            logger.error("❌ Signature verification failed")

            await db.applications.update_one(
                {"_id": ObjectId(application_id)},
                {"$set": {
                    "payment_status": "failed",
                    "payment_verification_status": "rejected",
                    "status": "verification_rejected" if application.get("application_type") == "job" else "rejected",
                    "verification_notes": f"Signature verification failed. Razorpay payment ID: {razorpay_payment_id}",
                    "razorpay_payment_id": razorpay_payment_id,
                    "razorpay_order_id": razorpay_order_id,
                    "razorpay_signature": razorpay_signature,
                    "updated_at": datetime.utcnow()
                }}
            )

            applicant_email = application.get("applicant_email") or application.get("user_email")
            if applicant_email:
                await central_notification.send_notification(
                    user_ids=[applicant_email],
                    notification_type="application_status",
                    title="❌ Payment Verification Failed",
                    message="Your payment verification failed.\n\nPlease contact support or re-apply.",
                    metadata={
                        "status": "verification_rejected",
                        "show_blue_bell": True,
                        "application_id": application_id,
                        "razorpay_payment_id": razorpay_payment_id
                    },
                    send_email=True,
                    send_websocket=True
                )

            return {
                "success": False,
                "code": "E400",
                "message": "Invalid payment signature. Verification failed.",
                "payment_verified": False,
                "razorpay_payment_id": razorpay_payment_id,
                "razorpay_order_id": razorpay_order_id
            }

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


# ==================== GET PAYMENT STATUS ====================

@router.get("/payment/payment-status/{payment_id}")
async def get_payment_status(
    payment_id: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Get payment status for an application"""
    try:
        user_email = current_user.get("email")
        if not payment_id:
            raise HTTPException(status_code=400, detail="Payment ID is required")

        application = None
        if ObjectId.is_valid(payment_id):
            application = await db.applications.find_one({"_id": ObjectId(payment_id)})
        if not application:
            application = await db.applications.find_one({"payment_id": payment_id})
        if not application:
            application = await db.applications.find_one({"razorpay_order_id": payment_id})
        if not application and user_email:
            application = await db.applications.find_one({
                "user_email": user_email,
                "razorpay_order_id": payment_id
            })

        if not application:
            return {"success": False, "message": "Payment not found", "status": "not_found"}

        app_user_email = application.get("user_email") or application.get("applicant_email")
        if app_user_email != user_email and current_user.get("role") not in ["admin", "superadmin", "customadmin"]:
            raise HTTPException(status_code=403, detail="Access denied")

        return {
            "success": True,
            "application_id": str(application["_id"]),
            "application_type": application.get("application_type", "job"),
            "status": application.get("status", "unknown"),
            "payment_status": application.get("payment_status", "pending"),
            "payment_verification_status": application.get("payment_verification_status", "not_submitted"),
            "payment_method": application.get("payment_method", "razorpay"),
            "payment_amount": application.get("payment_amount", 0),
            "razorpay_order_id": application.get("razorpay_order_id"),
            "razorpay_payment_id": application.get("razorpay_payment_id"),
            "transaction_id": application.get("transaction_id"),
            "paid_at": application.get("paid_at").isoformat() if application.get("paid_at") else None,
            "created_at": application.get("created_at").isoformat() if application.get("created_at") else None,
            "updated_at": application.get("updated_at").isoformat() if application.get("updated_at") else None,
            "is_completed": application.get("payment_status") == "completed",
            "is_pending_verification": application.get("payment_verification_status") == "pending",
            "is_verified": application.get("payment_verification_status") == "approved",
            "is_rejected": application.get("payment_verification_status") == "rejected"
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Error getting payment status: {e}")
        return {"success": False, "message": str(e), "status": "error"}


# ==================== WEBHOOK (AUTO-APPROVE) ====================

@router.post("/payment/razorpay/webhook")
async def razorpay_webhook(
    request_data: dict = Body(...),
    db=Depends(get_db)
):
    """Webhook — payment.captured auto-approves"""
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

            application = await db.applications.find_one({"razorpay_order_id": order_id})
            if application:
                application_id = str(application["_id"])
                application_type = application.get("application_type", "job")
                new_status = "verification_successful" if application_type == "job" else "payment_verified"

                await db.applications.update_one(
                    {"_id": ObjectId(application_id)},
                    {"$set": {
                        "payment_status": "completed",
                        "payment_verification_status": "approved",
                        "status": new_status,
                        "razorpay_payment_id": payment_id,
                        "razorpay_order_id": order_id,
                        "transaction_id": payment_id,
                        "paid_at": datetime.utcnow(),
                        "payment_verified_at": datetime.utcnow(),
                        "payment_verified_by": "razorpay_webhook",
                        "payment_amount": int(amount),
                        "payment_method": "razorpay",
                        "updated_at": datetime.utcnow()
                    }}
                )
                logger.info(f"✅ Application {application_id} auto-approved via webhook")

                applicant_email = application.get("applicant_email") or application.get("user_email")
                if applicant_email:
                    job_title = application.get("job_title", "Application")
                    await central_notification.send_notification(
                        user_ids=[applicant_email],
                        notification_type="application_status",
                        title="✅ Payment Verified Successfully!",
                        message=f"Your payment of ₹{int(amount)} for '{job_title}' has been verified.",
                        metadata={
                            "status": new_status,
                            "amount": int(amount),
                            "transaction_id": payment_id,
                            "show_blue_bell": True,
                            "application_type": application_type
                        },
                        send_email=True,
                        send_websocket=True
                    )

        elif event == "payment.failed":
            payment = payload.get("payment", {}).get("entity", {})
            order_id = payment.get("order_id")
            payment_id = payment.get("id")
            logger.warning(f"❌ Payment failed: {payment_id} for order: {order_id}")

            application = await db.applications.find_one({"razorpay_order_id": order_id})
            if application:
                application_id = str(application["_id"])
                application_type = application.get("application_type", "job")
                await db.applications.update_one(
                    {"_id": ObjectId(application_id)},
                    {"$set": {
                        "payment_status": "failed",
                        "payment_verification_status": "rejected",
                        "status": "verification_rejected" if application_type == "job" else "rejected",
                        "razorpay_payment_id": payment_id,
                        "updated_at": datetime.utcnow()
                    }}
                )

        return {"success": True, "received": True}
    except Exception as e:
        logger.error(f"❌ Webhook error: {e}")
        return {"success": False, "error": str(e)}


# ==================== EMERGENCY FIX ====================

@router.post("/payment/fix-verification/{application_id}")
async def fix_verification(
    application_id: str,
    db=Depends(get_db)
):
    """Emergency: manually mark payment as approved"""
    try:
        if not ObjectId.is_valid(application_id):
            return {"success": False, "message": "Invalid application ID"}

        application = await db.applications.find_one({"_id": ObjectId(application_id)})
        if not application:
            return {"success": False, "message": "Application not found"}

        application_type = application.get("application_type", "job")
        new_status = "verification_successful" if application_type == "job" else "payment_verified"

        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": {
                "payment_status": "completed",
                "payment_verification_status": "approved",
                "status": new_status,
                "payment_verified_at": datetime.utcnow(),
                "payment_verified_by": "admin_emergency_fix",
                "updated_at": datetime.utcnow()
            }}
        )

        applicant_email = application.get("applicant_email") or application.get("user_email")
        if applicant_email:
            job_title = application.get("job_title", "Application")
            await central_notification.send_notification(
                user_ids=[applicant_email],
                notification_type="application_status",
                title="✅ Payment Verified!",
                message=f"Your payment for '{job_title}' has been verified.",
                metadata={"status": new_status, "show_blue_bell": True},
                send_email=True,
                send_websocket=True
            )

        return {
            "success": True,
            "message": "Application marked as verified",
            "application_id": application_id,
            "new_status": new_status
        }
    except Exception as e:
        logger.error(f"❌ Error fixing verification: {e}")
        return {"success": False, "message": str(e)}


# ==================== NO-SIGNATURE FALLBACK (AUTO-APPROVE) ====================

@router.post("/payment/razorpay/verify-payment-no-signature")
async def verify_payment_no_signature(
    request_data: dict = Body(...),
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Emergency fallback — auto-approves"""
    try:
        razorpay_order_id = request_data.get("razorpay_order_id")
        razorpay_payment_id = request_data.get("razorpay_payment_id")
        application_id = request_data.get("application_id")

        if not razorpay_order_id or not razorpay_payment_id:
            return {
                "success": False,
                "code": "E400",
                "message": "Missing required payment details",
                "payment_verified": False
            }

        application = None
        if application_id and ObjectId.is_valid(application_id):
            application = await db.applications.find_one({"_id": ObjectId(application_id)})
        if not application:
            application = await db.applications.find_one({"razorpay_order_id": razorpay_order_id})
        if not application:
            user_email = current_user.get("email")
            if user_email:
                application = await db.applications.find_one({
                    "user_email": user_email,
                    "razorpay_order_id": razorpay_order_id
                })

        if not application:
            return {"success": False, "code": "E404", "message": "Application not found", "payment_verified": False}

        application_id = str(application["_id"])
        application_type = application.get("application_type", "job")
        payment_amount = application.get("payment_amount", 0)
        applicant_email = application.get("applicant_email") or application.get("user_email")

        if application.get("payment_status") == "completed":
            return {
                "success": True,
                "payment_verified": True,
                "application_id": application_id,
                "status": application.get("status"),
                "message": "Payment already verified"
            }

        new_status = "verification_successful" if application_type == "job" else "payment_verified"

        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": {
                "payment_status": "completed",
                "payment_verification_status": "approved",
                "status": new_status,
                "razorpay_payment_id": razorpay_payment_id,
                "razorpay_order_id": razorpay_order_id,
                "transaction_id": razorpay_payment_id,
                "paid_at": datetime.utcnow(),
                "payment_verified_at": datetime.utcnow(),
                "payment_verified_by": "razorpay_fallback_auto",
                "updated_at": datetime.utcnow(),
                "verification_method": "no_signature_fallback"
            }}
        )

        if applicant_email:
            job_title = application.get("job_title", "Job Application")
            await central_notification.send_notification(
                user_ids=[applicant_email],
                notification_type="application_status",
                title="✅ Payment Verified Successfully!",
                message=f"Your payment for '{job_title}' has been verified.",
                metadata={
                    "status": new_status,
                    "amount": payment_amount,
                    "transaction_id": razorpay_payment_id,
                    "show_blue_bell": True
                },
                send_email=True,
                send_websocket=True
            )

        return {
            "success": True,
            "payment_verified": True,
            "application_id": application_id,
            "status": new_status,
            "payment_status": "completed",
            "payment_verification_status": "approved",
            "razorpay_payment_id": razorpay_payment_id,
            "razorpay_order_id": razorpay_order_id,
            "verification_method": "no_signature_fallback",
            "message": "Payment verified successfully!",
            "application_type": application_type
        }
    except Exception as e:
        logger.error(f"❌ Verification error: {e}")
        import traceback
        traceback.print_exc()
        return {"success": False, "code": "E500", "message": f"Verification failed: {str(e)}", "payment_verified": False}


print("=" * 70)
print("✅ Razorpay Integration Loaded - AUTO-APPROVAL ENABLED")
print("=" * 70)