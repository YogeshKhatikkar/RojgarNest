# app/core/security/ip_blacklist.py - UPDATED to use unified security collection
from datetime import datetime, timedelta
from typing import Optional, List, Dict
from app.db.connection import get_db
from app.core.utils.logger import logger
from app.models.security_model import SecurityModel, SecurityType, Severity


class IPBlacklistManager:
    """
    Manage IP blacklisting using unified security collection
    """
    
    def __init__(self):
        self.default_ban_minutes = 60
    
    async def blacklist_ip(self, ip: str, reason: str, 
                          duration_minutes: int = None, 
                          permanent: bool = False) -> bool:
        """Blacklist an IP address"""
        try:
            db = get_db()
            
            expires_at = None
            if not permanent:
                expires_at = datetime.utcnow() + timedelta(
                    minutes=duration_minutes or self.default_ban_minutes
                )
            
            blacklist_entry = SecurityModel.create_blacklist(
                ip=ip,
                reason=reason,
                permanent=permanent,
                hours=(duration_minutes or self.default_ban_minutes) // 60
            )
            
            # Update or insert
            await db.security.update_one(
                {"ip_address": ip, "type": SecurityType.IP_BLACKLIST},
                {
                    "$set": {
                        "reason": reason,
                        "permanent": permanent,
                        "expires_at": expires_at,
                        "attempts": 1,
                        "created_at": datetime.utcnow()
                    }
                },
                upsert=True
            )
            
            logger.warning(f"IP blacklisted: {ip} - Reason: {reason}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to blacklist IP {ip}: {e}")
            return False
    
    async def unblacklist_ip(self, ip: str) -> bool:
        """Remove IP from blacklist"""
        try:
            db = get_db()
            result = await db.security.delete_many({
                "ip_address": ip,
                "type": SecurityType.IP_BLACKLIST
            })
            return result.deleted_count > 0
        except Exception as e:
            logger.error(f"Failed to unblacklist IP {ip}: {e}")
            return False
    
    async def is_blacklisted(self, ip: str) -> bool:
        """Check if IP is blacklisted"""
        try:
            db = get_db()
            entry = await db.security.find_one({
                "ip_address": ip,
                "type": SecurityType.IP_BLACKLIST,
                "$or": [
                    {"expires_at": {"$gt": datetime.utcnow()}},
                    {"permanent": True}
                ]
            })
            return entry is not None
        except:
            return False
    
    async def record_failed_attempt(self, ip: str, user_email: Optional[str] = None) -> Dict:
        """Record failed login attempt for IP"""
        db = get_db()
        
        # Increment attempt counter
        result = await db.security.update_one(
            {"ip_address": ip, "type": SecurityType.IP_BLACKLIST},
            {
                "$inc": {"attempts": 1},
                "$set": {"last_failed_at": datetime.utcnow()},
                "$setOnInsert": {"created_at": datetime.utcnow()}
            },
            upsert=True
        )
        
        # Check if should be blacklisted (5+ failed attempts in 10 minutes)
        entry = await db.security.find_one({
            "ip_address": ip,
            "type": SecurityType.IP_BLACKLIST
        })
        
        # Also log security event
        security_log = SecurityModel.create_log(
            ip=ip,
            event_type="failed_login_attempt",
            severity=Severity.MEDIUM,
            details={"attempts": entry.get("attempts", 0)},
            user_id=user_email
        )
        await db.security.insert_one(security_log.model_dump(by_alias=True))
        
        if entry and entry.get("attempts", 0) >= 5:
            await self.blacklist_ip(
                ip, 
                f"Too many failed attempts: {entry['attempts']}", 
                duration_minutes=30
            )
            return {"blacklisted": True, "reason": "Too many failed attempts"}
        
        return {"blacklisted": False, "attempts": entry.get("attempts", 0)}
    
    async def log_security_event(self, ip: str, event_type: str, severity: str,
                                  details: Dict = None, user_id: str = None) -> bool:
        """Log security event to unified security collection"""
        try:
            db = get_db()
            
            severity_map = {
                "low": Severity.LOW,
                "medium": Severity.MEDIUM,
                "high": Severity.HIGH,
                "critical": Severity.CRITICAL
            }
            
            security_log = SecurityModel.create_log(
                ip=ip,
                event_type=event_type,
                severity=severity_map.get(severity, Severity.MEDIUM),
                details=details,
                user_id=user_id
            )
            
            await db.security.insert_one(security_log.model_dump(by_alias=True))
            return True
        except Exception as e:
            logger.error(f"Failed to log security event: {e}")
            return False
    
    async def get_blacklist_stats(self) -> Dict:
        """Get blacklist statistics"""
        db = get_db()
        
        total = await db.security.count_documents({"type": SecurityType.IP_BLACKLIST})
        permanent = await db.security.count_documents({
            "type": SecurityType.IP_BLACKLIST,
            "permanent": True
        })
        now = datetime.utcnow()
        temporary = await db.security.count_documents({
            "type": SecurityType.IP_BLACKLIST,
            "permanent": False, 
            "expires_at": {"$gt": now}
        })
        
        return {
            "total_blacklisted": total,
            "permanent_bans": permanent,
            "temporary_bans": temporary,
            "active_bans": temporary + permanent
        }
    
    async def get_security_logs(self, limit: int = 100, 
                                 event_type: str = None,
                                 severity: str = None) -> List[Dict]:
        """Get security logs"""
        db = get_db()
        
        query = {"type": SecurityType.SECURITY_LOG}
        if event_type:
            query["event_type"] = event_type
        if severity:
            severity_map = {
                "low": Severity.LOW,
                "medium": Severity.MEDIUM,
                "high": Severity.HIGH,
                "critical": Severity.CRITICAL
            }
            query["severity"] = severity_map.get(severity)
        
        logs = await db.security.find(query).sort("created_at", -1).limit(limit).to_list(limit)
        
        return [
            {
                "id": str(log["_id"]),
                "ip": log.get("ip_address"),
                "event_type": log.get("event_type"),
                "severity": log.get("severity"),
                "details": log.get("details"),
                "timestamp": log["created_at"].isoformat()
            }
            for log in logs
        ]
    
    async def cleanup_expired(self) -> int:
        """Clean up expired temporary bans"""
        db = get_db()
        result = await db.security.delete_many({
            "type": SecurityType.IP_BLACKLIST,
            "permanent": False,
            "expires_at": {"$lt": datetime.utcnow()}
        })
        if result.deleted_count > 0:
            logger.info(f"Cleaned up {result.deleted_count} expired IP bans")
        return result.deleted_count


ip_blacklist = IPBlacklistManager()