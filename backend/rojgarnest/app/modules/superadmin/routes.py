# app/modules/superadmin/routes.py - FIXED WITH PROTECTION

from fastapi import APIRouter, Depends, Query, HTTPException
from typing import Optional

from app.core.services.dependencies import role_required
from app.db.connection import get_db
from .schema import UserFilterSchema, PromoteToAdminSchema, BulkActionSchema
from .service import SuperAdminService
from app.modules.superadmin.AI.ai_routes import router as superadmin_ai_router

router = APIRouter()

router.include_router(superadmin_ai_router)


async def get_superadmin_service(db=Depends(get_db)):
    return SuperAdminService(db)


# ====================== JOB MANAGEMENT ======================

@router.get("/jobs")
async def get_all_jobs(
    status: Optional[str] = Query(None, pattern="^(open|closed|filled)$"),
    limit: int = Query(100, ge=1, le=500),
    skip: int = Query(0, ge=0),
    user=Depends(role_required("superadmin")),
    db=Depends(get_db)
):
    """Superadmin can view all jobs across all admins"""
    from app.modules.jobs.service import JobService
    
    job_service = JobService(db)
    query = {}
    if status:
        query["status"] = status
    
    jobs = await db.job.find(query).sort("created_at", -1).skip(skip).limit(limit).to_list(limit)
    total = await db.job.count_documents(query)
    
    for job in jobs:
        job["_id"] = str(job["_id"])
        app_count = await db.applications.count_documents({"job_id": job["_id"]})
        job["applications_count"] = app_count
    
    return {
        "jobs": jobs,
        "total": total,
        "skip": skip,
        "limit": limit
    }


@router.delete("/jobs/{job_id}")
async def superadmin_delete_job(
    job_id: str,
    user=Depends(role_required("superadmin")),
    db=Depends(get_db)
):
    """Superadmin can delete any job"""
    from app.modules.jobs.service import JobService
    from bson import ObjectId
    
    if not ObjectId.is_valid(job_id):
        raise HTTPException(status_code=400, detail="Invalid job ID")
    
    job_service = JobService(db)
    return await job_service.delete_job(job_id)


# ====================== APPLICATION MANAGEMENT ======================

@router.get("/applications")
async def get_all_applications(
    status: Optional[str] = Query(None, pattern="^(pending|shortlisted|interview|offered|rejected)$"),
    limit: int = Query(100, ge=1, le=500),
    skip: int = Query(0, ge=0),
    user=Depends(role_required("superadmin")),
    db=Depends(get_db)
):
    """Superadmin can view all applications"""
    query = {}
    if status:
        query["status"] = status
    
    applications = await db.applications.find(query).sort("applied_at", -1).skip(skip).limit(limit).to_list(limit)
    
    for app in applications:
        app["_id"] = str(app["_id"])
        app["job_id"] = str(app["job_id"]) if app.get("job_id") else None
    
    total = await db.applications.count_documents(query)
    
    return {
        "applications": applications,
        "total": total,
        "skip": skip,
        "limit": limit
    }


@router.put("/applications/{application_id}/status")
async def superadmin_update_status(
    application_id: str,
    status: str = Query(..., pattern="^(pending|shortlisted|interview|offered|rejected)$"),
    notes: Optional[str] = None,
    user=Depends(role_required("superadmin")),
    db=Depends(get_db)
):
    """Superadmin can update any application status"""
    from app.modules.jobs.schema import ApplicationStatusUpdateSchema
    from app.modules.jobs.service import JobService
    from bson import ObjectId
    
    if not ObjectId.is_valid(application_id):
        raise HTTPException(status_code=400, detail="Invalid application ID")
    
    job_service = JobService(db)
    status_data = ApplicationStatusUpdateSchema(status=status, notes=notes)
    
    superadmin_user = {"email": user.get("email"), "role": "superadmin", "name": user.get("name", "SuperAdmin")}
    
    return await job_service.update_application_status(application_id, status_data, superadmin_user)


# ====================== AI SMART DASHBOARD ======================

@router.get("/ai-dashboard")
async def ai_smart_dashboard(
    service: SuperAdminService = Depends(get_superadmin_service),
    user=Depends(role_required("superadmin"))
):
    """Ultra Advanced AI-Powered Dashboard with predictions and anomaly detection"""
    return await service.get_ai_smart_dashboard()


@router.get("/report")
async def rojgarnest_full_report(
    service: SuperAdminService = Depends(get_superadmin_service),
    user=Depends(role_required("superadmin"))
):
    """One click complete platform report"""
    return await service.get_ai_smart_dashboard()


# ====================== USER MANAGEMENT ======================

@router.get("/users")
async def list_all_users(
    role: Optional[str] = Query(None),
    is_active: Optional[bool] = Query(None),
    limit: int = Query(50),
    skip: int = Query(0),
    service: SuperAdminService = Depends(get_superadmin_service),
    user=Depends(role_required("superadmin"))
):
    filters = UserFilterSchema(role=role, is_active=is_active, limit=limit, skip=skip)
    return await service.list_users(filters)


@router.put("/users/role")
async def change_user_role(
    data: PromoteToAdminSchema,
    service: SuperAdminService = Depends(get_superadmin_service),
    user=Depends(role_required("superadmin"))
):
    return await service.change_user_role(data.email, "admin", data.notes)


@router.post("/users/bulk-action")
async def bulk_user_action(
    data: BulkActionSchema,
    service: SuperAdminService = Depends(get_superadmin_service),
    user=Depends(role_required("superadmin"))
):
    # ✅ FIXED: Bulk action now only supports promote, demote, deactivate (no delete)
    return await service.bulk_action(data, user.get("email", "superadmin"))


# ✅ FIXED: DELETE endpoint now uses SOFT DELETE (keeps data)
@router.delete("/users/{email}")
async def delete_user(
    email: str,
    service: SuperAdminService = Depends(get_superadmin_service),
    user=Depends(role_required("superadmin"))
):
    """
    SOFT DELETE user - Deactivates account but preserves all data.
    User can be reactivated later by setting is_active=True.
    """
    # Prevent self-deletion
    if email == user.get("email"):
        raise HTTPException(status_code=403, detail="Cannot deactivate your own account")
    
    return await service.delete_user(email, deleted_by=user.get("email", "superadmin"))


@router.get("/")
async def superadmin_home(user=Depends(role_required("superadmin"))):
    return {
        "message": "🚀 Ultra High-Tech AI SuperAdmin Panel is Live!",
        "smart_dashboard": "Use /ai-dashboard for full AI intelligence",
        "one_click_report": "Use /report for complete platform report",
        "note": "User deletion is SOFT DELETE only - data is preserved"
    }


# Add missing imports
from bson import ObjectId
from app.modules.jobs.schema import ApplicationStatusUpdateSchema

print("✅ SuperAdmin Routes Loaded - AUTH DELETION DISABLED (Soft Delete Only)")