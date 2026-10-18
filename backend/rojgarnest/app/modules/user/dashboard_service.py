# app/modules/user/dashboard_service.py
# ============================================================
# USER DASHBOARD STATS SERVICE
# ============================================================
# Provides:
#   - Profile Completion Percentage
#   - Career Score (AI-based)
#   - Job Applications Count
#   - Service Applications Count
# ============================================================
# ✅ FIXED: Resume section now counts GENERATED resume (not just uploads)
# ============================================================

import logging
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional

from app.db.connection import get_db
from app.core.utils.logger import logger

module_logger = logging.getLogger(__name__)


class UserDashboardService:
    """
    Service for computing user dashboard statistics.
    All calculations are done in real-time from the database.
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
        - job_applications: count of job applications
        - service_applications: count of service applications
        - Additional breakdowns
        """
        try:
            # Fetch user data in parallel
            auth_user = await self.auth.find_one({"email": email})
            profile = await self.profile.find_one({"email": email})

            if not auth_user:
                return self._empty_stats()

            # ============================================================
            # 1. PROFILE COMPLETION PERCENTAGE
            # ============================================================
            profile_completion = self._calculate_profile_completion(
                auth_user, profile
            )

            # ============================================================
            # 2. CAREER SCORE (AI-based)
            # ============================================================
            career_score = await self._calculate_career_score(
                auth_user, profile
            )

            # ============================================================
            # 3. JOB APPLICATIONS COUNT
            # ============================================================
            job_apps_count = await self.applications.count_documents({
                "user_email": email,
                "application_type": "job",
                "is_archived": {"$ne": True},
                "status": {"$nin": ["saved", "unsaved"]},
            })

            job_apps_saved = await self.applications.count_documents({
                "user_email": email,
                "application_type": "job",
                "status": "saved",
                "is_archived": {"$ne": True},
            })

            # ============================================================
            # 4. SERVICE APPLICATIONS COUNT
            # ============================================================
            service_apps_count = await self.applications.count_documents({
                "user_email": email,
                "application_type": "service",
                "is_archived": {"$ne": True},
                "is_draft": {"$ne": True},
            })

            # ============================================================
            # 5. ADDITIONAL BREAKDOWNS
            # ============================================================
            job_status_breakdown = await self._get_status_breakdown(
                email, "job"
            )
            service_status_breakdown = await self._get_status_breakdown(
                email, "service"
            )

            # ============================================================
            # 6. PROFILE SECTION BREAKDOWN
            # ============================================================
            profile_sections = self._get_profile_sections_breakdown(
                auth_user, profile
            )

            # ============================================================
            # 7. CAREER SCORE BREAKDOWN
            # ============================================================
            career_breakdown = await self._get_career_score_breakdown(
                auth_user, profile
            )

            return {
                "success": True,
                "profile_completion": profile_completion,
                "career_score": career_score,
                "job_applications": {
                    "total": job_apps_count,
                    "saved": job_apps_saved,
                    "applied": job_apps_count,
                    "by_status": job_status_breakdown,
                },
                "service_applications": {
                    "total": service_apps_count,
                    "by_status": service_status_breakdown,
                },
                "profile_sections": profile_sections,
                "career_breakdown": career_breakdown,
                "computed_at": datetime.utcnow().isoformat(),
            }

        except Exception as e:
            module_logger.error(f"Dashboard stats failed: {e}")
            return self._empty_stats()

    # ============================================================
    # HELPER: Detect if user has ANY resume (uploaded OR generated)
    # ============================================================
    def _has_resume(self, profile: Optional[Dict[str, Any]]) -> Dict[str, bool]:
        """
        ✅ NEW HELPER: Detects resume presence from MULTIPLE signals.

        Returns dict with:
          - has_uploaded: True if user uploaded a resume file
          - has_generated: True if user generated an AI resume
          - has_any: True if either is true
        """
        if not profile:
            return {
                "has_uploaded": False,
                "has_generated": False,
                "has_any": False,
            }

        additional = profile.get("additional_details") or {}

        # ---- Signal 1: Uploaded resume (legacy) ----
        resume_url = (
            profile.get("resume_url")
            or additional.get("resume_url")
        )
        has_uploaded = bool(
            resume_url and str(resume_url).startswith("http")
        )

        # ---- Signal 2: Generated resume (NEW) ----
        # Any of these indicate a resume was generated from profile data
        has_generated = bool(
            profile.get("resume_generated_at")
            or profile.get("resume_cache_html")
            or profile.get("resume_formats_available")
            or profile.get("has_generated_resume") == True
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
        """
        Calculate profile completion percentage (0-100).

        Weights:
          - Basic info (name, email, phone, dob, gender): 20%
          - Address (city, state):                        10%
          - Education (at least 1 record):                15%
          - Experience (at least 1 record OR fresher):    15%
          - Skills (at least 5 skills):                   15%
          - Resume (uploaded OR generated):               10%   ✅ FIXED
          - Profile photo:                                5%
          - Summary/Career objective:                     10%
        """
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
            # Freshers get credit if they marked themselves as fresher
            # and have internships or projects
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

        # ============================================================
        # ✅ FIXED: Resume (10%) — now counts GENERATED resume too
        # ============================================================
        resume_flags = self._has_resume(profile)
        if resume_flags["has_any"]:
            score += 10
            if resume_flags["has_generated"] and not resume_flags["has_uploaded"]:
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
    # CAREER SCORE CALCULATION (AI-based)
    # ============================================================
    async def _calculate_career_score(
        self,
        auth_user: Dict[str, Any],
        profile: Optional[Dict[str, Any]],
    ) -> int:
        """
        Calculate career score (0-100).

        Factors:
          - Skills score:           30%
          - Experience score:       25%
          - Education score:        20%
          - Profile completeness:   15%
          - Market alignment:       10%
        """
        if not profile:
            return 30

        breakdown = await self._get_career_score_breakdown(auth_user, profile)

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
        """Return breakdown of career score components."""
        if not profile:
            profile = {}

        # ---- Skill Score (0-100) ----
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
            # Bonus for having many skills
            skill_score = min(100, skill_score + (len(skills) * 2))

        # ---- Experience Score (0-100) ----
        experience = profile.get("experience") or []
        exp_years = 0
        for exp in experience:
            try:
                start = exp.get("start_date", "")
                if start:
                    exp_years += 1
            except Exception:
                pass

        # Also count internships
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
            # Freshers with projects/internships get some credit
            projects = profile.get("projects") or []
            experience_score = 35 + min(20, len(projects) * 5)
        else:
            experience_score = 30

        # ---- Education Score (0-100) ----
        academic_records = profile.get("academic_records") or []
        edu_score = 0
        if academic_records:
            # Check highest level
            levels = []
            for edu in academic_records:
                level = (edu.get("level") or "").lower()
                if "phd" in level:
                    levels.append(100)
                elif "post_graduation" in level or "post graduation" in level:
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

            # Bonus for multiple degrees
            edu_score = min(100, edu_score + (len(academic_records) - 1) * 5)
        else:
            edu_score = 10

        # ---- Completeness Score (0-100) ----
        completeness_score = self._calculate_profile_completion(
            auth_user, profile
        )

        # ---- Market Alignment Score (0-100) ----
        # Simple heuristic: how many high-demand skills user has
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
    # STATUS BREAKDOWN
    # ============================================================
    async def _get_status_breakdown(
        self, email: str, app_type: str
    ) -> Dict[str, int]:
        """Get count of applications by status."""
        pipeline = [
            {
                "$match": {
                    "user_email": email,
                    "application_type": app_type,
                    "is_archived": {"$ne": True},
                }
            },
            {"$group": {"_id": "$status", "count": {"$sum": 1}}},
        ]

        try:
            results = await self.applications.aggregate(pipeline).to_list(50)
            return {item["_id"]: item["count"] for item in results if item["_id"]}
        except Exception:
            return {}

    # ============================================================
    # ✅ FIXED: PROFILE SECTIONS BREAKDOWN (Resume OR upload)
    # ============================================================
    def _get_profile_sections_breakdown(
        self,
        auth_user: Dict[str, Any],
        profile: Optional[Dict[str, Any]],
    ) -> Dict[str, Any]:
        """
        Return a breakdown of which profile sections are complete.
        ✅ FIXED: 'resume' now true if uploaded OR generated.
        """
        if not profile:
            profile = {}

        address = profile.get("current_address") or {}
        additional = profile.get("additional_details") or {}

        # ✅ Use the same helper — single source of truth
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
            # ✅ FIXED: Resume counts if uploaded OR generated
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
    # EMPTY STATS
    # ============================================================
    def _empty_stats(self) -> Dict[str, Any]:
        return {
            "success": False,
            "profile_completion": 0,
            "career_score": 0,
            "job_applications": {
                "total": 0,
                "saved": 0,
                "applied": 0,
                "by_status": {},
            },
            "service_applications": {
                "total": 0,
                "by_status": {},
            },
            "profile_sections": {},
            "career_breakdown": {},
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


print("✅ User Dashboard Service Loaded — Resume (upload OR generate) counts 10%")