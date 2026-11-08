# app/core/encryption.py
"""
Military-Grade Encryption for Sensitive Data
- AES-256 (Fernet) encryption
- Safe key derivation with validation
- Data masking
- Field-level encryption

FIXED: Invalid ENCRYPTION_KEY no longer crashes the app.
      Validates key is exactly 32 bytes before use.
"""

import base64
import hashlib
import json
import logging
from typing import Any, Dict, Optional

from cryptography.fernet import Fernet, InvalidToken
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

from app.core.config.settings import settings

logger = logging.getLogger(__name__)

_FERNET_KEY_BYTES = 32           # Fernet requires exactly 32 raw bytes
_FERNET_KEY_B64_LEN = 44         # 32 bytes → 44 chars base64 (with '=' padding)
_PBKDF2_SALT = b"rojgarnest_salt_2024"
_PBKDF2_ITERATIONS = 100_000
_HASH_SALT = b"rojgarnest_hash_salt"


class EncryptionManager:
    """
    Enterprise-grade encryption for sensitive data.

    Key resolution order:
      1. settings.ENCRYPTION_KEY  — if it's a valid Fernet key (44-char b64, 32 bytes decoded)
      2. PBKDF2(SECRET_KEY)       — deterministic fallback if #1 missing/invalid
      3. None                     — encryption disabled (encrypt/decrypt become pass-through)
    """

    def __init__(self):
        self.key: Optional[bytes] = self._resolve_key()
        self.cipher: Optional[Fernet] = None

        if self.key is not None:
            try:
                self.cipher = Fernet(self.key)
                logger.info("✅ EncryptionManager ready (Fernet AES-256).")
            except Exception as e:
                # Should never happen because _resolve_key validates, but belt-and-braces
                logger.error("❌ Fernet init failed despite validated key: %s", e)
                self.cipher = None
        else:
            logger.warning(
                "⚠️  Encryption DISABLED — no valid ENCRYPTION_KEY and no SECRET_KEY fallback."
            )

    # ------------------------------------------------------------
    # KEY RESOLUTION
    # ------------------------------------------------------------
    def _resolve_key(self) -> Optional[bytes]:
        """
        Return a 32-byte Fernet key, or None if encryption is disabled.

        Priority:
          1. settings.ENCRYPTION_KEY  (validated strictly)
          2. Derive from settings.SECRET_KEY via PBKDF2
        """
        raw_env = (getattr(settings, "ENCRYPTION_KEY", "") or "").strip()

        # ---- Path 1: explicit ENCRYPTION_KEY ----
        if raw_env:
            key = self._validate_fernet_key(raw_env)
            if key is not None:
                logger.info("🔐 Using ENCRYPTION_KEY from settings.")
                return key
            else:
                logger.warning(
                    "⚠️  ENCRYPTION_KEY is set but INVALID (must be 44-char urlsafe "
                    "base64 of 32 bytes, e.g. from Fernet.generate_key()). "
                    "Falling back to PBKDF2(SECRET_KEY)."
                )
                logger.warning(
                    "    Generate a valid key with: "
                    "python -c \"from cryptography.fernet import Fernet; "
                    "print(Fernet.generate_key().decode())\""
                )

        # ---- Path 2: derive from SECRET_KEY ----
        secret = (getattr(settings, "SECRET_KEY", "") or "").strip()
        if secret:
            try:
                kdf = PBKDF2HMAC(
                    algorithm=hashes.SHA256(),
                    length=_FERNET_KEY_BYTES,
                    salt=_PBKDF2_SALT,
                    iterations=_PBKDF2_ITERATIONS,
                )
                derived = base64.urlsafe_b64encode(kdf.derive(secret.encode()))
                # Validate before returning
                validated = self._validate_fernet_key(derived.decode())
                if validated is not None:
                    logger.info("🔐 Using PBKDF2-derived key from SECRET_KEY.")
                    return validated
                else:
                    logger.error("❌ PBKDF2-derived key failed validation — this should never happen.")
                    return None
            except Exception as e:
                logger.error("❌ PBKDF2 key derivation failed: %s", e)
                return None

        # ---- Path 3: disabled ----
        logger.error(
            "❌ Neither ENCRYPTION_KEY nor SECRET_KEY is set. Encryption is disabled."
        )
        return None

    @staticmethod
    def _validate_fernet_key(candidate: str) -> Optional[bytes]:
        """
        Return a valid 32-byte Fernet key if `candidate` is correct, else None.
        Checks:
          - length (44 chars)
          - decodes as urlsafe base64
          - decoded byte-length == 32
          - Fernet() constructor accepts it
        """
        s = candidate.strip()
        if not s:
            return None

        # Fernet keys are always exactly 44 chars (32 bytes → b64 with padding)
        if len(s) != _FERNET_KEY_B64_LEN:
            return None

        try:
            decoded = base64.urlsafe_b64decode(s.encode())
        except Exception:
            return None

        if len(decoded) != _FERNET_KEY_BYTES:
            return None

        try:
            Fernet(decoded)  # final authority — raises if wrong
        except Exception:
            return None

        return decoded

    # ------------------------------------------------------------
    # ENCRYPT / DECRYPT
    # ------------------------------------------------------------
    def encrypt(self, data: Any) -> str:
        """
        Encrypt any JSON-serializable value.
        Returns a base64 string of the Fernet token.
        If encryption is disabled or value is None, returns str(data) (pass-through).
        """
        if data is None:
            return ""
        if self.cipher is None:
            return str(data)
        try:
            json_str = json.dumps(data, default=str, ensure_ascii=False)
            token = self.cipher.encrypt(json_str.encode("utf-8"))
            return base64.b64encode(token).decode()
        except Exception as e:
            logger.error("❌ encrypt() failed: %s", e)
            return str(data)

    def decrypt(self, encrypted_data: Any) -> Any:
        """
        Reverse of encrypt().
        If the value doesn't look like our token (or decryption fails), returns it unchanged.
        """
        if encrypted_data is None or encrypted_data == "":
            return encrypted_data
        if self.cipher is None:
            return encrypted_data
        try:
            token_bytes = base64.b64decode(encrypted_data)
            plaintext = self.cipher.decrypt(token_bytes)
            return json.loads(plaintext.decode("utf-8"))
        except (InvalidToken, ValueError, TypeError):
            # Not ours / already plaintext / wrong key — return as-is
            return encrypted_data
        except Exception as e:
            logger.error("❌ decrypt() failed: %s", e)
            return encrypted_data

    # ------------------------------------------------------------
    # HASHING
    # ------------------------------------------------------------
    def hash_sensitive_data(self, data: str) -> str:
        """Irreversible PBKDF2-HMAC-SHA256 hash — for equality checks only."""
        if not data:
            return ""
        return hashlib.pbkdf2_hmac(
            "sha256", data.encode("utf-8"), _HASH_SALT, _PBKDF2_ITERATIONS
        ).hex()

    # ------------------------------------------------------------
    # MASKING
    # ------------------------------------------------------------
    def mask_personal_info(self, text: str, start: int = 2, end: int = 2) -> str:
        if not text or len(text) < start + end:
            return "*" * 8
        visible_start = text[:start]
        visible_end = text[-end:] if end > 0 else ""
        masked = "*" * (len(text) - start - end)
        return f"{visible_start}{masked}{visible_end}"

    def mask_email(self, email: str) -> str:
        if not email or "@" not in email:
            return email
        local, domain = email.split("@", 1)
        return f"{self.mask_personal_info(local, 2, 1)}@{domain}"

    def mask_phone(self, phone: str) -> str:
        if not phone or len(phone) < 10:
            return phone
        return self.mask_personal_info(phone, 3, 2)

    # ------------------------------------------------------------
    # FIELD ENCRYPTION HELPER
    # ------------------------------------------------------------
    def encrypt_field(self, field_name: str, value: Any) -> Dict[str, Any]:
        return {
            f"{field_name}_encrypted": self.encrypt(value),
            f"{field_name}_masked": (
                self.mask_personal_info(str(value)) if isinstance(value, str) else None
            ),
        }


# ------------------------------------------------------------------
# Singleton — created once at import time
# ------------------------------------------------------------------
encryption_manager = EncryptionManager()


# ------------------------------------------------------------------
# DataProtector — unchanged public API
# ------------------------------------------------------------------
class DataProtector:
    """Protect sensitive data at field level."""

    SENSITIVE_FIELDS = [
        "password", "pin", "refresh_token", "session_hash",
        "mobile", "phone", "email", "address", "aadhar",
        "pan", "bank_account", "credit_card",
    ]

    @classmethod
    def protect_document(cls, doc: Dict) -> Dict:
        if not doc:
            return doc

        protected = doc.copy()

        for field in cls.SENSITIVE_FIELDS:
            if field in protected:
                if field in ("password", "pin", "refresh_token", "session_hash"):
                    protected[field] = "[PROTECTED]"
                elif field in ("mobile", "phone"):
                    protected[field] = encryption_manager.mask_phone(str(protected[field]))
                elif field == "email":
                    protected[field] = encryption_manager.mask_email(str(protected[field]))
                else:
                    protected[field] = encryption_manager.mask_personal_info(
                        str(protected[field])
                    )

        return protected