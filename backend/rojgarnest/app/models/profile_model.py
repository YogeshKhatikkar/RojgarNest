# app/models/profile_model.py - FIXED VERSION
# ONLY nested disability object - NO top-level duplicates

from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator
from typing import List, Optional, Dict, Any, Union
from datetime import datetime
from enum import Enum
from bson import ObjectId
import hashlib
import json

# ==================== VERSION CONTROL ====================
class ModelVersion(str, Enum):
    V1 = "1.0"
    V2 = "1.1"
    V3 = "2.0"
    LATEST = "2.0"

# ==================== SCHEMA EVOLUTION ====================
class SchemaMetadata(BaseModel):
    """Track schema version and migration history"""
    version: str = ModelVersion.LATEST
    migrated_at: datetime = Field(default_factory=datetime.utcnow)
    migration_history: List[Dict[str, Any]] = Field(default_factory=list)
    deprecated_fields: Dict[str, str] = Field(default_factory=dict)

# ==================== EXTENSIBLE METADATA ====================
class ExtensibleMetadata(BaseModel):
    """Allow future fields without breaking changes"""
    custom_fields: Dict[str, Any] = Field(default_factory=dict)
    extensions: Dict[str, Any] = Field(default_factory=dict)
    tags: List[str] = Field(default_factory=list)
    
    def get(self, key: str, default: Any = None) -> Any:
        return self.custom_fields.get(key, default)
    
    def set(self, key: str, value: Any) -> None:
        self.custom_fields[key] = value

# ==================== BASE MODEL WITH VERSIONING ====================
class VersionedBaseModel(BaseModel):
    """Base model with version control for all child models"""
    version: str = ModelVersion.LATEST
    metadata: SchemaMetadata = Field(default_factory=SchemaMetadata)
    extensible: ExtensibleMetadata = Field(default_factory=ExtensibleMetadata)
    
    class Config:
        extra = "allow"
        arbitrary_types_allowed = True
        populate_by_name = True
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            ObjectId: lambda v: str(v)
        }

# ==================== LANGUAGE ====================
class Language(VersionedBaseModel):
    """Language model for user languages"""
    name: str
    proficiency: str = Field(..., pattern="^(native|fluent|intermediate|basic|professional)$")
    can_read: bool = True
    can_write: bool = True
    can_speak: bool = True
    is_native: bool = False
    certification_url: Optional[str] = None
    _id: Optional[str] = None

# ==================== ADDRESS ====================
class Address(VersionedBaseModel):
    house_number: Optional[str] = Field(None, alias="house_no")
    village_name: Optional[str] = Field(None, alias="village")
    post_office: Optional[str] = Field(None, alias="po")
    tehsil: Optional[str] = None
    district: str = ""
    state: str = ""
    pincode: Optional[str] = Field(None, alias="zipcode")
    landmark: Optional[str] = None
    country: str = "India"
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    address_type: str = "current"

# ==================== EMERGENCY CONTACT ====================
class EmergencyContact(VersionedBaseModel):
    name: str = ""
    relationship: str = ""
    phone: str = ""
    alternate_phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None

# ==================== DISABILITY INFO (ONLY NESTED - NO TOP-LEVEL) ====================
class DisabilityInfo(VersionedBaseModel):
    """Disability information - ONLY nested, no top-level duplicates"""
    is_disabled: bool = Field(default=False, alias="has_disability")
    disability_category: Optional[str] = Field(default=None, alias="category")
    disability_category_name: Optional[str] = Field(default=None, alias="category_name")
    disability_percentage: Optional[float] = Field(default=None, ge=0, le=100, alias="percentage")
    disability_details: str = Field(default="", alias="details")
    physically_challenged: str = Field(default="No", alias="physical_status")
    certificate_url: Optional[str] = Field(default=None, alias="cert_url")
    certificate_verified: bool = Field(default=False, alias="cert_verified")
    verified_at: Optional[datetime] = None
    verified_by: Optional[str] = None
    disability_type: List[str] = Field(default_factory=list)
    accommodation_needed: List[str] = Field(default_factory=list)
    medical_certificate_id: Optional[str] = None
    
    @property
    def display_category(self) -> str:
        """Get display-friendly category name"""
        if self.disability_category_name:
            return self.disability_category_name
        if self.disability_category:
            return self.disability_category
        return "Not specified"

# ==================== GOVERNMENT IDs ====================
class GovernmentIDs(VersionedBaseModel):
    aadhar_number: Optional[str] = None
    aadhar_verified: bool = False
    pan_number: Optional[str] = None
    pan_verified: bool = False
    voter_id: Optional[str] = None
    driving_license: Optional[str] = None
    passport_number: Optional[str] = None

# ==================== BANK DETAILS ====================
class BankDetails(VersionedBaseModel):
    account_holder_name: Optional[str] = None
    account_number: Optional[str] = None
    confirm_account_number: Optional[str] = None
    ifsc_code: Optional[str] = None
    bank_name: Optional[str] = None
    branch_name: Optional[str] = None
    upi_id: Optional[str] = None
    is_verified: bool = False

# ==================== SOCIAL LINKS ====================
class SocialLinks(VersionedBaseModel):
    linkedin: Optional[str] = None
    github: Optional[str] = None
    portfolio: Optional[str] = None
    twitter: Optional[str] = None
    facebook: Optional[str] = None
    instagram: Optional[str] = None
    youtube: Optional[str] = None
    personal_website: Optional[str] = None

# ==================== WORK AUTHORIZATION ====================
class WorkAuthorization(VersionedBaseModel):
    is_indian_citizen: bool = True
    has_work_permit: bool = False
    work_permit_country: Optional[str] = None
    visa_type: Optional[str] = None
    visa_valid_until: Optional[str] = None
    passport_number: Optional[str] = None

# ==================== DOCUMENT ====================
class Document(VersionedBaseModel):
    doc_type: str
    doc_name: str
    doc_url: str
    doc_public_id: Optional[str] = None
    uploaded_at: datetime = Field(default_factory=datetime.utcnow)
    verified: bool = False
    verified_at: Optional[datetime] = None

class Documents(VersionedBaseModel):
    documents: List[Document] = Field(default_factory=list)
    resume_url: Optional[str] = None
    resume_public_id: Optional[str] = None
    profile_photo_url: Optional[str] = None
    signature_url: Optional[str] = None

# ==================== ACADEMIC RECORD ====================
class AcademicRecord(VersionedBaseModel):
    level: str = Field(..., pattern="^(10th|12th|diploma|graduation|post_graduation|phd)$")
    degree: Optional[str] = None
    stream: Optional[str] = None
    subjects: List[str] = Field(default_factory=list)
    institute: str
    board_university: Optional[str] = None
    year_of_passing: int
    cgpa_percentage: Optional[float] = None
    result_type: Optional[str] = "Percentage"
    grade: Optional[str] = None
    medium: Optional[str] = None
    backlogs: Optional[int] = Field(default=0, ge=0)
    certificate_url: Optional[str] = None
    is_pursuing: bool = False
    expected_completion_year: Optional[int] = None
    _id: Optional[str] = None

# ==================== SKILL ====================
class Skill(VersionedBaseModel):
    name: str
    level: str = Field(..., pattern="^(beginner|intermediate|advanced|expert)$")
    years_of_experience: Optional[float] = Field(None, alias="years")
    last_used: Optional[str] = Field(None, alias="last_used_date")
    importance: Optional[int] = Field(None, ge=1, le=10)
    ai_match_score: Optional[float] = None
    endorsement_count: int = 0
    verified_by: Optional[str] = None
    verified_at: Optional[datetime] = None
    skill_category: Optional[str] = None
    sub_skills: List[str] = Field(default_factory=list)
    _id: Optional[str] = None

# ==================== EXPERIENCE ====================
class Experience(VersionedBaseModel):
    company: str
    role: str
    start_date: str
    end_date: Optional[str] = None
    description: str
    achievements: List[str] = Field(default_factory=list)
    industry_type: Optional[str] = Field(None, alias="industry")
    work_type: Optional[str] = Field(None, alias="work_mode")
    employment_type: str = "Full-time"
    location: Optional[str] = None
    salary: Optional[int] = None
    skills_used: List[str] = Field(default_factory=list)
    reason_for_leaving: Optional[str] = None
    reporting_manager: Optional[str] = None
    team_size: Optional[int] = None
    is_current: bool = False
    notice_period_days: Optional[int] = None
    offer_letter_url: Optional[str] = None
    experience_certificate_url: Optional[str] = None
    is_verified: bool = False
    verified_by: Optional[str] = None
    _id: Optional[str] = None

# ==================== INTERNSHIP ====================
class Internship(VersionedBaseModel):
    company: str
    role: str
    start_date: str
    end_date: Optional[str] = None
    description: str
    technologies: List[str] = Field(default_factory=list)
    stipend: Optional[float] = None
    _id: Optional[str] = None

# ==================== CERTIFICATION ====================
class Certification(VersionedBaseModel):
    name: str
    issuer: str
    year: int
    url: Optional[str] = None
    expiry_date: Optional[str] = None
    credential_id: Optional[str] = None
    _id: Optional[str] = None

# ==================== PROJECT ====================
class Project(VersionedBaseModel):
    title: str
    description: str
    technologies: List[str] = Field(default_factory=list)
    url: Optional[str] = None
    github_url: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    is_live: bool = False
    _id: Optional[str] = None

# ==================== EXTRACURRICULAR ====================
class Extracurricular(VersionedBaseModel):
    activity_type: str = Field(..., pattern="^(sports|cultural|volunteering|club|hackathon|workshop|other)$")
    title: str
    description: str
    year: int
    achievement: Optional[str] = None
    _id: Optional[str] = None

# ==================== EMPLOYMENT PREFERENCES ====================
class EmploymentPreferences(VersionedBaseModel):
    preferred_work_modes: List[str] = ["Full-time"]
    preferred_shifts: List[str] = ["Day"]
    preferred_work_location: str = "Any"
    notice_period_days: Optional[int] = None
    can_join_immediately: bool = False
    expected_salary_min: Optional[int] = None
    expected_salary_max: Optional[int] = None
    expected_salary_currency: str = "INR"
    is_salary_negotiable: bool = True
    preferred_industries: List[str] = Field(default_factory=list)
    preferred_job_roles: List[str] = Field(default_factory=list)
    preferred_locations: List[str] = Field(default_factory=list)
    open_to_relocate: bool = False
    open_to_travel: bool = False
    travel_percentage: Optional[int] = None

# ==================== APPLICATION PREFERENCES ====================
class ApplicationPreferences(VersionedBaseModel):
    email_notifications: bool = True
    sms_notifications: bool = False
    whatsapp_notifications: bool = False
    auto_apply_matches: bool = False
    min_match_percentage: int = 70
    saved_searches: List[Dict[str, Any]] = Field(default_factory=list)

# ==================== CAREER GOALS ====================
class CareerGoals(VersionedBaseModel):
    short_term_goals: List[str] = Field(default_factory=list)
    short_term_target_role: Optional[str] = None
    short_term_target_industry: Optional[str] = None
    short_term_target_salary: Optional[int] = None
    medium_term_goals: List[str] = Field(default_factory=list)
    medium_term_target_role: Optional[str] = None
    medium_term_target_industry: Optional[str] = None
    medium_term_target_salary: Optional[int] = None
    long_term_goals: List[str] = Field(default_factory=list)
    long_term_target_role: Optional[str] = None
    long_term_target_industry: Optional[str] = None
    long_term_target_salary: Optional[int] = None
    dream_role: Optional[str] = None
    dream_company: Optional[str] = None
    dream_industry: Optional[str] = None
    willing_to_change_career: bool = False
    interested_in_different_domain: List[str] = Field(default_factory=list)
    preferred_work_life_balance: str = "balanced"
    career_ambition: str = "grow"

# ==================== PERSONALITY TRAITS ====================
class PersonalityTraits(VersionedBaseModel):
    openness: Optional[int] = Field(None, ge=1, le=10)
    conscientiousness: Optional[int] = Field(None, ge=1, le=10)
    extraversion: Optional[int] = Field(None, ge=1, le=10)
    agreeableness: Optional[int] = Field(None, ge=1, le=10)
    neuroticism: Optional[int] = Field(None, ge=1, le=10)
    prefers_independent_work: bool = False
    prefers_team_work: bool = True
    prefers_leadership_role: bool = False
    prefers_creative_work: bool = False
    prefers_analytical_work: bool = False
    stress_tolerance: str = "medium"
    deadline_preference: str = "flexible"
    communication_style: str = "balanced"
    learning_style: str = "visual"

# ==================== WORK ENVIRONMENT PREFERENCES ====================
class WorkEnvironmentPreferences(VersionedBaseModel):
    preferred_company_size: str = "any"
    preferred_company_type: List[str] = ["private"]
    preferred_culture: List[str] = Field(default_factory=list)
    desk_type: str = "any"
    noise_level: str = "moderate"
    team_size_preference: str = "medium"
    collaboration_frequency: str = "daily"
    flexible_hours_required: bool = False
    core_hours_required: bool = True
    weekend_work_willing: bool = False
    overtime_willing: bool = False
    health_insurance_importance: int = 8
    retirement_benefits_importance: int = 6
    learning_budget_importance: int = 7
    work_from_home_importance: int = 5
    gym_membership_importance: int = 3

# ==================== COMPENSATION EXPECTATIONS ====================
class CompensationExpectations(VersionedBaseModel):
    expected_salary_min: Optional[int] = None
    expected_salary_max: Optional[int] = None
    expected_salary_currency: str = "INR"
    is_salary_negotiable: bool = True
    expected_fixed_salary_percentage: int = 70
    expected_variable_salary_percentage: int = 30
    expected_esops: bool = False
    must_have_benefits: List[str] = Field(default_factory=list)
    nice_to_have_benefits: List[str] = Field(default_factory=list)
    desired_perks: List[str] = Field(default_factory=list)
    expected_annual_increment_percentage: int = 10

# ==================== JOB SEARCH PREFERENCES ====================
class JobSearchPreferences(VersionedBaseModel):
    job_alert_frequency: str = "daily"
    job_alert_channels: List[str] = ["email", "whatsapp"]
    auto_apply_for_matching_jobs: bool = False
    auto_apply_threshold_percentage: int = 85
    require_manual_review_before_apply: bool = True
    receive_similar_job_alerts: bool = True
    receive_career_tips: bool = True
    receive_market_updates: bool = True
    saved_searches: List[Dict[str, Any]] = Field(default_factory=list)
    exclude_companies: List[str] = Field(default_factory=list)
    preferred_companies: List[str] = Field(default_factory=list)
    max_commute_distance_km: Optional[int] = None
    willing_to_relocate_cities: List[str] = Field(default_factory=list)

# ==================== LOCATION PREFERENCES ====================
class LocationPreferences(VersionedBaseModel):
    preferred_cities: List[str] = Field(default_factory=list)
    preferred_states: List[str] = Field(default_factory=list)
    preferred_countries: List[str] = Field(default_factory=list)
    willing_to_relocate: bool = False
    willing_to_travel_for_work: bool = False
    max_travel_percentage: int = 0
    preferred_regions: List[str] = Field(default_factory=list)
    avoid_cities: List[str] = Field(default_factory=list)
    tier_preference: str = "any"

# ==================== ADDITIONAL DETAILS ====================
class AdditionalDetails(VersionedBaseModel):
    soft_skills: List[str] = Field(default_factory=list)
    linkedin_url: Optional[str] = None
    github_url: Optional[str] = None
    portfolio_url: Optional[str] = None
    resume_url: Optional[str] = None
    video_resume_url: Optional[str] = None
    preferred_job_types: List[str] = Field(default_factory=list)
    preferred_industries: List[str] = Field(default_factory=list)
    preferred_locations: List[str] = Field(default_factory=list)
    open_to_relocate: bool = False
    availability_date: Optional[str] = None
    salary_expectation_min: Optional[int] = None
    salary_expectation_max: Optional[int] = None
    willing_for_internship: bool = True
    willing_for_full_time: bool = True

# ==================== SKILL ASSESSMENT ====================
class SkillAssessment(VersionedBaseModel):
    skill_name: str
    proficiency_level: str
    years_of_experience: float
    last_used: Optional[str] = None
    is_core_skill: bool = False
    is_learning: bool = False
    interested_in_improving: bool = True
    certifications: List[str] = Field(default_factory=list)
    projects_using_skill: List[str] = Field(default_factory=list)
    _id: Optional[str] = None

# ==================== SKILL GAP ANALYSIS ====================
class SkillGapAnalysis(VersionedBaseModel):
    analysis_date: datetime = Field(default_factory=datetime.utcnow)
    current_skills: List[str] = Field(default_factory=list)
    missing_skills_for_target: List[Dict[str, Any]] = Field(default_factory=list)
    recommended_skills_to_learn: List[Dict[str, Any]] = Field(default_factory=list)
    skill_gap_score: int = 0
    estimated_learning_time_months: int = 0
    learning_resources: List[Dict[str, Any]] = Field(default_factory=list)

# ==================== JOB FIT SCORE ====================
class JobFitScore(VersionedBaseModel):
    job_type: str
    fit_score: int = 0
    reason: str = ""
    strengths: List[str] = Field(default_factory=list)
    weaknesses: List[str] = Field(default_factory=list)
    recommended_improvements: List[str] = Field(default_factory=list)
    salary_expectation_range: str = ""

# ==================== CAREER PATH RECOMMENDATION ====================
class CareerPathRecommendation(VersionedBaseModel):
    role: str
    industry: str
    match_percentage: int = 0
    required_skills: List[str] = Field(default_factory=list)
    missing_skills: List[str] = Field(default_factory=list)
    estimated_salary_range: str = ""
    growth_potential: str = "medium"
    demand_in_market: str = "medium"
    years_to_reach: int = 0
    recommended_certifications: List[str] = Field(default_factory=list)
    success_stories: List[str] = Field(default_factory=list)

# ==================== EDUCATION GOAL ====================
class EducationGoal(VersionedBaseModel):
    wants_higher_education: bool = False
    interested_degrees: List[str] = Field(default_factory=list)
    interested_institutes: List[str] = Field(default_factory=list)
    willing_to_study_abroad: bool = False
    preferred_study_countries: List[str] = Field(default_factory=list)
    education_budget: Optional[int] = None
    need_scholarship: bool = False
    part_time_study_preferred: bool = False
    online_course_preferred: bool = True

# ==================== CERTIFICATION GOAL ====================
class CertificationGoal(VersionedBaseModel):
    interested_certifications: List[str] = Field(default_factory=list)
    certification_budget: Optional[int] = None
    willing_to_get_certified: bool = True
    preferred_certification_mode: str = "online"
    target_certifications_by_year: Dict[str, List[str]] = Field(default_factory=dict)

# ==================== NETWORKING PREFERENCES ====================
class NetworkingPreferences(VersionedBaseModel):
    interested_in_mentorship: bool = False
    willing_to_mentor_others: bool = False
    interested_in_networking_events: bool = False
    preferred_networking_mode: str = "online"
    industry_events_interested: List[str] = Field(default_factory=list)
    professional_associations: List[str] = Field(default_factory=list)

# ==================== WORK-LIFE BALANCE ====================
class WorkLifeBalance(VersionedBaseModel):
    preferred_weekly_hours: int = 45
    max_weekly_hours: int = 60
    preferred_shift: str = "day"
    weekend_preference: str = "saturday_sunday_off"
    vacation_days_expected: int = 20
    work_from_home_days_per_week: int = 0
    family_time_priority: int = 7
    health_priority: int = 8
    social_life_priority: int = 5

# ==================== FINANCIAL GOALS ====================
class FinancialGoals(VersionedBaseModel):
    target_savings_per_month: Optional[int] = None
    target_investment_per_month: Optional[int] = None
    financial_independence_target_age: Optional[int] = None
    retirement_age: Optional[int] = None
    expected_retirement_corpus: Optional[int] = None
    children_education_fund_needed: bool = False
    house_purchase_plan_years: Optional[int] = None
    emergency_fund_months: int = 6

# ==================== PORTFOLIO ====================
class Portfolio(VersionedBaseModel):
    github_url: Optional[str] = None
    linkedin_url: Optional[str] = None
    portfolio_website: Optional[str] = None
    behance_url: Optional[str] = None
    dribbble_url: Optional[str] = None
    medium_blog: Optional[str] = None
    stackoverflow_url: Optional[str] = None
    leetcode_url: Optional[str] = None
    hackerrank_url: Optional[str] = None
    codeforces_url: Optional[str] = None
    youtube_channel: Optional[str] = None
    personal_blog: Optional[str] = None
    research_gate_url: Optional[str] = None
    google_scholar_url: Optional[str] = None

# ==================== JOB APPLICATION HISTORY ====================
class JobApplicationHistory(VersionedBaseModel):
    job_id: str
    job_title: str
    company: str
    applied_date: datetime = Field(default_factory=datetime.utcnow)
    status: str = "applied"
    match_score_at_application: Optional[int] = None
    notes: Optional[str] = None
    interview_rounds_cleared: int = 0
    offer_details: Optional[Dict[str, Any]] = None
    reason_for_rejection: Optional[str] = None
    feedback_received: Optional[str] = None
    _id: Optional[str] = None

# ==================== AI RECOMMENDATION FEEDBACK ====================
class AIRecommendationFeedback(VersionedBaseModel):
    recommendation_id: str
    recommendation_type: str
    was_helpful: bool
    rating: int = Field(ge=1, le=5)
    feedback_text: Optional[str] = None
    clicked: bool = False
    applied: bool = False
    success_outcome: bool = False
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    _id: Optional[str] = None

# ==================== CAREER CACHE ====================
class CareerCache(VersionedBaseModel):
    analysis_id: Optional[str] = None
    generated_at: datetime = Field(default_factory=datetime.utcnow)
    top_career_match: str = ""
    match_score: float = 0
    top_skills: List[str] = Field(default_factory=list)
    immediate_actions: List[str] = Field(default_factory=list)
    analysis_hash: Optional[str] = None
    version: int = 1

# ==================== SESSION INFO ====================
class SessionInfo(VersionedBaseModel):
    session_id: str
    session_hash: str
    device: str
    login_time: datetime
    ip: str
    last_activity: datetime = Field(default_factory=datetime.utcnow)

# ==================== EDUCATIONAL BACKGROUND ====================
class EducationalBackground(VersionedBaseModel):
    highest_qualification: str = ""
    total_years_of_education: int = 0
    fields_of_study: List[str] = Field(default_factory=list)
    institutions_attended: List[str] = Field(default_factory=list)
    gap_in_education: bool = False
    gap_explanation: Optional[str] = None

# ==================== CAREER ASPIRATIONS ====================
class CareerAspirations(VersionedBaseModel):
    ultimate_career_goal: Optional[str] = None
    dream_role: Optional[str] = None
    dream_industry: Optional[str] = None
    dream_company: Optional[str] = None
    desired_work_countries: List[str] = Field(default_factory=list)
    entrepreneurial_interest: bool = False
    freelance_interest: bool = False
    remote_work_interest: bool = True
    startup_interest: bool = False
    corporate_interest: bool = True
    government_job_interest: bool = False

# ==================== LEARNING PREFERENCES ====================
class LearningPreferences(VersionedBaseModel):
    preferred_learning_method: str = "online"
    available_learning_hours_per_week: int = 5
    learning_budget_per_month: Optional[int] = None
    interested_certifications: List[str] = Field(default_factory=list)
    interested_skill_categories: List[str] = Field(default_factory=list)
    preferred_learning_platforms: List[str] = Field(default_factory=list)
    mentorship_required: bool = False
    study_group_interest: bool = False

# ==================== INCOME & EXPENSE ====================
class IncomeExpense(VersionedBaseModel):
    current_monthly_income: Optional[int] = None
    expected_monthly_income: Optional[int] = None
    monthly_expenses: Optional[int] = None
    monthly_savings: Optional[int] = None
    existing_loans: bool = False
    loan_amount: Optional[int] = None
    loan_emi: Optional[int] = None
    dependents_count: int = 0
    earning_members_count: int = 0

# ==================== REFERENCES ====================
class Reference(VersionedBaseModel):
    name: str
    designation: str
    company: str
    phone: str
    email: str
    relationship: str
    _id: Optional[str] = None

class References(VersionedBaseModel):
    references: List[Reference] = Field(default_factory=list)

# ==================== PERSONAL INFO (COMBINED) ====================
class PersonalInfo(VersionedBaseModel):
    full_name: str = ""
    first_name: str = ""
    middle_name: str = ""
    last_name: str = ""
    gender: str = "Male"
    dob: Optional[str] = None
    age: Optional[int] = None
    blood_group: Optional[str] = None
    nationality: str = "Indian"
    religion: Optional[str] = None
    category: str = "General/UR"
    preferred_name: Optional[str] = None
    pronouns: Optional[str] = None
    profile_picture_url: Optional[str] = None
    cover_photo_url: Optional[str] = None
    bio: Optional[str] = None

# ==================== CONTACT INFO (COMBINED) ====================
class ContactInfo(VersionedBaseModel):
    email: EmailStr
    phone: Optional[str] = None
    alternate_mobile: Optional[str] = None
    whatsapp_number: Optional[str] = None
    emergency_contact: EmergencyContact = Field(default_factory=EmergencyContact)

# ==================== FAMILY INFO (COMBINED) ====================
class FamilyInfo(VersionedBaseModel):
    father_name: Optional[str] = None
    mother_name: Optional[str] = None
    guardian_name: Optional[str] = None
    spouse_name: Optional[str] = None
    marital_status: str = "Unmarried"
    family_annual_income: Optional[int] = None
    number_of_dependents: Optional[int] = None

# ==================== PHYSICAL ATTRIBUTES (COMBINED) ====================
class PhysicalAttributes(VersionedBaseModel):
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    eye_sight: Optional[str] = None
    blood_group: Optional[str] = None

# ==================== EDUCATION SUMMARY (COMBINED) ====================
class EducationSummary(VersionedBaseModel):
    highest_qualification: str = ""
    total_years_of_education: int = 0
    fields_of_study: List[str] = Field(default_factory=list)
    institutions_attended: List[str] = Field(default_factory=list)
    is_educated: bool = True
    is_pursuing_education: bool = False
    expected_graduation_year: Optional[int] = None

# ==================== EXPERIENCE SUMMARY (COMBINED) ====================
class ExperienceSummary(VersionedBaseModel):
    total_years: float = 0
    total_months: int = 0
    current_company: Optional[str] = None
    current_designation: Optional[str] = None
    is_fresher: bool = True
    current_salary: Optional[int] = None
    has_leadership_experience: bool = False
    industries: List[str] = Field(default_factory=list)

# ==================== SKILL SUMMARY (COMBINED) ====================
class SkillSummary(VersionedBaseModel):
    total_skills: int = 0
    expert_skills: List[str] = Field(default_factory=list)
    advanced_skills: List[str] = Field(default_factory=list)
    intermediate_skills: List[str] = Field(default_factory=list)
    beginner_skills: List[str] = Field(default_factory=list)
    top_skills: List[str] = Field(default_factory=list)

# ==================== JOB PREFERENCES (COMBINED) ====================
class JobPreferences(VersionedBaseModel):
    preferred_job_types: List[str] = Field(default_factory=list)
    preferred_industries: List[str] = Field(default_factory=list)
    preferred_locations: List[str] = Field(default_factory=list)
    expected_salary_min: Optional[int] = None
    expected_salary_max: Optional[int] = None
    open_to_relocate: bool = False
    open_to_remote_work: bool = False

# ==================== VERIFICATION STATUS (COMBINED) ====================
class VerificationStatus(VersionedBaseModel):
    email_verified: bool = False
    mobile_verified: bool = False
    aadhar_verified: bool = False
    pan_verified: bool = False
    disability_verified: bool = False
    profile_completed: bool = False
    profile_completion_percentage: int = 0

# ==================== PROFILE SUMMARY (MASTER) ====================
class ProfileSummary(VersionedBaseModel):
    schema_version: str = ModelVersion.LATEST
    generated_at: datetime = Field(default_factory=datetime.utcnow)
    personal: PersonalInfo = Field(default_factory=PersonalInfo)
    contact: ContactInfo = Field(default_factory=lambda: ContactInfo(email="temp@example.com"))
    family: FamilyInfo = Field(default_factory=FamilyInfo)
    physical: PhysicalAttributes = Field(default_factory=PhysicalAttributes)
    disability: DisabilityInfo = Field(default_factory=DisabilityInfo)
    education: EducationSummary = Field(default_factory=EducationSummary)
    experience: ExperienceSummary = Field(default_factory=ExperienceSummary)
    skills: SkillSummary = Field(default_factory=SkillSummary)
    job_preferences: JobPreferences = Field(default_factory=JobPreferences)
    location_preferences: LocationPreferences = Field(default_factory=LocationPreferences)
    compensation: CompensationExpectations = Field(default_factory=CompensationExpectations)
    verification: VerificationStatus = Field(default_factory=VerificationStatus)
    languages_known: List[str] = Field(default_factory=list)
    social_links: SocialLinks = Field(default_factory=SocialLinks)
    career_goals: CareerGoals = Field(default_factory=CareerGoals)
    personality_traits: PersonalityTraits = Field(default_factory=PersonalityTraits)
    custom_data: Dict[str, Any] = Field(default_factory=dict)

# ==================== MAIN PROFILE MODEL ====================
class ProfileModel(VersionedBaseModel):
    """Main Profile Model with versioning and extensibility - NO TOP-LEVEL DISABILITY FIELDS"""
    
    schema_version: str = ModelVersion.LATEST
    schema_migrated_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Core fields
    email: EmailStr
    full_name: str = ""
    first_name: str = ""
    middle_name: str = ""
    last_name: str = ""
    
    # Optional personal fields
    phone: Optional[str] = None
    dob: Optional[str] = None
    gender: str = "Male"
    blood_group: Optional[str] = None
    nationality: str = "Indian"
    religion: Optional[str] = None
    category: str = "General/UR"
    
    # Physical attributes
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    eye_sight: Optional[str] = None
    
    # ==================== DISABILITY - ONLY NESTED OBJECT ====================
    # ⚠️ NO top-level fields like is_disable, disability_category, etc.
    # Use ONLY the nested disability object
    disability: DisabilityInfo = Field(default_factory=DisabilityInfo)
    
    # Family details
    father_name: Optional[str] = None
    mother_name: Optional[str] = None
    guardian_name: Optional[str] = None
    spouse_name: Optional[str] = None
    marital_status: str = "Unmarried"
    family_annual_income: Optional[int] = None
    number_of_dependents: Optional[int] = None
    
    # Contact
    alternate_mobile: Optional[str] = None
    whatsapp_number: Optional[str] = None
    emergency_contact: EmergencyContact = Field(default_factory=EmergencyContact)
    
    # Address
    current_address: Address = Field(default_factory=Address)
    permanent_address: Optional[Address] = None
    same_as_current: bool = True
    
    # KYC & Documents
    government_ids: GovernmentIDs = Field(default_factory=GovernmentIDs)
    bank_details: BankDetails = Field(default_factory=BankDetails)
    social_links: SocialLinks = Field(default_factory=SocialLinks)
    work_authorization: WorkAuthorization = Field(default_factory=WorkAuthorization)
    documents: Documents = Field(default_factory=Documents)
    
    # Professional
    summary: Optional[str] = None
    career_objective: Optional[str] = None
    academic_records: List[AcademicRecord] = Field(default_factory=list)
    experience: List[Experience] = Field(default_factory=list)
    internships: List[Internship] = Field(default_factory=list)
    skills: List[Skill] = Field(default_factory=list)
    certifications: List[Certification] = Field(default_factory=list)
    projects: List[Project] = Field(default_factory=list)
    extracurricular: List[Extracurricular] = Field(default_factory=list)
    languages: List[Language] = Field(default_factory=list)
    languages_known: List[str] = Field(default_factory=list)
    
    # Experience status
    currently_employed: bool = False
    current_company: Optional[str] = None
    current_designation: Optional[str] = None
    current_salary: Optional[int] = None
    total_experience_years: float = 0
    total_experience_months: int = 0
    employment_gaps: List[Dict[str, Any]] = Field(default_factory=list)
    is_fresher: bool = True
    
    # Education status
    is_educated: bool = True
    is_pursuing_education: bool = False
    expected_graduation_year: Optional[int] = None
    gap_in_education: bool = False
    gap_reason: Optional[str] = None
    
    # Career
    career_goals: CareerGoals = Field(default_factory=CareerGoals)
    career_goals_legacy: List[str] = Field(default_factory=list)
    domain_interests: List[str] = Field(default_factory=list)
    career_change_interest: bool = False
    previous_career_fields: List[str] = Field(default_factory=list)
    transferable_skills: List[str] = Field(default_factory=list)
    reason_for_career_change: Optional[str] = None
    target_career_fields: List[str] = Field(default_factory=list)
    
    # Job search
    actively_looking_for_job: bool = False
    notice_period_days: Optional[int] = None
    can_join_immediately: bool = False
    preferred_joining_date: Optional[str] = None
    available_for_full_time: bool = True
    available_for_part_time: bool = False
    available_for_contract: bool = False
    available_for_freelance: bool = False
    available_for_internship: bool = True
    
    # Preferences
    employment_preferences: EmploymentPreferences = Field(default_factory=EmploymentPreferences)
    application_preferences: ApplicationPreferences = Field(default_factory=ApplicationPreferences)
    job_search_preferences: JobSearchPreferences = Field(default_factory=JobSearchPreferences)
    work_environment_preferences: WorkEnvironmentPreferences = Field(default_factory=WorkEnvironmentPreferences)
    compensation_expectations: CompensationExpectations = Field(default_factory=CompensationExpectations)
    location_preferences: LocationPreferences = Field(default_factory=LocationPreferences)
    work_life_balance: WorkLifeBalance = Field(default_factory=WorkLifeBalance)
    
    # Advanced career
    personality_traits: PersonalityTraits = Field(default_factory=PersonalityTraits)
    skill_assessments: List[SkillAssessment] = Field(default_factory=list)
    skill_gap_analysis: Optional[SkillGapAnalysis] = None
    job_fit_scores: List[JobFitScore] = Field(default_factory=list)
    career_path_recommendations: List[CareerPathRecommendation] = Field(default_factory=list)
    education_goals: EducationGoal = Field(default_factory=EducationGoal)
    certification_goals: CertificationGoal = Field(default_factory=CertificationGoal)
    networking_preferences: NetworkingPreferences = Field(default_factory=NetworkingPreferences)
    
    # Financial
    financial_goals: FinancialGoals = Field(default_factory=FinancialGoals)
    income_expense: IncomeExpense = Field(default_factory=IncomeExpense)
    
    # Portfolio & References
    portfolio: Portfolio = Field(default_factory=Portfolio)
    references: References = Field(default_factory=References)
    
    # History & Tracking
    job_application_history: List[JobApplicationHistory] = Field(default_factory=list)
    ai_feedback_history: List[AIRecommendationFeedback] = Field(default_factory=list)
    
    # Additional info
    additional_details: AdditionalDetails = Field(default_factory=AdditionalDetails)
    educational_background: EducationalBackground = Field(default_factory=EducationalBackground)
    career_aspirations: CareerAspirations = Field(default_factory=CareerAspirations)
    learning_preferences: LearningPreferences = Field(default_factory=LearningPreferences)
    
    # Basic literacy
    can_read: bool = False
    can_write: bool = False
    basic_education_level: str = "None"
    basic_skills: List[str] = Field(default_factory=list)
    
    # Fresher specific
    internship_details: str = ""
    training_program: str = ""
    daily_wage: Optional[int] = None
    projects_done: str = ""
    certifications_list: List[str] = Field(default_factory=list)
    labour_type: str = "Mason"
    
    # Student info
    current_status: str = Field(default="student", pattern="^(student|fresher|working|unemployed)$")
    college_name: Optional[str] = None
    passing_year: Optional[int] = None
    has_backlogs: bool = False
    
    # Cache fields
    career_cache: Optional[CareerCache] = None
    career_cache_updated_at: Optional[datetime] = None
    learning_path_cache: Optional[Dict[str, Any]] = None
    learning_path_updated_at: Optional[datetime] = None
    active_sessions: List[SessionInfo] = Field(default_factory=list, max_length=5)
    market_cache: Optional[Dict[str, Any]] = None
    market_cache_updated_at: Optional[datetime] = None
    skill_demand_cache: Optional[Dict[str, Any]] = None
    
    # AI Features
    embedding: Optional[List[float]] = None
    ai_enriched: bool = False
    last_ai_update: Optional[datetime] = None
    
    # System
    role: str = "user"
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    
    _cached_summary: Optional[ProfileSummary] = None
    
    # ==================== HELPER METHODS ====================
    
    @property
    def is_disabled(self) -> bool:
        """Get disability status from nested object"""
        return self.disability.is_disabled
    
    @property
    def disability_display(self) -> str:
        """Get disability display string from nested object"""
        if not self.disability.is_disabled:
            return "No disability"
        if self.disability.disability_percentage:
            return f"{self.disability.display_category} ({self.disability.disability_percentage:.0f}%)"
        return self.disability.display_category
    
    @property
    def disability_status(self) -> str:
        """Get disability status from nested object"""
        if not self.disability.is_disabled:
            return "not_applicable"
        if self.disability.certificate_verified:
            return "verified"
        if self.disability.certificate_url:
            return "pending_verification"
        return "not_verified"
    
    def get_disability_summary(self) -> Dict[str, Any]:
        """Get disability summary from nested object"""
        return {
            "has_disability": self.disability.is_disabled,
            "category": self.disability.disability_category,
            "category_name": self.disability.display_category,
            "percentage": self.disability.disability_percentage,
            "is_verified": self.disability.certificate_verified,
            "status": self.disability_status,
            "details": self.disability.disability_details,
            "accommodations": self.disability.accommodation_needed
        }
    
    @classmethod
    def migrate_from_legacy(cls, old_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Migrate data from old schema to new schema
        CONVERTS TOP-LEVEL DISABILITY FIELDS TO NESTED OBJECT
        """
        new_data = old_data.copy()
        
        # CRITICAL: Convert top-level disability fields to nested object
        if any(field in old_data for field in ['is_disable', 'disability_category', 
                                                 'disability_percentage', 'physically_challenged', 
                                                 'disability_details']):
            new_data['disability'] = {
                'is_disabled': old_data.get('is_disable', False),
                'disability_category': old_data.get('disability_category'),
                'disability_percentage': old_data.get('disability_percentage'),
                'disability_details': old_data.get('disability_details', ''),
                'physically_challenged': old_data.get('physically_challenged', 'No'),
            }
            
            # Remove old top-level fields to prevent duplicates
            for field in ['is_disable', 'disability_category', 'disability_percentage', 
                         'physically_challenged', 'disability_details']:
                if field in new_data:
                    del new_data[field]
        
        # Also handle address field for backward compatibility
        if 'address' in old_data and isinstance(old_data['address'], dict):
            new_data['current_address'] = old_data['address']
        
        new_data['schema_version'] = ModelVersion.LATEST
        new_data['schema_migrated_at'] = datetime.utcnow().isoformat()
        
        return new_data
    
    @property
    def summary(self) -> ProfileSummary:
        """Get complete profile summary"""
        if self._cached_summary:
            return self._cached_summary
        
        # Calculate age
        age = None
        if self.dob:
            try:
                birth = datetime.strptime(self.dob, "%Y-%m-%d")
                today = datetime.now()
                age = today.year - birth.year
                if today.month < birth.month or (today.month == birth.month and today.day < birth.day):
                    age -= 1
            except:
                pass
        
        # Calculate total experience
        total_exp_years = 0
        industries = []
        has_leadership = False
        for exp in self.experience:
            total_exp_years += 1
            if exp.industry_type:
                industries.append(exp.industry_type)
            if 'lead' in exp.role.lower() or 'manage' in exp.role.lower():
                has_leadership = True
        
        # Skill categorization
        expert_skills = []
        advanced_skills = []
        intermediate_skills = []
        beginner_skills = []
        for skill in self.skills:
            if skill.level == 'expert':
                expert_skills.append(skill.name)
            elif skill.level == 'advanced':
                advanced_skills.append(skill.name)
            elif skill.level == 'intermediate':
                intermediate_skills.append(skill.name)
            else:
                beginner_skills.append(skill.name)
        
        # Calculate profile completion
        completion = self._calculate_completion()
        
        # Get highest qualification
        highest_qualification = ""
        if self.academic_records:
            highest_qualification = self.academic_records[-1].degree or ""
        
        # Get fields of study
        fields_of_study = [edu.stream for edu in self.academic_records if edu.stream]
        
        # Get institutions
        institutions = [edu.institute for edu in self.academic_records if edu.institute]
        
        self._cached_summary = ProfileSummary(
            personal=PersonalInfo(
                full_name=self.full_name,
                first_name=self.first_name,
                middle_name=self.middle_name,
                last_name=self.last_name,
                gender=self.gender,
                dob=self.dob,
                age=age,
                blood_group=self.blood_group,
                nationality=self.nationality,
                religion=self.religion,
                category=self.category,
            ),
            contact=ContactInfo(
                email=self.email,
                phone=self.phone,
                alternate_mobile=self.alternate_mobile,
                whatsapp_number=self.whatsapp_number,
                emergency_contact=self.emergency_contact,
            ),
            family=FamilyInfo(
                father_name=self.father_name,
                mother_name=self.mother_name,
                guardian_name=self.guardian_name,
                spouse_name=self.spouse_name,
                marital_status=self.marital_status,
                family_annual_income=self.family_annual_income,
                number_of_dependents=self.number_of_dependents,
            ),
            physical=PhysicalAttributes(
                height_cm=self.height_cm,
                weight_kg=self.weight_kg,
                eye_sight=self.eye_sight,
                blood_group=self.blood_group,
            ),
            disability=self.disability,
            education=EducationSummary(
                highest_qualification=highest_qualification,
                total_years_of_education=len(self.academic_records) * 3,
                fields_of_study=fields_of_study,
                institutions_attended=institutions,
                is_educated=self.is_educated,
                is_pursuing_education=self.is_pursuing_education,
                expected_graduation_year=self.expected_graduation_year,
            ),
            experience=ExperienceSummary(
                total_years=total_exp_years,
                total_months=int(total_exp_years * 12),
                current_company=self.current_company,
                current_designation=self.current_designation,
                is_fresher=self.is_fresher,
                current_salary=self.current_salary,
                has_leadership_experience=has_leadership,
                industries=list(set(industries)),
            ),
            skills=SkillSummary(
                total_skills=len(self.skills),
                expert_skills=expert_skills,
                advanced_skills=advanced_skills,
                intermediate_skills=intermediate_skills,
                beginner_skills=beginner_skills,
                top_skills=expert_skills + advanced_skills[:5],
            ),
            job_preferences=JobPreferences(
                preferred_job_types=self.additional_details.preferred_job_types,
                preferred_industries=self.additional_details.preferred_industries,
                preferred_locations=self.additional_details.preferred_locations,
                expected_salary_min=self.compensation_expectations.expected_salary_min,
                expected_salary_max=self.compensation_expectations.expected_salary_max,
                open_to_relocate=self.additional_details.open_to_relocate,
                open_to_remote_work=any('remote' in mode.lower() for mode in self.additional_details.preferred_job_types),
            ),
            location_preferences=self.location_preferences,
            compensation=self.compensation_expectations,
            verification=VerificationStatus(
                email_verified=True,
                mobile_verified=True,
                aadhar_verified=self.government_ids.aadhar_verified,
                pan_verified=self.government_ids.pan_verified,
                disability_verified=self.disability.certificate_verified,
                profile_completed=completion >= 70,
                profile_completion_percentage=completion,
            ),
            languages_known=self.languages_known,
            social_links=self.social_links,
            career_goals=self.career_goals,
            personality_traits=self.personality_traits,
        )
        return self._cached_summary
    
    def _calculate_completion(self) -> int:
        """Calculate profile completion percentage"""
        completion = 0
        if self.full_name:
            completion += 10
        if self.email:
            completion += 10
        if self.phone:
            completion += 10
        if self.academic_records:
            completion += 15
        if self.skills:
            completion += 15
        if self.experience and not self.is_fresher:
            completion += 20
        if self.current_address.district:
            completion += 10
        if self.current_address.state:
            completion += 10
        return min(100, completion)
    
    def clear_summary_cache(self) -> None:
        """Clear cached summary"""
        self._cached_summary = None
    
    @field_validator("full_name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        if not v or not v.strip():
            return ""
        return v.strip()
    
    @model_validator(mode='after')
    def set_updated_at(self):
        self.updated_at = datetime.utcnow()
        return self
    
    class Config:
        collection = "profile"
        arbitrary_types_allowed = True
        populate_by_name = True
        extra = "allow"
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            ObjectId: lambda v: str(v)
        }

# ==================== EXPORT ALL MODELS ====================
__all__ = [
    "ModelVersion",
    "SchemaMetadata",
    "ExtensibleMetadata",
    "VersionedBaseModel",
    "Language",
    "Address",
    "EmergencyContact",
    "DisabilityInfo",
    "GovernmentIDs",
    "BankDetails",
    "SocialLinks",
    "WorkAuthorization",
    "Document",
    "Documents",
    "AcademicRecord",
    "Skill",
    "Experience",
    "Internship",
    "Certification",
    "Project",
    "Extracurricular",
    "EmploymentPreferences",
    "ApplicationPreferences",
    "CareerGoals",
    "PersonalityTraits",
    "WorkEnvironmentPreferences",
    "CompensationExpectations",
    "JobSearchPreferences",
    "LocationPreferences",
    "AdditionalDetails",
    "SkillAssessment",
    "SkillGapAnalysis",
    "JobFitScore",
    "CareerPathRecommendation",
    "EducationGoal",
    "CertificationGoal",
    "NetworkingPreferences",
    "WorkLifeBalance",
    "FinancialGoals",
    "Portfolio",
    "JobApplicationHistory",
    "AIRecommendationFeedback",
    "CareerCache",
    "SessionInfo",
    "EducationalBackground",
    "CareerAspirations",
    "LearningPreferences",
    "IncomeExpense",
    "Reference",
    "References",
    "PersonalInfo",
    "ContactInfo",
    "FamilyInfo",
    "PhysicalAttributes",
    "EducationSummary",
    "ExperienceSummary",
    "SkillSummary",
    "JobPreferences",
    "VerificationStatus",
    "ProfileSummary",
    "ProfileModel",
]

print("✅ Future-Proof Profile Model Loaded Successfully")
print("   Features: Versioning, Extensibility, Migration Support, Backward Compatibility")
print("   ✅ FIXED: Only nested disability object - NO TOP-LEVEL DUPLICATES")
print(f"   Total Models: {len(__all__)}")