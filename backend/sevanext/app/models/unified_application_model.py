# app/models/unified_application_model.py
"""
UNIFIED APPLICATION MODEL - Single collection for ALL applications
Both JOB and SERVICE applications are stored in the same 'applications' collection
Differentiated by 'application_type' field: "job" or "service"

✅ UPDATED: Added `service_documents[]` field.
✅ UPDATED: Added `scheme_documents[]` field (parallel to service_documents).
   - Documents uploaded in scheme apply screen are stored ONLY here.
   - They are filtered by application_id when displayed.
   - Tagged with source="schemes_application".
   - user_documents_screen uploads (profile docs) NEVER appear here.
"""

from pydantic import BaseModel, EmailStr, Field, model_validator
from typing import Optional, List, Dict, Any
from datetime import datetime
from bson import ObjectId
from enum import Enum


class ApplicationType(str, Enum):
    JOB = "job"
    SERVICE = "service"


class PaymentVerificationStatus(str, Enum):
    NOT_SUBMITTED = "not_submitted"
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class UnifiedApplicationModel(BaseModel):
    """
    UNIFIED APPLICATION MODEL
    One collection for ALL applications (jobs + services + schemes)
    application_type field determines the type
    """

    # ==================== TYPE IDENTIFICATION ====================
    application_type: str = Field(
        default="job",
        pattern="^(job|service|schemes)$",
        description="'job' | 'service' | 'schemes' - determines which type this is"
    )

    # ==================== COMMON FIELDS ====================
    user_email: EmailStr
    user_name: str
    user_id: Optional[str] = None
    user_mobile: Optional[str] = None
    user_category: Optional[str] = "General/UR"
    is_disabled: bool = False

    # ✅ Folder-safe username (used for Cloudinary paths)
    application_username: Optional[str] = None

    # Status fields
    status: str = Field(
        default="saved",
        pattern="^(saved|pending|pending_verification|under_review|review_application|approved|rejected|completed|verification_successful|verification_rejected|confirmed_application|update_application|approved_application|update_rejected|final_submitted|replaced|payment_pending|payment_verified|draft|submitted)$"
    )

    # ✅ Draft flag — used while documents are still being uploaded
    is_draft: bool = False

    # ==================== JOB-SPECIFIC FIELDS ====================
    job_id: Optional[str] = None
    job_title: Optional[str] = None
    organization: Optional[str] = None
    added_by: Optional[str] = None
    applicant_name: Optional[str] = None
    applicant_email: Optional[EmailStr] = None
    resume_url: Optional[str] = None
    cover_letter: Optional[str] = None
    additional_info: Optional[Dict[str, Any]] = None
    match_score: Optional[float] = None
    ai_match: Optional[Dict[str, Any]] = None

    # ==================== SERVICE-SPECIFIC FIELDS ====================
    service_id: Optional[str] = None
    sub_type_id: Optional[str] = None
    service_name: Optional[str] = None
    sub_service_name: Optional[str] = None
    fields: Dict[str, Any] = Field(default_factory=dict)
    documents: Dict[str, str] = Field(default_factory=dict)  # legacy

    # ============================================================
    # ✅ SERVICE APPLICATION DOCUMENTS (uploaded by user during apply_service)
    # ------------------------------------------------------------
    # Each entry:
    #   {
    #     "document_type": "aadhaar_card",
    #     "label": "Aadhaar Card",
    #     "url": "https://cloudinary.com/...",
    #     "download_url": "...",
    #     "public_id": "service_applications/{app_id}/aadhaar_card/...",
    #     "resource_type": "raw" | "image" | "auto",
    #     "file_name": "aadhaar.pdf",
    #     "file_size": 123456,
    #     "is_pdf": true,
    #     "is_image": false,
    #     "source": "service_application",   ← filter tag
    #     "uploaded_at": ISO timestamp,
    #     "uploaded_by": "user@example.com"
    #   }
    # ============================================================
    service_documents: List[Dict[str, Any]] = Field(default_factory=list)

    # ============================================================
    # ✅ SCHEME APPLICATION DOCUMENTS (uploaded by user during apply_scheme)
    # ------------------------------------------------------------
    # Each entry (mirrors service_documents exactly):
    #   {
    #     "document_type": "aadhaar_card",
    #     "label": "Aadhaar Card",
    #     "url": "https://cloudinary.com/...",
    #     "download_url": "...",
    #     "public_id": "scheme_applications/{app_id}/aadhaar_card/...",
    #     "resource_type": "raw" | "image" | "auto",
    #     "file_name": "aadhaar.pdf",
    #     "file_size": 123456,
    #     "is_pdf": true,
    #     "is_image": false,
    #     "source": "schemes_application",   ← filter tag
    #     "uploaded_at": ISO timestamp,
    #     "uploaded_by": "user@example.com"
    #   }
    #
    # ✅ This array belongs ONLY to this scheme application.
    # ✅ NEVER mixed with profile docs (from user_documents_screen).
    # ✅ Fetched via /schemes/application/{id}/documents
    # ============================================================
    scheme_documents: List[Dict[str, Any]] = Field(default_factory=list)

    # ==================== SCHEME-SPECIFIC FIELDS ====================
    scheme_id: Optional[str] = None
    scheme_name: Optional[str] = None
    scheme_name_hindi: Optional[str] = None
    scheme_level: Optional[str] = None
    scheme_state: Optional[str] = None
    scheme_category: Optional[str] = None
    applicant_details: Optional[Dict[str, Any]] = Field(default_factory=dict)
    applicant_address: Optional[Dict[str, Any]] = Field(default_factory=dict)
    bank_details: Optional[Dict[str, Any]] = Field(default_factory=dict)

    # ==================== PAYMENT FIELDS (RAZORPAY ONLY) ====================
    payment_id: Optional[str] = None
    payment_amount: Optional[int] = None
    payment_gst: Optional[int] = None
    payment_service_charge: Optional[int] = None
    payment_total: Optional[int] = None
    payment_category_used: Optional[str] = None
    payment_status: Optional[str] = "pending"
    payment_verification_status: str = Field(
        default="not_submitted",
        pattern="^(not_submitted|pending|approved|rejected)$"
    )
    payment_method: str = Field(
        default="razorpay",
        pattern="^(razorpay|test|none)$"
    )

    # Razorpay fields
    razorpay_order_id: Optional[str] = None
    razorpay_payment_id: Optional[str] = None
    razorpay_signature: Optional[str] = None

    # Transaction details
    transaction_id: Optional[str] = None
    transaction_date: Optional[datetime] = None

    # Payment receipt/screenshot
    payment_receipt_url: Optional[str] = None
    payment_receipt_public_id: Optional[str] = None
    screenshot_url: Optional[str] = None
    screenshot_public_id: Optional[str] = None

    # Payment verification
    payment_verified_by: Optional[str] = None
    payment_verified_at: Optional[datetime] = None
    payment_rejection_reason: Optional[str] = None
    payment_verification_notes: Optional[str] = None

    order_id: Optional[str] = None
    expires_at: Optional[datetime] = None

    # ==================== TIMESTAMPS ====================
    saved_at: Optional[datetime] = None
    applied_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    paid_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    confirmed_at: Optional[datetime] = None
    confirmed_by: Optional[str] = None
    confirmation_notes: Optional[str] = None
    submitted_at: Optional[datetime] = None

    # ==================== ADMIN FIELDS ====================
    admin_notes: Optional[str] = None
    last_status_update: Optional[datetime] = None
    last_updated_by: Optional[str] = None
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    remarks: Optional[str] = None

    # ==================== SUBMITTED DOCUMENT FIELDS ====================
    submitted_document_url: Optional[str] = None
    submitted_document_download_url: Optional[str] = None
    submitted_document_name: Optional[str] = None
    submitted_document_public_id: Optional[str] = None
    submitted_document_resource_type: Optional[str] = None
    submitted_document_storage: Optional[str] = None
    submitted_document_folder: Optional[str] = None
    submitted_by: Optional[str] = None

    # Final document (for final submission)
    final_document_url: Optional[str] = None
    final_document_download_url: Optional[str] = None
    final_document_name: Optional[str] = None
    final_document_public_id: Optional[str] = None
    final_submitted_at: Optional[datetime] = None
    final_submitted_by: Optional[str] = None

    # ==================== APPLICATION UPDATE FIELDS ====================
    application_updates: List[Dict[str, Any]] = Field(default_factory=list)
    update_notes: Optional[str] = None
    update_submitted_at: Optional[datetime] = None
    update_submitted_by: Optional[str] = None
    update_approved_at: Optional[datetime] = None
    update_approved_by: Optional[str] = None
    update_rejected_at: Optional[datetime] = None
    update_rejected_by: Optional[str] = None
    admin_update_notes: Optional[str] = None

    # ==================== RE-APPLICATION TRACKING ====================
    previous_application_id: Optional[str] = None
    previous_status: Optional[str] = None
    replaced_at: Optional[datetime] = None
    replaced_by: Optional[str] = None

    # ==================== HELPER PROPERTIES ====================

    @property
    def is_job(self) -> bool:
        return self.application_type == "job"

    @property
    def is_service(self) -> bool:
        return self.application_type == "service"

    @property
    def is_scheme(self) -> bool:
        return self.application_type == "schemes"

    @property
    def is_saved(self) -> bool:
        return self.status == "saved"

    @property
    def is_applied(self) -> bool:
        return self.status != "saved"

    @property
    def is_payment_completed(self) -> bool:
        return self.payment_verification_status in ["approved", "verified"]

    @property
    def display_title(self) -> str:
        if self.is_job:
            return self.job_title or "Job Application"
        if self.is_scheme:
            return self.scheme_name or self.scheme_name_hindi or "Scheme Application"
        return self.service_name or "Service Application"

    @property
    def display_organization(self) -> str:
        if self.is_job:
            return self.organization or "Company"
        if self.is_scheme:
            return self.scheme_category or "Government Scheme"
        return self.sub_service_name or "Service"

    @property
    def is_pending_payment(self) -> bool:
        return self.payment_verification_status == "pending"

    @property
    def is_payment_rejected(self) -> bool:
        return self.payment_verification_status == "rejected"

    @property
    def has_submitted_document(self) -> bool:
        return bool(self.submitted_document_url)

    @property
    def has_final_document(self) -> bool:
        return bool(self.final_document_url)

    @property
    def has_updates(self) -> bool:
        return len(self.application_updates) > 0

    @property
    def has_service_documents(self) -> bool:
        return len(self.service_documents) > 0

    @property
    def has_scheme_documents(self) -> bool:
        return len(self.scheme_documents) > 0

    # ==================== HELPER METHODS ====================

    def save_job(self) -> None:
        self.status = "saved"
        self.saved_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()

    def apply_job(self) -> None:
        self.status = "pending_verification"
        self.applied_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()

    def submit_payment_verification(self, transaction_id: str, screenshot_url: str) -> None:
        self.transaction_id = transaction_id
        self.payment_receipt_url = screenshot_url
        self.payment_verification_status = "pending"
        self.status = "pending_verification"
        self.updated_at = datetime.utcnow()

    def approve_payment(self, admin_email: str, notes: Optional[str] = None) -> None:
        self.payment_verification_status = "approved"
        self.payment_verified_by = admin_email
        self.payment_verified_at = datetime.utcnow()
        self.payment_verification_notes = notes or "Payment approved"
        self.paid_at = datetime.utcnow()
        if self.is_job:
            self.status = "verification_successful"
        elif self.is_scheme:
            self.status = "pending"
        else:
            self.status = "payment_verified"
        self.updated_at = datetime.utcnow()

    def reject_payment(self, admin_email: str, reason: str) -> None:
        self.payment_verification_status = "rejected"
        self.payment_verified_by = admin_email
        self.payment_verified_at = datetime.utcnow()
        self.payment_rejection_reason = reason
        if self.is_job:
            self.status = "verification_rejected"
        else:
            self.status = "rejected"
        self.updated_at = datetime.utcnow()

    def confirm_application(self, user_email: str, notes: Optional[str] = None) -> None:
        self.status = "confirmed_application"
        self.confirmed_at = datetime.utcnow()
        self.confirmed_by = user_email
        self.confirmation_notes = notes
        self.updated_at = datetime.utcnow()

    def submit_update(self, updates: List[Dict[str, str]], user_email: str, notes: Optional[str] = None) -> None:
        self.status = "update_application"
        self.application_updates = updates
        self.update_notes = notes
        self.update_submitted_at = datetime.utcnow()
        self.update_submitted_by = user_email
        self.updated_at = datetime.utcnow()

    def approve_update(self, admin_email: str, notes: Optional[str] = None) -> None:
        self.status = "approved_application"
        self.update_approved_at = datetime.utcnow()
        self.update_approved_by = admin_email
        self.admin_update_notes = notes

        for update in self.application_updates:
            field_name = update.get("field_name")
            field_value = update.get("field_value")
            if field_name and field_value:
                if self.is_job:
                    if self.additional_info is None:
                        self.additional_info = {}
                    self.additional_info[field_name] = field_value
                elif self.is_scheme:
                    if self.applicant_details is None:
                        self.applicant_details = {}
                    self.applicant_details[field_name] = field_value
                else:
                    self.fields[field_name] = field_value

        self.updated_at = datetime.utcnow()

    def reject_update(self, admin_email: str, notes: str) -> None:
        self.status = "update_rejected"
        self.update_rejected_at = datetime.utcnow()
        self.update_rejected_by = admin_email
        self.admin_update_notes = notes
        self.updated_at = datetime.utcnow()

    def submit_document(self, document_url: str, document_name: str, admin_email: str, notes: Optional[str] = None) -> None:
        self.submitted_document_url = document_url
        self.submitted_document_name = document_name
        self.submitted_at = datetime.utcnow()
        self.submitted_by = admin_email
        self.status = "review_application"
        self.confirmation_notes = notes
        self.updated_at = datetime.utcnow()

    def final_submit(self, document_url: str, document_name: str, admin_email: str, notes: Optional[str] = None) -> None:
        self.submitted_document_url = document_url
        self.submitted_document_name = document_name
        self.submitted_at = datetime.utcnow()
        self.submitted_by = admin_email
        self.final_document_url = document_url
        self.final_document_name = document_name
        self.final_submitted_at = datetime.utcnow()
        self.final_submitted_by = admin_email
        if self.is_job:
            self.status = "final_submitted"
        else:
            self.status = "completed"
        self.completed_at = datetime.utcnow()
        self.confirmation_notes = notes
        self.updated_at = datetime.utcnow()

    # ✅ Append a service document with source tag
    def add_service_document(self, doc: Dict[str, Any]) -> None:
        if self.service_documents is None:
            self.service_documents = []
        doc.setdefault("source", "service_application")
        doc.setdefault("uploaded_at", datetime.utcnow().isoformat())
        self.service_documents.append(doc)
        self.updated_at = datetime.utcnow()

    # ✅ NEW: Append a scheme document with source tag
    def add_scheme_document(self, doc: Dict[str, Any]) -> None:
        if self.scheme_documents is None:
            self.scheme_documents = []
        doc.setdefault("source", "schemes_application")
        doc.setdefault("uploaded_at", datetime.utcnow().isoformat())
        self.scheme_documents.append(doc)
        self.updated_at = datetime.utcnow()

    def to_dict(self) -> Dict[str, Any]:
        return self.model_dump(by_alias=True, exclude_none=True)

    def model_dump(self, **kwargs) -> Dict[str, Any]:
        data = super().model_dump(**kwargs)
        for key, value in data.items():
            if isinstance(value, datetime):
                data[key] = value.isoformat()
        return data

    class Config:
        collection = "applications"
        arbitrary_types_allowed = True
        json_encoders = {
            datetime: lambda v: v.isoformat(),
        }
        populate_by_name = True
        extra = "allow"


print("=" * 70)
print("✅ UNIFIED APPLICATION MODEL LOADED")
print("   ✅ Single 'applications' collection for ALL applications")
print("   ✅ application_type='job' for job applications")
print("   ✅ application_type='service' for service applications")
print("   ✅ application_type='schemes' for scheme applications")
print("   ✅ service_documents[] holds ONLY app-specific service uploads")
print("   ✅ scheme_documents[] holds ONLY app-specific scheme uploads")
print("   ✅ RAZORPAY ONLY - No QR code, No PhonePe")
print("=" * 70)