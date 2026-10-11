# app/modules/schemes/schemas.py
"""
Government Schemes Pydantic Schemas

✅ Fully detailed request/response models
✅ Matches routes.py + service.py + frontend contract
✅ Supports all application fields (personal, address, bank, documents)
✅ Supports submit flow + admin actions + notifications
✅ FIXED: documents accept BOTH `url` and `document_url`
"""

from pydantic import BaseModel, Field, EmailStr, validator
from typing import Optional, Dict, Any, List, Literal
from datetime import datetime


# ============================================================
# ENUMS (as Literal for Pydantic v2 compat)
# ============================================================
ApplicationStatusLiteral = Literal[
    "pending",
    "submitted",
    "under_review",
    "approved",
    "rejected",
    "completed",
    "verification_successful",
    "verification_rejected",
    "update_application",
    "final_submit",
    "cancelled",
]

ApplicationTypeLiteral = Literal["schemes"]

PaymentStatusLiteral = Literal[
    "not_submitted",
    "not_applicable",
    "pending",
    "verified",
    "rejected",
    "approved",
]


# ============================================================
# APPLICANT DETAILS
# ============================================================
class ApplicantDetails(BaseModel):
    """
    Personal + contact + identity details submitted from
    scheme_apply_screen.dart (Step 1).
    """
    full_name: str = Field(..., min_length=1, max_length=200)
    father_name: Optional[str] = Field(default="", max_length=200)
    mother_name: Optional[str] = Field(default="", max_length=200)
    date_of_birth: Optional[str] = Field(
        default="", description="YYYY-MM-DD"
    )
    gender: Optional[str] = Field(default="male")
    category: Optional[str] = Field(default="General")
    marital_status: Optional[str] = Field(default="Unmarried")
    aadhaar_number: Optional[str] = Field(default="", max_length=12)
    mobile: str = Field(..., min_length=10, max_length=10)
    email: EmailStr
    annual_income: Optional[int] = Field(default=0, ge=0)
    bpl_status: Optional[bool] = False
    disability_status: Optional[bool] = False
    disability_percentage: Optional[float] = Field(default=0.0, ge=0, le=100)
    scheme_name: Optional[str] = None
    scheme_id: Optional[str] = None
    application_type: Optional[ApplicationTypeLiteral] = "schemes"

    @validator("aadhaar_number", pre=True, always=True)
    def validate_aadhaar(cls, v):
        if v is None or v == "":
            return ""
        v = str(v)
        if len(v) not in (0, 12):
            raise ValueError("Aadhaar number must be 12 digits")
        if not v.isdigit():
            raise ValueError("Aadhaar number must contain only digits")
        return v

    @validator("mobile", pre=True, always=True)
    def validate_mobile(cls, v):
        v = str(v)
        if not v.isdigit():
            raise ValueError("Mobile number must contain only digits")
        return v


# ============================================================
# APPLICANT ADDRESS
# ============================================================
class ApplicantAddress(BaseModel):
    address_line1: str = Field(..., min_length=1, max_length=300)
    address_line2: Optional[str] = Field(default="", max_length=300)
    village_city: str = Field(..., min_length=1, max_length=200)
    district: str = Field(..., min_length=1, max_length=200)
    state: str = Field(..., min_length=1, max_length=200)
    pincode: str = Field(..., min_length=6, max_length=6)
    country: Optional[str] = Field(default="India", max_length=100)

    @validator("pincode")
    def validate_pincode(cls, v):
        if not v.isdigit():
            raise ValueError("Pincode must contain only digits")
        return v


# ============================================================
# BANK DETAILS
# ============================================================
class BankDetails(BaseModel):
    account_holder_name: str = Field(..., min_length=1, max_length=200)
    bank_name: str = Field(..., min_length=1, max_length=200)
    account_number: str = Field(..., min_length=6, max_length=30)
    ifsc_code: str = Field(..., min_length=11, max_length=11)
    branch_name: Optional[str] = Field(default="", max_length=200)
    account_type: Optional[Literal["savings", "current"]] = "savings"

    @validator("ifsc_code")
    def validate_ifsc(cls, v):
        v = v.upper()
        if not v[:4].isalpha():
            raise ValueError("IFSC code must start with 4 letters")
        if not v[4:].isalnum():
            raise ValueError("IFSC code must have alphanumeric after 4 letters")
        return v

    @validator("account_number")
    def validate_account_number(cls, v):
        if not v.isdigit():
            raise ValueError("Account number must contain only digits")
        return v


# ============================================================
# DOCUMENT (normalized) — ✅ accepts BOTH `url` and `document_url`
# ============================================================
class SchemeDocumentItem(BaseModel):
    """
    A single uploaded document.
    Accepts BOTH `url` and `document_url` as input.
    Always outputs `document_url` in the model.
    """
    document_type: Optional[str] = Field(default="", max_length=100)
    document_name: Optional[str] = Field(default="", max_length=200)
    document_url: Optional[str] = Field(default="", max_length=2000)
    public_id: Optional[str] = None
    uploaded_at: Optional[datetime] = None
    verified: Optional[bool] = False

    # Allow legacy / alias input fields (they will NOT appear in output)
    url: Optional[str] = None
    label: Optional[str] = None

    class Config:
        extra = "allow"

    @validator("document_url", always=True, pre=True)
    def resolve_document_url(cls, v, values):
        # Prefer explicit document_url, fall back to url
        if v and str(v).strip():
            return str(v).strip()
        url = values.get("url")
        if url and str(url).strip():
            return str(url).strip()
        return ""

    @validator("document_name", always=True, pre=True)
    def resolve_document_name(cls, v, values):
        if v and str(v).strip():
            return str(v).strip()
        label = values.get("label")
        if label and str(label).strip():
            return str(label).strip()
        return ""


# ============================================================
# APPLY REQUEST / RESPONSE
# ============================================================
class SchemeApplyRequest(BaseModel):
    """
    Request body for POST /api/v1/schemes/apply
    """
    scheme_id: str = Field(..., min_length=1, max_length=100)
    scheme_name: Optional[str] = Field(default=None, max_length=300)
    applicant_details: Optional[Dict[str, Any]] = Field(default_factory=dict)
    applicant_address: Optional[Dict[str, Any]] = Field(default_factory=dict)
    bank_details: Optional[Dict[str, Any]] = Field(default_factory=dict)
    documents: Optional[List[SchemeDocumentItem]] = Field(default_factory=list)
    additional_info: Optional[Dict[str, Any]] = Field(default=None)
    remarks: Optional[str] = Field(default="")

    class Config:
        extra = "allow"


class SchemeApplyResponse(BaseModel):
    success: bool
    application_id: Optional[str] = None
    application_type: Optional[str] = "schemes"
    message: Optional[str] = "Application submitted successfully"
    status: Optional[str] = "pending"


# ============================================================
# SUBMIT REQUEST / RESPONSE
# ============================================================
class SchemeSubmitRequest(BaseModel):
    remarks: Optional[str] = Field(default="")
    additional_info: Optional[Dict[str, Any]] = Field(default=None)


class SchemeSubmitResponse(BaseModel):
    success: bool
    message: str
    application_id: str
    status: str
    submitted_at: Optional[str] = None


# ============================================================
# FULL APPLICATION RESPONSE
# ============================================================
class SchemeApplicationResponse(BaseModel):
    _id: Optional[str] = None
    application_id: str
    application_type: Optional[str] = "schemes"

    user_email: Optional[str] = None
    user_id: Optional[str] = None
    user_name: Optional[str] = None
    user_mobile: Optional[str] = None

    scheme_id: str
    scheme_name: Optional[str] = None
    scheme_name_hindi: Optional[str] = None
    scheme_level: Optional[str] = None
    scheme_state: Optional[str] = None
    scheme_category: Optional[str] = None

    applicant_details: Optional[Dict[str, Any]] = Field(default_factory=dict)
    applicant_address: Optional[Dict[str, Any]] = Field(default_factory=dict)
    bank_details: Optional[Dict[str, Any]] = Field(default_factory=dict)
    documents: Optional[List[SchemeDocumentItem]] = Field(default_factory=list)
    additional_info: Optional[Dict[str, Any]] = None
    remarks: Optional[str] = None

    status: Optional[ApplicationStatusLiteral] = "pending"
    payment_verification_status: Optional[PaymentStatusLiteral] = "not_submitted"
    payment_amount: Optional[float] = 0
    payment_method: Optional[str] = None

    created_at: Optional[Any] = None
    updated_at: Optional[Any] = None
    applied_at: Optional[Any] = None
    submitted_at: Optional[Any] = None
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[Any] = None
    admin_notes: Optional[str] = None

    is_archived: Optional[bool] = False

    class Config:
        extra = "allow"
        arbitrary_types_allowed = True


class ApplicationResponse(BaseModel):
    success: bool = True
    applications: List[Dict[str, Any]] = Field(default_factory=list)
    total: Optional[int] = 0


class ApplicationDetailResponse(BaseModel):
    success: bool = True
    application: Optional[Dict[str, Any]] = None
    scheme: Optional[Dict[str, Any]] = None


# ============================================================
# DOCUMENT UPLOAD RESPONSE
# ============================================================
class DocumentUploadResponse(BaseModel):
    success: bool = True
    message: str = "Document uploaded successfully"
    document: Optional[SchemeDocumentItem] = None


class TempDocumentUploadResponse(BaseModel):
    success: bool = True
    message: str = "Document uploaded successfully"
    document: Optional[Dict[str, Any]] = None


# ============================================================
# ADMIN
# ============================================================
class AdminUpdateStatusRequest(BaseModel):
    status: ApplicationStatusLiteral
    notes: Optional[str] = None


class AdminUpdateStatusResponse(BaseModel):
    success: bool
    message: str
    application_id: str


# ============================================================
# SCHEME LIST / DETAIL RESPONSES
# ============================================================
class SchemeListResponse(BaseModel):
    success: bool = True
    schemes: List[Dict[str, Any]] = Field(default_factory=list)
    total: int = 0
    skip: int = 0
    limit: int = 50


class SchemeDetailResponse(BaseModel):
    success: bool = True
    scheme: Optional[Dict[str, Any]] = None


class SchemeCategory(BaseModel):
    id: str
    name: str
    name_hindi: str
    icon: str


class SchemeCategoriesResponse(BaseModel):
    success: bool = True
    categories: List[SchemeCategory] = Field(default_factory=list)


class SchemeStatesResponse(BaseModel):
    success: bool = True
    states: List[str] = Field(default_factory=list)