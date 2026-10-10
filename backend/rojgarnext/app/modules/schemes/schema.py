# app/modules/schemes/schema.py
"""
Government Schemes - Pydantic Schemas
Complete schema definitions for scheme data and applications
"""

from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional, List, Dict, Any
from datetime import datetime
from enum import Enum


# ============================================================
# ENUMS
# ============================================================

class SchemeLevel(str, Enum):
    """Scheme level - Central or State Government"""
    CENTRAL = "central"
    STATE = "state"


class SchemeStatus(str, Enum):
    """Scheme application status"""
    DRAFT = "draft"
    SAVED = "saved"
    PENDING = "pending"
    PENDING_VERIFICATION = "pending_verification"
    UNDER_REVIEW = "under_review"
    REVIEW_APPLICATION = "review_application"
    APPROVED = "approved"
    APPROVED_APPLICATION = "approved_application"
    REJECTED = "rejected"
    COMPLETED = "completed"
    PAYMENT_PENDING = "payment_pending"
    PAYMENT_VERIFIED = "payment_verified"
    VERIFICATION_SUCCESSFUL = "verification_successful"
    VERIFICATION_REJECTED = "verification_rejected"
    UPDATE_APPLICATION = "update_application"
    CONFIRMED_APPLICATION = "confirmed_application"
    FINAL_SUBMITTED = "final_submitted"


class SchemeCategory(str, Enum):
    """Scheme categories"""
    AGRICULTURE = "agriculture"
    EDUCATION = "education"
    HEALTH = "health"
    HOUSING = "housing"
    EMPLOYMENT = "employment"
    WOMEN_CHILD = "women_child"
    SOCIAL_WELFARE = "social_welfare"
    FINANCIAL_INCLUSION = "financial_inclusion"
    PENSION = "pension"
    INSURANCE = "insurance"
    SKILL_DEVELOPMENT = "skill_development"
    ENTREPRENEURSHIP = "entrepreneurship"
    DISABILITY = "disability"
    SC_ST_WELFARE = "sc_st_welfare"
    MINORITY_WELFARE = "minority_welfare"
    OTHER = "other"


# ============================================================
# SCHEME DETAILS MODEL
# ============================================================

class SchemeBenefit(BaseModel):
    """Individual benefit offered by scheme"""
    title: str
    description: str
    amount: Optional[str] = None
    type: str = Field(default="financial", pattern="^(financial|non_financial|service|training)$")


class SchemeEligibility(BaseModel):
    """Eligibility criteria for scheme"""
    age_min: Optional[int] = Field(None, ge=0, le=100)
    age_max: Optional[int] = Field(None, ge=0, le=100)
    gender: Optional[str] = Field(None, pattern="^(male|female|all|transgender)$")
    income_limit: Optional[int] = None  # Annual income in rupees
    category: Optional[List[str]] = None  # General, OBC, SC, ST, EWS
    education_level: Optional[str] = None
    occupation: Optional[str] = None
    domicile_state: Optional[str] = None  # Required state domicile
    disability_required: bool = False
    bpl_required: bool = False
    aadhaar_required: bool = True
    other_conditions: Optional[List[str]] = None


class SchemeDocument(BaseModel):
    """Required document for scheme application"""
    name: str
    name_hindi: str
    required: bool = True
    description: Optional[str] = None


class SchemeApplicationStep(BaseModel):
    """Step in application process"""
    step_number: int
    title: str
    title_hindi: str
    description: str
    description_hindi: str


class SchemeContactInfo(BaseModel):
    """Contact information for scheme"""
    helpline: Optional[str] = None
    email: Optional[str] = None
    website: Optional[str] = None
    office_address: Optional[str] = None


class SchemeModel(BaseModel):
    """
    Complete Government Scheme Model
    """
    # Basic Info
    scheme_id: str = Field(..., description="Unique scheme identifier")
    scheme_name: str
    scheme_name_hindi: str
    short_description: str
    short_description_hindi: str
    
    # Level & Category
    level: str = Field(default="central", pattern="^(central|state)$")
    state: Optional[str] = None  # Required if level is state
    category: str = Field(default="other")
    sub_category: Optional[str] = None
    
    # Detailed Info
    full_description: str
    full_description_hindi: str
    benefits: List[SchemeBenefit] = Field(default_factory=list)
    eligibility: SchemeEligibility = Field(default_factory=SchemeEligibility)
    eligibility_details_hindi: str = ""
    
    # Who can apply (Target Beneficiaries)
    target_beneficiaries: List[str] = Field(default_factory=list)
    target_beneficiaries_hindi: List[str] = Field(default_factory=list)
    
    # Documents Required
    required_documents: List[SchemeDocument] = Field(default_factory=list)
    
    # Application Process
    application_steps: List[SchemeApplicationStep] = Field(default_factory=list)
    application_mode: str = Field(default="online", pattern="^(online|offline|both)$")
    
    # Important Dates
    application_start_date: Optional[str] = None
    application_end_date: Optional[str] = None
    is_always_open: bool = True
    
    # Contact
    contact_info: SchemeContactInfo = Field(default_factory=SchemeContactInfo)
    
    # Official Links
    official_website: Optional[str] = None
    apply_link: Optional[str] = None
    notification_pdf_url: Optional[str] = None
    
    # Fees
    has_application_fee: bool = False
    application_fee: Optional[int] = 0
    fee_details_hindi: Optional[str] = None
    
    # Display
    icon: str = "📋"
    color: str = "blue"
    priority: int = Field(default=5, ge=1, le=10)
    is_featured: bool = False
    is_active: bool = True
    
    # Metadata
    tags: List[str] = Field(default_factory=list)
    search_keywords: List[str] = Field(default_factory=list)
    
    # Timestamps
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    
    class Config:
        collection = "schemes"
        use_enum_values = True
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }


# ============================================================
# SCHEME APPLICATION MODEL
# ============================================================

class SchemeApplicantDetails(BaseModel):
    """Applicant personal details"""
    full_name: str
    full_name_hindi: Optional[str] = None
    father_name: Optional[str] = None
    mother_name: Optional[str] = None
    date_of_birth: str
    gender: str
    category: str  # General, OBC, SC, ST, EWS
    religion: Optional[str] = None
    marital_status: Optional[str] = None
    aadhaar_number: Optional[str] = None
    mobile: str
    email: EmailStr
    annual_income: Optional[int] = None
    bpl_status: bool = False
    disability_status: bool = False
    disability_percentage: Optional[float] = None


class SchemeApplicantAddress(BaseModel):
    """Applicant address details"""
    address_line1: str
    address_line2: Optional[str] = None
    village_city: str
    district: str
    state: str
    pincode: str
    country: str = "India"


class SchemeBankDetails(BaseModel):
    """Bank details for benefit transfer"""
    account_holder_name: str
    bank_name: str
    account_number: str
    ifsc_code: str
    branch_name: Optional[str] = None
    account_type: str = "savings"


class SchemeApplicationDocument(BaseModel):
    """Uploaded document for application"""
    document_type: str
    document_name: str
    document_url: str
    public_id: Optional[str] = None
    uploaded_at: datetime = Field(default_factory=datetime.utcnow)
    verified: bool = False


class SchemeApplicationModel(BaseModel):
    """
    Government Scheme Application Model
    Stored in 'scheme_applications' collection
    """
    # Application Info
    application_id: Optional[str] = None
    
    # User Info
    user_email: EmailStr
    user_id: Optional[str] = None
    user_name: str
    user_mobile: Optional[str] = None
    
    # Scheme Info
    scheme_id: str
    scheme_name: str
    scheme_name_hindi: str
    scheme_level: str  # central or state
    scheme_state: Optional[str] = None
    scheme_category: str
    
    # Applicant Details
    applicant_details: SchemeApplicantDetails
    applicant_address: SchemeApplicantAddress
    bank_details: Optional[SchemeBankDetails] = None
    
    # Uploaded Documents
    documents: List[SchemeApplicationDocument] = Field(default_factory=list)
    
    # Additional Info
    additional_info: Optional[Dict[str, Any]] = None
    remarks: Optional[str] = None
    
    # Status
    status: str = Field(default="draft")
    payment_verification_status: str = "not_submitted"
    
    # Payment (if applicable)
    payment_amount: Optional[int] = None
    payment_id: Optional[str] = None
    payment_method: str = "razorpay"
    razorpay_order_id: Optional[str] = None
    razorpay_payment_id: Optional[str] = None
    razorpay_signature: Optional[str] = None
    payment_receipt_url: Optional[str] = None
    transaction_id: Optional[str] = None
    paid_at: Optional[datetime] = None
    payment_verified_at: Optional[datetime] = None
    payment_verified_by: Optional[str] = None
    payment_rejection_reason: Optional[str] = None
    
    # Admin Actions
    admin_notes: Optional[str] = None
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    
    # Document Submission (Admin)
    submitted_document_url: Optional[str] = None
    submitted_document_name: Optional[str] = None
    submitted_document_public_id: Optional[str] = None
    submitted_at: Optional[datetime] = None
    submitted_by: Optional[str] = None
    
    # Final Submission
    final_document_url: Optional[str] = None
    final_document_name: Optional[str] = None
    final_submitted_at: Optional[datetime] = None
    final_submitted_by: Optional[str] = None
    
    # Updates
    application_updates: List[Dict[str, Any]] = Field(default_factory=list)
    update_notes: Optional[str] = None
    update_submitted_at: Optional[datetime] = None
    update_submitted_by: Optional[str] = None
    update_approved_at: Optional[datetime] = None
    update_approved_by: Optional[str] = None
    update_rejected_at: Optional[datetime] = None
    update_rejected_by: Optional[str] = None
    admin_update_notes: Optional[str] = None
    
    # Timestamps
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    applied_at: Optional[datetime] = None
    
    # Archive
    is_archived: bool = False
    archived_at: Optional[datetime] = None
    archived_reason: Optional[str] = None
    
    class Config:
        collection = "scheme_applications"
        use_enum_values = True
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }


# ============================================================
# REQUEST/RESPONSE SCHEMAS
# ============================================================

class SchemeListResponse(BaseModel):
    """Response for scheme list"""
    success: bool = True
    schemes: List[Dict[str, Any]]
    total: int
    page: int = 1
    limit: int = 50


class SchemeDetailResponse(BaseModel):
    """Response for single scheme detail"""
    success: bool = True
    scheme: Dict[str, Any]


class SchemeApplicationCreateSchema(BaseModel):
    """Schema for creating scheme application"""
    scheme_id: str
    applicant_details: SchemeApplicantDetails
    applicant_address: SchemeApplicantAddress
    bank_details: Optional[SchemeBankDetails] = None
    additional_info: Optional[Dict[str, Any]] = None
    remarks: Optional[str] = None


class SchemeApplicationStatusUpdateSchema(BaseModel):
    """Schema for updating application status"""
    status: str
    notes: Optional[str] = None


class SchemeApplicationResponse(BaseModel):
    """Response for scheme application"""
    success: bool = True
    application_id: str
    message: str
    status: str


class SchemeFilterSchema(BaseModel):
    """Schema for filtering schemes"""
    level: Optional[str] = None  # central, state, all
    state: Optional[str] = None
    category: Optional[str] = None
    search: Optional[str] = None
    is_featured: Optional[bool] = None
    limit: int = Field(default=50, ge=1, le=200)
    skip: int = Field(default=0, ge=0)


print("✅ Schemes Schema Loaded Successfully")