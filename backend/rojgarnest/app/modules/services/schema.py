# app/modules/services/schema.py - COMPLETE FIXED VERSION
# ✅ Added CONFIRMED_APPLICATION and UPDATE_APPLICATION statuses
# ✅ Added User action schemas

from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional, List, Dict, Any
from datetime import datetime
from enum import Enum


class ServiceType(str, Enum):
    PAN = "pan"
    AADHAAR = "aadhar"
    EPF = "epf"
    PASSPORT = "passport"
    DRIVING_LICENSE = "driving_license"
    VOTER_ID = "voter_id"
    RATION_CARD = "ration_card"
    INCOME_CERTIFICATE = "income_certificate"
    CASTE_CERTIFICATE = "caste_certificate"
    DOMICILE = "domicile"
    DISABILITY = "disability"
    BONAFIDE = "bonafide"
    GAP_CERTIFICATE = "gap_certificate"


class ServiceApplicationStatus(str, Enum):
    """Service Application Status Enum - Complete list"""
    PENDING = "pending"
    PAYMENT_PENDING = "payment_pending"
    PAYMENT_VERIFIED = "payment_verified"
    UNDER_REVIEW = "under_review"
    REVIEW_APPLICATION = "review_application"          # ✅ Admin review
    APPROVED = "approved"
    REJECTED = "rejected"
    COMPLETED = "completed"
    PENDING_VERIFICATION = "pending_verification"
    CONFIRMED_APPLICATION = "confirmed_application"    # ✅ User confirms application
    UPDATE_APPLICATION = "update_application"          # ✅ User submitted update


class ServiceApplicationCreateSchema(BaseModel):
    """Schema for creating a service application"""
    # User details (auto-fetched from auth)
    user_email: str
    user_name: str
    user_mobile: str
    
    # Service details
    service_type: ServiceType
    service_sub_type: str
    service_name: str
    sub_service_name: str
    application_type: str = "online_service"
    fields: Dict[str, Any] = Field(default_factory=dict)
    documents: Dict[str, str] = Field(default_factory=dict)
    amount: Optional[int] = None


class ServiceApplicationUpdateSchema(BaseModel):
    """Schema for updating a service application"""
    status: Optional[ServiceApplicationStatus] = None
    admin_notes: Optional[str] = None
    payment_status: Optional[str] = None
    transaction_id: Optional[str] = None
    updated_fields: Optional[Dict[str, Any]] = None


class ServiceApplicationResponseSchema(BaseModel):
    """Schema for service application response with document fields"""
    id: str
    user_email: str
    user_name: str
    service_type: str
    service_sub_type: str
    service_name: str
    sub_service_name: str
    application_type: str
    status: str
    payment_status: str
    amount: Optional[int] = None
    transaction_id: Optional[str] = None
    fields: Dict[str, Any]
    documents: Dict[str, str]
    admin_notes: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    payment_id: Optional[str] = None
    qr_code_data: Optional[str] = None
    
    # ✅ DOCUMENT FIELDS
    submitted_document_url: Optional[str] = None
    submitted_document_name: Optional[str] = None
    submitted_document_public_id: Optional[str] = None
    submitted_document_folder: Optional[str] = None
    submitted_document_resource_type: Optional[str] = None
    submitted_document_storage: Optional[str] = None
    submitted_at: Optional[datetime] = None
    submitted_by: Optional[str] = None
    final_document_url: Optional[str] = None
    final_document_name: Optional[str] = None
    final_submitted_at: Optional[datetime] = None
    final_submitted_by: Optional[str] = None
    confirmation_notes: Optional[str] = None
    
    # ✅ UPDATE FIELDS
    application_updates: List[Dict[str, Any]] = Field(default_factory=list)
    update_notes: Optional[str] = None
    update_submitted_at: Optional[datetime] = None
    update_submitted_by: Optional[str] = None


class ServiceFeeSchema(BaseModel):
    """Schema for service fee"""
    service_type: ServiceType
    sub_type_id: str
    amount: int = 100
    currency: str = "INR"


class PaymentQRResponseSchema(BaseModel):
    """Schema for payment QR response"""
    needs_payment: bool
    amount: int
    payment_id: str
    qr_code_data: str
    expires_at: datetime
    category_used: str = "service"


class ServiceApplicationStatusUpdateSchema(BaseModel):
    """Schema for status update - FIXED: expects string status"""
    status: str  # ✅ Changed from Enum to str for easier JSON handling
    admin_notes: Optional[str] = None
    
    @field_validator('status')
    @classmethod
    def validate_status(cls, v: str) -> str:
        """Validate that status is a valid ServiceApplicationStatus value"""
        valid_statuses = [s.value for s in ServiceApplicationStatus]
        if v not in valid_statuses:
            raise ValueError(f"Invalid status. Must be one of: {valid_statuses}")
        return v


class ServiceDocumentUploadSchema(BaseModel):
    """Schema for document upload"""
    document_type: str
    document_url: str


# ==================== USER ACTION SCHEMAS ====================

class ServiceApplicationConfirmSchema(BaseModel):
    """Schema for user confirming application"""
    application_id: str
    notes: Optional[str] = None


class ServiceApplicationUpdateFieldSchema(BaseModel):
    """Schema for a single field update"""
    field_name: str
    field_value: str


class ServiceApplicationUpdateSubmitSchema(BaseModel):
    """Schema for user submitting application update"""
    application_id: str
    updates: List[ServiceApplicationUpdateFieldSchema]
    notes: Optional[str] = None


print("✅ Services Schema Loaded - With CONFIRMED_APPLICATION and UPDATE_APPLICATION")