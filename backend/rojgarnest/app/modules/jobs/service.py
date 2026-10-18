# app/modules/jobs/service.py - COMPLETE FIXED VERSION
# ✅ NO HARD DELETES of applications/jobs — ONLY soft-delete & archive
# ✅ delete_job() → archives applications, soft-deletes job
# ✅ unsave_job() → archives (not deletes) saved bookmark
# ✅ No TTL, no drop, no delete_many on user data
# ✅ 100% DATA RETENTION

from fastapi import HTTPException, BackgroundTasks, UploadFile
from typing import Optional, List, Dict, Any, Union
from datetime import datetime
from bson import ObjectId
import json
import logging
import asyncio

from app.db.connection import get_db
from app.models.job_model import (
    JobModel, JobLocation, JobAttachment, IndividualPost,
    geocode_location_async, get_admin_current_location
)
from app.models.unified_application_model import UnifiedApplicationModel
from app.modules.jobs.schema import (
    JobCreateSchema,
    JobUpdateSchema,
    ApplicationCreateSchema,
    ApplicationStatusUpdateSchema
)
from app.core.services.cloudinary import upload_to_cloudinary
from app.core.ai.ai_service import compute_ai_match
from app.core.location.distance_calculator import DistanceCalculator
from app.modules.notification.service import central_notification

# ✅ Import real_time_market_ai
from app.core.ai.real_time_market_ai import real_time_market_ai

logger = logging.getLogger(__name__)


class PaymentStatus:
    PENDING = "pending"
    COMPLETED = "completed"
    FAILED = "failed"
    REFUNDED = "refunded"
    AUTHORIZED = "authorized"


class JobService:
    """
    CENTRALIZED JOB SERVICE — Uses unified applications collection.

    ✅ All job applications have application_type='job'
    ✅ NO HARD DELETES — only soft-delete (is_archived=True)
    ✅ Applications are NEVER physically removed
    """

    def __init__(self, db):
        self.jobs = db.job
        self.applications = db.applications
        self.auth = db.auth
        self.db = db
        self.profile = db.profile

    def _unwrap(self, body: Any) -> Dict[str, Any]:
        if body is None:
            return {}
        if isinstance(body, dict):
            if 'data' in body:
                inner_data = body['data']
                return inner_data if isinstance(inner_data, dict) else {'data': inner_data}
            return body
        if isinstance(body, list):
            return {'data': body}
        return body

    def _get_attachment_type(self, filename: str) -> str:
        ext = filename.lower().split('.')[-1]
        if ext == 'pdf':
            return 'pdf'
        elif ext in ['jpg', 'jpeg', 'png', 'webp']:
            return 'image'
        return 'notice'

    async def _get_user_email(self, current_user: dict) -> tuple:
        email = current_user.get("email")
        name = current_user.get("name", "User")
        if not email:
            user_id = current_user.get("user_id")
            if user_id and ObjectId.is_valid(user_id):
                user = await self.db.auth.find_one({"_id": ObjectId(user_id)})
                if user:
                    email = user.get("email")
                    name = user.get("name", email)
        if not email:
            raise HTTPException(status_code=400, detail="User email not found")
        return email, name

    # ==========================================================
    # ADD JOB
    # ==========================================================
    async def add_job(
        self,
        job_data: JobCreateSchema,
        background_tasks: BackgroundTasks,
        attachments: Optional[List[UploadFile]] = None,
        current_user: dict = None
    ):
        """ADD JOB — Saves job and sends notifications"""
        try:
            logger.info("=" * 70)
            logger.info(f"📝 ADDING JOB: {job_data.post_name}")
            logger.info(f"   Organization: {job_data.organization}")
            logger.info(f"   Color Type: {job_data.color_type}")
            logger.info("=" * 70)

            if job_data.use_current_location and not job_data.location_text:
                job_data.location_text = "Current Location (will be replaced)"

            job_dict = job_data.model_dump(exclude_none=True, by_alias=True)

            job_dict.setdefault("color_type", "blue")

            admin_email = None
            admin_name = None
            if current_user:
                admin_email = current_user.get("email")
                admin_name = current_user.get("name", "")
                if not admin_email:
                    user_id = current_user.get("user_id")
                    if user_id and ObjectId.is_valid(user_id):
                        user = await self.db.auth.find_one({"_id": ObjectId(user_id)})
                        if user:
                            admin_email = user.get("email")
                            admin_name = user.get("name", "")

            if not admin_email:
                admin_email = "admin@rojgarnest.com"

            use_current_location = job_dict.get("use_current_location", False)

            if use_current_location:
                admin_location = await get_admin_current_location(admin_email, self.db)
                if admin_location:
                    job_dict["job_location"] = admin_location
                    logger.info(f"📍 Using admin's current location: {admin_location.get('location_name')}")
                else:
                    logger.warning(f"⚠️ Admin {admin_email} has no saved location")
                    geocoded_data = await geocode_location_async(job_data.location_text)
                    job_dict["job_location"] = geocoded_data
            else:
                geocoded_data = await geocode_location_async(job_data.location_text)
                job_dict["job_location"] = geocoded_data

            if not job_dict.get("job_location"):
                job_dict["job_location"] = {
                    "latitude": 0.0,
                    "longitude": 0.0,
                    "location_name": job_data.location_text or "India",
                    "city": None,
                    "district": None,
                    "state": None,
                    "country": "India",
                    "is_geocoded": False,
                    "geocoded_at": None,
                    "source": "manual"
                }

            application_fees = job_dict.get("application_fees")
            if application_fees and isinstance(application_fees, dict) and len(application_fees) > 0:
                cleaned_fees = {}
                for category, fee in application_fees.items():
                    try:
                        fee_amount = int(fee)
                        if fee_amount >= 0:
                            cleaned_fees[category.lower()] = fee_amount
                    except (ValueError, TypeError):
                        pass
                if cleaned_fees:
                    job_dict["application_fees"] = cleaned_fees
                    job_dict["has_application_fees"] = True
                else:
                    job_dict["has_application_fees"] = False
            else:
                job_dict["has_application_fees"] = False

            if job_dict.get("multiple_posts") and len(job_dict["multiple_posts"]) > 0:
                processed_posts = []
                total_vacancies = 0
                for post in job_dict["multiple_posts"]:
                    processed_post = {
                        "post_name": post.get("post_name"),
                        "total_posts": post.get("total_posts", 1),
                        "qualification": post.get("qualification", ""),
                        "qualification_main": post.get("qualification_main"),
                        "qualification_sub": post.get("qualification_sub"),
                        "degree_stream": post.get("degree_stream"),
                        "degree_name": post.get("degree_name"),
                        "age_min": post.get("age_min"),
                        "age_max": post.get("age_max"),
                        "experience_details": post.get("experience_details"),
                        "pay_scales": post.get("pay_scales", []),
                        "category_vacancies": post.get("category_vacancies", [])
                    }
                    processed_posts.append(processed_post)
                    total_vacancies += post.get("total_posts", 1)
                job_dict["multiple_posts"] = processed_posts
                job_dict["total_posts"] = total_vacancies

            job_dict.setdefault("required_skills", [])
            job_dict.setdefault("nice_to_have_skills", [])
            job_dict.setdefault("benefits", [])
            job_dict.setdefault("tags", [])
            job_dict.setdefault("attachments", [])
            job_dict.setdefault("status", "open")
            job_dict.setdefault("job_level", "mid")
            job_dict.setdefault("salary_currency", "INR")
            job_dict.setdefault("experience_min_years", 0)
            job_dict.setdefault("has_apply_with_us", False)
            job_dict.setdefault("has_official_notification", False)
            job_dict.setdefault("exam_cities", [])
            job_dict.setdefault("languages_required", [])
            job_dict.setdefault("interview_documents", [])
            job_dict.setdefault("selection_stages", [])
            job_dict.setdefault("age_relaxation_by_category", {})
            job_dict.setdefault("multiple_posts", [])
            job_dict.setdefault("application_mode", "Online")
            job_dict.setdefault("work_schedule", "Full Time")
            job_dict.setdefault("shift", "Day Shift")
            job_dict.setdefault("working_days", "Monday to Friday")
            job_dict.setdefault("gender_preference", "Any")
            job_dict.setdefault("urgency_level", "Normal")
            job_dict.setdefault("is_fully_remote", False)
            job_dict.setdefault("is_hybrid", False)
            job_dict.setdefault("has_bond", False)
            job_dict.setdefault("color_type", "blue")

            apply_url = job_dict.get("apply_with_us_url")
            if apply_url and str(apply_url).strip() and str(apply_url).strip() != '#':
                job_dict["has_apply_with_us"] = True

            official_url = job_dict.get("official_notification_url")
            if official_url and str(official_url).strip() and str(official_url).strip() != '#':
                job_dict["has_official_notification"] = True

            if attachments:
                for file in attachments:
                    if file.filename:
                        upload_result = await upload_to_cloudinary(file, folder="jobs/attachments")
                        job_dict["attachments"].append({
                            "type": self._get_attachment_type(file.filename),
                            "name": file.filename,
                            "url": upload_result["url"],
                            "size_kb": upload_result.get("size_kb", 0),
                            "uploaded_at": datetime.utcnow()
                        })

            publisher_role = "admin"
            if current_user:
                publisher_role = current_user.get("role", "admin").lower()
                if publisher_role == "custom_admin":
                    publisher_role = "customadmin"

            job_dict["added_by"] = admin_email
            job_dict["added_by_name"] = admin_name
            job_dict["publisher_role"] = publisher_role
            job_dict["created_at"] = datetime.utcnow()
            job_dict["updated_at"] = datetime.utcnow()
            job_dict["source"] = "manual"
            job_dict["is_deleted"] = False
            job_dict["is_archived"] = False

            job_dict = {k: v for k, v in job_dict.items() if v is not None}

            result = await self.jobs.insert_one(job_dict)
            job_id = str(result.inserted_id)
            job_dict["_id"] = result.inserted_id

            notification_result = await central_notification.notify_new_job(
                job_dict, background_tasks, publisher_role=publisher_role
            )

            return {
                "status": "success",
                "message": "Job posted successfully",
                "job_id": job_id,
                "job_title": job_data.post_name,
                "organization": job_data.organization,
                "job_location": job_dict.get("job_location"),
                "color_type": job_dict.get("color_type", "blue"),
                "has_apply_with_us": job_dict.get("has_apply_with_us", False),
                "has_official_notification": job_dict.get("has_official_notification", False),
                "has_application_fees": job_dict.get("has_application_fees", False),
                "application_fees": job_dict.get("application_fees", {}),
                "total_posts": job_dict.get("total_posts", 1),
                "notifications_sent": notification_result.get("emails_sent", 0),
                "created_at": datetime.utcnow().isoformat()
            }

        except Exception as e:
            logger.error(f"❌ Failed to add job: {e}")
            import traceback
            traceback.print_exc()
            raise HTTPException(status_code=400, detail=f"Failed to add job: {str(e)}")

    # ==========================================================
    # LIST JOBS (OPTIMIZED)
    # ==========================================================
    async def list_jobs(
        self,
        skip: int = 0,
        limit: int = 20,
        job_type: Optional[str] = None,
        category: Optional[str] = None,
        search: Optional[str] = None,
        user_location: Optional[dict] = None,
        color_type: Optional[str] = None,
    ) -> dict:
        """
        ✅ List jobs with filters.
        ✅ Excludes soft-deleted jobs (is_deleted=True).
        """
        query = {
            "status": "open",
            "is_deleted": {"$ne": True}   # ✅ Never show deleted jobs
        }

        if job_type and job_type != 'all' and job_type != 'null' and job_type != '':
            query["job_type"] = job_type

        if category and category != 'all':
            query["category"] = category

        if color_type and color_type != 'all' and color_type != 'null' and color_type != '':
            ct = color_type.lower().strip()
            if ct == 'gray':
                ct = 'grey'
            query["color_type"] = ct

        if search and search.strip():
            search_term = search.strip()
            query["$or"] = [
                {"post_name": {"$regex": search_term, "$options": "i"}},
                {"organization": {"$regex": search_term, "$options": "i"}},
                {"description": {"$regex": search_term, "$options": "i"}}
            ]

        count_task = self.jobs.count_documents(query)

        projection = {
            "_id": 1,
            "post_name": 1,
            "organization": 1,
            "location": 1,
            "job_location": 1,
            "job_type": 1,
            "job_level": 1,
            "category": 1,
            "color_type": 1,
            "post_date": 1,
            "last_date": 1,
            "description": 1,
            "salary_min": 1,
            "salary_max": 1,
            "salary_currency": 1,
            "total_posts": 1,
            "multiple_posts": 1,
            "experience_min_years": 1,
            "experience_max_years": 1,
            "required_qualification": 1,
            "qualification": 1,
            "education_details": 1,
            "experience_details": 1,
            "age_min_years": 1,
            "age_max_years": 1,
            "age_calculation_date": 1,
            "age_relaxation_details": 1,
            "age_relaxation_by_category": 1,
            "has_application_fees": 1,
            "application_fees": 1,
            "has_apply_with_us": 1,
            "apply_with_us_url": 1,
            "has_official_notification": 1,
            "official_notification_url": 1,
            "official_notification_link": 1,
            "advertisement_url": 1,
            "advertisement_download_url": 1,
            "advertisement_name": 1,
            "advertisement_storage": 1,
            "advertisement_public_id": 1,
            "advertisement_resource_type": 1,
            "advertisement_is_public": 1,
            "advertisement_is_pdf": 1,
            "advertisement_folder_path": 1,
            "advertisement_file_size": 1,
            "has_advertisement_file": 1,
            "website_url": 1,
            "apply_link": 1,
            "action": 1,
            "work_schedule": 1,
            "shift": 1,
            "working_days": 1,
            "is_fully_remote": 1,
            "is_hybrid": 1,
            "benefits": 1,
            "required_skills": 1,
            "nice_to_have_skills": 1,
            "tags": 1,
            "languages_required": 1,
            "other_languages": 1,
            "application_start_date": 1,
            "application_end_date": 1,
            "admit_card_date": 1,
            "exam_date": 1,
            "result_date": 1,
            "interview_venue": 1,
            "interview_link": 1,
            "interview_date": 1,
            "interview_time": 1,
            "interview_documents": 1,
            "is_interview_online": 1,
            "selection_stages": 1,
            "selection_process_details": 1,
            "physical_eligibility": 1,
            "medical_standards": 1,
            "has_medical_requirement": 1,
            "contact_person": 1,
            "contact_designation": 1,
            "contact_email": 1,
            "contact_phone": 1,
            "helpline_number": 1,
            "helpline_email": 1,
            "whatsapp_number": 1,
            "telegram_channel": 1,
            "important_notes": 1,
            "terms_conditions": 1,
            "urgency_level": 1,
            "gender_preference": 1,
            "application_mode": 1,
            "exam_cities": 1,
            "created_at": 1,
            "updated_at": 1,
            "added_by": 1,
            "added_by_name": 1,
            "publisher_role": 1,
        }

        jobs_task = self.jobs.find(query, projection).skip(skip).limit(limit).sort("created_at", -1).to_list(limit)

        total, jobs_list = await asyncio.gather(count_task, jobs_task)

        for job in jobs_list:
            job["_id"] = str(job["_id"])
            job.setdefault("color_type", "blue")
            job.setdefault("has_apply_with_us", False)
            job.setdefault("has_official_notification", False)
            job.setdefault("has_application_fees", False)
            job.setdefault("has_advertisement_file", False)

            distance_km = None
            if user_location and user_location.get("latitude") and user_location.get("longitude"):
                job_loc = job.get("job_location", {})
                job_lat = job_loc.get("latitude")
                job_lon = job_loc.get("longitude")

                if job_lat is not None and job_lon is not None and (job_lat != 0 or job_lon != 0):
                    import math
                    lat1, lon1 = user_location["latitude"], user_location["longitude"]
                    lat2, lon2 = job_lat, job_lon

                    R = 6371
                    dlat = math.radians(lat2 - lat1)
                    dlon = math.radians(lon2 - lon1)
                    a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
                    c = 2 * math.asin(math.sqrt(a))
                    distance_km = round(R * c, 2)

            job["distance_km"] = distance_km

        return {"jobs": jobs_list, "total": total}

    # ==========================================================
    # GET SINGLE JOB
    # ==========================================================
    async def get_job(self, job_id: str) -> dict:
        if not ObjectId.is_valid(job_id):
            raise HTTPException(status_code=400, detail="Invalid job ID")

        job = await self.jobs.find_one({
            "_id": ObjectId(job_id),
            "is_deleted": {"$ne": True}   # ✅ Exclude soft-deleted
        })
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")

        job["_id"] = str(job["_id"])
        job.setdefault("color_type", "blue")
        return job

    # ==========================================================
    # APPLY WITH PAYMENT (IDEMPOTENT)
    # ==========================================================
    async def apply_with_payment_idempotent(
        self,
        job_id: str,
        application_data: ApplicationCreateSchema,
        current_user: dict,
        payment_id: str
    ) -> Dict[str, Any]:
        """
        ✅ Idempotent application with payment.
        - NO duplicate applications
        - NO payment_pending status saved
        - Application created ONLY after payment success
        """
        try:
            user_email = current_user.get("email")
            if not user_email:
                raise HTTPException(status_code=400, detail="User email not found")

            job = await self.jobs.find_one({
                "_id": ObjectId(job_id),
                "is_deleted": {"$ne": True}
            })
            if not job:
                raise HTTPException(status_code=404, detail="Job not found")

            existing_app = await self.applications.find_one({
                "job_id": job_id,
                "applicant_email": user_email,
                "application_type": "job",
                "status": {"$ne": "saved"}
            })

            if existing_app:
                logger.info(f"📋 Found existing application: {existing_app['_id']}")
                return {
                    "success": True,
                    "message": "You have already applied for this job",
                    "application_id": str(existing_app["_id"]),
                    "status": existing_app.get("status", "already_applied"),
                    "already_applied": True
                }

            payment_record = await self.applications.find_one({
                "payment_id": payment_id,
                "application_type": "job",
                "payment_verification_status": "approved"
            })

            if not payment_record:
                logger.warning(f"⚠️ Payment {payment_id} not approved yet")
                return {
                    "success": False,
                    "message": "Payment not verified yet. Please wait for admin approval.",
                    "status": "pending_verification",
                    "payment_id": payment_id,
                    "waiting_for_verification": True
                }

            profile = await self.db.profile.find_one({"email": user_email})
            auth_user = await self.db.auth.find_one({"email": user_email})

            applicant_name = profile.get("full_name") if profile else current_user.get("name", user_email.split('@')[0])
            user_category = profile.get("category", "General/UR") if profile else "General/UR"
            disability = profile.get("disability", {}) if profile else {}
            is_disabled = disability.get("is_disabled", False) if isinstance(disability, dict) else False

            amount = payment_record.get("payment_amount", 0)
            category_used = payment_record.get("payment_category_used", "general/ur")

            razorpay_order_id = payment_record.get("razorpay_order_id")
            razorpay_payment_id = payment_record.get("razorpay_payment_id")
            razorpay_signature = payment_record.get("razorpay_signature")

            application_doc = {
                "application_type": "job",
                "job_id": job_id,
                "job_title": job.get("post_name", "Job Opportunity"),
                "organization": job.get("organization", "Company"),
                "added_by": job.get("added_by", "admin@rojgarnest.com"),
                "applicant_email": user_email,
                "applicant_name": applicant_name,
                "user_email": user_email,
                "user_name": applicant_name,
                "user_id": current_user.get("user_id"),
                "user_category": user_category,
                "is_disabled": is_disabled,
                "color_type": job.get("color_type", "blue"),

                "status": "verification_successful",
                "payment_verification_status": "approved",
                "payment_id": payment_id,
                "payment_amount": amount,
                "payment_category_used": category_used,
                "payment_method": payment_record.get("payment_method", "razorpay"),

                "razorpay_order_id": razorpay_order_id,
                "razorpay_payment_id": razorpay_payment_id,
                "razorpay_signature": razorpay_signature,

                "transaction_id": payment_record.get("transaction_id") or razorpay_payment_id,
                "transaction_date": payment_record.get("paid_at", datetime.utcnow()),
                "paid_at": datetime.utcnow(),
                "applied_at": datetime.utcnow(),
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow(),

                "is_archived": False,
                "cover_letter": application_data.cover_letter if application_data else None,
                "additional_info": application_data.additional_info if application_data else None,
            }

            result = await self.applications.insert_one(application_doc)
            application_id = str(result.inserted_id)

            logger.info(f"✅ Application created with payment: {application_id}")

            await central_notification.send_notification(
                user_ids=[user_email],
                notification_type="application_status",
                title="✅ Application Submitted Successfully!",
                message=f"Your application for '{job.get('post_name', 'Job')}' has been submitted successfully.\n\nPayment: ₹{amount} verified.",
                related_id=application_id,
                metadata={
                    "status": "verification_successful",
                    "amount": amount,
                    "job_title": job.get("post_name"),
                    "application_id": application_id,
                    "color_type": job.get("color_type", "blue"),
                    "show_blue_bell": True
                },
                send_email=True,
                send_websocket=True
            )

            admin_email = job.get("added_by")
            if admin_email:
                await central_notification.send_notification(
                    user_ids=[admin_email],
                    notification_type="admin_alert",
                    title="📋 New Application Submitted",
                    message=f"New application for '{job.get('post_name', 'Job')}' from {applicant_name}.\nPayment: ₹{amount} verified.",
                    related_id=application_id,
                    metadata={
                        "job_title": job.get("post_name"),
                        "applicant_email": user_email,
                        "applicant_name": applicant_name,
                        "amount": amount,
                        "status": "verification_successful",
                        "show_blue_bell": True
                    },
                    send_email=True,
                    send_websocket=True
                )

            return {
                "success": True,
                "application_id": application_id,
                "application_type": "job",
                "message": "Application submitted successfully!",
                "status": "verification_successful",
                "amount": amount,
                "already_applied": False
            }

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"❌ apply_with_payment_idempotent error: {e}")
            import traceback
            traceback.print_exc()
            raise HTTPException(status_code=500, detail=f"Application failed: {str(e)}")

    # ==========================================================
    # APPLY TO JOB WITHOUT PAYMENT
    # ==========================================================
    async def apply_to_job(self, job_id: str, application_data: ApplicationCreateSchema, current_user: dict):
        if not ObjectId.is_valid(job_id):
            raise HTTPException(status_code=400, detail="Invalid job ID")

        job = await self.jobs.find_one({
            "_id": ObjectId(job_id),
            "is_deleted": {"$ne": True}
        })
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")

        applicant_email, applicant_name = await self._get_user_email(current_user)

        existing_applied = await self.applications.find_one({
            "job_id": job_id,
            "user_email": applicant_email,
            "application_type": "job",
            "status": {"$ne": "saved"}
        })
        if existing_applied:
            raise HTTPException(status_code=400, detail="Already applied")

        existing_saved = await self.applications.find_one({
            "job_id": job_id,
            "user_email": applicant_email,
            "application_type": "job",
            "status": "saved"
        })

        if existing_saved:
            return await self.convert_saved_to_applied(job_id, application_data, current_user, None)

        application = UnifiedApplicationModel(
            application_type="job",
            user_email=applicant_email,
            user_name=applicant_name,
            user_id=current_user.get("user_id"),
            job_id=job_id,
            job_title=job.get("post_name", "Job Opportunity"),
            organization=job.get("organization", "Company"),
            added_by=job.get("added_by", "admin@rojgarnest.com"),
            applicant_name=applicant_name,
            applicant_email=applicant_email,
            resume_url=application_data.resume_url,
            cover_letter=application_data.cover_letter,
            additional_info=application_data.additional_info,
            status="pending",
            applied_at=datetime.utcnow(),
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )

        app_dict = application.to_dict()
        app_dict["color_type"] = job.get("color_type", "blue")
        app_dict["is_archived"] = False

        result = await self.applications.insert_one(app_dict)
        application_id = str(result.inserted_id)

        ai_score = None
        try:
            profile = await self.db.profile.find_one({"email": applicant_email})
            if profile and job:
                ai_result = await compute_ai_match(job, profile)
                ai_score = ai_result.get("match_percentage", 50)
                await self.applications.update_one(
                    {"_id": result.inserted_id},
                    {"$set": {"ai_match": ai_result, "match_score": ai_score}}
                )
        except Exception as ai_err:
            logger.warning(f"AI matching skipped: {ai_err}")

        await central_notification.notify_new_application(
            {
                "application_id": application_id,
                "job_id": job_id,
                "job_title": job.get("post_name"),
                "organization": job.get("organization"),
                "applicant_name": applicant_name,
                "applicant_email": applicant_email
            },
            job,
            job.get("added_by", "admin@rojgarnest.com")
        )

        return {
            "success": True,
            "application_id": application_id,
            "application_type": "job",
            "message": "Application submitted successfully",
            "ai_match_score": ai_score,
            "status": "pending"
        }

    # ==========================================================
    # UPDATE APPLICATION STATUS
    # ==========================================================
    async def update_application_status(self, application_id: str, status_data: ApplicationStatusUpdateSchema, current_user: dict):
        if not ObjectId.is_valid(application_id):
            raise HTTPException(status_code=400, detail="Invalid application ID")

        admin_email, _ = await self._get_user_email(current_user)
        user_role = current_user.get("role", "").lower()

        application = await self.applications.find_one({
            "_id": ObjectId(application_id),
            "application_type": "job"
        })
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")

        job = await self.jobs.find_one({"_id": ObjectId(application.get("job_id"))})

        if job and job.get("added_by") != admin_email and user_role != "superadmin":
            raise HTTPException(status_code=403, detail="Access denied")

        new_status = status_data.status
        notes = status_data.notes

        update_data = {
            "status": new_status,
            "admin_notes": notes,
            "last_status_update": datetime.utcnow(),
            "last_updated_by": admin_email,
            "updated_at": datetime.utcnow()
        }

        result = await self.applications.update_one(
            {"_id": ObjectId(application_id)},
            {"$set": update_data}
        )

        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Application not found or status unchanged")

        await central_notification.notify_status_update(
            application_id=application_id,
            new_status=new_status,
            notes=notes,
            updated_by_email=admin_email
        )

        return {"message": f"Status updated to {new_status}"}

    # ==========================================================
    # SAVE JOB (BOOKMARK)
    # ==========================================================
    async def save_job(self, job_id: str, current_user: dict) -> Dict[str, Any]:
        if not ObjectId.is_valid(job_id):
            raise HTTPException(status_code=400, detail="Invalid job ID")

        job = await self.jobs.find_one({
            "_id": ObjectId(job_id),
            "is_deleted": {"$ne": True}
        })
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")

        applicant_email, applicant_name = await self._get_user_email(current_user)

        existing_applied = await self.applications.find_one({
            "job_id": job_id,
            "user_email": applicant_email,
            "application_type": "job",
            "status": {"$ne": "saved"}
        })

        if existing_applied:
            raise HTTPException(status_code=400, detail="You have already applied for this job")

        existing_saved = await self.applications.find_one({
            "job_id": job_id,
            "user_email": applicant_email,
            "application_type": "job",
            "status": "saved"
        })

        if existing_saved:
            raise HTTPException(status_code=400, detail="Job already saved")

        application = UnifiedApplicationModel(
            application_type="job",
            user_email=applicant_email,
            user_name=applicant_name,
            user_id=current_user.get("user_id"),
            job_id=job_id,
            job_title=job.get("post_name", "Job Opportunity"),
            organization=job.get("organization", "Company"),
            added_by=job.get("added_by", "admin@rojgarnest.com"),
            applicant_name=applicant_name,
            applicant_email=applicant_email,
            status="saved",
            saved_at=datetime.utcnow(),
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )

        app_dict = application.to_dict()
        app_dict["color_type"] = job.get("color_type", "blue")
        app_dict["is_archived"] = False

        result = await self.applications.insert_one(app_dict)

        return {
            "success": True,
            "message": "Job saved successfully",
            "application_id": str(result.inserted_id),
            "application_type": "job",
            "status": "saved"
        }

    # ==========================================================
    # ✅ FIXED: UNSAVE JOB — ARCHIVES instead of DELETES
    # ==========================================================
    async def unsave_job(self, job_id: str, current_user: dict) -> Dict[str, Any]:
        """
        ✅ FIXED: Unsave job — ARCHIVES the saved bookmark.
        NEVER physically removes the record.
        """
        if not ObjectId.is_valid(job_id):
            raise HTTPException(status_code=400, detail="Invalid job ID")

        applicant_email, _ = await self._get_user_email(current_user)
        now = datetime.utcnow()

        # ✅ ARCHIVE instead of DELETE
        result = await self.applications.update_many(
            {
                "job_id": job_id,
                "user_email": applicant_email,
                "application_type": "job",
                "status": "saved"
            },
            {"$set": {
                "status": "unsaved",
                "is_archived": True,
                "archived_at": now,
                "archived_reason": "user_unsaved",
                "updated_at": now
            }}
        )

        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Saved job not found")

        return {
            "success": True,
            "message": "Job removed from saved (archived, not deleted)",
            "archived_count": result.modified_count,
            "data_preserved": True
        }

    # ==========================================================
    # GET SAVED JOBS
    # ==========================================================
    async def get_saved_jobs(self, current_user: dict) -> Dict[str, Any]:
        applicant_email, _ = await self._get_user_email(current_user)

        saved_applications = await self.applications.find({
            "user_email": applicant_email,
            "application_type": "job",
            "status": "saved",
            "is_archived": {"$ne": True}
        }).sort("saved_at", -1).to_list(100)

        saved_jobs = []
        for app in saved_applications:
            job = await self.jobs.find_one({
                "_id": ObjectId(app["job_id"]),
                "is_deleted": {"$ne": True}
            })
            if job:
                job["_id"] = str(job["_id"])
                job.setdefault("color_type", "blue")
                job["saved_at"] = app.get("saved_at")
                job["application_id"] = str(app["_id"])
                job["is_saved"] = True
                saved_jobs.append(job)

        return {
            "success": True,
            "saved_jobs": saved_jobs,
            "total": len(saved_jobs)
        }

    # ==========================================================
    # GET APPLIED JOBS
    # ==========================================================
    async def get_applied_jobs(self, current_user: dict) -> Dict[str, Any]:
        applicant_email, _ = await self._get_user_email(current_user)

        applied_applications = await self.applications.find({
            "user_email": applicant_email,
            "application_type": "job",
            "status": {"$nin": ["saved", "unsaved"]},
            "is_archived": {"$ne": True}
        }).sort("applied_at", -1).to_list(100)

        applied_jobs = []
        for app in applied_applications:
            job = await self.jobs.find_one({"_id": ObjectId(app["job_id"])})
            if job:
                job["_id"] = str(job["_id"])
                job.setdefault("color_type", "blue")
                job["applied_at"] = app.get("applied_at")
                job["application_id"] = str(app["_id"])
                job["application_status"] = app.get("status", "pending")
                job["match_score"] = app.get("match_score")
                job["is_applied"] = True
                applied_jobs.append(job)

        return {
            "success": True,
            "applied_jobs": applied_jobs,
            "total": len(applied_jobs)
        }

    # ==========================================================
    # GET MY APPLICATIONS BY MODE
    # ==========================================================
    async def get_my_applications_by_mode(
        self,
        current_user: dict,
        filter_mode: Optional[str] = None
    ) -> Dict[str, Any]:
        applicant_email, _ = await self._get_user_email(current_user)

        query = {
            "user_email": applicant_email,
            "application_type": "job",
            "is_archived": {"$ne": True}
        }

        if filter_mode == "saved":
            query["status"] = "saved"
        elif filter_mode == "applied":
            query["status"] = {"$nin": ["saved", "unsaved"]}

        applications = await self.applications.find(query).sort("created_at", -1).to_list(100)

        result_apps = []
        for app in applications:
            app_dict = {
                "_id": str(app["_id"]),

                # ✅ NEW: Application number (generated by payment verify)
                "application_number": app.get("application_number"),

                "application_type": app.get("application_type", "job"),
                "job_id": app.get("job_id"),
                "job_title": app.get("job_title", "Job Opportunity"),
                "organization": app.get("organization", "Company"),
                "applicant_name": app.get("applicant_name"),
                "applicant_email": app.get("applicant_email"),
                "user_email": app.get("user_email"),
                "status": app.get("status", "saved"),
                "match_score": app.get("match_score"),
                "color_type": app.get("color_type", "blue"),
                "saved_at": app.get("saved_at").isoformat() if app.get("saved_at") else None,
                "applied_at": app.get("applied_at").isoformat() if app.get("applied_at") else None,
                "created_at": app.get("created_at").isoformat() if app.get("created_at") else None,
                "payment_verification_status": app.get("payment_verification_status", "not_submitted"),
                "payment_amount": app.get("payment_amount"),
                "payment_category_used": app.get("payment_category_used"),
                "transaction_id": app.get("transaction_id"),
                "transaction_date": app.get("transaction_date").isoformat() if app.get("transaction_date") else None,
                "payment_receipt_url": app.get("payment_receipt_url"),
                "application_updates": app.get("application_updates", []),
                "update_notes": app.get("update_notes"),
                "update_submitted_at": app.get("update_submitted_at").isoformat() if app.get("update_submitted_at") else None,
                "submitted_document_url": app.get("submitted_document_url"),
                "submitted_document_name": app.get("submitted_document_name"),
                "submitted_at": app.get("submitted_at").isoformat() if app.get("submitted_at") else None,
                "final_document_url": app.get("final_document_url"),
                "final_submitted_at": app.get("final_submitted_at").isoformat() if app.get("final_submitted_at") else None,
                "is_saved": app.get("status") == "saved",
                "is_applied": app.get("status") not in ["saved", "unsaved"]
            }
            result_apps.append(app_dict)

        return {
            "success": True,
            "applications": result_apps,
            "total": len(result_apps),
            "saved_count": sum(1 for app in result_apps if app['is_saved']),
            "applied_count": sum(1 for app in result_apps if app['is_applied']),
            "filter_mode": filter_mode or "all",
            "application_type": "job",
            "message": f"Showing {len(result_apps)} job applications"
        }

    # ==========================================================
    # GET ADMIN APPLICATIONS
    # ==========================================================
    async def get_admin_applications(self, admin_email: str, status_filter: Optional[str] = None) -> Dict[str, Any]:
        try:
            admin_jobs = await self.jobs.find({"added_by": admin_email}, {"_id": 1}).to_list(1000)
            admin_job_ids = [str(job["_id"]) for job in admin_jobs]

            if not admin_job_ids:
                return {
                    "applications": [],
                    "jobs_count": 0,
                    "total": 0,
                    "admin_email": admin_email
                }

            query = {
                "job_id": {"$in": admin_job_ids},
                "application_type": "job"
            }
            if status_filter and status_filter != "all":
                query["status"] = status_filter

            applications = await self.applications.find(query).sort("applied_at", -1).to_list(1000)

            for app in applications:
                job = await self.jobs.find_one({"_id": ObjectId(app["job_id"])}) if app.get("job_id") else None
                if job:
                    app["job_title"] = job.get("post_name", "Unknown")
                    app["organization"] = job.get("organization", "Unknown")
                    app["color_type"] = job.get("color_type", "blue")
                else:
                    app.setdefault("color_type", "blue")
                app["_id"] = str(app["_id"])
                app["job_id"] = str(app["job_id"]) if app.get("job_id") else None
                if "applied_at" in app and isinstance(app["applied_at"], datetime):
                    app["applied_at"] = app["applied_at"].isoformat()
                app["application_type"] = "job"

            return {
                "applications": applications,
                "jobs_count": len(admin_job_ids),
                "total": len(applications),
                "admin_email": admin_email
            }
        except Exception as e:
            logger.error(f"Error in get_admin_applications: {e}")
            return {
                "applications": [],
                "jobs_count": 0,
                "total": 0,
                "admin_email": admin_email,
                "error": str(e)
            }

    # ==========================================================
    # GET ADMIN JOBS
    # ==========================================================
    async def get_admin_jobs(self, admin_email: str) -> Dict:
        try:
            jobs = await self.jobs.find({
                "added_by": admin_email,
                "is_deleted": {"$ne": True}   # ✅ exclude soft-deleted
            }).sort("created_at", -1).to_list(1000)

            for job in jobs:
                job["_id"] = str(job["_id"])
                job.setdefault("color_type", "blue")
                app_count = await self.applications.count_documents({
                    "job_id": str(job["_id"]),
                    "application_type": "job",
                    "is_archived": {"$ne": True}   # ✅ exclude archived
                })
                job["applications_count"] = app_count

            return {"success": True, "jobs": jobs, "total": len(jobs)}
        except Exception as e:
            logger.error(f"Error in get_admin_jobs: {e}")
            return {"success": False, "jobs": [], "total": 0}

    # ==========================================================
    # GET MY APPLICATIONS (LEGACY)
    # ==========================================================
    async def get_my_applications(self, current_user: dict):
        return await self.get_my_applications_by_mode(current_user, "all")

    # ==========================================================
    # CHECK IF JOB IS SAVED
    # ==========================================================
    async def is_job_saved(self, job_id: str, current_user: dict) -> bool:
        if not ObjectId.is_valid(job_id):
            return False

        applicant_email, _ = await self._get_user_email(current_user)

        saved_app = await self.applications.find_one({
            "job_id": job_id,
            "user_email": applicant_email,
            "application_type": "job",
            "status": "saved",
            "is_archived": {"$ne": True}
        })

        return saved_app is not None

    # ==========================================================
    # CHECK IF JOB IS APPLIED
    # ==========================================================
    async def is_job_applied(self, job_id: str, current_user: dict) -> bool:
        if not ObjectId.is_valid(job_id):
            return False

        applicant_email, _ = await self._get_user_email(current_user)

        applied_app = await self.applications.find_one({
            "job_id": job_id,
            "user_email": applicant_email,
            "application_type": "job",
            "status": {"$nin": ["saved", "unsaved"]},
            "is_archived": {"$ne": True}
        })

        return applied_app is not None

    # ==========================================================
    # CONVERT SAVED TO APPLIED
    # ==========================================================
    async def convert_saved_to_applied(
        self,
        job_id: str,
        application_data: ApplicationCreateSchema,
        current_user: dict,
        payment_id: Optional[str] = None
    ) -> Dict[str, Any]:
        if not ObjectId.is_valid(job_id):
            raise HTTPException(status_code=400, detail="Invalid job ID")

        applicant_email, applicant_name = await self._get_user_email(current_user)

        saved_app = await self.applications.find_one({
            "job_id": job_id,
            "user_email": applicant_email,
            "application_type": "job",
            "status": "saved",
            "is_archived": {"$ne": True}
        })

        if not saved_app:
            return await self.apply_to_job(job_id, application_data, current_user)

        job = await self.jobs.find_one({"_id": ObjectId(job_id)})
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")

        has_fees = job.get("has_application_fees", False)
        amount = 0

        if has_fees and payment_id:
            payment = await self.db.payments.find_one({"_id": ObjectId(payment_id)})
            if payment:
                amount = payment.get("amount", 0)

        new_status = "pending_verification" if has_fees and amount > 0 else "pending"

        update_data = {
            "status": new_status,
            "applied_at": datetime.utcnow(),
            "resume_url": application_data.resume_url,
            "cover_letter": application_data.cover_letter,
            "additional_info": application_data.additional_info,
            "color_type": job.get("color_type", "blue"),
            "updated_at": datetime.utcnow()
        }

        if has_fees and payment_id:
            update_data["payment_id"] = payment_id

        result = await self.applications.update_one(
            {"_id": saved_app["_id"]},
            {"$set": update_data}
        )

        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Application not found")

        application_id = str(saved_app["_id"])

        ai_score = None
        try:
            profile = await self.db.profile.find_one({"email": applicant_email})
            if profile and job:
                ai_result = await compute_ai_match(job, profile)
                ai_score = ai_result.get("match_percentage", 50)
                await self.applications.update_one(
                    {"_id": saved_app["_id"]},
                    {"$set": {"ai_match": ai_result, "match_score": ai_score}}
                )
        except Exception as ai_err:
            logger.warning(f"AI matching skipped: {ai_err}")

        await central_notification.notify_new_application(
            {
                "application_id": application_id,
                "job_id": job_id,
                "job_title": job.get("post_name"),
                "organization": job.get("organization"),
                "applicant_name": applicant_name,
                "applicant_email": applicant_email
            },
            job,
            job.get("added_by", "admin@rojgarnest.com")
        )

        status_message = "Your application has been submitted successfully."
        if has_fees and amount > 0:
            status_message = "Your application has been submitted. Payment verification is pending admin approval."

        await central_notification.send_notification(
            user_ids=[applicant_email],
            notification_type="application_status",
            title="✅ Application Submitted",
            message=f"Your application for {job.get('post_name')} at {job.get('organization')} has been submitted successfully.\n\n{status_message}",
            send_email=True,
            send_websocket=True
        )

        return {
            "success": True,
            "application_id": application_id,
            "application_type": "job",
            "message": status_message,
            "ai_match_score": ai_score,
            "status": new_status,
            "is_saved": False,
            "is_applied": True
        }

    # ==========================================================
    # GET APPLICATION FEES
    # ==========================================================
    async def get_application_fees(self, job_id: str) -> Dict[str, Any]:
        if not ObjectId.is_valid(job_id):
            raise HTTPException(status_code=400, detail="Invalid job ID")

        job = await self.jobs.find_one({"_id": ObjectId(job_id)})
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")

        return {
            "has_application_fees": job.get("has_application_fees", False),
            "application_fees": job.get("application_fees", {}),
            "job_title": job.get("post_name"),
            "organization": job.get("organization"),
            "color_type": job.get("color_type", "blue")
        }

    # ==========================================================
    # GET NEARBY JOBS
    # ==========================================================
    async def get_nearby_jobs(self, latitude: float, longitude: float, radius_km: float = 10.0, limit: int = 50):
        radius_meters = radius_km * 1000

        jobs = await self.jobs.find({
            "status": "open",
            "is_deleted": {"$ne": True}
        }).to_list(500)

        nearby_jobs = []
        for job in jobs:
            job_location = job.get("job_location", {})
            job_lat = job_location.get("latitude")
            job_lon = job_location.get("longitude")

            if job_lat is not None and job_lon is not None and (job_lat != 0 or job_lon != 0):
                distance = DistanceCalculator.calculate_distance(latitude, longitude, job_lat, job_lon)

                if distance <= radius_meters:
                    job["_id"] = str(job["_id"])
                    job.setdefault("color_type", "blue")
                    job["distance_km"] = round(distance / 1000, 2)
                    job["distance_meters"] = round(distance, 2)
                    nearby_jobs.append(job)

        nearby_jobs.sort(key=lambda x: x.get("distance_km", float('inf')))
        return {"jobs": nearby_jobs[:limit], "total": len(nearby_jobs)}

    # ==========================================================
    # GET APPLICATION DETAIL
    # ==========================================================
    async def get_application_detail(self, application_id: str, current_user: dict) -> Dict[str, Any]:
        if not ObjectId.is_valid(application_id):
            raise HTTPException(status_code=400, detail="Invalid application ID")

        application = await self.applications.find_one({
            "_id": ObjectId(application_id),
            "application_type": "job"
        })

        if not application:
            raise HTTPException(status_code=404, detail="Application not found")

        user_email = current_user.get("email")
        user_role = current_user.get("role", "").lower()

        is_owner = application.get("user_email") == user_email
        is_admin = user_role in ["admin", "customadmin", "superadmin"]

        if not (is_owner or is_admin):
            raise HTTPException(status_code=403, detail="Access denied")

        application["_id"] = str(application["_id"])
        application.setdefault("color_type", "blue")

        job = await self.jobs.find_one({"_id": ObjectId(application.get("job_id"))})
        profile = await self.db.profile.find_one({"email": application.get("user_email")})

        return {
            "application": application,
            "job": {
                "_id": str(job["_id"]) if job else None,
                "post_name": job.get("post_name") if job else None,
                "organization": job.get("organization") if job else None,
                "color_type": job.get("color_type", "blue") if job else "blue"
            } if job else None,
            "profile": {
                "_id": str(profile["_id"]) if profile else None,
                "full_name": profile.get("full_name") if profile else None,
                "phone": profile.get("phone") if profile else None,
                "skills": profile.get("skills", []) if profile else []
            } if profile else None,
            "application_type": "job"
        }

    # ==========================================================
    # AI-ENHANCED JOBS
    # ==========================================================
    async def get_ai_enhanced_jobs(self, current_user: dict, limit: int = 20) -> Dict:
        """Get AI-enhanced job listings with match scores."""
        email = current_user.get("email")
        if not email:
            return {"jobs": [], "total": 0, "message": "User not found"}

        profile = await self.db.profile.find_one({"email": email})
        if not profile:
            return {
                "jobs": [],
                "total": 0,
                "message": "Complete your profile for personalized jobs"
            }

        user_skills = [s.get('name', '').lower() for s in profile.get('skills', [])]
        user_exp = len(profile.get('experience', []))
        user_edu = len(profile.get('academic_records', []))

        query = {
            "status": "open",
            "is_deleted": {"$ne": True}
        }
        if user_skills:
            query["required_skills.name"] = {"$in": user_skills}

        jobs = await self.jobs.find(query).limit(limit * 2).to_list(limit * 2)

        if not jobs:
            jobs = await self.jobs.find({
                "status": "open",
                "is_deleted": {"$ne": True}
            }).limit(limit).to_list(limit)

        enhanced_jobs = []
        for job in jobs:
            job_skills = []
            for skill in job.get('required_skills', []):
                if isinstance(skill, dict):
                    job_skills.append(skill.get('name', '').lower())
                elif isinstance(skill, str):
                    job_skills.append(skill.lower())

            if job_skills and user_skills:
                matching_skills = set(user_skills) & set(job_skills)
                skill_match = (len(matching_skills) / len(job_skills)) * 100
            else:
                skill_match = 50
                matching_skills = set()

            req_exp = job.get('experience_min_years', 0)
            exp_match = min(100, (user_exp / max(1, req_exp)) * 100) if req_exp > 0 else 70
            edu_match = min(100, user_edu * 30) if user_edu > 0 else 20

            total_match = (skill_match * 0.5 + exp_match * 0.3 + edu_match * 0.2)

            try:
                market_demand = await real_time_market_ai.predict_future_demand(
                    job.get('post_name', ''), 6
                )
            except Exception as e:
                logger.warning(f"Market demand prediction failed: {e}")
                market_demand = {"growth_percentage": 0}

            enhanced_job = dict(job)
            enhanced_job['_id'] = str(job['_id'])
            enhanced_job.setdefault('color_type', 'blue')
            enhanced_job['ai_match'] = {
                'match_score': round(total_match),
                'skill_match': round(skill_match),
                'experience_match': round(exp_match),
                'education_match': round(edu_match),
                'matching_skills': list(matching_skills)[:5],
                'missing_skills': list(set(job_skills) - set(user_skills))[:5] if job_skills else [],
                'market_demand': market_demand.get('growth_percentage', 0)
            }

            enhanced_jobs.append(enhanced_job)

        enhanced_jobs.sort(key=lambda x: x['ai_match']['match_score'], reverse=True)

        return {
            "jobs": enhanced_jobs[:limit],
            "total": len(enhanced_jobs),
            "user_summary": {
                "skills_count": len(user_skills),
                "experience_count": user_exp,
                "education_count": user_edu
            }
        }

    # ==========================================================
    # ✅ FIXED: UPDATE JOB
    # ==========================================================
    async def update_job(
        self,
        job_id: str,
        job_data: Dict[str, Any],
        admin_email: Optional[str] = None,
        user_role: str = "admin"
    ) -> Dict[str, Any]:
        """Update an existing job."""
        if not ObjectId.is_valid(job_id):
            raise HTTPException(status_code=400, detail="Invalid job ID")

        job = await self.jobs.find_one({"_id": ObjectId(job_id)})
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")

        job_owner = job.get("added_by")
        user_role_lower = (user_role or "admin").lower()
        if user_role_lower == "custom_admin":
            user_role_lower = "customadmin"

        if job_owner != admin_email and user_role_lower != "superadmin":
            raise HTTPException(status_code=403, detail="Access denied")

        update_data: Dict[str, Any] = {}
        allowed_fields = {
            "post_name", "organization", "location", "location_text", "job_type",
            "job_level", "category", "color_type", "status", "description",
            "last_date", "required_qualification", "experience_min_years",
            "experience_max_years", "required_skills", "nice_to_have_skills",
            "benefits", "tags", "salary_min", "salary_max", "salary_currency",
            "total_posts", "multiple_posts", "age_min_years", "age_max_years",
            "age_calculation_date", "age_relaxation_details",
            "age_relaxation_by_category", "physical_eligibility", "medical_standards",
            "training_details", "has_bond", "bond_duration", "bond_amount",
            "bond_terms", "education_details", "experience_details",
            "is_fresher_eligible", "is_experienced_eligible", "work_schedule",
            "shift", "working_days", "languages_required", "other_languages",
            "interview_venue", "interview_link", "interview_date", "interview_time",
            "interview_documents", "contact_person", "contact_designation",
            "contact_email", "contact_phone", "important_notes", "terms_conditions",
            "selection_stages", "selection_process_details", "urgency_level",
            "gender_preference", "is_fully_remote", "is_hybrid", "official_website",
            "helpline_number", "helpline_email", "whatsapp_number", "telegram_channel",
            "application_mode", "exam_cities", "application_start_date",
            "application_end_date", "admit_card_date", "exam_date", "result_date",
            "has_application_fees", "application_fees", "apply_with_us_url",
            "has_apply_with_us", "official_notification_url", "has_official_notification",
            "is_featured", "is_urgent", "is_draft",
        }

        for field in allowed_fields:
            if field in job_data and job_data[field] is not None:
                update_data[field] = job_data[field]

        if "color_type" in update_data:
            ct = str(update_data["color_type"]).lower().strip()
            if ct == "gray":
                ct = "grey"
            valid_colors = {"blue", "green", "red", "orange", "purple", "teal",
                            "pink", "indigo", "amber", "cyan", "grey", "white"}
            update_data["color_type"] = ct if ct in valid_colors else "blue"

        if "apply_with_us_url" in update_data:
            url = str(update_data["apply_with_us_url"]).strip()
            update_data["has_apply_with_us"] = bool(url and url != "#")

        if "application_fees" in update_data and isinstance(update_data["application_fees"], dict):
            cleaned_fees = {}
            for cat, fee in update_data["application_fees"].items():
                try:
                    amt = int(fee)
                    if amt >= 0:
                        cleaned_fees[cat.lower()] = amt
                except (ValueError, TypeError):
                    pass
            update_data["application_fees"] = cleaned_fees
            update_data["has_application_fees"] = bool(cleaned_fees)

        if not update_data:
            return {
                "success": True,
                "message": "No fields to update",
                "job_id": job_id,
                "modified": False,
            }

        update_data["updated_at"] = datetime.utcnow()
        update_data["last_updated_by"] = admin_email

        result = await self.jobs.update_one(
            {"_id": ObjectId(job_id)},
            {"$set": update_data}
        )

        updated_job = await self.jobs.find_one({"_id": ObjectId(job_id)})
        updated_job["_id"] = str(updated_job["_id"])
        updated_job.setdefault("color_type", "blue")

        logger.info(f"✅ Job {job_id} updated by {admin_email} ({len(update_data)} fields)")

        return {
            "success": True,
            "message": "Job updated successfully",
            "job_id": job_id,
            "modified": result.modified_count > 0,
            "fields_updated": len(update_data),
            "data": updated_job,
        }

    # ==========================================================
    # ✅ CRITICAL FIX: DELETE JOB — SOFT DELETE ONLY
    # ✅ Applications are ARCHIVED, NEVER deleted
    # ==========================================================
    async def delete_job(
        self,
        job_id: str,
        admin_email: Optional[str] = None,
        user_role: str = "admin"
    ) -> Dict[str, Any]:
        """
        ✅ SAFE JOB DELETION — NO HARD DELETE:

        What it does:
        - Soft-deletes the job (is_deleted=True, is_archived=True)
        - Archives ALL applications for this job (is_archived=True)
        - Deletes only the Cloudinary advertisement file (if exists)
        - Logs everything in security collection

        What it does NOT do:
        - ❌ Never calls delete_one / delete_many on jobs
        - ❌ Never calls delete_one / delete_many on applications
        - ❌ No data is physically removed

        Result: 100% data retention.
        """
        if not ObjectId.is_valid(job_id):
            raise HTTPException(status_code=400, detail="Invalid job ID")

        # Find job
        job = await self.jobs.find_one({"_id": ObjectId(job_id)})
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")

        # Permission check
        job_owner = job.get("added_by")
        user_role_lower = (user_role or "admin").lower()
        if user_role_lower == "custom_admin":
            user_role_lower = "customadmin"

        if job_owner != admin_email and user_role_lower != "superadmin":
            raise HTTPException(status_code=403, detail="Access denied")

        now = datetime.utcnow()

        # ✅ STEP 1: ARCHIVE all applications (NEVER DELETE!)
        app_archive_result = await self.applications.update_many(
            {
                "job_id": job_id,
                "application_type": "job"
            },
            {"$set": {
                "is_archived": True,
                "archived_at": now,
                "archived_reason": "parent_job_deleted",
                "archived_by": admin_email,
                "updated_at": now
            }}
        )

        # ✅ STEP 2: SOFT-DELETE job (NEVER physical delete!)
        await self.jobs.update_one(
            {"_id": ObjectId(job_id)},
            {"$set": {
                "is_deleted": True,
                "is_archived": True,
                "deleted_at": now,
                "deleted_by": admin_email,
                "status": "closed",
                "updated_at": now
            }}
        )

        # ✅ STEP 3: Delete ONLY the Cloudinary advertisement file
        adv_public_id = job.get("advertisement_public_id")
        if adv_public_id:
            try:
                from app.core.services.cloudinary import delete_from_cloudinary
                resource_type = job.get("advertisement_resource_type", "raw")
                await delete_from_cloudinary(adv_public_id, resource_type)
                logger.info(f"🗑️ Deleted Cloudinary ad file: {adv_public_id}")
            except Exception as e:
                logger.warning(f"⚠️ Could not delete Cloudinary ad: {e}")

        # ✅ STEP 4: Log the action (never deletes)
        try:
            await self.db.security.insert_one({
                "type": "security_log",
                "event_type": "job_soft_deleted",
                "ip_address": "internal",
                "user_email": admin_email,
                "severity": "medium",
                "details": {
                    "job_id": job_id,
                    "job_title": job.get("post_name"),
                    "applications_archived": app_archive_result.modified_count,
                },
                "action_taken": "soft_deleted_and_archived",
                "created_at": now
            })
        except Exception as e:
            logger.warning(f"⚠️ Could not log job deletion: {e}")

        logger.info(
            f"🔒 Job {job_id} SOFT-DELETED by {admin_email}. "
            f"Archived {app_archive_result.modified_count} applications. "
            f"Data preserved."
        )

        return {
            "success": True,
            "message": (
                f"Job deleted successfully. "
                f"{app_archive_result.modified_count} applications archived "
                f"(data preserved, not removed)."
            ),
            "job_id": job_id,
            "applications_archived": app_archive_result.modified_count,
            "applications_deleted": 0,   # ✅ NEVER any hard deletion
            "data_preserved": True,
            "soft_delete": True,
        }


print("=" * 70)
print("✅ Job Service Updated - 100% DATA RETENTION")
print("   ✅ application_type='job' for all job applications")
print("   ✅ delete_job() → SOFT DELETE + ARCHIVE (no hard delete)")
print("   ✅ unsave_job() → ARCHIVE (no hard delete)")
print("   ✅ NO payment_pending status - Direct verification_successful")
print("   ✅ NO TTL indexes, NO drop, NO delete_many on user data")
print("=" * 70)