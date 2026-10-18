# app/modules/resume/routes.py - COMPLETE VERSION
# ✅ NEW: /rebuild — rebuilds resume in all formats
# ✅ NEW: /profile-photo — lightweight endpoint for current photo URL
# ✅ NEW: /rebuild now sets resume_generated_at + has_generated_resume
# ✅ FIXED: Profile completion now correctly credits generated resumes

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, BackgroundTasks
from typing import Optional, List, Dict, Any
from bson import ObjectId
from datetime import datetime
import logging

from app.core.services.dependencies import get_current_user, role_required
from app.db.connection import get_db
from app.modules.resume.service import ResumeService
from app.modules.resume.AI.ai_routes import router as resume_ai_router
from app.core.utils.logger import logger

logger = logging.getLogger(__name__)

router = APIRouter()

# Include AI routes
router.include_router(resume_ai_router)


async def get_resume_service(db=Depends(get_db)):
    return ResumeService(db)


# ==================== RESUME UPLOAD AND PARSE ====================

@router.post("/upload-resume")
async def upload_user_resume(
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    User uploads resume to Cloudinary
    Folder: RojgarNest_uploads/users_data/{username}/resume/
    """
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Resume file is required")

    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    allowed_extensions = ['pdf', 'doc', 'docx']
    file_ext = file.filename.split('.')[-1].lower() if file.filename else ''
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type. Allowed: {', '.join(allowed_extensions)}"
        )

    try:
        username = email.split('@')[0]

        from app.core.services.cloudinary import upload_user_document

        await file.seek(0)

        upload_result = await upload_user_document(
            file=file,
            username=username,
            document_type="resume"
        )

        now = datetime.utcnow()

        await db.profile.update_one(
            {"email": email},
            {"$set": {
                "resume_url": upload_result["url"],
                "resume_public_id": upload_result.get("public_id"),
                "resume_name": file.filename,
                "resume_uploaded_at": now,
                # ✅ ALSO mark as "has resume" for dashboard counting
                "has_generated_resume": True,
                "updated_at": now,
            }},
            upsert=True
        )

        service = await get_resume_service(db=db)
        resume_data = {
            "filename": file.filename,
            "file_url": upload_result["url"],
            "file_public_id": upload_result.get("public_id"),
            "file_size_kb": upload_result.get("size_bytes", 0) // 1024,
            "file_type": file_ext,
            "is_primary": True,
            "uploaded_at": now
        }
        await service.save_resume_record(email, resume_data)

        return {
            "success": True,
            "message": "Resume uploaded successfully to Cloudinary",
            "resume_url": upload_result["url"],
            "resume_name": file.filename,
            "folder_path": upload_result.get("folder_path"),
            "public_id": upload_result.get("public_id")
        }

    except Exception as e:
        logger.error(f"❌ Error uploading resume: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to upload resume: {str(e)}")


@router.post("/upload")
async def upload_resume(
    file: UploadFile = File(...),
    service: ResumeService = Depends(get_resume_service),
    current_user: dict = Depends(get_current_user)
):
    """Upload and auto-parse resume using AI"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    return await service.upload_and_parse_resume(email, file)


@router.get("/my-resumes")
async def get_my_resumes(
    service: ResumeService = Depends(get_resume_service),
    current_user: dict = Depends(get_current_user)
):
    """Get all user's resumes"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    return await service.get_user_resumes(email)


@router.get("/primary")
async def get_primary_resume(
    service: ResumeService = Depends(get_resume_service),
    current_user: dict = Depends(get_current_user)
):
    """Get user's primary resume"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    return await service.get_primary_resume(email)


@router.put("/primary/{resume_id}")
async def set_primary_resume(
    resume_id: str,
    service: ResumeService = Depends(get_resume_service),
    current_user: dict = Depends(get_current_user)
):
    """Set a resume as primary"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    return await service.set_primary_resume(email, resume_id)


@router.delete("/{resume_id}")
async def delete_resume(
    resume_id: str,
    service: ResumeService = Depends(get_resume_service),
    current_user: dict = Depends(get_current_user)
):
    """Delete a resume"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    return await service.delete_resume(email, resume_id)


# ==================== PROFILE RESUME VIEW ====================

@router.get("/profile-resume")
async def get_profile_resume(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Get complete user profile in resume format
    """
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    service = await get_resume_service(db=db)
    return await service.get_profile_resume(email)


@router.get("/profile-resume-by-email")
async def get_profile_resume_by_email(
    email: str = Query(..., description="User email to fetch resume"),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Get any user's profile in resume format - For Admin/CustomAdmin only
    """
    user_role = current_user.get("role", "").lower()
    allowed_roles = ["admin", "customadmin", "superadmin", "custom_admin"]

    if user_role not in allowed_roles:
        raise HTTPException(
            status_code=403,
            detail="Access denied. Only admin can view other user resumes."
        )

    service = await get_resume_service(db=db)
    return await service.get_profile_resume(email)


@router.get("/preview")
async def get_resume_preview(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Get resume preview data for frontend display
    """
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    service = await get_resume_service(db=db)
    return await service.get_resume_preview(email)


@router.post("/parse/{resume_id}")
async def parse_resume(
    resume_id: str,
    service: ResumeService = Depends(get_resume_service),
    current_user: dict = Depends(get_current_user)
):
    """Parse existing resume with AI"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    return await service.parse_resume_with_ai(email, resume_id)


@router.post("/ats-optimize")
async def optimize_for_ats(
    job_id: str = Query(..., description="Job ID for optimization"),
    service: ResumeService = Depends(get_resume_service),
    current_user: dict = Depends(get_current_user)
):
    """Get ATS optimization suggestions for resume"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    return await service.get_ats_optimization(email, job_id)


@router.get("/export")
async def export_resume_pdf(
    format: str = Query("json", description="Export format: json or html"),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Export resume in specified format
    """
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    service = await get_resume_service(db=db)
    resume_data = await service.get_profile_resume(email)

    if format == "json":
        return resume_data
    elif format == "html":
        html_content = await service.generate_resume_html(email, resume_data)
        return {"success": True, "html": html_content, "format": "html"}
    else:
        raise HTTPException(status_code=400, detail=f"Unsupported format: {format}")


@router.get("/download")
async def download_resume_pdf(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Generate and download resume as PDF
    """
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    service = await get_resume_service(db=db)
    return await service.generate_resume_pdf(email)


@router.get("/share")
async def share_resume(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Generate shareable link for resume
    """
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    service = await get_resume_service(db=db)
    return await service.generate_shareable_link(email)


# ==============================================================
# ✅ FIXED: REBUILD RESUME — NOW SETS resume_generated_at
# ==============================================================
@router.post("/rebuild")
async def rebuild_resume(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Rebuild resume in all formats using latest profile data.
    Called automatically after profile photo upload, and manually by user.

    ✅ NEW: Sets `resume_generated_at` and `has_generated_resume` flags
    so that user dashboard profile completion correctly credits the
    resume section (+10%) even when no file was uploaded.
    """
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    try:
        service = await get_resume_service(db=db)

        # 1. Build fresh resume data (includes latest photo URL)
        resume_data = await service.get_profile_resume(email)

        # 2. Generate HTML (used for PDF printing)
        html = await service.generate_resume_html(email, resume_data)

        # 3. Cache to profile + set generation flags
        formats = ["classic", "modern", "fresher", "executive", "tech", "government"]
        now = datetime.utcnow()

        await db.profile.update_one(
            {"email": email},
            {"$set": {
                "resume_cache_html": html,
                "resume_cache_updated_at": now,
                "resume_formats_available": formats,
                # ✅ NEW FLAGS — dashboard_service reads these
                "resume_generated_at": now,
                "has_generated_resume": True,
                "updated_at": now,
            }},
            upsert=True
        )

        logger.info(
            f"✅ Resume rebuilt + generation flags set for {email}"
        )

        return {
            "success": True,
            "message": "Resume rebuilt successfully",
            "formats": formats,
            "resume_data": resume_data,
            "rebuilt_at": now.isoformat()
        }
    except Exception as e:
        logger.error(f"Resume rebuild failed: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Rebuild failed: {str(e)}")


# ==============================================================
# ✅ NEW: GET CURRENT PROFILE PHOTO URL (LIGHTWEIGHT)
# ==============================================================
@router.get("/profile-photo")
async def get_profile_photo(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Lightweight endpoint — returns only the current profile photo URL.
    """
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    profile = await db.profile.find_one(
        {"email": email},
        {"profile_photo_url": 1, "additional_details.profile_photo_url": 1}
    )

    photo_url = None
    if profile:
        photo_url = (
            profile.get("profile_photo_url")
            or (profile.get("additional_details") or {}).get("profile_photo_url")
        )

    return {
        "success": True,
        "profile_photo_url": photo_url,
        "has_photo": bool(photo_url)
    }


print("✅ Resume Routes Loaded - Complete profile resume view available")
print("✅ NEW: /rebuild — rebuilds resume AND sets resume_generated_at flag")
print("✅ NEW: /profile-photo — lightweight current photo URL endpoint")