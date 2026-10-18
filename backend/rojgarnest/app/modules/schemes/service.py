# app/modules/schemes/service.py
"""
Government Schemes Service

✅ CRITICAL FIX: application_id now stores the APPLICATION NUMBER (YYYYMMSSSSS)
✅ CRITICAL FIX: Documents are stored in `scheme_documents[]` (not `documents[]`)
✅ CRITICAL FIX: Every document entry gets source="schemes_application"
✅ Mirrors the service module pattern EXACTLY for perfect parity
"""

from fastapi import HTTPException, BackgroundTasks
from typing import Dict, Any, List, Optional
from datetime import datetime
import logging

from app.modules.notification.service import central_notification

from app.core.utils.application_number_generator import (
    ApplicationNumberGenerator,
    application_number_generator,
)

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
    # ✅ UNIVERSAL DOCUMENT NORMALIZER
    # ------------------------------------------------------------
    # Forces source="schemes_application"
    # Aligns field names with service_documents format EXACTLY
    # ============================================================
    def _normalize_document_item(self, doc: Any, index: int = 0) -> Optional[Dict[str, Any]]:
        """
        Normalize a single document entry.
        Returns None if no valid URL is found.

        Output shape (mirrors service_documents):
        {
            "document_type": "...",
            "label": "...",
            "url": "https://...",
            "download_url": "https://...",
            "public_id": "...",
            "resource_type": "raw" | "image" | "auto",
            "file_name": "...",
            "file_size": 0,
            "is_pdf": bool,
            "is_image": bool,
            "source": "schemes_application",   ← FORCED
            "uploaded_at": ISO,
            "uploaded_by": "..." | None,
        }
        """
        if doc is None:
            return None

        # ---------- Case 1: doc is a plain string URL ----------
        if isinstance(doc, str):
            url = doc.strip()
            if not url or not (url.startswith("http://") or url.startswith("https://")):
                return None
            module_logger.info(f"📎 Doc[{index}] plain string URL: {url[:80]}")
            return {
                "document_type": f"document_{index + 1}",
                "label": f"Document {index + 1}",
                "url": url,
                "download_url": url,
                "public_id": None,
                "resource_type": "auto",
                "file_name": f"Document {index + 1}",
                "file_size": 0,
                "is_pdf": False,
                "is_image": False,
                "source": "schemes_application",
                "uploaded_at": datetime.utcnow().isoformat(),
                "uploaded_by": None,
            }

        # ---------- Case 2: doc is not a dict ----------
        if not isinstance(doc, dict):
            return None

        # ---------- Case 3: doc is a dict → extract URL ----------
        url_candidates = [
            doc.get("document_url"),
            doc.get("url"),
            doc.get("documentUrl"),
            doc.get("file_url"),
            doc.get("fileUrl"),
            doc.get("link"),
            doc.get("href"),
            doc.get("cloudinary_url"),
            doc.get("secure_url"),
        ]

        final_url = ""
        for candidate in url_candidates:
            if candidate is None:
                continue
            s = str(candidate).strip()
            if s and s.lower() not in ("null", "undefined", "none", "n/a", ""):
                final_url = s
                break

        if not final_url:
            module_logger.warning(
                f"⚠️ Doc[{index}] SKIPPED — no valid URL. Keys: {list(doc.keys())}"
            )
            return None

        # ---------- Extract name ----------
        name_candidates = [
            doc.get("document_name"),
            doc.get("label"),
            doc.get("name"),
            doc.get("title"),
            doc.get("original_filename"),
            doc.get("filename"),
            doc.get("file_name"),
        ]
        final_name = ""
        for candidate in name_candidates:
            if candidate:
                s = str(candidate).strip()
                if s:
                    final_name = s
                    break

        # ---------- Extract type ----------
        type_candidates = [
            doc.get("document_type"),
            doc.get("type"),
            doc.get("doc_type"),
            doc.get("category"),
        ]
        final_type = ""
        for candidate in type_candidates:
            if candidate:
                s = str(candidate).strip()
                if s:
                    final_type = s
                    break

        if not final_name:
            final_name = (
                final_type.replace("_", " ").title()
                if final_type
                else f"Document {index + 1}"
            )
        if not final_type:
            final_type = f"document_{index + 1}"

        # ---------- Extract metadata ----------
        download_url = doc.get("download_url") or final_url
        public_id = doc.get("public_id") or doc.get("publicId")
        resource_type = doc.get("resource_type") or doc.get("resourceType") or "auto"
        file_size = doc.get("file_size") or doc.get("size_bytes") or 0
        is_pdf = bool(doc.get("is_pdf", False))
        is_image = bool(doc.get("is_image", False))

        uploaded_at = doc.get("uploaded_at") or datetime.utcnow().isoformat()
        uploaded_by = doc.get("uploaded_by")

        module_logger.info(
            f"📎 Doc[{index}] NORMALIZED → "
            f"type={final_type}, name={final_name}, url={final_url[:80]}"
        )

        return {
            "document_type": final_type,
            "label": final_name,
            "url": final_url,
            "download_url": download_url,
            "public_id": public_id,
            "resource_type": resource_type,
            "file_name": final_name,
            "file_size": file_size,
            "is_pdf": is_pdf,
            "is_image": is_image,
            "source": "schemes_application",   # ✅ FORCED TAG
            "uploaded_at": uploaded_at,
            "uploaded_by": uploaded_by,
        }

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

            module_logger.info(
                f"📋 list_schemes → returned {len(schemes)} of {total} "
                f"(query={query})"
            )

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
                scheme = await self.schemes.find_one(
                    {
                        "scheme_id": {"$regex": f"^{scheme_id}$", "$options": "i"},
                        "is_active": True,
                    }
                )
            if not scheme:
                try:
                    from bson import ObjectId
                    if ObjectId.is_valid(scheme_id):
                        scheme = await self.schemes.find_one(
                            {"_id": ObjectId(scheme_id), "is_active": True}
                        )
                except Exception:
                    pass

            if not scheme:
                module_logger.warning(f"Scheme not found: {scheme_id}")
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
            return sorted([s for s in states if s])
        except Exception as e:
            module_logger.error(f"Error getting states: {e}")
            return []

    # ============================================================
    # ✅ CREATE APPLICATION
    # ------------------------------------------------------------
    # ✅ CRITICAL FIX: application_id = APPLICATION NUMBER (YYYYMMSSSSS)
    # ✅ CRITICAL FIX: documents → scheme_documents[]
    # ✅ CRITICAL FIX: every doc gets source="schemes_application"
    # ============================================================
    async def create_application(
        self,
        data: Dict[str, Any],
        user_email: str,
        user_id: str,
        background_tasks: BackgroundTasks = None,
    ) -> Dict[str, Any]:
        """
        Submit a scheme application.

        ✅ AUTO-FILL: If applicant_details/address/bank_details are missing,
        they are automatically fetched from the user's profile.

        ✅ CRITICAL FIX: application_id = APPLICATION NUMBER (YYYYMMSSSSS)
        ✅ CRITICAL FIX: Documents are stored in `scheme_documents[]`
        ✅ CRITICAL FIX: Every doc gets `source: "schemes_application"`
        """
        try:
            scheme_id = (data.get("scheme_id") or "").strip()
            if not scheme_id:
                raise HTTPException(
                    status_code=400, detail="scheme_id is required"
                )

            # ---------- Lookup scheme ----------
            total_in_db = await self.schemes.count_documents({})
            module_logger.info("=" * 70)
            module_logger.info(f"🔍 SCHEME APPLICATION LOOKUP")
            module_logger.info(f"   Requested scheme_id: '{scheme_id}'")
            module_logger.info(f"   Total schemes in DB:  {total_in_db}")

            if total_in_db == 0:
                module_logger.error("❌ SCHEMES COLLECTION IS EMPTY!")
                raise HTTPException(
                    status_code=500,
                    detail=(
                        "Schemes collection is empty. "
                        "Please run: python seed_schemes.py"
                    ),
                )

            scheme = await self.schemes.find_one(
                {"scheme_id": scheme_id, "is_active": True}
            )

            if not scheme:
                scheme = await self.schemes.find_one(
                    {
                        "scheme_id": {
                            "$regex": f"^{scheme_id}$",
                            "$options": "i",
                        },
                        "is_active": True,
                    }
                )

            if not scheme:
                try:
                    from bson import ObjectId
                    if ObjectId.is_valid(scheme_id):
                        scheme = await self.schemes.find_one(
                            {"_id": ObjectId(scheme_id), "is_active": True}
                        )
                except Exception:
                    pass

            if not scheme:
                all_ids = await self.schemes.distinct("scheme_id")
                module_logger.error(f"❌ Scheme '{scheme_id}' NOT FOUND!")
                raise HTTPException(
                    status_code=404,
                    detail=(
                        f"Scheme '{scheme_id}' not found. "
                        f"Available: {all_ids[:10]}"
                    ),
                )

            module_logger.info(
                f"✅ Found scheme: {scheme.get('scheme_name')}"
            )
            module_logger.info("=" * 70)

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

            # ---------- Duplicate check ----------
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
                module_logger.info(
                    f"📋 Existing application found: "
                    f"application_id={existing.get('application_id')}"
                )
                return {
                    "success": True,
                    "message": "You have already applied for this scheme",
                    "application_id": existing.get("application_id"),
                    "application_number": existing.get("application_id"),
                    "status": existing.get("status", "pending"),
                    "already_exists": True,
                }

            # ============================================================
            # ✅ GENERATE APPLICATION NUMBER (WILL BE USED AS application_id)
            # ============================================================
            try:
                application_number = await ApplicationNumberGenerator.generate_application_number(self.db)
                module_logger.info("=" * 70)
                module_logger.info(f"🎫 APPLICATION NUMBER GENERATED: {application_number}")
                module_logger.info(f"   Format: YYYYMMSSSSS")
                module_logger.info(f"   Year: {application_number[:4]}")
                module_logger.info(f"   Month: {application_number[4:6]}")
                module_logger.info(f"   Sequence: {application_number[6:]}")
                module_logger.info("=" * 70)
            except Exception as e:
                module_logger.error(f"❌ Failed to generate application number: {e}")
                from datetime import datetime as dt
                now = dt.utcnow()
                fallback_seq = int(now.timestamp()) % 100000
                application_number = f"{now.year}{now.month:02d}{fallback_seq:05d}"
                module_logger.warning(f"⚠️ Using fallback application number: {application_number}")

            # ============================================================
            # ✅ AUTO-FILL FROM PROFILE
            # ============================================================
            profile = await self.profile.find_one({"email": user_email})
            auth_user = await self.auth.find_one({"email": user_email})

            user_name = (
                profile.get("full_name")
                if profile
                else user_email.split("@")[0]
            )
            user_mobile = auth_user.get("mobile") if auth_user else None

            provided_details = data.get("applicant_details", {}) or {}
            provided_address = data.get("applicant_address", {}) or {}
            provided_bank = data.get("bank_details", {}) or {}

            # --- Build complete applicant details ---
            disability = (profile.get("disability", {}) or {}) if profile else {}
            gov_ids = (profile.get("government_ids", {}) or {}) if profile else {}

            applicant_details = {
                "full_name": (
                    provided_details.get("full_name") or
                    (profile.get("full_name") if profile else "") or
                    (auth_user.get("name") if auth_user else "")
                ),
                "father_name": (
                    provided_details.get("father_name") or
                    (profile.get("father_name") if profile else "")
                ),
                "mother_name": (
                    provided_details.get("mother_name") or
                    (profile.get("mother_name") if profile else "")
                ),
                "date_of_birth": (
                    provided_details.get("date_of_birth") or
                    (profile.get("dob") if profile else "")
                ),
                "gender": (
                    provided_details.get("gender") or
                    (profile.get("gender") if profile else "male")
                ),
                "category": (
                    provided_details.get("category") or
                    (profile.get("category") if profile else "General")
                ),
                "marital_status": (
                    provided_details.get("marital_status") or
                    (profile.get("marital_status") if profile else "Unmarried")
                ),
                "aadhaar_number": (
                    provided_details.get("aadhaar_number") or
                    gov_ids.get("aadhar_number", "")
                ),
                "mobile": (
                    provided_details.get("mobile") or
                    (auth_user.get("mobile") if auth_user else "") or
                    (profile.get("phone") if profile else "")
                ),
                "email": (
                    provided_details.get("email") or
                    user_email
                ),
                "annual_income": (
                    provided_details.get("annual_income") or
                    (profile.get("family_annual_income", 0) if profile else 0)
                ),
                "bpl_status": (
                    provided_details.get("bpl_status") or
                    (profile.get("bpl_status", False) if profile else False)
                ),
                "disability_status": (
                    provided_details.get("disability_status") or
                    disability.get("is_disabled", False)
                ),
                "disability_percentage": (
                    provided_details.get("disability_percentage") or
                    disability.get("disability_percentage", 0.0)
                ),
                "scheme_name": resolved_scheme_name,
                "scheme_id": scheme_id,
                "application_type": SCHEME_APPLICATION_TYPE,
            }

            # --- Build complete address ---
            current_address = (
                (profile.get("current_address", {}) or {}) if profile else {}
            )

            applicant_address = {
                "address_line1": (
                    provided_address.get("address_line1") or
                    current_address.get("house_number") or
                    current_address.get("address_line1") or
                    ""
                ),
                "address_line2": (
                    provided_address.get("address_line2") or
                    current_address.get("landmark") or
                    current_address.get("address_line2") or
                    ""
                ),
                "village_city": (
                    provided_address.get("village_city") or
                    current_address.get("village_name") or
                    current_address.get("city") or
                    ""
                ),
                "district": (
                    provided_address.get("district") or
                    current_address.get("district") or
                    ""
                ),
                "state": (
                    provided_address.get("state") or
                    current_address.get("state") or
                    ""
                ),
                "pincode": (
                    provided_address.get("pincode") or
                    current_address.get("pincode") or
                    current_address.get("zipcode") or
                    ""
                ),
                "country": (
                    provided_address.get("country") or
                    current_address.get("country") or
                    "India"
                ),
            }

            # --- Build complete bank details ---
            profile_bank = (
                (profile.get("bank_details", {}) or {}) if profile else {}
            )

            bank_details = {
                "account_holder_name": (
                    provided_bank.get("account_holder_name") or
                    profile_bank.get("account_holder_name") or
                    ""
                ),
                "bank_name": (
                    provided_bank.get("bank_name") or
                    profile_bank.get("bank_name") or
                    ""
                ),
                "account_number": (
                    provided_bank.get("account_number") or
                    profile_bank.get("account_number") or
                    ""
                ),
                "ifsc_code": (
                    provided_bank.get("ifsc_code") or
                    profile_bank.get("ifsc_code") or
                    ""
                ),
                "branch_name": (
                    provided_bank.get("branch_name") or
                    profile_bank.get("branch_name") or
                    ""
                ),
                "account_type": (
                    provided_bank.get("account_type") or
                    profile_bank.get("account_type") or
                    "savings"
                ),
            }

            # ============================================================
            # ✅ NORMALIZE DOCUMENTS → SCHEME_DOCUMENTS
            # ============================================================
            now = datetime.utcnow()

            incoming_docs = data.get("documents") or []
            module_logger.info("=" * 70)
            module_logger.info(
                f"📎 PROCESSING {len(incoming_docs)} INCOMING DOCUMENT(S)"
            )
            for i, d in enumerate(incoming_docs):
                module_logger.info(f"   [{i}] {d}")
            module_logger.info("=" * 70)

            normalized_docs: List[Dict[str, Any]] = []
            for idx, d in enumerate(incoming_docs):
                normalized = self._normalize_document_item(d, idx)
                if normalized:
                    # ✅ Tag uploader
                    if normalized.get("uploaded_by") is None:
                        normalized["uploaded_by"] = user_email
                    normalized_docs.append(normalized)

            module_logger.info(
                f"📎 NORMALIZED {len(normalized_docs)} document(s) "
                f"out of {len(incoming_docs)} incoming"
            )
            for i, doc in enumerate(normalized_docs):
                module_logger.info(
                    f"   [{i}] {doc['document_type']} → "
                    f"{doc['url'][:80]}"
                )

            # ============================================================
            # ✅ BUILD APPLICATION DOCUMENT
            # ------------------------------------------------------------
            # ✅ application_id  = APPLICATION NUMBER (YYYYMMSSSSS)
            # ✅ scheme_documents = normalized_docs
            # ✅ documents       = [] (legacy, empty)
            # ============================================================
            application_doc: Dict[str, Any] = {
                "application_id": application_number,
                "application_type": SCHEME_APPLICATION_TYPE,
                "user_email": user_email,
                "user_id": user_id,
                "user_name": user_name,
                "user_mobile": user_mobile,
                "application_username": user_email.split("@")[0],

                # Scheme info
                "scheme_id": scheme_id,
                "scheme_name": resolved_scheme_name,
                "scheme_name_hindi": scheme_name_hindi,
                "scheme_level": scheme.get("level", "central"),
                "scheme_state": scheme.get("state"),
                "scheme_category": scheme.get("category", "other"),

                # Applicant info
                "applicant_details": applicant_details,
                "applicant_address": applicant_address,
                "bank_details": bank_details,

                # ✅ Documents — stored in dedicated array with source tag
                "scheme_documents": normalized_docs,
                "documents": [],  # legacy field — kept empty

                # Additional info
                "additional_info": data.get("additional_info"),
                "remarks": data.get("remarks"),

                # Status
                "status": "pending",
                "payment_verification_status": "not_submitted",
                "payment_amount": scheme.get("application_fee", 0),
                "payment_method": "razorpay",
                "is_archived": False,

                # Timestamps
                "created_at": now,
                "updated_at": now,
                "applied_at": now,
            }

            module_logger.info("=" * 70)
            module_logger.info(f"💾 INSERTING SCHEME APPLICATION")
            module_logger.info(f"   application_id (= application_number): {application_number}")
            module_logger.info(f"   scheme_documents: {len(normalized_docs)} doc(s)")
            module_logger.info("=" * 70)

            await self.applications.insert_one(application_doc)

            # ---------- Verify saved ----------
            saved = await self.applications.find_one(
                {"application_id": application_number}
            )
            if saved:
                saved_docs = saved.get("scheme_documents", [])
                module_logger.info(
                    f"✅ VERIFIED: Application saved with "
                    f"application_id={application_number}, "
                    f"{len(saved_docs)} document(s) in scheme_documents[]"
                )

            # ---------- Notification ----------
            if background_tasks:
                background_tasks.add_task(
                    self._send_application_notification,
                    user_email,
                    user_name,
                    resolved_scheme_name,
                    application_number,
                )
            else:
                try:
                    await self._send_application_notification(
                        user_email,
                        user_name,
                        resolved_scheme_name,
                        application_number,
                    )
                except Exception as e:
                    module_logger.warning(
                        f"Notification send failed: {e}"
                    )

            return {
                "success": True,
                "application_id": application_number,
                "application_number": application_number,
                "application_type": SCHEME_APPLICATION_TYPE,
                "message": "Application submitted successfully",
                "status": "pending",
                "documents_saved": len(normalized_docs),
            }
        except HTTPException:
            raise
        except Exception as e:
            module_logger.error(
                f"Error creating scheme application: {e}"
            )
            import traceback
            traceback.print_exc()
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
    # ✅ UPLOAD A DOCUMENT (per application)
    # ------------------------------------------------------------
    # Mirrors the service upload endpoint exactly.
    # Appends to scheme_documents[] with source="schemes_application".
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

            doc_type_safe = (document_type or "").strip() or f"document_{int(datetime.utcnow().timestamp())}"

            doc = {
                "document_type": doc_type_safe,
                "label": (document_name or "").strip() or doc_type_safe.replace("_", " ").title(),
                "url": document_url.strip(),
                "download_url": document_url.strip(),
                "public_id": public_id,
                "resource_type": "auto",
                "file_name": (document_name or "").strip() or doc_type_safe,
                "file_size": 0,
                "is_pdf": bool(document_url.lower().endswith(".pdf")),
                "is_image": bool(
                    any(document_url.lower().endswith(ext)
                        for ext in (".jpg", ".jpeg", ".png", ".webp", ".gif"))
                ),
                "source": "schemes_application",   # ✅ FORCED
                "uploaded_at": datetime.utcnow().isoformat(),
                "uploaded_by": user_email,
            }

            # Replace existing doc of same type (idempotent)
            await self.applications.update_one(
                {"application_id": application_id},
                {"$pull": {"scheme_documents": {"document_type": doc_type_safe}}},
            )

            # Push new doc
            await self.applications.update_one(
                {"application_id": application_id},
                {
                    "$push": {"scheme_documents": doc},
                    "$set": {"updated_at": datetime.utcnow()},
                },
            )

            module_logger.info(
                f"📄 Uploaded doc '{doc['label']}' → "
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
    # ✅ DELETE A DOCUMENT (per application)
    # ============================================================
    async def delete_document(
        self,
        application_id: str,
        user_email: str,
        document_type: str,
    ) -> Dict[str, Any]:
        try:
            result = await self.applications.update_one(
                {
                    "application_id": application_id,
                    "application_type": SCHEME_APPLICATION_TYPE,
                    "user_email": user_email,
                },
                {
                    "$pull": {"scheme_documents": {"document_type": document_type}},
                    "$set": {"updated_at": datetime.utcnow()},
                },
            )

            return {
                "success": result.modified_count > 0,
                "message": "Document removed" if result.modified_count > 0 else "Not found",
            }
        except Exception as e:
            module_logger.error(f"Error deleting document: {e}")
            raise HTTPException(status_code=500, detail=str(e))

    # ============================================================
    # GET USER APPLICATIONS
    # ------------------------------------------------------------
    # ✅ Returns scheme_documents[] (normalized + source tag)
    # ✅ Drops legacy `documents` to prevent double-render on frontend
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

                # ✅ Ensure application_number
                if "application_number" not in app or not app["application_number"]:
                    app["application_number"] = app.get("application_id")

                # ✅ Normalize scheme_documents
                docs = app.get("scheme_documents") or []
                normalized = []
                if isinstance(docs, list):
                    for d in docs:
                        if not isinstance(d, dict):
                            continue
                        url = (
                            d.get("url")
                            or d.get("document_url")
                            or ""
                        ).strip()
                        if not url or url.lower() in ("null", "undefined", ""):
                            continue
                        normalized.append({
                            "document_type": d.get("document_type"),
                            "label": d.get("label") or d.get("document_name"),
                            "url": url,
                            "download_url": d.get("download_url") or url,
                            "public_id": d.get("public_id"),
                            "resource_type": d.get("resource_type", "auto"),
                            "file_name": d.get("file_name"),
                            "file_size": d.get("file_size", 0),
                            "is_pdf": d.get("is_pdf", False),
                            "is_image": d.get("is_image", False),
                            "source": d.get("source", "schemes_application"),
                            "uploaded_at": (
                                d["uploaded_at"].isoformat()
                                if isinstance(d.get("uploaded_at"), datetime)
                                else d.get("uploaded_at")
                            ),
                            "uploaded_by": d.get("uploaded_by"),
                        })
                app["scheme_documents"] = normalized

                # ✅ Drop legacy documents array (frontend reads scheme_documents)
                app.pop("documents", None)

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

            # ✅ Ensure application_number
            if "application_number" not in application or not application["application_number"]:
                application["application_number"] = application.get("application_id")

            # ✅ Serialize timestamps
            for field in [
                "created_at",
                "updated_at",
                "applied_at",
                "submitted_at",
                "reviewed_at",
            ]:
                if isinstance(application.get(field), datetime):
                    application[field] = application[field].isoformat()

            # ✅ Normalize scheme_documents
            docs = application.get("scheme_documents") or []
            normalized = []
            for d in docs:
                if not isinstance(d, dict):
                    continue
                url = (d.get("url") or d.get("document_url") or "").strip()
                if not url or url.lower() in ("null", "undefined", ""):
                    continue
                normalized.append({
                    "document_type": d.get("document_type"),
                    "label": d.get("label") or d.get("document_name"),
                    "url": url,
                    "download_url": d.get("download_url") or url,
                    "public_id": d.get("public_id"),
                    "resource_type": d.get("resource_type", "auto"),
                    "file_name": d.get("file_name"),
                    "file_size": d.get("file_size", 0),
                    "is_pdf": d.get("is_pdf", False),
                    "is_image": d.get("is_image", False),
                    "source": d.get("source", "schemes_application"),
                    "uploaded_at": (
                        d["uploaded_at"].isoformat()
                        if isinstance(d.get("uploaded_at"), datetime)
                        else d.get("uploaded_at")
                    ),
                    "uploaded_by": d.get("uploaded_by"),
                })
            application["scheme_documents"] = normalized
            application.pop("documents", None)

            # Attach scheme master doc
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

                # ✅ Ensure application_number
                if "application_number" not in app or not app["application_number"]:
                    app["application_number"] = app.get("application_id")

                # ✅ Normalize scheme_documents for admin view
                docs = app.get("scheme_documents") or []
                normalized = []
                for d in docs:
                    if not isinstance(d, dict):
                        continue
                    url = (d.get("url") or d.get("document_url") or "").strip()
                    if not url or url.lower() in ("null", "undefined", ""):
                        continue
                    normalized.append({
                        "document_type": d.get("document_type"),
                        "label": d.get("label") or d.get("document_name"),
                        "url": url,
                        "download_url": d.get("download_url") or url,
                        "public_id": d.get("public_id"),
                        "resource_type": d.get("resource_type", "auto"),
                        "file_name": d.get("file_name"),
                        "file_size": d.get("file_size", 0),
                        "is_pdf": d.get("is_pdf", False),
                        "is_image": d.get("is_image", False),
                        "source": d.get("source", "schemes_application"),
                        "uploaded_at": (
                            d["uploaded_at"].isoformat()
                            if isinstance(d.get("uploaded_at"), datetime)
                            else d.get("uploaded_at")
                        ),
                        "uploaded_by": d.get("uploaded_by"),
                    })
                app["scheme_documents"] = normalized
                app.pop("documents", None)

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
                    f"Application Number: {application_id}"
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


# === Late import to avoid circular dependency at module load ===
from fastapi import HTTPException  # noqa: E402


print("✅ Scheme Service Loaded — SCHEME DOCUMENTS PARITY WITH SERVICE")
print("   ✅ application_id = APPLICATION NUMBER (YYYYMMSSSSS)")
print("   ✅ Documents stored in `scheme_documents[]` (parallel to service_documents)")
print("   ✅ Every doc tagged with source='schemes_application'")
print("   ✅ Accepts document_url / url / documentUrl / file_url / fileUrl")
print("   ✅ Verifies documents are saved to DB after insert")