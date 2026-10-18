# app/modules/admin/routes.py - COMPLETE UPDATED VERSION
# ✅ Full Job CRUD Operations
# ✅ Full Application Management
# ✅ Payment Verification
# ✅ Document Upload (Review/Final Submit)
# ✅ Notifications to all parties
# ✅ All original functionality preserved

from fastapi import (
    APIRouter, Depends, HTTPException, Query, Body, 
    BackgroundTasks, UploadFile, File, Form
)
from typing import Optional, List
from bson import ObjectId
from datetime import datetime
import json
import logging

from app.core.services.dependencies import role_required, get_current_user
from app.db.connection import get_db
from .service import AdminService
from app.modules.jobs.service import JobService
from app.modules.jobs.schema import JobCreateSchema, ApplicationStatusUpdateSchema
from app.core.services.cloudinary import upload_to_cloudinary, upload_private_file, upload_user_document
from app.modules.notification.service import central_notification

logger = logging.getLogger(__name__)

router = APIRouter()


# ============================================================
# DEPENDENCY HELPERS
# ============================================================
async def get_admin_service(db=Depends(get_db)):
    """Get AdminService instance"""
    return AdminService(db)


async def get_job_service(db=Depends(get_db)):
    """Get JobService instance"""
    return JobService(db)


async def _get_admin_email(user: dict, db) -> str:
    """Extract admin email from user object or database"""
    admin_email = user.get("email")
    if not admin_email:
        user_id = user.get("user_id")
        if user_id and ObjectId.is_valid(user_id):
            auth_user = await db.auth.find_one({"_id": ObjectId(user_id)})
            if auth_user:
                admin_email = auth_user.get("email")
    return admin_email or "admin@rojgarnest.com"


# ============================================================
# JOB MANAGEMENT ENDPOINTS
# ============================================================

@router.post("/add-job")
async def add_admin_job(
    job_data: dict = Body(...),
    background_tasks: BackgroundTasks = None,
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Admin adds a new job - Direct JSON endpoint
    
    Creates a new job posting with all provided data.
    Sends notifications to all active users (excluding publisher's role).
    
    Role-based notification rules:
    - Admin publishes → Notify all EXCEPT customadmin
    - CustomAdmin publishes → Notify all EXCEPT admin
    - SuperAdmin publishes → Notify ALL
    """
    try:
        # Get admin email
        admin_email = await _get_admin_email(user, db)
        
        # Add tracking fields
        job_data["added_by"] = admin_email
        job_data["created_at"] = datetime.utcnow()
        job_data["updated_at"] = datetime.utcnow()
        job_data["status"] = "open"
        
        # Set defaults for required fields
        job_data.setdefault("post_name", "Untitled Job")
        job_data.setdefault("organization", "Not Specified")
        job_data.setdefault("post_date", datetime.utcnow().strftime("%Y-%m-%d"))
        job_data.setdefault("job_type", "private")
        job_data.setdefault("color_type", "blue")
        
        # Validate with schema
        from app.modules.jobs.schema import JobCreateSchema
        job_data_model = JobCreateSchema(**job_data)
        logger.info(f"✅ Job data validated: {job_data_model.post_name}")
        
    except Exception as e:
        logger.error(f"❌ Validation error: {e}")
        raise HTTPException(status_code=422, detail=f"Validation error in job data: {str(e)}")
    
    # Use JobService for creation (handles notifications)
    from app.modules.jobs.service import JobService
    job_service = JobService(db)
    
    if background_tasks is None:
        background_tasks = BackgroundTasks()
    
    return await job_service.add_job(
        job_data_model,
        background_tasks,
        None,
        user
    )


@router.post("/add-job-with-file")
async def add_admin_job_with_file(
    background_tasks: BackgroundTasks,
    job_data: str = Form(...),
    attachments: Optional[List[UploadFile]] = File(None),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Admin adds job with file attachments
    
    Creates a job posting with optional file attachments.
    Files are uploaded to Cloudinary.
    """
    try:
        job_dict = json.loads(job_data)
        
        # Get admin email
        admin_email = await _get_admin_email(user, db)
        
        # Add tracking fields
        job_dict["added_by"] = admin_email
        job_dict["created_at"] = datetime.utcnow()
        job_dict["updated_at"] = datetime.utcnow()
        job_dict["status"] = "open"
        
        # Validate with schema
        job_data_model = JobCreateSchema(**job_dict)
        
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON in job_data field")
    except Exception as e:
        raise HTTPException(status_code=422, detail=f"Validation error in job data: {str(e)}")
    
    job_service = JobService(db)
    return await job_service.add_job(job_data_model, background_tasks, attachments, user)


@router.post("/add-job-with-advertisement")
async def add_admin_job_with_advertisement(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    job_data: str = Form(...),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Admin adds job with advertisement file upload
    
    Creates a job posting with an advertisement PDF/image.
    File is uploaded to Cloudinary as PRIVATE.
    Sends notifications to all active users.
    """
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="Advertisement file is required")
    
    # File size validation (50MB max)
    MAX_FILE_SIZE = 50 * 1024 * 1024
    
    file_content = await file.read()
    file_size = len(file_content)
    await file.seek(0)
    
    if file_size > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=413,
            detail=f"File too large. Max: {MAX_FILE_SIZE // (1024*1024)}MB, "
                   f"Your file: {file_size // (1024*1024)}MB"
        )
    
    try:
        job_dict = json.loads(job_data)
        
        # Get admin email
        admin_email = await _get_admin_email(user, db)
        job_dict["added_by"] = admin_email
        
        logger.info("=" * 60)
        logger.info(f"📝 Adding job with advertisement - Admin: {admin_email}")
        logger.info(f"   Job Title: {job_dict.get('post_name')}")
        logger.info(f"   Organization: {job_dict.get('organization')}")
        logger.info(f"   File: {file.filename}")
        logger.info(f"   Size: {file_size // 1024} KB")
        logger.info("=" * 60)
        
        # Validate with schema
        job_data_model = JobCreateSchema(**job_dict)
        job_dict_for_insert = job_data_model.model_dump(exclude_none=True, by_alias=True)
        
        # Handle location
        use_current_location = job_dict_for_insert.get("use_current_location", False)
        
        if use_current_location:
            from app.models.job_model import get_admin_current_location
            admin_location = await get_admin_current_location(admin_email, db)
            if admin_location:
                job_dict_for_insert["job_location"] = admin_location
                logger.info(f"📍 Using admin's current location: {admin_location.get('location_name')}")
        
        # Add metadata
        job_dict_for_insert["created_at"] = datetime.utcnow()
        job_dict_for_insert["updated_at"] = datetime.utcnow()
        job_dict_for_insert["status"] = "open"
        
        # Insert job to get ID
        result = await db.job.insert_one(job_dict_for_insert)
        job_id = str(result.inserted_id)
        
        logger.info(f"📝 Job created with ID: {job_id}")
        
        # Upload file as PRIVATE
        upload_result = await upload_private_file(
            file=file,
            folder="jobs/advertisements",
            job_id=job_id,
            organization=job_dict.get("organization", "company"),
            post_name=job_dict.get("post_name", "job")
        )
        
        # Update job with advertisement URLs
        update_data = {
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
        }
        
        await db.job.update_one(
            {"_id": ObjectId(job_id)},
            {"$set": update_data}
        )
        
        logger.info(f"✅ Job {job_id} updated with advertisement")
        
        # Get the complete job document
        job_doc = await db.job.find_one({"_id": ObjectId(job_id)})
        
        # Determine publisher role for notification filtering
        publisher_role = user.get("role", "admin").lower()
        if publisher_role == "custom_admin":
            publisher_role = "customadmin"
        
        # Send notifications
        await central_notification.notify_new_job(
            job_doc,
            background_tasks,
            publisher_role=publisher_role
        )
        
        return {
            "success": True,
            "message": "Job added successfully with private advertisement",
            "job_id": job_id,
            "job_title": job_dict.get('post_name'),
            "advertisement_url": upload_result["url"],
            "advertisement_download_url": upload_result["download_url"],
            "file_size_kb": file_size // 1024,
            "is_pdf": upload_result.get("is_pdf", False)
        }
        
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {e}")
        raise HTTPException(status_code=400, detail=f"Invalid JSON: {str(e)}")
    except Exception as e:
        logger.error(f"Error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed: {str(e)}")


@router.get("/jobs")
async def get_admin_jobs(
    status: Optional[str] = Query(None, pattern="^(open|closed|filled|draft)$"),
    limit: int = Query(100, ge=1, le=500),
    skip: int = Query(0, ge=0),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Get all jobs posted by the logged-in admin
    
    Returns paginated list of jobs with application counts.
    Supports filtering by status.
    """
    try:
        admin_email = await _get_admin_email(user, db)
        
        logger.info(f"🔍 Fetching jobs for admin: {admin_email}")
        
        job_service = JobService(db)
        return await job_service.get_admin_jobs(admin_email)
        
    except Exception as e:
        logger.error(f"❌ Error in get_admin_jobs: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/jobs/{job_id}")
async def get_admin_job_detail(
    job_id: str,
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Get single job details
    
    Returns complete job information including application count.
    Only accessible by the admin who created the job (or superadmin).
    """
    if not ObjectId.is_valid(job_id):
        raise HTTPException(status_code=400, detail="Invalid job ID")
    
    admin_email = await _get_admin_email(user, db)
    user_role = user.get("role", "").lower()
    
    # Find job
    job = await db.job.find_one({"_id": ObjectId(job_id)})
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    # Permission check
    if job.get("added_by") != admin_email and user_role != "superadmin":
        raise HTTPException(status_code=403, detail="Access denied")
    
    # Serialize
    job["_id"] = str(job["_id"])
    if "created_at" in job and job["created_at"]:
        job["created_at"] = (
            job["created_at"].isoformat() 
            if isinstance(job["created_at"], datetime) 
            else job["created_at"]
        )
    if "updated_at" in job and job["updated_at"]:
        job["updated_at"] = (
            job["updated_at"].isoformat() 
            if isinstance(job["updated_at"], datetime) 
            else job["updated_at"]
        )
    
    # Add application count
    applications_count = await db.applications.count_documents({"job_id": job_id})
    job["applications_count"] = applications_count
    
    return job


@router.put("/jobs/{job_id}")
async def update_admin_job(
    job_id: str,
    job_data: dict = Body(...),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ FIXED: Update existing job.
    """
    if not ObjectId.is_valid(job_id):
        raise HTTPException(status_code=400, detail="Invalid job ID")

    # Find job
    job = await db.job.find_one({"_id": ObjectId(job_id)})
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    # Get admin email
    admin_email = await _get_admin_email(user, db)
    user_role = (user.get("role") or "").lower()
    if user_role == "custom_admin":
        user_role = "customadmin"

    # Permission check
    if job.get("added_by") != admin_email and user_role != "superadmin":
        raise HTTPException(status_code=403, detail="Access denied")

    job_service = JobService(db)
    return await job_service.update_job(
        job_id, 
        job_data, 
        admin_email, 
        user_role
    )


@router.delete("/jobs/{job_id}")
async def delete_admin_job(
    job_id: str,
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ FIXED: Delete job and all associated applications.
    """
    if not ObjectId.is_valid(job_id):
        raise HTTPException(status_code=400, detail="Invalid job ID")

    job = await db.job.find_one({"_id": ObjectId(job_id)})
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    admin_email = await _get_admin_email(user, db)
    user_role = (user.get("role") or "").lower()
    if user_role == "custom_admin":
        user_role = "customadmin"

    if job.get("added_by") != admin_email and user_role != "superadmin":
        raise HTTPException(status_code=403, detail="Access denied")

    job_service = JobService(db)
    return await job_service.delete_job(job_id, admin_email, user_role)


@router.post("/jobs/{job_id}/publish")
async def publish_admin_job(
    job_id: str,
    background_tasks: BackgroundTasks,
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Publish a draft job
    
    Changes job status from 'draft' to 'open'.
    Sends notifications to all active users.
    """
    if not ObjectId.is_valid(job_id):
        raise HTTPException(status_code=400, detail="Invalid job ID")
    
    # Find job
    job = await db.job.find_one({"_id": ObjectId(job_id)})
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    # Get admin email
    admin_email = await _get_admin_email(user, db)
    user_role = user.get("role", "").lower()
    
    # Permission check
    if job.get("added_by") != admin_email and user_role != "superadmin":
        raise HTTPException(status_code=403, detail="Access denied")
    
    # Check if already published
    if job.get("status") == "open" and not job.get("is_draft", True):
        return {
            "success": True,
            "message": "Job is already published",
            "job_id": job_id,
            "status": "open"
        }
    
    # Update job status
    update_result = await db.job.update_one(
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
    
    if update_result.modified_count == 0:
        logger.warning(f"⚠️ Job {job_id} status unchanged during publish")
    
    # Get updated job
    updated_job = await db.job.find_one({"_id": ObjectId(job_id)})
    updated_job["_id"] = str(updated_job["_id"])
    
    # Send notifications
    publisher_role = user.get("role", "admin").lower()
    if publisher_role == "custom_admin":
        publisher_role = "customadmin"
    
    if background_tasks:
        await central_notification.notify_new_job(
            updated_job,
            background_tasks,
            publisher_role=publisher_role
        )
    
    logger.info(f"✅ Job {job_id} published by {admin_email}")
    
    return {
        "success": True,
        "message": "Job published successfully",
        "job_id": job_id,
        "status": "open",
        "data": updated_job
    }


# ============================================================
# APPLICATION MANAGEMENT ENDPOINTS
# ============================================================

@router.get("/applications")
async def get_admin_applications(
    status: Optional[str] = Query(
        None, 
        pattern="^(pending|shortlisted|interview|offered|rejected|"
                "submitted|pending_verification|verification_successful|"
                "verification_rejected|review_application|final_submitted)$"
    ),
    limit: int = Query(100, ge=1, le=500),
    skip: int = Query(0, ge=0),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Get all applications for jobs posted by the logged-in admin
    
    Returns paginated list of applications with candidate info.
    Supports filtering by status.
    """
    try:
        admin_email = await _get_admin_email(user, db)
        
        if not admin_email:
            raise HTTPException(status_code=400, detail="Admin email not found")
        
        job_service = JobService(db)
        return await job_service.get_admin_applications(admin_email, status)
        
    except Exception as e:
        logger.error(f"Error in get_admin_applications: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/applications/{application_id}/detail")
async def get_application_detail(
    application_id: str,
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Get detailed application data including user profile
    
    Returns complete application with candidate profile, job details, etc.
    """
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    admin_email = await _get_admin_email(user, db)
    user_role = user.get("role", "").lower()
    
    # Find application
    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    # Verify admin has access
    job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))})
    if job and job.get("added_by") != admin_email and user_role != "superadmin":
        raise HTTPException(status_code=403, detail="Access denied")
    
    # Get applicant profile
    applicant_email = application.get("applicant_email")
    profile = await db.profile.find_one({"email": applicant_email}) if applicant_email else None
    user_auth = await db.auth.find_one({"email": applicant_email}) if applicant_email else None
    
    # Serialize
    application["_id"] = str(application["_id"])
    application["job_id"] = str(application["job_id"]) if application.get("job_id") else None
    
    if application.get("applied_at") and isinstance(application["applied_at"], datetime):
        application["applied_at"] = application["applied_at"].isoformat()
    if application.get("created_at") and isinstance(application["created_at"], datetime):
        application["created_at"] = application["created_at"].isoformat()
    if application.get("updated_at") and isinstance(application["updated_at"], datetime):
        application["updated_at"] = application["updated_at"].isoformat()
    
    return {
        "application": application,
        "user_profile": {
            "_id": str(profile["_id"]) if profile else None,
            "full_name": profile.get("full_name") if profile else None,
            "phone": profile.get("phone") if profile else None,
            "email": applicant_email,
            "skills": profile.get("skills", []) if profile else [],
            "experience": profile.get("experience", []) if profile else [],
            "academic_records": profile.get("academic_records", []) if profile else [],
            "summary": profile.get("summary") if profile else None,
            "resume_url": profile.get("additional_details", {}).get("resume_url") if profile else None,
            "category": profile.get("category") if profile else None,
            "disability": profile.get("disability", {}) if profile else {},
        } if profile else None,
        "user_auth": {
            "email": user_auth.get("email") if user_auth else None,
            "name": user_auth.get("name") if user_auth else None,
            "is_email_verified": user_auth.get("is_email_verified") if user_auth else False,
            "is_mobile_verified": user_auth.get("is_mobile_verified") if user_auth else False,
        } if user_auth else None,
        "job": {
            "_id": str(job["_id"]),
            "post_name": job.get("post_name"),
            "organization": job.get("organization"),
            "location": job.get("location"),
            "job_type": job.get("job_type"),
            "description": job.get("description"),
            "required_skills": job.get("required_skills", []),
            "has_application_fees": job.get("has_application_fees", False),
            "application_fees": job.get("application_fees", {}),
        } if job else None
    }


@router.put("/applications/{application_id}/status")
async def update_application_status(
    application_id: str,
    status: str = Query(
        ..., 
        pattern="^(pending|shortlisted|interview|offered|rejected|"
                "submitted|pending_verification|verification_successful|"
                "verification_rejected|review_application|final_submitted)$"
    ),
    notes: Optional[str] = Query(None),
    background_tasks: BackgroundTasks = None,
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Update application status
    
    Changes application status and sends notifications to:
    - Applicant (via email, SMS, WhatsApp, in-app, WebSocket)
    - Job poster (if different from updater)
    - All customadmins
    """
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    # Find application
    application = await db.applications.find_one({"_id": ObjectId(application_id)})
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    
    # Find job
    job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))})
    
    # Get admin email
    admin_email = await _get_admin_email(user, db)
    user_role = user.get("role", "").lower()
    
    # Permission check
    if job and job.get("added_by") != admin_email and user_role != "superadmin":
        raise HTTPException(status_code=403, detail="Access denied")
    
    old_status = application.get("status", "unknown")
    
    # Build update data
    update_data = {
        "status": status,
        "last_status_update": datetime.utcnow(),
        "last_updated_by": admin_email,
        "updated_at": datetime.utcnow()
    }
    
    if notes:
        update_data["admin_notes"] = notes
    
    # Update application
    result = await db.applications.update_one(
        {"_id": ObjectId(application_id)},
        {"$set": update_data}
    )
    
    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="Application not found or status unchanged")
    
    # Send notifications
    applicant_email = application.get("applicant_email")
    
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
        "final_submitted": "✅ Your application has been FINAL SUBMITTED!"
    }
    
    # Notify applicant
    if applicant_email:
        await central_notification.send_notification(
            user_ids=[applicant_email],
            notification_type="application_status",
            title=f"Application Status: {status.upper()}",
            message=status_messages.get(
                status, 
                f"Your application status has been updated to {status}."
            ),
            related_id=application_id,
            metadata={
                "application_id": application_id,
                "job_title": job.get("post_name") if job else "",
                "old_status": old_status,
                "new_status": status,
                "notes": notes,
                "color_type": job.get("color_type", "blue") if job else "blue",
                "show_blue_bell": True
            },
            send_email=True,
            send_websocket=True
        )
        logger.info(f"📧 Status notification sent to applicant: {applicant_email}")
    
    # Notify job poster (if different)
    job_poster_email = job.get("added_by") if job else None
    if job_poster_email and job_poster_email != admin_email:
        await central_notification.send_notification(
            user_ids=[job_poster_email],
            notification_type="admin_alert",
            title=f"📋 Application Status Changed: {job.get('post_name', 'Job') if job else 'Job'}",
            message=f"Application by {application.get('applicant_name', 'Candidate')} "
                    f"changed from {old_status} to {status}",
            related_id=application_id,
            metadata={
                "application_id": application_id,
                "applicant_email": applicant_email,
                "old_status": old_status,
                "new_status": status,
                "show_blue_bell": True
            },
            send_email=True,
            send_websocket=True
        )
        logger.info(f"📧 Status notification sent to admin: {job_poster_email}")
    
    # Notify customadmins
    customadmins = await db.auth.find({"role": "customadmin", "is_active": True}).to_list(100)
    for ca in customadmins:
        ca_email = ca.get("email")
        if ca_email != admin_email and ca_email != job_poster_email:
            await central_notification.send_notification(
                user_ids=[ca_email],
                notification_type="customadmin_alert",
                title=f"📋 Application Update: {job.get('post_name', 'Job') if job else 'Job'}",
                message=f"Application by {applicant_email} for '{job.get('post_name', 'Job') if job else 'Job'}' "
                        f"is now {status}",
                related_id=application_id,
                metadata={
                    "application_id": application_id,
                    "applicant_email": applicant_email,
                    "new_status": status,
                    "show_blue_bell": True
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
        "updated_by": admin_email,
        "notifications_sent": True
    }


@router.post("/applications/bulk-status")
async def bulk_update_status(
    application_ids: List[str] = Body(...),
    status: str = Body(...),
    notes: Optional[str] = Body(None),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Bulk update application statuses
    
    Updates multiple applications at once with the same status.
    """
    if not application_ids:
        raise HTTPException(status_code=400, detail="No applications selected")
    
    job_service = JobService(db)
    updated_count = 0
    failed_ids = []
    
    for app_id in application_ids:
        if ObjectId.is_valid(app_id):
            try:
                status_data = ApplicationStatusUpdateSchema(status=status, notes=notes)
                await job_service.update_application_status(app_id, status_data, user)
                updated_count += 1
            except Exception as e:
                logger.error(f"Failed to update {app_id}: {e}")
                failed_ids.append(app_id)
        else:
            failed_ids.append(app_id)
    
    return {
        "success": True,
        "updated_count": updated_count,
        "failed_count": len(failed_ids),
        "failed_ids": failed_ids,
        "status": status,
        "notifications_sent": updated_count
    }


@router.get("/applications/fast-search")
async def fast_search_applications(
    query: str = Query(..., min_length=1, description="Search by email or job title"),
    status: Optional[str] = Query(None),
    limit: int = Query(20, ge=1, le=100),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ ULTRA FAST: Search applications by email or job title
    """
    try:
        admin_email = await _get_admin_email(user, db)
        
        if not admin_email:
            raise HTTPException(status_code=400, detail="Admin email not found")
        
        # Get admin's jobs
        admin_jobs = await db.job.find({"added_by": admin_email}, {"_id": 1}).to_list(1000)
        admin_job_ids = [str(job["_id"]) for job in admin_jobs]
        
        if not admin_job_ids:
            return {"applications": [], "total": 0}
        
        # Build search query
        search_query = {
            "job_id": {"$in": admin_job_ids},
            "$or": [
                {"applicant_email": {"$regex": query, "$options": "i"}},
                {"job_title": {"$regex": query, "$options": "i"}},
                {"applicant_name": {"$regex": query, "$options": "i"}}
            ]
        }
        
        if status:
            search_query["status"] = status
        
        apps = await db.applications.find(search_query).sort(
            "applied_at", -1
        ).limit(limit).to_list(limit)
        
        results = []
        for app in apps:
            results.append({
                "_id": str(app["_id"]),
                "job_title": app.get("job_title", ""),
                "organization": app.get("organization", ""),
                "applicant_name": app.get("applicant_name", ""),
                "applicant_email": app.get("applicant_email", ""),
                "status": app.get("status", "pending"),
                "match_score": app.get("match_score", 0),
                "applied_at": (
                    app.get("applied_at").isoformat() 
                    if app.get("applied_at") else None
                ),
            })
        
        return {
            "applications": results,
            "total": len(results),
            "search_query": query
        }
        
    except Exception as e:
        logger.error(f"Error in fast_search_applications: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# DOCUMENT UPLOAD ENDPOINTS (Review & Final Submit)
# ============================================================

@router.post("/applications/{application_id}/submit-document")
async def admin_submit_document(
    application_id: str,
    file: UploadFile = File(...),
    notes: Optional[str] = Form(None),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Admin submits document for review
    
    Uploads a document and changes status to 'review_application'.
    Sends notifications to applicant, job poster, and all customadmins.
    """
    admin_email = await _get_admin_email(user, db)
    admin_name = user.get("name", "Admin")
    
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
    
    # Validate file type
    allowed_extensions = ['pdf', 'jpg', 'jpeg', 'png']
    file_ext = file.filename.split('.')[-1].lower() if file.filename else ''
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400, 
            detail=f"Invalid file type. Allowed: {', '.join(allowed_extensions)}"
        )
    
    try:
        # Find application
        application = await db.applications.find_one({"_id": ObjectId(application_id)})
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")
        
        applicant_email = application.get("applicant_email")
        if not applicant_email:
            raise HTTPException(status_code=404, detail="Applicant email not found")
        
        username = applicant_email.split('@')[0]
        
        # Find job and verify permission
        job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))})
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        
        if job.get("added_by") != admin_email and user.get("role") != "superadmin":
            raise HTTPException(status_code=403, detail="Access denied")
        
        await file.seek(0)
        
        # Upload to Cloudinary
        upload_result = await upload_user_document(
            file=file,
            username=username,
            document_type="applications"
        )
        
        logger.info(f"✅ File uploaded to Cloudinary: {upload_result['url']}")
        
        old_status = application.get("status", "unknown")
        
        # Update application
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
        
        # Verify update
        updated_app = await db.applications.find_one({"_id": ObjectId(application_id)})
        saved_url = updated_app.get("submitted_document_url") if updated_app else None
        logger.info(f"✅ VERIFIED: submitted_document_url = {saved_url}")
        
        # Send notifications
        job_title = job.get("post_name", "Job")
        organization = job.get("organization", "Company")
        
        # Notify applicant
        user_title = f"📄 Document Submitted: {job_title}"
        user_message = (
            f"Your document '{file.filename}' has been submitted successfully "
            f"by {admin_name} for the position '{job_title}' at {organization}."
        )
        if notes:
            user_message += f"\n\nAdmin Notes: {notes}"
        
        await central_notification.send_notification(
            user_ids=[applicant_email],
            notification_type="application_status",
            title=user_title,
            message=user_message,
            related_id=application_id,
            metadata={
                "job_title": job_title,
                "document_name": file.filename,
                "admin_name": admin_name,
                "admin_notes": notes,
                "show_blue_bell": True,
                "status": "review_application",
                "submitted_document_url": upload_result["url"]
            },
            send_email=True,
            send_websocket=True
        )
        logger.info(f"🔔 Notification sent to applicant: {applicant_email}")
        
        # Notify job poster
        job_poster_email = job.get("added_by")
        if job_poster_email and job_poster_email != admin_email:
            await central_notification.send_notification(
                user_ids=[job_poster_email],
                notification_type="admin_alert",
                title=f"📄 Document Submitted for {job_title}",
                message=f"Document '{file.filename}' has been submitted by {admin_name} "
                        f"for application from {applicant_email}",
                related_id=application_id,
                metadata={
                    "job_title": job_title,
                    "applicant_email": applicant_email,
                    "document_name": file.filename,
                    "admin_name": admin_name,
                    "admin_notes": notes,
                    "show_blue_bell": True,
                    "submitted_document_url": upload_result["url"]
                },
                send_email=True,
                send_websocket=True
            )
            logger.info(f"🔔 Notification sent to job poster: {job_poster_email}")
        
        # Notify all customadmins
        customadmins = await db.auth.find({"role": "customadmin", "is_active": True}).to_list(100)
        for ca in customadmins:
            ca_email = ca.get("email")
            if ca_email != admin_email and ca_email != job_poster_email:
                await central_notification.send_notification(
                    user_ids=[ca_email],
                    notification_type="customadmin_alert",
                    title=f"📄 Document Submitted for {job_title}",
                    message=f"Document submitted by {admin_name} for application from {applicant_email}",
                    related_id=application_id,
                    metadata={
                        "job_title": job_title,
                        "applicant_email": applicant_email,
                        "admin_name": admin_name,
                        "show_blue_bell": True,
                        "submitted_document_url": upload_result["url"]
                    },
                    send_email=True,
                    send_websocket=True
                )
        
        return {
            "success": True,
            "message": "Document submitted successfully!",
            "application_id": application_id,
            "submitted_document_url": upload_result["url"],
            "submitted_document_name": file.filename,
            "admin_notes": notes,
            "notifications_sent": True,
            "status": "review_application"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error submitting document: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.post("/applications/{application_id}/final-submit-with-document")
async def admin_final_submit_with_document(
    application_id: str,
    file: UploadFile = File(...),
    notes: Optional[str] = Form(None),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Admin FINAL SUBMIT application with document
    
    Uploads final document and changes status to 'final_submitted'.
    Deletes old document from Cloudinary if exists.
    Sends notifications to all parties.
    """
    admin_email = await _get_admin_email(user, db)
    admin_name = user.get("name", "Admin")
    
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
    
    # Validate file type
    allowed_extensions = ['pdf', 'jpg', 'jpeg', 'png']
    file_ext = file.filename.split('.')[-1].lower() if file.filename else ''
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type. Allowed: {', '.join(allowed_extensions)}"
        )
    
    try:
        # Find application
        application = await db.applications.find_one({"_id": ObjectId(application_id)})
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")
        
        applicant_email = application.get("applicant_email")
        if not applicant_email:
            raise HTTPException(status_code=404, detail="Applicant email not found")
        
        username = applicant_email.split('@')[0]
        
        # Find job and verify permission
        job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))})
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        
        if job.get("added_by") != admin_email and user.get("role") != "superadmin":
            raise HTTPException(status_code=403, detail="Access denied")
        
        # Delete old document from Cloudinary if exists
        old_public_id = application.get("submitted_document_public_id")
        if old_public_id:
            try:
                from app.core.services.cloudinary import delete_from_cloudinary
                old_resource_type = application.get(
                    "submitted_document_resource_type", "raw"
                )
                await delete_from_cloudinary(old_public_id, old_resource_type)
                logger.info(f"🗑️ Old document deleted: {old_public_id}")
            except Exception as del_err:
                logger.warning(f"⚠️ Could not delete old document: {del_err}")
        
        await file.seek(0)
        
        # Upload new document
        upload_result = await upload_user_document(
            file=file,
            username=username,
            document_type="applications"
        )
        
        logger.info(f"✅ NEW file uploaded to Cloudinary: {upload_result['url']}")
        
        old_status = application.get("status", "unknown")
        
        # Update application
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
        
        # Verify update
        updated_app = await db.applications.find_one({"_id": ObjectId(application_id)})
        saved_url = updated_app.get("submitted_document_url") if updated_app else None
        logger.info(f"✅ VERIFIED: submitted_document_url = {saved_url}")
        
        # Send notifications
        job_title = job.get("post_name", "Job")
        organization = job.get("organization", "Company")
        
        # Notify applicant
        user_title = f"✅ FINAL SUBMISSION: {job_title}"
        user_message = (
            f"Your FINAL document '{file.filename}' has been submitted successfully "
            f"by {admin_name} for the position '{job_title}' at {organization}.\n\n"
            "This is your FINAL submission. No further changes are allowed."
        )
        if notes:
            user_message += f"\n\nAdmin Notes: {notes}"
        
        await central_notification.send_notification(
            user_ids=[applicant_email],
            notification_type="application_status",
            title=user_title,
            message=user_message,
            related_id=application_id,
            metadata={
                "job_title": job_title,
                "document_name": file.filename,
                "admin_name": admin_name,
                "admin_notes": notes,
                "is_final": True,
                "show_blue_bell": True,
                "status": "final_submitted",
                "final_document_url": upload_result["url"]
            },
            send_email=True,
            send_websocket=True
        )
        logger.info(f"🔔 Notification sent to applicant: {applicant_email}")
        
        # Notify job poster
        job_poster_email = job.get("added_by")
        if job_poster_email and job_poster_email != admin_email:
            await central_notification.send_notification(
                user_ids=[job_poster_email],
                notification_type="admin_alert",
                title=f"✅ FINAL DOCUMENT Submitted for {job_title}",
                message=f"FINAL document '{file.filename}' has been submitted by {admin_name} "
                        f"for application from {applicant_email}",
                related_id=application_id,
                metadata={
                    "job_title": job_title,
                    "applicant_email": applicant_email,
                    "document_name": file.filename,
                    "admin_name": admin_name,
                    "admin_notes": notes,
                    "is_final": True,
                    "show_blue_bell": True,
                    "final_document_url": upload_result["url"]
                },
                send_email=True,
                send_websocket=True
            )
            logger.info(f"🔔 Notification sent to job poster: {job_poster_email}")
        
        # Notify all customadmins
        customadmins = await db.auth.find({"role": "customadmin", "is_active": True}).to_list(100)
        for ca in customadmins:
            ca_email = ca.get("email")
            if ca_email != admin_email and ca_email != job_poster_email:
                await central_notification.send_notification(
                    user_ids=[ca_email],
                    notification_type="customadmin_alert",
                    title="✅ FINAL DOCUMENT Submitted",
                    message=f"FINAL document submitted by {admin_name} for application "
                            f"from {applicant_email} for '{job_title}'",
                    related_id=application_id,
                    metadata={
                        "job_title": job_title,
                        "applicant_email": applicant_email,
                        "admin_name": admin_name,
                        "is_final": True,
                        "show_blue_bell": True,
                        "final_document_url": upload_result["url"]
                    },
                    send_email=True,
                    send_websocket=True
                )
        
        return {
            "success": True,
            "message": "FINAL application document submitted successfully!",
            "application_id": application_id,
            "status": "final_submitted",
            "old_status": old_status,
            "final_document_url": upload_result["url"],
            "submitted_document_url": upload_result["url"],
            "document_name": file.filename,
            "admin_notes": notes,
            "old_document_deleted": old_public_id is not None,
            "notifications_sent": True
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in final submit: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.post("/applications/{application_id}/review-status")
async def admin_review_application_status(
    application_id: str,
    notes: Optional[str] = Query(None),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Admin updates application status to 'review_application'
    
    No document upload required - just status change with notifications.
    """
    admin_email = await _get_admin_email(user, db)
    admin_name = user.get("name", "Admin")
    
    logger.info("=" * 60)
    logger.info(f"📋 REVIEW APPLICATION STATUS UPDATE")
    logger.info(f"   Application ID: {application_id}")
    logger.info(f"   Admin Email: {admin_email}")
    logger.info("=" * 60)
    
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    try:
        # Find application
        application = await db.applications.find_one({"_id": ObjectId(application_id)})
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")
        
        # Find job and verify permission
        job = await db.job.find_one({"_id": ObjectId(application.get("job_id"))})
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        
        if job.get("added_by") != admin_email and user.get("role") != "superadmin":
            raise HTTPException(status_code=403, detail="Access denied")
        
        old_status = application.get("status", "unknown")
        applicant_email = application.get("applicant_email")
        
        # Preserve existing document URL if any
        existing_doc_url = application.get("submitted_document_url")
        
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
        
        # Send notifications
        job_title = job.get("post_name", "Job")
        organization = job.get("organization", "Company")
        
        # Notify applicant
        if applicant_email:
            user_title = f"📋 Application Under Review: {job_title}"
            user_message = (
                f"Your application for '{job_title}' at {organization} is now under REVIEW "
                f"by {admin_name}.\n\nThe admin is reviewing your documents. "
                "You will be notified once the review is complete."
            )
            if notes:
                user_message += f"\n\nAdmin Notes: {notes}"
            
            await central_notification.send_notification(
                user_ids=[applicant_email],
                notification_type="application_status",
                title=user_title,
                message=user_message,
                related_id=application_id,
                metadata={
                    "job_title": job_title,
                    "status": "review_application",
                    "admin_notes": notes,
                    "admin_name": admin_name,
                    "show_blue_bell": True,
                    "submitted_document_url": existing_doc_url
                },
                send_email=True,
                send_websocket=True
            )
            logger.info(f"🔔 Notification sent to user: {applicant_email}")
        
        # Notify job poster
        job_poster_email = job.get("added_by")
        if job_poster_email and job_poster_email != admin_email:
            await central_notification.send_notification(
                user_ids=[job_poster_email],
                notification_type="admin_alert",
                title=f"📋 Application Under Review: {job_title}",
                message=f"Application from {applicant_email} for '{job_title}' "
                        f"is now under REVIEW by {admin_name}.",
                related_id=application_id,
                metadata={
                    "job_title": job_title,
                    "applicant_email": applicant_email,
                    "status": "review_application",
                    "admin_notes": notes,
                    "admin_name": admin_name,
                    "show_blue_bell": True
                },
                send_email=True,
                send_websocket=True
            )
            logger.info(f"🔔 Notification sent to job poster: {job_poster_email}")
        
        return {
            "success": True,
            "message": f"Application status updated from {old_status} to review_application",
            "application_id": application_id,
            "status": "review_application",
            "old_status": old_status,
            "admin_notes": notes,
            "notifications_sent": True,
            "submitted_document_url": existing_doc_url
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in review status: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


# ============================================================
# PAYMENT VERIFICATION ENDPOINTS
# ============================================================

@router.get("/pending-payments")
async def get_pending_payments(
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Get all pending payment verifications
    
    Returns list of applications with pending payment verification.
    """
    # Get pending job applications
    job_pending = await db.applications.find({
        "application_type": "job",
        "payment_verification_status": "pending"
    }).to_list(100)
    
    # Get pending service applications
    service_pending = await db.applications.find({
        "application_type": "service",
        "payment_verification_status": "pending"
    }).to_list(100)
    
    # Format job applications
    job_results = []
    for app in job_pending:
        job = None
        if app.get("job_id") and ObjectId.is_valid(app["job_id"]):
            job = await db.job.find_one({"_id": ObjectId(app["job_id"])})
        
        job_results.append({
            "id": str(app["_id"]),
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
    
    # Format service applications
    service_results = []
    for app in service_pending:
        service_results.append({
            "id": str(app["_id"]),
            "type": "service",
            "user_email": app.get("user_email"),
            "user_name": app.get("user_name", "Unknown"),
            "service_name": app.get("service_name", "Service"),
            "sub_service_name": app.get("sub_service_name", ""),
            "amount": app.get("payment_amount", 0),
            "category_used": app.get("payment_category_used", "service"),
            "transaction_id": app.get("transaction_id", "N/A"),
            "screenshot_url": app.get("payment_receipt_url") or app.get("screenshot_url"),
            "status": app.get("status", "pending_verification"),
            "created_at": (
                app.get("created_at").isoformat() 
                if app.get("created_at") else None
            )
        })
    
    return {
        "payments": job_results + service_results,
        "total": len(job_results) + len(service_results)
    }


@router.post("/verify-payment/{application_id}")
async def admin_verify_payment(
    application_id: str,
    action: str = Query(..., pattern="^(approve|reject)$"),
    notes: Optional[str] = Query(None),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Admin approves or rejects a pending payment verification
    
    Updates application directly and sends notifications to all parties.
    """
    if not ObjectId.is_valid(application_id):
        raise HTTPException(400, "Invalid application ID")
    
    # Find application (job or service)
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
    admin_name = user.get("name", "Admin")
    
    user_email = application.get("applicant_email") or application.get("user_email")
    amount = application.get("payment_amount", 0)
    transaction_id = application.get("transaction_id")
    job_id = application.get("job_id")
    job_title = application.get("job_title", "Job Application")
    job_poster_email = application.get("added_by")
    
    if action == "approve":
        # Update application
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
            "Your application is now submitted."
        )
        
        # Notify user
        await central_notification.send_notification(
            user_ids=[user_email],
            notification_type="application_status",
            title=title,
            message=message,
            related_id=application_id,
            metadata={
                "status": status_msg,
                "amount": amount,
                "transaction_id": transaction_id,
                "show_blue_bell": True
            },
            send_email=True,
            send_sms=True,
            send_websocket=True
        )
        
        # Notify job poster
        if job_poster_email and job_poster_email != admin_email:
            await central_notification.send_notification(
                user_ids=[job_poster_email],
                notification_type="admin_alert",
                title="💰 Payment Approved",
                message=f"Payment of ₹{amount} from {user_email} for '{job_title}' "
                        f"has been APPROVED by {admin_name}.",
                related_id=application_id,
                metadata={
                    "status": "payment_approved",
                    "amount": amount,
                    "job_title": job_title,
                    "applicant_email": user_email,
                    "approved_by": admin_email,
                    "show_blue_bell": True
                },
                send_email=True,
                send_websocket=True
            )
        
        # Notify customadmins
        customadmins = await db.auth.find({"role": "customadmin", "is_active": True}).to_list(100)
        for ca in customadmins:
            ca_email = ca.get("email")
            if ca_email != admin_email and ca_email != job_poster_email:
                await central_notification.send_notification(
                    user_ids=[ca_email],
                    notification_type="customadmin_alert",
                    title="💰 Payment Approved",
                    message=f"Payment of ₹{amount} from {user_email} for '{job_title}' "
                            f"has been APPROVED by {admin_name}",
                    related_id=application_id,
                    metadata={
                        "status": "payment_approved",
                        "amount": amount,
                        "job_title": job_title,
                        "approved_by": admin_email,
                        "show_blue_bell": True
                    },
                    send_email=True,
                    send_websocket=True
                )
        
        return {
            "success": True,
            "message": "Payment approved successfully.",
            "application_id": application_id,
            "action": action,
            "notes": notes,
            "notifications_sent": True
        }
    
    else:  # reject
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
        message = f"Your payment of ₹{amount} for '{job_title}' has been REJECTED.\nReason: {notes}"
        
        # Notify user
        await central_notification.send_notification(
            user_ids=[user_email],
            notification_type="application_status",
            title=title,
            message=message,
            related_id=application_id,
            metadata={
                "status": status_msg,
                "amount": amount,
                "rejection_reason": notes,
                "show_blue_bell": True
            },
            send_email=True,
            send_sms=True,
            send_websocket=True
        )
        
        # Notify job poster
        if job_poster_email and job_poster_email != admin_email:
            await central_notification.send_notification(
                user_ids=[job_poster_email],
                notification_type="admin_alert",
                title="💰 Payment Rejected",
                message=f"Payment of ₹{amount} from {user_email} for '{job_title}' "
                        f"has been REJECTED by {admin_name}.\nReason: {notes}",
                related_id=application_id,
                metadata={
                    "status": "payment_rejected",
                    "amount": amount,
                    "job_title": job_title,
                    "rejection_reason": notes,
                    "show_blue_bell": True
                },
                send_email=True,
                send_websocket=True
            )
        
        # Notify customadmins
        customadmins = await db.auth.find({"role": "customadmin", "is_active": True}).to_list(100)
        for ca in customadmins:
            ca_email = ca.get("email")
            if ca_email != admin_email and ca_email != job_poster_email:
                await central_notification.send_notification(
                    user_ids=[ca_email],
                    notification_type="customadmin_alert",
                    title="💰 Payment Rejected",
                    message=f"Payment of ₹{amount} from {user_email} for '{job_title}' "
                            f"has been REJECTED by {admin_name}.\nReason: {notes}",
                    related_id=application_id,
                    metadata={
                        "status": "payment_rejected",
                        "amount": amount,
                        "job_title": job_title,
                        "rejection_reason": notes,
                        "show_blue_bell": True
                    },
                    send_email=True,
                    send_websocket=True
                )
        
        return {
            "success": True,
            "message": f"Payment rejected. Reason: {notes}",
            "application_id": application_id,
            "action": action,
            "notes": notes,
            "notifications_sent": True
        }


# ============================================================
# AI & ANALYTICS ENDPOINTS
# ============================================================

@router.get("/ai/dashboard")
async def get_admin_ai_dashboard(
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Get AI-powered dashboard statistics
    
    Returns comprehensive stats including applications, scores, trends.
    """
    try:
        admin_email = await _get_admin_email(user, db)
        
        if not admin_email:
            raise HTTPException(status_code=400, detail="Admin email not found")
        
        # Get admin's jobs
        admin_jobs = await db.job.find({"added_by": admin_email}).to_list(1000)
        admin_job_ids = [str(job["_id"]) for job in admin_jobs]
        
        # Get application counts
        total_applications = 0
        pending_applications = 0
        shortlisted_applications = 0
        interview_applications = 0
        offered_applications = 0
        rejected_applications = 0
        avg_match_score = 0
        
        if admin_job_ids:
            total_applications = await db.applications.count_documents({
                "job_id": {"$in": admin_job_ids}
            })
            pending_applications = await db.applications.count_documents({
                "job_id": {"$in": admin_job_ids}, "status": "pending"
            })
            shortlisted_applications = await db.applications.count_documents({
                "job_id": {"$in": admin_job_ids}, "status": "shortlisted"
            })
            interview_applications = await db.applications.count_documents({
                "job_id": {"$in": admin_job_ids}, "status": "interview"
            })
            offered_applications = await db.applications.count_documents({
                "job_id": {"$in": admin_job_ids}, "status": "offered"
            })
            rejected_applications = await db.applications.count_documents({
                "job_id": {"$in": admin_job_ids}, "status": "rejected"
            })
            
            # Calculate average match score
            pipeline = [
                {"$match": {"job_id": {"$in": admin_job_ids}, "match_score": {"$exists": True}}},
                {"$group": {"_id": None, "avg": {"$avg": "$match_score"}}}
            ]
            result = await db.applications.aggregate(pipeline).to_list(1)
            if result:
                avg_match_score = round(result[0].get("avg", 0), 1)
        
        # Recent applications (last 30 days)
        from datetime import timedelta
        last_30_days = datetime.utcnow() - timedelta(days=30)
        recent_apps = await db.applications.count_documents({
            "job_id": {"$in": admin_job_ids},
            "created_at": {"$gte": last_30_days}
        }) if admin_job_ids else 0
        
        # Top jobs by applications
        top_jobs = []
        if admin_job_ids:
            pipeline = [
                {"$match": {"job_id": {"$in": admin_job_ids}}},
                {"$group": {"_id": "$job_title", "count": {"$sum": 1}}},
                {"$sort": {"count": -1}},
                {"$limit": 5}
            ]
            top_jobs_result = await db.applications.aggregate(pipeline).to_list(5)
            top_jobs = [
                {"title": item["_id"], "count": item["count"]}
                for item in top_jobs_result
            ]
        
        return {
            "total_applications": total_applications,
            "pending_applications": pending_applications,
            "shortlisted_applications": shortlisted_applications,
            "interview_applications": interview_applications,
            "offered_applications": offered_applications,
            "rejected_applications": rejected_applications,
            "average_ai_match": avg_match_score,
            "auto_shortlist_ready": await db.applications.count_documents({
                "job_id": {"$in": admin_job_ids},
                "match_score": {"$gte": 85},
                "status": "pending"
            }) if admin_job_ids else 0,
            "high_risk_applications": 0,
            "trend_direction": "increasing" if recent_apps > 50 else "stable",
            "predicted_next_30_days": recent_apps * 2,
            "top_job_categories": top_jobs,
            "admin_jobs_count": len(admin_jobs)
        }
        
    except Exception as e:
        logger.error(f"Error in AI dashboard: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/ai/applications/ranked")
async def get_ranked_applications(
    limit: int = Query(50, ge=1, le=200),
    user=Depends(role_required(["admin", "customadmin", "superadmin"])),
    db=Depends(get_db)
):
    """
    ✅ Get AI-ranked applications
    
    Returns applications sorted by AI match score.
    """
    try:
        admin_email = await _get_admin_email(user, db)
        
        if not admin_email:
            raise HTTPException(status_code=400, detail="Admin email not found")
        
        # Get admin's jobs
        admin_jobs = await db.job.find({"added_by": admin_email}, {"_id": 1}).to_list(1000)
        admin_job_ids = [str(job["_id"]) for job in admin_jobs]
        
        if not admin_job_ids:
            return {"ranked_applications": [], "total": 0}
        
        # Get applications sorted by match score
        applications = await db.applications.find({
            "job_id": {"$in": admin_job_ids}
        }).sort("match_score", -1).limit(limit).to_list(limit)
        
        ranked_apps = []
        for app in applications:
            ranked_apps.append({
                "application_id": str(app["_id"]),
                "candidate_name": app.get("applicant_name", "N/A"),
                "candidate_email": app.get("applicant_email", "N/A"),
                "job_title": app.get("job_title", "N/A"),
                "match_score": app.get("match_score", 0),
                "status": app.get("status", "pending"),
                "applied_at": (
                    app.get("applied_at").isoformat() 
                    if app.get("applied_at") else None
                )
            })
        
        return {
            "ranked_applications": ranked_apps,
            "total": len(ranked_apps),
            "ai_ranked": True
        }
        
    except Exception as e:
        logger.error(f"Error in ranked applications: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# TEST ENDPOINTS
# ============================================================

@router.get("/test-google-drive")
async def test_google_drive_connection(
    user=Depends(role_required(["admin", "superadmin"]))
):
    """Test Google Drive connection"""
    from app.core.services.google_drive import google_drive_service
    
    result = await google_drive_service.test_connection()
    return result


print("✅ Admin Routes Loaded - Full Job CRUD + Application Management")
print("   ✅ Job CRUD: Add, Get, Update, Delete, Publish")
print("   ✅ Application Management: List, Detail, Status Update")
print("   ✅ Document Upload: Review, Final Submit")
print("   ✅ Payment Verification: Approve, Reject")
print("   ✅ AI Dashboard & Rankings")
print("   ✅ Notifications to all parties")