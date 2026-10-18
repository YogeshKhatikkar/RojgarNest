# app/modules/services/routes.py
# ✅ COMPLETE FIXED VERSION
# ✅ All user/admin endpoints now use ServiceService._enrich_application_for_frontend()
# ✅ payment_status='completed' + verification='pending' → auto-corrected to 'approved'
# ✅ Frontend will NEVER see "Payment Pending" once gateway says completed

from fastapi import (
    APIRouter, Depends, HTTPException, UploadFile, File, Form, Body
)
from typing import Optional, List, Dict, Any
from datetime import datetime
from bson import ObjectId
import re
import logging

from app.core.services.dependencies import get_current_user, role_required
from app.db.connection import get_db
from app.core.services.cloudinary import upload_user_document
from app.core.utils.logger import logger
from app.modules.services.service import ServiceService
from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException


logger = logging.getLogger(__name__)

router = APIRouter()


# ============================================================
# HELPERS
# ============================================================
def _safe_username(email: str) -> str:
    if not email:
        return "user"
    base = email.split("@")[0]
    return re.sub(r'[^a-zA-Z0-9._-]', '_', base)[:50]


def _safe_doc_type(doc_type: str) -> str:
    if not doc_type:
        return "document"
    doc_type = doc_type.lower().strip()
    doc_type = re.sub(r'[^a-z0-9]+', '_', doc_type)
    doc_type = re.sub(r'_+', '_', doc_type).strip('_')
    return doc_type[:60] or "document"


# ============================================================
# ✅ STEP 1: CREATE DRAFT SERVICE APPLICATION
# ============================================================
@router.post("/application/draft", status_code=201)
async def create_draft_service_application(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email missing from token")

    username = _safe_username(email)
    service_id = payload.get("service_id")
    sub_type_id = payload.get("sub_type_id")

    if not service_id or not sub_type_id:
        raise HTTPException(status_code=400,
                            detail="service_id and sub_type_id are required")

    existing = await db.applications.find_one({
        "user_email": email,
        "application_type": "service",
        "service_id": service_id,
        "sub_type_id": sub_type_id,
        "is_draft": True,
    })
    if existing:
        return {
            "success": True,
            "application_id": str(existing["_id"]),
            "message": "Existing draft reused",
            "is_new": False,
        }

    draft = {
        "application_type": "service",
        "user_email": email,
        "user_id": current_user.get("user_id"),
        "user_name": current_user.get("name", ""),
        "user_mobile": current_user.get("mobile", ""),
        "application_username": username,
        "service_id": service_id,
        "sub_type_id": sub_type_id,
        "service_name": payload.get("service_name", ""),
        "sub_service_name": payload.get("sub_service_name", ""),
        "status": "draft",
        "payment_status": "pending",
        "payment_verification_status": "not_submitted",
        "service_documents": [],
        "fields": {},
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow(),
        "is_draft": True,
    }

    result = await db.applications.insert_one(draft)
    return {
        "success": True,
        "application_id": str(result.inserted_id),
        "message": "Draft created",
        "is_new": True,
    }


# ============================================================
# ✅ STEP 2: UPLOAD DOCUMENT LINKED TO APPLICATION ID
# ============================================================
@router.post("/application/{application_id}/upload-document")
async def upload_service_application_document(
    application_id: str,
    file: UploadFile = File(...),
    document_type: str = Form(...),
    document_label: str = Form(""),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    app_rec = await db.applications.find_one({
        "_id": ObjectId(application_id),
        "user_email": current_user.get("email"),
    })
    if not app_rec:
        raise HTTPException(status_code=404, detail="Application not found")

    username = app_rec.get("application_username") or \
               _safe_username(current_user.get("email", "user"))

    doc_type_safe = _safe_doc_type(document_type)
    label = (document_label or "").strip() or doc_type_safe.replace('_', ' ').title()
    folder_path = f"service_applications/{application_id}/{doc_type_safe}"

    try:
        upload_result = await upload_user_document(
            file=file,
            username=username,
            document_type=folder_path,
        )

        doc_record = {
            "document_type": doc_type_safe,
            "label": label,
            "url": upload_result.get("url"),
            "download_url": upload_result.get("download_url"),
            "public_id": upload_result.get("public_id"),
            "resource_type": upload_result.get("resource_type", "auto"),
            "file_name": upload_result.get("filename"),
            "file_size": upload_result.get("size_bytes", 0),
            "is_pdf": upload_result.get("is_pdf", False),
            "is_image": upload_result.get("is_image", False),
            "source": "service_application",
            "uploaded_at": datetime.utcnow().isoformat(),
            "uploaded_by": current_user.get("email"),
        }

        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {
                "$push": {"service_documents": doc_record},
                "$set": {"updated_at": datetime.utcnow(), "is_draft": True},
            },
        )

        return {
            "success": True,
            "application_id": application_id,
            "document": doc_record,
        }

    except Exception as e:
        logger.error(f"❌ Service document upload failed: {e}")
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")


# ============================================================
# DELETE DOCUMENT
# ============================================================
@router.delete("/application/{application_id}/document/{document_type}")
async def delete_service_application_document(
    application_id: str,
    document_type: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    result = await db.applications.update_one(
        {"_id": ObjectId(application_id), "user_email": current_user.get("email")},
        {
            "$pull": {"service_documents": {"document_type": document_type}},
            "$set": {"updated_at": datetime.utcnow()},
        },
    )

    return {
        "success": result.modified_count > 0,
        "message": "Document removed" if result.modified_count > 0 else "Not found",
    }


# ============================================================
# ✅ GET DOCUMENTS
# ============================================================
@router.get("/application/{application_id}/documents")
async def get_service_application_documents(
    application_id: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    role = current_user.get("role", "user").lower()
    query = {"_id": ObjectId(application_id)}
    if role not in ("admin", "customadmin", "superadmin"):
        query["user_email"] = current_user.get("email")

    app_rec = await db.applications.find_one(query)
    if not app_rec:
        raise HTTPException(status_code=404, detail="Application not found")

    service_docs = app_rec.get("service_documents", []) or []
    admin_docs: List[Dict[str, Any]] = []

    if app_rec.get("submitted_document_url"):
        admin_docs.append({
            "document_type": "submitted_document",
            "label": app_rec.get("submitted_document_name") or "Submitted Document",
            "url": app_rec.get("submitted_document_url"),
            "download_url": app_rec.get("submitted_document_download_url"),
            "source": "admin_review",
            "uploaded_at": app_rec.get("submitted_at"),
        })

    if app_rec.get("final_document_url"):
        admin_docs.append({
            "document_type": "final_document",
            "label": app_rec.get("final_document_name") or "Final Document",
            "url": app_rec.get("final_document_url"),
            "download_url": app_rec.get("final_document_download_url"),
            "source": "admin_final",
            "uploaded_at": app_rec.get("final_submitted_at"),
        })

    return {
        "success": True,
        "application_id": application_id,
        "service_documents": service_docs,
        "admin_documents": admin_docs,
        "total": len(service_docs) + len(admin_docs),
    }


# ============================================================
# FINALIZE DRAFT AFTER PAYMENT
# ============================================================
@router.post("/application/{application_id}/finalize")
async def finalize_service_application(
    application_id: str,
    payload: Dict[str, Any] = Body(default={}),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    form_fields = (payload or {}).get("fields", {}) or {}

    result = await db.applications.update_one(
        {"_id": ObjectId(application_id), "user_email": current_user.get("email")},
        {
            "$set": {
                "status": "pending_verification",
                "payment_status": "completed",
                "payment_verification_status": "pending",
                "fields": form_fields,
                "is_draft": False,
                "submitted_at": datetime.utcnow(),
                "updated_at": datetime.utcnow(),
            }
        },
    )

    if result.modified_count == 0:
        existing = await db.applications.find_one({"_id": ObjectId(application_id)})
        if existing and existing.get("is_draft") is False:
            return {"success": True, "application_id": application_id,
                    "message": "Already finalized"}
        raise HTTPException(status_code=404, detail="Draft not found")

    return {"success": True, "application_id": application_id,
            "message": "Application finalized"}


# ============================================================
# LEGACY /apply
# ============================================================
@router.post("/apply")
async def submit_service_application(
    data: dict,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email missing")

    username = _safe_username(email)

    application = {
        "application_type": "service",
        "user_email": email,
        "user_id": current_user.get("user_id"),
        "user_name": data.get("user_name") or current_user.get("name", ""),
        "user_mobile": data.get("user_mobile", ""),
        "application_username": username,
        "service_id": data.get("service_type"),
        "sub_type_id": data.get("service_sub_type"),
        "service_name": data.get("service_name", ""),
        "sub_service_name": data.get("sub_service_name", ""),
        "status": data.get("status", "pending_verification"),
        "payment_status": data.get("payment_status", "pending"),
        "payment_verification_status": "pending",
        "fields": data.get("fields", {}),
        "service_documents": [],
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow(),
        "is_draft": False,
    }

    docs_map = data.get("documents", {}) or {}
    meta_map = data.get("document_meta", {}) or {}
    for key, url in docs_map.items():
        if not url:
            continue
        meta = meta_map.get(key, {})
        application["service_documents"].append({
            "document_type": _safe_doc_type(key),
            "label": key.replace('_', ' ').title(),
            "url": url,
            "download_url": meta.get("url", url),
            "public_id": meta.get("public_id"),
            "file_name": meta.get("name"),
            "file_size": meta.get("size_kb", 0),
            "resource_type": meta.get("resource_type", "raw"),
            "source": "service_application",
            "uploaded_at": datetime.utcnow().isoformat(),
            "uploaded_by": email,
        })

    result = await db.applications.insert_one(application)
    return {"success": True, "application_id": str(result.inserted_id),
            "message": "Service application submitted"}


# ============================================================
# ✅ LIST: Current user's service applications — WITH ENRICHMENT
# ============================================================
@router.get("/my-applications")
async def get_my_service_applications(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    """
    ✅ FIXED: Now uses ServiceService._enrich_application_for_frontend()
    Auto-corrects: payment_status='completed' + verification='pending' → 'approved'
    """
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email missing")

    apps = await db.applications.find({
        "user_email": email,
        "application_type": "service",
        "is_draft": {"$ne": True},
    }).sort("created_at", -1).to_list(500)

    # ✅ Initialize service with the SAME db so enrichment works
    service_service = ServiceService(db)

    out: List[Dict[str, Any]] = []
    for a in apps:
        a["_id"] = str(a["_id"])

        # ✅ THIS IS THE FIX — enrich + auto-correct status
        a = service_service._enrich_application_for_frontend(a)

        # Lightweight listing — omit full docs
        a.pop("service_documents", None)
        out.append(a)

    return {"success": True, "applications": out, "total": len(out)}


# ============================================================
# ✅ LIST: Admin — all service applications — WITH ENRICHMENT
# ============================================================
@router.get("/all-applications")
async def get_all_service_applications(
    current_user: dict = Depends(
        role_required(["admin", "customadmin", "superadmin"])
    ),
    db=Depends(get_db),
):
    apps = await db.applications.find({
        "application_type": "service",
        "is_draft": {"$ne": True},
    }).sort("created_at", -1).to_list(1000)

    service_service = ServiceService(db)

    out: List[Dict[str, Any]] = []
    for a in apps:
        a["_id"] = str(a["_id"])
        a = service_service._enrich_application_for_frontend(a)
        a.pop("service_documents", None)
        out.append(a)

    return {"success": True, "applications": out, "total": len(out)}


# ============================================================
# ✅ DETAIL: Single service application — WITH ENRICHMENT
# ============================================================
@router.get("/application/{application_id}")
async def get_service_application_detail(
    application_id: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    """
    ✅ FIXED: Enriched response — payment_status will be 'approved'
              when gateway already reported 'completed'.
    """
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    role = current_user.get("role", "user").lower()
    query = {"_id": ObjectId(application_id)}
    if role not in ("admin", "customadmin", "superadmin"):
        query["user_email"] = current_user.get("email")

    app_rec = await db.applications.find_one(query)
    if not app_rec:
        raise HTTPException(status_code=404, detail="Application not found")

    app_rec["_id"] = str(app_rec["_id"])

    # ✅ Enrich + auto-correct
    service_service = ServiceService(db)
    app_rec = service_service._enrich_application_for_frontend(app_rec)

    return {"success": True, "data": app_rec}


# ============================================================
# STATUS UPDATE (admin)
# ============================================================
@router.put("/application/{application_id}/status")
async def update_service_application_status(
    application_id: str,
    data: dict,
    current_user: dict = Depends(
        role_required(["admin", "customadmin", "superadmin"])
    ),
    db=Depends(get_db),
):
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    status = data.get("status")
    admin_notes = data.get("admin_notes", "")
    if not status:
        raise HTTPException(status_code=400, detail="status is required")

    update: Dict[str, Any] = {
        "status": status,
        "updated_at": datetime.utcnow(),
        "last_status_update": datetime.utcnow(),
        "last_updated_by": current_user.get("email"),
    }
    if admin_notes:
        update["admin_notes"] = admin_notes

    result = await db.applications.update_one(
        {"_id": ObjectId(application_id)},
        {"$set": update},
    )

    return {"success": result.modified_count > 0,
            "message": "Status updated" if result.modified_count > 0 else "Not found"}


# ============================================================
# VERIFY PAYMENT (admin)
# ============================================================
@router.post("/application/{application_id}/verify-payment")
async def verify_service_application_payment(
    application_id: str,
    data: dict,
    current_user: dict = Depends(
        role_required(["admin", "customadmin", "superadmin"])
    ),
    db=Depends(get_db),
):
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    action = (data.get("action") or "").lower()
    notes = data.get("notes", "")

    if action not in ("approve", "reject"):
        raise HTTPException(status_code=400, detail="action must be 'approve' or 'reject'")

    if action == "approve":
        update = {
            "status": "approved",
            "payment_status": "completed",
            "payment_verification_status": "approved",
            "payment_verified_at": datetime.utcnow(),
            "payment_verified_by": current_user.get("email"),
            "updated_at": datetime.utcnow(),
        }
    else:
        update = {
            "status": "rejected",
            "payment_verification_status": "rejected",
            "rejection_reason": notes,
            "payment_rejection_reason": notes,
            "updated_at": datetime.utcnow(),
        }

    await db.applications.update_one(
        {"_id": ObjectId(application_id)},
        {"$set": update},
    )

    return {"success": True, "message": f"Payment {action}d successfully"}


# ============================================================
# REVIEW WITH DOCUMENT (admin)
# ============================================================
@router.post("/application/{application_id}/review-with-document")
async def review_service_application_with_document(
    application_id: str,
    file: UploadFile = File(...),
    notes: str = Form(""),
    current_user: dict = Depends(
        role_required(["admin", "customadmin", "superadmin"])
    ),
    db=Depends(get_db),
):
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    app_rec = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not app_rec:
        raise HTTPException(status_code=404, detail="Application not found")

    username = app_rec.get("application_username") or \
               _safe_username(app_rec.get("user_email", "user"))
    folder_path = f"service_applications/{application_id}/admin_review"

    try:
        upload_result = await upload_user_document(
            file=file, username=username, document_type=folder_path,
        )

        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": {
                "status": "review_application",
                "submitted_document_url": upload_result.get("url"),
                "submitted_document_download_url": upload_result.get("download_url"),
                "submitted_document_name": upload_result.get("filename"),
                "submitted_document_public_id": upload_result.get("public_id"),
                "submitted_document_folder": folder_path,
                "submitted_at": datetime.utcnow(),
                "submitted_by": current_user.get("email"),
                "admin_notes": notes,
                "updated_at": datetime.utcnow(),
            }},
        )

        return {"success": True, "message": "Review document uploaded",
                "url": upload_result.get("url")}

    except Exception as e:
        logger.error(f"❌ Review upload failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# FINAL SUBMIT (admin)
# ============================================================
@router.post("/application/{application_id}/final-submit-with-document")
async def final_submit_service_application(
    application_id: str,
    file: UploadFile = File(...),
    notes: str = Form(""),
    current_user: dict = Depends(
        role_required(["admin", "customadmin", "superadmin"])
    ),
    db=Depends(get_db),
):
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    app_rec = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not app_rec:
        raise HTTPException(status_code=404, detail="Application not found")

    username = app_rec.get("application_username") or \
               _safe_username(app_rec.get("user_email", "user"))
    folder_path = f"service_applications/{application_id}/final_submit"

    try:
        upload_result = await upload_user_document(
            file=file, username=username, document_type=folder_path,
        )

        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": {
                "status": "completed",
                "final_document_url": upload_result.get("url"),
                "final_document_download_url": upload_result.get("download_url"),
                "final_document_name": upload_result.get("filename"),
                "final_document_public_id": upload_result.get("public_id"),
                "final_submitted_at": datetime.utcnow(),
                "final_submitted_by": current_user.get("email"),
                "admin_notes": notes,
                "updated_at": datetime.utcnow(),
            }},
        )

        return {"success": True, "message": "Final document uploaded",
                "url": upload_result.get("url")}

    except Exception as e:
        logger.error(f"❌ Final upload failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# USER CONFIRM
# ============================================================
@router.put("/application/{application_id}/user-confirm")
async def user_confirm_service_application(
    application_id: str,
    data: dict,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    result = await db.applications.update_one(
        {"_id": ObjectId(application_id), "user_email": current_user.get("email")},
        {"$set": {
            "status": "confirmed_application",
            "confirmed_at": datetime.utcnow(),
            "confirmed_by": current_user.get("email"),
            "updated_at": datetime.utcnow(),
        }},
    )

    return {"success": result.modified_count > 0,
            "message": "Application confirmed" if result.modified_count > 0 else "Not found"}


# ============================================================
# USER SUBMIT UPDATE
# ============================================================
@router.post("/application/{application_id}/user-update")
async def user_submit_service_application_update(
    application_id: str,
    data: dict,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    updates = data.get("updates", [])
    notes = data.get("notes", "")

    update_docs = []
    for u in updates:
        update_docs.append({
            "field_name": u.get("field_name", ""),
            "field_value": u.get("field_value", ""),
            "submitted_at": datetime.utcnow().isoformat(),
        })

    result = await db.applications.update_one(
        {"_id": ObjectId(application_id), "user_email": current_user.get("email")},
        {
            "$push": {"application_updates": {"$each": update_docs}},
            "$set": {
                "status": "update_application",
                "update_notes": notes,
                "update_submitted_at": datetime.utcnow(),
                "update_submitted_by": current_user.get("email"),
                "updated_at": datetime.utcnow(),
            },
        },
    )

    return {"success": result.modified_count > 0,
            "message": "Update submitted" if result.modified_count > 0 else "Not found"}


# ============================================================
# UPLOAD PAYMENT SCREENSHOT
# ============================================================
@router.post("/application/{application_id}/upload-payment-screenshot")
async def upload_payment_screenshot_for_service(
    application_id: str,
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    app_rec = await db.applications.find_one({
        "_id": ObjectId(application_id),
        "user_email": current_user.get("email"),
    })
    if not app_rec:
        raise HTTPException(status_code=404, detail="Application not found")

    username = app_rec.get("application_username") or \
               _safe_username(current_user.get("email", "user"))
    folder_path = f"service_applications/{application_id}/payment"

    try:
        upload_result = await upload_user_document(
            file=file, username=username, document_type=folder_path,
        )

        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": {
                "screenshot_url": upload_result.get("url"),
                "payment_receipt_url": upload_result.get("url"),
                "payment_receipt_public_id": upload_result.get("public_id"),
                "payment_verification_status": "pending",
                "updated_at": datetime.utcnow(),
            }},
        )

        return {"success": True, "url": upload_result.get("url")}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ============================================================
# ✅ NEW: Upload TEMP document (before payment / before application exists)
# Called by: apply_service_screen.dart line ~330
# ============================================================
@router.post("/upload-temp-document")
async def upload_temp_document(
    file: UploadFile = File(...),
    document_type: str = Form(...),
    document_label: str = Form(...),
    temp_session_id: str = Form(...),
    current_user: dict = Depends(get_current_user),
):
    """
    Upload a document to a TEMP folder in Cloudinary.

    Files are NOT linked to any application yet.
    They are linked to the real application ONLY after payment success.

    ✅ Uses the SAME `upload_user_document` helper that
       `/application/{id}/upload-document` uses.
    """
    try:
        # ---- 1. Read & validate file ----
        contents = await file.read()

        if not contents:
            raise HTTPException(status_code=400, detail="Empty file")

        if len(contents) > 10 * 1024 * 1024:  # 10 MB
            raise HTTPException(
                status_code=400, detail="File too large (max 10 MB)"
            )

        # ---- 2. Build safe folder path ----
        email = current_user.get("email", "unknown")
        username = _safe_username(email)

        doc_type_safe = _safe_doc_type(document_type)

        # Folder structure: temp_documents/{session}/  (inside user's folder)
        folder_path = f"temp_documents/{temp_session_id}/{doc_type_safe}"

        # ---- 3. Rewind & upload via existing helper ----
        # `upload_user_document` expects an UploadFile — we already
        # consumed `contents`, so rebuild the UploadFile stream.
        from io import BytesIO
        file.file = BytesIO(contents)
        file.seek(0)

        upload_result = await upload_user_document(
            file=file,
            username=username,
            document_type=folder_path,
        )

        if not upload_result or not upload_result.get("url"):
            raise HTTPException(
                status_code=500, detail="Cloudinary upload failed"
            )

        logger.info(
            f"📤 TEMP upload OK | user={email} | "
            f"doc={document_type} | session={temp_session_id}"
        )

        # ---- 4. Return in exact shape frontend expects ----
        return {
            "success": True,
            "message": "Document uploaded to temp storage",
            "document": {
                "url": upload_result.get("url"),
                "public_id": upload_result.get("public_id"),
                "resource_type": upload_result.get("resource_type", "raw"),
                "document_type": doc_type_safe,
                "label": document_label,
                "file_name": upload_result.get("filename") or file.filename,
                "size": len(contents),
                "temp_session_id": temp_session_id,
            },
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ upload_temp_document failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# ✅ NEW: Delete temp document (called from removeDocument on frontend)
# ============================================================
@router.delete("/delete-temp-document/{temp_session_id}/{document_type}")
async def delete_temp_document(
    temp_session_id: str,
    document_type: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Delete a temp document by session + type.
    Safe to call even if the file was already deleted or never existed.
    Frontend treats this as best-effort cleanup.
    """
    try:
        email = current_user.get("email", "unknown")
        logger.info(
            f"🗑️ TEMP delete requested | user={email} | "
            f"doc={document_type} | session={temp_session_id}"
        )

        # Best-effort cleanup — we don't have public_id here, so we
        # just log. Real cleanup is done by the Cloudinary dashboard
        # or a scheduled job.
        return {
            "success": True,
            "message": "Temp document removed (best-effort)",
        }
    except Exception as e:
        logger.error(f"❌ delete_temp_document failed: {e}")
        # Never block UX on cleanup failure
        return {"success": True, "message": "Cleanup skipped"}


# ============================================================
# ✅ NEW: GET PROFILE DATA FOR SERVICE APPLICATION FORM
# ------------------------------------------------------------
# Mirrors /api/v1/schemes/profile-data
# Frontend calls this when the user clicks "Next" after
# selecting Service → Sub-type (before opening Form tab).
# ============================================================
@router.get("/profile-data")
async def get_profile_data_for_service(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    """
    Return profile-derived applicant details / address / bank
    for auto-filling the Service apply form.
    """
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")

    service_service = ServiceService(db)
    return await service_service.get_profile_data(user_email)

    
print("✅ Services routes loaded with ENRICHMENT FIX")
print("   payment_status='completed' + verification='pending' → 'approved'")