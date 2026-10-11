# app/modules/schemes/service.py
"""
Government Schemes Service

✅ All applications go to UNIFIED `applications` collection
✅ application_type = "schemes" always set
✅ Documents stored in applications.documents[] — read per-application
✅ submit_application() for final submission
✅ Handles typed SchemeApplyRequest payloads
"""

from fastapi import HTTPException, BackgroundTasks
from typing import Dict, Any, List, Optional
from datetime import datetime
import logging
import uuid

from app.modules.notification.service import central_notification

module_logger = logging.getLogger(__name__)


SCHEME_APPLICATION_TYPE = "schemes"


class SchemeService:
    """Government Schemes Service."""

    def __init__(self, db):
        self.db = db
        self.schemes = db.schemes
        self.applications = db.applications   # unified
        self.auth = db.auth
        self.profile = db.profile

    # ============================================================
    # SCHEME LISTING
    # ============================================================
    async def list_schemes(
        self,
        level: Optional[str] = None,
        state: Optional[str] = None,
        category: Optional[str] = None,
        search: Optional[str] = None,
        is_featured: Optional[bool] = None,
        limit: int = 50,
        skip: int = 0,
    ) -> Dict[str, Any]:
        try:
            query: Dict[str, Any] = {"is_active": True}
            if level and level != "all":
                query["level"] = level
            if state and state != "all":
                query["state"] = state
            if category and category != "all":
                query["category"] = category
            if is_featured is not None:
                query["is_featured"] = is_featured

            if search and search.strip():
                term = search.strip()
                query["$or"] = [
                    {"scheme_name": {"$regex": term, "$options": "i"}},
                    {"scheme_name_hindi": {"$regex": term, "$options": "i"}},
                    {"short_description": {"$regex": term, "$options": "i"}},
                    {"short_description_hindi": {"$regex": term, "$options": "i"}},
                    {"tags": {"$in": [term.lower()]}},
                    {"search_keywords": {"$in": [term.lower()]}},
                ]

            total = await self.schemes.count_documents(query)
            schemes = (
                await self.schemes.find(query)
                .sort([("priority", -1), ("created_at", -1)])
                .skip(skip)
                .limit(limit)
                .to_list(limit)
            )
            for s in schemes:
                s["_id"] = str(s["_id"])
                if isinstance(s.get("created_at"), datetime):
                    s["created_at"] = s["created_at"].isoformat()
                if isinstance(s.get("updated_at"), datetime):
                    s["updated_at"] = s["updated_at"].isoformat()

            return {
                "success": True,
                "schemes": schemes,
                "total": total,
                "skip": skip,
                "limit": limit,
            }
        except Exception as e:
            module_logger.error(f"Error listing schemes: {e}")
            raise HTTPException(status_code=500, detail=str(e))

    async def get_scheme_detail(self, scheme_id: str) -> Dict[str, Any]:
        try:
            scheme = await self.schemes.find_one(
                {"scheme_id": scheme_id, "is_active": True}
            )
            if not scheme:
                raise HTTPException(status_code=404, detail="Scheme not found")
            scheme["_id"] = str(scheme["_id"])
            if isinstance(scheme.get("created_at"), datetime):
                scheme["created_at"] = scheme["created_at"].isoformat()
            if isinstance(scheme.get("updated_at"), datetime):
                scheme["updated_at"] = scheme["updated_at"].isoformat()
            return {"success": True, "scheme": scheme}
        except HTTPException:
            raise
        except Exception as e:
            module_logger.error(f"Error getting scheme detail: {e}")
            raise HTTPException(status_code=500, detail=str(e))

    async def get_featured_schemes(self, limit: int = 10) -> List[Dict]:
        try:
            schemes = (
                await self.schemes.find(
                    {"is_active": True, "is_featured": True}
                )
                .sort("priority", -1)
                .limit(limit)
                .to_list(limit)
            )
            for s in schemes:
                s["_id"] = str(s["_id"])
            return schemes
        except Exception as e:
            module_logger.error(f"Error getting featured schemes: {e}")
            return []

    async def get_schemes_by_category(
        self, category: str, limit: int = 20
    ) -> List[Dict]:
        try:
            schemes = (
                await self.schemes.find(
                    {"is_active": True, "category": category}
                )
                .sort("priority", -1)
                .limit(limit)
                .to_list(limit)
            )
            for s in schemes:
                s["_id"] = str(s["_id"])
            return schemes
        except Exception as e:
            module_logger.error(f"Error getting schemes by category: {e}")
            return []

    async def get_states_with_schemes(self) -> List[str]:
        try:
            states = await self.schemes.distinct(
                "state",
                {
                    "is_active": True,
                    "level": "state",
                    "state": {"$ne": None},
                },
            )
            return sorted(states)
        except Exception as e:
            module_logger.error(f"Error getting states: {e}")
            return []

    # ============================================================
    # CREATE APPLICATION
    # ============================================================
    async def create_application(
        self,
        data: Dict[str, Any],
        user_email: str,
        user_id: str,
        background_tasks: BackgroundTasks = None,
    ) -> Dict[str, Any]:
        try:
            scheme_id = (data.get("scheme_id") or "").strip()
            if not scheme_id:
                raise HTTPException(
                    status_code=400, detail="scheme_id is required"
                )

            scheme = await self.schemes.find_one(
                {"scheme_id": scheme_id, "is_active": True}
            )
            if not scheme:
                raise HTTPException(
                    status_code=404, detail="Scheme not found"
                )

            scheme_name_hindi = (
                scheme.get("scheme_name_hindi") or ""
            ).strip()
            scheme_name_en = (scheme.get("scheme_name") or "").strip()
            resolved_scheme_name = (
                scheme_name_hindi or scheme_name_en or scheme_id
            )

            override_name = (data.get("scheme_name") or "").strip()
            if override_name:
                resolved_scheme_name = override_name

            # Duplicate check
            existing = await self.applications.find_one(
                {
                    "application_type": SCHEME_APPLICATION_TYPE,
                    "user_email": user_email,
                    "scheme_id": scheme_id,
                    "status": {
                        "$nin": [
                            "rejected",
                            "verification_rejected",
                            "cancelled",
                        ]
                    },
                    "is_archived": {"$ne": True},
                }
            )
            if existing:
                return {
                    "success": False,
                    "message": "You have already applied for this scheme",
                    "application_id": str(
                        existing.get("application_id") or existing["_id"]
                    ),
                    "status": existing.get("status", "pending"),
                }

            profile = await self.profile.find_one({"email": user_email})
            user_name = (
                profile.get("full_name")
                if profile
                else user_email.split("@")[0]
            )
            user_mobile = profile.get("phone") if profile else None

            application_id = str(uuid.uuid4())
            now = datetime.utcnow()

            # Normalize documents
            incoming_docs = data.get("documents") or []
            normalized_docs: List[Dict[str, Any]] = []
            for d in incoming_docs:
                if not isinstance(d, dict):
                    continue
                doc_url = (
                    d.get("document_url") or d.get("url") or ""
                ).strip()
                if not doc_url:
                    continue
                normalized_docs.append(
                    {
                        "document_type": (
                            d.get("document_type") or ""
                        ).strip(),
                        "document_name": (
                            d.get("document_name")
                            or d.get("label")
                            or ""
                        ).strip(),
                        "document_url": doc_url,
                        "public_id": d.get("public_id"),
                        "uploaded_at": now,
                        "verified": False,
                    }
                )

            application_doc: Dict[str, Any] = {
                "application_id": application_id,
                "application_type": SCHEME_APPLICATION_TYPE,
                "user_email": user_email,
                "user_id": user_id,
                "user_name": user_name,
                "user_mobile": user_mobile,
                "scheme_id": scheme_id,
                "scheme_name": resolved_scheme_name,
                "scheme_name_hindi": scheme_name_hindi,
                "scheme_level": scheme.get("level", "central"),
                "scheme_state": scheme.get("state"),
                "scheme_category": scheme.get("category", "other"),
                "applicant_details": data.get("applicant_details", {}) or {},
                "applicant_address": data.get("applicant_address", {}) or {},
                "bank_details": data.get("bank_details") or {},
                "documents": normalized_docs,
                "additional_info": data.get("additional_info"),
                "remarks": data.get("remarks"),
                "status": "pending",
                "payment_verification_status": "not_submitted",
                "payment_amount": scheme.get("application_fee", 0),
                "payment_method": "razorpay",
                "is_archived": False,
                "created_at": now,
                "updated_at": now,
                "applied_at": now,
            }

            await self.applications.insert_one(application_doc)

            module_logger.info(
                f"✅ Scheme application created: {application_id} | "
                f"type={SCHEME_APPLICATION_TYPE}"
            )

            if background_tasks:
                background_tasks.add_task(
                    self._send_application_notification,
                    user_email,
                    user_name,
                    resolved_scheme_name,
                    application_id,
                )
            else:
                try:
                    await self._send_application_notification(
                        user_email,
                        user_name,
                        resolved_scheme_name,
                        application_id,
                    )
                except Exception as e:
                    module_logger.warning(
                        f"Notification send failed: {e}"
                    )

            return {
                "success": True,
                "application_id": application_id,
                "application_type": SCHEME_APPLICATION_TYPE,
                "message": "Application submitted successfully",
                "status": "pending",
            }
        except HTTPException:
            raise
        except Exception as e:
            module_logger.error(
                f"Error creating scheme application: {e}"
            )
            raise HTTPException(status_code=500, detail=str(e))

    # ============================================================
    # SUBMIT APPLICATION (FINAL SUBMIT)
    # ============================================================
    async def submit_application(
        self,
        application_id: str,
        user_email: str,
        additional_data: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        try:
            application = await self.applications.find_one(
                {
                    "application_type": SCHEME_APPLICATION_TYPE,
                    "application_id": application_id,
                    "user_email": user_email,
                }
            )

            if not application:
                raise HTTPException(
                    status_code=404, detail="Application not found"
                )

            current_status = application.get("status", "")
            if current_status in [
                "submitted",
                "under_review",
                "approved",
                "completed",
            ]:
                return {
                    "success": True,
                    "message": f"Application already {current_status}",
                    "application_id": application_id,
                    "status": current_status,
                }

            now = datetime.utcnow()

            update_data: Dict[str, Any] = {
                "status": "submitted",
                "submitted_at": now,
                "updated_at": now,
            }

            if additional_data:
                if additional_data.get("remarks"):
                    update_data["remarks"] = additional_data["remarks"]
                if additional_data.get("additional_info"):
                    update_data["additional_info"] = additional_data[
                        "additional_info"
                    ]

            await self.applications.update_one(
                {"application_id": application_id},
                {"$set": update_data},
            )

            module_logger.info(
                f"✅ Application {application_id} submitted successfully"
            )

            scheme_name = (
                application.get("scheme_name")
                or application.get("scheme_name_hindi")
                or "Scheme"
            )
            user_name = application.get("user_name", "User")

            try:
                await central_notification.send_notification(
                    user_ids=[user_email],
                    notification_type="application_status",
                    title=f"✅ Application Submitted: {scheme_name}",
                    message=(
                        f"Dear {user_name}, your application for "
                        f"'{scheme_name}' has been submitted "
                        f"successfully. Application ID: {application_id}"
                    ),
                    related_id=application_id,
                    metadata={
                        "application_id": application_id,
                        "scheme_name": scheme_name,
                        "status": "submitted",
                    },
                    send_email=True,
                    send_websocket=True,
                )
            except Exception as ne:
                module_logger.warning(f"Notification failed: {ne}")

            return {
                "success": True,
                "message": "Application submitted successfully",
                "application_id": application_id,
                "status": "submitted",
                "submitted_at": now.isoformat(),
            }

        except HTTPException:
            raise
        except Exception as e:
            module_logger.error(f"Error submitting application: {e}")
            raise HTTPException(status_code=500, detail=str(e))

    # ============================================================
    # UPLOAD A DOCUMENT
    # ============================================================
    async def upload_document(
        self,
        application_id: str,
        user_email: str,
        document_type: str,
        document_name: str,
        document_url: str,
        public_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        try:
            if not document_url or not document_url.strip():
                raise HTTPException(
                    status_code=400,
                    detail="document_url is required",
                )

            application = await self.applications.find_one(
                {
                    "application_type": SCHEME_APPLICATION_TYPE,
                    "application_id": application_id,
                    "user_email": user_email,
                }
            )
            if not application:
                raise HTTPException(
                    status_code=404, detail="Application not found"
                )

            doc = {
                "document_type": (document_type or "").strip(),
                "document_name": (document_name or "").strip(),
                "document_url": document_url.strip(),
                "public_id": public_id,
                "uploaded_at": datetime.utcnow(),
                "verified": False,
            }

            # Replace existing doc of same type
            await self.applications.update_one(
                {"application_id": application_id},
                {
                    "$pull": {
                        "documents": {
                            "document_type": doc["document_type"]
                        }
                    }
                },
            )

            # Push new doc
            await self.applications.update_one(
                {"application_id": application_id},
                {
                    "$push": {"documents": doc},
                    "$set": {"updated_at": datetime.utcnow()},
                },
            )

            module_logger.info(
                f"📄 Uploaded doc '{doc['document_name']}' → "
                f"application {application_id}"
            )

            return {
                "success": True,
                "message": "Document uploaded successfully",
                "document": doc,
            }
        except HTTPException:
            raise
        except Exception as e:
            module_logger.error(f"Error uploading document: {e}")
            raise HTTPException(status_code=500, detail=str(e))

    # ============================================================
    # GET USER APPLICATIONS
    # ============================================================
    async def get_user_applications(
        self,
        user_email: str,
        status: Optional[str] = None,
    ) -> Dict[str, Any]:
        try:
            query: Dict[str, Any] = {
                "application_type": SCHEME_APPLICATION_TYPE,
                "user_email": user_email,
                "is_archived": {"$ne": True},
            }
            if status and status != "all":
                query["status"] = status

            applications = (
                await self.applications.find(query)
                .sort("created_at", -1)
                .to_list(100)
            )

            for app in applications:
                app["_id"] = str(app["_id"])
                if isinstance(app.get("created_at"), datetime):
                    app["created_at"] = app["created_at"].isoformat()
                if isinstance(app.get("updated_at"), datetime):
                    app["updated_at"] = app["updated_at"].isoformat()
                if isinstance(app.get("applied_at"), datetime):
                    app["applied_at"] = app["applied_at"].isoformat()
                if isinstance(app.get("submitted_at"), datetime):
                    app["submitted_at"] = app["submitted_at"].isoformat()

                docs = app.get("documents")
                normalized = []
                if isinstance(docs, list):
                    for d in docs:
                        if not isinstance(d, dict):
                            continue
                        url = (d.get("document_url") or "").strip()
                        if not url or url.lower() in (
                            "null",
                            "undefined",
                            "",
                        ):
                            continue
                        normalized.append(
                            {
                                "document_type": d.get("document_type"),
                                "document_name": d.get("document_name"),
                                "document_url": url,
                                "public_id": d.get("public_id"),
                                "uploaded_at": (
                                    d["uploaded_at"].isoformat()
                                    if isinstance(
                                        d.get("uploaded_at"), datetime
                                    )
                                    else d.get("uploaded_at")
                                ),
                                "verified": d.get("verified", False),
                            }
                        )
                app["documents"] = normalized

            return {
                "success": True,
                "applications": applications,
                "total": len(applications),
            }
        except Exception as e:
            module_logger.error(
                f"Error getting user applications: {e}"
            )
            raise HTTPException(status_code=500, detail=str(e))

    async def get_application_detail(
        self, application_id: str, user_email: str
    ) -> Dict[str, Any]:
        try:
            application = await self.applications.find_one(
                {
                    "application_type": SCHEME_APPLICATION_TYPE,
                    "application_id": application_id,
                    "user_email": user_email,
                }
            )
            if not application:
                raise HTTPException(
                    status_code=404, detail="Application not found"
                )
            application["_id"] = str(application["_id"])

            # Normalize dates
            for field in [
                "created_at",
                "updated_at",
                "applied_at",
                "submitted_at",
                "reviewed_at",
            ]:
                if isinstance(application.get(field), datetime):
                    application[field] = application[field].isoformat()

            scheme = await self.schemes.find_one(
                {"scheme_id": application.get("scheme_id")}
            )
            if scheme:
                scheme["_id"] = str(scheme["_id"])

            return {
                "success": True,
                "application": application,
                "scheme": scheme,
            }
        except HTTPException:
            raise
        except Exception as e:
            module_logger.error(
                f"Error getting application detail: {e}"
            )
            raise HTTPException(status_code=500, detail=str(e))

    # ============================================================
    # ADMIN OPERATIONS
    # ============================================================
    async def get_all_applications(
        self,
        admin_email: str,
        status: Optional[str] = None,
        scheme_id: Optional[str] = None,
        limit: int = 100,
        skip: int = 0,
    ) -> Dict[str, Any]:
        try:
            admin = await self.auth.find_one({"email": admin_email})
            if not admin or admin.get("role") not in (
                "admin",
                "customadmin",
                "superadmin",
            ):
                raise HTTPException(
                    status_code=403, detail="Access denied"
                )

            query: Dict[str, Any] = {
                "application_type": SCHEME_APPLICATION_TYPE,
                "is_archived": {"$ne": True},
            }
            if status and status != "all":
                query["status"] = status
            if scheme_id:
                query["scheme_id"] = scheme_id

            total = await self.applications.count_documents(query)
            apps = (
                await self.applications.find(query)
                .sort("created_at", -1)
                .skip(skip)
                .limit(limit)
                .to_list(limit)
            )
            for app in apps:
                app["_id"] = str(app["_id"])
                if isinstance(app.get("created_at"), datetime):
                    app["created_at"] = app["created_at"].isoformat()
                if isinstance(app.get("updated_at"), datetime):
                    app["updated_at"] = app["updated_at"].isoformat()
                if isinstance(app.get("applied_at"), datetime):
                    app["applied_at"] = app["applied_at"].isoformat()

            return {
                "success": True,
                "applications": apps,
                "total": total,
            }
        except HTTPException:
            raise
        except Exception as e:
            module_logger.error(
                f"Error getting all applications: {e}"
            )
            raise HTTPException(status_code=500, detail=str(e))

    async def update_application_status(
        self,
        application_id: str,
        status: str,
        admin_email: str,
        notes: Optional[str] = None,
    ) -> Dict[str, Any]:
        try:
            admin = await self.auth.find_one({"email": admin_email})
            if not admin or admin.get("role") not in (
                "admin",
                "customadmin",
                "superadmin",
            ):
                raise HTTPException(
                    status_code=403, detail="Access denied"
                )

            application = await self.applications.find_one(
                {
                    "application_type": SCHEME_APPLICATION_TYPE,
                    "application_id": application_id,
                }
            )
            if not application:
                raise HTTPException(
                    status_code=404, detail="Application not found"
                )

            now = datetime.utcnow()
            update_data: Dict[str, Any] = {
                "status": status,
                "updated_at": now,
                "reviewed_by": admin_email,
                "reviewed_at": now,
            }
            if notes:
                update_data["admin_notes"] = notes

            await self.applications.update_one(
                {"application_id": application_id},
                {"$set": update_data},
            )

            user_email = application.get("user_email")
            scheme_name = (
                application.get("scheme_name")
                or application.get("scheme_name_hindi")
                or "Scheme"
            )

            try:
                await central_notification.send_notification(
                    user_ids=[user_email],
                    notification_type="application_status",
                    title=(
                        f"Scheme Application Update: {scheme_name}"
                    ),
                    message=(
                        f"Your application for '{scheme_name}' "
                        f"has been updated to: {status.upper()}"
                    ),
                    related_id=application_id,
                    metadata={
                        "application_id": application_id,
                        "scheme_name": scheme_name,
                        "status": status,
                        "admin_notes": notes,
                    },
                    send_email=True,
                    send_websocket=True,
                )
            except Exception as ne:
                module_logger.warning(f"Notification failed: {ne}")

            return {
                "success": True,
                "message": f"Application status updated to {status}",
                "application_id": application_id,
            }
        except HTTPException:
            raise
        except Exception as e:
            module_logger.error(
                f"Error updating application status: {e}"
            )
            raise HTTPException(status_code=500, detail=str(e))

    # ============================================================
    # HELPERS
    # ============================================================
    async def _send_application_notification(
        self,
        user_email: str,
        user_name: str,
        scheme_name: str,
        application_id: str,
    ):
        try:
            await central_notification.send_notification(
                user_ids=[user_email],
                notification_type="application_status",
                title=(
                    f"✅ Scheme Application Submitted: {scheme_name}"
                ),
                message=(
                    f"Dear {user_name}, your application for "
                    f"'{scheme_name}' has been submitted successfully. "
                    f"Application ID: {application_id}"
                ),
                related_id=application_id,
                metadata={
                    "application_id": application_id,
                    "scheme_name": scheme_name,
                    "status": "pending",
                },
                send_email=True,
                send_websocket=True,
            )
        except Exception as e:
            module_logger.error(
                f"Error sending notification: {e}"
            )

    async def seed_schemes(self) -> Dict[str, Any]:
        try:
            count = await self.schemes.count_documents({})
            if count > 0:
                return {
                    "success": True,
                    "message": f"Schemes already seeded ({count} exist)",
                    "seeded": 0,
                }
            return {
                "success": True,
                "message": "Schemes seeding not implemented",
                "seeded": 0,
            }
        except Exception as e:
            module_logger.error(f"Error seeding schemes: {e}")
            return {"success": False, "error": str(e)}


print("✅ Scheme Service Loaded Successfully (TYPED + DOCS + SUBMIT)")