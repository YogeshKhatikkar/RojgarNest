# app/core/services/cloudinary.py
# ✅ COMPLETE FIXED VERSION
# ✅ Handles authenticated Cloudinary URLs with re-signing
# ✅ Generates fresh signed URLs for expired signatures
# ✅ Supports both public and authenticated resources

import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, Optional, List
from fastapi import UploadFile
import time
import re

from app.core.config.settings import settings

logger = logging.getLogger(__name__)

# Import cloudinary
try:
    import cloudinary
    import cloudinary.uploader
    from cloudinary.utils import cloudinary_url
    CLOUDINARY_AVAILABLE = True
    logger.info("✅ Cloudinary libraries loaded successfully")
except ImportError as e:
    CLOUDINARY_AVAILABLE = False
    logger.error(f"❌ Cloudinary import error: {e}")

# Configure Cloudinary
if CLOUDINARY_AVAILABLE and settings.CLOUDINARY_CLOUD_NAME:
    cloudinary.config(
        cloud_name=settings.CLOUDINARY_CLOUD_NAME,
        api_key=settings.CLOUDINARY_API_KEY,
        api_secret=settings.CLOUDINARY_API_SECRET,
        secure=True
    )
    logger.info(f"☁️ Cloudinary configured: {settings.CLOUDINARY_CLOUD_NAME}")


# ============================================================
# ✅ CRITICAL: URL PARSER FOR CLOUDINARY URLs
# ============================================================
def parse_cloudinary_url(url: str) -> Optional[Dict[str, Any]]:
    """
    ✅ CRITICAL FIX: Parse a Cloudinary URL to extract components.
    
    Handles URLs like:
    https://res.cloudinary.com/du64hubaf/image/authenticated/s--AR9AIwnK--/v1/RojgarNest_uploads/users_data/user/file.pdf
    
    Returns:
    {
        'cloud_name': 'du64hubaf',
        'resource_type': 'image',
        'type': 'authenticated',
        'version': 'v1',
        'public_id': 'RojgarNest_uploads/users_data/user/file',
        'format': 'pdf',
        'is_authenticated': True
    }
    """
    if not url:
        return None
    
    try:
        # Pattern for Cloudinary URLs with optional signature
        # https://res.cloudinary.com/{cloud}/{resource_type}/{type}/[s--{sig}--/][v{version}/]{public_id}[.{format}]
        pattern = r'https?://res\.cloudinary\.com/([^/]+)/([^/]+)/([^/]+)/(?:s--[^/]+--/)?(?:v(\d+)/)?(.+?)(?:\.([^.]+))?$'
        
        match = re.match(pattern, url)
        
        if not match:
            # Try simpler pattern
            pattern2 = r'https?://res\.cloudinary\.com/([^/]+)/([^/]+)/([^/]+)/(?:v(\d+)/)?(.+?)(?:\.([^.]+))?$'
            match = re.match(pattern2, url)
        
        if not match:
            logger.debug(f"URL does not match Cloudinary pattern: {url[:100]}")
            return None
        
        groups = match.groups()
        
        cloud_name = groups[0]
        resource_type = groups[1]
        url_type = groups[2]
        version = groups[3]
        public_id_raw = groups[4]
        format_ext = groups[5] if len(groups) > 5 else None
        
        # Clean public_id - remove format extension if present
        public_id = public_id_raw
        if format_ext and public_id.endswith(f".{format_ext}"):
            public_id = public_id[:-len(f".{format_ext}")]
        
        is_authenticated = url_type == "authenticated"
        
        return {
            "cloud_name": cloud_name,
            "resource_type": resource_type,
            "type": url_type,
            "version": version,
            "public_id": public_id,
            "format": format_ext,
            "is_authenticated": is_authenticated,
        }
        
    except Exception as e:
        logger.warning(f"Failed to parse Cloudinary URL: {e}")
        return None


# ============================================================
# ✅ CRITICAL: RE-SIGN STORED CLOUDINARY URLS
# ============================================================
def resign_cloudinary_url(
    stored_url: str,
    expires_seconds: int = 86400,  # 24 hours
) -> str:
    """
    ✅ CRITICAL FIX: Takes a stored Cloudinary URL (possibly with expired signature)
    and returns a FRESH signed URL.
    
    This is THE KEY FIX for the error:
    https://res.cloudinary.com/du64hubaf/image/authenticated/s--AR9AIwnK--/v1/...
    
    The signature `s--AR9AIwnK--` expires. We regenerate it.
    
    Args:
        stored_url: The URL stored in MongoDB
        expires_seconds: How long the new URL should be valid
    
    Returns:
        A fresh signed URL (or the original URL if not authenticated)
    """
    if not stored_url:
        return stored_url
    
    # If it's not a Cloudinary URL, return as-is
    if "cloudinary.com" not in stored_url:
        return stored_url
    
    # If it's not authenticated, return as-is (public URLs don't expire)
    if "/authenticated/" not in stored_url:
        logger.debug(f"Public URL, no re-signing needed")
        return stored_url
    
    # Parse the URL
    parsed = parse_cloudinary_url(stored_url)
    if not parsed:
        logger.warning(f"Could not parse URL for re-signing: {stored_url[:100]}")
        return stored_url
    
    try:
        # ✅ Generate fresh signed URL
        fresh_url, options = cloudinary_url(
            parsed["public_id"],
            resource_type=parsed["resource_type"],
            type="authenticated",
            sign_url=True,
            expires_at=int(time.time()) + expires_seconds,
            format=parsed.get("format"),
        )
        
        logger.info(f"✅ Re-signed URL for: {parsed['public_id'][:60]}...")
        logger.info(f"   Expires in: {expires_seconds // 3600} hours")
        
        return fresh_url
        
    except Exception as e:
        logger.error(f"❌ Failed to re-sign URL: {e}")
        return stored_url


def resign_download_url(
    stored_url: str,
    expires_seconds: int = 86400,
) -> str:
    """
    Generate a fresh signed DOWNLOAD URL (forces download).
    """
    if not stored_url:
        return stored_url
    
    if "cloudinary.com" not in stored_url or "/authenticated/" not in stored_url:
        return stored_url
    
    parsed = parse_cloudinary_url(stored_url)
    if not parsed:
        return stored_url
    
    try:
        fresh_url, options = cloudinary_url(
            parsed["public_id"],
            resource_type=parsed["resource_type"],
            type="authenticated",
            sign_url=True,
            flags="attachment",
            expires_at=int(time.time()) + expires_seconds,
            format=parsed.get("format"),
        )
        return fresh_url
    except Exception as e:
        logger.error(f"❌ Failed to re-sign download URL: {e}")
        return stored_url


# ============================================================
# ✅ CRITICAL: SIGN ALL DOCUMENTS IN A LIST
# ============================================================
def sign_document_urls(doc: Dict[str, Any]) -> Dict[str, Any]:
    """
    ✅ Takes a document dict and returns it with FRESH signed URLs.
    
    Signs these fields:
    - url
    - document_url
    - download_url
    - secure_url
    """
    if not doc or not isinstance(doc, dict):
        return doc
    
    result = dict(doc)
    
    url_fields = ["url", "document_url", "download_url", "secure_url"]
    
    for field in url_fields:
        if result.get(field):
            result[field] = resign_cloudinary_url(result[field])
    
    return result


def sign_documents_list(documents: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    ✅ Sign all documents in a list.
    """
    if not documents:
        return []
    
    return [
        sign_document_urls(doc)
        for doc in documents
        if isinstance(doc, dict)
    ]


# ============================================================
# EXISTING FUNCTIONS (UPDATED TO USE RE-SIGNING)
# ============================================================

async def get_signed_view_url(
    public_id: str,
    resource_type: str = "raw",
    expires_seconds: int = 86400,
) -> str:
    """Generate a signed URL for viewing private Cloudinary files in browser."""
    if not CLOUDINARY_AVAILABLE:
        return public_id
    
    # If it's already a full URL, re-sign it
    if public_id.startswith("http"):
        return resign_cloudinary_url(public_id, expires_seconds)
    
    try:
        url, options = cloudinary_url(
            public_id,
            resource_type=resource_type,
            type="authenticated",
            sign_url=True,
            expires_at=int(time.time() + expires_seconds),
        )
        
        logger.info(f"🔐 Generated signed VIEW URL for: {public_id[:60]}...")
        return url
        
    except Exception as e:
        logger.error(f"Failed to generate view URL: {e}")
        return public_id


async def get_signed_download_url(
    public_id: str,
    resource_type: str = "raw",
    expires_seconds: int = 86400,
) -> str:
    """Generate a signed download URL that forces download."""
    if not CLOUDINARY_AVAILABLE:
        return public_id
    
    # If it's already a full URL, re-sign it
    if public_id.startswith("http"):
        return resign_download_url(public_id, expires_seconds)
    
    try:
        url, options = cloudinary_url(
            public_id,
            resource_type=resource_type,
            type="authenticated",
            sign_url=True,
            flags="attachment",
            expires_at=int(time.time() + expires_seconds),
        )
        
        logger.info(f"🔐 Generated signed DOWNLOAD URL for: {public_id[:60]}...")
        return url
        
    except Exception as e:
        logger.error(f"Failed to generate download URL: {e}")
        return public_id


async def upload_private_file(
    file: UploadFile,
    folder: str = "RojgarNest",
    job_id: str = None,
    organization: str = None,
    post_name: str = None,
) -> Dict[str, Any]:
    """Upload PRIVATE file to Cloudinary (not publicly accessible)."""
    
    logger.info("=" * 50)
    logger.info(f"📤 Uploading PRIVATE file to CLOUDINARY")
    logger.info(f"   File: {file.filename}")
    logger.info(f"   Folder: {folder}")
    logger.info("=" * 50)
    
    if not CLOUDINARY_AVAILABLE:
        raise Exception("Cloudinary libraries not installed. Run: pip install cloudinary")
    
    if not settings.CLOUDINARY_CLOUD_NAME:
        raise Exception("Cloudinary not configured. Please check .env file")
    
    try:
        file_content = await file.read()
        file_size = len(file_content)
        await file.seek(0)
        
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        cloudinary_folder = f"rojgarnest/{folder}" if folder else "RojgarNest"
        
        original_filename = file.filename or "file"
        name_without_ext = Path(original_filename).stem
        safe_name = "".join(c for c in name_without_ext if c.isalnum() or c in '._-')[:50]
        
        if job_id:
            public_id = f"{cloudinary_folder}/{timestamp}_{job_id}_{safe_name}"
        else:
            public_id = f"{cloudinary_folder}/{timestamp}_{safe_name}"
        
        public_id = public_id.replace("//", "/")
        
        is_pdf = original_filename.lower().endswith('.pdf')
        resource_type = "raw" if is_pdf else "auto"
        
        logger.info(f"   Uploading to Cloudinary (PRIVATE mode)...")
        logger.info(f"   Public ID: {public_id}")
        
        upload_result = cloudinary.uploader.upload(
            file_content,
            public_id=public_id,
            resource_type=resource_type,
            type="authenticated",
            use_filename=True,
            unique_filename=True,
            overwrite=True,
        )
        
        public_id_result = upload_result.get('public_id')
        resource_type_result = upload_result.get('resource_type', resource_type)
        
        signed_view_url = await get_signed_view_url(
            public_id_result,
            resource_type_result,
            expires_seconds=86400,
        )
        
        signed_download_url = await get_signed_download_url(
            public_id_result,
            resource_type_result,
            expires_seconds=86400,
        )
        
        logger.info(f"✅ Private file uploaded successfully!")
        
        return {
            "url": signed_view_url,
            "download_url": signed_download_url,
            "public_id": public_id_result,
            "resource_type": resource_type_result,
            "filename": original_filename,
            "original_filename": original_filename,
            "size_bytes": file_size,
            "folder_path": cloudinary_folder,
            "storage": "cloudinary",
            "is_pdf": is_pdf,
            "is_public": False,
            "success": True,
        }
        
    except Exception as e:
        logger.error(f"❌ Cloudinary upload failed: {e}")
        raise Exception(f"Cloudinary upload failed: {str(e)}")


async def upload_to_cloudinary(
    file: UploadFile,
    folder: str = "RojgarNest",
    job_id: str = None,
    organization: str = None,
    post_name: str = None,
) -> Dict[str, Any]:
    """Upload file to Cloudinary - Public version."""
    
    logger.info(f"📤 Starting public file upload to CLOUDINARY: {file.filename}")
    
    if not CLOUDINARY_AVAILABLE:
        raise Exception("Cloudinary libraries not installed")
    
    if not settings.CLOUDINARY_CLOUD_NAME:
        raise Exception("Cloudinary not configured")
    
    try:
        file_content = await file.read()
        file_size = len(file_content)
        await file.seek(0)
        
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        cloudinary_folder = f"rojgarnest/{folder}" if folder else "RojgarNest"
        
        original_filename = file.filename or "file"
        name_without_ext = Path(original_filename).stem
        safe_name = "".join(c for c in name_without_ext if c.isalnum() or c in '._-')[:50]
        
        if job_id:
            public_id = f"{cloudinary_folder}/{timestamp}_{job_id}_{safe_name}"
        else:
            public_id = f"{cloudinary_folder}/{timestamp}_{safe_name}"
        
        public_id = public_id.replace("//", "/")
        
        upload_result = cloudinary.uploader.upload(
            file_content,
            public_id=public_id,
            resource_type="auto",
            use_filename=True,
            unique_filename=True,
            overwrite=True,
        )
        
        file_url = upload_result.get('secure_url')
        public_id_result = upload_result.get('public_id')
        
        return {
            "url": file_url,
            "public_id": public_id_result,
            "filename": original_filename,
            "original_filename": original_filename,
            "size_bytes": file_size,
            "folder_path": cloudinary_folder,
            "storage": "cloudinary",
            "success": True,
        }
        
    except Exception as e:
        logger.error(f"❌ Cloudinary upload failed: {e}")
        raise Exception(f"Cloudinary upload failed: {str(e)}")


async def delete_from_cloudinary(file_id: str, resource_type: str = "image") -> Dict[str, Any]:
    """Delete file from Cloudinary."""
    if not CLOUDINARY_AVAILABLE:
        return {"result": "failed", "error": "Cloudinary not available"}
    
    try:
        result = cloudinary.uploader.destroy(file_id, resource_type=resource_type)
        if result.get('result') == 'ok':
            logger.info(f"🗑️ File deleted from Cloudinary: {file_id}")
            return {"result": "success", "deleted": True}
        else:
            logger.error(f"❌ Failed to delete: {file_id} - {result}")
            return {"result": "failed", "error": str(result)}
    except Exception as e:
        logger.error(f"❌ Delete error: {e}")
        return {"result": "failed", "error": str(e)}


async def refresh_signed_url(
    public_id: str,
    resource_type: str = "raw",
    expires_seconds: int = 86400,
) -> Dict[str, Any]:
    """Refresh expired signed URLs for a private file."""
    if not CLOUDINARY_AVAILABLE:
        return {"success": False, "error": "Cloudinary not available"}
    
    try:
        signed_view_url = await get_signed_view_url(
            public_id,
            resource_type,
            expires_seconds=expires_seconds,
        )
        
        signed_download_url = await get_signed_download_url(
            public_id,
            resource_type,
            expires_seconds=expires_seconds,
        )
        
        return {
            "success": True,
            "url": signed_view_url,
            "download_url": signed_download_url,
            "expires_in_hours": expires_seconds // 3600,
        }
        
    except Exception as e:
        logger.error(f"Failed to refresh signed URLs: {e}")
        return {"success": False, "error": str(e)}


async def test_cloudinary_connection() -> Dict[str, Any]:
    """Test Cloudinary connection."""
    if not CLOUDINARY_AVAILABLE:
        return {"success": False, "error": "Cloudinary libraries not installed"}
    
    if not settings.CLOUDINARY_CLOUD_NAME:
        return {"success": False, "error": "Cloudinary not configured"}
    
    try:
        url, options = cloudinary_url("test", format="jpg")
        return {
            "success": True,
            "cloud_name": settings.CLOUDINARY_CLOUD_NAME,
            "message": "Cloudinary configured successfully",
            "test_url": url,
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


async def upload_payment_screenshot(
    file: UploadFile,
    username: str,
    payment_id: str,
) -> Dict[str, Any]:
    """Upload a payment screenshot to Cloudinary."""
    logger.info(f"📤 Uploading payment screenshot for: {username}")
    
    if not CLOUDINARY_AVAILABLE:
        raise Exception("Cloudinary libraries not installed")
    
    if not settings.CLOUDINARY_CLOUD_NAME:
        raise Exception("Cloudinary not configured")
    
    file_content = await file.read()
    file_size = len(file_content)
    await file.seek(0)
    
    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    original_filename = file.filename or "screenshot"
    name_without_ext = Path(original_filename).stem
    safe_name = "".join(c for c in name_without_ext if c.isalnum() or c in '._-')[:50]
    
    folder = f"RojgarNest_uploads/users_data/{username}/payment"
    public_id = f"{folder}/{timestamp}_{payment_id}_{safe_name}"
    public_id = public_id.replace("//", "/")
    
    is_pdf = original_filename.lower().endswith('.pdf')
    resource_type = "raw" if is_pdf else "auto"
    
    upload_result = cloudinary.uploader.upload(
        file_content,
        public_id=public_id,
        resource_type=resource_type,
        type="authenticated",
        use_filename=True,
        unique_filename=True,
        overwrite=True,
    )
    
    public_id_result = upload_result.get('public_id')
    resource_type_result = upload_result.get('resource_type', resource_type)
    
    signed_view_url = await get_signed_view_url(
        public_id_result,
        resource_type_result,
        expires_seconds=86400,
    )
    
    signed_download_url = await get_signed_download_url(
        public_id_result,
        resource_type_result,
        expires_seconds=86400,
    )
    
    return {
        "url": signed_view_url,
        "download_url": signed_download_url,
        "public_id": public_id_result,
        "resource_type": resource_type_result,
        "filename": original_filename,
        "size_bytes": file_size,
        "folder_path": folder,
        "storage": "cloudinary",
        "is_pdf": is_pdf,
        "success": True,
    }


async def upload_user_document(
    file: UploadFile,
    username: str,
    document_type: str = "applications",
) -> Dict[str, Any]:
    """
    Upload user document to Cloudinary under:
        RojgarNest_uploads/users_data/{username}/{document_type}/
    """
    logger.info(f"📤 Uploading user document: {file.filename}")
    
    if not CLOUDINARY_AVAILABLE:
        raise Exception("Cloudinary libraries not installed")
    
    if not settings.CLOUDINARY_CLOUD_NAME:
        raise Exception("Cloudinary not configured")
    
    try:
        file_content = await file.read()
        file_size = len(file_content)
        await file.seek(0)
        
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        
        cloudinary_folder = f"RojgarNest_uploads/users_data/{username}/{document_type}"
        
        original_filename = file.filename or "document"
        name_without_ext = Path(original_filename).stem
        safe_name = "".join(c for c in name_without_ext if c.isalnum() or c in '._-')[:50]
        
        public_id = f"{cloudinary_folder}/{timestamp}_{safe_name}"
        public_id = public_id.replace("//", "/")
        
        is_pdf = original_filename.lower().endswith('.pdf')
        is_image = original_filename.lower().endswith(('.jpg', '.jpeg', '.png', '.webp', '.gif'))
        
        if is_pdf:
            resource_type = "raw"
        elif is_image:
            resource_type = "image"
        else:
            resource_type = "auto"
        
        upload_result = cloudinary.uploader.upload(
            file_content,
            public_id=public_id,
            resource_type=resource_type,
            type="authenticated",
            use_filename=True,
            unique_filename=True,
            overwrite=True,
        )
        
        public_id_result = upload_result.get('public_id')
        resource_type_result = upload_result.get('resource_type', resource_type)
        
        signed_view_url = await get_signed_view_url(
            public_id_result,
            resource_type_result,
            expires_seconds=86400,
        )
        
        signed_download_url = await get_signed_download_url(
            public_id_result,
            resource_type_result,
            expires_seconds=86400,
        )
        
        return {
            "url": signed_view_url,
            "download_url": signed_download_url,
            "public_id": public_id_result,
            "resource_type": resource_type_result,
            "filename": original_filename,
            "size_bytes": file_size,
            "folder_path": cloudinary_folder,
            "storage": "cloudinary",
            "is_pdf": is_pdf,
            "is_image": is_image,
            "is_public": False,
            "success": True,
        }
        
    except Exception as e:
        logger.error(f"❌ Cloudinary upload failed: {e}")
        raise Exception(f"Cloudinary upload failed: {str(e)}")


logger.info("=" * 60)
logger.info("✅ Cloudinary service ready")
logger.info("   ✅ Handles authenticated URLs with re-signing")
logger.info("   ✅ parse_cloudinary_url() - extracts components")
logger.info("   ✅ resign_cloudinary_url() - generates fresh signatures")
logger.info("   ✅ sign_documents_list() - batch signs documents")
logger.info("=" * 60)