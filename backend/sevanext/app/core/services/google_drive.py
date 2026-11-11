# app/core/services/google_drive.py - UPDATED with Shared Drive support

import logging
from datetime import datetime
from typing import Dict, Any, Optional
from pathlib import Path

from fastapi import UploadFile
from app.core.config.settings import settings

logger = logging.getLogger(__name__)

try:
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
    from googleapiclient.http import MediaInMemoryUpload
    from googleapiclient.errors import HttpError
    GOOGLE_DRIVE_AVAILABLE = True
    logger.info("✅ Google Drive libraries loaded successfully")
except ImportError as e:
    GOOGLE_DRIVE_AVAILABLE = False
    logger.error(f"❌ Google Drive libraries not installed: {e}")


class GoogleDriveService:
    """Google Drive service for uploading job advertisements - SHARED DRIVE SUPPORT"""
    
    def __init__(self):
        self.drive_service = None
        self.target_folder_id = None
        self.shared_drive_id = None
        self._initialize()
    
    def _initialize(self):
        """Initialize Google Drive service using JSON key file with Shared Drive support"""
        if not GOOGLE_DRIVE_AVAILABLE:
            logger.error("❌ Google Drive libraries not installed")
            return
        
        try:
            folder_id = getattr(settings, 'GOOGLE_DRIVE_FOLDER_ID', None)
            
            logger.info("=" * 50)
            logger.info("📁 Initializing Google Drive Service...")
            logger.info(f"   Target Folder ID: {folder_id}")
            
            if not folder_id:
                logger.error("❌ Missing GOOGLE_DRIVE_FOLDER_ID in .env")
                return
            
            # Path to service account JSON key file
            json_key_path = Path(__file__).parent.parent.parent.parent / "service-account-key.json"
            
            if not json_key_path.exists():
                logger.error(f"❌ Service account key file not found: {json_key_path}")
                logger.info("   Please download the JSON key from Google Cloud Console")
                logger.info("   and save it as: service-account-key.json")
                return
            
            logger.info(f"   Using key file: {json_key_path}")
            
            # Create credentials from JSON file with FULL DRIVE scope
            credentials = service_account.Credentials.from_service_account_file(
                json_key_path,
                scopes=['https://www.googleapis.com/auth/drive']
            )
            
            # Build service
            self.drive_service = build('drive', 'v3', credentials=credentials)
            self.target_folder_id = folder_id
            
            # Check if this is a Shared Drive folder
            folder = self.drive_service.files().get(
                fileId=folder_id,
                fields='id, name, mimeType, driveId, capabilities',
                supportsAllDrives=True
            ).execute()
            
            if folder.get('driveId'):
                self.shared_drive_id = folder['driveId']
                logger.info(f"✅ Connected to SHARED DRIVE: {folder.get('name')}")
                logger.info(f"   Drive ID: {self.shared_drive_id}")
                logger.info(f"   Folder ID: {folder.get('id')}")
            else:
                logger.warning(f"⚠️ Connected to personal folder: {folder.get('name')}")
                logger.warning("   Service accounts have limited storage in personal folders!")
                logger.warning("   Recommended: Use a Shared Drive for unlimited storage")
            
            logger.info("=" * 50)
            
        except HttpError as e:
            logger.error(f"❌ Google Drive HTTP error: {e}")
            if e.resp.status == 404:
                logger.error("   Folder not found! Check GOOGLE_DRIVE_FOLDER_ID")
                logger.info("   Make sure the folder exists and is shared with the service account")
            elif e.resp.status == 403:
                logger.error("   Permission denied! Add service account as Manager to the folder/drive")
            self.drive_service = None
        except Exception as e:
            logger.error(f"❌ Google Drive initialization failed: {e}")
            self.drive_service = None
    
    async def upload_advertisement(
        self, 
        file: UploadFile, 
        job_id: str, 
        organization: str,
        post_name: str
    ) -> Dict[str, Any]:
        """Upload advertisement file to Google Drive Shared Drive"""
        if not self.drive_service:
            raise Exception("Google Drive service not initialized. Check that service-account-key.json exists and folder ID is correct.")
        
        try:
            file_content = await file.read()
            original_filename = file.filename or "advertisement"
            
            timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
            org_short = organization.replace(' ', '_')[:20] if organization else "company"
            job_short = post_name.replace(' ', '_')[:20] if post_name else "job"
            
            # Get file extension
            file_ext = Path(original_filename).suffix
            if not file_ext and file.content_type:
                if 'pdf' in file.content_type:
                    file_ext = '.pdf'
                elif 'image' in file.content_type:
                    file_ext = '.jpg'
                else:
                    file_ext = '.bin'
            
            final_filename = f"job_{job_id}_{org_short}_{job_short}_{timestamp}{file_ext}"
            
            logger.info(f"📤 Uploading to Google Drive: {final_filename}")
            logger.info(f"   Original: {original_filename}")
            logger.info(f"   Size: {len(file_content)} bytes")
            if self.shared_drive_id:
                logger.info(f"   📁 Uploading to SHARED DRIVE (unlimited storage)")
            
            media = MediaInMemoryUpload(
                file_content,
                mimetype=file.content_type or 'application/octet-stream',
                resumable=True
            )
            
            file_metadata = {
                'name': final_filename,
                'parents': [self.target_folder_id]
            }
            
            # Upload file with Shared Drive support
            uploaded_file = self.drive_service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id, name, webViewLink, mimeType, size',
                supportsAllDrives=True
            ).execute()
            
            file_id = uploaded_file.get('id')
            file_name = uploaded_file.get('name')
            mime_type = uploaded_file.get('mimeType', '')
            
            # Make file accessible to anyone with the link
            permission = {
                'type': 'anyone',
                'role': 'reader'
            }
            self.drive_service.permissions().create(
                fileId=file_id,
                body=permission,
                supportsAllDrives=True
            ).execute()
            
            # Create direct download link
            if 'pdf' in mime_type.lower():
                direct_link = f"https://drive.google.com/uc?id={file_id}&export=download"
            else:
                direct_link = f"https://drive.google.com/uc?id={file_id}"
            
            logger.info(f"✅ File uploaded successfully!")
            logger.info(f"   File ID: {file_id}")
            logger.info(f"   Direct URL: {direct_link}")
            logger.info(f"   Web Link: {uploaded_file.get('webViewLink')}")
            
            return {
                "url": direct_link,
                "web_link": uploaded_file.get('webViewLink'),
                "file_id": file_id,
                "filename": file_name,
                "original_filename": original_filename,
                "size_bytes": len(file_content),
                "mime_type": mime_type,
                "storage": "google_drive",
                "is_shared_drive": bool(self.shared_drive_id),
                "success": True
            }
            
        except HttpError as e:
            logger.error(f"❌ Google Drive HTTP error: {e}")
            if e.resp.status == 403:
                error_msg = str(e)
                if "storageQuotaExceeded" in error_msg:
                    raise Exception("""
❌ Google Drive storage quota exceeded!

SOLUTION: Use a Shared Drive instead of a personal folder:

1. Go to Google Drive → Click "+ New" → "New Shared Drive"
2. Name it: rojgarnest_ads
3. Add your service account email as Manager:
   - Service account email: rojgarnest@rojgarnest.iam.gserviceaccount.com
4. Get the Shared Drive folder ID (from URL)
5. Update GOOGLE_DRIVE_FOLDER_ID in .env with the Shared Drive folder ID
6. Run the diagnostic script again: python test_drive.py
""")
                elif "permission" in error_msg.lower():
                    raise Exception("Permission denied. Please add the service account as Manager to the folder/drive.")
            raise Exception(f"Google Drive upload failed: {e}")
        except Exception as e:
            logger.error(f"❌ Google Drive upload failed: {e}")
            raise Exception(f"Google Drive upload failed: {str(e)}")
    
    async def delete_file(self, file_id: str) -> bool:
        """Delete file from Google Drive"""
        if not self.drive_service:
            return False
        try:
            self.drive_service.files().delete(
                fileId=file_id,
                supportsAllDrives=True
            ).execute()
            logger.info(f"🗑️ Deleted file: {file_id}")
            return True
        except Exception as e:
            logger.error(f"Delete failed: {e}")
            return False
    
    async def test_connection(self) -> Dict[str, Any]:
        """Test Google Drive connection"""
        if not self.drive_service:
            project_root = Path(__file__).parent.parent.parent.parent
            json_path = project_root / "service-account-key.json"
            return {
                "success": False,
                "error": "Service not initialized",
                "message": f"Check that {json_path} exists and folder ID is correct"
            }
        
        try:
            folder = self.drive_service.files().get(
                fileId=self.target_folder_id,
                fields='id, name, createdTime, driveId, capabilities',
                supportsAllDrives=True
            ).execute()
            
            is_shared_drive = bool(folder.get('driveId'))
            
            return {
                "success": True,
                "folder": {
                    "id": folder.get('id'),
                    "name": folder.get('name'),
                    "is_shared_drive": is_shared_drive,
                    "drive_id": folder.get('driveId')
                },
                "service_account_email": "rojgarnest@rojgarnest.iam.gserviceaccount.com",
                "message": "Google Drive connection successful" + (" (Shared Drive - Unlimited Storage)" if is_shared_drive else " (Personal Folder - Limited Storage)")
            }
        except HttpError as e:
            return {
                "success": False,
                "error": str(e),
                "message": f"HTTP Error: {e.resp.status} - {e.error_details}"
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "message": "Failed to connect to Google Drive"
            }


google_drive_service = GoogleDriveService()