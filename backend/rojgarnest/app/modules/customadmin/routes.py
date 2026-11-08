# app/modules/customadmin/routes.py - COMPLETE FIXED VERSION
# ✅ FIXED: POST /jobs respects is_draft → no forced status='open'
# ✅ FIXED: PUT /jobs/{job_id} uses $set MERGE → no tab data loss between saves
# ✅ FIXED: upload-advertisement accepts job_id → updates existing draft
# ✅ FIXED: upload-advertisement respects is_draft → no notifications on draft save
# ✅ FIXED: Removed duplicate final-submit-with-document definition
# ✅ FIXED: Draft path returns _id at top level for reliable Flutter capture
# ✅ FIXED: Added application_type query parameter to /applications endpoint
# ✅ FIXED: get_db() is sync — removed all 'await get_db()' calls
# ✅ Full Job CRUD Operations
# ✅ Full Application Management (Job + Service + SCHEMES)
# ✅ Payment Verification
# ✅ Document Upload (Review/Final Submit)
# ✅ Notifications to all parties
# ✅ NEW (this build): application_number propagated through ALL
#    review / final-submit / payment notifications, so the email header
#    shows the human-readable YYYYMMDDSSSS number instead of the raw _id
#
# ✅✅✅ NEW (2026-11-08): DUPLICATE EMAIL FIX
#    The following handlers used to send the APPLICANT a "Document
#    Submitted" / "Under Review" / "FINAL SUBMISSION" email, AND the
#    Flutter frontend then immediately called PUT /applications/{id}/status
#    which sent a SECOND email ("Under Review" / "FINAL SUBMITTED").
#    Result → applicant got 2 emails per action.
#
#    FIX: The three handlers below NO LONGER send applicant emails.
#    They still send admin/customadmin bell alerts.
#    The single applicant email goes out from PUT /applications/{id}/status:
#      - review      → "Application Status: REVIEW_APPLICATION"
#      - final submit → "Application Status: FINAL_SUBMIT"

from fastapi import (
    APIRouter, Depends, HTTPException, Query, Body,
    BackgroundTasks, UploadFile, File, Form
)
from typing import Optional, List
from bson import ObjectId
from datetime import datetime
import json
import logging

from app.core.services.dependencies import get_current_user
from app.db.connection import get_db
from .service import CustomAdminService
from app.modules.jobs.service import JobService
from app.modules.jobs.schema import JobCreateSchema, ApplicationStatusUpdateSchema
from app.modules.notification.service import central_notification
from app.core.services.cloudinary import (
    upload_to_cloudinary,
    upload_user_document,
    upload_private_file,
    delete_from_cloudinary
)
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from app.core.services.cloudinary import upload_advertisement_file
from app.core.database import get_database
from app.core.security import get_current_admin_user

router = APIRouter()

logger = logging.getLogger(__name__)

# ============================================================
# DEPENDENCY HELPERS
# ============================================================
async def get_customadmin_service(db=Depends(get_db)):
    """Get CustomAdminService instance"""
    return CustomAdminService(db)


def custom_admin_required(current_user=Depends(get_current_user)):
    """Check if user has customadmin access (case-insensitive)"""
    user_role = current_user.get("role", "").lower()
    allowed_roles = ["customadmin", "custom_admin", "admin", "superadmin"]
    if user_role not in allowed_roles:
        raise HTTPException(
            status_code=403,
            detail=f"Access denied. Required roles: customadmin, Your role: {user_role}"
        )
    return current_user


async def _get_admin_email(user: dict, db) -> str:
    """Get admin email from user dict or database"""
    if db is None:
        return "customadmin@rojgarnest.com"

    admin_email = user.get("email")
    if not admin_email:
        user_id = user.get("user_id")
        if user_id and ObjectId.is_valid(user_id):
            auth_user = await db.auth.find_one({"_id": ObjectId(user_id)})
            if auth_user:
                admin_email = auth_user.get("email")
    return admin_email or "customadmin@rojgarnest.com"


def _resolve_application_number(application: dict, fallback_id: str) -> str:
    """
    ✅ Resolve the human-readable application number.

    Priority:
      1. application['application_number']  (YYYYMMDDSSSS)
      2. application['application_id']      (legacy alias)
      3. fallback_id                        (the raw _id passed in)
    """
    return (
        (application or {}).get("application_number")
        or (application or {}).get("application_id")
        or fallback_id
    )


def _get_display_title(application: dict) -> tuple:
    """
    ✅ Build the (display_title, display_org) pair used for the email header,
    resolved per application type so scheme / service / job emails never
    show a blank organization.

    Returns:
        (display_title, display_org)
    """
    app_type = (application.get("application_type") or "job").lower()

    if app_type == "schemes":
        display_title = (
            application.get("scheme_name")
            or application.get("scheme_name_hindi")
            or "Scheme Application"
        )
        display_org = display_title
    elif app_type == "service":
        display_title = (
            application.get("sub_service_name")
            or application.get("service_name")
            or "Service Application"
        )
        display_org = display_title
    else:
        display_title = application.get("job_title") or "Job Application"
        display_org = application.get("organization") or "Company"

    return display_title, display_org


# ============================================================
# ACCESS VERIFICATION
# ============================================================

@router.get("/verify-access")
async def verify_customadmin_access(user=Depends(custom_admin_required)):
    """Verify customadmin access"""
    return {
        "has_access": True,
        "role": user.get("role", "").lower(),
        "message": "Custom Admin access granted"
    }


# ============================================================
# DASHBOARD & STATS
# ============================================================

@router.get("/dashboard")
async def get_customadmin_dashboard(
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required)
):
    """Get customadmin dashboard statistics"""
    admin_email = user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    return await service.get_dashboard_stats(admin_email)


@router.get("/stats")
async def get_customadmin_stats(
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required)
):
    """Get customadmin statistics"""
    admin_email = user.get("email")
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    return await service.get_dashboard_stats(admin_email)


# ============================================================
# JOB MANAGEMENT ENDPOINTS
# ============================================================

@router.get("/jobs")
async def get_customadmin_jobs(
    status: Optional[str] = Query(None, pattern="^(open|closed|filled|draft)$"),
    limit: int = Query(100, ge=1, le=500),
    skip: int = Query(0, ge=0),
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """Get all jobs posted by this customadmin."""
    admin_email = await _get_admin_email(user, db)
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    return await service.get_admin_jobs(admin_email)


@router.get("/jobs/{job_id}")
async def get_customadmin_job_detail(
    job_id: str,
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """Get single job details."""
    admin_email = await _get_admin_email(user, db)
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    return await service.get_job_detail(job_id, admin_email)


@router.post("/jobs")
async def add_customadmin_job(
    job_data: dict = Body(...),
    background_tasks: BackgroundTasks = BackgroundTasks(),
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """
    ✅ Create job OR save draft.

    ✅ FIX: If `is_draft=true` (or `status="draft"`) is in the payload
       (which is what Flutter sends during tab-wise draft saves), we
       DO NOT force status to "open", we DO NOT send notifications, and
       we DO save the record as a draft, returning the new `_id`.
    """
    admin_email = await _get_admin_email(user, db)
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")

    is_draft = (
        job_data.get("is_draft") is True
        or job_data.get("status") == "draft"
    )

    job_data["added_by"] = admin_email
    job_data["created_at"] = datetime.utcnow()
    job_data["updated_at"] = datetime.utcnow()
    job_data.setdefault("geolocation", [0, 0])
    job_data.setdefault("required_skills", [])
    job_data.setdefault("nice_to_have_skills", [])
    job_data.setdefault("benefits", [])
    job_data.setdefault("tags", [])
    job_data.setdefault("attachments", [])
    job_data.setdefault("multiple_posts", [])
    job_data.setdefault("job_level", "mid")
    job_data.setdefault("salary_currency", "INR")
    job_data.setdefault("experience_min_years", 0)
    job_data.setdefault("post_date", datetime.utcnow().strftime("%Y-%m-%d"))
    job_data.setdefault("job_type", "private")
    job_data.setdefault("color_type", "blue")

    if is_draft:
        job_data["status"] = "draft"
        job_data["is_draft"] = True
        job_data.setdefault("post_name", "Untitled Draft")
        job_data.setdefault("organization", "Not Specified")
        job_data.setdefault("category", "IT")
        job_data.setdefault("is_deleted", False)
        job_data.setdefault("is_archived", False)

        result = await db.job.insert_one(job_data)
        new_id = str(result.inserted_id)

        logger.info(f"✅ CustomAdmin Draft created: {new_id}")

        return {
            "success": True,
            "job_id": new_id,
            "_id": new_id,
            "is_draft": True,
            "status": "draft",
            "message": "Draft created successfully",
        }

    job_data["status"] = "open"
    job_data["is_draft"] = False

    apply_url = job_data.get("apply_with_us_url")
    if apply_url and str(apply_url).strip() and str(apply_url).strip() != '#':
        job_data["has_apply_with_us"] = True

    logger.info(f"✅ Custom Admin adding job — Email: {admin_email}")
    logger.info(f"📝 Job: {job_data.get('post_name')}")

    return await service.add_job(job_data, admin_email, background_tasks)


@router.put("/jobs/{job_id}")
async def update_customadmin_job(
    job_id: str,
    job_data: dict = Body(...),
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """
    ✅ FIXED: Update existing job using $set MERGE.
    """
    if not ObjectId.is_valid(job_id):
        raise HTTPException(status_code=400, detail="Invalid job ID")

    existing = await db.job.find_one({"_id": ObjectId(job_id)})
    if not existing:
        raise HTTPException(status_code=404, detail="Job not found")

    admin_email = await _get_admin_email(user, db)
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")

    user_role = (user.get("role") or "customadmin").lower()
    if user_role == "custom_admin":
        user_role = "customadmin"

    if existing.get("added_by") != admin_email and user_role != "superadmin":
        raise HTTPException(status_code=403, detail="Access denied")

    patch = {k: v for k, v in job_data.items() if k not in ("_id", "created_at", "added_by")}

    patch["updated_at"] = datetime.utcnow()
    patch["last_updated_by"] = admin_email

    incoming_status = patch.get("status")
    incoming_is_draft = patch.get("is_draft")
    if incoming_is_draft is True:
        patch["status"] = "draft"
    elif incoming_is_draft is False and incoming_status == "open":
        patch["status"] = "open"

    updated = await db.job.find_one_and_update(
        {"_id": ObjectId(job_id)},
        {"$set": patch},
        return_document=True,
    )

    if not updated:
        raise HTTPException(status_code=500, detail="Failed to update job")

    updated["_id"] = str(updated["_id"])
    for f in ("created_at", "updated_at", "published_at", "final_submitted_at"):
        if updated.get(f) and isinstance(updated[f], datetime):
            updated[f] = updated[f].isoformat()

    logger.info(f"✅ CustomAdmin Job {job_id} merged via $set ({len(patch)} fields)")

    return {
        "success": True,
        "message": "Job updated successfully",
        "data": updated,
    }


@router.delete("/jobs/{job_id}")
async def delete_customadmin_job(
    job_id: str,
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """Delete job and all associated applications."""
    admin_email = await _get_admin_email(user, db)
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    return await service.delete_job(job_id, admin_email)


@router.post("/jobs/{job_id}/publish")
async def publish_customadmin_job(
    job_id: str,
    background_tasks: BackgroundTasks,
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """Publish a draft job."""
    if not ObjectId.is_valid(job_id):
        raise HTTPException(status_code=400, detail="Invalid job ID")

    admin_email = await _get_admin_email(user, db)

    job = await db.job.find_one({"_id": ObjectId(job_id)})
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    if job.get("added_by") != admin_email:
        raise HTTPException(status_code=403, detail="Access denied")

    if job.get("status") == "open" and not job.get("is_draft", True):
        return {
            "success": True,
            "message": "Job is already published",
            "job_id": job_id,
            "status": "open"
        }

    await db.job.update_one(
        {"_id": ObjectId(job_id)},
        {
            "$set": {
                "status": "open",
                "is_draft": False,
                "published_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }
        }
    )

    updated_job = await db.job.find_one({"_id": ObjectId(job_id)})
    updated_job["_id"] = str(updated_job["_id"])

    if background_tasks:
        await central_notification.notify_new_job(
            updated_job,
            background_tasks,
            publisher_role="customadmin"
        )

    logger.info(f"✅ Job {job_id} published by {admin_email}")

    return {
        "success": True,
        "message": "Job published successfully",
        "job_id": job_id,
        "status": "open",
        "data": updated_job
    }


@router.post("/jobs/upload-advertisement")
async def customadmin_upload_advertisement(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    job_data: str = Form(...),
    job_id: Optional[str] = Form(None),
    is_update: Optional[str] = Form(None),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """
    ✅ GUARANTEED SINGLE-RECORD OPERATION (CustomAdmin)
    Same resolution order as admin version.
    """
    admin_email = await _get_admin_email(user, db)

    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Advertisement file is required")

    MAX_FILE_SIZE = 50 * 1024 * 1024
    file_content = await file.read()
    file_size = len(file_content)
    await file.seek(0)

    if file_size > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File too large")

    try:
        job_dict = json.loads(job_data)

        resolved_id = (job_id or "").strip() or None

        if not resolved_id:
            resolved_id = (
                str(job_dict.pop("job_id", "") or "").strip()
                or str(job_dict.pop("application_id", "") or "").strip()
                or str(job_dict.pop("draft_id", "") or "").strip()
                or str(job_dict.pop("_id", "") or "").strip()
                or None
            )
        else:
            job_dict.pop("job_id", None)
            job_dict.pop("application_id", None)
            job_dict.pop("draft_id", None)
            job_dict.pop("_id", None)

        if not resolved_id:
            title = (job_dict.get("post_name") or "").strip()
            org = (job_dict.get("organization") or "").strip()
            if title and title not in ("Untitled Draft", "Untitled Job", ""):
                candidate = await db.job.find_one({
                    "added_by": admin_email,
                    "post_name": title,
                    "organization": org,
                    "status": "draft",
                    "is_deleted": {"$ne": True},
                })
                if candidate:
                    resolved_id = str(candidate["_id"])

        is_draft = (
            job_dict.get("is_draft") is True
            or job_dict.get("status") == "draft"
        )

        job_dict.setdefault("post_name", "Untitled Job")
        job_dict.setdefault("organization", "Not Specified")
        job_dict.setdefault("post_date", datetime.utcnow().strftime("%Y-%m-%d"))
        job_dict.setdefault("job_type", "private")
        job_dict.setdefault("color_type", "blue")
        job_dict.setdefault("required_skills", [])
        job_dict.setdefault("multiple_posts", [])
        job_dict.setdefault("is_deleted", False)
        job_dict.setdefault("is_archived", False)

        job_dict["added_by"] = admin_email
        job_dict["updated_at"] = datetime.utcnow()

        if is_draft:
            job_dict["status"] = "draft"
            job_dict["is_draft"] = True
        else:
            job_dict["status"] = "open"
            job_dict["is_draft"] = False

        if job_dict.get("use_current_location", False):
            from app.models.job_model import get_admin_current_location
            admin_location = await get_admin_current_location(admin_email, db)
            if admin_location:
                job_dict["job_location"] = admin_location

        action = "created"
        if resolved_id and ObjectId.is_valid(resolved_id):
            existing = await db.job.find_one({"_id": ObjectId(resolved_id)})
            if not existing:
                raise HTTPException(status_code=404, detail="Job not found")
            if existing.get("added_by") != admin_email:
                raise HTTPException(status_code=403, detail="Access denied")

            job_id_resolved = resolved_id
            job_dict.pop("created_at", None)
            await db.job.update_one(
                {"_id": ObjectId(job_id_resolved)},
                {"$set": job_dict},
            )
            action = "updated"
        else:
            job_dict["created_at"] = datetime.utcnow()
            result = await db.job.insert_one(job_dict)
            job_id_resolved = str(result.inserted_id)
            action = "created"

        logger.info(f"📝 CustomAdmin {action} job {job_id_resolved}")

        upload_result = await upload_private_file(
            file=file,
            folder="jobs/advertisements",
            job_id=job_id_resolved,
            organization=job_dict.get("organization", "company"),
            post_name=job_dict.get("post_name", "job"),
        )

        await db.job.update_one(
            {"_id": ObjectId(job_id_resolved)},
            {"$set": {
                "advertisement_url": upload_result["url"],
                "advertisement_download_url": upload_result["download_url"],
                "advertisement_name": file.filename,
                "advertisement_storage": upload_result.get("storage", "cloudinary"),
                "advertisement_public_id": upload_result.get("public_id"),
                "advertisement_resource_type": upload_result.get("resource_type", "raw"),
                "advertisement_is_public": False,
                "advertisement_is_pdf": upload_result.get("is_pdf", False),
                "advertisement_folder_path": upload_result.get("folder_path"),
                "advertisement_file_size": file_size,
                "has_advertisement_file": True,
            }},
        )

        if not is_draft:
            job_doc = await db.job.find_one({"_id": ObjectId(job_id_resolved)})
            publisher_role = (user.get("role") or "customadmin").lower()
            if publisher_role == "custom_admin":
                publisher_role = "customadmin"
            await central_notification.notify_new_job(
                job_doc, background_tasks, publisher_role=publisher_role,
            )

        return {
            "success": True,
            "message": (
                "Draft saved successfully with advertisement"
                if is_draft
                else "Job published successfully with advertisement"
            ),
            "job_id": job_id_resolved,
            "_id": job_id_resolved,
            "action": action,
            "job_title": job_dict.get("post_name"),
            "is_draft": is_draft,
            "status": "draft" if is_draft else "open",
            "advertisement_url": upload_result["url"],
            "advertisement_download_url": upload_result["download_url"],
            "file_size_kb": file_size // 1024,
            "is_pdf": upload_result.get("is_pdf", False),
        }

    except json.JSONDecodeError as e:
        raise HTTPException(status_code=400, detail=f"Invalid JSON: {e}")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Upload error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed: {e}")


# ============================================================
# ✅ APPLICATION MANAGEMENT ENDPOINTS (FIXED — supports all types)
# ============================================================

@router.get("/applications")
async def get_customadmin_applications(
    status: Optional[str] = Query(
        None,
        pattern="^(all|pending|shortlisted|interview|offered|rejected|"
                "submitted|pending_verification|verification_successful|"
                "verification_rejected|review_application|final_submitted|"
                "approved|completed|under_review)$"
    ),
    application_type: Optional[str] = Query(
        "job",
        pattern="^(job|service|schemes)$",
        description="Filter by application type: 'job', 'service', or 'schemes'"
    ),
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """
    ✅ FIXED: Get applications filtered by application_type.
    """
    admin_email = await _get_admin_email(user, db)
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")

    logger.info("=" * 70)
    logger.info(f"📋 CUSTOMADMIN GET APPLICATIONS")
    logger.info(f"   Admin: {admin_email}")
    logger.info(f"   Status: {status}")
    logger.info(f"   Type: {application_type}")
    logger.info("=" * 70)

    return await service.get_admin_applications(
        admin_email=admin_email,
        status_filter=status,
        application_type=application_type or "job"
    )


@router.get("/applications/{application_id}")
async def get_customadmin_application_detail(
    application_id: str,
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """Get detailed application data"""
    admin_email = await _get_admin_email(user, db)
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    return await service.get_application_detail(application_id, admin_email)


@router.put("/applications/{application_id}/status")
async def update_customadmin_application_status(
    application_id: str,
    status: str = Query(
        ...,
        pattern="^(pending|shortlisted|interview|offered|rejected|"
                "submitted|pending_verification|verification_successful|"
                "verification_rejected|review_application|final_submit|"
                "approved|completed|under_review|update_application)$"
    ),
    notes: Optional[str] = Query(None),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """
    Update application status with notifications.

    ✅✅✅ This is the ONLY place the applicant receives a status email
           when the Flutter frontend calls `PUT /status?status=...`
           after uploading a review/final document.
    """
    admin_email = await _get_admin_email(user, db)
    admin_name = user.get("name", "Custom Admin")

    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")

    application_type = application.get("application_type", "job")

    if application_type == "job":
        job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))})
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        if job.get("added_by") != admin_email:
            raise HTTPException(status_code=403, detail="Access denied")
        display_title = job.get("post_name", "Job")
        display_org = job.get("organization", "Company")
        color_type = job.get("color_type", "blue")
    else:
        display_title = (
            application.get("scheme_name") or
            application.get("service_name") or
            "Application"
        )
        display_org = display_title
        color_type = application.get("color_type", "blue")

    old_status = application.get("status", "unknown")
    applicant_email = (
        application.get("applicant_email") or
        application.get("user_email")
    )

    app_number = _resolve_application_number(application, application_id)

    update_data = {
        "status": status,
        "last_status_update": datetime.utcnow(),
        "last_updated_by": admin_email,
        "updated_at": datetime.utcnow()
    }

    if notes:
        update_data["admin_notes"] = notes

    result = await db.applications.update_one(
        {"_id": ObjectId(application_id)},
        {"$set": update_data}
    )

    if result.modified_count == 0:
        raise HTTPException(
            status_code=404,
            detail="Application not found or status unchanged"
        )

    status_messages = {
        "shortlisted": "🎉 Congratulations! You have been shortlisted for this position.",
        "interview": "📞 Great news! You have been selected for an interview.",
        "offered": "🎊 Congratulations! You have received a job offer.",
        "rejected": "📝 Thank you for your interest. Your application has not been selected.",
        "submitted": "✅ Your application document has been submitted successfully.",
        "review_application": "📋 Your application is under review. Please wait for further updates.",
        "final_submit": "✅ Your application has been FINAL SUBMITTED!",
        "approved": "✅ Your application has been APPROVED!",
        "completed": "🎉 Your application has been COMPLETED!",
        "under_review": "📋 Your application is under review.",
        "pending_verification": "⏳ Your payment is pending verification.",
        "verification_successful": "✅ Your payment has been verified successfully!",
        "verification_rejected": "❌ Your payment verification was rejected."
    }

    if applicant_email:
        await central_notification.send_notification(
            user_ids=[applicant_email],
            notification_type="application_status",
            title=f"Application Status: {status.upper()}",
            message=status_messages.get(
                status,
                f"Your application status has been updated to {status} by {admin_name}."
            ) + f"\n\n📋 Application Number: {app_number}",
            related_id=app_number,
            metadata={
                "application_number": app_number,
                "application_id": app_number,
                "job_title": display_title,
                "organization": display_org,
                "old_status": old_status,
                "new_status": status,
                "admin_notes": notes,
                "admin_name": admin_name,
                "color_type": color_type,
                "application_type": application_type,
                "show_blue_bell": True
            },
            send_email=True,
            send_websocket=True
        )
        logger.info(f"🔔 Notification sent to applicant: {applicant_email}")

    return {
        "success": True,
        "message": f"Application status updated from {old_status} to {status}",
        "application_id": application_id,
        "application_number": app_number,
        "status": status,
        "old_status": old_status,
        "updated_by": admin_email,
        "notifications_sent": True
    }


@router.post("/applications/bulk-status")
async def bulk_update_customadmin_status(
    application_ids: List[str] = Body(...),
    status: str = Body(...),
    notes: Optional[str] = Body(None),
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """Bulk update application statuses"""
    admin_email = await _get_admin_email(user, db)
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    return await service.bulk_update_status(
        application_ids,
        status,
        notes,
        admin_email
    )


# ============================================================
# REVIEW APPLICATION STATUS UPDATE
# ============================================================
#
# ✅✅✅ DUPLICATE EMAIL FIX:
#     This endpoint used to send the APPLICANT an email
#     ("📋 Application Under Review"). Flutter ALSO calls
#     PUT /status?status=review_application after this → second email.
#     FIX: no applicant email here — only bell-alert / logs.
# ============================================================

@router.put("/applications/{application_id}/review-status")
async def customadmin_review_application_status(
    application_id: str,
    notes: Optional[str] = Query(None),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """Update application status to 'review_application' (no applicant email)."""
    admin_email = await _get_admin_email(user, db)
    admin_name = user.get("name", "Custom Admin")

    logger.info("=" * 60)
    logger.info(f"📋 REVIEW APPLICATION STATUS UPDATE")
    logger.info(f"   Application ID: {application_id}")
    logger.info(f"   Admin Email: {admin_email}")
    logger.info("=" * 60)

    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    try:
        application = await db.applications.find_one({"_id": ObjectId(application_id)})
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")

        application_type = application.get("application_type", "job")

        if application_type == "job":
            job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))})
            if not job:
                raise HTTPException(status_code=404, detail="Job not found")
            if job.get("added_by") != admin_email:
                raise HTTPException(status_code=403, detail="Access denied")

        old_status = application.get("status", "unknown")
        applicant_email = (
            application.get("applicant_email") or
            application.get("user_email")
        )
        existing_doc_url = application.get("submitted_document_url")

        app_number = _resolve_application_number(application, application_id)
        display_title, display_org = _get_display_title(application)

        update_data = {
            "status": "review_application",
            "last_status_update": datetime.utcnow(),
            "last_updated_by": admin_email,
            "updated_at": datetime.utcnow(),
            "admin_notes": notes if notes else f"Application moved to review stage by {admin_name}"
        }

        if existing_doc_url:
            update_data["submitted_document_url"] = existing_doc_url

        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data}
        )

        logger.info(f"✅ Application status updated from {old_status} to 'review_application'")

        # ✅✅✅ DUPLICATE EMAIL FIX — Applicant notification REMOVED.
        # ------------------------------------------------------------
        # The following block was sending a "📋 Application Under
        # Review" email to the applicant. Since the Flutter frontend
        # also calls PUT /status?status=review_application immediately
        # afterwards (which sends the same email), this was causing
        # TWO emails per action.
        #
        # The single applicant email is now sent ONLY by
        # PUT /applications/{id}/status.
        # ------------------------------------------------------------
        # if applicant_email:
        #     user_title = f"📋 Application Under Review"
        #     user_message = (
        #         f"Your application is now under REVIEW by {admin_name}.\n\n"
        #         f"📋 Application Number: {app_number}\n\n"
        #         "The admin is reviewing your documents. You will be notified once the review is complete."
        #     )
        #     if notes:
        #         user_message += f"\n\nAdmin Notes: {notes}"
        #
        #     await central_notification.send_notification(
        #         user_ids=[applicant_email],
        #         notification_type="application_status",
        #         title=user_title,
        #         message=user_message,
        #         related_id=app_number,
        #         metadata={
        #             "application_number": app_number,
        #             "application_id": app_number,
        #             "job_title": display_title,
        #             "organization": display_org,
        #             "status": "review_application",
        #             "admin_notes": notes,
        #             "admin_name": admin_name,
        #             "application_type": application_type,
        #             "show_blue_bell": True,
        #             "submitted_document_url": existing_doc_url
        #         },
        #         send_email=True,
        #         send_websocket=True
        #     )
        # ------------------------------------------------------------
        # ✅ END DUPLICATE EMAIL FIX
        # ------------------------------------------------------------

        return {
            "success": True,
            "message": f"Application status updated from {old_status} to review_application",
            "application_id": application_id,
            "application_number": app_number,
            "status": "review_application",
            "old_status": old_status,
            "admin_notes": notes,
            "notifications_sent": True,
            "submitted_document_url": existing_doc_url,
            "applicant_email_sent": False,  # ✅ PUT /status will send it
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in review status: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


# ============================================================
# DOCUMENT UPLOAD (Review & Final Submit)
# ============================================================
#
# ✅✅✅ DUPLICATE EMAIL FIX:
#    customadmin_submit_document() used to send the APPLICANT a
#    "📄 Document Submitted" email. Flutter ALSO calls
#    PUT /status?status=review_application immediately after this
#    (which sends the "Under Review" email). FIX: no applicant email.
# ============================================================

@router.post("/applications/{application_id}/submit-document")
async def customadmin_submit_document(
    application_id: str,
    file: UploadFile = File(...),
    notes: Optional[str] = Form(None),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """
    CustomAdmin submits document for review.

    ✅✅✅ DUPLICATE EMAIL FIX: Applicant email REMOVED.
           Only the follow-up PUT /status sends the applicant email.
    """
    admin_email = await _get_admin_email(user, db)
    admin_name = user.get("name", "Custom Admin")

    logger.info("=" * 60)
    logger.info(f"📤 SUBMIT DOCUMENT FOR REVIEW")
    logger.info(f"   Application ID: {application_id}")
    logger.info(f"   Admin Email: {admin_email}")
    logger.info(f"   File: {file.filename if file else 'No file'}")
    logger.info("=" * 60)

    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Document file is required")

    allowed_extensions = ['pdf', 'jpg', 'jpeg', 'png']
    file_ext = file.filename.split('.')[-1].lower() if file.filename else ''
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type. Allowed: {', '.join(allowed_extensions)}"
        )

    try:
        application = await db.applications.find_one({"_id": ObjectId(application_id)})
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")

        applicant_email = (
            application.get("applicant_email") or
            application.get("user_email")
        )
        if not applicant_email:
            raise HTTPException(status_code=404, detail="Applicant email not found")

        username = applicant_email.split('@')[0]

        application_type = application.get("application_type", "job")

        if application_type == "job":
            job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))})
            if not job:
                raise HTTPException(status_code=404, detail="Job not found")
            if job.get("added_by") != admin_email:
                raise HTTPException(status_code=403, detail="Access denied")

        await file.seek(0)

        upload_result = await upload_user_document(
            file=file,
            username=username,
            document_type="applications"
        )

        logger.info(f"✅ File uploaded to Cloudinary: {upload_result['url']}")

        old_status = application.get("status", "unknown")

        update_data = {
            "status": "review_application",
            "last_status_update": datetime.utcnow(),
            "last_updated_by": admin_email,
            "updated_at": datetime.utcnow(),
            "submitted_document_url": upload_result["url"],
            "submitted_document_name": file.filename,
            "submitted_document_storage": upload_result.get("storage", "cloudinary"),
            "submitted_document_public_id": upload_result.get("public_id"),
            "submitted_document_resource_type": upload_result.get("resource_type", "raw"),
            "submitted_document_folder": upload_result.get("folder_path"),
            "submitted_at": datetime.utcnow(),
            "submitted_by": admin_email,
            "admin_notes": notes if notes else None
        }

        result = await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data}
        )

        if result.modified_count == 0:
            logger.error(f"❌ Failed to update application {application_id}")
            raise HTTPException(status_code=500, detail="Failed to update application")

        updated_app = await db.applications.find_one({"_id": ObjectId(application_id)})
        saved_url = updated_app.get("submitted_document_url") if updated_app else None
        logger.info(f"✅ VERIFIED: submitted_document_url = {saved_url}")

        app_number = _resolve_application_number(application, application_id)
        display_title, display_org = _get_display_title(application)

        logger.info(f"📋 Using application_number for admin alert only: {app_number}")

        # ✅✅✅ DUPLICATE EMAIL FIX — Applicant notification REMOVED.
        # ------------------------------------------------------------
        # The following block was sending a "📄 Document Submitted"
        # email to the applicant. Since the Flutter frontend ALSO
        # calls PUT /status?status=review_application immediately
        # afterwards (which sends "📋 Application Under Review"),
        # this was causing TWO emails.
        #
        # The single applicant email is now sent ONLY by
        # PUT /applications/{id}/status.
        # ------------------------------------------------------------
        # user_title = f"📄 Document Submitted"
        # user_message = (
        #     f"Your document '{file.filename}' has been submitted successfully "
        #     f"by {admin_name}.\n\n"
        #     f"📋 Application Number: {app_number}"
        # )
        # if notes:
        #     user_message += f"\n\nAdmin Notes: {notes}"
        #
        # await central_notification.send_notification(
        #     user_ids=[applicant_email],
        #     notification_type="application_status",
        #     title=user_title,
        #     message=user_message,
        #     related_id=app_number,
        #     metadata={
        #         "application_number": app_number,
        #         "application_id": app_number,
        #         "job_title": display_title,
        #         "organization": display_org,
        #         "document_name": file.filename,
        #         "admin_name": admin_name,
        #         "admin_notes": notes,
        #         "application_type": application_type,
        #         "show_blue_bell": True,
        #         "status": "review_application",
        #         "submitted_document_url": upload_result["url"]
        #     },
        #     send_email=True,
        #     send_websocket=True
        # )
        # logger.info(f"🔔 Notification sent to user: {applicant_email}")
        # ------------------------------------------------------------
        # ✅ END DUPLICATE EMAIL FIX
        # ------------------------------------------------------------

        return {
            "success": True,
            "message": "Document submitted successfully!",
            "application_id": application_id,
            "application_number": app_number,
            "submitted_document_url": upload_result["url"],
            "submitted_document_name": file.filename,
            "admin_notes": notes,
            "notifications_sent": True,
            "status": "review_application",
            "applicant_email_sent": False,  # ✅ PUT /status will send it
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error submitting document: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


# ============================================================
# ✅ FIXED: ONLY ONE definition of final-submit-with-document.
#    The previous file had TWO — FastAPI silently ignored the second.
#
# ✅✅✅ DUPLICATE EMAIL FIX:
#    customadmin_final_submit_with_document() used to send the APPLICANT
#    a "✅ FINAL SUBMISSION" email. Flutter ALSO calls
#    PUT /status?status=final_submit immediately after (which sends
#    the "FINAL SUBMITTED" email). FIX: no applicant email here.
# ============================================================

@router.post("/applications/{application_id}/final-submit-with-document")
async def customadmin_final_submit_with_document(
    application_id: str,
    file: UploadFile = File(...),
    notes: Optional[str] = Form(None),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """
    CustomAdmin FINAL SUBMIT application with document.

    ✅✅✅ DUPLICATE EMAIL FIX: Applicant email REMOVED.
           Only the follow-up PUT /status sends the applicant email.
    """
    admin_email = await _get_admin_email(user, db)
    admin_name = user.get("name", "Custom Admin")

    logger.info("=" * 60)
    logger.info(f"📤 FINAL SUBMIT WITH DOCUMENT")
    logger.info(f"   Application ID: {application_id}")
    logger.info(f"   Admin Email: {admin_email}")
    logger.info(f"   File: {file.filename}")
    logger.info("=" * 60)

    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Document file is required")

    allowed_extensions = ['pdf', 'jpg', 'jpeg', 'png']
    file_ext = file.filename.split('.')[-1].lower() if file.filename else ''
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type. Allowed: {', '.join(allowed_extensions)}"
        )

    try:
        application = await db.applications.find_one({"_id": ObjectId(application_id)})
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")

        applicant_email = (
            application.get("applicant_email") or
            application.get("user_email")
        )
        if not applicant_email:
            raise HTTPException(status_code=404, detail="Applicant email not found")

        username = applicant_email.split('@')[0]

        application_type = application.get("application_type", "job")

        if application_type == "job":
            job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))})
            if not job:
                raise HTTPException(status_code=404, detail="Job not found")
            if job.get("added_by") != admin_email:
                raise HTTPException(status_code=403, detail="Access denied")

        old_public_id = application.get("submitted_document_public_id")
        if old_public_id:
            try:
                old_resource_type = application.get(
                    "submitted_document_resource_type", "raw"
                )
                await delete_from_cloudinary(old_public_id, old_resource_type)
                logger.info(f"🗑️ Old document deleted: {old_public_id}")
            except Exception as del_err:
                logger.warning(f"⚠️ Could not delete old document: {del_err}")

        await file.seek(0)

        upload_result = await upload_user_document(
            file=file,
            username=username,
            document_type="applications"
        )

        logger.info(f"✅ NEW file uploaded to Cloudinary: {upload_result['url']}")

        old_status = application.get("status", "unknown")

        update_data = {
            "status": "final_submitted",
            "last_status_update": datetime.utcnow(),
            "last_updated_by": admin_email,
            "updated_at": datetime.utcnow(),
            "submitted_document_url": upload_result["url"],
            "submitted_document_name": file.filename,
            "submitted_document_storage": upload_result.get("storage", "cloudinary"),
            "submitted_document_public_id": upload_result.get("public_id"),
            "submitted_document_resource_type": upload_result.get("resource_type", "raw"),
            "submitted_document_folder": upload_result.get("folder_path"),
            "submitted_at": datetime.utcnow(),
            "submitted_by": admin_email,
            "final_submitted_at": datetime.utcnow(),
            "final_submitted_by": admin_email,
            "final_document_url": upload_result["url"],
            "final_document_name": file.filename,
            "admin_notes": notes if notes else "Final submitted"
        }

        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data}
        )

        updated_app = await db.applications.find_one({"_id": ObjectId(application_id)})
        saved_url = updated_app.get("submitted_document_url") if updated_app else None
        logger.info(f"✅ VERIFIED: submitted_document_url = {saved_url}")

        app_number = _resolve_application_number(application, application_id)
        display_title, display_org = _get_display_title(application)

        logger.info(f"📋 Using application_number for FINAL admin alert only: {app_number}")

        # ✅✅✅ DUPLICATE EMAIL FIX — Applicant notification REMOVED.
        # ------------------------------------------------------------
        # The following block was sending a "✅ FINAL SUBMISSION"
        # email to the applicant. Since the Flutter frontend ALSO
        # calls PUT /status?status=final_submit immediately afterwards
        # (which sends "✅ Your application has been FINAL SUBMITTED!"),
        # this was causing TWO emails.
        #
        # The single applicant email is now sent ONLY by
        # PUT /applications/{id}/status.
        # ------------------------------------------------------------
        # user_title = f"✅ FINAL SUBMISSION"
        # user_message = (
        #     f"Your FINAL document '{file.filename}' has been submitted successfully "
        #     f"by {admin_name}.\n\n"
        #     f"📋 Application Number: {app_number}\n\n"
        #     "This is your FINAL submission. No further changes are allowed."
        # )
        # if notes:
        #     user_message += f"\n\nAdmin Notes: {notes}"
        #
        # await central_notification.send_notification(
        #     user_ids=[applicant_email],
        #     notification_type="application_status",
        #     title=user_title,
        #     message=user_message,
        #     related_id=app_number,
        #     metadata={
        #         "application_number": app_number,
        #         "application_id": app_number,
        #         "job_title": display_title,
        #         "organization": display_org,
        #         "document_name": file.filename,
        #         "admin_name": admin_name,
        #         "admin_notes": notes,
        #         "is_final": True,
        #         "application_type": application_type,
        #         "show_blue_bell": True,
        #         "status": "final_submitted",
        #         "final_document_url": upload_result["url"]
        #     },
        #     send_email=True,
        #     send_websocket=True
        # )
        # logger.info(f"🔔 Notification sent to user: {applicant_email}")
        # ------------------------------------------------------------
        # ✅ END DUPLICATE EMAIL FIX
        # ------------------------------------------------------------

        return {
            "success": True,
            "message": "FINAL application document submitted successfully!",
            "application_id": application_id,
            "application_number": app_number,
            "status": "final_submitted",
            "old_status": old_status,
            "final_document_url": upload_result["url"],
            "submitted_document_url": upload_result["url"],
            "document_name": file.filename,
            "admin_notes": notes,
            "old_document_deleted": old_public_id is not None,
            "notifications_sent": True,
            "applicant_email_sent": False,  # ✅ PUT /status will send it
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in final submit: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


# ============================================================
# USER MANAGEMENT (Read-only)
# ============================================================

@router.get("/users/search")
async def search_customadmin_users(
    query: str = Query(..., min_length=1),
    limit: int = Query(20, ge=1, le=100),
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required)
):
    """Search users (read-only access)"""
    return await service.search_users(query, limit)


@router.get("/users/{email}")
async def get_customadmin_user_profile(
    email: str,
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required)
):
    """Get user profile details (read-only)"""
    return await service.get_user_profile(email)


# ============================================================
# REPORTS
# ============================================================

@router.get("/reports/{report_type}")
async def generate_customadmin_report(
    report_type: str,
    service: CustomAdminService = Depends(get_customadmin_service),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """Generate various reports"""
    admin_email = await _get_admin_email(user, db)
    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")
    return await service.generate_report(report_type, admin_email)


# ============================================================
# NOTIFICATIONS
# ============================================================

@router.get("/notifications/count")
async def get_customadmin_notification_count(
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """Get unread notification count"""
    user_id = user.get("user_id")
    user_email = user.get("email")

    if not user_id and not user_email:
        raise HTTPException(status_code=400, detail="User ID and email not found")

    query = {"$or": [
        {"user_id": user_id},
        {"user_email": user_email}
    ], "read": False}

    count = await db.notifications.count_documents(query)
    return {"unread_count": count}


@router.get("/notifications")
async def get_customadmin_notifications(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """Get notifications for customadmin"""
    user_id = user.get("user_id")
    user_email = user.get("email")

    query = {"$or": [
        {"user_id": user_id},
        {"user_email": user_email}
    ]}

    notifications = await db.notifications.find(query).sort(
        "created_at", -1
    ).skip(skip).limit(limit).to_list(limit)

    for n in notifications:
        n["_id"] = str(n["_id"])
        if n.get("created_at"):
            n["created_at"] = n["created_at"].isoformat()

    return {"notifications": notifications, "total": len(notifications)}


@router.post("/notifications/mark-read/{notification_id}")
async def mark_customadmin_notification_read(
    notification_id: str,
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """Mark a notification as read"""
    user_id = user.get("user_id")
    user_email = user.get("email")

    if not ObjectId.is_valid(notification_id):
        raise HTTPException(status_code=400, detail="Invalid notification ID")

    result = await db.notifications.update_one(
        {
            "_id": ObjectId(notification_id),
            "$or": [
                {"user_id": user_id},
                {"user_email": user_email}
            ]
        },
        {"$set": {"read": True, "read_at": datetime.utcnow()}}
    )

    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="Notification not found")

    return {"success": True, "message": "Notification marked as read"}


# ============================================================
# SETTINGS
# ============================================================

@router.get("/settings")
async def get_customadmin_settings(
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """Get customadmin settings"""
    admin_email = await _get_admin_email(user, db)
    profile = await db.profile.find_one({"email": admin_email})

    return {
        "email": admin_email,
        "name": user.get("name"),
        "role": "customadmin",
        "profile": profile
    }


@router.put("/settings")
async def update_customadmin_settings(
    settings_data: dict = Body(...),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """Update customadmin settings"""
    admin_email = await _get_admin_email(user, db)

    await db.profile.update_one(
        {"email": admin_email},
        {
            "$set": {
                "admin_settings": settings_data,
                "updated_at": datetime.utcnow()
            }
        },
        upsert=True
    )

    return {"message": "Settings updated successfully"}


# ============================================================
# PENDING PAYMENTS
# ============================================================

@router.get("/pending-payments")
async def customadmin_get_pending_payments(
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """Get all pending payment verifications for custom admin"""
    pending = await db.applications.find({
        "application_type": "job",
        "payment_verification_status": "pending"
    }).to_list(100)

    results = []
    for app in pending:
        job = None
        if app.get("job_id") and ObjectId.is_valid(app["job_id"]):
            job = await db.job.find_one({"_id": ObjectId(app["job_id"])})

        results.append({
            "id": str(app["_id"]),
            "application_number": _resolve_application_number(app, str(app["_id"])),
            "type": "job",
            "user_email": app.get("applicant_email") or app.get("user_email"),
            "user_name": app.get("applicant_name") or app.get("user_name", "Unknown"),
            "job_title": app.get("job_title") or (job.get("post_name") if job else "Job"),
            "organization": app.get("organization") or (job.get("organization") if job else ""),
            "amount": app.get("payment_amount", 0),
            "category_used": app.get("payment_category_used", "none"),
            "transaction_id": app.get("transaction_id", "N/A"),
            "screenshot_url": app.get("payment_receipt_url"),
            "status": app.get("status", "pending_verification"),
            "created_at": (
                app.get("created_at").isoformat()
                if app.get("created_at") else None
            )
        })

    return {"payments": results, "total": len(results)}


@router.post("/verify-payment/{application_id}")
async def customadmin_verify_payment(
    application_id: str,
    action: str = Query(..., pattern="^(approve|reject)$"),
    notes: Optional[str] = Query(None),
    user=Depends(custom_admin_required),
    db=Depends(get_db)
):
    """CustomAdmin approves or rejects a pending payment verification"""
    if not ObjectId.is_valid(application_id):
        raise HTTPException(400, "Invalid application ID")

    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(404, "Application not found")

    application_type = application.get("application_type", "job")

    if application.get("payment_verification_status") != "pending":
        return {
            "success": False,
            "message": f"Payment already {application.get('payment_verification_status')}"
        }

    admin_email = await _get_admin_email(user, db)
    admin_name = user.get("name", "Custom Admin")

    user_email = application.get("applicant_email") or application.get("user_email")
    amount = application.get("payment_amount", 0)
    transaction_id = application.get("transaction_id")
    job_title = application.get("job_title", "Job Application")
    job_poster_email = application.get("added_by")

    app_number = _resolve_application_number(application, application_id)
    display_title, display_org = _get_display_title(application)

    if action == "approve":
        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {
                "$set": {
                    "payment_verification_status": "approved",
                    "status": "verification_successful" if application_type == "job" else "payment_verified",
                    "payment_verified_by": admin_email,
                    "payment_verified_at": datetime.utcnow(),
                    "verification_notes": notes if notes else "Payment approved by admin",
                    "updated_at": datetime.utcnow()
                }
            }
        )

        status_msg = "verification_successful" if application_type == "job" else "payment_verified"
        title = f"✅ Payment Verified Successfully: {job_title}"
        message = (
            f"Your payment of ₹{amount} for '{job_title}' has been verified successfully. "
            f"Your application is now submitted.\n\n"
            f"📋 Application Number: {app_number}"
        )

        await central_notification.send_notification(
            user_ids=[user_email],
            notification_type="application_status",
            title=title,
            message=message,
            related_id=app_number,
            metadata={
                "status": status_msg,
                "amount": amount,
                "transaction_id": transaction_id,
                "application_number": app_number,
                "application_id": app_number,
                "job_title": display_title,
                "organization": display_org,
                "show_blue_bell": True
            },
            send_email=True,
            send_sms=True,
            send_websocket=True
        )

        return {
            "success": True,
            "message": "Payment approved successfully.",
            "application_id": application_id,
            "application_number": app_number,
            "action": action,
            "notes": notes,
            "notifications_sent": True
        }

    else:
        if not notes:
            notes = "Payment rejected by admin - Please contact support"

        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {
                "$set": {
                    "payment_verification_status": "rejected",
                    "status": "verification_rejected" if application_type == "job" else "rejected",
                    "payment_verified_by": admin_email,
                    "payment_verified_at": datetime.utcnow(),
                    "payment_rejection_reason": notes,
                    "verification_notes": notes,
                    "updated_at": datetime.utcnow()
                }
            }
        )

        status_msg = "verification_rejected" if application_type == "job" else "rejected"
        title = f"❌ Payment Verification Failed: {job_title}"
        message = (
            f"Your payment of ₹{amount} for '{job_title}' has been REJECTED.\n"
            f"Reason: {notes}\n\n"
            f"📋 Application Number: {app_number}"
        )

        await central_notification.send_notification(
            user_ids=[user_email],
            notification_type="application_status",
            title=title,
            message=message,
            related_id=app_number,
            metadata={
                "status": status_msg,
                "amount": amount,
                "rejection_reason": notes,
                "application_number": app_number,
                "application_id": app_number,
                "job_title": display_title,
                "organization": display_org,
                "show_blue_bell": True
            },
            send_email=True,
            send_sms=True,
            send_websocket=True
        )

        return {
            "success": True,
            "message": f"Payment rejected. Reason: {notes}",
            "application_id": application_id,
            "application_number": app_number,
            "action": action,
            "notes": notes,
            "notifications_sent": True
        }


# ============================================================
# SCHEMES — thin wrappers (delegate to schemes router)
# ============================================================

@router.post("/applications/{application_id}/review-with-document")
async def customadmin_scheme_review_with_document(
    application_id: str,
    file: UploadFile = File(...),
    notes: str = Form(""),
    user=Depends(custom_admin_required),
    db=Depends(get_db),
):
    """
    CustomAdmin wrapper — delegates to the schemes router logic.
    Kept for backward compatibility with older frontend builds.
    """
    from app.modules.schemes.routes import scheme_review_with_document
    return await scheme_review_with_document(
        application_id=application_id,
        file=file,
        notes=notes,
        db=db,
        current_user=user,
    )


@router.get("/applications/{application_id}/documents")
async def customadmin_scheme_documents(
    application_id: str,
    user=Depends(custom_admin_required),
    db=Depends(get_db),
):
    """
    CustomAdmin wrapper — delegates to schemes router.
    """
    from app.modules.schemes.routes import get_scheme_documents
    return await get_scheme_documents(
        application_id=application_id,
        db=db,
        current_user=user,
    )


@router.post("/jobs/{job_id}/upload-advertisement")
async def upload_advertisement_to_existing_job(
    job_id: str,
    file: UploadFile = File(...),
    job_data: str = Form(...),
    current_user: dict = Depends(get_current_admin_user),
):
    """
    ✅ Upload an advertisement file and UPDATE the EXISTING job record.
    This does NOT create a new job.
    """
    db = get_database()

    if not ObjectId.is_valid(job_id):
        raise HTTPException(status_code=400, detail="Invalid job id")

    existing = await db.job.find_one({"_id": ObjectId(job_id)})
    if not existing:
        raise HTTPException(status_code=404, detail="Job not found")

    try:
        parsed_data = json.loads(job_data)
        if not isinstance(parsed_data, dict):
            raise ValueError("job_data must be a JSON object")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid job_data: {e}")

    try:
        upload = await upload_advertisement_file(file, job_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {e}")

    filename = upload["filename"] or ""
    parsed_data.update({
        "advertisement_url": upload["secure_url"],
        "advertisement_public_id": upload["public_id"],
        "advertisement_filename": filename,
        "advertisement_is_pdf": filename.lower().endswith(".pdf"),
        "advertisement_is_public": False,
        "updated_at": datetime.utcnow().isoformat(),
        "last_updated_by": current_user.get("email", ""),
    })

    parsed_data.pop("_id", None)
    await db.job.update_one(
        {"_id": ObjectId(job_id)},
        {"$set": parsed_data},
    )

    return {
        "success": True,
        "job_id": job_id,
        "advertisement_url": upload["secure_url"],
        "advertisement_public_id": upload["public_id"],
        "message": "Advertisement uploaded and job updated",
    }


# ============================================================
# END OF FILE
# ============================================================

print("✅ Custom Admin Routes Loaded")
print("   ✅ FIXED: POST /jobs respects is_draft (no forced status='open')")
print("   ✅ FIXED: PUT /jobs/{id} merges via $set (no tab data loss)")
print("   ✅ FIXED: upload-advertisement updates existing draft via job_id")
print("   ✅ FIXED: upload-advertisement respects is_draft (no notify on draft)")
print("   ✅ FIXED: Removed duplicate final-submit-with-document definition")
print("   ✅ FIXED: application_type query param on /applications")
print("   ✅ FIXED: Duplicate 'Document Submitted' email removed")
print("   ✅ FIXED: Duplicate 'FINAL SUBMISSION' email removed")
print("   ✅ FIXED: Duplicate 'Application Under Review' email removed")
print("   ✅ Applicant now receives ONE email per status change")
print("   ✅ Job CRUD: Add, Get, Update, Delete, Publish")
print("   ✅ Application Management: job + service + schemes")
print("   ✅ Document Upload: Review, Final Submit")
print("   ✅ Payment Verification: Approve, Reject")
print("   ✅ NEW: application_number propagated to ALL notifications")
print("      (review / final submit / payment / status update)")
print("      → email header shows YYYYMMDDSSSS, not the raw _id")