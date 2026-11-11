# app/modules/user/service.py - COMPLETE FIXED VERSION (No KeyError)

from fastapi import HTTPException
from typing import List, Dict, Any, Optional
from datetime import datetime
from bson import ObjectId
from app.core.config.settings import settings
import logging

from app.models.profile_model import (
    ProfileModel, AcademicRecord, Experience, AdditionalDetails,
    Skill, Certification, Project, Internship, Extracurricular, Language,
    BankDetails, GovernmentIDs, EmergencyContact, Reference, References,
    EmploymentPreferences, SocialLinks, WorkAuthorization, ApplicationPreferences,
    Address, DisabilityInfo, Documents, CareerCache, SessionInfo
)
from app.models.application_model import Application
from app.modules.user.AI import AICareerAnalyzer, AIJobMatcher, AISkillAnalyzer

logger = logging.getLogger(__name__)


class ProfileService:
    def __init__(self, db):
        self.profiles = db.profile
        self.applications = db.applications
        self.auth = db.auth
        self.ai_analyzer = AICareerAnalyzer()
        self.ai_matcher = AIJobMatcher()
        self.ai_skill_analyzer = AISkillAnalyzer()
        self.ai_cache = {}

    # ====================== AI METHODS ======================
    async def get_ai_insights(self, email: str) -> Dict:
        cache_key = f"ai_insights_{email}"
        if cache_key in self.ai_cache:
            cached_time, data = self.ai_cache[cache_key]
            if (datetime.utcnow() - cached_time).seconds < 300:
                return data
        
        profile = await self.get_full_profile(email)
        insights = await self.ai_analyzer.analyze_user_profile(profile)
        self.ai_cache[cache_key] = (datetime.utcnow(), insights)
        return insights
    
    async def get_ai_recommendations(self, email: str, limit: int = 10) -> List:
        profile = await self.get_full_profile(email)
        return await self.ai_matcher.get_recommendations(profile, limit)
    
    async def get_ai_skill_gap(self, email: str) -> Dict:
        profile = await self.get_full_profile(email)
        jobs = await self.get_relevant_jobs(email)
        return await self.ai_skill_analyzer.analyze_skill_gaps(profile, jobs)
    
    async def refresh_ai_insights(self, email: str) -> Dict:
        cache_key = f"ai_insights_{email}"
        if cache_key in self.ai_cache:
            del self.ai_cache[cache_key]
        profile = await self.get_full_profile(email)
        insights = await self.ai_analyzer.analyze_user_profile(profile)
        return {"message": "AI insights refreshed successfully", "data": insights}
    
    async def get_relevant_jobs(self, email: str, limit: int = 20) -> List:
        from app.db.connection import get_db
        db = get_db()
        profile = await self.profiles.find_one({"email": email})
        
        if not profile:
            return []
        
        user_skills = [s.get('name', '').lower() for s in profile.get('skills', [])]
        
        if user_skills:
            jobs = await db.job.find({
                "status": "open",
                "required_skills.name": {"$in": user_skills}
            }).limit(limit).to_list(limit)
        else:
            jobs = await db.job.find({"status": "open"}).limit(limit).to_list(limit)
        
        return jobs

    # ====================== SERIALIZER ======================
    def _serialize(self, doc: dict) -> dict:
        if doc and "_id" in doc:
            doc["_id"] = str(doc["_id"])
        return doc

    def _deserialize_id(self, doc: dict) -> dict:
        if doc and "_id" in doc and isinstance(doc["_id"], str):
            doc["_id"] = ObjectId(doc["_id"])
        return doc

    # ====================== FULL PROFILE ======================
    async def get_full_profile(self, email: str) -> Dict[str, Any]:
        """Get complete user profile with all fields"""
        profile = await self.profiles.find_one({"email": email})
        
        if not profile:
            return self._get_empty_profile(email)
        
        # Ensure all nested fields exist with defaults
        profile = self._ensure_defaults(profile)
        
        return self._serialize(profile)

    def _get_empty_profile(self, email: str) -> Dict[str, Any]:
        """Return empty profile structure with all defaults"""
        return {
            "full_name": "", "first_name": "", "middle_name": "", "last_name": "",
            "email": email, "phone": "", "dob": "", "gender": "Male",
            "blood_group": "", "nationality": "Indian", "religion": "",
            "category": "General/UR", "birth_place": "", "hobbies": [], "interests": [],
            "height_cm": None, "weight_kg": None,
            # Disability is now ONLY nested object - no top-level fields
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
            "emergency_contact": {"name": "", "relationship": "", "phone": "", "alternate_phone": "", "email": "", "address": ""},
            "current_address": {"house_number": "", "village_name": "", "post_office": "", "tehsil": "", "district": "", "state": "", "pincode": "", "landmark": "", "country": "India"},
            "permanent_address": {}, "same_as_current": True,
            "government_ids": {"aadhar_number": "", "aadhar_verified": False, "pan_number": "", "pan_verified": False, "voter_id": "", "driving_license": "", "passport_number": ""},
            "bank_details": {"account_holder_name": "", "account_number": "", "ifsc_code": "", "bank_name": "", "branch_name": "", "upi_id": "", "is_verified": False},
            "social_links": {"linkedin": "", "github": "", "portfolio": "", "twitter": "", "facebook": "", "instagram": "", "youtube": "", "personal_website": ""},
            "work_authorization": {"is_indian_citizen": True, "has_work_permit": False, "work_permit_country": "", "visa_type": "", "visa_valid_until": "", "passport_number": ""},
            "employment_preferences": {"preferred_work_modes": ["Full-time"], "preferred_shifts": ["Day"], "preferred_work_location": "Any", "notice_period_days": None, "can_join_immediately": False, "expected_salary_min": None, "expected_salary_max": None, "is_salary_negotiable": True, "preferred_industries": [], "preferred_job_roles": [], "preferred_locations": [], "open_to_relocate": False, "open_to_travel": False, "travel_percentage": None},
            "application_preferences": {"email_notifications": True, "sms_notifications": False, "whatsapp_notifications": False, "auto_apply_matches": False, "min_match_percentage": 70, "saved_searches": []},
            "references": {"references": []},
            "summary": "", "career_objective": "", "languages_known": [],
            "academic_records": [], "experience": [], "internships": [], "skills": [],
            "certifications": [], "projects": [], "extracurricular": [], "languages": [],
            "currently_employed": False, "current_company": "", "current_designation": "",
            "current_salary": None, "total_experience_years": 0,
            "is_educated": True, "is_pursuing_education": False,
            "career_goals": [], "domain_interests": [],
            "current_status": "student",
            "is_fresher": True, "internship_details": "", "training_program": "",
            "daily_wage": None, "projects_done": "", "certifications_list": [], "labour_type": "Mason",
            "can_read": False, "can_write": False, "basic_education_level": "None", "basic_skills": [],
            "additional_details": {},
            "role": "user", "created_at": datetime.utcnow(), "updated_at": datetime.utcnow()
        }

    def _ensure_defaults(self, profile: Dict) -> Dict:
        """Ensure all nested fields exist with defaults - FIXED for missing keys"""
        
        # ==================== DISABILITY - CRITICAL FIX ====================
        # Ensure disability object exists (ONLY nested, no top-level)
        if "disability" not in profile or not isinstance(profile["disability"], dict):
            profile["disability"] = {
                "is_disabled": False,
                "disability_category": "LD (Learning Disability)",
                "disability_percentage": None,
                "disability_details": "",
                "physically_challenged": "No",
                "certificate_verified": False
            }
        
        # ⚠️ IMPORTANT: Remove any top-level disability fields that might exist
        top_level_disability_fields = ["is_disable", "disability_category", "disability_percentage", 
                                       "physically_challenged", "disability_details"]
        for field in top_level_disability_fields:
            if field in profile:
                del profile[field]
        
        # Also copy any missing fields from disability to top-level (for backward compatibility only)
        # This is for older code that might still expect top-level fields
        disability = profile["disability"]
        if isinstance(disability, dict):
            profile["is_disable"] = disability.get("is_disabled", False)
            profile["disability_category"] = disability.get("disability_category", "LD (Learning Disability)")
            profile["disability_percentage"] = disability.get("disability_percentage")
            profile["physically_challenged"] = disability.get("physically_challenged", "No")
            profile["disability_details"] = disability.get("disability_details", "")

        # Government IDs - Use setdefault to avoid KeyError
        if "government_ids" not in profile:
            profile["government_ids"] = {}
        elif not isinstance(profile["government_ids"], dict):
            profile["government_ids"] = {}
        
        gov_defaults = {"aadhar_number": "", "aadhar_verified": False, "pan_number": "", "pan_verified": False, "voter_id": "", "driving_license": "", "passport_number": ""}
        for key, val in gov_defaults.items():
            if key not in profile["government_ids"]:
                profile["government_ids"][key] = val

        # Bank Details
        if "bank_details" not in profile:
            profile["bank_details"] = {}
        elif not isinstance(profile["bank_details"], dict):
            profile["bank_details"] = {}
        
        bank_defaults = {"account_holder_name": "", "account_number": "", "ifsc_code": "", "bank_name": "", "branch_name": "", "upi_id": "", "is_verified": False}
        for key, val in bank_defaults.items():
            if key not in profile["bank_details"]:
                profile["bank_details"][key] = val

        # Emergency Contact
        if "emergency_contact" not in profile:
            profile["emergency_contact"] = {}
        elif not isinstance(profile["emergency_contact"], dict):
            profile["emergency_contact"] = {}
        
        ec_defaults = {"name": "", "relationship": "", "phone": "", "alternate_phone": "", "email": "", "address": ""}
        for key, val in ec_defaults.items():
            if key not in profile["emergency_contact"]:
                profile["emergency_contact"][key] = val

        # Social Links
        if "social_links" not in profile:
            profile["social_links"] = {}
        elif not isinstance(profile["social_links"], dict):
            profile["social_links"] = {}
        
        social_defaults = {"linkedin": "", "github": "", "portfolio": "", "twitter": "", "facebook": "", "instagram": "", "youtube": "", "personal_website": ""}
        for key, val in social_defaults.items():
            if key not in profile["social_links"]:
                profile["social_links"][key] = val

        # Employment Preferences
        if "employment_preferences" not in profile:
            profile["employment_preferences"] = {}
        elif not isinstance(profile["employment_preferences"], dict):
            profile["employment_preferences"] = {}
        
        emp_defaults = {"preferred_work_modes": ["Full-time"], "preferred_shifts": ["Day"], "preferred_work_location": "Any", "notice_period_days": None, "can_join_immediately": False, "expected_salary_min": None, "expected_salary_max": None, "is_salary_negotiable": True, "preferred_industries": [], "preferred_job_roles": [], "preferred_locations": [], "open_to_relocate": False, "open_to_travel": False, "travel_percentage": None}
        for key, val in emp_defaults.items():
            if key not in profile["employment_preferences"]:
                profile["employment_preferences"][key] = val

        # Work Authorization
        if "work_authorization" not in profile:
            profile["work_authorization"] = {}
        elif not isinstance(profile["work_authorization"], dict):
            profile["work_authorization"] = {}
        
        work_defaults = {"is_indian_citizen": True, "has_work_permit": False, "work_permit_country": "", "visa_type": "", "visa_valid_until": "", "passport_number": ""}
        for key, val in work_defaults.items():
            if key not in profile["work_authorization"]:
                profile["work_authorization"][key] = val

        # Application Preferences
        if "application_preferences" not in profile:
            profile["application_preferences"] = {}
        elif not isinstance(profile["application_preferences"], dict):
            profile["application_preferences"] = {}
        
        app_defaults = {"email_notifications": True, "sms_notifications": False, "whatsapp_notifications": False, "auto_apply_matches": False, "min_match_percentage": 70, "saved_searches": []}
        for key, val in app_defaults.items():
            if key not in profile["application_preferences"]:
                profile["application_preferences"][key] = val

        # References
        if "references" not in profile:
            profile["references"] = {"references": []}
        elif not isinstance(profile["references"], dict):
            profile["references"] = {"references": []}
        elif "references" not in profile["references"]:
            profile["references"]["references"] = []

        # Category
        if "category" not in profile:
            profile["category"] = "General/UR"

        # Additional Details
        if "additional_details" not in profile:
            profile["additional_details"] = {}
        elif not isinstance(profile["additional_details"], dict):
            profile["additional_details"] = {}

        # Current Address
        if "current_address" not in profile:
            profile["current_address"] = {}
        elif not isinstance(profile["current_address"], dict):
            profile["current_address"] = {}
        
        address_defaults = {"house_number": "", "village_name": "", "post_office": "", "tehsil": "", "district": "", "state": "", "pincode": "", "landmark": "", "country": "India"}
        for key, val in address_defaults.items():
            if key not in profile["current_address"]:
                profile["current_address"][key] = val

        # Permanent Address
        if "permanent_address" not in profile:
            profile["permanent_address"] = {}
        elif not isinstance(profile["permanent_address"], dict):
            profile["permanent_address"] = {}

        # Address field (backward compatibility)
        if "address" not in profile:
            profile["address"] = {}

        return profile

    # ==================== CREATE OR UPDATE FULL PROFILE ====================
    
    async def create_or_update_full_profile(self, data: Dict[str, Any]) -> dict:
        """Create or update full profile with all fields"""
        email = data.get("email")
        if not email:
            raise HTTPException(status_code=400, detail="Email is required")
        
        # First ensure profile exists
        existing = await self.profiles.find_one({"email": email})
        
        # If no existing profile, create one first
        if not existing:
            empty_profile = self._get_empty_profile(email)
            await self.profiles.insert_one(empty_profile)
            existing = empty_profile
        
        # ==================== CRITICAL FIX: HANDLE DISABILITY ====================
        # The frontend sends disability fields as top-level fields
        # We need to map them to a 'disability' object
        disability_data = {}
        
        # Check for disability fields at top level
        if "is_disable" in data:
            disability_data["is_disabled"] = data["is_disable"]
        if "disability_category" in data:
            disability_data["disability_category"] = data["disability_category"]
        if "disability_percentage" in data:
            disability_data["disability_percentage"] = data["disability_percentage"]
        if "disability_details" in data:
            disability_data["disability_details"] = data["disability_details"]
        if "physically_challenged" in data:
            disability_data["physically_challenged"] = data["physically_challenged"]
        
        # Also check if disability object was sent directly
        if "disability" in data and isinstance(data["disability"], dict):
            for key, value in data["disability"].items():
                if value is not None:
                    disability_data[key] = value
        
        # Build update_data with proper nested structure
        update_data = {}
        
        # Process all simple fields (non-nested)
        simple_fields = [
            'full_name', 'first_name', 'middle_name', 'last_name', 'gender', 'dob',
            'blood_group', 'nationality', 'religion', 'category', 'father_name',
            'mother_name', 'guardian_name', 'spouse_name', 'marital_status',
            'alternate_mobile', 'whatsapp_number', 'summary', 'career_objective',
            'linkedin_url', 'github_url', 'portfolio_url', 'preferred_location',
            'open_to_relocate', 'open_to_remote_work', 'same_as_current',
            'height', 'weight', 'is_educated', 'can_read', 'can_write',
            'basic_education_level', 'is_fresher', 'internship_details',
            'training_program', 'daily_wage', 'projects_done', 'labour_type',
            'currently_employed', 'current_company', 'current_designation',
            'current_salary', 'total_experience_years', 'is_pursuing_education',
            'expected_graduation_year', 'gap_in_education', 'gap_reason',
            'career_change_interest', 'reason_for_career_change',
            'actively_looking_for_job', 'notice_period_days', 'can_join_immediately',
            'preferred_joining_date', 'available_for_full_time', 'available_for_part_time',
            'available_for_contract', 'available_for_freelance', 'available_for_internship'
        ]
        
        for field in simple_fields:
            if field in data and data[field] is not None:
                update_data[field] = data[field]
        
        # ==================== HANDLE DISABILITY OBJECT ====================
        if disability_data:
            # Create or update the disability object
            update_data["disability"] = disability_data
            
            # Also keep top-level fields for backward compatibility (but these will be removed on next read)
            if "is_disabled" in disability_data:
                update_data["is_disable"] = disability_data["is_disabled"]
            if "disability_category" in disability_data:
                update_data["disability_category"] = disability_data["disability_category"]
            if "disability_percentage" in disability_data:
                update_data["disability_percentage"] = disability_data["disability_percentage"]
            if "disability_details" in disability_data:
                update_data["disability_details"] = disability_data["disability_details"]
        
        # Handle family_annual_income and number_of_dependents
        if "family_annual_income" in data and data["family_annual_income"] is not None:
            update_data["family_annual_income"] = data["family_annual_income"]
        if "number_of_dependents" in data and data["number_of_dependents"] is not None:
            update_data["number_of_dependents"] = data["number_of_dependents"]
        
        # Handle arrays/lists
        array_fields = ['preferred_job_types', 'preferred_industries', 'languages_known',
                        'previous_career_fields', 'transferable_skills', 'target_career_fields']
        
        for field in array_fields:
            if field in data and data[field] is not None:
                if isinstance(data[field], list):
                    update_data[field] = data[field]
        
        # Handle nested objects
        nested_objects = {
            'government_ids': 'government_ids',
            'bank_details': 'bank_details',
            'social_links': 'social_links',
            'employment_preferences': 'employment_preferences',
            'work_authorization': 'work_authorization',
            'application_preferences': 'application_preferences',
            'current_address': 'current_address',
            'permanent_address': 'permanent_address',
            'additional_details': 'additional_details',
            'career_goals': 'career_goals',
            'personality_traits': 'personality_traits',
            'work_environment_preferences': 'work_environment_preferences',
            'compensation_expectations': 'compensation_expectations',
            'job_search_preferences': 'job_search_preferences'
        }
        
        for field, db_field in nested_objects.items():
            if field in data and isinstance(data[field], dict):
                for sub_key, sub_value in data[field].items():
                    if sub_value is not None:
                        update_data[f"{db_field}.{sub_key}"] = sub_value
        
        # Handle emergency_contact specially
        if "emergency_contact" in data and isinstance(data["emergency_contact"], dict):
            for ek, ev in data["emergency_contact"].items():
                if ev is not None:
                    update_data[f"emergency_contact.{ek}"] = ev
        elif "emergency_contact" in data and isinstance(data["emergency_contact"], str):
            update_data["emergency_contact.phone"] = data["emergency_contact"]
        if "emergency_contact_name" in data and data["emergency_contact_name"] is not None:
            update_data["emergency_contact.name"] = data["emergency_contact_name"]
        if "emergency_contact_relation" in data and data["emergency_contact_relation"] is not None:
            update_data["emergency_contact.relationship"] = data["emergency_contact_relation"]
        
        # Handle arrays within nested objects
        if "academic_records" in data and isinstance(data["academic_records"], list):
            update_data["academic_records"] = data["academic_records"]
        if "experience" in data and isinstance(data["experience"], list):
            update_data["experience"] = data["experience"]
        if "internships" in data and isinstance(data["internships"], list):
            update_data["internships"] = data["internships"]
        if "skills" in data and isinstance(data["skills"], list):
            update_data["skills"] = data["skills"]
        if "certifications" in data and isinstance(data["certifications"], list):
            update_data["certifications"] = data["certifications"]
        if "projects" in data and isinstance(data["projects"], list):
            update_data["projects"] = data["projects"]
        if "languages" in data and isinstance(data["languages"], list):
            update_data["languages"] = data["languages"]
        
        # Handle references
        if "references" in data and isinstance(data["references"], dict):
            if "references" in data["references"]:
                update_data["references.references"] = data["references"]["references"]
        
        # Remove None values
        update_data = {k: v for k, v in update_data.items() if v is not None}
        update_data["updated_at"] = datetime.utcnow()
        
        if update_data:
            try:
                await self.profiles.update_one(
                    {"email": email},
                    {"$set": update_data}
                )
                logger.info(f"✅ Updated profile for {email}: {len(update_data)} fields modified")
            except Exception as e:
                logger.error(f"Error updating profile for {email}: {e}")
                # Fallback: Update without nested dot notation
                fallback_data = {}
                for k, v in update_data.items():
                    if '.' not in k:
                        fallback_data[k] = v
                fallback_data["updated_at"] = datetime.utcnow()
                if fallback_data:
                    await self.profiles.update_one(
                        {"email": email},
                        {"$set": fallback_data}
                    )
                    logger.info(f"✅ Fallback update for {email} completed")
        else:
            # Still update the timestamp
            await self.profiles.update_one(
                {"email": email},
                {"$set": {"updated_at": datetime.utcnow()}}
            )
        
        # Clear AI cache
        cache_key = f"ai_insights_{email}"
        if cache_key in self.ai_cache:
            del self.ai_cache[cache_key]
        
        return {"message": "Profile saved successfully", "email": email}

    # ====================== GET PHONE NUMBER FROM AUTH ======================
    
    async def get_phone_from_auth(self, email: str) -> Optional[str]:
        """Get phone number from auth collection"""
        user = await self.auth.find_one({"email": email})
        if user:
            return user.get("mobile")
        return None
    
    async def sync_phone_to_profile(self, email: str) -> bool:
        """Sync phone number from auth to profile"""
        phone = await self.get_phone_from_auth(email)
        if phone:
            result = await self.profiles.update_one(
                {"email": email},
                {"$set": {"phone": phone}}
            )
            return result.modified_count > 0
        return False

    # ====================== GET FULL PROFILE WITH PHONE ======================
    
    async def get_full_profile_with_phone(self, email: str) -> Dict[str, Any]:
        """Get full profile with phone number synced from auth"""
        # First sync phone from auth to profile
        await self.sync_phone_to_profile(email)
        
        # Then get full profile
        return await self.get_full_profile(email)

    # ====================== BANK DETAILS ======================
    async def get_bank_details(self, email: str) -> Dict[str, Any]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return {}
        return profile.get("bank_details", {})

    async def update_bank_details(self, email: str, data: Dict[str, Any]) -> dict:
        update_data = {}
        for key, value in data.items():
            if value is not None:
                update_data[f"bank_details.{key}"] = value
        update_data["updated_at"] = datetime.utcnow()
        
        await self.profiles.update_one(
            {"email": email},
            {"$set": update_data},
            upsert=True
        )
        return {"message": "Bank details updated successfully", "email": email}

    # ====================== GOVERNMENT IDs ======================
    async def get_government_ids(self, email: str) -> Dict[str, Any]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return {}
        return profile.get("government_ids", {})

    async def update_government_ids(self, email: str, data: Dict[str, Any]) -> dict:
        update_data = {}
        for key, value in data.items():
            if value is not None:
                update_data[f"government_ids.{key}"] = value
        update_data["updated_at"] = datetime.utcnow()
        
        await self.profiles.update_one(
            {"email": email},
            {"$set": update_data},
            upsert=True
        )
        return {"message": "Government IDs updated successfully", "email": email}

    # ====================== EMERGENCY CONTACT ======================
    async def get_emergency_contact(self, email: str) -> Dict[str, Any]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return {}
        return profile.get("emergency_contact", {})

    async def update_emergency_contact(self, email: str, data: Dict[str, Any]) -> dict:
        update_data = {}
        for key, value in data.items():
            if value is not None:
                update_data[f"emergency_contact.{key}"] = value
        update_data["updated_at"] = datetime.utcnow()
        
        await self.profiles.update_one(
            {"email": email},
            {"$set": update_data},
            upsert=True
        )
        return {"message": "Emergency contact updated successfully", "email": email}

    # ====================== REFERENCES ======================
    async def get_references(self, email: str) -> List[Dict[str, Any]]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return []
        return profile.get("references", {}).get("references", [])

    async def add_reference(self, email: str, reference: Dict[str, Any]) -> dict:
        reference["_id"] = str(ObjectId())
        await self.profiles.update_one(
            {"email": email},
            {"$push": {"references.references": reference}, "$set": {"updated_at": datetime.utcnow()}},
            upsert=True
        )
        return {"message": "Reference added successfully", "data": reference}

    async def update_reference(self, email: str, ref_id: str, reference: Dict[str, Any]) -> dict:
        reference["_id"] = ref_id
        result = await self.profiles.update_one(
            {"email": email, "references.references._id": ref_id},
            {"$set": {"references.references.$": reference, "updated_at": datetime.utcnow()}}
        )
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="Reference not found")
        return {"message": "Reference updated successfully"}

    async def delete_reference(self, email: str, ref_id: str) -> dict:
        result = await self.profiles.update_one(
            {"email": email},
            {"$pull": {"references.references": {"_id": ref_id}}, "$set": {"updated_at": datetime.utcnow()}}
        )
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Reference not found")
        return {"message": "Reference deleted successfully"}

    # ====================== EMPLOYMENT PREFERENCES ======================
    async def get_employment_preferences(self, email: str) -> Dict[str, Any]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return {}
        return profile.get("employment_preferences", {})

    async def update_employment_preferences(self, email: str, data: Dict[str, Any]) -> dict:
        update_data = {}
        for key, value in data.items():
            if value is not None:
                update_data[f"employment_preferences.{key}"] = value
        update_data["updated_at"] = datetime.utcnow()
        
        await self.profiles.update_one(
            {"email": email},
            {"$set": update_data},
            upsert=True
        )
        return {"message": "Employment preferences updated successfully", "email": email}

    # ====================== SOCIAL LINKS ======================
    async def get_social_links(self, email: str) -> Dict[str, Any]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return {}
        return profile.get("social_links", {})

    async def update_social_links(self, email: str, data: Dict[str, Any]) -> dict:
        update_data = {}
        for key, value in data.items():
            if value is not None:
                update_data[f"social_links.{key}"] = value
        update_data["updated_at"] = datetime.utcnow()
        
        await self.profiles.update_one(
            {"email": email},
            {"$set": update_data},
            upsert=True
        )
        return {"message": "Social links updated successfully", "email": email}

    # ====================== WORK AUTHORIZATION ======================
    async def get_work_authorization(self, email: str) -> Dict[str, Any]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return {}
        return profile.get("work_authorization", {})

    async def update_work_authorization(self, email: str, data: Dict[str, Any]) -> dict:
        update_data = {}
        for key, value in data.items():
            if value is not None:
                update_data[f"work_authorization.{key}"] = value
        update_data["updated_at"] = datetime.utcnow()
        
        await self.profiles.update_one(
            {"email": email},
            {"$set": update_data},
            upsert=True
        )
        return {"message": "Work authorization updated successfully", "email": email}

    # ====================== APPLICATION PREFERENCES ======================
    async def get_application_preferences(self, email: str) -> Dict[str, Any]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return {}
        return profile.get("application_preferences", {})

    async def update_application_preferences(self, email: str, data: Dict[str, Any]) -> dict:
        update_data = {}
        for key, value in data.items():
            if value is not None:
                update_data[f"application_preferences.{key}"] = value
        update_data["updated_at"] = datetime.utcnow()
        
        await self.profiles.update_one(
            {"email": email},
            {"$set": update_data},
            upsert=True
        )
        return {"message": "Application preferences updated successfully", "email": email}

    # ====================== BASIC DETAILS ======================
    async def get_basic_details(self, email: str) -> Dict[str, Any]:
        profile = await self.get_full_profile(email)
        return {
            "full_name": profile.get("full_name", ""),
            "first_name": profile.get("first_name", ""),
            "middle_name": profile.get("middle_name", ""),
            "last_name": profile.get("last_name", ""),
            "email": profile.get("email", email),
            "phone": profile.get("phone", ""),
            "dob": profile.get("dob", ""),
            "gender": profile.get("gender", "Male"),
            "category": profile.get("category", "General/UR"),
            # Disability from nested object
            "is_disable": profile.get("is_disable", False),
            "disability_category": profile.get("disability_category", "LD (Learning Disability)"),
            "disability_percentage": profile.get("disability_percentage"),
            "physically_challenged": profile.get("physically_challenged", "No"),
            "disability_details": profile.get("disability_details", ""),
            "father_name": profile.get("father_name", ""),
            "mother_name": profile.get("mother_name", ""),
            "address": profile.get("current_address", {})
        }

    async def save_basic_details(self, email: str, data: Dict[str, Any]) -> dict:
        return await self.create_or_update_full_profile({"email": email, **data})

    # ====================== EDUCATION ======================
    async def get_education(self, email: str) -> List[dict]:
        profile = await self.profiles.find_one({"email": email})
        return profile.get("academic_records", []) if profile else []

    async def add_education(self, email: str, qualification: Dict[str, Any]) -> dict:
        if not qualification:
            raise HTTPException(status_code=400, detail="Qualification data required")
        
        qualification_dict = qualification.copy()
        qualification_dict["_id"] = str(ObjectId())
        
        result = await self.profiles.update_one(
            {"email": email},
            {"$push": {"academic_records": qualification_dict}},
            upsert=True
        )
        
        if result.matched_count == 0 and result.upserted_id is None:
            await self.profiles.insert_one({
                "email": email,
                "academic_records": [qualification_dict],
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            })
        
        cache_key = f"ai_insights_{email}"
        if cache_key in self.ai_cache:
            del self.ai_cache[cache_key]
        
        return {"message": "Education added successfully", "data": qualification_dict}

    async def update_education(self, email: str, qual_id: str, qualification: Dict[str, Any]) -> dict:
        if not qualification:
            raise HTTPException(status_code=400, detail="Qualification data required")
        
        qualification_dict = qualification.copy()
        qualification_dict["_id"] = qual_id
        
        result = await self.profiles.update_one(
            {"email": email, "academic_records._id": qual_id},
            {"$set": {"academic_records.$": qualification_dict}}
        )
        
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="Qualification not found")
        
        cache_key = f"ai_insights_{email}"
        if cache_key in self.ai_cache:
            del self.ai_cache[cache_key]
        
        return {"message": "Education updated successfully"}


        # ====================== DELETE EDUCATION ======================
    async def delete_education(self, email: str, qual_id: str) -> dict:
        """
        Delete an education record by its `_id`.
        Frontend sends DELETE /user/education/{qual_id}?email=...
        Response format matches what user_service.dart expects:
            { "success": true, "message": "...", "deleted_id": "..." }
        """
        result = await self.profiles.update_one(
            {"email": email},
            {
                "$pull": {"academic_records": {"_id": qual_id}},
                "$set": {"updated_at": datetime.utcnow()}
            }
        )

        if result.modified_count == 0:
            # Try legacy `id` field too
            result = await self.profiles.update_one(
                {"email": email},
                {
                    "$pull": {"academic_records": {"id": qual_id}},
                    "$set": {"updated_at": datetime.utcnow()}
                }
            )
            if result.modified_count == 0:
                raise HTTPException(status_code=404, detail="Education record not found")

        # Clear AI cache so next analysis reflects the change
        cache_key = f"ai_insights_{email}"
        if cache_key in self.ai_cache:
            del self.ai_cache[cache_key]

        logger.info(f"🗑️ Deleted education {qual_id} for {email}")
        return {
            "success": True,
            "message": "Education deleted successfully",
            "deleted_id": qual_id
        }


    # ====================== EXPERIENCE ======================
    async def get_experience(self, email: str) -> List[dict]:
        profile = await self.profiles.find_one({"email": email})
        return profile.get("experience", []) if profile else []

    async def add_experience(self, email: str, experience: Dict[str, Any]) -> dict:
        if not experience:
            raise HTTPException(status_code=400, detail="Experience data required")
        
        exp_dict = experience.copy()
        exp_dict["_id"] = str(ObjectId())
        
        await self.profiles.update_one(
            {"email": email},
            {"$push": {"experience": exp_dict}},
            upsert=True
        )
        
        cache_key = f"ai_insights_{email}"
        if cache_key in self.ai_cache:
            del self.ai_cache[cache_key]
        
        return {"message": "Experience added successfully", "data": exp_dict}

    async def update_experience(self, email: str, exp_id: str, experience: Dict[str, Any]) -> dict:
        if not experience:
            raise HTTPException(status_code=400, detail="Experience data required")
        
        exp_dict = experience.copy()
        exp_dict["_id"] = exp_id
        
        result = await self.profiles.update_one(
            {"email": email, "experience._id": exp_id},
            {"$set": {"experience.$": exp_dict}}
        )
        
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="Experience not found")
        
        cache_key = f"ai_insights_{email}"
        if cache_key in self.ai_cache:
            del self.ai_cache[cache_key]
        
        return {"message": "Experience updated successfully"}


            # ====================== DELETE EXPERIENCE ======================
    async def delete_experience(self, email: str, exp_id: str) -> dict:
        """
        Delete an experience record by its `_id`.
        Frontend sends DELETE /user/experience/{exp_id}?email=...
        Response format matches user_service.dart:
            { "success": true, "message": "...", "deleted_id": "..." }
        """
        result = await self.profiles.update_one(
            {"email": email},
            {
                "$pull": {"experience": {"_id": exp_id}},
                "$set": {"updated_at": datetime.utcnow()}
            }
        )

        if result.modified_count == 0:
            # Try legacy `id` field
            result = await self.profiles.update_one(
                {"email": email},
                {
                    "$pull": {"experience": {"id": exp_id}},
                    "$set": {"updated_at": datetime.utcnow()}
                }
            )
            if result.modified_count == 0:
                raise HTTPException(status_code=404, detail="Experience record not found")

        cache_key = f"ai_insights_{email}"
        if cache_key in self.ai_cache:
            del self.ai_cache[cache_key]

        logger.info(f"🗑️ Deleted experience {exp_id} for {email}")
        return {
            "success": True,
            "message": "Experience deleted successfully",
            "deleted_id": exp_id
        }

    # ====================== SKILLS (Full CRUD) ======================
    async def get_skills(self, email: str) -> List[dict]:
        profile = await self.profiles.find_one({"email": email})
        return profile.get("skills", []) if profile else []

    async def add_skill(self, email: str, skill: Dict[str, Any]) -> dict:
        if not skill:
            raise HTTPException(status_code=400, detail="Skill data required")
        
        skill_dict = skill.copy()
        skill_dict["_id"] = str(ObjectId())
        
        await self.profiles.update_one(
            {"email": email},
            {"$push": {"skills": skill_dict}},
            upsert=True
        )
        
        cache_key = f"ai_insights_{email}"
        if cache_key in self.ai_cache:
            del self.ai_cache[cache_key]
        
        return {"message": "Skill added successfully", "data": skill_dict}

    async def update_skill(self, email: str, skill_id: str, skill: Dict[str, Any]) -> dict:
        if not skill:
            raise HTTPException(status_code=400, detail="Skill data required")
        
        skill_dict = skill.copy()
        skill_dict["_id"] = skill_id
        
        result = await self.profiles.update_one(
            {"email": email, "skills._id": skill_id},
            {"$set": {"skills.$": skill_dict}}
        )
        
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="Skill not found")
        
        cache_key = f"ai_insights_{email}"
        if cache_key in self.ai_cache:
            del self.ai_cache[cache_key]
        
        return {"message": "Skill updated successfully"}

    async def delete_skill(self, email: str, skill_id: str) -> dict:
        result = await self.profiles.update_one(
            {"email": email},
            {"$pull": {"skills": {"_id": skill_id}}}
        )
        
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Skill not found")
        
        cache_key = f"ai_insights_{email}"
        if cache_key in self.ai_cache:
            del self.ai_cache[cache_key]
        
        return {"message": "Skill deleted successfully"}

    # ====================== INTERNSHIPS ======================
    async def get_internships(self, email: str) -> List[dict]:
        profile = await self.profiles.find_one({"email": email})
        return profile.get("internships", []) if profile else []

    async def add_internship(self, email: str, internship: Dict[str, Any]) -> dict:
        if not internship:
            raise HTTPException(status_code=400, detail="Internship data required")
        
        internship_dict = internship.copy()
        internship_dict["_id"] = str(ObjectId())
        
        await self.profiles.update_one(
            {"email": email},
            {"$push": {"internships": internship_dict}},
            upsert=True
        )
        
        return {"message": "Internship added successfully", "data": internship_dict}

    async def update_internship(self, email: str, internship_id: str, internship: Dict[str, Any]) -> dict:
        if not internship:
            raise HTTPException(status_code=400, detail="Internship data required")
        
        internship_dict = internship.copy()
        internship_dict["_id"] = internship_id
        
        result = await self.profiles.update_one(
            {"email": email, "internships._id": internship_id},
            {"$set": {"internships.$": internship_dict}}
        )
        
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="Internship not found")
        
        return {"message": "Internship updated successfully"}

    async def delete_internship(self, email: str, internship_id: str) -> dict:
        result = await self.profiles.update_one(
            {"email": email},
            {"$pull": {"internships": {"_id": internship_id}}}
        )
        
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Internship not found")
        
        return {"message": "Internship deleted successfully"}

    # ====================== CERTIFICATIONS ======================
    async def get_certifications(self, email: str) -> List[dict]:
        profile = await self.profiles.find_one({"email": email})
        return profile.get("certifications", []) if profile else []

    async def add_certification(self, email: str, certification: Dict[str, Any]) -> dict:
        if not certification:
            raise HTTPException(status_code=400, detail="Certification data required")
        
        cert_dict = certification.copy()
        cert_dict["_id"] = str(ObjectId())
        
        await self.profiles.update_one(
            {"email": email},
            {"$push": {"certifications": cert_dict}},
            upsert=True
        )
        
        return {"message": "Certification added successfully", "data": cert_dict}

    async def update_certification(self, email: str, cert_id: str, certification: Dict[str, Any]) -> dict:
        if not certification:
            raise HTTPException(status_code=400, detail="Certification data required")
        
        cert_dict = certification.copy()
        cert_dict["_id"] = cert_id
        
        result = await self.profiles.update_one(
            {"email": email, "certifications._id": cert_id},
            {"$set": {"certifications.$": cert_dict}}
        )
        
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="Certification not found")
        
        return {"message": "Certification updated successfully"}

    async def delete_certification(self, email: str, cert_id: str) -> dict:
        result = await self.profiles.update_one(
            {"email": email},
            {"$pull": {"certifications": {"_id": cert_id}}}
        )
        
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Certification not found")
        
        return {"message": "Certification deleted successfully"}

    # ====================== PROJECTS ======================
    async def get_projects(self, email: str) -> List[dict]:
        profile = await self.profiles.find_one({"email": email})
        return profile.get("projects", []) if profile else []

    async def add_project(self, email: str, project: Dict[str, Any]) -> dict:
        if not project:
            raise HTTPException(status_code=400, detail="Project data required")
        
        project_dict = project.copy()
        project_dict["_id"] = str(ObjectId())
        
        await self.profiles.update_one(
            {"email": email},
            {"$push": {"projects": project_dict}},
            upsert=True
        )
        
        return {"message": "Project added successfully", "data": project_dict}

    async def update_project(self, email: str, project_id: str, project: Dict[str, Any]) -> dict:
        if not project:
            raise HTTPException(status_code=400, detail="Project data required")
        
        project_dict = project.copy()
        project_dict["_id"] = project_id
        
        result = await self.profiles.update_one(
            {"email": email, "projects._id": project_id},
            {"$set": {"projects.$": project_dict}}
        )
        
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="Project not found")
        
        return {"message": "Project updated successfully"}

    async def delete_project(self, email: str, project_id: str) -> dict:
        result = await self.profiles.update_one(
            {"email": email},
            {"$pull": {"projects": {"_id": project_id}}}
        )
        
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Project not found")
        
        return {"message": "Project deleted successfully"}

    # ====================== LANGUAGES ======================
    async def get_languages(self, email: str) -> List[dict]:
        profile = await self.profiles.find_one({"email": email})
        return profile.get("languages", []) if profile else []

    async def add_language(self, email: str, language: Dict[str, Any]) -> dict:
        if not language:
            raise HTTPException(status_code=400, detail="Language data required")
        
        lang_dict = language.copy()
        lang_dict["_id"] = str(ObjectId())
        
        await self.profiles.update_one(
            {"email": email},
            {"$push": {"languages": lang_dict}},
            upsert=True
        )
        
        return {"message": "Language added successfully", "data": lang_dict}

    async def update_language(self, email: str, lang_id: str, language: Dict[str, Any]) -> dict:
        if not language:
            raise HTTPException(status_code=400, detail="Language data required")
        
        lang_dict = language.copy()
        lang_dict["_id"] = lang_id
        
        result = await self.profiles.update_one(
            {"email": email, "languages._id": lang_id},
            {"$set": {"languages.$": lang_dict}}
        )
        
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="Language not found")
        
        return {"message": "Language updated successfully"}

    async def delete_language(self, email: str, lang_id: str) -> dict:
        result = await self.profiles.update_one(
            {"email": email},
            {"$pull": {"languages": {"_id": lang_id}}}
        )
        
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Language not found")
        
        return {"message": "Language deleted successfully"}

    # ====================== OTHER DETAILS ======================
    async def get_other_details(self, email: str) -> Dict[str, Any]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return {}
        return profile.get("additional_details", {})

    async def update_other_details(self, email: str, details: Dict[str, Any]) -> dict:
        if details is None:
            details = {}
        
        await self.profiles.update_one(
            {"email": email},
            {"$set": {"additional_details": details}},
            upsert=True
        )
        return {"message": "Other details updated successfully"}

    # ====================== PROFILE + APPLICATIONS ======================
    async def get_profile_with_applications(self, email: str) -> Dict[str, Any]:
        # First sync phone from auth
        await self.sync_phone_to_profile(email)
        
        profile_doc = await self.profiles.find_one({"email": email})
        
        if not profile_doc:
            profile = await self.get_full_profile(email)
        else:
            profile = self._serialize(profile_doc)
        
        apps = await self.applications.find({"applicant_email": email}).to_list(100)
        
        return {
            "profile": profile,
            "applications": [self._serialize(a) for a in apps],
            "total_applications": len(apps),
            "pending_applications": len([a for a in apps if a.get("status") == "pending"])
        }

    # ====================== EDUCATED STATUS ======================
    async def update_educated_status(self, email: str, data: Dict[str, Any]) -> dict:
        await self.profiles.update_one(
            {"email": email},
            {"$set": {
                "is_educated": data.get("is_educated", True),
                "can_read": data.get("can_read", False),
                "can_write": data.get("can_write", False),
                "basic_education_level": data.get("basic_education_level", "None"),
                "languages_known": data.get("languages_known", []),
                "basic_skills": data.get("basic_skills", []),
                "updated_at": datetime.utcnow()
            }},
            upsert=True
        )
        return {"message": "Education status updated successfully"}

    # ====================== FRESHER STATUS ======================
    async def update_fresher_status(self, email: str, data: Dict[str, Any]) -> dict:
        await self.profiles.update_one(
            {"email": email},
            {"$set": {
                "is_fresher": data.get("is_fresher", True),
                "internship_details": data.get("internship_details", ""),
                "training_program": data.get("training_program", ""),
                "daily_wage": data.get("daily_wage"),
                "projects_done": data.get("projects_done", ""),
                "certifications_list": data.get("certifications", []),
                "labour_type": data.get("labour_type", "Mason"),
                "updated_at": datetime.utcnow()
            }},
            upsert=True
        )
        return {"message": "Fresher status updated successfully"}

    # ====================== CAREER GOALS ======================
    async def get_career_goals(self, email: str) -> Dict[str, Any]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return {}
        return profile.get("career_goals", {})

    async def update_career_goals(self, email: str, data: Dict[str, Any]) -> dict:
        update_data = {}
        for key, value in data.items():
            if value is not None:
                update_data[f"career_goals.{key}"] = value
        update_data["updated_at"] = datetime.utcnow()
        
        await self.profiles.update_one(
            {"email": email},
            {"$set": update_data},
            upsert=True
        )
        return {"message": "Career goals updated successfully", "email": email}

    # ====================== PERSONALITY TRAITS ======================
    async def get_personality_traits(self, email: str) -> Dict[str, Any]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return {}
        return profile.get("personality_traits", {})

    async def update_personality_traits(self, email: str, data: Dict[str, Any]) -> dict:
        update_data = {}
        for key, value in data.items():
            if value is not None:
                update_data[f"personality_traits.{key}"] = value
        update_data["updated_at"] = datetime.utcnow()
        
        await self.profiles.update_one(
            {"email": email},
            {"$set": update_data},
            upsert=True
        )
        return {"message": "Personality traits updated successfully", "email": email}

    # ====================== WORK ENVIRONMENT PREFERENCES ======================
    async def get_work_environment_preferences(self, email: str) -> Dict[str, Any]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return {}
        return profile.get("work_environment_preferences", {})

    async def update_work_environment_preferences(self, email: str, data: Dict[str, Any]) -> dict:
        update_data = {}
        for key, value in data.items():
            if value is not None:
                update_data[f"work_environment_preferences.{key}"] = value
        update_data["updated_at"] = datetime.utcnow()
        
        await self.profiles.update_one(
            {"email": email},
            {"$set": update_data},
            upsert=True
        )
        return {"message": "Work environment preferences updated successfully", "email": email}

    # ====================== COMPENSATION EXPECTATIONS ======================
    async def get_compensation_expectations(self, email: str) -> Dict[str, Any]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return {}
        return profile.get("compensation_expectations", {})

    async def update_compensation_expectations(self, email: str, data: Dict[str, Any]) -> dict:
        update_data = {}
        for key, value in data.items():
            if value is not None:
                update_data[f"compensation_expectations.{key}"] = value
        update_data["updated_at"] = datetime.utcnow()
        
        await self.profiles.update_one(
            {"email": email},
            {"$set": update_data},
            upsert=True
        )
        return {"message": "Compensation expectations updated successfully", "email": email}

    # ====================== JOB SEARCH PREFERENCES ======================
    async def get_job_search_preferences(self, email: str) -> Dict[str, Any]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return {}
        return profile.get("job_search_preferences", {})

    async def update_job_search_preferences(self, email: str, data: Dict[str, Any]) -> dict:
        update_data = {}
        for key, value in data.items():
            if value is not None:
                update_data[f"job_search_preferences.{key}"] = value
        update_data["updated_at"] = datetime.utcnow()
        
        await self.profiles.update_one(
            {"email": email},
            {"$set": update_data},
            upsert=True
        )
        return {"message": "Job search preferences updated successfully", "email": email}

    # ====================== SKILL ASSESSMENTS ======================
    async def get_skill_assessments(self, email: str) -> List[Dict[str, Any]]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return []
        return profile.get("skill_assessments", [])

    async def add_skill_assessment(self, email: str, assessment: Dict[str, Any]) -> dict:
        assessment["_id"] = str(ObjectId())
        await self.profiles.update_one(
            {"email": email},
            {"$push": {"skill_assessments": assessment}, "$set": {"updated_at": datetime.utcnow()}},
            upsert=True
        )
        return {"message": "Skill assessment added successfully", "data": assessment}

    async def update_skill_assessment(self, email: str, assessment_id: str, assessment: Dict[str, Any]) -> dict:
        assessment["_id"] = assessment_id
        result = await self.profiles.update_one(
            {"email": email, "skill_assessments._id": assessment_id},
            {"$set": {"skill_assessments.$": assessment, "updated_at": datetime.utcnow()}}
        )
        if result.matched_count == 0:
            raise HTTPException(status_code=404, detail="Skill assessment not found")
        return {"message": "Skill assessment updated successfully"}

    async def delete_skill_assessment(self, email: str, assessment_id: str) -> dict:
        result = await self.profiles.update_one(
            {"email": email},
            {"$pull": {"skill_assessments": {"_id": assessment_id}}, "$set": {"updated_at": datetime.utcnow()}}
        )
        if result.modified_count == 0:
            raise HTTPException(status_code=404, detail="Skill assessment not found")
        return {"message": "Skill assessment deleted successfully"}

    # ====================== JOB SEARCH STATUS ======================
    async def get_job_search_status(self, email: str) -> Dict[str, Any]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return {}
        return {
            "actively_looking_for_job": profile.get("actively_looking_for_job", False),
            "notice_period_days": profile.get("notice_period_days"),
            "can_join_immediately": profile.get("can_join_immediately", False),
            "preferred_joining_date": profile.get("preferred_joining_date"),
            "available_for_full_time": profile.get("available_for_full_time", True),
            "available_for_part_time": profile.get("available_for_part_time", False),
            "available_for_contract": profile.get("available_for_contract", False),
            "available_for_freelance": profile.get("available_for_freelance", False),
            "available_for_internship": profile.get("available_for_internship", True)
        }

    async def update_job_search_status(self, email: str, data: Dict[str, Any]) -> dict:
        update_data = {}
        for key, value in data.items():
            if value is not None:
                update_data[key] = value
        update_data["updated_at"] = datetime.utcnow()
        
        await self.profiles.update_one(
            {"email": email},
            {"$set": update_data},
            upsert=True
        )
        return {"message": "Job search status updated successfully", "email": email}

    # ====================== CAREER CHANGE INFO ======================
    async def get_career_change_info(self, email: str) -> Dict[str, Any]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return {}
        return {
            "career_change_interest": profile.get("career_change_interest", False),
            "previous_career_fields": profile.get("previous_career_fields", []),
            "transferable_skills": profile.get("transferable_skills", []),
            "reason_for_career_change": profile.get("reason_for_career_change"),
            "target_career_fields": profile.get("target_career_fields", [])
        }

    async def update_career_change_info(self, email: str, data: Dict[str, Any]) -> dict:
        update_data = {}
        for key, value in data.items():
            if value is not None:
                update_data[key] = value
        update_data["updated_at"] = datetime.utcnow()
        
        await self.profiles.update_one(
            {"email": email},
            {"$set": update_data},
            upsert=True
        )
        return {"message": "Career change information updated successfully", "email": email}
    
    # ====================== EDUCATIONAL BACKGROUND ======================
    async def get_educational_background(self, email: str) -> Dict[str, Any]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return {}
        return profile.get("educational_background", {})

    async def update_educational_background(self, email: str, data: Dict[str, Any]) -> dict:
        update_data = {}
        for key, value in data.items():
            if value is not None:
                update_data[f"educational_background.{key}"] = value
        update_data["updated_at"] = datetime.utcnow()
        
        await self.profiles.update_one(
            {"email": email},
            {"$set": update_data},
            upsert=True
        )
        return {"message": "Educational background updated successfully", "email": email}

    # ====================== CAREER ASPIRATIONS ======================
    async def get_career_aspirations(self, email: str) -> Dict[str, Any]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return {}
        return profile.get("career_aspirations", {})

    async def update_career_aspirations(self, email: str, data: Dict[str, Any]) -> dict:
        update_data = {}
        for key, value in data.items():
            if value is not None:
                update_data[f"career_aspirations.{key}"] = value
        update_data["updated_at"] = datetime.utcnow()
        
        await self.profiles.update_one(
            {"email": email},
            {"$set": update_data},
            upsert=True
        )
        return {"message": "Career aspirations updated successfully", "email": email}

    # ====================== LEARNING PREFERENCES ======================
    async def get_learning_preferences(self, email: str) -> Dict[str, Any]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return {}
        return profile.get("learning_preferences", {})

    async def update_learning_preferences(self, email: str, data: Dict[str, Any]) -> dict:
        update_data = {}
        for key, value in data.items():
            if value is not None:
                update_data[f"learning_preferences.{key}"] = value
        update_data["updated_at"] = datetime.utcnow()
        
        await self.profiles.update_one(
            {"email": email},
            {"$set": update_data},
            upsert=True
        )
        return {"message": "Learning preferences updated successfully", "email": email}

    # ====================== INCOME & EXPENSE ======================
    async def get_income_expense(self, email: str) -> Dict[str, Any]:
        profile = await self.profiles.find_one({"email": email})
        if not profile:
            return {}
        return profile.get("income_expense", {})

    async def update_income_expense(self, email: str, data: Dict[str, Any]) -> dict:
        update_data = {}
        for key, value in data.items():
            if value is not None:
                update_data[f"income_expense.{key}"] = value
        update_data["updated_at"] = datetime.utcnow()
        
        await self.profiles.update_one(
            {"email": email},
            {"$set": update_data},
            upsert=True
        )
        return {"message": "Income & expense information updated successfully", "email": email}


print("✅ Profile Service Loaded - Fixed for KeyError issues and Phone sync")