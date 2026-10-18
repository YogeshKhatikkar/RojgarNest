# app/modules/schemes/schemas.py
"""
Government Schemes Pydantic Schemas

✅ Documents accept BOTH `url` and `document_url` (AND `documentUrl`)
✅ Full backward compatibility with all frontend formats
✅ Response now returns `scheme_documents` (not legacy `documents`)
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
    """Personal + contact + identity details."""
    full_name: str = Field(..., min_length=1, max_length=200)
    father_name: Optional[str] = Field(default="", max_length=200)
    mother_name: Optional[str] = Field(default="", max_length=200)
    date_of_birth: Optional[str] = Field(default="", description="YYYY-MM-DD")
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
# ✅ DOCUMENT ITEM — Accepts ALL field name variants
# ============================================================
class SchemeDocumentItem(BaseModel):
    """
    A single uploaded document.

    ✅ Accepts ALL of these field names as input:
       - `document_url` (primary)
       - `url` (legacy / current frontend)
       - `documentUrl` (camelCase)
       - `file_url` (alternative)
       - `fileUrl` (camelCase alternative)

    Output ALWAYS uses `document_url` AND `url` for compatibility.
    """

    # Output fields
    document_type: Optional[str] = Field(default="", max_length=100)
    document_name: Optional[str] = Field(default="", max_length=200)
    url: Optional[str] = Field(default="", max_length=2000)
    document_url: Optional[str] = Field(default="", max_length=2000)
    download_url: Optional[str] = Field(default=None, max_length=2000)
    public_id: Optional[str] = None
    resource_type: Optional[str] = "auto"
    file_name: Optional[str] = None
    file_size: Optional[int] = 0
    is_pdf: Optional[bool] = False
    is_image: Optional[bool] = False
    source: Optional[str] = "schemes_application"
    uploaded_at: Optional[str] = None
    uploaded_by: Optional[str] = None
    label: Optional[str] = None

    # ✅ Input aliases (accepted but NOT output)
    documentUrl: Optional[str] = None
    file_url: Optional[str] = None
    fileUrl: Optional[str] = None
    name: Optional[str] = None

    class Config:
        extra = "allow"

    @validator("document_url", "url", always=True, pre=True)
    def resolve_document_url(cls, v, values):
        """
        ✅ Try all possible field names in priority order.
        """
        if v and str(v).strip():
            return str(v).strip()

        for key in ("document_url", "url", "documentUrl", "file_url", "fileUrl"):
            candidate = values.get(key)
            if candidate and str(candidate).strip():
                return str(candidate).strip()

        return ""

    @validator("document_name", "label", always=True, pre=True)
    def resolve_document_name(cls, v, values):
        """Resolve document name from multiple possible fields."""
        if v and str(v).strip():
            return str(v).strip()

        for key in ("document_name", "label", "name"):
            candidate = values.get(key)
            if candidate and str(candidate).strip():
                return str(candidate).strip()

        doc_type = values.get("document_type")
        if doc_type and str(doc_type).strip():
            return str(doc_type).replace("_", " ").title()

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
    application_number: Optional[str] = None
    application_type: Optional[str] = "schemes"
    message: Optional[str] = "Application submitted successfully"
    status: Optional[str] = "pending"
    documents_saved: Optional[int] = 0


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
    application_number: Optional[str] = None
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

    # ✅ scheme_documents[] (primary)
    scheme_documents: Optional[List[SchemeDocumentItem]] = Field(default_factory=list)

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


print("✅ Schemes Schemas Loaded — scheme_documents support")