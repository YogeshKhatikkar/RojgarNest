# app/models/application_model.py - COMPLETE WITH STATUS ONLY (NO apply_mode)

from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional, List, Dict, Any
from datetime import datetime
from bson import ObjectId


class Application(BaseModel):
    job_id: str
    job_title: str
    organization: str
    added_by: Optional[str] = None
    applicant_email: EmailStr
    applicant_name: str
    
    # ==================== STATUS ONLY (NEW) ====================
    # saved = bookmarked/saved job (not yet applied)
    # pending = payment verification pending
    # pending_verification = payment verification in progress
    # verification_successful = payment verified
    # verification_rejected = payment rejected
    # shortlisted, interview, offered, rejected = admin review status
    # submitted, review_application, confirmed_application, update_application, approved_application, update_rejected, final_submitted = application process status
    status: str = Field(
        default="saved",
        pattern="^(saved|pending|shortlisted|interview|offered|rejected|pending_verification|verification_successful|verification_rejected|submitted|review_application|confirmed_application|update_application|approved_application|update_rejected|final_submitted)$",
        description="Status: 'saved' means bookmarked, any other status means applied"
    )
    
    # Saved timestamp (when user saved/bookmarked)
    saved_at: Optional[datetime] = Field(
        default=None,
        description="When the job was saved by user"
    )
    
    # Application details
    applied_at: Optional[datetime] = Field(default=None, description="When application was submitted")
    resume_url: Optional[str] = None
    cover_letter: Optional[str] = None
    additional_info: Optional[Dict[str, Any]] = None

    # Payment information
    payment_id: Optional[str] = None
    transaction_id: Optional[str] = None
    transaction_date: Optional[datetime] = None
    payment_receipt_url: Optional[str] = None
    payment_receipt_public_id: Optional[str] = None
    payment_amount: Optional[int] = None
    payment_category_used: Optional[str] = None
    payment_verified_by: Optional[str] = None
    payment_verified_at: Optional[datetime] = None
    payment_rejection_reason: Optional[str] = None
    payment_verification_notes: Optional[str] = None

    # Admin side
    admin_notes: Optional[str] = None
    last_status_update: Optional[datetime] = None
    last_updated_by: Optional[str] = None

    # Submitted document (for CustomAdmin)
    submitted_document_url: Optional[str] = None
    submitted_document_name: Optional[str] = None
    submitted_document_storage: Optional[str] = None
    submitted_document_public_id: Optional[str] = None
    submitted_document_folder: Optional[str] = None
    submitted_at: Optional[datetime] = None
    submitted_by: Optional[str] = None
    
    # Final submitted document tracking
    final_document_url: Optional[str] = None
    final_document_name: Optional[str] = None
    final_document_public_id: Optional[str] = None
    final_submitted_at: Optional[datetime] = None
    final_submitted_by: Optional[str] = None

    # ==================== APPLICATION UPDATE FIELDS ====================
    application_updates: Optional[List[Dict[str, Any]]] = Field(
        default_factory=list,
        description="List of updates submitted by user: [{'field_name': 'xxx', 'field_value': 'yyy'}]"
    )
    update_notes: Optional[str] = Field(default=None)
    update_submitted_at: Optional[datetime] = None
    update_submitted_by: Optional[str] = None
    update_approved_at: Optional[datetime] = None
    update_approved_by: Optional[str] = None
    update_rejected_at: Optional[datetime] = None
    update_rejected_by: Optional[str] = None
    admin_update_notes: Optional[str] = None
    
    # ==================== ADDITIONAL DYNAMIC FIELDS ====================
    updated_fields: Optional[Dict[str, Any]] = Field(default_factory=dict)

    # AI Match
    ai_match: Optional[Dict[str, Any]] = None
    match_score: Optional[float] = None

    # Re-application tracking
    previous_application_id: Optional[str] = None
    previous_status: Optional[str] = None
    replaced_at: Optional[datetime] = None
    replaced_by: Optional[str] = None

    # System
    _id: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    @field_validator('job_id')
    @classmethod
    def validate_job_id(cls, v: str) -> str:
        if not ObjectId.is_valid(v):
            raise ValueError("Invalid job ID format")
        return v

    # ==================== HELPER METHODS ====================
    
    def save_job(self) -> None:
        """Mark application as saved (bookmark)"""
        self.status = "saved"
        self.saved_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()
    
    def apply_job(self) -> None:
        """Convert saved application to applied"""
        self.status = "pending"  # Will be updated based on payment
        self.applied_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()
    
    def is_saved(self) -> bool:
        """Check if application is saved (bookmarked)"""
        return self.status == "saved"
    
    def is_applied(self) -> bool:
        """Check if application is actually applied"""
        return self.status != "saved"
    
    def add_update(self, field_name: str, field_value: str, notes: Optional[str] = None) -> None:
        """Add a new update to the application"""
        if self.application_updates is None:
            self.application_updates = []
        
        self.application_updates.append({
            "field_name": field_name,
            "field_value": field_value,
            "submitted_at": datetime.utcnow().isoformat()
        })
        
        if notes:
            self.update_notes = notes
        
        self.update_submitted_at = datetime.utcnow()
        self.status = "update_application"
        self.updated_at = datetime.utcnow()
    
    def approve_updates(self, admin_email: str, admin_notes: Optional[str] = None) -> None:
        """Approve and merge updates into the application"""
        if self.application_updates:
            if self.updated_fields is None:
                self.updated_fields = {}
            
            for update in self.application_updates:
                field_name = update.get("field_name")
                field_value = update.get("field_value")
                if field_name and field_value:
                    self.updated_fields[field_name] = field_value
            
            if self.additional_info is None:
                self.additional_info = {}
            
            for update in self.application_updates:
                field_name = update.get("field_name")
                field_value = update.get("field_value")
                if field_name and field_value:
                    self.additional_info[field_name] = field_value
        
        self.status = "approved_application"
        self.update_approved_at = datetime.utcnow()
        self.update_approved_by = admin_email
        self.admin_update_notes = admin_notes
        self.updated_at = datetime.utcnow()
    
    def reject_updates(self, admin_email: str, admin_notes: Optional[str] = None) -> None:
        """Reject the updates"""
        self.status = "update_rejected"
        self.update_rejected_at = datetime.utcnow()
        self.update_rejected_by = admin_email
        self.admin_update_notes = admin_notes
        self.updated_at = datetime.utcnow()
    
    def get_merged_updates(self) -> Dict[str, Any]:
        """Get all updates merged into a single dictionary"""
        if self.updated_fields:
            return self.updated_fields
        if self.application_updates:
            merged = {}
            for update in self.application_updates:
                field_name = update.get("field_name")
                field_value = update.get("field_value")
                if field_name and field_value:
                    merged[field_name] = field_value
            return merged
        return {}
    
    model_config = {
        "collection": "applications",
        "arbitrary_types_allowed": True,
        "json_schema_extra": {
            "example": {
                "job_id": "507f1f77bcf86cd799439011",
                "job_title": "Software Engineer",
                "organization": "Tech Corp",
                "added_by": "admin@example.com",
                "applicant_email": "user@example.com",
                "applicant_name": "John Doe",
                "status": "saved",
                "cover_letter": "I am interested in this position."
            }
        }
    }


print("✅ Application Model Updated - Uses status='saved' only, apply_mode removed")