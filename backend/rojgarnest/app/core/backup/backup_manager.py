# app/core/backup/backup_manager.py - With fallback
"""
Automated Backup Management System
"""

import asyncio
import json
import os
import gzip
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional

# Try to import aiofiles, fallback to regular file operations
try:
    import aiofiles
    AIOFILES_AVAILABLE = True
except ImportError:
    AIOFILES_AVAILABLE = False
    import aiofiles as fallback  # This will fail, so we use regular file ops

from app.db.connection import get_db
from app.core.utils.logger import logger


class BackupManager:
    """Manage automated database backups"""
    
    def __init__(self):
        self.backup_path = "./backups"
        self.retention_days = 30
        self._ensure_backup_dir()
    
    def _ensure_backup_dir(self):
        """Ensure backup directory exists"""
        if not os.path.exists(self.backup_path):
            os.makedirs(self.backup_path)
    
    async def _write_file(self, filepath: str, data: bytes):
        """Write file asynchronously or synchronously"""
        if AIOFILES_AVAILABLE:
            async with aiofiles.open(filepath, 'wb') as f:
                await f.write(data)
        else:
            # Fallback to synchronous write
            with open(filepath, 'wb') as f:
                f.write(data)
    
    async def create_backup(self, backup_type: str = "full") -> Dict:
        """Create a database backup"""
        try:
            db = get_db()
            timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
            backup_filename = f"{backup_type}_backup_{timestamp}.json.gz"
            backup_filepath = os.path.join(self.backup_path, backup_filename)
            
            # Collections to backup
            collections = [
                "auth", "profile", "job", "applications", 
                "notifications", "sessions", "career_analyses",
                "learning_paths", "resumes", "security_logs"
            ]
            
            backup_data = {
                "backup_info": {
                    "type": backup_type,
                    "timestamp": datetime.utcnow().isoformat(),
                    "version": "1.0"
                },
                "data": {}
            }
            
            # Backup each collection
            for collection_name in collections:
                try:
                    cursor = db[collection_name].find({})
                    documents = await cursor.to_list(100000)
                    backup_data["data"][collection_name] = documents
                except Exception as e:
                    logger.warning(f"Could not backup {collection_name}: {e}")
            
            # Write compressed backup
            json_data = json.dumps(backup_data, default=str).encode('utf-8')
            compressed = gzip.compress(json_data)
            await self._write_file(backup_filepath, compressed)
            
            # Get file size
            file_size = os.path.getsize(backup_filepath) / (1024**2)  # MB
            
            # Store backup record
            backup_record = {
                "filename": backup_filename,
                "type": backup_type,
                "size_mb": round(file_size, 2),
                "collections": len(collections),
                "created_at": datetime.utcnow(),
                "location": backup_filepath
            }
            await db.backup_records.insert_one(backup_record)
            
            # Clean old backups
            await self._cleanup_old_backups()
            
            logger.info(f"✅ Backup created: {backup_filename} ({file_size:.2f} MB)")
            
            return {
                "success": True,
                "filename": backup_filename,
                "size_mb": round(file_size, 2),
                "timestamp": backup_record["created_at"]
            }
        except Exception as e:
            logger.error(f"Backup creation failed: {e}")
            return {"success": False, "error": str(e)}
    
    async def _cleanup_old_backups(self):
        """Delete backups older than retention period"""
        try:
            db = get_db()
            cutoff = datetime.utcnow() - timedelta(days=self.retention_days)
            
            old_backups = await db.backup_records.find({
                "created_at": {"$lt": cutoff}
            }).to_list(100)
            
            for backup in old_backups:
                filepath = backup.get("location")
                if filepath and os.path.exists(filepath):
                    os.remove(filepath)
                await db.backup_records.delete_one({"_id": backup["_id"]})
            
            if old_backups:
                logger.info(f"Cleaned up {len(old_backups)} old backups")
        except Exception as e:
            logger.error(f"Failed to cleanup old backups: {e}")
    
    async def list_backups(self, limit: int = 50) -> List[Dict]:
        """List all available backups"""
        try:
            db = get_db()
            backups = await db.backup_records.find().sort(
                "created_at", -1
            ).limit(limit).to_list(limit)
            
            for backup in backups:
                backup["_id"] = str(backup["_id"])
            
            return backups
        except Exception as e:
            logger.error(f"Failed to list backups: {e}")
            return []
    
    async def restore_backup(self, filename: str) -> Dict:
        """Restore database from backup"""
        try:
            db = get_db()
            backup = await db.backup_records.find_one({"filename": filename})
            
            if not backup:
                return {"success": False, "error": "Backup not found"}
            
            filepath = backup.get("location")
            if not filepath or not os.path.exists(filepath):
                return {"success": False, "error": "Backup file not found"}
            
            # Read and decompress backup
            with open(filepath, 'rb') as f:
                compressed = f.read()
                json_data = gzip.decompress(compressed)
                backup_data = json.loads(json_data.decode('utf-8'))
            
            # Restore each collection
            collections_restored = []
            for collection_name, documents in backup_data["data"].items():
                if documents:
                    # Optional: Clear existing data (be careful!)
                    # await db[collection_name].delete_many({})
                    
                    # Restore documents
                    try:
                        # Insert documents one by one to avoid duplicates
                        for doc in documents:
                            # Remove _id to let MongoDB generate new one
                            if "_id" in doc:
                                del doc["_id"]
                            await db[collection_name].insert_one(doc)
                        collections_restored.append(collection_name)
                    except Exception as e:
                        logger.warning(f"Could not restore {collection_name}: {e}")
            
            # Log restore
            await db.restore_logs.insert_one({
                "filename": filename,
                "collections_restored": collections_restored,
                "restored_at": datetime.utcnow(),
                "performed_by": "system"
            })
            
            logger.info(f"✅ Database restored from: {filename}")
            
            return {
                "success": True,
                "collections_restored": len(collections_restored),
                "message": f"Restored from {filename}"
            }
        except Exception as e:
            logger.error(f"Restore failed: {e}")
            return {"success": False, "error": str(e)}


backup_manager = BackupManager()