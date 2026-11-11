# app/modules/user/dashboard_service.py
# ============================================================
# USER DASHBOARD STATS SERVICE — COMPLETE FIXED VERSION
# ============================================================
# ✅ FIX 1: Service double-count eliminated (deduplication by
#           application_id + entity fallback)
# ✅ FIX 2: Scheme count fixed — detects type from
#           application_type / payment_type / scheme_id / service_id / job_id
# ✅ FIX 3: payment_received, payment_pending, payment_failed
#           computed for ALL 3 types
# ✅ FIX 4: Added `totals` block combining all 3 types
# ✅ FIX 5: Payment detection via Razorpay / transaction IDs
# ✅ FIX 6: Single query for all apps → consistent counts
# ✅ FIX 7: Handles user_email / email / applicant_email
# ============================================================

import logging
from datetime import datetime
from typing import Dict, Any, Optional, List

from app.core.utils.logger import logger  # noqa: F401

module_logger = logging.getLogger(__name__)

# ============================================================
# Status bucket definitions
# ============================================================
_PENDING_STATUSES = {
    "pending",
    "pending_verification",
    "review_application",
    "under_review",
    "update_application",
    "payment_pending",
    "submitted",
    "draft",
    "payment_initiated",
    "processing",
}

_APPROVED_STATUSES = {
    "approved",
    "approved_application",
    "completed",
    "final_submitted",
    "final_submit",
    "verification_successful",
    "payment_verified",
    "confirmed_application",
    "shortlisted",
    "interview",
    "offered",
    "hired",
    "accepted",
}

_REJECTED_STATUSES = {
    "rejected",
    "verification_rejected",
    "update_rejected",
    "payment_rejected",
    "cancelled",
    "declined",
}


class UserDashboardService:
    """
    Service for computing user dashboard statistics.

    All calculations are done in real-time from the database.
    Response contains **COUNTS ONLY** — no application IDs, no titles.
    """

    def __init__(self, db):
        self.db = db
        self.auth = db.auth
        self.profile = db.profile
        self.applications = db.applications
        self.jobs = db.job

    # ============================================================
    # MAIN: Get Complete Dashboard Stats
    # ============================================================
    async def get_dashboard_stats(self, email: str) -> Dict[str, Any]:
        """
        Returns complete dashboard statistics for a user:

        - profile_completion: 0-100
        - career_score: 0-100
        - job_applications:     { total, saved, applied, pending,
                                  approved, rejected,
                                  payment_received, payment_pending,
                                  payment_failed, by_status }
        - service_applications: { total, pending, approved, rejected,
                                  payment_received, payment_pending,
                                  payment_failed, by_status }
        - scheme_applications:  { total, pending, approved, rejected,
                                  payment_received, payment_pending,
                                  payment_failed, by_status }
        - totals: combined totals across all 3 types
        - profile_sections
        - career_breakdown
        """
        try:
            auth_user = await self.auth.find_one({"email": email})
            profile = await self.profile.find_one({"email": email})

            if not auth_user:
                return self._empty_stats()

            # ============================================================
            # 1. PROFILE COMPLETION
            # ============================================================
            profile_completion = self._calculate_profile_completion(
                auth_user, profile
            )

            # ============================================================
            # 2. CAREER SCORE
            # ============================================================
            career_score = await self._calculate_career_score(
                auth_user, profile
            )

            # ============================================================
            # 3-5. APPLICATIONS — SINGLE QUERY + PYTHON SPLIT
            # ------------------------------------------------------------
            # ✅ CRITICAL FIX: Instead of 3 separate count_documents
            #    calls (which caused inconsistencies when
            #    application_type was missing or spelled differently),
            #    we fetch ALL user apps once, dedupe, then split.
            # ============================================================
            all_docs = await self._fetch_all_user_applications(email)
            deduped = self._deduplicate(all_docs)

            job_docs: List[Dict] = []
            service_docs: List[Dict] = []
            scheme_docs: List[Dict] = []
            saved_jobs_count = 0

            for doc in deduped:
                app_type = self._detect_app_type(doc)
                status = str(doc.get("status") or "").lower()

                if app_type == "job":
                    if status == "saved":
                        saved_jobs_count += 1
                    elif status in ("unsaved", "archived"):
                        continue
                    else:
                        job_docs.append(doc)

                elif app_type == "service":
                    if doc.get("is_draft") is True:
                        continue
                    service_docs.append(doc)

                elif app_type == "scheme":
                    scheme_docs.append(doc)

            # ============================================================
            # Build per-type stats
            # ============================================================
            job_stats = self._build_type_stats(job_docs)
            job_stats["saved"] = saved_jobs_count
            job_stats["applied"] = job_stats["total"]

            service_stats = self._build_type_stats(service_docs)
            scheme_stats = self._build_type_stats(scheme_docs)

            # ============================================================
            # 6. PROFILE SECTIONS + CAREER BREAKDOWN
            # ============================================================
            profile_sections = self._get_profile_sections_breakdown(
                auth_user, profile
            )
            career_breakdown = await self._get_career_score_breakdown(
                auth_user, profile
            )

            return {
                "success": True,
                "profile_completion": profile_completion,
                "career_score": career_score,

                "job_applications": job_stats,
                "service_applications": service_stats,
                "scheme_applications": scheme_stats,

                "profile_sections": profile_sections,
                "career_breakdown": career_breakdown,

                # ✅ NEW: overall totals across all 3 types
                "totals": self._combine_totals(
                    job_stats, service_stats, scheme_stats
                ),

                "computed_at": datetime.utcnow().isoformat(),
            }

        except Exception as e:
            module_logger.error(
                f"Dashboard stats failed: {e}", exc_info=True
            )
            return self._empty_stats()

    # ============================================================
    # ✅ FETCH ALL USER APPLICATIONS
    # ------------------------------------------------------------
    # Matches by ANY of: user_email / email / applicant_email
    # Excludes archived documents.
    # ============================================================
    async def _fetch_all_user_applications(
        self, email: str
    ) -> List[Dict]:
        query = {
            "$or": [
                {"user_email": email},
                {"email": email},
                {"applicant_email": email},
            ],
            "is_archived": {"$ne": True},
        }

        projection = {
            "_id": 1,
            "application_id": 1,
            "application_number": 1,
            "application_type": 1,
            "payment_type": 1,
            "status": 1,
            "payment_status": 1,
            "payment_verification_status": 1,
            "payment_verified": 1,
            "is_paid": 1,
            "razorpay_payment_id": 1,
            "razorpay_order_id": 1,
            "transaction_id": 1,
            "payment_id": 1,
            "amount": 1,
            "payment_amount": 1,
            "job_id": 1,
            "service_id": 1,
            "scheme_id": 1,
            "is_draft": 1,
            "created_at": 1,
            "applied_at": 1,
        }

        docs: List[Dict] = []
        try:
            cursor = self.applications.find(query, projection)
            async for doc in cursor:
                docs.append(doc)
        except Exception as e:
            module_logger.error(f"fetch applications failed: {e}")

        return docs

    # ============================================================
    # ✅ DEDUPLICATE
    # ------------------------------------------------------------
    # Same logical application DB me 2 baar ho sakti hai
    # (service create-order + verify-payment dono create karte hain).
    #
    # Dedupe key priority:
    #   1. application_id / application_number
    #   2. app_type + job_id/service_id/scheme_id + status
    #   3. _id
    # ============================================================
    def _deduplicate(self, docs: List[Dict]) -> List[Dict]:
        seen = set()
        result = []

        for doc in docs:
            key = None

            app_id = (
                doc.get("application_id")
                or doc.get("application_number")
            )
            if app_id:
                key = f"num::{app_id}"

            if key is None:
                app_type = self._detect_app_type(doc)
                entity_id = (
                    doc.get("job_id")
                    or doc.get("service_id")
                    or doc.get("scheme_id")
                )
                status = str(doc.get("status") or "").lower()
                if entity_id:
                    key = f"entity::{app_type}::{entity_id}::{status}"

            if key is None:
                key = f"oid::{doc.get('_id')}"

            if key in seen:
                module_logger.warning(
                    f"Duplicate application skipped: {key}"
                )
                continue
            seen.add(key)
            result.append(doc)

        return result

    # ============================================================
    # ✅ DETECT APP TYPE (fallback chain)
    # ------------------------------------------------------------
    # Priority:
    #   1. application_type
    #   2. payment_type
    #   3. presence of scheme_id / service_id / job_id
    # ============================================================
    def _detect_app_type(self, doc: Dict) -> str:
        raw = doc.get("application_type") or doc.get("payment_type")
        if raw:
            t = str(raw).strip().lower()
            if t in ("job", "jobs"):
                return "job"
            if t in ("service", "services", "online_service"):
                return "service"
            if t in ("scheme", "schemes"):
                return "scheme"

        # Fallback by entity id presence
        if doc.get("scheme_id"):
            return "scheme"
        if doc.get("service_id"):
            return "service"
        if doc.get("job_id"):
            return "job"

        return "unknown"

    # ============================================================
    # ✅ BUILD PER-TYPE STATS
    # ------------------------------------------------------------
    # For a list of docs (already filtered by type):
    #   total, pending, approved, rejected,
    #   payment_received, payment_pending, payment_failed,
    #   by_status
    # ============================================================
    def _build_type_stats(self, docs: List[Dict]) -> Dict[str, Any]:
        pending = 0
        approved = 0
        rejected = 0
        pay_received = 0
        pay_pending = 0
        pay_failed = 0
        by_status: Dict[str, int] = {}

        for doc in docs:
            status = str(doc.get("status") or "").lower()
            by_status[status] = by_status.get(status, 0) + 1

            if status in _PENDING_STATUSES:
                pending += 1
            elif status in _APPROVED_STATUSES:
                approved += 1
            elif status in _REJECTED_STATUSES:
                rejected += 1

            pay = self._payment_bucket(doc)
            if pay == "received":
                pay_received += 1
            elif pay == "pending":
                pay_pending += 1
            elif pay == "failed":
                pay_failed += 1

        return {
            "total": len(docs),
            "pending": pending,
            "approved": approved,
            "rejected": rejected,
            "payment_received": pay_received,
            "payment_pending": pay_pending,
            "payment_failed": pay_failed,
            "by_status": by_status,
        }

    # ============================================================
    # ✅ PAYMENT BUCKET
    # ------------------------------------------------------------
    # Returns: 'received' | 'pending' | 'failed' | 'none'
    # ============================================================
    def _payment_bucket(self, doc: Dict) -> str:
        # 1) Explicit flag
        if doc.get("payment_verified") is True:
            return "received"
        if doc.get("is_paid") is True:
            return "received"

        def norm(v):
            return str(v or "").strip().lower()

        ps = norm(doc.get("payment_status"))
        pvs = norm(doc.get("payment_verification_status"))

        received = {
            "paid", "captured", "settled", "success", "successful",
            "verified", "approved", "completed", "payment_verified",
            "verification_successful", "received",
        }
        failed = {
            "failed", "declined", "cancelled", "rejected",
            "payment_rejected", "verification_rejected",
        }
        pending = {
            "pending", "pending_verification", "under_review",
            "created", "processing", "initiated",
        }

        if ps in received or pvs in received:
            return "received"
        if ps in failed or pvs in failed:
            return "failed"
        if ps in pending or pvs in pending:
            return "pending"

        # 2) Razorpay / transaction ID present → received
        for key in ("razorpay_payment_id", "transaction_id", "payment_id"):
            v = norm(doc.get(key))
            if v and v not in ("null", "undefined", "n/a", "none"):
                return "received"

        # 3) Main status
        status = norm(doc.get("status"))
        if status in (
            "completed", "approved", "approved_application",
            "confirmed_application", "payment_verified",
            "verification_successful", "final_submitted", "offered",
        ):
            return "received"
        if status in (
            "rejected", "verification_rejected",
            "update_rejected", "payment_rejected",
        ):
            return "failed"
        if status in (
            "payment_pending", "pending_verification",
            "pending", "draft",
        ):
            return "pending"

        return "none"

    # ============================================================
    # ✅ COMBINE TOTALS
    # ============================================================
    def _combine_totals(
        self,
        job_stats: Dict[str, Any],
        service_stats: Dict[str, Any],
        scheme_stats: Dict[str, Any],
    ) -> Dict[str, int]:
        keys = [
            "total", "pending", "approved", "rejected",
            "payment_received", "payment_pending", "payment_failed",
        ]
        out = {k: 0 for k in keys}
        for block in (job_stats, service_stats, scheme_stats):
            for k in keys:
                out[k] += int(block.get(k, 0) or 0)
        return out

    # ============================================================
    # HELPER: Detect if user has ANY resume
    # ============================================================
    def _has_resume(
        self, profile: Optional[Dict[str, Any]]
    ) -> Dict[str, bool]:
        if not profile:
            return {
                "has_uploaded": False,
                "has_generated": False,
                "has_any": False,
            }

        additional = profile.get("additional_details") or {}

        resume_url = (
            profile.get("resume_url")
            or additional.get("resume_url")
        )
        has_uploaded = bool(
            resume_url and str(resume_url).startswith("http")
        )

        has_generated = bool(
            profile.get("resume_generated_at")
            or profile.get("resume_cache_html")
            or profile.get("resume_formats_available")
            or profile.get("has_generated_resume") is True
        )

        return {
            "has_uploaded": has_uploaded,
            "has_generated": has_generated,
            "has_any": has_uploaded or has_generated,
        }

    # ============================================================
    # PROFILE COMPLETION CALCULATION
    # ============================================================
    def _calculate_profile_completion(
        self,
        auth_user: Dict[str, Any],
        profile: Optional[Dict[str, Any]],
    ) -> int:
        if not profile:
            profile = {}

        score = 0.0

        # ---- Basic Info (20%) ----
        basic_fields_present = 0
        if auth_user.get("name"):
            basic_fields_present += 1
        if auth_user.get("email"):
            basic_fields_present += 1
        if auth_user.get("mobile") or profile.get("phone"):
            basic_fields_present += 1
        if profile.get("dob"):
            basic_fields_present += 1
        if profile.get("gender"):
            basic_fields_present += 1
        score += (basic_fields_present / 5) * 20

        # ---- Address (10%) ----
        address = profile.get("current_address") or {}
        addr_fields = 0
        if address.get("city") or address.get("village_name"):
            addr_fields += 1
        if address.get("state"):
            addr_fields += 1
        if address.get("district"):
            addr_fields += 1
        score += (addr_fields / 3) * 10

        # ---- Education (15%) ----
        academic_records = profile.get("academic_records") or []
        if len(academic_records) >= 2:
            score += 15
        elif len(academic_records) == 1:
            score += 10

        # ---- Experience OR Fresher (15%) ----
        experience = profile.get("experience") or []
        is_fresher = profile.get("is_fresher", False)
        if len(experience) >= 2:
            score += 15
        elif len(experience) == 1:
            score += 12
        elif is_fresher:
            internships = profile.get("internships") or []
            projects = profile.get("projects") or []
            if internships or projects:
                score += 8
            else:
                score += 4

        # ---- Skills (15%) ----
        skills = profile.get("skills") or []
        if len(skills) >= 10:
            score += 15
        elif len(skills) >= 5:
            score += 12
        elif len(skills) >= 1:
            score += 6

        # ---- Resume (10%) ----
        resume_flags = self._has_resume(profile)
        if resume_flags["has_any"]:
            score += 10
            if (
                resume_flags["has_generated"]
                and not resume_flags["has_uploaded"]
            ):
                module_logger.debug(
                    "✅ Resume credit given via GENERATED resume "
                    "(no upload found)"
                )

        # ---- Profile Photo (5%) ----
        photo_url = (
            profile.get("profile_photo_url")
            or (profile.get("additional_details") or {}).get(
                "profile_photo_url"
            )
        )
        if photo_url and str(photo_url).startswith("http"):
            score += 5

        # ---- Summary (10%) ----
        summary = profile.get("summary") or ""
        career_obj = profile.get("career_objective") or ""
        if len(summary) >= 50:
            score += 10
        elif len(career_obj) >= 50:
            score += 8
        elif summary or career_obj:
            score += 4

        return int(min(100, max(0, round(score))))

    # ============================================================
    # CAREER SCORE CALCULATION
    # ============================================================
    async def _calculate_career_score(
        self,
        auth_user: Dict[str, Any],
        profile: Optional[Dict[str, Any]],
    ) -> int:
        if not profile:
            return 30

        breakdown = await self._get_career_score_breakdown(
            auth_user, profile
        )

        total = (
            breakdown["skill_score"] * 0.30
            + breakdown["experience_score"] * 0.25
            + breakdown["education_score"] * 0.20
            + breakdown["completeness_score"] * 0.15
            + breakdown["market_alignment_score"] * 0.10
        )

        return int(min(100, max(0, round(total))))

    async def _get_career_score_breakdown(
        self,
        auth_user: Dict[str, Any],
        profile: Optional[Dict[str, Any]],
    ) -> Dict[str, int]:
        if not profile:
            profile = {}

        # ---- Skill Score ----
        skills = profile.get("skills") or []
        skill_score = 0
        if skills:
            total_skill_points = 0
            for skill in skills:
                level = (skill.get("level") or "beginner").lower()
                if level == "expert":
                    total_skill_points += 100
                elif level == "advanced":
                    total_skill_points += 75
                elif level == "intermediate":
                    total_skill_points += 50
                else:
                    total_skill_points += 25
            skill_score = min(100, total_skill_points // len(skills))
            skill_score = min(100, skill_score + (len(skills) * 2))

        # ---- Experience Score ----
        experience = profile.get("experience") or []
        exp_years = 0
        for exp in experience:
            try:
                start = exp.get("start_date", "")
                if start:
                    exp_years += 1
            except Exception:
                pass

        internships = profile.get("internships") or []
        total_exp = exp_years + (len(internships) * 0.5)

        if total_exp >= 10:
            experience_score = 100
        elif total_exp >= 5:
            experience_score = 85
        elif total_exp >= 3:
            experience_score = 70
        elif total_exp >= 1:
            experience_score = 55
        elif profile.get("is_fresher"):
            projects = profile.get("projects") or []
            experience_score = 35 + min(20, len(projects) * 5)
        else:
            experience_score = 30

        # ---- Education Score ----
        academic_records = profile.get("academic_records") or []
        edu_score = 0
        if academic_records:
            levels = []
            for edu in academic_records:
                level = (edu.get("level") or "").lower()
                if "phd" in level:
                    levels.append(100)
                elif (
                    "post_graduation" in level
                    or "post graduation" in level
                ):
                    levels.append(90)
                elif "graduation" in level:
                    levels.append(75)
                elif "diploma" in level:
                    levels.append(60)
                elif "12th" in level:
                    levels.append(45)
                elif "10th" in level:
                    levels.append(30)
                else:
                    levels.append(20)

            edu_score = max(levels) if levels else 20
            edu_score = min(
                100, edu_score + (len(academic_records) - 1) * 5
            )
        else:
            edu_score = 10

        # ---- Completeness Score ----
        completeness_score = self._calculate_profile_completion(
            auth_user, profile
        )

        # ---- Market Alignment Score ----
        high_demand_skills = {
            "python", "javascript", "react", "node", "aws", "docker",
            "sql", "java", "typescript", "kubernetes", "machine learning",
            "data science", "flutter", "django", "fastapi", "mongodb",
            "postgresql", "git", "linux", "rest api", "graphql",
        }
        user_skill_names = {
            (s.get("name") or "").lower().strip() for s in skills
        }
        matched = len(user_skill_names & high_demand_skills)

        if matched >= 8:
            market_alignment = 100
        elif matched >= 5:
            market_alignment = 80
        elif matched >= 3:
            market_alignment = 60
        elif matched >= 1:
            market_alignment = 40
        else:
            market_alignment = 20

        return {
            "skill_score": int(skill_score),
            "experience_score": int(experience_score),
            "education_score": int(edu_score),
            "completeness_score": int(completeness_score),
            "market_alignment_score": int(market_alignment),
        }

    # ============================================================
    # PROFILE SECTIONS BREAKDOWN
    # ============================================================
    def _get_profile_sections_breakdown(
        self,
        auth_user: Dict[str, Any],
        profile: Optional[Dict[str, Any]],
    ) -> Dict[str, Any]:
        if not profile:
            profile = {}

        address = profile.get("current_address") or {}
        additional = profile.get("additional_details") or {}

        resume_flags = self._has_resume(profile)

        return {
            "basic_info": bool(
                auth_user.get("name")
                and auth_user.get("email")
                and (auth_user.get("mobile") or profile.get("phone"))
            ),
            "address": bool(
                (address.get("city") or address.get("village_name"))
                and address.get("state")
            ),
            "education": len(profile.get("academic_records") or []) > 0,
            "experience": len(profile.get("experience") or []) > 0,
            "skills": len(profile.get("skills") or []) > 0,
            "resume": resume_flags["has_any"],
            "profile_photo": bool(
                profile.get("profile_photo_url")
                or additional.get("profile_photo_url")
            ),
            "summary": bool(
                profile.get("summary") or profile.get("career_objective")
            ),
        }

    # ============================================================
    # EMPTY STATS — full consistent shape (COUNTS ONLY)
    # ============================================================
    def _empty_stats(self) -> Dict[str, Any]:
        def _empty_app_block():
            return {
                "total": 0,
                "pending": 0,
                "approved": 0,
                "rejected": 0,
                "payment_received": 0,
                "payment_pending": 0,
                "payment_failed": 0,
                "by_status": {},
            }

        return {
            "success": False,
            "profile_completion": 0,
            "career_score": 0,
            "job_applications": {
                **_empty_app_block(),
                "saved": 0,
                "applied": 0,
            },
            "service_applications": _empty_app_block(),
            "scheme_applications": _empty_app_block(),
            "profile_sections": {},
            "career_breakdown": {},
            "totals": {
                "total": 0,
                "pending": 0,
                "approved": 0,
                "rejected": 0,
                "payment_received": 0,
                "payment_pending": 0,
                "payment_failed": 0,
            },
            "computed_at": datetime.utcnow().isoformat(),
        }


user_dashboard_service = None


def get_user_dashboard_service(db=None):
    """Get singleton instance."""
    global user_dashboard_service
    if user_dashboard_service is None or db is not None:
        if db is None:
            from app.db.connection import get_db

            db = get_db()
        user_dashboard_service = UserDashboardService(db)
    return user_dashboard_service


print(
    "✅ User Dashboard Service Loaded — COUNTS ONLY "
    "(no application_number, no latest_applications)"
)
print(
    "✅ Job / Service / Scheme all have: "
    "total + pending + approved + rejected + "
    "payment_received + payment_pending + payment_failed + by_status"
)
print("✅ FIXED: Service double-count, Scheme 0-count, payment tracking")