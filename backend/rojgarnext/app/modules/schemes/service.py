# app/modules/schemes/service.py
"""
Government Schemes Service
Handles all scheme-related operations
"""

from fastapi import HTTPException, BackgroundTasks
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
from bson import ObjectId
import logging
import uuid

from app.db.connection import get_db
from app.core.utils.logger import logger
from app.modules.notification.service import central_notification

module_logger = logging.getLogger(__name__)


class SchemeService:
    """
    Government Schemes Service
    Manages schemes and scheme applications
    """
    
    def __init__(self, db):
        self.db = db
        self.schemes = db.schemes
        self.applications = db.scheme_applications
        self.auth = db.auth
        self.profile = db.profile
    
    # ============================================================
    # SCHEME LISTING & RETRIEVAL
    # ============================================================
    
    async def list_schemes(
        self,
        level: Optional[str] = None,
        state: Optional[str] = None,
        category: Optional[str] = None,
        search: Optional[str] = None,
        is_featured: Optional[bool] = None,
        limit: int = 50,
        skip: int = 0
    ) -> Dict[str, Any]:
        """
        List all active schemes with filters
        """
        try:
            query = {"is_active": True}
            
            if level and level != "all":
                query["level"] = level
            
            if state and state != "all":
                query["state"] = state
            
            if category and category != "all":
                query["category"] = category
            
            if is_featured is not None:
                query["is_featured"] = is_featured
            
            if search and search.strip():
                search_term = search.strip()
                query["$or"] = [
                    {"scheme_name": {"$regex": search_term, "$options": "i"}},
                    {"scheme_name_hindi": {"$regex": search_term, "$options": "i"}},
                    {"short_description": {"$regex": search_term, "$options": "i"}},
                    {"short_description_hindi": {"$regex": search_term, "$options": "i"}},
                    {"tags": {"$in": [search_term.lower()]}},
                    {"search_keywords": {"$in": [search_term.lower()]}},
                ]
            
            total = await self.schemes.count_documents(query)
            
            schemes = await self.schemes.find(query).sort(
                [("priority", -1), ("created_at", -1)]
            ).skip(skip).limit(limit).to_list(limit)
            
            # Serialize
            for scheme in schemes:
                scheme["_id"] = str(scheme["_id"])
                if "created_at" in scheme and isinstance(scheme["created_at"], datetime):
                    scheme["created_at"] = scheme["created_at"].isoformat()
                if "updated_at" in scheme and isinstance(scheme["updated_at"], datetime):
                    scheme["updated_at"] = scheme["updated_at"].isoformat()
            
            return {
                "success": True,
                "schemes": schemes,
                "total": total,
                "skip": skip,
                "limit": limit
            }
            
        except Exception as e:
            module_logger.error(f"Error listing schemes: {e}")
            raise HTTPException(status_code=500, detail=str(e))
    
    async def get_scheme_detail(self, scheme_id: str) -> Dict[str, Any]:
        """
        Get detailed information about a specific scheme
        """
        try:
            scheme = await self.schemes.find_one({
                "scheme_id": scheme_id,
                "is_active": True
            })
            
            if not scheme:
                raise HTTPException(status_code=404, detail="Scheme not found")
            
            scheme["_id"] = str(scheme["_id"])
            if "created_at" in scheme and isinstance(scheme["created_at"], datetime):
                scheme["created_at"] = scheme["created_at"].isoformat()
            if "updated_at" in scheme and isinstance(scheme["updated_at"], datetime):
                scheme["updated_at"] = scheme["updated_at"].isoformat()
            
            return {
                "success": True,
                "scheme": scheme
            }
            
        except HTTPException:
            raise
        except Exception as e:
            module_logger.error(f"Error getting scheme detail: {e}")
            raise HTTPException(status_code=500, detail=str(e))
    
    async def get_featured_schemes(self, limit: int = 10) -> List[Dict]:
        """Get featured schemes"""
        try:
            schemes = await self.schemes.find({
                "is_active": True,
                "is_featured": True
            }).sort("priority", -1).limit(limit).to_list(limit)
            
            for scheme in schemes:
                scheme["_id"] = str(scheme["_id"])
            
            return schemes
        except Exception as e:
            module_logger.error(f"Error getting featured schemes: {e}")
            return []
    
    async def get_schemes_by_category(self, category: str, limit: int = 20) -> List[Dict]:
        """Get schemes by category"""
        try:
            schemes = await self.schemes.find({
                "is_active": True,
                "category": category
            }).sort("priority", -1).limit(limit).to_list(limit)
            
            for scheme in schemes:
                scheme["_id"] = str(scheme["_id"])
            
            return schemes
        except Exception as e:
            module_logger.error(f"Error getting schemes by category: {e}")
            return []
    
    async def get_states_with_schemes(self) -> List[str]:
        """Get list of states that have schemes"""
        try:
            states = await self.schemes.distinct("state", {
                "is_active": True,
                "level": "state",
                "state": {"$ne": None}
            })
            return sorted(states)
        except Exception as e:
            module_logger.error(f"Error getting states: {e}")
            return []
    
    # ============================================================
    # SCHEME APPLICATION
    # ============================================================
    
    async def create_application(
        self,
        data: Dict[str, Any],
        user_email: str,
        user_id: str,
        background_tasks: BackgroundTasks = None
    ) -> Dict[str, Any]:
        """
        Create a new scheme application
        """
        try:
            scheme_id = data.get("scheme_id")
            if not scheme_id:
                raise HTTPException(status_code=400, detail="scheme_id is required")
            
            # Verify scheme exists
            scheme = await self.schemes.find_one({
                "scheme_id": scheme_id,
                "is_active": True
            })
            
            if not scheme:
                raise HTTPException(status_code=404, detail="Scheme not found")
            
            # Check if already applied
            existing = await self.applications.find_one({
                "user_email": user_email,
                "scheme_id": scheme_id,
                "status": {"$nin": ["rejected", "verification_rejected"]},
                "is_archived": {"$ne": True}
            })
            
            if existing:
                return {
                    "success": False,
                    "message": "You have already applied for this scheme",
                    "application_id": str(existing["_id"]),
                    "status": existing.get("status", "pending")
                }
            
            # Get user profile for additional info
            profile = await self.profile.find_one({"email": user_email})
            user_name = profile.get("full_name") if profile else user_email.split("@")[0]
            user_mobile = profile.get("phone") if profile else None
            
            # Create application
            application_id = str(uuid.uuid4())
            
            application_doc = {
                "application_id": application_id,
                "user_email": user_email,
                "user_id": user_id,
                "user_name": user_name,
                "user_mobile": user_mobile,
                "scheme_id": scheme_id,
                "scheme_name": scheme.get("scheme_name"),
                "scheme_name_hindi": scheme.get("scheme_name_hindi"),
                "scheme_level": scheme.get("level", "central"),
                "scheme_state": scheme.get("state"),
                "scheme_category": scheme.get("category", "other"),
                "applicant_details": data.get("applicant_details", {}),
                "applicant_address": data.get("applicant_address", {}),
                "bank_details": data.get("bank_details"),
                "documents": [],
                "additional_info": data.get("additional_info"),
                "remarks": data.get("remarks"),
                "status": "pending",
                "payment_verification_status": "not_submitted",
                "payment_amount": scheme.get("application_fee", 0),
                "payment_method": "razorpay",
                "is_archived": False,
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow(),
                "applied_at": datetime.utcnow()
            }
            
            result = await self.applications.insert_one(application_doc)
            
            module_logger.info(f"✅ Scheme application created: {application_id}")
            
            # Send notification
            if background_tasks:
                background_tasks.add_task(
                    self._send_application_notification,
                    user_email,
                    user_name,
                    scheme.get("scheme_name"),
                    application_id
                )
            
            return {
                "success": True,
                "application_id": application_id,
                "message": "Application submitted successfully",
                "status": "pending"
            }
            
        except HTTPException:
            raise
        except Exception as e:
            module_logger.error(f"Error creating scheme application: {e}")
            raise HTTPException(status_code=500, detail=str(e))
    
    async def get_user_applications(
        self,
        user_email: str,
        status: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Get all scheme applications for a user
        """
        try:
            query = {
                "user_email": user_email,
                "is_archived": {"$ne": True}
            }
            
            if status and status != "all":
                query["status"] = status
            
            applications = await self.applications.find(query).sort(
                "created_at", -1
            ).to_list(100)
            
            for app in applications:
                app["_id"] = str(app["_id"])
                if "created_at" in app and isinstance(app["created_at"], datetime):
                    app["created_at"] = app["created_at"].isoformat()
                if "updated_at" in app and isinstance(app["updated_at"], datetime):
                    app["updated_at"] = app["updated_at"].isoformat()
                if "applied_at" in app and isinstance(app["applied_at"], datetime):
                    app["applied_at"] = app["applied_at"].isoformat()
            
            return {
                "success": True,
                "applications": applications,
                "total": len(applications)
            }
            
        except Exception as e:
            module_logger.error(f"Error getting user applications: {e}")
            raise HTTPException(status_code=500, detail=str(e))
    
    async def get_application_detail(
        self,
        application_id: str,
        user_email: str
    ) -> Dict[str, Any]:
        """
        Get detailed information about a specific application
        """
        try:
            application = await self.applications.find_one({
                "application_id": application_id,
                "user_email": user_email
            })
            
            if not application:
                raise HTTPException(status_code=404, detail="Application not found")
            
            application["_id"] = str(application["_id"])
            
            # Get scheme details
            scheme = await self.schemes.find_one({
                "scheme_id": application.get("scheme_id")
            })
            
            if scheme:
                scheme["_id"] = str(scheme["_id"])
            
            return {
                "success": True,
                "application": application,
                "scheme": scheme
            }
            
        except HTTPException:
            raise
        except Exception as e:
            module_logger.error(f"Error getting application detail: {e}")
            raise HTTPException(status_code=500, detail=str(e))
    
    async def upload_document(
        self,
        application_id: str,
        user_email: str,
        document_type: str,
        document_name: str,
        document_url: str,
        public_id: str = None
    ) -> Dict[str, Any]:
        """
        Upload a document for a scheme application
        """
        try:
            application = await self.applications.find_one({
                "application_id": application_id,
                "user_email": user_email
            })
            
            if not application:
                raise HTTPException(status_code=404, detail="Application not found")
            
            document = {
                "document_type": document_type,
                "document_name": document_name,
                "document_url": document_url,
                "public_id": public_id,
                "uploaded_at": datetime.utcnow(),
                "verified": False
            }
            
            # Remove existing document of same type
            await self.applications.update_one(
                {"application_id": application_id},
                {"$pull": {"documents": {"document_type": document_type}}}
            )
            
            # Add new document
            await self.applications.update_one(
                {"application_id": application_id},
                {
                    "$push": {"documents": document},
                    "$set": {"updated_at": datetime.utcnow()}
                }
            )
            
            return {
                "success": True,
                "message": "Document uploaded successfully",
                "document": document
            }
            
        except HTTPException:
            raise
        except Exception as e:
            module_logger.error(f"Error uploading document: {e}")
            raise HTTPException(status_code=500, detail=str(e))
    
    # ============================================================
    # ADMIN OPERATIONS
    # ============================================================
    
    async def get_all_applications(
        self,
        admin_email: str,
        status: Optional[str] = None,
        scheme_id: Optional[str] = None,
        limit: int = 100,
        skip: int = 0
    ) -> Dict[str, Any]:
        """
        Get all scheme applications (Admin only)
        """
        try:
            # Verify admin
            admin = await self.auth.find_one({"email": admin_email})
            if not admin or admin.get("role") not in ["admin", "customadmin", "superadmin"]:
                raise HTTPException(status_code=403, detail="Access denied")
            
            query = {"is_archived": {"$ne": True}}
            
            if status and status != "all":
                query["status"] = status
            
            if scheme_id:
                query["scheme_id"] = scheme_id
            
            total = await self.applications.count_documents(query)
            
            applications = await self.applications.find(query).sort(
                "created_at", -1
            ).skip(skip).limit(limit).to_list(limit)
            
            for app in applications:
                app["_id"] = str(app["_id"])
                if "created_at" in app and isinstance(app["created_at"], datetime):
                    app["created_at"] = app["created_at"].isoformat()
                if "updated_at" in app and isinstance(app["updated_at"], datetime):
                    app["updated_at"] = app["updated_at"].isoformat()
            
            return {
                "success": True,
                "applications": applications,
                "total": total,
                "skip": skip,
                "limit": limit
            }
            
        except HTTPException:
            raise
        except Exception as e:
            module_logger.error(f"Error getting all applications: {e}")
            raise HTTPException(status_code=500, detail=str(e))
    
    async def update_application_status(
        self,
        application_id: str,
        status: str,
        admin_email: str,
        notes: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Update application status (Admin only)
        """
        try:
            # Verify admin
            admin = await self.auth.find_one({"email": admin_email})
            if not admin or admin.get("role") not in ["admin", "customadmin", "superadmin"]:
                raise HTTPException(status_code=403, detail="Access denied")
            
            application = await self.applications.find_one({
                "application_id": application_id
            })
            
            if not application:
                raise HTTPException(status_code=404, detail="Application not found")
            
            update_data = {
                "status": status,
                "updated_at": datetime.utcnow(),
                "reviewed_by": admin_email,
                "reviewed_at": datetime.utcnow()
            }
            
            if notes:
                update_data["admin_notes"] = notes
            
            await self.applications.update_one(
                {"application_id": application_id},
                {"$set": update_data}
            )
            
            # Send notification to user
            user_email = application.get("user_email")
            user_name = application.get("user_name", "User")
            scheme_name = application.get("scheme_name", "Scheme")
            
            await central_notification.send_notification(
                user_ids=[user_email],
                notification_type="application_status",
                title=f"Scheme Application Update: {scheme_name}",
                message=f"Your application for '{scheme_name}' has been updated to: {status.upper()}",
                related_id=application_id,
                metadata={
                    "application_id": application_id,
                    "scheme_name": scheme_name,
                    "status": status,
                    "admin_notes": notes
                },
                send_email=True,
                send_websocket=True
            )
            
            return {
                "success": True,
                "message": f"Application status updated to {status}",
                "application_id": application_id
            }
            
        except HTTPException:
            raise
        except Exception as e:
            module_logger.error(f"Error updating application status: {e}")
            raise HTTPException(status_code=500, detail=str(e))
    
    # ============================================================
    # HELPER METHODS
    # ============================================================
    
    async def _send_application_notification(
        self,
        user_email: str,
        user_name: str,
        scheme_name: str,
        application_id: str
    ):
        """Send notification for new application"""
        try:
            await central_notification.send_notification(
                user_ids=[user_email],
                notification_type="application_status",
                title=f"✅ Scheme Application Submitted: {scheme_name}",
                message=f"Dear {user_name}, your application for '{scheme_name}' has been submitted successfully. Application ID: {application_id}",
                related_id=application_id,
                metadata={
                    "application_id": application_id,
                    "scheme_name": scheme_name,
                    "status": "pending"
                },
                send_email=True,
                send_websocket=True
            )
        except Exception as e:
            module_logger.error(f"Error sending notification: {e}")
    
    # ============================================================
    # SEED DATA (For development/testing)
    # ============================================================
    
    async def seed_schemes(self) -> Dict[str, Any]:
        """
        Seed database with sample schemes (for development)
        """
        try:
            # Check if schemes already exist
            count = await self.schemes.count_documents({})
            if count > 0:
                return {
                    "success": True,
                    "message": f"Schemes already seeded ({count} schemes exist)",
                    "seeded": 0
                }
            
            # Sample schemes would be inserted here
            # In production, schemes should be managed via admin panel
            
            return {
                "success": True,
                "message": "Schemes seeding not implemented",
                "seeded": 0
            }
            
        except Exception as e:
            module_logger.error(f"Error seeding schemes: {e}")
            return {
                "success": False,
                "error": str(e)
            }


print("✅ Scheme Service Loaded Successfully")