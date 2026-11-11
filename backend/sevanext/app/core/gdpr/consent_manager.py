# app/core/gdpr/consent_manager.py
"""
User Consent Management for GDPR
"""

from datetime import datetime
from typing import Dict, Any, List, Optional

from app.db.connection import get_db
from app.core.utils.logger import logger


class ConsentManager:
    """Manage user consent for data processing"""
    
    @staticmethod
    async def get_consent(user_email: str) -> Dict:
        """Get user's consent status"""
        try:
            db = get_db()
            consent = await db.user_consent.find_one({"user_email": user_email})
            
            if not consent:
                return {
                    "has_consent": False,
                    "consent_given_at": None,
                    "purposes": [],
                    "can_withdraw": True
                }
            
            return {
                "has_consent": consent.get("has_consent", False),
                "consent_given_at": consent.get("consent_given_at"),
                "purposes": consent.get("purposes", []),
                "version": consent.get("version", "1.0"),
                "can_withdraw": True
            }
        except Exception as e:
            logger.error(f"Failed to get consent: {e}")
            return {"has_consent": False, "error": str(e)}
    
    @staticmethod
    async def update_consent(user_email: str, has_consent: bool, 
                             purposes: List[str], version: str = "1.0") -> Dict:
        """Update user's consent"""
        try:
            db = get_db()
            
            await db.user_consent.update_one(
                {"user_email": user_email},
                {
                    "$set": {
                        "has_consent": has_consent,
                        "consent_given_at": datetime.utcnow() if has_consent else None,
                        "purposes": purposes,
                        "version": version,
                        "updated_at": datetime.utcnow()
                    }
                },
                upsert=True
            )
            
            # Log consent change
            await db.consent_logs.insert_one({
                "user_email": user_email,
                "action": "update",
                "has_consent": has_consent,
                "purposes": purposes,
                "timestamp": datetime.utcnow(),
                "ip_address": "system"
            })
            
            return {
                "success": True,
                "message": "Consent updated successfully"
            }
        except Exception as e:
            logger.error(f"Failed to update consent: {e}")
            return {"success": False, "error": str(e)}
    
    @staticmethod
    async def withdraw_consent(user_email: str) -> Dict:
        """Withdraw user consent"""
        return await ConsentManager.update_consent(user_email, False, [])
    
    @staticmethod
    async def get_consent_logs(user_email: str, limit: int = 50) -> List[Dict]:
        """Get consent change history"""
        try:
            db = get_db()
            logs = await db.consent_logs.find(
                {"user_email": user_email}
            ).sort("timestamp", -1).limit(limit).to_list(limit)
            
            for log in logs:
                log["_id"] = str(log["_id"])
            
            return logs
        except Exception as e:
            logger.error(f"Failed to get consent logs: {e}")
            return []


consent_manager = ConsentManager()