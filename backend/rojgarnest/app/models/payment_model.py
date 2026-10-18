# app/models/payment_model.py
# ============================================================
# PAYMENT MODEL - Complete Payment Model
# ============================================================

from pydantic import BaseModel, Field, EmailStr
from typing import Optional, Dict, Any, List
from datetime import datetime
from enum import Enum
from bson import ObjectId


# ============================================================
# PAYMENT STATUS ENUM
# ============================================================
class PaymentStatus(str, Enum):
    """Payment status values"""
    PENDING = "pending"
    COMPLETED = "completed"
    FAILED = "failed"
    REFUNDED = "refunded"
    AUTHORIZED = "authorized"
    CANCELLED = "cancelled"


# ============================================================
# PAYMENT VERIFICATION STATUS ENUM
# ============================================================
class PaymentVerificationStatus(str, Enum):
    """Payment verification status values"""
    NOT_SUBMITTED = "not_submitted"
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


# ============================================================
# PAYMENT METHOD ENUM
# ============================================================
class PaymentMethod(str, Enum):
    """Payment method values"""
    RAZORPAY = "razorpay"
    PHONEPE = "phonepe"
    TEST = "test"
    NONE = "none"


# ============================================================
# PAYMENT TYPE ENUM
# ============================================================
class PaymentType(str, Enum):
    """Payment type values"""
    JOB = "job"
    SERVICE = "service"


# ============================================================
# MAIN PAYMENT MODEL
# ============================================================
class PaymentModel(BaseModel):
    """
    Complete Payment Model
    Used for payment tracking in the applications collection
    """

    # ==================== IDENTIFICATION ====================
    _id: Optional[str] = None
    application_id: Optional[str] = None
    user_email: Optional[EmailStr] = None
    user_name: Optional[str] = None
    user_id: Optional[str] = None

    # ==================== PAYMENT TYPE ====================
    payment_type: str = Field(
        default="job",
        pattern="^(job|service)$",
        description="'job' or 'service'"
    )

    # ==================== JOB/SERVICE DETAILS ====================
    job_id: Optional[str] = None
    job_title: Optional[str] = None
    organization: Optional[str] = None

    service_id: Optional[str] = None
    service_name: Optional[str] = None
    sub_type_id: Optional[str] = None
    sub_service_name: Optional[str] = None

    # ==================== AMOUNT ====================
    amount: Optional[int] = 0
    payment_amount: Optional[int] = 0
    application_fee: Optional[int] = 0
    gst_amount: Optional[int] = 0
    service_charge: Optional[int] = 0
    currency: str = "INR"

    # ==================== CATEGORY ====================
    payment_category_used: Optional[str] = None

    # ==================== PAYMENT STATUS ====================
    payment_status: str = Field(
        default="pending",
        pattern="^(pending|completed|failed|refunded|authorized|cancelled)$"
    )

    verification_status: str = Field(
        default="not_submitted",
        pattern="^(not_submitted|pending|approved|rejected)$"
    )

    payment_verification_status: str = Field(
        default="not_submitted",
        pattern="^(not_submitted|pending|approved|rejected)$"
    )

    # ==================== PAYMENT METHOD ====================
    payment_method: str = Field(
        default="razorpay",
        pattern="^(razorpay|phonepe|test|none)$"
    )

    # ==================== RAZORPAY FIELDS ====================
    razorpay_order_id: Optional[str] = None
    razorpay_payment_id: Optional[str] = None
    razorpay_signature: Optional[str] = None

    # ==================== TRANSACTION DETAILS ====================
    transaction_id: Optional[str] = None
    transaction_date: Optional[datetime] = None

    # ==================== RECEIPT / SCREENSHOT ====================
    payment_receipt_url: Optional[str] = None
    payment_receipt_public_id: Optional[str] = None
    screenshot_url: Optional[str] = None
    screenshot_public_id: Optional[str] = None

    # ==================== VERIFICATION ====================
    verified_by: Optional[str] = None
    verified_at: Optional[datetime] = None
    payment_verified_by: Optional[str] = None
    payment_verified_at: Optional[datetime] = None
    rejection_reason: Optional[str] = None
    payment_rejection_reason: Optional[str] = None
    verification_notes: Optional[str] = None
    payment_verification_notes: Optional[str] = None

    # ==================== ORDER INFO ====================
    order_id: Optional[str] = None
    expires_at: Optional[datetime] = None

    # ==================== TIMESTAMPS ====================
    paid_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    # ==================== HELPER METHODS ====================
    def mark_completed(self):
        """Mark payment as completed"""
        self.payment_status = PaymentStatus.COMPLETED.value
        self.paid_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()

    def mark_failed(self, reason: Optional[str] = None):
        """Mark payment as failed"""
        self.payment_status = PaymentStatus.FAILED.value
        if reason:
            self.rejection_reason = reason
        self.updated_at = datetime.utcnow()

    def approve_verification(self, admin_email: str, notes: Optional[str] = None):
        """Approve payment verification"""
        self.verification_status = PaymentVerificationStatus.APPROVED.value
        self.payment_verification_status = PaymentVerificationStatus.APPROVED.value
        self.verified_by = admin_email
        self.payment_verified_by = admin_email
        self.verified_at = datetime.utcnow()
        self.payment_verified_at = datetime.utcnow()
        if notes:
            self.verification_notes = notes
            self.payment_verification_notes = notes
        self.updated_at = datetime.utcnow()

    def reject_verification(self, admin_email: str, reason: str):
        """Reject payment verification"""
        self.verification_status = PaymentVerificationStatus.REJECTED.value
        self.payment_verification_status = PaymentVerificationStatus.REJECTED.value
        self.verified_by = admin_email
        self.payment_verified_by = admin_email
        self.verified_at = datetime.utcnow()
        self.payment_verified_at = datetime.utcnow()
        self.rejection_reason = reason
        self.payment_rejection_reason = reason
        self.updated_at = datetime.utcnow()

    class Config:
        collection = "payments"
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            ObjectId: lambda v: str(v),
        }


# ============================================================
# PAYMENT CREATE SCHEMA
# ============================================================
class PaymentCreateSchema(BaseModel):
    """Schema for creating a payment"""
    application_id: str
    user_email: EmailStr
    user_name: Optional[str] = None
    payment_type: str = Field(default="job", pattern="^(job|service)$")

    job_id: Optional[str] = None
    job_title: Optional[str] = None
    organization: Optional[str] = None

    service_id: Optional[str] = None
    service_name: Optional[str] = None
    sub_type_id: Optional[str] = None
    sub_service_name: Optional[str] = None

    amount: int
    payment_category_used: Optional[str] = None

    class Config:
        extra = "allow"


# ============================================================
# PAYMENT UPDATE SCHEMA
# ============================================================
class PaymentUpdateSchema(BaseModel):
    """Schema for updating a payment"""
    payment_status: Optional[str] = None
    verification_status: Optional[str] = None
    payment_verification_status: Optional[str] = None
    transaction_id: Optional[str] = None
    transaction_date: Optional[datetime] = None
    payment_receipt_url: Optional[str] = None
    payment_receipt_public_id: Optional[str] = None
    razorpay_payment_id: Optional[str] = None
    razorpay_order_id: Optional[str] = None
    razorpay_signature: Optional[str] = None
    verified_by: Optional[str] = None
    rejection_reason: Optional[str] = None
    verification_notes: Optional[str] = None

    class Config:
        extra = "allow"


# ============================================================
# PAYMENT RESPONSE SCHEMA
# ============================================================
class PaymentResponseSchema(BaseModel):
    """Schema for payment API response"""
    id: str
    application_id: Optional[str] = None
    user_email: Optional[str] = None
    user_name: Optional[str] = None
    payment_type: Optional[str] = None
    job_id: Optional[str] = None
    job_title: Optional[str] = None
    organization: Optional[str] = None
    amount: Optional[int] = None
    payment_amount: Optional[int] = None
    payment_status: Optional[str] = None
    verification_status: Optional[str] = None
    payment_verification_status: Optional[str] = None
    payment_method: Optional[str] = None
    transaction_id: Optional[str] = None
    transaction_date: Optional[datetime] = None
    payment_receipt_url: Optional[str] = None
    razorpay_order_id: Optional[str] = None
    razorpay_payment_id: Optional[str] = None
    verified_by: Optional[str] = None
    verified_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True
        json_encoders = {
            datetime: lambda v: v.isoformat(),
        }


# ============================================================
# EXPORTS
# ============================================================
__all__ = [
    "PaymentModel",
    "PaymentStatus",
    "PaymentVerificationStatus",
    "PaymentMethod",
    "PaymentType",
    "PaymentCreateSchema",
    "PaymentUpdateSchema",
    "PaymentResponseSchema",
]


print("✅ Payment Model Loaded Successfully")