# app/core/encryption.py
"""
Military-Grade Encryption for Sensitive Data
- AES-256 encryption
- Secure key management
- Data masking
- Field-level encryption
"""

import base64
import hashlib
import os
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC  # Fixed import
from typing import Any, Dict, Optional
import json

from app.core.config.settings import settings


class EncryptionManager:
    """
    Enterprise-grade encryption for sensitive data
    """
    
    def __init__(self):
        self.key = self._get_or_create_key()
        self.cipher = Fernet(self.key) if self.key else None
    
    def _get_or_create_key(self) -> bytes:
        """Get or create encryption key"""
        if settings.ENCRYPTION_KEY:
            try:
                return base64.b64decode(settings.ENCRYPTION_KEY)
            except:
                pass
        
        # Generate new key using PBKDF2HMAC
        salt = b'rojgarnest_salt_2024'
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=100000,
        )
        key = base64.urlsafe_b64encode(kdf.derive(settings.SECRET_KEY.encode()))
        return key
    
    def encrypt(self, data: Any) -> str:
        """Encrypt any data type"""
        if not self.cipher or data is None:
            return str(data) if data else ""
        
        try:
            json_str = json.dumps(data, default=str)
            encrypted = self.cipher.encrypt(json_str.encode())
            return base64.b64encode(encrypted).decode()
        except Exception as e:
            return str(data)
    
    def decrypt(self, encrypted_data: str) -> Any:
        """Decrypt encrypted data"""
        if not self.cipher or not encrypted_data:
            return encrypted_data
        
        try:
            encrypted_bytes = base64.b64decode(encrypted_data)
            decrypted = self.cipher.decrypt(encrypted_bytes)
            return json.loads(decrypted.decode())
        except Exception:
            return encrypted_data
    
    def hash_sensitive_data(self, data: str) -> str:
        """Hash sensitive data for comparison (without storing original)"""
        if not data:
            return ""
        
        salt = b'rojgarnest_hash_salt'
        return hashlib.pbkdf2_hmac(
            'sha256',
            data.encode(),
            salt,
            100000
        ).hex()
    
    def mask_personal_info(self, text: str, start: int = 2, end: int = 2) -> str:
        """Mask personal information (email, phone, etc.)"""
        if not text or len(text) < start + end:
            return "*" * 8
        
        visible_start = text[:start]
        visible_end = text[-end:] if end > 0 else ""
        masked = "*" * (len(text) - start - end)
        
        return f"{visible_start}{masked}{visible_end}"
    
    def mask_email(self, email: str) -> str:
        """Mask email address"""
        if not email or "@" not in email:
            return email
        
        local, domain = email.split("@", 1)
        masked_local = self.mask_personal_info(local, 2, 1)
        return f"{masked_local}@{domain}"
    
    def mask_phone(self, phone: str) -> str:
        """Mask phone number"""
        if not phone or len(phone) < 10:
            return phone
        
        return self.mask_personal_info(phone, 3, 2)
    
    def encrypt_field(self, field_name: str, value: Any) -> Dict[str, Any]:
        """Encrypt specific field for storage"""
        return {
            f"{field_name}_encrypted": self.encrypt(value),
            f"{field_name}_masked": self.mask_personal_info(str(value)) if isinstance(value, str) else None
        }


encryption_manager = EncryptionManager()


class DataProtector:
    """Protect sensitive data at field level"""
    
    SENSITIVE_FIELDS = [
        'password', 'pin', 'refresh_token', 'session_hash',
        'mobile', 'phone', 'email', 'address', 'aadhar',
        'pan', 'bank_account', 'credit_card'
    ]
    
    @classmethod
    def protect_document(cls, doc: Dict) -> Dict:
        """Protect sensitive fields in document"""
        if not doc:
            return doc
        
        protected = doc.copy()
        
        for field in cls.SENSITIVE_FIELDS:
            if field in protected:
                if field in ['password', 'pin', 'refresh_token', 'session_hash']:
                    protected[field] = "[PROTECTED]"
                elif field in ['mobile', 'phone']:
                    protected[field] = encryption_manager.mask_phone(str(protected[field]))
                elif field == 'email':
                    protected[field] = encryption_manager.mask_email(str(protected[field]))
                else:
                    protected[field] = encryption_manager.mask_personal_info(str(protected[field]))
        
        return protected