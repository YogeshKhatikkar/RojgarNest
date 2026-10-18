# app/modules/schemes/routes.py
"""
Government Schemes API Routes
"""

from fastapi import APIRouter, Depends, HTTPException, Query, Body, UploadFile, File, Form
from typing import Optional, List, Dict, Any
from bson import ObjectId
import logging

from app.core.services.dependencies import get_current_user, role_required
from app.db.connection import get_db
from app.modules.schemes.service import SchemeService
from app.modules.schemes.schema import (
    SchemeApplicationCreateSchema,
    SchemeApplicationStatusUpdateSchema,
    SchemeFilterSchema
)
from app.core.services.cloudinary import upload_user_document
from app.core.utils.logger import logger

router = APIRouter(prefix="/schemes", tags=["Government Schemes"])


async def get_scheme_service(db=Depends(get_db)):
    """Dependency to get SchemeService instance"""
    return SchemeService(db)


# ============================================================
# SCHEME LISTING & RETRIEVAL (Public)
# ============================================================

@router.get("/list")
async def list_schemes(
    level: Optional[str] = Query(None, description="central, state, or all"),
    state: Optional[str] = Query(None, description="State name for state schemes"),
    category: Optional[str] = Query(None, description="Scheme category"),
    search: Optional[str] = Query(None, description="Search term"),
    is_featured: Optional[bool] = Query(None, description="Filter featured schemes"),
    limit: int = Query(50, ge=1, le=200),
    skip: int = Query(0, ge=0),
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user)
):
    """
    List all government schemes with filters
    """
    return await service.list_schemes(
        level=level,
        state=state,
        category=category,
        search=search,
        is_featured=is_featured,
        limit=limit,
        skip=skip
    )


@router.get("/featured")
async def get_featured_schemes(
    limit: int = Query(10, ge=1, le=50),
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user)
):
    """
    Get featured schemes
    """
    schemes = await service.get_featured_schemes(limit)
    return {
        "success": True,
        "schemes": schemes,
        "total": len(schemes)
    }


@router.get("/categories")
async def get_scheme_categories(
    current_user: dict = Depends(get_current_user)
):
    """
    Get all available scheme categories
    """
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
    return {
        "success": True,
        "categories": categories
    }


@router.get("/states")
async def get_states_with_schemes(
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user)
):
    """
    Get list of states that have schemes
    """
    states = await service.get_states_with_schemes()
    return {
        "success": True,
        "states": states
    }


@router.get("/detail/{scheme_id}")
async def get_scheme_detail(
    scheme_id: str,
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user)
):
    """
    Get detailed information about a specific scheme
    Returns full scheme details including:
    - Benefits (लाभ)
    - Eligibility (पात्रता)
    - Required documents (आवश्यक दस्तावेज)
    - Application process (आवेदन प्रक्रिया)
    - Target beneficiaries (लाभार्थी)
    """
    return await service.get_scheme_detail(scheme_id)


# ============================================================
# SCHEME APPLICATION (User)
# ============================================================

@router.post("/apply")
async def apply_for_scheme(
    data: Dict[str, Any] = Body(...),
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user)
):
    """
    Apply for a government scheme
    """
    user_email = current_user.get("email")
    user_id = current_user.get("user_id")
    
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    return await service.create_application(
        data=data,
        user_email=user_email,
        user_id=user_id
    )


@router.get("/my-applications")
async def get_my_scheme_applications(
    status: Optional[str] = Query(None, description="Filter by status"),
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user)
):
    """
    Get all scheme applications for the current user
    """
    user_email = current_user.get("email")
    
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    return await service.get_user_applications(user_email, status)


@router.get("/application/{application_id}")
async def get_application_detail(
    application_id: str,
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user)
):
    """
    Get detailed information about a specific scheme application
    """
    user_email = current_user.get("email")
    
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    return await service.get_application_detail(application_id, user_email)


@router.post("/application/{application_id}/upload-document")
async def upload_application_document(
    application_id: str,
    file: UploadFile = File(...),
    document_type: str = Form(...),
    document_name: str = Form(...),
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(get_current_user)
):
    """
    Upload a document for a scheme application
    """
    user_email = current_user.get("email")
    
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="File is required")
    
    # Validate file type
    allowed_extensions = ['pdf', 'jpg', 'jpeg', 'png']
    file_ext = file.filename.split('.')[-1].lower() if file.filename else ''
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type. Allowed: {', '.join(allowed_extensions)}"
        )
    
    # Validate file size (10MB max)
    file_content = await file.read()
    file_size = len(file_content)
    await file.seek(0)
    
    if file_size > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail=f"File too large. Max: 10MB, Your file: {file_size // (1024*1024)}MB"
        )
    
    # Upload to Cloudinary
    username = user_email.split('@')[0]
    upload_result = await upload_user_document(
        file=file,
        username=username,
        document_type=f"scheme_applications/{application_id}"
    )
    
    return await service.upload_document(
        application_id=application_id,
        user_email=user_email,
        document_type=document_type,
        document_name=document_name,
        document_url=upload_result.get("url"),
        public_id=upload_result.get("public_id")
    )


# ============================================================
# ADMIN OPERATIONS
# ============================================================

@router.get("/admin/all-applications")
async def get_all_scheme_applications(
    status: Optional[str] = Query(None, description="Filter by status"),
    scheme_id: Optional[str] = Query(None, description="Filter by scheme"),
    limit: int = Query(100, ge=1, le=500),
    skip: int = Query(0, ge=0),
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"]))
):
    """
    Get all scheme applications (Admin only)
    """
    admin_email = current_user.get("email")
    return await service.get_all_applications(
        admin_email=admin_email,
        status=status,
        scheme_id=scheme_id,
        limit=limit,
        skip=skip
    )


@router.put("/admin/application/{application_id}/status")
async def update_application_status(
    application_id: str,
    status: str = Query(..., description="New status"),
    notes: Optional[str] = Query(None, description="Admin notes"),
    service: SchemeService = Depends(get_scheme_service),
    current_user: dict = Depends(role_required(["admin", "customadmin", "superadmin"]))
):
    """
    Update scheme application status (Admin only)
    """
    admin_email = current_user.get("email")
    return await service.update_application_status(
        application_id=application_id,
        status=status,
        admin_email=admin_email,
        notes=notes
    )


print("✅ Schemes Routes Loaded Successfully")