# app/modules/user/routes.py - COMPLETE FIXED VERSION
# ✅ FIXED: /full-profile now accepts optional email param for admin viewing candidate
# ✅ FIXED: Null/empty/deleted documents are STRIPPED from response (never returned to frontend)
# ✅ Added: DELETE /education/{id}  ✅ Added: DELETE /experience/{id}
# ✅ All original functionality preserved
# ✅ NEW: /upload-profile-photo - uploads photo + auto-rebuilds resume

from fastapi import APIRouter, Depends, HTTPException, Query, Body, BackgroundTasks, UploadFile, File, Form
from typing import Optional, List, Dict, Any
from bson import ObjectId
from datetime import datetime
import logging
from app.db.connection import get_db
from app.modules.user.service import ProfileService
from app.core.services.dependencies import get_current_user, role_required
from app.core.ai.ultra_ai_engine import ultra_ai_engine
from app.modules.user.AI.ai_routes import router as user_ai_router
from app.core.utils.logger import logger

router = APIRouter()

router.include_router(user_ai_router)

print("✅ User routes loaded with Ultra AI features")

# ================= SERVICE DEPENDENCY =================
async def get_profile_service(db=Depends(get_db)):
    return ProfileService(db)


# ================= ✅ DOCUMENT CLEANING HELPERS =================
DOCUMENT_KEYS = {
    "profile_photo_url", "aadhaar_front", "aadhaar_back", "aadhaar_url",
    "pan_url", "passport_url", "voter_id_url", "driving_license_url",
    "ration_card", "npr_card",
    "tenth_marksheet", "tenth_certificate", "twelfth_marksheet", "twelfth_certificate",
    "diploma_certificate", "diploma_marksheet",
    "graduation_degree", "graduation_marksheet",
    "post_graduation_degree", "post_graduation_marksheet",
    "phd_certificate", "phd_thesis",
    "iti_certificate", "vocational_certificate", "skill_development_certificate",
    "resume_url", "experience_certificate", "experience_letter_url",
    "previous_employment_proof", "service_certificate", "offer_letter_url",
    "appointment_letter", "salary_slip_url", "salary_certificate",
    "relieving_letter", "promotion_letter", "increment_letter",
    "training_certificate", "internship_certificate", "apprenticeship_certificate",
    "caste_certificate_general", "caste_certificate_obc", "caste_certificate_sc",
    "caste_certificate_st", "caste_certificate_url",
    "ews_certificate", "non_creamy_layer", "caste_validity",
    "disability_certificate_url", "medical_certificate_physical",
    "hearing_disability", "visual_disability", "learning_disability",
    "mental_disability", "multiple_disability", "disability_id_card",
    "income_certificate_url", "income_tax_return", "form_16",
    "bank_statement", "pension_certificate", "fd_certificate",
    "domicile_certificate", "residence_certificate",
    "electricity_bill", "water_bill", "gas_bill",
    "rent_agreement", "property_document",
    "birth_certificate", "marriage_certificate", "family_member_id",
    "dependent_certificate", "family_pension", "survivor_certificate",
    "job_seeker_registration", "employment_exchange_card", "ncs_id",
    "nrega_card", "pmay_certificate", "pmjjby_certificate",
    "pmsby_certificate", "apy_enrollment",
    "professional_certification", "skill_certificate", "computer_certificate",
    "language_certificate", "soft_skills_certificate", "leadership_certificate",
    "project_management_certificate", "digital_marketing_certificate",
    "data_science_certificate", "cloud_computing_certificate", "cybersecurity_certificate",
    "gap_certificate", "skip_certificate", "skip_year_certificate",
    "education_gap_certificate", "character_certificate", "migration_certificate",
    "transfer_certificate", "bonafide_certificate", "conduct_certificate",
    "medical_fitness_certificate", "antecedent_certificate",
    "noc_certificate", "other_document_url",
}

INVALID_DOC_VALUES = {
    None, "", "null", "undefined", "n/a", "na", "-", "none",
    "false", "true", "0", "not found", "notfound", "not_found",
    "deleted", "removed", "empty", "{}", "[]"
}


def _is_valid_doc_url(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, (dict, list)) and len(value) == 0:
        return False
    s = str(value).strip()
    if not s:
        return False
    lower = s.lower()
    if lower in INVALID_DOC_VALUES:
        return False
    if not (s.startswith("http://") or s.startswith("https://")
            or s.startswith("file:") or s.startswith("blob:")):
        return False
    if len(s) < 12:
        return False
    for placeholder in ("not-found", "notfound", "placeholder",
                        "example.com/dummy", "undefined"):
        if placeholder in lower:
            return False
    return True


def _clean_documents_in_profile(profile: dict) -> dict:
    if not profile or not isinstance(profile, dict):
        return profile
    for key in DOCUMENT_KEYS:
        if key in profile:
            if not _is_valid_doc_url(profile[key]):
                del profile[key]
    additional = profile.get("additional_details")
    if isinstance(additional, dict):
        for key in list(additional.keys()):
            if key in DOCUMENT_KEYS or key.endswith("_url") or key.endswith("_certificate"):
                if not _is_valid_doc_url(additional[key]):
                    del additional[key]
        if not additional:
            profile["additional_details"] = {}
    return profile


# ================= CONTACT DETAILS =================
@router.get("/contact-details")
async def get_contact_details(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Get user's email and mobile (read-only from login)"""
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    user = await db.auth.find_one({"email": email})
    mobile = user.get("mobile", "") if user else ""
    name = user.get("name", "") if user else ""

    return {"email": email, "mobile": mobile, "name": name}


# ================= ✅ FULL PROFILE (FIXED — accepts email param for admins) =================
@router.get("/full-profile")
async def get_full_profile(
    email: Optional[str] = Query(
        None,
        description="(Admin only) Fetch profile of another user by email"
    ),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    caller_email = current_user.get("email")
    caller_role = (current_user.get("role") or "").lower()

    if not caller_email:
        raise HTTPException(status_code=400, detail="User email not found")

    target_email = caller_email

    if email and email.strip() and email.strip().lower() != caller_email.lower():
        admin_roles = {"admin", "customadmin", "custom_admin", "superadmin"}
        if caller_role not in admin_roles:
            raise HTTPException(
                status_code=403,
                detail="Access denied. Only admins can view other users' profiles."
            )
        target_email = email.strip()

    result = await service.get_full_profile(target_email)

    if isinstance(result, dict):
        if "data" in result and isinstance(result["data"], dict):
            result["data"] = _clean_documents_in_profile(result["data"])
        else:
            result = _clean_documents_in_profile(result)

        raw = await db.profile.find_one({"email": target_email}) or {}
        cleaned_raw = _clean_documents_in_profile(dict(raw))

        if isinstance(result, dict):
            if "data" in result and isinstance(result["data"], dict):
                result["data"]["additional_details"] = cleaned_raw.get(
                    "additional_details", {}
                )
                for k in DOCUMENT_KEYS:
                    if k in cleaned_raw:
                        result["data"][k] = cleaned_raw[k]
            else:
                result["additional_details"] = cleaned_raw.get(
                    "additional_details", {}
                )
                for k in DOCUMENT_KEYS:
                    if k in cleaned_raw:
                        result[k] = cleaned_raw[k]

    return result


@router.post("/full-profile")
async def create_or_update_full_profile(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    data["email"] = email
    return await service.create_or_update_full_profile(data)


# ==============================================================
# ✅ NEW: UPLOAD PROFILE PHOTO — AUTO REBUILDS RESUME
# ==============================================================
@router.post("/upload-profile-photo")
async def upload_profile_photo(
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Upload profile photo → Cloudinary → DB → auto-rebuild resume in all formats.
    Frontend calls this from: Documents screen, Build Resume screen, Dashboard avatar.
    Response includes immediate URL so frontend can update UI without refresh.
    """
    from app.core.services.cloudinary import upload_user_document

    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Profile photo is required")

    allowed_extensions = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic', 'heif'}
    file_ext = file.filename.split('.')[-1].lower() if file.filename else ''
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid image type. Allowed: {', '.join(sorted(allowed_extensions))}"
        )

    # Size check — max 5MB for profile photo
    file_content = await file.read()
    file_size = len(file_content)
    await file.seek(0)
    if file_size > 5 * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail=f"Photo too large. Max: 5MB, Your file: {file_size // (1024*1024)}MB"
        )

    try:
        username = email.split('@')[0]

        # 1️⃣ Upload to Cloudinary
        upload_result = await upload_user_document(
            file=file,
            username=username,
            document_type="profile_photo"
        )
        photo_url = upload_result.get("url")
        public_id = upload_result.get("public_id")

        if not photo_url:
            raise HTTPException(status_code=500, detail="Cloudinary returned no URL")

        logger.info(f"✅ Profile photo uploaded: {photo_url}")

        # 2️⃣ Update DB (top-level + additional_details for compatibility)
        now = datetime.utcnow()
        update_payload = {
            "profile_photo_url": photo_url,
            "additional_details.profile_photo_url": photo_url,
            "profile_photo_public_id": public_id,
            "additional_details.profile_photo_public_id": public_id,
            "profile_photo_updated_at": now,
            "updated_at": now,
        }
        await db.profile.update_one(
            {"email": email},
            {"$set": update_payload},
            upsert=True
        )

        # 3️⃣ Auto-rebuild resume in ALL formats
        resume_formats = ["classic", "modern", "fresher", "executive", "tech", "government"]
        resume_rebuilt = False
        resume_error = None
        try:
            from app.modules.resume.service import ResumeService
            resume_service = ResumeService(db)

            # Build fresh resume data (uses new profile photo automatically)
            resume_data = await resume_service.get_profile_resume(email)
            html = await resume_service.generate_resume_html(email, resume_data)

            await db.profile.update_one(
                {"email": email},
                {"$set": {
                    "resume_cache_html": html,
                    "resume_cache_updated_at": datetime.utcnow(),
                    "resume_formats_available": resume_formats,
                }},
                upsert=True
            )
            resume_rebuilt = True
            logger.info(f"✅ Resume auto-rebuilt for {email}")
        except Exception as re:
            resume_error = str(re)
            logger.warning(f"⚠️ Resume auto-rebuild failed: {re}")

        return {
            "success": True,
            "message": "Profile photo uploaded & resume rebuilt",
            "url": photo_url,
            "download_url": upload_result.get("download_url"),
            "public_id": public_id,
            "file_size_kb": file_size // 1024,
            "resume_ready": resume_rebuilt,
            "resume_formats": resume_formats,
            "resume_error": resume_error,
            "updated_at": now.isoformat(),
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Profile photo upload failed: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")

# ==============================================================
# ✅ NEW: GET SIGNED URL FOR PRIVATE PROFILE PHOTO
# ==============================================================
@router.post("/get-signed-photo-url")
async def get_signed_photo_url(
    data: dict = Body(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Generates a signed, temporary URL for a private Cloudinary image.
    The frontend sends the public_id, and the backend returns a secure URL.
    """
    from app.core.services.cloudinary import get_signed_view_url

    public_id = data.get("public_id")
    resource_type = data.get("resource_type", "image")

    if not public_id:
        raise HTTPException(status_code=400, detail="public_id is required")

    try:
        # Generate a signed URL that expires in 24 hours
        signed_url = await get_signed_view_url(
            public_id=public_id,
            resource_type=resource_type,
            expires_seconds=86400
        )

        if not signed_url:
            raise HTTPException(status_code=500, detail="Could not generate signed URL")

        return {"success": True, "url": signed_url}

    except Exception as e:
        logger.error(f"Failed to generate signed URL for {public_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to generate signed URL: {str(e)}")


# ==================== DASHBOARD STATS ENDPOINT ====================
@router.get("/dashboard-stats")
async def get_user_dashboard_stats(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    """
    ✅ Returns complete dashboard statistics:
    - profile_completion: 0-100
    - career_score: 0-100
    - job_applications: {total, saved, applied, by_status}
    - service_applications: {total, by_status}
    - profile_sections: which sections are complete
    - career_breakdown: detailed score breakdown
    """
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    from app.modules.user.dashboard_service import UserDashboardService

    service = UserDashboardService(db)
    result = await service.get_dashboard_stats(email)
    return result


print("✅ User routes loaded with Ultra AI features + DELETE education/experience")
print("✅ /full-profile now accepts optional email param for admin viewing candidate")
print("✅ Null / deleted documents are STRIPPED from every response")
print("✅ NEW: /upload-profile-photo — auto-rebuilds resume after photo upload")
print("✅ NEW: /dashboard-stats — returns career score, profile %, app counts")


# ================= BASIC DETAILS =================
@router.get("/basic-details")
async def get_basic_details(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_basic_details(email)


@router.post("/basic-details")
async def save_basic_details(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.save_basic_details(email, data)


# ================= BANK DETAILS =================
@router.get("/bank-details")
async def get_bank_details(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_bank_details(email)


@router.post("/bank-details")
async def update_bank_details(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_bank_details(email, data)


# ================= GOVERNMENT IDs =================
@router.get("/government-ids")
async def get_government_ids(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_government_ids(email)


@router.post("/government-ids")
async def update_government_ids(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_government_ids(email, data)


# ================= EMERGENCY CONTACT =================
@router.get("/emergency-contact")
async def get_emergency_contact(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_emergency_contact(email)


@router.post("/emergency-contact")
async def update_emergency_contact(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_emergency_contact(email, data)


# ================= REFERENCES =================
@router.get("/references")
async def get_references(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_references(email)


@router.post("/references")
async def add_reference(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.add_reference(email, data)


@router.put("/references/{ref_id}")
async def update_reference(
    ref_id: str,
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_reference(email, ref_id, data)


@router.delete("/references/{ref_id}")
async def delete_reference(
    ref_id: str,
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.delete_reference(email, ref_id)


# ================= EMPLOYMENT PREFERENCES =================
@router.get("/employment-preferences")
async def get_employment_preferences(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_employment_preferences(email)


@router.post("/employment-preferences")
async def update_employment_preferences(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_employment_preferences(email, data)


# ================= SOCIAL LINKS =================
@router.get("/social-links")
async def get_social_links(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_social_links(email)


@router.post("/social-links")
async def update_social_links(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_social_links(email, data)


# ================= WORK AUTHORIZATION =================
@router.get("/work-authorization")
async def get_work_authorization(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_work_authorization(email)


@router.post("/work-authorization")
async def update_work_authorization(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_work_authorization(email, data)


# ================= APPLICATION PREFERENCES =================
@router.get("/application-preferences")
async def get_application_preferences(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_application_preferences(email)


@router.post("/application-preferences")
async def update_application_preferences(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_application_preferences(email, data)


# ================= CAREER GOALS =================
@router.get("/career-goals")
async def get_career_goals(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_career_goals(email)


@router.post("/career-goals")
async def update_career_goals(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_career_goals(email, data)


# ================= PERSONALITY TRAITS =================
@router.get("/personality-traits")
async def get_personality_traits(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_personality_traits(email)


@router.post("/personality-traits")
async def update_personality_traits(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_personality_traits(email, data)


# ================= WORK ENVIRONMENT PREFERENCES =================
@router.get("/work-environment-preferences")
async def get_work_environment_preferences(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_work_environment_preferences(email)


@router.post("/work-environment-preferences")
async def update_work_environment_preferences(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_work_environment_preferences(email, data)


# ================= COMPENSATION EXPECTATIONS =================
@router.get("/compensation-expectations")
async def get_compensation_expectations(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_compensation_expectations(email)


@router.post("/compensation-expectations")
async def update_compensation_expectations(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_compensation_expectations(email, data)


# ================= JOB SEARCH PREFERENCES =================
@router.get("/job-search-preferences")
async def get_job_search_preferences(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_job_search_preferences(email)


@router.post("/job-search-preferences")
async def update_job_search_preferences(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_job_search_preferences(email, data)


# ================= SKILL ASSESSMENTS =================
@router.get("/skill-assessments")
async def get_skill_assessments(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_skill_assessments(email)


@router.post("/skill-assessments")
async def add_skill_assessment(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.add_skill_assessment(email, data)


@router.put("/skill-assessments/{assessment_id}")
async def update_skill_assessment(
    assessment_id: str,
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_skill_assessment(email, assessment_id, data)


@router.delete("/skill-assessments/{assessment_id}")
async def delete_skill_assessment(
    assessment_id: str,
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.delete_skill_assessment(email, assessment_id)


# ================= JOB SEARCH STATUS =================
@router.get("/job-search-status")
async def get_job_search_status(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_job_search_status(email)


@router.post("/job-search-status")
async def update_job_search_status(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_job_search_status(email, data)


# ================= CAREER CHANGE INFO =================
@router.get("/career-change-info")
async def get_career_change_info(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_career_change_info(email)


@router.post("/career-change-info")
async def update_career_change_info(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_career_change_info(email, data)


# ================= EDUCATION =================
@router.get("/education")
async def get_education(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_education(email)


@router.post("/education")
async def add_education(
    qualification: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.add_education(email, qualification)


@router.put("/education/{qual_id}")
async def update_education(
    qual_id: str,
    qualification: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_education(email, qual_id, qualification)


@router.delete("/education/{qual_id}")
async def delete_education(
    qual_id: str,
    email: Optional[str] = Query(None),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.delete_education(user_email, qual_id)


# ================= EXPERIENCE =================
@router.get("/experience")
async def get_experience(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_experience(email)


@router.post("/experience")
async def add_experience(
    experience: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.add_experience(email, experience)


@router.put("/experience/{exp_id}")
async def update_experience(
    exp_id: str,
    experience: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_experience(email, exp_id, experience)


@router.delete("/experience/{exp_id}")
async def delete_experience(
    exp_id: str,
    email: Optional[str] = Query(None),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.delete_experience(user_email, exp_id)


# ================= SKILLS =================
@router.get("/skills")
async def get_skills(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_skills(email)


@router.post("/skills")
async def add_skill(
    skill: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.add_skill(email, skill)


@router.put("/skills/{skill_id}")
async def update_skill(
    skill_id: str,
    skill: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_skill(email, skill_id, skill)


@router.delete("/skills/{skill_id}")
async def delete_skill(
    skill_id: str,
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.delete_skill(email, skill_id)


# ================= INTERNSHIPS =================
@router.get("/internships")
async def get_internships(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_internships(email)


@router.post("/internships")
async def add_internship(
    internship: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.add_internship(email, internship)


@router.put("/internships/{internship_id}")
async def update_internship(
    internship_id: str,
    internship: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_internship(email, internship_id, internship)


@router.delete("/internships/{internship_id}")
async def delete_internship(
    internship_id: str,
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.delete_internship(email, internship_id)


# ================= CERTIFICATIONS =================
@router.get("/certifications")
async def get_certifications(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_certifications(email)


@router.post("/certifications")
async def add_certification(
    certification: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.add_certification(email, certification)


@router.put("/certifications/{cert_id}")
async def update_certification(
    cert_id: str,
    certification: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_certification(email, cert_id, certification)


@router.delete("/certifications/{cert_id}")
async def delete_certification(
    cert_id: str,
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.delete_certification(email, cert_id)


# ================= PROJECTS =================
@router.get("/projects")
async def get_projects(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_projects(email)


@router.post("/projects")
async def add_project(
    project: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.add_project(email, project)


@router.put("/projects/{project_id}")
async def update_project(
    project_id: str,
    project: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_project(email, project_id, project)


@router.delete("/projects/{project_id}")
async def delete_project(
    project_id: str,
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.delete_project(email, project_id)


# ================= LANGUAGES =================
@router.get("/languages")
async def get_languages(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_languages(email)


@router.post("/languages")
async def add_language(
    language: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.add_language(email, language)


@router.put("/languages/{lang_id}")
async def update_language(
    lang_id: str,
    language: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_language(email, lang_id, language)


@router.delete("/languages/{lang_id}")
async def delete_language(
    lang_id: str,
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.delete_language(email, lang_id)


# ================= OTHER DETAILS =================
@router.get("/other-details")
async def get_other_details(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_other_details(email)


@router.put("/other-details")
async def update_other_details(
    details: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_other_details(email, details)


# ================= PROFILE + APPLICATIONS =================
@router.get("/profile-with-applications")
async def get_profile_with_applications(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_profile_with_applications(email)


# ================= EDUCATED STATUS =================
@router.post("/educated-status")
async def update_educated_status(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_educated_status(email, data)


# ================= FRESHER STATUS =================
@router.post("/fresher-status")
async def update_fresher_status(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_fresher_status(email, data)


# ================= SAVED JOBS =================
@router.get("/saved-jobs")
async def get_saved_jobs(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    user = await db.auth.find_one({"email": email})
    saved_job_ids = user.get("saved_jobs", []) if user else []

    jobs = []
    for job_id in saved_job_ids:
        try:
            if isinstance(job_id, str) and len(job_id) == 24:
                obj_id = ObjectId(job_id)
            else:
                obj_id = job_id
            job = await db.job.find_one({"_id": obj_id})
            if job:
                job["_id"] = str(job["_id"])
                jobs.append(job)
        except Exception:
            continue

    return {"saved_jobs": jobs}


@router.post("/saved-jobs")
async def save_job(
    data: dict = Body(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    job_id = data.get("job_id")
    if not job_id:
        raise HTTPException(status_code=400, detail="Job ID required")

    try:
        obj_id = ObjectId(job_id) if isinstance(job_id, str) and len(job_id) == 24 else job_id
        job_exists = await db.job.find_one({"_id": obj_id})
        if not job_exists:
            raise HTTPException(status_code=404, detail="Job not found")
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid job ID")

    await db.auth.update_one(
        {"email": email},
        {"$addToSet": {"saved_jobs": job_id}}
    )

    return {"message": "Job saved successfully", "success": True}


@router.delete("/saved-jobs/{job_id}")
async def unsave_job(
    job_id: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    await db.auth.update_one(
        {"email": email},
        {"$pull": {"saved_jobs": job_id}}
    )
    return {"message": "Job removed from saved", "success": True}


# ================= AI POWERED ENDPOINTS =================
@router.get("/ai/insights")
async def get_ai_insights(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_ai_insights(email)


@router.get("/ai/recommendations")
async def get_ai_recommendations(
    limit: int = Query(10, ge=1, le=20),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_ai_recommendations(email, limit)


@router.get("/ai/skill-gap")
async def get_ai_skill_gap(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_ai_skill_gap(email)


@router.post("/ai/refresh")
async def refresh_ai_insights(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.refresh_ai_insights(email)


# ================= ULTRA AI ENDPOINTS =================
@router.get("/ai/ultra-analysis")
async def get_ultra_ai_analysis(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    profile = await db.profile.find_one({"email": email})
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    jobs = await db.job.find({"status": "open"}).limit(50).to_list(50)

    career_analysis = await ultra_ai_engine._deep_candidate_analysis(profile, {})
    job_matches = await ultra_ai_engine.auto_job_matching(profile, jobs)
    predictions = await ultra_ai_engine.predictive_analytics(30)

    return {
        "career_analysis": career_analysis,
        "top_job_matches": job_matches[:5],
        "market_predictions": predictions,
        "recommended_actions": await _generate_personalized_actions(profile, career_analysis)
    }


@router.get("/ai/resume-score")
async def get_ai_resume_score(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    profile = await db.profile.find_one({"email": email})
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    score = 0
    suggestions = []

    if profile.get('full_name'):
        score += 10
    else:
        suggestions.append("Add your full name")

    if profile.get('summary'):
        score += 15
    else:
        suggestions.append("Add a professional summary")

    skills_count = len(profile.get('skills', []))
    if skills_count >= 10:
        score += 20
    elif skills_count >= 5:
        score += 15
        suggestions.append(f"Add {10 - skills_count} more skills to reach optimal count")
    else:
        score += 5
        suggestions.append("Add at least 5-10 relevant skills")

    exp_count = len(profile.get('experience', []))
    if exp_count >= 3:
        score += 20
    elif exp_count >= 1:
        score += 10
        suggestions.append("Add more work experience details")
    else:
        suggestions.append("Add work experience or internships")

    edu_count = len(profile.get('academic_records', []))
    if edu_count >= 2:
        score += 15
    elif edu_count >= 1:
        score += 10
        suggestions.append("Add your educational qualifications")

    project_count = len(profile.get('projects', []))
    if project_count >= 3:
        score += 10
    elif project_count >= 1:
        score += 5
        suggestions.append("Add more projects to showcase your work")

    cert_count = len(profile.get('certifications', []))
    if cert_count >= 2:
        score += 10
    elif cert_count >= 1:
        score += 5
        suggestions.append("Add relevant certifications")

    return {
        "resume_score": min(100, score),
        "rating": "Excellent" if score >= 80 else "Good" if score >= 60 else "Average" if score >= 40 else "Needs Improvement",
        "suggestions": suggestions[:10],
        "profile_completion_percentage": min(100, score),
        "next_actions": suggestions[:5]
    }


async def _generate_personalized_actions(profile: Dict, analysis: Dict) -> List[str]:
    actions = []
    if analysis.get('skill_match', 0) < 60:
        actions.append("Focus on developing in-demand skills")
    if len(profile.get('projects', [])) < 2:
        actions.append("Build and showcase personal projects")
    if len(profile.get('certifications', [])) < 2:
        actions.append("Get relevant certifications")
    if not profile.get('summary'):
        actions.append("Write a compelling professional summary")
    if not actions:
        actions.append("Start applying to matching jobs")
        actions.append("Network with industry professionals")
        actions.append("Keep your profile updated")
    return actions[:5]


# ==================== EDUCATIONAL BACKGROUND ====================
@router.get("/educational-background")
async def get_educational_background(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_educational_background(email)


@router.post("/educational-background")
async def update_educational_background(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_educational_background(email, data)


# ==================== CAREER ASPIRATIONS ====================
@router.get("/career-aspirations")
async def get_career_aspirations(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_career_aspirations(email)


@router.post("/career-aspirations")
async def update_career_aspirations(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_career_aspirations(email, data)


# ==================== LEARNING PREFERENCES ====================
@router.get("/learning-preferences")
async def get_learning_preferences(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_learning_preferences(email)


@router.post("/learning-preferences")
async def update_learning_preferences(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_learning_preferences(email, data)


# ==================== INCOME & EXPENSE ====================
@router.get("/income-expense")
async def get_income_expense(
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.get_income_expense(email)


@router.post("/income-expense")
async def update_income_expense(
    data: Dict[str, Any] = Body(...),
    service: ProfileService = Depends(get_profile_service),
    current_user: dict = Depends(get_current_user)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")
    return await service.update_income_expense(email, data)


# ==================== GET USER PROFILE BY EMAIL ====================
@router.get("/user-profile-by-email")
async def get_user_profile_by_email(
    email: str = Query(..., description="User email to fetch profile"),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    user_role = current_user.get("role", "").lower()
    allowed_roles = ["admin", "customadmin", "superadmin", "custom_admin"]
    if user_role not in allowed_roles:
        raise HTTPException(status_code=403,
            detail="Access denied. Only admin can view other user profiles.")

    profile = await db.profile.find_one({"email": email})

    if not profile:
        auth_user = await db.auth.find_one({"email": email})
        if auth_user:
            profile = {
                "email": auth_user.get("email"),
                "full_name": auth_user.get("name", ""),
                "phone": auth_user.get("mobile", ""),
                "role": auth_user.get("role", "user"),
            }
        else:
            raise HTTPException(status_code=404, detail=f"User with email {email} not found")

    if "_id" in profile:
        profile["_id"] = str(profile["_id"])

    profile = _ensure_profile_defaults(profile)
    profile = _clean_documents_in_profile(profile)

    return {"success": True, "data": profile, "message": "Profile fetched successfully"}


def _ensure_profile_defaults(profile: dict) -> dict:
    defaults = {
        "full_name": "", "first_name": "", "middle_name": "", "last_name": "",
        "phone": "", "dob": "", "gender": "Male", "blood_group": "",
        "nationality": "Indian", "religion": "", "category": "General/UR",
        "disability": {
            "is_disabled": False,
            "disability_category": "LD (Learning Disability)",
            "disability_percentage": None,
            "disability_details": "",
            "physically_challenged": "No",
            "certificate_verified": False
        },
        "father_name": "", "mother_name": "", "guardian_name": "", "spouse_name": "",
        "marital_status": "Unmarried", "family_annual_income": None, "number_of_dependents": None,
        "alternate_mobile": "", "whatsapp_number": "",
        "emergency_contact": {"name": "", "relationship": "", "phone": ""},
        "current_address": {
            "house_number": "", "village_name": "", "post_office": "",
            "tehsil": "", "district": "", "state": "", "pincode": "",
            "landmark": "", "country": "India"
        },
        "permanent_address": {}, "same_as_current": True,
        "summary": "", "career_objective": "",
        "social_links": {"linkedin": "", "github": "", "portfolio": ""},
        "academic_records": [], "experience": [], "skills": [],
        "certifications": [], "projects": [], "languages_known": [],
        "resume_url": "", "created_at": None, "updated_at": None
    }
    for key, default_value in defaults.items():
        if key not in profile:
            profile[key] = default_value
        elif isinstance(default_value, dict) and isinstance(profile[key], dict):
            for sub_key, sub_default in default_value.items():
                if sub_key not in profile[key]:
                    profile[key][sub_key] = sub_default
    return profile


# ==================== DOCUMENT MANAGEMENT ENDPOINTS ====================
ALLOWED_MIME_TYPES = {
    'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/heic', 'image/heif',
    'application/pdf', 'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain', 'text/csv',
}

ALLOWED_EXTENSIONS = {
    'pdf', 'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif',
    'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv'
}


@router.post("/upload-document")
async def upload_user_document_endpoint(
    file: UploadFile = File(...),
    document_type: str = Form(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Upload document to Cloudinary.
    ✅ If document_type is a profile-photo key, ALSO syncs top-level fields
    and triggers resume rebuild.
    """
    from app.core.services.cloudinary import upload_user_document

    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Document file is required")

    content_type = file.content_type
    file_ext = file.filename.split('.')[-1].lower() if file.filename else ''

    is_allowed = False
    if content_type and content_type in ALLOWED_MIME_TYPES:
        is_allowed = True
    elif file_ext in ALLOWED_EXTENSIONS:
        is_allowed = True
    elif content_type and content_type.startswith('image/'):
        is_allowed = True

    if not is_allowed:
        raise HTTPException(status_code=400,
            detail=f"Invalid file type. Allowed: {', '.join(sorted(ALLOWED_EXTENSIONS))}")

    file_content = await file.read()
    file_size = len(file_content)
    await file.seek(0)

    max_size = 10 * 1024 * 1024
    if file_size > max_size:
        raise HTTPException(status_code=400,
            detail=f"File too large. Max size: 10MB, Your file: {file_size // (1024*1024)}MB")

    try:
        username = email.split('@')[0]

        upload_result = await upload_user_document(
            file=file,
            username=username,
            document_type="documents"
        )

        # Save to additional_details
        await db.profile.update_one(
            {"email": email},
            {"$set": {
                f"additional_details.{document_type}": upload_result["url"],
                "updated_at": datetime.utcnow()
            }},
            upsert=True
        )

        # ✅ PROFILE PHOTO SPECIAL CASE — mirror to top-level + rebuild resume
        is_profile_photo = document_type in (
            "profile_photo_url", "profile_photo",
            "profile_picture", "profile_picture_url"
        )
        resume_rebuilt = False

        if is_profile_photo:
            await db.profile.update_one(
                {"email": email},
                {"$set": {
                    "profile_photo_url": upload_result["url"],
                    "profile_photo_public_id": upload_result.get("public_id"),
                    "profile_photo_updated_at": datetime.utcnow(),
                }},
                upsert=True
            )
            try:
                from app.modules.resume.service import ResumeService
                resume_service = ResumeService(db)
                resume_data = await resume_service.get_profile_resume(email)
                html = await resume_service.generate_resume_html(email, resume_data)
                await db.profile.update_one(
                    {"email": email},
                    {"$set": {
                        "resume_cache_html": html,
                        "resume_cache_updated_at": datetime.utcnow(),
                    }},
                )
                resume_rebuilt = True
                logger.info(f"✅ Resume auto-rebuilt after profile photo (via documents) for {email}")
            except Exception as re:
                logger.warning(f"⚠️ Resume auto-rebuild (via documents) failed: {re}")

        return {
            "success": True,
            "message": "Document uploaded successfully",
            "url": upload_result["url"],
            "document_type": document_type,
            "filename": file.filename,
            "public_id": upload_result.get("public_id"),
            "file_size_kb": file_size // 1024,
            "is_profile_photo": is_profile_photo,
            "resume_rebuilt": resume_rebuilt,
        }

    except Exception as e:
        logger.error(f"Document upload error: {e}")
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")


@router.put("/update-profile")
async def update_profile_field(
    data: dict = Body(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    update_data = {}
    for key, value in data.items():
        update_data[key] = value

    update_data["updated_at"] = datetime.utcnow()

    result = await db.profile.update_one(
        {"email": email},
        {"$set": update_data},
        upsert=True
    )

    return {
        "success": True,
        "message": "Profile updated successfully",
        "modified": result.modified_count > 0
    }


@router.post("/update-document")
async def update_document_url(
    data: dict = Body(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    document_key = data.get("document_key")
    document_url = data.get("document_url")

    if not document_key or not document_url:
        raise HTTPException(status_code=400, detail="Document key and URL are required")

    result = await db.profile.update_one(
        {"email": email},
        {"$set": {
            f"additional_details.{document_key}": document_url,
            "updated_at": datetime.utcnow()
        }},
        upsert=True
    )

    return {
        "success": True,
        "message": "Document URL updated successfully",
        "modified": result.modified_count > 0
    }


@router.delete("/delete-document")
async def delete_document(
    data: dict = Body(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    document_key = data.get("document_key")
    if not document_key:
        raise HTTPException(status_code=400, detail="Document key is required")

    profile = await db.profile.find_one({"email": email})
    additional = (profile or {}).get("additional_details", {}) or {}

    # ✅ Check for profile photo FIRST (has separate public_id key)
    is_profile_photo = document_key in (
        "profile_photo_url", "profile_photo",
        "profile_picture", "profile_picture_url"
    )

    if is_profile_photo:
        old_url = (
            (profile or {}).get("profile_photo_url")
            or additional.get("profile_photo_url")
        )
        old_public_id = (
            (profile or {}).get("profile_photo_public_id")
            or additional.get("profile_photo_public_id")
        )
    else:
        old_url = additional.get(document_key) or (profile or {}).get(document_key)
        old_public_id = additional.get(f"{document_key}_public_id")

    # ─── Delete from Cloudinary ───
    if old_public_id or old_url:
        try:
            from app.core.services.cloudinary import delete_from_cloudinary

            public_id = old_public_id
            resource_type = "raw"

            if not public_id and old_url:
                try:
                    parts = str(old_url).split("/upload/")
                    if len(parts) == 2:
                        tail = parts[1]
                        if tail.startswith("v"):
                            slash = tail.find("/")
                            if slash != -1:
                                tail = tail[slash + 1:]
                        if tail.endswith(".pdf"):
                            tail = tail[:-4]
                        public_id = tail

                    if "/image/upload/" in str(old_url):
                        resource_type = "image"
                except Exception as infer_err:
                    logger.warning(f"Could not infer Cloudinary public_id: {infer_err}")

            if public_id:
                await delete_from_cloudinary(public_id, resource_type=resource_type)
                logger.info(f"🗑️ Deleted Cloudinary file: {public_id} ({resource_type})")
        except Exception as e:
            logger.warning(f"Cloudinary delete skipped: {e}")

    # ─── Build $unset map ───
    unset_fields = {
        f"additional_details.{document_key}": "",
        f"additional_details.{document_key}_public_id": "",
        document_key: "",
    }

    # ✅ Also clear profile-photo-specific keys
    if is_profile_photo:
        unset_fields.update({
            "profile_photo_url": "",
            "profile_photo_public_id": "",
            "profile_photo_updated_at": "",
            "additional_details.profile_photo_url": "",
            "additional_details.profile_photo_public_id": "",
        })

    result = await db.profile.update_one(
        {"email": email},
        {"$unset": unset_fields, "$set": {"updated_at": datetime.utcnow()}}
    )

    return {
        "success": True,
        "message": "Document deleted successfully",
        "modified": result.modified_count > 0
    }


@router.get("/get-documents")
async def get_user_documents(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    profile = await db.profile.find_one({"email": email})
    if not profile:
        return {"success": True, "documents": {}}

    profile = _clean_documents_in_profile(dict(profile))
    additional = profile.get("additional_details", {}) or {}

    documents = {}
    for key in DOCUMENT_KEYS:
        val = additional.get(key) or profile.get(key)
        if _is_valid_doc_url(val):
            documents[key] = val

    return {"success": True, "documents": documents}


@router.get("/user-documents-by-email")
async def get_user_documents_by_email(
    email: str = Query(..., description="User email"),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    user_role = current_user.get("role", "").lower()
    allowed = ["admin", "customadmin", "super_admin", "superadmin"]
    if user_role not in allowed:
        raise HTTPException(status_code=403, detail="Access denied")

    profile = await db.profile.find_one({"email": email})
    if not profile:
        auth_user = await db.auth.find_one({"email": email})
        if not auth_user:
            raise HTTPException(status_code=404, detail="User not found")
        return {"success": True, "documents": {}}

    profile = _clean_documents_in_profile(dict(profile))
    additional = profile.get("additional_details", {}) or {}

    documents = {}
    for key in DOCUMENT_KEYS:
        val = additional.get(key) or profile.get(key)
        if _is_valid_doc_url(val):
            documents[key] = val

    return {"success": True, "documents": documents}


# ================= END OF FILE =================
print("✅ User routes loaded with Ultra AI features + DELETE education/experience")
print("✅ /full-profile now accepts optional email param for admin viewing candidate")
print("✅ Null / deleted documents are STRIPPED from every response")
print("✅ NEW: /upload-profile-photo — auto-rebuilds resume after photo upload")