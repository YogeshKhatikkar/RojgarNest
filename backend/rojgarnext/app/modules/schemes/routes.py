# app/modules/schemes/routes.py
"""
Government Schemes API Routes

✅ CRITICAL FIX: /apply endpoint now logs incoming documents
✅ CRITICAL FIX: Uses `payload.dict()` correctly
✅ Sets `resume_generated_at` flag NOT applied here (schemes are separate)
"""

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    UploadFile,
    File,
    Form,
    BackgroundTasks,
)
from typing import Optional
from datetime import datetime

from app.core.services.dependencies import get_current_user, role_required
from app.db.connection import get_db
from app.modules.schemes.service import SchemeService
from app.modules.schemes.schemas import (
    SchemeApplyRequest,
    SchemeApplyResponse,
    SchemeSubmitRequest,
    SchemeSubmitResponse,
    ApplicationResponse,
    ApplicationDetailResponse,
    DocumentUploadResponse,
    TempDocumentUploadResponse,
    AdminUpdateStatusRequest,
    AdminUpdateStatusResponse,
    SchemeListResponse,
    SchemeDetailResponse,
    SchemeCategoriesResponse,
    SchemeStatesResponse,
)
from app.core.services.cloudinary import upload_user_document
from app.core.utils.logger import logger

# ✅ NO prefix here — main.py adds /api/v1/schemes
router = APIRouter(tags=["Government Schemes"])


async def get_scheme_service(db=Depends(get_db)) -> SchemeService:
    return SchemeService(db)


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
        level=level,
        state=state,
        category=category,
        search=search,
        is_featured=is_featured,
        limit=limit,
        skip=skip,
    )


@router.get("/featured", response_model=SchemeListResponse)
async def get_featured_schemes(
    limit: int = Query(10, ge=1, le=50),
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user),
):
    schemes = await service.get_featured_schemes(limit)
    return {
        "success": True,
        "schemes": schemes,
        "total": len(schemes),
        "skip": 0,
        "limit": limit,
    }


@router.get("/categories", response_model=SchemeCategoriesResponse)
async def get_scheme_categories(
    current_user: dict = Depends(get_current_user),
):
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
# APPLY - MAIN APPLICATION SUBMISSION
# ============================================================
@router.post("/apply", response_model=SchemeApplyResponse)
async def apply_for_scheme(
    background_tasks: BackgroundTasks,
    payload: SchemeApplyRequest,
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user),
):
    """
    Submit a scheme application.

    ✅ CRITICAL FIX: Logs every incoming document for debugging
    ✅ Normalizes documents using universal helper
    """
    user_email = current_user.get("email")
    user_id = current_user.get("user_id")

    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")

    logger.info("=" * 70)
    logger.info("📝 SCHEME APPLICATION SUBMISSION")
    logger.info(f"   User: {user_email}")
    logger.info(f"   Scheme: {payload.scheme_id}")
    logger.info(f"   Documents received: {len(payload.documents or [])}")

    # ✅ CRITICAL: Log every incoming document
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
# FINAL SUBMISSION
# ============================================================
@router.post(
    "/application/{application_id}/submit",
    response_model=SchemeSubmitResponse,
)
async def submit_application(
    application_id: str,
    payload: SchemeSubmitRequest = SchemeSubmitRequest(),
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user),
):
    """Submit an application after all documents are uploaded."""
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")

    logger.info("=" * 70)
    logger.info("📤 FINAL APPLICATION SUBMISSION")
    logger.info(f"   Application ID: {application_id}")
    logger.info(f"   User: {user_email}")
    logger.info("=" * 70)

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


@router.get(
    "/application/{application_id}",
    response_model=ApplicationDetailResponse,
)
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
# UPLOAD DOCUMENT (per application)
# ============================================================
@router.post(
    "/application/{application_id}/upload-document",
    response_model=DocumentUploadResponse,
)
async def upload_application_document(
    application_id: str,
    file: UploadFile = File(...),
    document_type: str = Form(...),
    document_name: str = Form(...),
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user),
):
    """
    Upload a single document for a scheme application.

    ✅ Saved into applications.documents[]
    ✅ Tied to application_id — shows ONLY in matching card
    """
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")

    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="File is required")

    allowed = ["pdf", "jpg", "jpeg", "png"]
    file_ext = file.filename.split(".")[-1].lower() if file.filename else ""
    if file_ext not in allowed:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type. Allowed: {', '.join(allowed)}",
        )

    file_content = await file.read()
    file_size = len(file_content)
    await file.seek(0)

    if file_size > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail=(
                f"File too large. Max: 10MB, yours: "
                f"{file_size // (1024 * 1024)}MB"
            ),
        )

    username = user_email.split("@")[0]
    upload_result = await upload_user_document(
        file=file,
        username=username,
        document_type=f"scheme_applications/{application_id}",
    )

    if not upload_result or not upload_result.get("url"):
        raise HTTPException(
            status_code=500, detail="Cloudinary upload failed"
        )

    logger.info(f"✅ Document uploaded to Cloudinary: {upload_result['url']}")

    return await service.upload_document(
        application_id=application_id,
        user_email=user_email,
        document_type=document_type,
        document_name=document_name,
        document_url=upload_result.get("url"),
        public_id=upload_result.get("public_id"),
    )


# ============================================================
# TEMP DOCUMENT UPLOAD
# ============================================================
@router.post(
    "/upload-temp-document",
    response_model=TempDocumentUploadResponse,
)
async def upload_temp_document(
    file: UploadFile = File(...),
    document_type: str = Form(...),
    document_name: str = Form(...),
    current_user: dict = Depends(get_current_user),
):
    """
    Upload a document temporarily for scheme application.
    Returns Cloudinary URL to be stored when the application is submitted.

    ✅ CRITICAL FIX: Returns BOTH `url` and `document_url` in response
    """
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")

    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="File is required")

    allowed = ["pdf", "jpg", "jpeg", "png"]
    file_ext = file.filename.split(".")[-1].lower() if file.filename else ""
    if file_ext not in allowed:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type. Allowed: {', '.join(allowed)}",
        )

    file_content = await file.read()
    file_size = len(file_content)
    await file.seek(0)

    if file_size > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail="File too large. Max: 10MB",
        )

    username = user_email.split("@")[0]
    upload_result = await upload_user_document(
        file=file,
        username=username,
        document_type=f"scheme_documents/{document_type}",
    )

    if not upload_result or not upload_result.get("url"):
        raise HTTPException(
            status_code=500, detail="Cloudinary upload failed"
        )

    logger.info(
        f"✅ Temp document uploaded: {document_name} → "
        f"{upload_result['url']}"
    )

    # ✅ Return BOTH url and document_url for compatibility
    return {
        "success": True,
        "message": "Document uploaded successfully",
        "document": {
            "url": upload_result.get("url"),                    # ✅ Legacy
            "document_url": upload_result.get("url"),           # ✅ New
            "public_id": upload_result.get("public_id"),
            "document_type": document_type,
            "document_name": document_name,
            "filename": file.filename,
            "size_bytes": file_size,
        },
    }


# ============================================================
# ADMIN
# ============================================================
@router.get("/admin/all-applications", response_model=ApplicationResponse)
async def get_all_scheme_applications(
    status: Optional[str] = Query(None),
    scheme_id: Optional[str] = Query(None),
    limit: int = Query(100, ge=1, le=500),
    skip: int = Query(0, ge=0),
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(
        role_required(["admin", "customadmin", "superadmin"])
    ),
):
    return await service.get_all_applications(
        admin_email=current_user.get("email"),
        status=status,
        scheme_id=scheme_id,
        limit=limit,
        skip=skip,
    )


@router.put(
    "/admin/application/{application_id}/status",
    response_model=AdminUpdateStatusResponse,
)
async def update_application_status(
    application_id: str,
    payload: AdminUpdateStatusRequest,
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(
        role_required(["admin", "customadmin", "superadmin"])
    ),
):
    return await service.update_application_status(
        application_id=application_id,
        status=payload.status,
        admin_email=current_user.get("email"),
        notes=payload.notes,
    )


# ============================================================
# ✅ DEBUG: Print ALL registered paths on import
# ============================================================
print("=" * 70)
print("✅ Schemes Routes Loaded Successfully (UNIVERSAL DOCUMENT FIX)")
print("=" * 70)
print("📋 Routes registered on this router:")
for r in router.routes:
    methods = ",".join(r.methods) if hasattr(r, "methods") else "?"
    print(f"   [{methods:12s}] {r.path}")
print("=" * 70)
print("➡️  Final paths (after main.py adds prefix '/api/v1/schemes'):")
for r in router.routes:
    methods = ",".join(r.methods) if hasattr(r, "methods") else "?"
    print(f"   [{methods:12s}] /api/v1/schemes{r.path}")
print("=" * 70)