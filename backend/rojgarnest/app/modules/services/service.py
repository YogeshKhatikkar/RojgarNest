# app/modules/services/service.py - COMPLETE FINAL FIXED VERSION
# ✅ CRITICAL FIX: _enrich_application_for_frontend now AUTO-CORRECTS
#    legacy data where payment_status="completed" but verification="pending"
# ✅ This fixes the EXACT issue: DB shows completed but UI shows pending

from fastapi import HTTPException, BackgroundTasks
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
from bson import ObjectId
import logging
import json
import base64
import secrets

from app.db.connection import get_db
from app.core.config.settings import settings
from app.core.utils.logger import logger
from app.models.unified_application_model import UnifiedApplicationModel, ApplicationType
from app.modules.services.schema import (
    ServiceApplicationCreateSchema,
    ServiceApplicationUpdateSchema,
    ServiceApplicationStatus,
    ServiceType,
    ServiceFeeSchema,
    ServiceApplicationConfirmSchema,
    ServiceApplicationUpdateSubmitSchema
)
from app.modules.notification.service import central_notification

module_logger = logging.getLogger(__name__)


class ServiceService:
    """Service Application Service - Uses Unified Applications Collection"""

    def __init__(self, db):
        self.db = db
        self.applications = db.applications
        self.auth = db.auth
        self.profile = db.profile
        self.notifications = db.notifications

    async def _get_db(self):
        return self.db

    # ============================================================
    # ✅✅✅ THE CRITICAL FIX - _enrich_application_for_frontend
    # ------------------------------------------------------------
    # This method now detects the EXACT broken combination:
    #   payment_status = "completed" AND
    #   payment_verification_status = "pending"
    # And auto-corrects it to:
    #   payment_verification_status = "approved"
    #   status = "verification_successful" (job) / "payment_verified" (service)
    #
    # Result: Frontend will NEVER see "pending" for a completed payment.
    # ============================================================
    def _enrich_application_for_frontend(self, app: Dict[str, Any]) -> Dict[str, Any]:
        """
        Normalize & enrich application data for frontend display.

        CRITICAL: If gateway says payment completed but verification is pending,
        auto-correct to approved. This handles legacy data created before
        the auto-approval feature was added.
        """
        if not app:
            return app

        # ---- Read raw fields safely ----
        raw_gateway_status = str(app.get("payment_status") or "pending").strip().lower()
        raw_payment_status = str(app.get("payment_verification_status") or "not_submitted").strip().lower()
        raw_app_status = str(app.get("status") or "payment_pending").strip().lower()
        app_type = str(app.get("application_type") or "service").strip().lower()

        module_logger.info("=" * 70)
        module_logger.info("🔍 ENRICHING APPLICATION FOR FRONTEND")
        module_logger.info(f"   App ID: {app.get('_id')}")
        module_logger.info(f"   Type: {app_type}")
        module_logger.info(f"   Raw gateway status: {raw_gateway_status}")
        module_logger.info(f"   Raw payment verification: {raw_payment_status}")
        module_logger.info(f"   Raw app status: {raw_app_status}")

        # ============================================================
        # ✅ THE FIX: Auto-correct broken combination
        # If gateway = completed but verification = pending
        # → treat as approved (because gateway already verified)
        # ============================================================
        auto_corrected = False

        if raw_gateway_status == "completed" and raw_payment_status in ("pending", "not_submitted", "pending_verification", "under_review"):
            module_logger.warning(
                f"⚠️ AUTO-CORRECTING broken data: "
                f"payment_status=completed + verification={raw_payment_status}"
            )
            raw_payment_status = "approved"
            auto_corrected = True

            # Also fix the app status if it's still in a pending state
            if raw_app_status in ("pending_verification", "payment_pending", "pending"):
                if app_type == "job":
                    raw_app_status = "verification_successful"
                else:
                    raw_app_status = "payment_verified"
                module_logger.warning(f"   → Corrected app status to: {raw_app_status}")

        # ============================================================
        # Normalize payment verification status
        # ============================================================
        if raw_payment_status in ("approved", "verified", "success", "completed"):
            normalized_payment = "approved"
            is_verified = True
            is_pending = False
            is_rejected = False
        elif raw_payment_status in ("pending", "pending_verification", "under_review"):
            normalized_payment = "pending"
            is_verified = False
            is_pending = True
            is_rejected = False
        elif raw_payment_status in ("rejected", "failed", "declined"):
            normalized_payment = "rejected"
            is_verified = False
            is_pending = False
            is_rejected = True
        else:
            normalized_payment = "not_submitted"
            is_verified = False
            is_pending = False
            is_rejected = False

        # Override in app dict
        app["payment_verification_status"] = normalized_payment
        app["payment_status"] = raw_gateway_status

        # ============================================================
        # Add clear boolean flags for frontend
        # ============================================================
        app["is_payment_verified"] = is_verified
        app["is_payment_pending"] = is_pending
        app["is_payment_rejected"] = is_rejected
        app["is_payment_not_submitted"] = (normalized_payment == "not_submitted")
        app["is_payment_completed"] = (raw_gateway_status == "completed")
        app["_auto_corrected"] = auto_corrected  # Debug flag

        # ============================================================
        # Add human-readable display status
        # ============================================================
        if is_verified:
            display_status = "Payment Verified"
            display_status_key = "verified"
            display_color = "green"
        elif is_rejected:
            display_status = "Payment Rejected"
            display_status_key = "rejected"
            display_color = "red"
        elif is_pending:
            display_status = "Payment Pending Verification"
            display_status_key = "pending"
            display_color = "orange"
        else:
            display_status = raw_app_status.replace("_", " ").title()
            display_status_key = raw_app_status
            display_color = "grey"

        app["display_status"] = display_status
        app["display_status_key"] = display_status_key
        app["display_status_color"] = display_color

        # ============================================================
        # Override the app status (for frontend to read directly)
        # ============================================================
        app["status"] = raw_app_status

        # ============================================================
        # Timestamp formatting
        # ============================================================
        for ts_field in ("payment_verified_at", "paid_at", "updated_at", "created_at",
                         "applied_at", "submitted_at", "final_submitted_at",
                         "transaction_date"):
            if app.get(ts_field) and isinstance(app[ts_field], datetime):
                app[ts_field] = app[ts_field].isoformat()

        # ============================================================
        # Ensure payment receipt URL is present
        # ============================================================
        if not app.get("payment_receipt_url"):
            app["payment_receipt_url"] = app.get("screenshot_url")

        # ============================================================
        # Ensure application_type is set
        # ============================================================
        app["application_type"] = app_type

        module_logger.info(f"   ✅ Final payment_verification_status: {normalized_payment}")
        module_logger.info(f"   ✅ Final app status: {raw_app_status}")
        module_logger.info(f"   ✅ Auto-corrected: {auto_corrected}")
        module_logger.info("=" * 70)

        return app

    # ============================================================
    # Helper: Return raw application by ID
    # ============================================================
    async def get_application_by_id(self, application_id: str) -> Optional[Dict[str, Any]]:
        """Fetch raw application from DB by ID (service type only)"""
        if not ObjectId.is_valid(application_id):
            return None
        return await self.applications.find_one({
            "_id": ObjectId(application_id),
            "application_type": "service"
        })

    # ============================================================
    # Service display helper
    # ============================================================
    def _get_service_display_details(self, service_id: str, sub_type_id: str) -> Dict[str, str]:
        service_names = {
            "pan": "PAN Card",
            "aadhar": "Aadhaar",
            "epf": "EPF / PF",
            "passport": "Passport",
            "driving_license": "Driving License",
            "voter_id": "Voter ID",
            "ration_card": "Ration Card",
            "income_certificate": "Income Certificate",
            "caste_certificate": "Caste Certificate",
            "domicile": "Domicile Certificate",
            "disability": "Disability Certificate",
            "bonafide": "Bonafide Certificate",
            "gap_certificate": "Gap Certificate",
        }
        service_icons = {
            "pan": "🪪", "aadhar": "🪪", "epf": "🏦", "passport": "🛂",
            "driving_license": "🚗", "voter_id": "🗳️", "ration_card": "🪪",
            "income_certificate": "💵", "caste_certificate": "📜",
            "domicile": "🏠", "disability": "♿", "bonafide": "📄",
            "gap_certificate": "⏳",
        }
        return {
            "service_name": service_names.get(service_id, service_id),
            "service_icon": service_icons.get(service_id, "📄"),
            "sub_service_name": sub_type_id.replace("_", " ").title(),
            "sub_service_description": "",
        }

    # ============================================================
    # CREATE APPLICATION
    # ============================================================
    async def create_application(
        self,
        data: ServiceApplicationCreateSchema,
        user_email: str,
        user_name: str,
        user_id: str
    ) -> Dict[str, Any]:
        try:
            profile = await self.profile.find_one({"email": user_email})
            user_category = profile.get("category", "General/UR") if profile else "General/UR"

            disability = profile.get("disability", {}) if profile else {}
            is_disabled = disability.get("is_disabled", False) if isinstance(disability, dict) else False

            fee = await self._calculate_service_fee(
                service_type=data.service_type,
                sub_type_id=data.service_sub_type,
                user_category=user_category,
                is_disabled=is_disabled
            )

            application = UnifiedApplicationModel(
                application_type="service",
                user_email=user_email,
                user_name=user_name,
                user_id=user_id,
                user_category="service",
                is_disabled=is_disabled,
                service_id=data.service_type.value,
                sub_type_id=data.service_sub_type,
                service_name=data.service_name,
                sub_service_name=data.sub_service_name,
                fields=data.fields,
                documents=data.documents,
                status="payment_pending",
                payment_amount=fee,
                payment_category_used="service",
                payment_verification_status="not_submitted",
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow()
            )

            result = await self.applications.insert_one(application.to_dict())
            application_id = str(result.inserted_id)

            qr_response = None
            if fee > 0:
                qr_response = await self._generate_payment_qr(
                    application_id=application_id,
                    user_email=user_email,
                    amount=fee,
                    service_type=data.service_type.value,
                    sub_type_id=data.service_sub_type,
                    form_data=data.fields,
                    documents=data.documents
                )

                await self.applications.update_one(
                    {"_id": ObjectId(application_id)},
                    {
                        "$set": {
                            "payment_id": qr_response["payment_id"],
                            "qr_code_data": qr_response["qr_code_data"],
                            "qr_image_url": qr_response["qr_image_url"],
                            "upi_text": qr_response.get("upi_text"),
                            "order_id": qr_response.get("order_id"),
                            "expires_at": qr_response.get("expires_at"),
                            "status": "payment_pending",
                            "updated_at": datetime.utcnow()
                        }
                    }
                )

            return {
                "success": True,
                "application_id": application_id,
                "application_type": "service",
                "amount": fee,
                "needs_payment": fee > 0,
                "payment_id": qr_response.get("payment_id") if qr_response else None,
                "qr_code_data": qr_response.get("qr_code_data") if qr_response else None,
                "qr_image_url": qr_response.get("qr_image_url") if qr_response else None,
                "expires_at": qr_response.get("expires_at") if qr_response else None,
                "status": "payment_pending",
                "message": "Application created. Complete payment to submit."
            }

        except Exception as e:
            module_logger.error(f"Failed to create service application: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to create application: {str(e)}")

    # ============================================================
    # SUBMIT VERIFICATION
    # ============================================================
    async def submit_verification(
        self,
        application_id: str,
        transaction_id: str,
        transaction_date: str,
        screenshot_url: str,
        screenshot_public_id: str,
        user_email: str
    ) -> Dict[str, Any]:
        if not ObjectId.is_valid(application_id):
            raise HTTPException(status_code=400, detail="Invalid application ID")

        application = await self.applications.find_one({
            "_id": ObjectId(application_id),
            "application_type": "service"
        })
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")

        if application.get("user_email") != user_email:
            raise HTTPException(status_code=403, detail="Unauthorized")

        if application.get("payment_verification_status") == "pending":
            raise HTTPException(status_code=400, detail="Verification already submitted")

        update_data = {
            "transaction_id": transaction_id.strip(),
            "transaction_date": datetime.fromisoformat(transaction_date),
            "payment_receipt_url": screenshot_url,
            "payment_receipt_public_id": screenshot_public_id,
            "payment_verification_status": "pending",
            "status": "pending_verification",
            "updated_at": datetime.utcnow()
        }

        await self.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data}
        )

        await central_notification.send_notification(
            user_ids=[user_email],
            notification_type="application_status",
            title="⏳ Service Application Pending Verification",
            message=f"Your service application '{application.get('sub_service_name')}' is pending verification.",
            related_id=application_id,
            metadata={
                "service_name": application.get("service_name"),
                "sub_service_name": application.get("sub_service_name"),
                "amount": application.get("payment_amount"),
                "application_type": "service",
                "status": "pending_verification"
            },
            send_email=True,
            send_websocket=True
        )

        await self._notify_admins(
            application_id=application_id,
            service_name=application.get("service_name"),
            sub_service_name=application.get("sub_service_name"),
            user_email=user_email,
            user_name=application.get("user_name"),
            amount=application.get("payment_amount"),
            transaction_id=transaction_id,
            action="verify"
        )

        return {
            "success": True,
            "message": "Verification submitted. Application pending admin approval.",
            "application_id": application_id,
            "application_type": "service",
            "status": "pending_verification"
        }

    # ============================================================
    # VERIFY PAYMENT (ADMIN)
    # ============================================================
    async def verify_payment(
        self,
        application_id: str,
        action: str,
        admin_email: str,
        notes: Optional[str] = None
    ) -> Dict[str, Any]:
        if not ObjectId.is_valid(application_id):
            raise HTTPException(status_code=400, detail="Invalid application ID")

        application = await self.applications.find_one({
            "_id": ObjectId(application_id),
            "application_type": "service"
        })
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")

        current_status = application.get("status")
        if current_status in ["approved", "rejected", "completed", "payment_verified", "verification_successful"]:
            return {
                "success": False,
                "message": f"Application already {current_status}",
                "application_id": application_id
            }

        user_email = application.get("user_email")
        service_name = application.get("service_name")
        sub_service_name = application.get("sub_service_name")
        amount = application.get("payment_amount", 0)
        transaction_id = application.get("transaction_id")

        if action == "approve":
            update_data = {
                "status": "payment_verified",
                "payment_status": "completed",
                "payment_verification_status": "approved",
                "payment_verified_by": admin_email,
                "payment_verified_at": datetime.utcnow(),
                "paid_at": datetime.utcnow(),
                "payment_verification_notes": notes or "Payment approved",
                "updated_at": datetime.utcnow()
            }

            await self.applications.update_one(
                {"_id": ObjectId(application_id)},
                {"$set": update_data}
            )

            await central_notification.send_notification(
                user_ids=[user_email],
                notification_type="application_status",
                title="✅ Payment Verified Successfully!",
                message=f"Your payment of ₹{amount} for '{sub_service_name}' has been verified successfully.",
                related_id=application_id,
                metadata={
                    "status": "payment_verified",
                    "amount": amount,
                    "service_name": service_name,
                    "sub_service_name": sub_service_name,
                    "application_type": "service"
                },
                send_email=True,
                send_websocket=True
            )

            module_logger.info(f"✅ Payment approved for {application_id} by {admin_email}")

            return {
                "success": True,
                "message": "Payment approved successfully",
                "application_id": application_id,
                "application_type": "service",
                "status": "payment_verified"
            }

        else:
            if not notes:
                notes = "Payment rejected by admin - Please contact support"

            update_data = {
                "status": "rejected",
                "payment_status": "failed",
                "payment_verification_status": "rejected",
                "payment_verified_by": admin_email,
                "payment_verified_at": datetime.utcnow(),
                "payment_rejection_reason": notes,
                "payment_verification_notes": notes,
                "updated_at": datetime.utcnow()
            }

            await self.applications.update_one(
                {"_id": ObjectId(application_id)},
                {"$set": update_data}
            )

            await central_notification.send_notification(
                user_ids=[user_email],
                notification_type="application_status",
                title="❌ Payment Verification Failed",
                message=f"Your payment of ₹{amount} for '{sub_service_name}' has been REJECTED.\nReason: {notes}",
                related_id=application_id,
                metadata={
                    "status": "rejected",
                    "amount": amount,
                    "service_name": service_name,
                    "sub_service_name": sub_service_name,
                    "application_type": "service",
                    "rejection_reason": notes
                },
                send_email=True,
                send_websocket=True
            )

            module_logger.info(f"❌ Payment rejected for {application_id} by {admin_email}")

            return {
                "success": True,
                "message": f"Payment rejected. Reason: {notes}",
                "application_id": application_id,
                "application_type": "service",
                "status": "rejected"
            }

    # ============================================================
    # ✅ GET USER APPLICATIONS (WITH AUTO-FIX)
    # ============================================================
    async def get_user_applications(self, user_email: str) -> List[Dict[str, Any]]:
        """Get all service applications for a user - WITH ENRICHED STATUS"""
        try:
            applications = await self.applications.find({
                "user_email": user_email,
                "application_type": "service"
            }).sort("created_at", -1).to_list(100)

            enriched = []
            for app in applications:
                app["_id"] = str(app["_id"])
                if app.get("payment_id"):
                    app["payment_id"] = str(app["payment_id"])

                # ✅ Enrich — this will auto-correct pending data
                app = self._enrich_application_for_frontend(app)

                service_id = app.get("service_id", "")
                sub_type_id = app.get("sub_type_id", "")
                details = self._get_service_display_details(service_id, sub_type_id)
                app["display_service_name"] = details.get("service_name", service_id)
                app["display_service_icon"] = details.get("service_icon", "📄")
                app["display_sub_service_name"] = details.get("sub_service_name", sub_type_id)

                enriched.append(app)

            module_logger.info(
                f"📋 Fetched {len(enriched)} service applications for {user_email}"
            )
            return enriched
        except Exception as e:
            module_logger.error(f"Failed to get user applications: {e}")
            return []

    # ============================================================
    # ✅ GET ALL APPLICATIONS (ADMIN)
    # ============================================================
    async def get_all_applications(
        self,
        admin_email: str,
        status: Optional[str] = None,
        limit: int = 100,
        skip: int = 0
    ) -> Dict[str, Any]:
        try:
            user = await self.auth.find_one({"email": admin_email})
            if user.get("role") not in ["admin", "customadmin", "superadmin"]:
                raise HTTPException(status_code=403, detail="Access denied")

            query = {"application_type": "service"}
            if status:
                query["status"] = status

            applications = await self.applications.find(query).sort(
                "created_at", -1
            ).skip(skip).limit(limit).to_list(limit)

            enriched = []
            for app in applications:
                app["_id"] = str(app["_id"])
                app = self._enrich_application_for_frontend(app)

                service_id = app.get("service_id", "")
                sub_type_id = app.get("sub_type_id", "")
                details = self._get_service_display_details(service_id, sub_type_id)
                app["display_service_name"] = details.get("service_name", service_id)
                app["display_service_icon"] = details.get("service_icon", "📄")
                app["display_sub_service_name"] = details.get("sub_service_name", sub_type_id)

                enriched.append(app)

            total = await self.applications.count_documents(query)

            return {
                "applications": enriched,
                "total": total,
                "skip": skip,
                "limit": limit
            }
        except Exception as e:
            module_logger.error(f"Failed to get all applications: {e}")
            raise HTTPException(status_code=500, detail=str(e))

    # ============================================================
    # ✅ GET APPLICATION DETAIL (WITH AUTO-FIX)
    # ============================================================
    async def get_application_detail(self, application_id: str, user_email: str) -> Dict[str, Any]:
        if not ObjectId.is_valid(application_id):
            raise HTTPException(status_code=400, detail="Invalid application ID")

        application = await self.applications.find_one({
            "_id": ObjectId(application_id),
            "application_type": "service"
        })
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")

        is_owner = application.get("user_email") == user_email
        if not is_owner:
            user = await self.auth.find_one({"email": user_email})
            if user.get("role") not in ["admin", "customadmin", "superadmin"]:
                raise HTTPException(status_code=403, detail="Access denied")

        application["_id"] = str(application["_id"])

        # ✅ Enrich — auto-corrects pending data
        application = self._enrich_application_for_frontend(application)

        service_id = application.get("service_id", "")
        sub_type_id = application.get("sub_type_id", "")
        details = self._get_service_display_details(service_id, sub_type_id)
        application["display_service_name"] = details.get("service_name", service_id)
        application["display_service_icon"] = details.get("service_icon", "📄")
        application["display_sub_service_name"] = details.get("sub_service_name", sub_type_id)

        return application

    # ============================================================
    # ✅ GET PAYMENT STATUS ONLY (Fast endpoint)
    # ============================================================
    async def get_payment_status(self, application_id: str, user_email: str) -> Dict[str, Any]:
        """Lightweight payment status fetcher"""
        if not ObjectId.is_valid(application_id):
            raise HTTPException(status_code=400, detail="Invalid application ID")

        application = await self.applications.find_one({
            "_id": ObjectId(application_id),
            "application_type": "service"
        })
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")

        is_owner = application.get("user_email") == user_email
        if not is_owner:
            user = await self.auth.find_one({"email": user_email})
            if user.get("role") not in ["admin", "customadmin", "superadmin"]:
                raise HTTPException(status_code=403, detail="Access denied")

        enriched = self._enrich_application_for_frontend(application)

        return {
            "success": True,
            "application_id": str(application["_id"]),
            "payment_verification_status": enriched.get("payment_verification_status"),
            "status": enriched.get("status"),
            "is_payment_verified": enriched.get("is_payment_verified"),
            "is_payment_pending": enriched.get("is_payment_pending"),
            "is_payment_rejected": enriched.get("is_payment_rejected"),
            "display_status": enriched.get("display_status"),
            "display_status_key": enriched.get("display_status_key"),
            "display_status_color": enriched.get("display_status_color"),
            "payment_amount": application.get("payment_amount"),
            "payment_verified_at": enriched.get("payment_verified_at"),
            "payment_verified_by": application.get("payment_verified_by"),
            "updated_at": enriched.get("updated_at"),
        }

    # ============================================================
    # UPDATE APPLICATION STATUS (ADMIN)
    # ============================================================
    async def update_application_status(
        self,
        application_id: str,
        status: str,
        admin_email: str,
        admin_notes: Optional[str] = None
    ) -> Dict[str, Any]:
        if not ObjectId.is_valid(application_id):
            raise HTTPException(status_code=400, detail="Invalid application ID")

        application = await self.applications.find_one({
            "_id": ObjectId(application_id),
            "application_type": "service"
        })
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")

        old_status = application.get("status")

        update_data = {
            "status": status,
            "admin_notes": admin_notes,
            "updated_at": datetime.utcnow(),
            "last_updated_by": admin_email
        }

        result = await self.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data}
        )

        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Application not found or status unchanged")

        user_email = application.get("user_email")
        if user_email:
            status_messages = {
                "payment_verified": "✅ Your payment has been verified.",
                "under_review": "📋 Your application is under review.",
                "review_application": "📋 Your application is under review. Please take action.",
                "approved": "🎉 Congratulations! Your application has been approved.",
                "rejected": "📝 Your application has been rejected.",
                "completed": "✅ Your application has been completed successfully.",
                "confirmed_application": "✅ Your application has been confirmed successfully!",
                "update_application": "📝 Your application update has been submitted for admin review.",
            }

            service_name = application.get("service_name", "Service")

            await central_notification.send_notification(
                user_ids=[user_email],
                notification_type="application_status",
                title=f"Service Application Status: {status.upper()}",
                message=status_messages.get(
                    status,
                    f"Your application status has been updated to {status}."
                ),
                related_id=application_id,
                metadata={
                    "application_id": application_id,
                    "service_name": service_name,
                    "old_status": old_status,
                    "new_status": status,
                    "application_type": "service",
                    "admin_notes": admin_notes,
                    "admin_email": admin_email,
                    "show_blue_bell": True
                },
                send_email=True,
                send_websocket=True
            )

        return {
            "success": True,
            "message": f"Application status updated to {status}",
            "application_id": application_id,
            "application_type": "service",
            "old_status": old_status,
            "new_status": status,
            "updated_by": admin_email
        }

    # ============================================================
    # USER CONFIRM APPLICATION
    # ============================================================
    async def user_confirm_application(
        self,
        application_id: str,
        user_email: str,
        notes: Optional[str] = None
    ) -> Dict[str, Any]:
        if not ObjectId.is_valid(application_id):
            raise HTTPException(status_code=400, detail="Invalid application ID")

        application = await self.applications.find_one({
            "_id": ObjectId(application_id),
            "application_type": "service"
        })
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")

        if application.get("user_email") != user_email:
            raise HTTPException(status_code=403, detail="Unauthorized")

        current_status = application.get("status", "")
        if current_status not in ["review_application", "under_review"]:
            raise HTTPException(
                status_code=400,
                detail=f"Cannot confirm application in '{current_status}' status."
            )

        update_data = {
            "status": "confirmed_application",
            "confirmed_at": datetime.utcnow(),
            "confirmed_by": user_email,
            "updated_at": datetime.utcnow()
        }

        if notes:
            update_data["confirmation_notes"] = notes

        result = await self.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data}
        )

        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Application not found")

        service_name = application.get("service_name", "Service")

        await central_notification.send_notification(
            user_ids=[user_email],
            notification_type="application_status",
            title="✅ Application Confirmed!",
            message=f"Your service application for '{service_name}' has been confirmed successfully.",
            related_id=application_id,
            metadata={
                "status": "confirmed_application",
                "service_name": service_name,
                "application_id": application_id,
                "application_type": "service",
                "show_blue_bell": True
            },
            send_email=True,
            send_websocket=True
        )

        return {
            "success": True,
            "message": "Application confirmed successfully",
            "application_id": application_id,
            "application_type": "service",
            "status": "confirmed_application"
        }

    # ============================================================
    # INTERNAL HELPERS
    # ============================================================
    async def _calculate_service_fee(
        self,
        service_type: ServiceType,
        sub_type_id: str,
        user_category: str,
        is_disabled: bool
    ) -> int:
        base_fees = {
            ServiceType.PAN: 100,
            ServiceType.AADHAAR: 50,
            ServiceType.EPF: 150,
            ServiceType.PASSPORT: 200,
            ServiceType.DRIVING_LICENSE: 150,
            ServiceType.VOTER_ID: 50,
            ServiceType.RATION_CARD: 75,
            ServiceType.INCOME_CERTIFICATE: 100,
            ServiceType.CASTE_CERTIFICATE: 100,
            ServiceType.DOMICILE: 80,
            ServiceType.DISABILITY: 50,
            ServiceType.BONAFIDE: 75,
            ServiceType.GAP_CERTIFICATE: 80,
        }
        base_fee = base_fees.get(service_type, 100)
        if is_disabled:
            return max(10, int(base_fee * 0.5))
        return base_fee

    async def _generate_payment_qr(
        self,
        application_id: str,
        user_email: str,
        amount: int,
        service_type: str,
        sub_type_id: str,
        form_data: Dict = None,
        documents: Dict = None
    ) -> Dict[str, Any]:
        from app.modules.payment.routes import generate_qr_code_html

        payment_id = str(ObjectId())
        order_id = f"SVC{payment_id[-8:]}{int(datetime.utcnow().timestamp())}"

        upi_id = getattr(settings, 'UPI_ID', 'your-upi-id@okhdfcbank')
        upi_text = f"upi://pay?pa={upi_id}&pn=RojgarNest&am={amount}&cu=INR&tn={order_id}&tid={order_id}"
        qr_image_url = generate_qr_code_html(upi_text, amount, order_id)

        qr_data = {
            "type": "upi_qr",
            "upi_text": upi_text,
            "qr_image_url": qr_image_url,
            "amount": amount,
            "order_id": order_id,
            "service_type": service_type,
            "sub_type": sub_type_id,
            "expires_in_minutes": 30
        }

        qr_code_data = base64.b64encode(json.dumps(qr_data).encode()).decode()

        return {
            "payment_id": payment_id,
            "qr_code_data": qr_code_data,
            "qr_image_url": qr_image_url,
            "amount": amount,
            "order_id": order_id,
            "expires_at": datetime.utcnow() + timedelta(minutes=30)
        }

    async def _notify_admins(
        self,
        application_id: str,
        service_name: str,
        sub_service_name: str,
        user_email: str,
        user_name: str,
        amount: int,
        transaction_id: Optional[str] = None,
        action: str = "new",
        update_count: int = 0
    ):
        try:
            admins = await self.auth.find({
                "role": {"$in": ["admin", "customadmin", "superadmin"]},
                "is_active": True
            }).to_list(100)

            admin_emails = [admin.get("email") for admin in admins if admin.get("email")]

            if admin_emails:
                if action == "new":
                    title = f"📋 New Service Application: {service_name}"
                    message = f"{user_name} ({user_email}) has applied for {sub_service_name} service.\nAmount: ₹{amount}"
                elif action == "confirm":
                    title = f"✅ Application Confirmed: {service_name}"
                    message = f"{user_name} ({user_email}) has confirmed their application for {sub_service_name}."
                elif action == "update":
                    title = f"📝 Application Update: {service_name}"
                    message = f"{user_name} ({user_email}) has submitted an update for {sub_service_name} service.\nUpdates: {update_count} fields"
                else:
                    title = f"💰 Payment Verification: {service_name}"
                    message = f"{user_name} ({user_email}) has submitted payment verification for {sub_service_name}.\nTransaction ID: {transaction_id}\nAmount: ₹{amount}"

                await central_notification.send_notification(
                    user_ids=admin_emails,
                    notification_type="admin_alert",
                    title=title,
                    message=message,
                    metadata={
                        "application_id": application_id,
                        "service_name": service_name,
                        "sub_service_name": sub_service_name,
                        "user_email": user_email,
                        "user_name": user_name,
                        "amount": amount,
                        "application_type": "service",
                        "status": "pending_verification" if action == "verify" else "pending",
                        "transaction_id": transaction_id,
                        "show_blue_bell": True
                    },
                    send_email=True,
                    send_websocket=True
                )
        except Exception as e:
            module_logger.error(f"Failed to notify admins: {e}")

    # ============================================================
    # ✅ NEW: GET PROFILE DATA FOR SERVICE APPLICATION
    # ------------------------------------------------------------
    # Fetches applicant details / address / bank details from
    # profile & auth collections so the Flutter Form tab can
    # auto-fill fields. Mirrors SchemesModule.get_profile_data.
    # ============================================================
    async def get_profile_data(self, user_email: str) -> Dict[str, Any]:
        """
        Return profile-derived data for prefilling the Form tab.

        Returns:
            {
                "success": True,
                "profile_complete": bool,
                "missing_fields": [...],
                "applicant_details": {...},
                "applicant_address": {...},
                "bank_details": {...}
            }
        """
        if not user_email:
            raise HTTPException(
                status_code=400, detail="User email is required"
            )

        profile = await self.profile.find_one({"email": user_email})
        if not profile:
            raise HTTPException(
                status_code=404,
                detail=(
                    "Profile not found. Please complete your "
                    "profile first."
                ),
            )

        auth_user = await self.auth.find_one({"email": user_email})

        disability = profile.get("disability", {}) or {}
        gov_ids = profile.get("government_ids", {}) or {}

        applicant_details = {
            "full_name": (
                profile.get("full_name")
                or (auth_user.get("name") if auth_user else "")
                or ""
            ),
            "father_name": profile.get("father_name", "") or "",
            "mother_name": profile.get("mother_name", "") or "",
            "date_of_birth": profile.get("dob", "") or "",
            "gender": (profile.get("gender") or "male"),
            "category": profile.get("category", "General") or "General",
            "marital_status": (
                profile.get("marital_status") or "Unmarried"
            ),
            "aadhaar_number": gov_ids.get("aadhar_number", "") or "",
            "mobile": (
                (auth_user.get("mobile") if auth_user else "")
                or profile.get("phone", "")
                or ""
            ),
            "email": user_email,
            "annual_income": (
                profile.get("family_annual_income", 0) or 0
            ),
            "bpl_status": bool(profile.get("bpl_status", False)),
            "disability_status": bool(
                disability.get("is_disabled", False)
            ),
            "disability_percentage": float(
                disability.get("disability_percentage", 0.0) or 0.0
            ),
            "scheme_name": None,
            "scheme_id": None,
            "application_type": "service",   # ✅ differentiate
        }

        cur_addr = profile.get("current_address", {}) or {}
        applicant_address = {
            "address_line1": (
                cur_addr.get("house_number")
                or cur_addr.get("address_line1")
                or ""
            ),
            "address_line2": (
                cur_addr.get("landmark")
                or cur_addr.get("address_line2")
                or ""
            ),
            "village_city": (
                cur_addr.get("village_name")
                or cur_addr.get("city")
                or cur_addr.get("village_city")
                or ""
            ),
            "district": cur_addr.get("district", "") or "",
            "state": cur_addr.get("state", "") or "",
            "pincode": (
                cur_addr.get("pincode")
                or cur_addr.get("zipcode")
                or ""
            ),
            "country": cur_addr.get("country", "India") or "India",
        }

        raw_bank = profile.get("bank_details", {}) or {}
        bank_info = {
            "account_holder_name": (
                raw_bank.get("account_holder_name", "") or ""
            ),
            "bank_name": raw_bank.get("bank_name", "") or "",
            "account_number": (
                raw_bank.get("account_number", "") or ""
            ),
            "ifsc_code": raw_bank.get("ifsc_code", "") or "",
            "branch_name": raw_bank.get("branch_name", "") or "",
            "account_type": (
                raw_bank.get("account_type", "savings") or "savings"
            ),
        }

        required_fields = {
            "full_name": applicant_details["full_name"],
            "father_name": applicant_details["father_name"],
            "date_of_birth": applicant_details["date_of_birth"],
            "mobile": applicant_details["mobile"],
            "email": applicant_details["email"],
            "aadhaar_number": applicant_details["aadhaar_number"],
            "address_line1": applicant_address["address_line1"],
            "village_city": applicant_address["village_city"],
            "district": applicant_address["district"],
            "state": applicant_address["state"],
            "pincode": applicant_address["pincode"],
            "bank_name": bank_info["bank_name"],
            "account_number": bank_info["account_number"],
            "ifsc_code": bank_info["ifsc_code"],
        }

        missing_fields = [
            field
            for field, value in required_fields.items()
            if not value or str(value).strip() == ""
        ]

        return {
            "success": True,
            "profile_complete": len(missing_fields) == 0,
            "missing_fields": missing_fields,
            "applicant_details": applicant_details,
            "applicant_address": applicant_address,
            "bank_details": bank_info,
        }


print("=" * 70)
print("✅ Service Service Updated - AUTO-CORRECTS legacy payment data")
print("   ✅ payment_status='completed' + verification='pending' → 'approved'")
print("=" * 70)