# app/modules/schemes/routes.py
"""
Government Schemes API Routes

✅ FIXED: Added review-with-document + final-submit-with-document endpoints
✅ FIXED: Added /application/{id}/status endpoint (frontend compatibility)
✅ FIXED: Documents stored in scheme_documents[]
✅ FIXED: /documents endpoint accepts BOTH _id AND application_id
✅ FIXED: /documents reads from BOTH documents[] AND scheme_documents[]
"""

import re
from fastapi import (
    APIRouter, Depends, HTTPException, Query,
    UploadFile, File, Form, BackgroundTasks,
)
from typing import Optional, List, Dict, Any
from datetime import datetime
from bson import ObjectId

from app.core.services.dependencies import get_current_user, role_required
from app.db.connection import get_db
from app.modules.schemes.service import SchemeService
from app.modules.schemes.schemas import (
    SchemeApplyRequest, SchemeApplyResponse,
    SchemeSubmitRequest, SchemeSubmitResponse,
    ApplicationResponse, ApplicationDetailResponse,
    DocumentUploadResponse, TempDocumentUploadResponse,
    AdminUpdateStatusRequest, AdminUpdateStatusResponse,
    SchemeListResponse, SchemeDetailResponse,
    SchemeCategoriesResponse, SchemeStatesResponse,
)
from app.core.services.cloudinary import upload_user_document, delete_from_cloudinary
from app.core.utils.logger import logger

router = APIRouter(tags=["Government Schemes"])


# ============================================================
# SERVICE DEPENDENCY
# ============================================================
async def get_scheme_service(db=Depends(get_db)) -> SchemeService:
    return SchemeService(db)


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


def _is_admin_role(role: str) -> bool:
    return (role or "").strip().lower() in (
        "admin", "customadmin", "custom_admin", "superadmin"
    )


def _find_scheme_application_filter(application_id: str) -> Dict[str, Any]:
    """
    Build a flexible $or filter matching ANY of:
      - _id (if valid ObjectId)
      - application_id
      - application_number
    """
    ids: List[Dict[str, Any]] = []
    if ObjectId.is_valid(application_id):
        ids.append({"_id": ObjectId(application_id)})
    ids.append({"application_id": application_id})
    ids.append({"application_number": application_id})
    return {"$or": ids}


async def _find_scheme_application(db, application_id: str) -> Optional[Dict[str, Any]]:
    """
    Find a scheme application by any ID form.
    Tries with application_type filter first, then without.
    """
    if not application_id or not application_id.strip():
        return None
    application_id = application_id.strip()

    or_filter = _find_scheme_application_filter(application_id)

    # Try with application_type filter
    app = await db.applications.find_one({
        "$and": [{"application_type": "schemes"}, or_filter]
    })
    if app:
        return app

    # Fallback: without application_type filter
    app = await db.applications.find_one(or_filter)
    return app


def _build_scheme_application_query(
    application_id: str,
    user_email: Optional[str] = None,
    role: str = "user",
) -> Dict[str, Any]:
    base_filters: List[Dict[str, Any]] = [{"application_type": "schemes"}]
    base_filters.append(_find_scheme_application_filter(application_id))

    if not _is_admin_role(role):
        if user_email:
            base_filters.append({"user_email": user_email})

    if len(base_filters) == 1:
        return base_filters[0]
    return {"$and": base_filters}


# ============================================================
# SCHEME LISTING
# ============================================================
@router.get("/list", response_model=SchemeListResponse)
async def list_schemes(
    level: Optional[str] = Query(None),
    state: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    is_featured: Optional[bool] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    skip: int = Query(0, ge=0),
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user),
):
    return await service.list_schemes(
        level=level, state=state, category=category,
        search=search, is_featured=is_featured,
        limit=limit, skip=skip,
    )


@router.get("/featured", response_model=SchemeListResponse)
async def get_featured_schemes(
    limit: int = Query(10, ge=1, le=50),
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user),
):
    schemes = await service.get_featured_schemes(limit)
    return {"success": True, "schemes": schemes, "total": len(schemes), "skip": 0, "limit": limit}


@router.get("/categories", response_model=SchemeCategoriesResponse)
async def get_scheme_categories(current_user: dict = Depends(get_current_user)):
    categories = [
        {"id": "agriculture", "name": "Agriculture", "name_hindi": "कृषि", "icon": "🌾"},
        {"id": "education", "name": "Education", "name_hindi": "शिक्षा", "icon": "📚"},
        {"id": "health", "name": "Health", "name_hindi": "स्वास्थ्य", "icon": "🏥"},
        {"id": "housing", "name": "Housing", "name_hindi": "आवास", "icon": "🏠"},
        {"id": "employment", "name": "Employment", "name_hindi": "रोजगार", "icon": "💼"},
        {"id": "women_child", "name": "Women & Child", "name_hindi": "महिला एवं बाल", "icon": "👩"},
        {"id": "social_welfare", "name": "Social Welfare", "name_hindi": "समाज कल्याण", "icon": "🤝"},
        {"id": "financial_inclusion", "name": "Financial Inclusion", "name_hindi": "वित्तीय समावेशन", "icon": "💰"},
        {"id": "pension", "name": "Pension", "name_hindi": "पेंशन", "icon": "👴"},
        {"id": "insurance", "name": "Insurance", "name_hindi": "बीमा", "icon": "🛡️"},
        {"id": "skill_development", "name": "Skill Development", "name_hindi": "कौशल विकास", "icon": "🎓"},
        {"id": "entrepreneurship", "name": "Entrepreneurship", "name_hindi": "उद्यमिता", "icon": "🚀"},
        {"id": "disability", "name": "Disability", "name_hindi": "विकलांगता", "icon": "♿"},
        {"id": "sc_st_welfare", "name": "SC/ST Welfare", "name_hindi": "अनुसूचित जाति/जनजाति कल्याण", "icon": "📋"},
        {"id": "minority_welfare", "name": "Minority Welfare", "name_hindi": "अल्पसंख्यक कल्याण", "icon": "🕌"},
        {"id": "other", "name": "Other", "name_hindi": "अन्य", "icon": "📌"},
    ]
    return {"success": True, "categories": categories}


@router.get("/states", response_model=SchemeStatesResponse)
async def get_states_with_schemes(
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user),
):
    states = await service.get_states_with_schemes()
    return {"success": True, "states": states}


@router.get("/detail/{scheme_id}", response_model=SchemeDetailResponse)
async def get_scheme_detail(
    scheme_id: str,
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user),
):
    return await service.get_scheme_detail(scheme_id)


# ============================================================
# APPLY
# ============================================================
@router.post("/apply", response_model=SchemeApplyResponse)
async def apply_for_scheme(
    background_tasks: BackgroundTasks,
    payload: SchemeApplyRequest,
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user),
):
    user_email = current_user.get("email")
    user_id = current_user.get("user_id")

    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")

    logger.info("=" * 70)
    logger.info("📝 SCHEME APPLICATION SUBMISSION")
    logger.info(f"   User: {user_email}")
    logger.info(f"   Scheme: {payload.scheme_id}")
    logger.info(f"   Documents received: {len(payload.documents or [])}")
    for i, doc in enumerate(payload.documents or []):
        logger.info(f"   [{i}] type={doc.document_type}, name={doc.document_name}, url={str(doc.document_url)[:80]}")
    logger.info("=" * 70)

    return await service.create_application(
        data=payload.dict(),
        user_email=user_email,
        user_id=user_id,
        background_tasks=background_tasks,
    )


# ============================================================
# FINAL SUBMISSION (by user)
# ============================================================
@router.post("/application/{application_id}/submit", response_model=SchemeSubmitResponse)
async def submit_application(
    application_id: str,
    payload: SchemeSubmitRequest = SchemeSubmitRequest(),
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user),
):
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.submit_application(
        application_id=application_id,
        user_email=user_email,
        additional_data=payload.dict(),
    )


# ============================================================
# MY APPLICATIONS
# ============================================================
@router.get("/my-applications", response_model=ApplicationResponse)
async def get_my_scheme_applications(
    status: Optional[str] = Query(None),
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user),
):
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_user_applications(user_email, status)


@router.get("/application/{application_id}", response_model=ApplicationDetailResponse)
async def get_application_detail(
    application_id: str,
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user),
):
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_application_detail(application_id, user_email)


# ============================================================
# GET DOCUMENTS
# ============================================================
@router.get("/application/{application_id}/documents")
async def get_scheme_documents(
    application_id: str,
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    if not application_id or not application_id.strip():
        raise HTTPException(status_code=400, detail="Application ID is required")

    application_id = application_id.strip()
    role = (current_user.get("role") or "user").strip().lower()
    user_email = current_user.get("email")

    logger.info("=" * 70)
    logger.info("📄 GET SCHEME DOCUMENTS")
    logger.info(f"   Raw ID from URL: '{application_id}'")
    logger.info(f"   Is valid ObjectId: {ObjectId.is_valid(application_id)}")
    logger.info(f"   User role: {role}")
    logger.info(f"   User email: {user_email}")
    logger.info("=" * 70)

    query = _build_scheme_application_query(application_id, user_email, role)
    logger.info(f"🔍 MongoDB query: {query}")

    app_rec = await db.applications.find_one(query)

    if not app_rec and _is_admin_role(role):
        logger.info("🔄 Retrying without user filter (admin override)...")
        app_rec = await db.applications.find_one({
            "$and": [
                {"application_type": "schemes"},
                _find_scheme_application_filter(application_id),
            ]
        })

    if not app_rec:
        logger.warning("⚠️ Still not found. Trying final fallback...")
        fallback: Dict[str, Any] = {"application_type": "schemes", "application_id": application_id}
        if not _is_admin_role(role) and user_email:
            fallback["user_email"] = user_email
        app_rec = await db.applications.find_one(fallback)

    if not app_rec:
        logger.error(f"❌ Scheme application NOT FOUND: {application_id}")
        raise HTTPException(status_code=404, detail=f"Application not found: {application_id}")

    actual_id = str(app_rec["_id"])
    stored_app_id = app_rec.get("application_id", "")
    logger.info(f"✅ Found scheme application: _id={actual_id}, application_id={stored_app_id}")

    normalized_user_docs: List[Dict[str, Any]] = []
    seen_urls: set = set()

    # From scheme_documents (new)
    scheme_docs = app_rec.get("scheme_documents") or []
    if not isinstance(scheme_docs, list):
        scheme_docs = []
    logger.info(f"📄 Total scheme_documents: {len(scheme_docs)}")

    for d in scheme_docs:
        if not isinstance(d, dict):
            continue
        url = (d.get("url") or d.get("document_url") or "").strip()
        if not url or url in seen_urls:
            continue
        seen_urls.add(url)
        uploaded_at = d.get("uploaded_at")
        if isinstance(uploaded_at, datetime):
            uploaded_at = uploaded_at.isoformat()
        normalized_user_docs.append({
            "url": url,
            "document_url": url,
            "download_url": d.get("download_url") or url,
            "label": d.get("document_name") or d.get("label") or d.get("document_type") or "Document",
            "document_name": d.get("document_name"),
            "document_type": d.get("document_type") or "document",
            "public_id": d.get("public_id"),
            "source": d.get("source") or "schemes_application",
            "uploaded_at": uploaded_at,
        })

    # From documents (legacy)
    legacy_docs = app_rec.get("documents") or []
    if not isinstance(legacy_docs, list):
        legacy_docs = []
    logger.info(f"📄 Total legacy documents[]: {len(legacy_docs)}")

    for d in legacy_docs:
        if not isinstance(d, dict):
            continue
        url = (d.get("document_url") or d.get("url") or "").strip()
        if not url or url in seen_urls:
            continue
        seen_urls.add(url)
        uploaded_at = d.get("uploaded_at")
        if isinstance(uploaded_at, datetime):
            uploaded_at = uploaded_at.isoformat()
        normalized_user_docs.append({
            "url": url,
            "document_url": url,
            "download_url": d.get("download_url") or url,
            "label": d.get("document_name") or d.get("label") or d.get("document_type") or "Document",
            "document_name": d.get("document_name"),
            "document_type": d.get("document_type") or "document",
            "public_id": d.get("public_id"),
            "source": "schemes_application",
            "uploaded_at": uploaded_at,
        })

    # Admin documents
    admin_docs: List[Dict[str, Any]] = []

    submitted_url = (app_rec.get("submitted_document_url") or "").strip()
    if submitted_url and submitted_url not in seen_urls:
        seen_urls.add(submitted_url)
        submitted_at = app_rec.get("submitted_at")
        if isinstance(submitted_at, datetime):
            submitted_at = submitted_at.isoformat()
        admin_docs.append({
            "url": submitted_url,
            "document_url": submitted_url,
            "download_url": app_rec.get("submitted_document_download_url") or submitted_url,
            "label": app_rec.get("submitted_document_name") or "Review Document",
            "document_type": "admin_review",
            "source": "admin_review",
            "badge": "ADMIN REVIEW",
            "uploaded_at": submitted_at,
        })

    final_url = (app_rec.get("final_document_url") or "").strip()
    if final_url and final_url not in seen_urls:
        seen_urls.add(final_url)
        final_submitted_at = app_rec.get("final_submitted_at")
        if isinstance(final_submitted_at, datetime):
            final_submitted_at = final_submitted_at.isoformat()
        admin_docs.append({
            "url": final_url,
            "document_url": final_url,
            "download_url": app_rec.get("final_document_download_url") or final_url,
            "label": app_rec.get("final_document_name") or "Final Submission Document",
            "document_type": "admin_final",
            "source": "admin_final",
            "badge": "ADMIN FINAL",
            "uploaded_at": final_submitted_at,
        })

    logger.info(f"📄 Total admin_documents: {len(admin_docs)}")
    logger.info(f"✅ Total user docs: {len(normalized_user_docs)}")
    logger.info("=" * 70)

    return {
        "success": True,
        "application_id": actual_id,
        "application_number": stored_app_id,
        "scheme_documents": normalized_user_docs,
        "admin_documents": admin_docs,
        "total": len(normalized_user_docs) + len(admin_docs),
    }


# ============================================================
# UPLOAD DOCUMENT (user, per application)
# ============================================================
@router.post("/application/{application_id}/upload-document", response_model=DocumentUploadResponse)
async def upload_scheme_document(
    application_id: str,
    file: UploadFile = File(...),
    document_type: str = Form(...),
    document_name: str = Form(""),
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user),
):
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="File is required")

    allowed = ["pdf", "jpg", "jpeg", "png"]
    file_ext = file.filename.split(".")[-1].lower() if file.filename else ""
    if file_ext not in allowed:
        raise HTTPException(status_code=400, detail=f"Invalid file type. Allowed: {', '.join(allowed)}")

    file_content = await file.read()
    file_size = len(file_content)
    await file.seek(0)

    if file_size > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail=f"File too large. Max: 10MB")

    username = _safe_username(user_email)
    doc_type_safe = _safe_doc_type(document_type)
    folder_path = f"scheme_applications/{application_id}/{doc_type_safe}"

    upload_result = await upload_user_document(file=file, username=username, document_type=folder_path)
    if not upload_result or not upload_result.get("url"):
        raise HTTPException(status_code=500, detail="Cloudinary upload failed")

    logger.info(f"✅ Document uploaded: {upload_result['url']}")

    return await service.upload_document(
        application_id=application_id,
        user_email=user_email,
        document_type=document_type,
        document_name=document_name or file.filename,
        document_url=upload_result.get("url"),
        public_id=upload_result.get("public_id"),
    )


# ============================================================
# DELETE DOCUMENT
# ============================================================
@router.delete("/application/{application_id}/document/{document_type}")
async def delete_scheme_document(
    application_id: str,
    document_type: str,
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user),
):
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.delete_document(
        application_id=application_id,
        user_email=user_email,
        document_type=document_type,
    )


# ============================================================
# TEMP DOCUMENT UPLOAD
# ============================================================
@router.post("/upload-temp-document", response_model=TempDocumentUploadResponse)
async def upload_temp_document(
    file: UploadFile = File(...),
    document_type: str = Form(...),
    document_name: str = Form(...),
    current_user: dict = Depends(get_current_user),
):
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="File is required")

    allowed = ["pdf", "jpg", "jpeg", "png"]
    file_ext = file.filename.split(".")[-1].lower() if file.filename else ""
    if file_ext not in allowed:
        raise HTTPException(status_code=400, detail=f"Invalid file type. Allowed: {', '.join(allowed)}")

    file_content = await file.read()
    file_size = len(file_content)
    await file.seek(0)

    if file_size > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File too large. Max: 10MB")

    username = _safe_username(user_email)
    doc_type_safe = _safe_doc_type(document_type)
    folder_path = f"scheme_documents/{doc_type_safe}"

    upload_result = await upload_user_document(file=file, username=username, document_type=folder_path)
    if not upload_result or not upload_result.get("url"):
        raise HTTPException(status_code=500, detail="Cloudinary upload failed")

    logger.info(f"✅ Temp document uploaded: {document_name} → {upload_result['url']}")

    return {
        "success": True,
        "message": "Document uploaded successfully",
        "document": {
            "url": upload_result.get("url"),
            "document_url": upload_result.get("url"),
            "public_id": upload_result.get("public_id"),
            "document_type": document_type,
            "document_name": document_name,
            "file_name": file.filename,
            "size_bytes": file_size,
            "is_pdf": bool(file_ext == "pdf"),
            "is_image": bool(file_ext in ["jpg", "jpeg", "png"]),
            "resource_type": "raw" if file_ext == "pdf" else "image",
            "source": "schemes_application",
            "uploaded_at": datetime.utcnow().isoformat(),
            "uploaded_by": user_email,
        },
    }


# ============================================================
# ✅ NEW: STATUS UPDATE (used by frontend customadmin screen)
# PUT /api/v1/schemes/application/{id}/status
# Accepts query params: status, notes
# OR body: {status, admin_notes, notes}
# ============================================================
@router.put("/application/{application_id}/status")
async def update_scheme_application_status(
    application_id: str,
    status: Optional[str] = Query(None),
    notes: Optional[str] = Query(None),
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """
    Update scheme application status.
    Accepts status via query param OR body.
    """
    role = (current_user.get("role") or "user").strip().lower()
    if not _is_admin_role(role):
        raise HTTPException(status_code=403, detail="Admin access required")

    if not status:
        raise HTTPException(status_code=400, detail="status is required")

    application = await _find_scheme_application(db, application_id)
    if not application:
        raise HTTPException(status_code=404, detail=f"Application not found: {application_id}")

    actual_id = str(application["_id"])
    old_status = application.get("status", "unknown")
    admin_email = current_user.get("email") or "admin"

    update_data: Dict[str, Any] = {
        "status": status,
        "last_status_update": datetime.utcnow(),
        "last_updated_by": admin_email,
        "updated_at": datetime.utcnow(),
    }
    if notes:
        update_data["admin_notes"] = notes

    await db.applications.update_one(
        {"_id": application["_id"]},
        {"$set": update_data}
    )

    logger.info(f"✅ Scheme application {actual_id}: {old_status} → {status}")

    # Notify applicant
    applicant_email = application.get("applicant_email") or application.get("user_email")
    if applicant_email:
        try:
            from app.modules.notification.service import central_notification
            scheme_name = (
                application.get("scheme_name")
                or application.get("scheme_name_hindi")
                or "Scheme Application"
            )
            await central_notification.send_notification(
                user_ids=[applicant_email],
                notification_type="application_status",
                title=f"📋 Application Status: {status.upper()}",
                message=f"Your scheme application for '{scheme_name}' is now {status.upper()}.",
                related_id=actual_id,
                metadata={
                    "application_id": actual_id,
                    "scheme_name": scheme_name,
                    "old_status": old_status,
                    "new_status": status,
                    "admin_notes": notes,
                    "show_blue_bell": True,
                },
                send_email=True,
                send_websocket=True,
            )
        except Exception as ne:
            logger.warning(f"⚠️ Notification failed: {ne}")

    return {
        "success": True,
        "message": f"Status updated from {old_status} to {status}",
        "application_id": actual_id,
        "status": status,
        "old_status": old_status,
    }


# ============================================================
# ✅ NEW: REVIEW WITH DOCUMENT
# POST /api/v1/schemes/application/{id}/review-with-document
# ============================================================
@router.post("/application/{application_id}/review-with-document")
async def scheme_review_with_document(
    application_id: str,
    file: UploadFile = File(...),
    notes: str = Form(""),
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """
    Admin/CustomAdmin uploads review document for scheme application.
    """
    role = (current_user.get("role") or "user").strip().lower()
    if not _is_admin_role(role):
        raise HTTPException(status_code=403, detail="Admin access required")

    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Document file is required")

    allowed_extensions = ['pdf', 'jpg', 'jpeg', 'png']
    file_ext = file.filename.split('.')[-1].lower() if file.filename else ''
    if file_ext not in allowed_extensions:
        raise HTTPException(status_code=400, detail=f"Invalid file type. Allowed: {', '.join(allowed_extensions)}")

    file_content = await file.read()
    file_size = len(file_content)
    await file.seek(0)

    if file_size > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File too large. Max: 10MB")

    logger.info("=" * 70)
    logger.info(f"📤 SCHEME REVIEW WITH DOCUMENT")
    logger.info(f"   App ID: {application_id}")
    logger.info(f"   Role: {role}")
    logger.info(f"   File: {file.filename}")
    logger.info("=" * 70)

    application = await _find_scheme_application(db, application_id)
    if not application:
        raise HTTPException(status_code=404, detail=f"Application not found: {application_id}")

    actual_id = str(application["_id"])
    applicant_email = application.get("applicant_email") or application.get("user_email")
    username = _safe_username(applicant_email) if applicant_email else "user"

    upload_result = await upload_user_document(
        file=file,
        username=username,
        document_type="scheme_applications/review",
    )

    if not upload_result or not upload_result.get("url"):
        raise HTTPException(status_code=500, detail="Cloudinary upload failed")

    old_status = application.get("status", "pending")
    now = datetime.utcnow()

    update_data = {
        "status": "review_application",
        "last_status_update": now,
        "last_updated_by": current_user.get("email"),
        "updated_at": now,
        "submitted_document_url": upload_result["url"],
        "submitted_document_download_url": upload_result.get("download_url"),
        "submitted_document_name": file.filename,
        "submitted_document_public_id": upload_result.get("public_id"),
        "submitted_document_resource_type": upload_result.get("resource_type", "raw"),
        "submitted_document_folder": upload_result.get("folder_path"),
        "submitted_at": now,
        "submitted_by": current_user.get("email"),
        "admin_notes": notes if notes else None,
    }

    await db.applications.update_one({"_id": application["_id"]}, {"$set": update_data})

    logger.info(f"✅ Status: {old_status} → review_application")

    if applicant_email:
        try:
            from app.modules.notification.service import central_notification
            scheme_name = application.get("scheme_name") or application.get("scheme_name_hindi") or "Scheme"
            await central_notification.send_notification(
                user_ids=[applicant_email],
                notification_type="application_status",
                title=f"📋 Application Under Review: {scheme_name}",
                message=f"Your scheme application for '{scheme_name}' is now under REVIEW.",
                related_id=actual_id,
                metadata={
                    "application_id": actual_id,
                    "scheme_name": scheme_name,
                    "status": "review_application",
                    "document_name": file.filename,
                    "admin_notes": notes,
                    "show_blue_bell": True,
                    "submitted_document_url": upload_result["url"],
                },
                send_email=True,
                send_websocket=True,
            )
        except Exception as ne:
            logger.warning(f"⚠️ Notification failed: {ne}")

    return {
        "success": True,
        "message": "Review document submitted successfully",
        "application_id": actual_id,
        "status": "review_application",
        "old_status": old_status,
        "submitted_document_url": upload_result["url"],
        "submitted_document_name": file.filename,
        "admin_notes": notes,
    }


# ============================================================
# ✅ NEW: FINAL SUBMIT WITH DOCUMENT
# POST /api/v1/schemes/application/{id}/final-submit-with-document
# ============================================================
@router.post("/application/{application_id}/final-submit-with-document")
async def scheme_final_submit_with_document(
    application_id: str,
    file: UploadFile = File(...),
    notes: str = Form(""),
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """
    Admin/CustomAdmin FINAL SUBMIT for scheme application.
    """
    role = (current_user.get("role") or "user").strip().lower()
    if not _is_admin_role(role):
        raise HTTPException(status_code=403, detail="Admin access required")

    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Document file is required")

    allowed_extensions = ['pdf', 'jpg', 'jpeg', 'png']
    file_ext = file.filename.split('.')[-1].lower() if file.filename else ''
    if file_ext not in allowed_extensions:
        raise HTTPException(status_code=400, detail=f"Invalid file type. Allowed: {', '.join(allowed_extensions)}")

    file_content = await file.read()
    file_size = len(file_content)
    await file.seek(0)

    if file_size > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File too large. Max: 10MB")

    logger.info("=" * 70)
    logger.info(f"📤 SCHEME FINAL SUBMIT")
    logger.info(f"   App ID: {application_id}")
    logger.info(f"   Role: {role}")
    logger.info(f"   File: {file.filename}")
    logger.info("=" * 70)

    application = await _find_scheme_application(db, application_id)
    if not application:
        raise HTTPException(status_code=404, detail=f"Application not found: {application_id}")

    actual_id = str(application["_id"])
    applicant_email = application.get("applicant_email") or application.get("user_email")
    username = _safe_username(applicant_email) if applicant_email else "user"

    # Delete old document if exists
    old_public_id = application.get("submitted_document_public_id")
    if old_public_id:
        try:
            old_resource_type = application.get("submitted_document_resource_type", "raw")
            await delete_from_cloudinary(old_public_id, old_resource_type)
            logger.info(f"🗑️ Old document deleted: {old_public_id}")
        except Exception as del_err:
            logger.warning(f"⚠️ Could not delete old document: {del_err}")

    upload_result = await upload_user_document(
        file=file,
        username=username,
        document_type="scheme_applications/final_submit",
    )

    if not upload_result or not upload_result.get("url"):
        raise HTTPException(status_code=500, detail="Cloudinary upload failed")

    old_status = application.get("status", "pending")
    now = datetime.utcnow()

    update_data = {
        "status": "final_submitted",
        "last_status_update": now,
        "last_updated_by": current_user.get("email"),
        "updated_at": now,
        "submitted_document_url": upload_result["url"],
        "submitted_document_download_url": upload_result.get("download_url"),
        "submitted_document_name": file.filename,
        "submitted_document_public_id": upload_result.get("public_id"),
        "submitted_document_resource_type": upload_result.get("resource_type", "raw"),
        "submitted_document_folder": upload_result.get("folder_path"),
        "submitted_at": now,
        "submitted_by": current_user.get("email"),
        "final_document_url": upload_result["url"],
        "final_document_download_url": upload_result.get("download_url"),
        "final_document_name": file.filename,
        "final_document_public_id": upload_result.get("public_id"),
        "final_submitted_at": now,
        "final_submitted_by": current_user.get("email"),
        "admin_notes": notes if notes else "Final submitted",
    }

    await db.applications.update_one({"_id": application["_id"]}, {"$set": update_data})

    logger.info(f"✅ Status: {old_status} → final_submitted")

    if applicant_email:
        try:
            from app.modules.notification.service import central_notification
            scheme_name = application.get("scheme_name") or application.get("scheme_name_hindi") or "Scheme"
            await central_notification.send_notification(
                user_ids=[applicant_email],
                notification_type="application_status",
                title=f"✅ FINAL SUBMISSION: {scheme_name}",
                message=f"Your FINAL document for '{scheme_name}' has been submitted successfully.",
                related_id=actual_id,
                metadata={
                    "application_id": actual_id,
                    "scheme_name": scheme_name,
                    "status": "final_submitted",
                    "document_name": file.filename,
                    "admin_notes": notes,
                    "is_final": True,
                    "show_blue_bell": True,
                    "final_document_url": upload_result["url"],
                },
                send_email=True,
                send_websocket=True,
            )
        except Exception as ne:
            logger.warning(f"⚠️ Notification failed: {ne}")

    return {
        "success": True,
        "message": "FINAL document submitted successfully!",
        "application_id": actual_id,
        "status": "final_submitted",
        "old_status": old_status,
        "final_document_url": upload_result["url"],
        "submitted_document_url": upload_result["url"],
        "document_name": file.filename,
        "admin_notes": notes,
        "old_document_deleted": old_public_id is not None,
    }


# ============================================================
# ADMIN: ALL APPLICATIONS
# ============================================================
@router.get("/admin/all-applications", response_model=ApplicationResponse)
async def get_all_scheme_applications(
    status: Optional[str] = Query(None),
    scheme_id: Optional[str] = Query(None),
    limit: int = Query(100, ge=1, le=500),
    skip: int = Query(0, ge=0),
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"])),
):
    return await service.get_all_applications(
        admin_email=current_user.get("email"),
        status=status, scheme_id=scheme_id, limit=limit, skip=skip,
    )


@router.put("/admin/application/{application_id}/status", response_model=AdminUpdateStatusResponse)
async def admin_update_application_status(
    application_id: str,
    payload: AdminUpdateStatusRequest,
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"])),
):
    return await service.update_application_status(
        application_id=application_id,
        status=payload.status,
        admin_email=current_user.get("email"),
        notes=payload.notes,
    )


# ============================================================
# PROFILE DATA FOR SCHEME APPLICATION
# ============================================================
@router.get("/profile-data")
async def get_profile_data_for_scheme(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")

    profile = await db.profile.find_one({"email": user_email})
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found. Please complete your profile first.")

    auth_user = await db.auth.find_one({"email": user_email})
    disability = profile.get("disability", {}) or {}
    gov_ids = profile.get("government_ids", {}) or {}

    applicant_details = {
        "full_name": profile.get("full_name") or (auth_user.get("name") if auth_user else "") or "",
        "father_name": profile.get("father_name", ""),
        "mother_name": profile.get("mother_name", ""),
        "date_of_birth": profile.get("dob", ""),
        "gender": profile.get("gender", "male"),
        "category": profile.get("category", "General"),
        "marital_status": profile.get("marital_status", "Unmarried"),
        "aadhaar_number": gov_ids.get("aadhar_number", ""),
        "mobile": (auth_user.get("mobile") if auth_user else "") or profile.get("phone", "") or "",
        "email": user_email,
        "annual_income": profile.get("family_annual_income", 0) or 0,
        "bpl_status": profile.get("bpl_status", False),
        "disability_status": disability.get("is_disabled", False),
        "disability_percentage": disability.get("disability_percentage", 0.0),
        "scheme_name": None,
        "scheme_id": None,
        "application_type": "schemes",
    }

    current_address = profile.get("current_address", {}) or {}
    applicant_address = {
        "address_line1": current_address.get("house_number") or current_address.get("address_line1") or "",
        "address_line2": current_address.get("landmark") or current_address.get("address_line2") or "",
        "village_city": current_address.get("village_name") or current_address.get("city") or current_address.get("village_city") or "",
        "district": current_address.get("district", "") or "",
        "state": current_address.get("state", "") or "",
        "pincode": current_address.get("pincode") or current_address.get("zipcode") or "",
        "country": current_address.get("country", "India") or "India",
    }

    bank_details_raw = profile.get("bank_details", {}) or {}
    bank_info = {
        "account_holder_name": bank_details_raw.get("account_holder_name", "") or "",
        "bank_name": bank_details_raw.get("bank_name", "") or "",
        "account_number": bank_details_raw.get("account_number", "") or "",
        "ifsc_code": bank_details_raw.get("ifsc_code", "") or "",
        "branch_name": bank_details_raw.get("branch_name", "") or "",
        "account_type": bank_details_raw.get("account_type", "savings") or "savings",
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
        field for field, value in required_fields.items()
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
print("✅ Schemes Routes Loaded")
print("   ✅ /application/{id}/review-with-document")
print("   ✅ /application/{id}/final-submit-with-document")
print("   ✅ /application/{id}/status (query + body)")
print("   ✅ /application/{id}/documents")
print("   ✅ /application/{id}/upload-document")
print("   ✅ /admin/application/{id}/status")
print("=" * 70)
for r in router.routes:
    methods = ",".join(r.methods) if hasattr(r, "methods") else "?"
    print(f"   [{methods:12s}] /api/v1/schemes{r.path}")
print("=" * 70)