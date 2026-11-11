# app/core/gdpr/data_anonymizer.py
"""
Data Anonymization for GDPR Compliance
"""

import hashlib
from datetime import datetime
from typing import Dict, Any
from bson import ObjectId

from app.db.connection import get_db
from app.core.utils.logger import logger


class DataAnonymizer:
    """Anonymize user data for GDPR compliance"""
    
    @staticmethod
    async def anonymize_user(user_email: str) -> Dict:
        """Completely anonymize a user's data"""
        try:
            db = get_db()
            
            # Generate anonymous ID
            anonymous_id = hashlib.sha256(f"{user_email}{datetime.utcnow()}".encode()).hexdigest()[:16]
            anonymous_email = f"deleted_{anonymous_id}@anonymized.user"
            
            # Anonymize auth data
            await db.auth.update_one(
                {"email": user_email},
                {
                    "$set": {
                        "email": anonymous_email,
                        "mobile": "0000000000",
                        "name": "Deleted User",
                        "is_active": False,
                        "anonymized_at": datetime.utcnow(),
                        "anonymized": True
                    },
                    "$unset": {
                        "password": "",
                        "pin": "",
                        "refresh_token": "",
                        "device_info": ""
                    }
                }
            )
            
            # Anonymize profile data
            await db.profile.update_one(
                {"email": user_email},
                {
                    "$set": {
                        "full_name": "Deleted User",
                        "email": anonymous_email,
                        "phone": "0000000000",
                        "address": {"city": "Deleted", "country": "Deleted"},
                        "anonymized_at": datetime.utcnow(),
                        "anonymized": True,
                        "skills": [],
                        "experience": [],
                        "education": []
                    }
                }
            )
            
            # Delete or anonymize related data
            await db.applications.delete_many({"applicant_email": user_email})
            await db.notifications.delete_many({"user_email": user_email})
            await db.sessions.delete_many({"user_email": user_email})
            
            # Log the anonymization
            await db.gdpr_logs.insert_one({
                "action": "anonymize",
                "user_email": user_email,
                "anonymous_id": anonymous_id,
                "timestamp": datetime.utcnow(),
                "performed_by": "system"
            })
            
            return {
                "success": True,
                "message": "User data anonymized successfully",
                "anonymous_id": anonymous_id
            }
        except Exception as e:
            logger.error(f"GDPR anonymization failed: {e}")
            return {"success": False, "error": str(e)}
    
    @staticmethod
    async def check_if_anonymized(email: str) -> bool:
        """Check if user data is already anonymized"""
        try:
            db = get_db()
            user = await db.auth.find_one({"email": email})
            return user.get("anonymized", False) if user else False
        except:
            return False


data_anonymizer = DataAnonymizer()