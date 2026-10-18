# app/modules/jobs/routes.py - UPDATED (NO apply_mode) + color_type filter
# ✅ FIXED: Added logger import
# ✅ NEW: color_type query parameter in list_jobs

from fastapi import APIRouter, Depends, Query, BackgroundTasks, UploadFile, File, Form, HTTPException, Body
from typing import Optional, List, Annotated, Dict
import json
import logging
from bson import ObjectId
from app.core.services.dependencies import get_current_user, role_required
from app.db.connection import get_db
from app.modules.jobs.service import JobService
from app.core.config.settings import settings
from app.modules.jobs.AI.ai_routes import router as jobs_ai_router
from datetime import datetime
from app.modules.jobs.schema import (
    JobCreateSchema,
    JobUpdateSchema,
    ApplicationCreateSchema,
    ApplicationStatusUpdateSchema
)

logger = logging.getLogger(__name__)

router = APIRouter()

router.include_router(jobs_ai_router)

ENABLE_JOB_FETCH = False

async def get_job_service(db=Depends(get_db)):
    return JobService(db)


# ====================== ADMIN / SUPERADMIN / CUSTOMADMIN ENDPOINTS ======================

@router.post("/add-job")
async def add_job(
    job_data: Annotated[str, Form(...)],
    background_tasks: BackgroundTasks,
    attachments: Optional[List[UploadFile]] = File(None),
    service: JobService = Depends(get_job_service),
    user=Depends(role_required(["admin", "customadmin", "superadmin"]))
):
    """Admin/SuperAdmin/CustomAdmin adds job → supports file attachments + sends notifications"""
    try:
        job_dict = json.loads(job_data)
        job_data_model = JobCreateSchema(**job_dict)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON in job_data field")
    except Exception as e:
        raise HTTPException(status_code=422, detail=f"Validation error in job data: {str(e)}")

    return await service.add_job(job_data_model, background_tasks, attachments, user)


@router.post("/add-job-json")
async def add_job_json(
    job_data: JobCreateSchema,
    background_tasks: BackgroundTasks,
    service: JobService = Depends(get_job_service),
    user=Depends(role_required(["admin", "customadmin", "superadmin"]))
):
    """Add a new job using JSON (easier for testing via Swagger UI)"""
    return await service.add_job(job_data, background_tasks, None, user)


@router.get("/advertisement/{job_id}")
async def get_job_advertisement(
    job_id: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Get job advertisement URL from Cloudinary"""
    if not ObjectId.is_valid(job_id):
        raise HTTPException(status_code=400, detail="Invalid job ID")

    job = await db.job.find_one({"_id": ObjectId(job_id)})
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    advertisement_url = job.get("advertisement_url")
    advertisement_name = job.get("advertisement_name")
    advertisement_storage = job.get("advertisement_storage", "unknown")

    if not advertisement_url:
        raise HTTPException(status_code=404, detail="No advertisement found for this job")

    return {
        "success": True,
        "url": advertisement_url,
        "filename": advertisement_name,
        "storage": advertisement_storage,
        "job_title": job.get("post_name"),
        "organization": job.get("organization")
    }


@router.get("/admin/jobs")
async def get_admin_jobs(
    service: JobService = Depends(get_job_service),
    user=Depends(role_required(["admin", "customadmin", "superadmin"]))
):
    """Get all jobs posted by the logged-in admin"""
    admin_email = user.get("email")
    if not admin_email:
        user_id = user.get("user_id")
        if user_id:
            db = get_db()
            auth_user = await db.auth.find_one({"_id": ObjectId(user_id)})
            if auth_user:
                admin_email = auth_user.get("email")

    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")

    return await service.get_admin_jobs(admin_email)


@router.get("/admin/applications")
async def get_admin_applications(
    status: Optional[str] = Query(None, pattern="^(pending|shortlisted|interview|offered|rejected|submitted|pending_verification|verification_successful|verification_rejected|review_application|confirmed_application|update_application)$"),
    service: JobService = Depends(get_job_service),
    user=Depends(role_required(["admin", "customadmin", "superadmin"]))
):
    """Get all applications for jobs posted by the logged-in admin"""
    admin_email = user.get("email")
    if not admin_email:
        user_id = user.get("user_id")
        if user_id:
            db = get_db()
            auth_user = await db.auth.find_one({"_id": ObjectId(user_id)})
            if auth_user:
                admin_email = auth_user.get("email")

    if not admin_email:
        raise HTTPException(status_code=400, detail="Admin email not found")

    return await service.get_admin_applications(admin_email, status)


# ====================== USER ENDPOINTS ======================

@router.get("/")
async def list_jobs(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    job_type: Optional[str] = Query(None, description="private/remote/government/hybrid/all"),
    category: Optional[str] = Query(None, description="IT/Banking/Healthcare/etc"),
    color_type: Optional[str] = Query(
        None,
        description="blue/green/red/orange/purple/teal/pink/indigo/amber/cyan/grey/white/all"
    ),  # ✅ NEW
    search: Optional[str] = Query(None),
    service: JobService = Depends(get_job_service),
    current_user: dict = Depends(get_current_user)
):
    """List jobs with filters"""
    print("=" * 50)
    print(f"📋 LIST JOBS REQUEST")
    print(f"   job_type: {job_type}")
    print(f"   category: {category}")
    print(f"   color_type: {color_type}")   # ✅ NEW
    print(f"   search: {search}")
    print(f"   skip: {skip}")
    print(f"   limit: {limit}")
    print("=" * 50)

    user_location = None
    if current_user:
        email = current_user.get("email")
        if email:
            db = get_db()
            user = await db.auth.find_one({"email": email})
            if user and user.get("current_location"):
                loc = user["current_location"]
                user_location = {
                    "latitude": loc.get("latitude"),
                    "longitude": loc.get("longitude")
                }

    return await service.list_jobs(
        skip, limit, job_type, category, search, user_location, color_type  # ✅ NEW
    )


@router.get("/recommended")
async def recommended_jobs(
    limit: int = 10,
    service: JobService = Depends(get_job_service),
    user=Depends(get_current_user)
):
    """AI-based recommended jobs"""
    return await service.get_recommended_jobs(user, limit) if hasattr(service, 'get_recommended_jobs') else {"jobs": [], "total": 0}


@router.post("/apply/{job_id}")
async def apply_to_job(
    job_id: str,
    application_data: ApplicationCreateSchema,
    service: JobService = Depends(get_job_service),
    user=Depends(get_current_user)
):
    """User applies to a job → email sent to admin"""
    return await service.apply_to_job(job_id, application_data, user)


@router.get("/my-applications")
async def my_applications(
    filter_mode: Optional[str] = Query(None, pattern="^(saved|applied|all)$", description="Filter by mode: saved (bookmarks), applied (submitted), all"),
    service: JobService = Depends(get_job_service),
    current_user: dict = Depends(get_current_user)
):
    """
    User sees their applications filtered by mode
    - filter_mode='saved': Only saved/bookmarked jobs (status='saved')
    - filter_mode='applied': Only submitted applications (status != 'saved')
    - filter_mode='all' or None: Both
    """
    return await service.get_my_applications_by_mode(current_user, filter_mode)


# ====================== ADMIN / SUPERADMIN MANAGEMENT ======================

@router.get("/applications/{job_id}")
async def get_job_applications(
    job_id: str,
    service: JobService = Depends(get_job_service),
    user=Depends(role_required(["admin", "customadmin", "superadmin"]))
):
    """Admin sees all applications for their job"""
    return await service.get_applications_for_job(job_id, user) if hasattr(service, 'get_applications_for_job') else {"applications": []}


@router.put("/applications/{application_id}/status")
async def update_application_status(
    application_id: str,
    status: str = Query(..., pattern="^(pending|shortlisted|interview|offered|rejected|submitted|pending_verification|verification_successful|verification_rejected|review_application|confirmed_application|update_application)$"),
    notes: Optional[str] = Query(None),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """Admin changes status + notifies user via Notification module"""
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")

    job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))})
    admin_email = user.get("email")

    if job and job.get("added_by") != admin_email and user.get("role") != "superadmin":
        raise HTTPException(status_code=403, detail="Access denied")

    old_status = application.get("status", "unknown")

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
        raise HTTPException(status_code=404, detail="Application not found or status unchanged")

    from app.modules.notification.service import central_notification

    applicant_email = application.get("applicant_email")
    if applicant_email:
        status_messages = {
            "shortlisted": "🎉 Congratulations! You have been shortlisted for this position.",
            "interview": "📞 Great news! You have been selected for an interview.",
            "offered": "🎊 Congratulations! You have received a job offer.",
            "rejected": "📝 Thank you for your interest. Your application has not been selected.",
            "submitted": "✅ Your application document has been submitted successfully.",
            "pending_verification": "⏳ Your payment is pending verification. Please wait for admin approval.",
            "verification_successful": "✅ Your payment has been verified successfully! Application submitted.",
            "verification_rejected": "❌ Your payment verification was rejected. Please re-apply with correct payment details.",
            "review_application": "📋 Your application is under review. Please wait for further updates.",
            "confirmed_application": "✅ Your application has been confirmed!",
            "update_application": "📝 Your update has been submitted for admin review."
        }

        await central_notification.send_notification(
            user_ids=[applicant_email],
            notification_type="application_status",
            title=f"Application Status: {status.upper()}",
            message=status_messages.get(status, f"Your application status has been updated to {status}."),
            metadata={
                "application_id": application_id,
                "job_title": job.get("post_name") if job else "",
                "old_status": old_status,
                "new_status": status,
                "color_type": (job.get("color_type", "blue") if job else "blue"),  # ✅ NEW
            },
            send_email=True,
            send_websocket=True
        )

    return {
        "success": True,
        "message": f"Application status updated from {old_status} to {status}",
        "application_id": application_id,
        "status": status,
        "old_status": old_status,
        "updated_by": admin_email
    }


# ====================== APPLICATION UPDATE ENDPOINTS ======================

@router.put("/applications/{application_id}/user-status")
async def update_application_user_status(
    application_id: str,
    status: str = Query(..., pattern="^(confirmed_application)$"),
    notes: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    User updates application status (e.g., confirm application)
    This endpoint is called when user confirms application from review_application status
    """
    from datetime import datetime
    from app.modules.notification.service import central_notification

    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")

    user_email = current_user.get("email")
    if application.get("applicant_email") != user_email:
        raise HTTPException(status_code=403, detail="Unauthorized - This is not your application")

    current_status = application.get("status", "")
    if current_status != "review_application":
        raise HTTPException(
            status_code=400,
            detail=f"Cannot confirm application in '{current_status}' status. Only applications under review can be confirmed."
        )

    update_data = {
        "status": status,
        "confirmed_at": datetime.utcnow(),
        "confirmed_by": user_email,
        "confirmation_notes": notes,
        "updated_at": datetime.utcnow()
    }

    result = await db.applications.update_one(
        {"_id": ObjectId(application_id)},
        {"$set": update_data}
    )

    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="Application not found")

    job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))})
    job_title = job.get("post_name", "Job") if job else "Job"
    organization = job.get("organization", "Company") if job else "Company"
    color_type = job.get("color_type", "blue") if job else "blue"  # ✅ NEW

    admin_email = job.get("added_by") if job else None
    if admin_email:
        await central_notification.send_notification(
            user_ids=[admin_email],
            notification_type="admin_alert",
            title=f"✅ Application Confirmed: {job_title}",
            message=f"User {user_email} has confirmed their application for '{job_title}' at {organization}.",
            metadata={
                "application_id": application_id,
                "applicant_email": user_email,
                "job_title": job_title,
                "status": "confirmed_application",
                "color_type": color_type,  # ✅ NEW
            },
            send_email=True,
            send_websocket=True
        )

    customadmins = await db.auth.find({"role": "customadmin", "is_active": True}).to_list(100)
    for customadmin in customadmins:
        ca_email = customadmin.get("email")
        if ca_email != admin_email:
            await central_notification.send_notification(
                user_ids=[ca_email],
                notification_type="customadmin_alert",
                title=f"✅ Application Confirmed: {job_title}",
                message=f"User {user_email} confirmed application for '{job_title}'",
                metadata={
                    "application_id": application_id,
                    "applicant_email": user_email,
                    "job_title": job_title,
                    "color_type": color_type,  # ✅ NEW
                },
                send_email=True,
                send_websocket=True
            )

    await central_notification.send_notification(
        user_ids=[user_email],
        notification_type="application_status",
        title="✅ Application Confirmed!",
        message=f"Your application for '{job_title}' has been confirmed successfully.",
        metadata={
            "application_id": application_id,
            "job_title": job_title,
            "status": "confirmed_application",
            "color_type": color_type,  # ✅ NEW
        },
        send_email=True,
        send_websocket=True
    )

    return {
        "success": True,
        "message": "Application confirmed successfully",
        "status": status,
        "application_id": application_id
    }


@router.post("/applications/{application_id}/submit-update")
async def submit_application_update(
    application_id: str,
    updates: List[Dict[str, str]] = Body(..., description="List of field updates"),
    notes: Optional[str] = Body(None),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Submit application update from user
    Status changes to 'update_application'
    Sends notifications to admin and customadmin
    """
    from datetime import datetime
    from app.modules.notification.service import central_notification

    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")

    user_email = current_user.get("email")
    if application.get("applicant_email") != user_email:
        raise HTTPException(status_code=403, detail="Unauthorized - This is not your application")

    current_status = application.get("status", "")
    if current_status != "review_application":
        raise HTTPException(
            status_code=400,
            detail=f"Cannot update application in '{current_status}' status. Only applications under review can be updated."
        )

    if not updates or len(updates) == 0:
        raise HTTPException(status_code=400, detail="At least one update field is required")

    update_data = {
        "status": "update_application",
        "application_updates": updates,
        "update_notes": notes,
        "update_submitted_at": datetime.utcnow(),
        "update_submitted_by": user_email,
        "updated_at": datetime.utcnow()
    }

    result = await db.applications.update_one(
        {"_id": ObjectId(application_id)},
        {"$set": update_data}
    )

    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="Application not found")

    job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))})
    job_title = job.get("post_name", "Job") if job else "Job"
    organization = job.get("organization", "Company") if job else "Company"
    color_type = job.get("color_type", "blue") if job else "blue"  # ✅ NEW

    updates_text = "\n".join([f"• {u.get('field_name', 'Field')}: {u.get('field_value', 'Value')}" for u in updates])

    admin_email = job.get("added_by") if job else None
    if admin_email:
        await central_notification.send_notification(
            user_ids=[admin_email],
            notification_type="admin_alert",
            title=f"📝 Application Update Submitted: {job_title}",
            message=f"User {user_email} has submitted an update for their application.\n\nUpdates:\n{updates_text}\n\nNotes: {notes if notes else 'No notes'}",
            metadata={
                "application_id": application_id,
                "applicant_email": user_email,
                "updates": updates,
                "notes": notes,
                "job_title": job_title,
                "status": "update_application",
                "color_type": color_type,  # ✅ NEW
            },
            send_email=True,
            send_websocket=True
        )

    customadmins = await db.auth.find({"role": "customadmin", "is_active": True}).to_list(100)
    for customadmin in customadmins:
        ca_email = customadmin.get("email")
        if ca_email != admin_email:
            await central_notification.send_notification(
                user_ids=[ca_email],
                notification_type="customadmin_alert",
                title=f"📝 Application Update: {job_title}",
                message=f"User {user_email} submitted an application update for '{job_title}'",
                metadata={
                    "application_id": application_id,
                    "applicant_email": user_email,
                    "job_title": job_title,
                    "updates_count": len(updates),
                    "color_type": color_type,  # ✅ NEW
                },
                send_email=True,
                send_websocket=True
            )

    await central_notification.send_notification(
        user_ids=[user_email],
        notification_type="application_status",
        title="📝 Application Update Submitted",
        message=f"Your update for '{job_title}' has been submitted successfully. The admin will review it.",
        metadata={
            "application_id": application_id,
            "job_title": job_title,
            "status": "update_application",
            "color_type": color_type,  # ✅ NEW
        },
        send_email=True,
        send_websocket=True
    )

    return {
        "success": True,
        "message": "Application update submitted successfully",
        "status": "update_application",
        "application_id": application_id,
        "updates_count": len(updates)
    }


@router.get("/applications/{application_id}/updates")
async def get_application_updates(
    application_id: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Get application updates for a specific application
    Used to display submitted updates to admin
    """
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")

    user_email = current_user.get("email")
    user_role = current_user.get("role", "").lower()

    is_owner = application.get("applicant_email") == user_email
    is_admin = user_role in ["admin", "customadmin", "superadmin"]

    if not (is_owner or is_admin):
        raise HTTPException(status_code=403, detail="Unauthorized")

    updates = application.get("application_updates", [])
    update_notes = application.get("update_notes")
    update_submitted_at = application.get("update_submitted_at")
    update_submitted_by = application.get("update_submitted_by")

    return {
        "success": True,
        "updates": updates,
        "notes": update_notes,
        "submitted_at": update_submitted_at.isoformat() if update_submitted_at else None,
        "submitted_by": update_submitted_by,
        "status": application.get("status")
    }


@router.put("/applications/{application_id}/admin-process-update")
async def admin_process_application_update(
    application_id: str,
    action: str = Query(..., pattern="^(approve|reject)$"),
    admin_notes: Optional[str] = Query(None),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    Admin processes an application update (approve or reject)
    """
    from datetime import datetime
    from app.modules.notification.service import central_notification

    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")

    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")

    current_status = application.get("status", "")
    if current_status != "update_application":
        raise HTTPException(
            status_code=400,
            detail=f"Cannot process update in '{current_status}' status"
        )

    admin_email = user.get("email")

    job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))})
    job_title = job.get("post_name", "Job") if job else "Job"
    color_type = job.get("color_type", "blue") if job else "blue"  # ✅ NEW
    applicant_email = application.get("applicant_email")

    if action == "approve":
        updates = application.get("application_updates", [])

        update_data = {
            "status": "approved_application",
            "update_approved_at": datetime.utcnow(),
            "update_approved_by": admin_email,
            "admin_update_notes": admin_notes,
            "updated_at": datetime.utcnow()
        }

        for update in updates:
            field_name = update.get("field_name")
            field_value = update.get("field_value")
            if field_name and field_value:
                update_data[f"additional_info.{field_name}"] = field_value

        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data}
        )

        message = "Application update approved successfully"
        status = "approved_application"

        await central_notification.send_notification(
            user_ids=[applicant_email],
            notification_type="application_status",
            title=f"✅ Application Update Approved: {job_title}",
            message=f"Your application update for '{job_title}' has been approved by admin.\n\nAdmin Notes: {admin_notes if admin_notes else 'No notes'}",
            metadata={
                "application_id": application_id,
                "job_title": job_title,
                "action": action,
                "admin_notes": admin_notes,
                "color_type": color_type,  # ✅ NEW
            },
            send_email=True,
            send_websocket=True
        )

    else:
        update_data = {
            "status": "update_rejected",
            "update_rejected_at": datetime.utcnow(),
            "update_rejected_by": admin_email,
            "admin_update_notes": admin_notes,
            "updated_at": datetime.utcnow()
        }

        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data}
        )

        message = "Application update rejected"
        status = "update_rejected"

        await central_notification.send_notification(
            user_ids=[applicant_email],
            notification_type="application_status",
            title=f"📋 Application Update Rejected: {job_title}",
            message=f"Your application update for '{job_title}' has been rejected by admin.\n\nReason: {admin_notes if admin_notes else 'Please contact support for more information'}",
            metadata={
                "application_id": application_id,
                "job_title": job_title,
                "action": action,
                "admin_notes": admin_notes,
                "color_type": color_type,  # ✅ NEW
            },
            send_email=True,
            send_websocket=True
        )

    return {
        "success": True,
        "message": message,
        "status": status,
        "application_id": application_id
    }


# ====================== BASIC CRUD ======================

@router.get("/{job_id}")
async def get_job(
    job_id: str,
    service: JobService = Depends(get_job_service)
):
    return await service.get_job(job_id)


@router.put("/{job_id}")
async def update_job(
    job_id: str,
    job_data: JobUpdateSchema,
    service: JobService = Depends(get_job_service)
):
    return await service.update_job(job_id, job_data.model_dump(exclude_none=True))


@router.delete("/{job_id}")
async def delete_job(
    job_id: str,
    service: JobService = Depends(get_job_service)
):
    return await service.delete_job(job_id)


@router.get("/ai-health")
async def ai_detector_health(
    current_user: dict = Depends(get_current_user)
):
    """Check AI fake job detector health"""
    from app.modules.jobs.AI.fake_job_detector import fake_job_detector

    return {
        "ai_fake_detector": "active" if fake_job_detector.client else "fallback_mode",
        "openai_configured": bool(settings.OPENAI_API_KEY),
        "features": [
            "AI fake job detection",
            "Duplicate prevention",
            "Auto-validation"
        ]
    }


@router.get("/nearby")
async def get_nearby_jobs(
    latitude: float = Query(..., ge=-90, le=90),
    longitude: float = Query(..., ge=-180, le=180),
    radius_km: float = Query(10.0, ge=1, le=100),
    limit: int = Query(50, ge=1, le=200),
    service: JobService = Depends(get_job_service),
    current_user: dict = Depends(get_current_user)
):
    """Get jobs near a specific location"""
    return await service.get_nearby_jobs(latitude, longitude, radius_km, limit) if hasattr(service, 'get_nearby_jobs') else {"jobs": [], "total": 0}


@router.get("/refresh-signed-url/{job_id}")
async def refresh_job_advertisement_url(
    job_id: str,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    Refresh signed URL for job advertisement (if expired)
    Returns a new signed URL valid for 24 hours
    """
    from app.core.services.cloudinary import get_signed_view_url, get_signed_download_url

    if not ObjectId.is_valid(job_id):
        raise HTTPException(status_code=400, detail="Invalid job ID")

    job = await db.job.find_one({"_id": ObjectId(job_id)})
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    public_id = job.get("advertisement_public_id")
    resource_type = job.get("advertisement_resource_type", "raw")

    if not public_id:
        raise HTTPException(status_code=404, detail="No advertisement found for this job")

    new_view_url = await get_signed_view_url(public_id, resource_type, expires_seconds=86400)
    new_download_url = await get_signed_download_url(public_id, resource_type, expires_seconds=86400)

    await db.job.update_one(
        {"_id": ObjectId(job_id)},
        {
            "$set": {
                "advertisement_url": new_view_url,
                "advertisement_download_url": new_download_url,
                "advertisement_url_refreshed_at": datetime.utcnow()
            }
        }
    )

    return {
        "success": True,
        "url": new_view_url,
        "download_url": new_download_url,
        "expires_in_hours": 24,
        "message": "Signed URL refreshed successfully"
    }


@router.get("/{job_id}/application-fees")
async def get_job_application_fees(
    job_id: str,
    service: JobService = Depends(get_job_service),
    current_user: dict = Depends(get_current_user)
):
    """Get application fees for a specific job"""
    return await service.get_application_fees(job_id)


# ====================== APPLY WITH PAYMENT ENDPOINT ======================

@router.post("/apply-with-payment/{job_id}")
async def apply_with_payment(
    job_id: str,
    payment_id: str = Query(..., description="Payment ID from QR generation"),
    application_data: ApplicationCreateSchema = Body(...),
    service: JobService = Depends(get_job_service),
    user=Depends(get_current_user)
):
    """
    ✅ FIXED: User applies to a job with payment verification
    - IDEMPOTENT: No duplicate applications
    - NO payment_pending status
    - Application created ONLY after payment success
    """
    return await service.apply_with_payment_idempotent(job_id, application_data, user, payment_id)


# ====================== UPDATE PAYMENT STATUS ENDPOINT ======================

@router.post("/update-payment-status/{job_id}")
async def update_job_payment_status(
    job_id: str,
    update_data: dict = Body(...),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """
    ✅ FIXED: Update application payment status after successful verification
    """
    try:
        user_email = current_user.get("email")
        payment_id = update_data.get("payment_id")
        razorpay_payment_id = update_data.get("razorpay_payment_id")
        razorpay_order_id = update_data.get("razorpay_order_id")
        razorpay_signature = update_data.get("razorpay_signature")
        transaction_id = update_data.get("transaction_id") or razorpay_payment_id
        payment_status = update_data.get("payment_status", "completed")
        amount = update_data.get("amount")

        logger.info("=" * 70)
        logger.info("📤 Updating APPLICATION status on server...")
        logger.info(f"   Job ID: {job_id}")
        logger.info(f"   User: {user_email}")
        logger.info(f"   Payment ID: {payment_id}")
        logger.info(f"   Razorpay Payment ID: {razorpay_payment_id}")
        logger.info(f"   Status: {payment_status}")
        logger.info("=" * 70)

        app_query = {"user_email": user_email, "job_id": job_id, "application_type": "job"}
        if payment_id and ObjectId.is_valid(payment_id):
            app_query = {"_id": ObjectId(payment_id)}
        elif razorpay_order_id:
            app_query = {"razorpay_order_id": razorpay_order_id}

        application = await db.applications.find_one(app_query)

        if not application:
            logger.warning(f"⚠️ Application not found for job_id: {job_id}")
            application = await db.applications.find_one({
                "user_email": user_email,
                "job_id": job_id,
                "application_type": "job"
            })

        if not application:
            logger.error(f"❌ Application not found for: {app_query}")
            return {
                "success": False,
                "message": "Application not found"
            }

        application_id = str(application["_id"])

        update_data_db = {
            "status": "verification_successful",
            "payment_verification_status": "approved",
            "transaction_id": transaction_id,
            "razorpay_payment_id": razorpay_payment_id,
            "razorpay_order_id": razorpay_order_id,
            "razorpay_signature": razorpay_signature,
            "paid_at": datetime.utcnow(),
            "payment_verified_at": datetime.utcnow(),
            "payment_verified_by": user_email or "system",
            "updated_at": datetime.utcnow()
        }

        if amount:
            update_data_db["payment_amount"] = int(amount)

        await db.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data_db}
        )

        logger.info(f"✅ Application {application_id} updated to verification_successful")

        applicant_email = application.get("applicant_email") or application.get("user_email")
        if applicant_email:
            from app.modules.notification.service import central_notification
            await central_notification.send_notification(
                user_ids=[applicant_email],
                notification_type="application_status",
                title="✅ Payment Verified Successfully",
                message=f"Your payment of ₹{amount} for '{application.get('job_title', 'Job')}' has been verified successfully.\n\nTransaction ID: {razorpay_payment_id}\nOrder ID: {razorpay_order_id}\n\nYour application has been submitted.",
                metadata={
                    "status": "verification_successful",
                    "amount": amount,
                    "transaction_id": razorpay_payment_id,
                    "show_blue_bell": True,
                    "job_title": application.get("job_title", "Job"),
                    "application_id": application_id,
                    "razorpay_payment_id": razorpay_payment_id,
                    "razorpay_order_id": razorpay_order_id,
                    "color_type": application.get("color_type", "blue"),  # ✅ NEW
                },
                send_email=True,
                send_websocket=True
            )

        return {
            "success": True,
            "message": "Application payment status updated successfully",
            "application_id": application_id,
            "status": "verification_successful"
        }

    except Exception as e:
        logger.error(f"❌ Error updating payment status: {e}")
        import traceback
        traceback.print_exc()
        return {
            "success": False,
            "message": str(e)
        }


# ====================== SAVE JOB (BOOKMARK) ENDPOINTS ======================

@router.post("/save/{job_id}")
async def save_job_endpoint(
    job_id: str,
    service: JobService = Depends(get_job_service),
    current_user: dict = Depends(get_current_user)
):
    """
    Save a job (Bookmark) - creates application with status='saved'
    """
    return await service.save_job(job_id, current_user)


@router.delete("/save/{job_id}")
async def unsave_job_endpoint(
    job_id: str,
    service: JobService = Depends(get_job_service),
    current_user: dict = Depends(get_current_user)
):
    """
    Remove saved job (delete application with status='saved')
    """
    return await service.unsave_job(job_id, current_user)


@router.get("/saved")
async def get_saved_jobs_endpoint(
    service: JobService = Depends(get_job_service),
    current_user: dict = Depends(get_current_user)
):
    """
    Get all saved jobs (status='saved')
    """
    return await service.get_saved_jobs(current_user)


@router.get("/applied")
async def get_applied_jobs_endpoint(
    service: JobService = Depends(get_job_service),
    current_user: dict = Depends(get_current_user)
):
    """
    Get all applied jobs (status != 'saved')
    """
    return await service.get_applied_jobs(current_user)


@router.get("/check-saved/{job_id}")
async def check_job_saved(
    job_id: str,
    service: JobService = Depends(get_job_service),
    current_user: dict = Depends(get_current_user)
):
    """
    Check if a job is saved by the current user
    """
    is_saved = await service.is_job_saved(job_id, current_user)
    is_applied = await service.is_job_applied(job_id, current_user)

    return {
        "success": True,
        "is_saved": is_saved,
        "is_applied": is_applied,
        "status": "saved" if is_saved else ("applied" if is_applied else "none")
    }


@router.post("/convert-saved-to-applied/{job_id}")
async def convert_saved_to_applied_endpoint(
    job_id: str,
    application_data: ApplicationCreateSchema,
    payment_id: Optional[str] = Query(None, description="Payment ID if payment was made"),
    service: JobService = Depends(get_job_service),
    current_user: dict = Depends(get_current_user)
):
    """
    Convert a saved job (status='saved') to applied (with payment if required)
    """
    return await service.convert_saved_to_applied(
        job_id, application_data, current_user, payment_id
    )


print("✅ Centralized Job Routes Loaded - NO apply_mode, uses status='saved' only")
print("✅ apply-with-payment endpoint FIXED - Idempotent, NO payment_pending")
print("✅ update-payment-status endpoint FIXED - Logger added, Idempotent, NO payment_pending")
print("✅ NEW: color_type query param added to list_jobs")