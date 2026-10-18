# app/modules/user/schema.py - COMPLETE UPDATED VERSION
# Matches frontend user_service.dart contract exactly

from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime


# ==================== NESTED SCHEMAS ====================

class AddressSchema(BaseModel):
    house_number: Optional[str] = None
    village_name: Optional[str] = None
    city: Optional[str] = None
    post_office: Optional[str] = None
    tehsil: Optional[str] = None
    district: Optional[str] = ""
    state: Optional[str] = ""
    country: Optional[str] = "India"
    pincode: Optional[str] = None
    landmark: Optional[str] = None

    class Config:
        extra = "allow"


class EmergencyContactSchema(BaseModel):
    name: Optional[str] = ""
    relationship: Optional[str] = ""
    phone: Optional[str] = ""
    alternate_phone: Optional[str] = None
    email: Optional[str] = None

    class Config:
        extra = "allow"


class DisabilitySchema(BaseModel):
    is_disabled: bool = False
    disability_category: Optional[str] = ""
    disability_percentage: Optional[float] = None
    disability_details: Optional[str] = ""
    certificate_url: Optional[str] = None
    certificate_verified: bool = False

    class Config:
        extra = "allow"


class SocialLinksSchema(BaseModel):
    linkedin: Optional[str] = ""
    github: Optional[str] = ""
    portfolio: Optional[str] = ""
    twitter: Optional[str] = ""
    facebook: Optional[str] = ""
    instagram: Optional[str] = ""
    youtube: Optional[str] = ""
    personal_website: Optional[str] = ""

    class Config:
        extra = "allow"


class CompensationExpectationsSchema(BaseModel):
    expected_salary_min: Optional[int] = None
    expected_salary_max: Optional[int] = None
    expected_salary_currency: Optional[str] = "INR"
    is_salary_negotiable: Optional[bool] = True

    class Config:
        extra = "allow"


# ==================== MAIN BASIC DETAILS SCHEMA ====================
# Permissive schema — accepts any of the fields the frontend sends.
# extra="allow" so that new fields added on frontend won't break backend.

class BasicDetailsSchema(BaseModel):
    # Personal
    full_name: Optional[str] = None
    first_name: Optional[str] = None
    middle_name: Optional[str] = None
    last_name: Optional[str] = None
    gender: Optional[str] = None
    dob: Optional[str] = None
    birth_place: Optional[str] = None
    blood_group: Optional[str] = None
    nationality: Optional[str] = None
    religion: Optional[str] = None
    category: Optional[str] = None
    hobbies: Optional[List[str]] = None
    interests: Optional[List[str]] = None

    # Family
    father_name: Optional[str] = None
    mother_name: Optional[str] = None
    guardian_name: Optional[str] = None
    spouse_name: Optional[str] = None
    marital_status: Optional[str] = None
    family_annual_income: Optional[int] = None
    number_of_dependents: Optional[int] = None

    # Contact
    alternate_mobile: Optional[str] = None
    whatsapp_number: Optional[str] = None
    emergency_contact: Optional[EmergencyContactSchema] = None

    # Address
    current_address: Optional[AddressSchema] = None
    same_as_current: Optional[bool] = None
    permanent_address: Optional[AddressSchema] = None

    # Professional
    summary: Optional[str] = None
    career_objective: Optional[str] = None
    linkedin_url: Optional[str] = None
    github_url: Optional[str] = None
    portfolio_url: Optional[str] = None
    social_links: Optional[SocialLinksSchema] = None

    # Physical
    height: Optional[float] = None
    weight: Optional[float] = None
    languages_known: Optional[List[str]] = None

    # Disability (nested only)
    disability: Optional[DisabilitySchema] = None

    # Job preferences
    preferred_location: Optional[str] = None
    open_to_relocate: Optional[bool] = None
    open_to_remote_work: Optional[bool] = None
    preferred_job_types: Optional[List[str]] = None
    preferred_industries: Optional[List[str]] = None
    compensation_expectations: Optional[CompensationExpectationsSchema] = None

    class Config:
        extra = "allow"
        populate_by_name = True


# ==================== EDUCATION SCHEMAS ====================

class EducationCreateSchema(BaseModel):
    level: str
    degree: Optional[str] = ""
    stream: Optional[str] = ""
    institute: str
    board_university: Optional[str] = ""
    year_of_passing: int
    cgpa_percentage: Optional[float] = None
    result_type: Optional[str] = "Percentage"
    grade: Optional[str] = ""
    medium: Optional[str] = ""
    subjects: List[str] = Field(default_factory=list)
    backlogs: Optional[int] = 0
    certificate_url: Optional[str] = ""
    achievements: List[str] = Field(default_factory=list)
    is_pursuing: Optional[bool] = False

    class Config:
        extra = "allow"


class EducationUpdateSchema(BaseModel):
    level: Optional[str] = None
    degree: Optional[str] = None
    stream: Optional[str] = None
    institute: Optional[str] = None
    board_university: Optional[str] = None
    year_of_passing: Optional[int] = None
    cgpa_percentage: Optional[float] = None
    result_type: Optional[str] = None
    grade: Optional[str] = None
    medium: Optional[str] = None
    subjects: Optional[List[str]] = None
    backlogs: Optional[int] = None
    certificate_url: Optional[str] = None
    achievements: Optional[List[str]] = None

    class Config:
        extra = "allow"


# ==================== EXPERIENCE SCHEMAS ====================

class ExperienceCreateSchema(BaseModel):
    company: str
    role: str
    industry_type: Optional[str] = ""
    work_type: Optional[str] = ""
    employment_type: Optional[str] = "Full-time"
    location: Optional[str] = ""
    salary: Optional[int] = None
    start_date: str
    end_date: Optional[str] = None
    description: Optional[str] = ""
    achievements: List[str] = Field(default_factory=list)
    skills_used: List[str] = Field(default_factory=list)
    reason_for_leaving: Optional[str] = ""
    reporting_manager: Optional[str] = ""
    team_size: Optional[int] = None

    class Config:
        extra = "allow"


class ExperienceUpdateSchema(BaseModel):
    company: Optional[str] = None
    role: Optional[str] = None
    industry_type: Optional[str] = None
    work_type: Optional[str] = None
    employment_type: Optional[str] = None
    location: Optional[str] = None
    salary: Optional[int] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    description: Optional[str] = None
    achievements: Optional[List[str]] = None
    skills_used: Optional[List[str]] = None
    reason_for_leaving: Optional[str] = None
    reporting_manager: Optional[str] = None
    team_size: Optional[int] = None

    class Config:
        extra = "allow"


# ==================== INTERNSHIP SCHEMAS ====================

class InternshipCreateSchema(BaseModel):
    company: str
    role: str
    start_date: str
    end_date: Optional[str] = None
    description: Optional[str] = ""
    stipend: Optional[int] = None
    technologies: List[str] = Field(default_factory=list)

    class Config:
        extra = "allow"


class InternshipUpdateSchema(BaseModel):
    company: Optional[str] = None
    role: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    description: Optional[str] = None
    stipend: Optional[int] = None
    technologies: Optional[List[str]] = None

    class Config:
        extra = "allow"


# ==================== SKILL SCHEMAS ====================

class SkillCreateSchema(BaseModel):
    name: str
    proficiency: Optional[str] = "Intermediate"
    level: Optional[str] = None
    category: Optional[str] = "Technical"
    years_of_experience: Optional[int] = 0

    class Config:
        extra = "allow"


class SkillUpdateSchema(BaseModel):
    name: Optional[str] = None
    proficiency: Optional[str] = None
    level: Optional[str] = None
    category: Optional[str] = None
    years_of_experience: Optional[int] = None

    class Config:
        extra = "allow"


# ==================== PROJECT SCHEMAS ====================

class ProjectCreateSchema(BaseModel):
    title: str
    description: Optional[str] = ""
    technologies: List[str] = Field(default_factory=list)
    role: Optional[str] = ""
    duration: Optional[str] = ""
    url: Optional[str] = ""
    github_url: Optional[str] = ""

    class Config:
        extra = "allow"


class ProjectUpdateSchema(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    technologies: Optional[List[str]] = None
    role: Optional[str] = None
    duration: Optional[str] = None
    url: Optional[str] = None
    github_url: Optional[str] = None

    class Config:
        extra = "allow"


# ==================== CERTIFICATION SCHEMAS ====================

class CertificationCreateSchema(BaseModel):
    name: str
    issuer: Optional[str] = ""
    year: Optional[int] = None
    credential_id: Optional[str] = ""
    url: Optional[str] = ""

    class Config:
        extra = "allow"


class CertificationUpdateSchema(BaseModel):
    name: Optional[str] = None
    issuer: Optional[str] = None
    year: Optional[int] = None
    credential_id: Optional[str] = None
    url: Optional[str] = None

    class Config:
        extra = "allow"


# ==================== LANGUAGE SCHEMAS ====================

class LanguageCreateSchema(BaseModel):
    name: str
    proficiency: Optional[str] = "Fluent"
    read: Optional[bool] = True
    write: Optional[bool] = True
    speak: Optional[bool] = True

    class Config:
        extra = "allow"


class LanguageUpdateSchema(BaseModel):
    name: Optional[str] = None
    proficiency: Optional[str] = None
    read: Optional[bool] = None
    write: Optional[bool] = None
    speak: Optional[bool] = None

    class Config:
        extra = "allow"


# ==================== OTHER DETAIL SCHEMAS ====================

class BankDetailsSchema(BaseModel):
    account_holder_name: Optional[str] = None
    account_number: Optional[str] = None
    ifsc_code: Optional[str] = None
    bank_name: Optional[str] = None
    branch_name: Optional[str] = None
    upi_id: Optional[str] = None

    class Config:
        extra = "allow"


class GovernmentIDsSchema(BaseModel):
    aadhar_number: Optional[str] = None
    pan_number: Optional[str] = None
    voter_id: Optional[str] = None
    driving_license: Optional[str] = None
    passport_number: Optional[str] = None

    class Config:
        extra = "allow"


class ReferenceCreateSchema(BaseModel):
    name: str
    designation: Optional[str] = ""
    company: Optional[str] = ""
    phone: Optional[str] = ""
    email: Optional[str] = ""
    relationship: Optional[str] = ""

    class Config:
        extra = "allow"


class EmploymentPreferencesSchema(BaseModel):
    preferred_work_modes: Optional[List[str]] = None
    preferred_shifts: Optional[List[str]] = None
    preferred_work_location: Optional[str] = None
    notice_period_days: Optional[int] = None
    can_join_immediately: Optional[bool] = None
    expected_salary_min: Optional[int] = None
    expected_salary_max: Optional[int] = None
    preferred_industries: Optional[List[str]] = None
    preferred_job_roles: Optional[List[str]] = None
    preferred_locations: Optional[List[str]] = None
    open_to_relocate: Optional[bool] = None

    class Config:
        extra = "allow"


class WorkAuthorizationSchema(BaseModel):
    is_indian_citizen: Optional[bool] = True
    has_work_permit: Optional[bool] = False
    work_permit_country: Optional[str] = None
    visa_type: Optional[str] = None
    visa_valid_until: Optional[str] = None

    class Config:
        extra = "allow"


class ApplicationPreferencesSchema(BaseModel):
    email_notifications: Optional[bool] = True
    sms_notifications: Optional[bool] = False
    whatsapp_notifications: Optional[bool] = False
    auto_apply_matches: Optional[bool] = False
    min_match_percentage: Optional[int] = 70

    class Config:
        extra = "allow"


# ==================== STATUS TOGGLE SCHEMAS ====================

class EducatedStatusSchema(BaseModel):
    is_educated: Optional[bool] = None
    can_read: Optional[bool] = None
    can_write: Optional[bool] = None
    basic_education_level: Optional[str] = None
    languages_known: Optional[List[str]] = None
    basic_skills: Optional[List[str]] = None

    class Config:
        extra = "allow"


class FresherStatusSchema(BaseModel):
    is_fresher: Optional[bool] = None
    internship_details: Optional[str] = None
    training_program: Optional[str] = None
    daily_wage: Optional[int] = None
    projects_done: Optional[str] = None
    labour_type: Optional[str] = None

    class Config:
        extra = "allow"


# ==================== OTHER DETAILS (generic) ====================

class OtherDetailsSchema(BaseModel):
    """Generic schema for other-details endpoint"""
    soft_skills: Optional[List[str]] = None
    video_resume_url: Optional[str] = None

    class Config:
        extra = "allow"