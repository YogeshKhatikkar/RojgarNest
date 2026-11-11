# app/modules/notification/service.py
# ============================================================
# ✅ COMPLETE FIXED VERSION (v4)
# ✅ INTEGRATED: Brevo + MSG91 + WhatsApp
# ✅ All notification types now route through unified dispatcher
# ✅ Email: SMTP or Brevo (switchable via .env)
# ✅ SMS: Twilio / MSG91 / Fast2SMS / Brevo (switchable via .env)
# ✅ WhatsApp: MSG91 / Twilio / Meta (switchable via .env)
# ✅ AI-based advanced email formatting for Job, Service, and Scheme
# ✅ FIXED (v3): "Details unavailable" bug
# ✅✅✅ FIXED (v4 — THIS BUILD): Application Number shows as MongoDB _id
#          The root cause was that `send_notification()` received
#          metadata['application_number'] = the raw Mongo _id, and
#          the AI email formatter rendered it verbatim.
#          FIX:
#            1. NEW: `_resolve_canonical_app_number_async()` — accepts
#               any of {_id, application_id, application_number} and
#               returns the true YYYYMMDDSSSS application_number via
#               a DB lookup when the input looks like a Mongo _id.
#            2. `send_notification()` now calls this helper BEFORE
#               building the email — so metadata['application_number']
#               always holds the human-readable number.
#            3. `notify_status_update()` also calls it and passes
#               BOTH `application_number` and `application_id` = the
#               resolved number, so the email header shows the
#               correct YYYYMMDDSSSS value.
#            4. Fallback: if lookup fails, Mongo _id is shortened to
#               "xxxxxxxx...xxxx" (16 chars) instead of 24-char hex,
#               so users never see a raw DB id.
# ============================================================

import asyncio
import re
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from fastapi import HTTPException, BackgroundTasks
from bson import ObjectId
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, List, Union
import logging

# ============================================================
# 📧📱💬 UNIFIED NOTIFICATION IMPORTS
# ============================================================
from app.core.services.email import (
    send_html_email,
    build_modern_ai_notification_email,
    _is_mongo_object_id,
    _is_human_readable,
    resolve_application_number_async,
)
from app.core.services.sms import send_sms_async
from app.core.services.whatsapp import send_whatsapp
from app.core.services.notification_dispatcher import (
    dispatch_otp,
    dispatch_verification_success,
    dispatch_password_reset,
    dispatch_welcome,
    dispatch_application_status,
    dispatch_job_alert,
    dispatch_payment_status,
    dispatch_admin_alert,
)

from app.core.config.settings import settings
from app.db.connection import get_db
from app.modules.notification.websocket import broadcast_notification

logger = logging.getLogger(__name__)


class NotificationType:
    """Notification types for different scenarios"""
    NEW_JOB = "new_job"
    JOB_APPLICATION = "job_application"
    APPLICATION_STATUS = "application_status"
    USER_REGISTRATION = "user_registration"
    USER_VERIFICATION = "user_verification"
    PASSWORD_RESET = "password_reset"
    SYSTEM_ALERT = "system_alert"
    ADMIN_ALERT = "admin_alert"
    SUPERADMIN_ALERT = "superadmin_alert"
    CUSTOMADMIN_ALERT = "customadmin_alert"
    NEW_SCHEME = "new_scheme"
    SCHEME_APPLICATION = "scheme_application"
    SCHEME_STATUS = "scheme_status"
    NEW_SERVICE = "new_service"
    SERVICE_APPLICATION = "service_application"
    SERVICE_STATUS = "service_status"


class UserRole:
    USER = "user"
    ADMIN = "admin"
    SUPERADMIN = "superadmin"
    CUSTOMADMIN = "customadmin"


# ============================================================
# ✅ TITLE PARSER HELPERS
# ============================================================
_TITLE_SCHEME_PATTERNS = [
    re.compile(r"Scheme Status Update:\s*(.+)$", re.IGNORECASE),
    re.compile(r"New Government Scheme:\s*(.+)$", re.IGNORECASE),
    re.compile(r"Scheme Application:\s*(.+)$", re.IGNORECASE),
    re.compile(r"Scheme(?: Payment Verified| Status| Update| Failed)?:\s*(.+)$", re.IGNORECASE),
]
_TITLE_SERVICE_PATTERNS = [
    re.compile(r"Service Status Update:\s*(.+)$", re.IGNORECASE),
    re.compile(r"New Service Available:\s*(.+)$", re.IGNORECASE),
    re.compile(r"Service Application:\s*(.+)$", re.IGNORECASE),
    re.compile(r"Service(?: Payment Verified| Status| Update| Failed)?:\s*(.+)$", re.IGNORECASE),
]
_TITLE_JOB_PATTERNS = [
    re.compile(r"New Job Alert:\s*(.+?)\s+at\s+(.+)$", re.IGNORECASE),
    re.compile(r"Application Status Update:\s*(.+)$", re.IGNORECASE),
    re.compile(r"Application Status:\s*(.+)$", re.IGNORECASE),
]


def _strip_status_suffix(text: str) -> str:
    """
    Remove trailing status annotations from a title segment.
    Example:
        "PM-KISAN — VERIFICATION SUCCESSFUL"  → "PM-KISAN"
        "PM-KISAN (VERIFICATION SUCCESSFUL)"  → "PM-KISAN"
        "PM-KISAN [APPROVED]"                 → "PM-KISAN"
    """
    if not text:
        return ""
    t = text.strip()
    # Trim dash/paren/bracket suffixes
    t = re.sub(r"\s+[—\-–]\s+[A-Z_ ]+$", "", t)
    t = re.sub(r"\s*\([A-Z_ ]+\)\s*$", "", t)
    t = re.sub(r"\s*\[[A-Z_ ]+\]\s*$", "", t)
    return t.strip()


def _extract_name_from_title(title: str, app_type: str) -> Optional[str]:
    """
    Extract a human-readable name from the notification title
    for the given app_type.
    """
    if not title:
        return None

    patterns = []
    if app_type == "scheme":
        patterns = _TITLE_SCHEME_PATTERNS
    elif app_type == "service":
        patterns = _TITLE_SERVICE_PATTERNS
    elif app_type == "job":
        patterns = _TITLE_JOB_PATTERNS

    for pattern in patterns:
        m = pattern.search(title)
        if m:
            # Some patterns have 2 groups (e.g. job title at company)
            if m.lastindex and m.lastindex >= 2:
                candidate = m.group(2) or m.group(1)
            else:
                candidate = m.group(1)
            cleaned = _strip_status_suffix(candidate)
            if cleaned:
                return cleaned

    return None


class CentralNotificationService:
    """
    Centralized Notification Service - One place for all notifications
    ✅ Multi-channel: Email + SMS + WhatsApp + In-App + WebSocket
    ✅ AI-formatted emails for Job, Service, and Scheme
    """

    def __init__(self):
        self.db = None

    async def _get_db(self):
        if self.db is None:
            self.db = get_db()
        return self.db

    # ============================================================
    # ✅✅✅ NEW: CANONICAL APPLICATION NUMBER RESOLVER
    # ============================================================
    async def _resolve_canonical_app_number_async(
        self,
        metadata: Dict[str, Any],
    ) -> str:
        """
        Resolve the true YYYYMMDDSSSS application_number from any of:
          - metadata['application_number']   (if already YYYYMMDDSSSS → returned)
          - metadata['application_id']       (if not ObjectId → returned)
          - metadata['_id'] / metadata['mongo_id']  (ObjectId → DB lookup)
          - metadata['related_id']           (fallback)

        Returns:
            The resolved application_number, or "N/A" if nothing usable.
        """
        if not isinstance(metadata, dict):
            return "N/A"

        # 1) Try explicit application_number first
        app_num = metadata.get("application_number")
        if _is_human_readable(app_num):
            return str(app_num).strip()

        # 2) Try application_id next (may be legacy or true number)
        app_id = metadata.get("application_id")
        if _is_human_readable(app_id):
            # It's non-ObjectId → treat as the real application_number
            return str(app_id).strip()
        if app_id is not None and _is_mongo_object_id(app_id):
            # application_id is a Mongo _id → do DB lookup
            resolved = await resolve_application_number_async(str(app_id))
            if resolved and resolved != "N/A":
                return resolved

        # 3) Try _id / mongo_id / related_id → DB lookup
        for key in ("_id", "mongo_id", "related_id"):
            val = metadata.get(key)
            if val is not None and _is_mongo_object_id(val):
                resolved = await resolve_application_number_async(str(val))
                if resolved and resolved != "N/A":
                    return resolved

        # 4) Try any non-ObjectId _id / related_id
        for key in ("_id", "mongo_id", "related_id"):
            val = metadata.get(key)
            if _is_human_readable(val):
                return str(val).strip()

        return "N/A"

    # ==================== GET ACTIVE USERS WITH ROLE EXCLUSION ====================

    async def get_active_users_for_notification(self, exclude_role: Optional[str] = None) -> List[Dict]:
        """
        Get all active users for notifications
        A user is considered active if is_email_verified = True
        """
        db = await self._get_db()

        query = {"is_email_verified": True}

        if exclude_role == "admin":
            query["role"] = {"$nin": ["admin", "superadmin"]}
            logger.info("📊 Excluding 'admin' and 'superadmin' roles for this notification")
        elif exclude_role == "customadmin":
            query["role"] = {"$nin": ["customadmin", "superadmin"]}
            logger.info("📊 Excluding 'customadmin' and 'superadmin' roles for this notification")
        else:
            logger.info("📊 No role exclusion - sending to all verified users")

        users = await db.auth.find(query).to_list(length=10000)

        mobile_verified_users = await db.auth.find({
            "is_email_verified": False,
            "is_mobile_verified": True
        }).to_list(length=10000)

        all_users = users + mobile_verified_users
        unique_users = {str(u["_id"]): u for u in all_users}.values()

        logger.info(f"📊 Total active users for notification: {len(unique_users)}")

        return list(unique_users)

    async def get_users_by_role(self, roles: List[str]) -> List[Dict]:
        """Get users with specific roles"""
        db = await self._get_db()

        users = await db.auth.find({
            "is_email_verified": True,
            "role": {"$in": roles}
        }).to_list(length=10000)

        return users

    # ==================== BULK EMAIL SENDING (FAST - SINGLE CONNECTION) ====================

    async def send_bulk_email_notification(
        self,
        user_emails: List[str],
        subject: str,
        html_body: str,
        batch_size: int = 50
    ) -> Dict[str, Any]:
        """
        Send bulk email to multiple users using a single SMTP connection
        """
        provider = (settings.EMAIL_PROVIDER or "smtp").lower()
        if provider in ("brevo", "sendgrid", "mailgun"):
            logger.info(f"📧 Bulk email via cloud provider: {provider}")
            from app.core.services.email import get_email_service
            svc = get_email_service()
            sent = 0
            failed = 0
            failed_emails = []
            for em in user_emails:
                ok = await svc.send(
                    to_email=em,
                    subject=subject,
                    html_body=html_body,
                )
                if ok:
                    sent += 1
                else:
                    failed += 1
                    failed_emails.append({"email": em, "error": "provider_failed"})
            return {
                "sent": sent,
                "failed": failed,
                "total": len(user_emails),
                "failed_emails": failed_emails,
            }

        if not settings.SMTP_HOST or not settings.SMTP_USER:
            logger.warning("SMTP not configured, skipping bulk email")
            return {"sent": 0, "failed": 0, "total": len(user_emails)}

        if not user_emails:
            return {"sent": 0, "failed": 0, "total": 0}

        results = {
            "sent": 0,
            "failed": 0,
            "total": len(user_emails),
            "failed_emails": []
        }

        for i in range(0, len(user_emails), batch_size):
            batch = user_emails[i:i + batch_size]

            try:
                server = smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT)
                server.starttls()
                server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)

                for email in batch:
                    try:
                        msg = MIMEMultipart("alternative")
                        msg["From"] = settings.SMTP_FROM
                        msg["To"] = email
                        msg["Subject"] = subject
                        msg.attach(MIMEText(html_body, "html"))

                        server.sendmail(settings.SMTP_FROM, [email], msg.as_string())
                        results["sent"] += 1
                        logger.info(f"📧 Bulk email sent to {email}")

                    except Exception as e:
                        results["failed"] += 1
                        results["failed_emails"].append({"email": email, "error": str(e)})
                        logger.error(f"Failed to send email to {email}: {e}")

                server.quit()

            except Exception as e:
                logger.error(f"SMTP connection failed for batch: {e}")
                for email in batch:
                    results["failed"] += 1
                    results["failed_emails"].append({"email": email, "error": str(e)})

        logger.info(f"📧 Bulk email complete: {results['sent']} sent, {results['failed']} failed")
        return results

    # ==================== CORE NOTIFICATION METHOD ====================

    async def send_notification(
        self,
        user_ids: Union[str, List[str]],
        notification_type: str,
        title: str,
        message: str,
        related_id: Optional[str] = None,
        metadata: Optional[Dict] = None,
        send_email: bool = True,
        send_sms: bool = False,
        send_whatsapp_flag: bool = True,
        send_websocket: bool = True
    ) -> Dict[str, Any]:
        """
        Send notification to one or multiple users across ALL channels.

        ✅ v4 FIX: Before dispatching, we resolve the true application_number
           from any of {_id, application_id, application_number} so that
           emails, websocket payloads, and DB records always carry the
           human-readable YYYYMMDDSSSS value — never a raw 24-char Mongo _id.

        ✅ NEW in v3:
        - Auto-detect app_type from notification_type + title + metadata.
        - Auto-inject scheme_name / service_name / organization into
          metadata (from title) so the email header never shows
          "Details unavailable" even when callers forget to pass them.
        """
        db = await self._get_db()

        # ------------------------------------------------------------
        # ✅ AUTO-ENRICH METADATA BEFORE ANY DISPATCH
        # ------------------------------------------------------------
        metadata = dict(metadata or {})  # copy so we don't mutate caller

        # ✅✅✅ CRITICAL FIX (v4): Resolve the REAL application_number
        resolved_number = await self._resolve_canonical_app_number_async(metadata)
        if resolved_number and resolved_number != "N/A":
            metadata["application_number"] = resolved_number
            # Keep application_id in sync so downstream code works
            metadata["application_id"] = resolved_number
            logger.info(
                f"✅ Resolved application_number: {resolved_number} "
                f"(from metadata: "
                f"app_number={metadata.get('application_number')}, "
                f"app_id={metadata.get('application_id')}, "
                f"related_id={related_id})"
            )
        else:
            logger.warning(
                f"⚠️ Could not resolve application_number from metadata. "
                f"Keys: {list(metadata.keys())}, related_id={related_id}"
            )

        # 1. Detect app type early
        app_type = self._detect_app_type(notification_type, metadata)

        # 2. Make sure metadata["application_type"] is set for later stages
        if not metadata.get("application_type"):
            metadata["application_type"] = app_type

        # 3. Auto-inject the human-readable name if missing
        if app_type == "scheme":
            if not any(metadata.get(k) for k in ("scheme_name", "scheme_name_hindi", "department")):
                extracted = _extract_name_from_title(title, "scheme")
                if extracted:
                    metadata["scheme_name"] = extracted
                    logger.info(f"🛠️ Auto-injected scheme_name from title: {extracted}")
        elif app_type == "service":
            if not any(metadata.get(k) for k in ("service_name", "sub_service_name", "service_type", "department")):
                extracted = _extract_name_from_title(title, "service")
                if extracted:
                    metadata["service_name"] = extracted
                    logger.info(f"🛠️ Auto-injected service_name from title: {extracted}")
        elif app_type == "job":
            if not any(metadata.get(k) for k in ("organization", "company", "job_organization")):
                extracted = _extract_name_from_title(title, "job")
                if extracted:
                    metadata["organization"] = extracted
                    logger.info(f"🛠️ Auto-injected organization from title: {extracted}")

        # ------------------------------------------------------------
        # SEND TO EACH USER
        # ------------------------------------------------------------
        if isinstance(user_ids, str):
            user_ids = [user_ids]

        results = {
            "total_users": len(user_ids),
            "db_notifications": 0,
            "emails_sent": 0,
            "sms_sent": 0,
            "whatsapp_sent": 0,
            "websocket_sent": 0,
            "failed": []
        }

        email_list = []

        for user_id in user_ids:
            try:
                user = None

                if '@' in user_id:
                    user = await db.auth.find_one({"email": user_id})
                    user_id_value = user_id
                else:
                    if ObjectId.is_valid(user_id):
                        user = await db.auth.find_one({"_id": ObjectId(user_id)})
                        user_id_value = user_id
                    else:
                        results["failed"].append({
                            "user_id": user_id,
                            "reason": "Invalid user ID format"
                        })
                        continue

                if not user:
                    results["failed"].append({
                        "user_id": user_id,
                        "reason": "User not found"
                    })
                    continue

                user_email = user.get("email")
                user_name = user.get("name", "User")
                user_role = user.get("role", "user")
                user_mobile = user.get("mobile") or user.get("phone")
                is_email_verified = user.get("is_email_verified", False)
                is_mobile_verified = user.get("is_mobile_verified", False)

                # 1. DB notification (bell icon)
                if is_email_verified or is_mobile_verified:
                    notification_doc = {
                        "user_id": user_id_value,
                        "user_email": user_email,
                        "type": notification_type,
                        "title": title,
                        "message": message,
                        "related_id": metadata.get("application_number") or related_id,
                        "read": False,
                        "created_at": datetime.utcnow(),
                        "metadata": metadata,
                        "user_role": user_role
                    }
                    await db.notifications.insert_one(notification_doc)
                    results["db_notifications"] += 1
                    logger.info(f"📝 DB notification saved for {user_email}: {title[:50]}")

                # 2. Email
                if send_email and user_email and is_email_verified:
                    email_list.append(user_email)

                # 3. SMS
                if send_sms and user_mobile:
                    try:
                        await send_sms_async(
                            to_mobile=user_mobile,
                            message=f"{title}: {message[:120]}",
                            template_id=settings.MSG91_TEMPLATE_ID_ALERT,
                            variables={"name": user_name, "message": message[:140]},
                        )
                        results["sms_sent"] += 1
                        logger.info(f"📱 SMS sent to {user_mobile}: {title[:50]}")
                    except Exception as e:
                        logger.warning(f"SMS send failed for {user_mobile}: {e}")

                # 4. WhatsApp
                if send_whatsapp_flag and user_mobile and settings.WHATSAPP_PROVIDER != "disabled":
                    try:
                        await send_whatsapp(
                            to_mobile=user_mobile,
                            message=f"{title}: {message[:200]}",
                            template_id=settings.MSG91_WHATSAPP_TEMPLATE_ALERT,
                            variables={"name": user_name, "message": message[:200]},
                        )
                        results["whatsapp_sent"] += 1
                        logger.info(f"💬 WhatsApp sent to {user_mobile}: {title[:50]}")
                    except Exception as e:
                        logger.warning(f"WhatsApp send failed for {user_mobile}: {e}")

                # 5. WebSocket
                if send_websocket and (is_email_verified or is_mobile_verified):
                    try:
                        from .websocket import broadcast_notification

                        ws_message = {
                            "type": "new_notification",
                            "notification_type": notification_type,
                            "title": title,
                            "message": message,
                            "user_id": user_id_value,
                            "user_email": user_email,
                            "user_role": user_role,
                            "metadata": metadata,
                            "timestamp": datetime.utcnow().isoformat()
                        }
                        await broadcast_notification(ws_message)
                        results["websocket_sent"] += 1
                        logger.info(f"📡 WebSocket notification sent to {user_email}: {title[:50]}")
                    except Exception as e:
                        logger.warning(f"WebSocket notification failed for {user_email}: {e}")

            except Exception as e:
                logger.error(f"Failed to send notification to {user_id}: {e}")
                results["failed"].append({"user_id": user_id, "reason": str(e)})

        # Bulk emails
        if email_list and send_email:
            html_body = self._create_beautiful_email_html(
                notification_type=notification_type,
                title=title,
                message=message,
                metadata=metadata,
                related_id=metadata.get("application_number") or related_id
            )

            bulk_result = await self.send_bulk_email_notification(
                user_emails=email_list,
                subject=title,
                html_body=html_body,
                batch_size=50
            )
            results["emails_sent"] = bulk_result["sent"]

        logger.info(f"📢 Notification sent: type={notification_type}, results={results}")
        return results

    # ==================== APP TYPE DETECTION ====================

    def _detect_app_type(
        self,
        notification_type: str,
        metadata: Optional[Dict] = None,
    ) -> str:
        """
        ✅ v3: Detect app_type from notification_type + metadata.

        Priority:
          1. explicit metadata['application_type']
          2. notification_type name (contains 'scheme' / 'service' / 'job')
          3. metadata entity hints (scheme_id / service_id / job_id)
          4. title-pattern fallback
          5. default → 'job'
        """
        metadata = metadata or {}

        # 1) Explicit
        explicit = str(metadata.get("application_type") or "").strip().lower()
        if explicit in ("job", "jobs"):
            return "job"
        if explicit in ("service", "services", "online_service"):
            return "service"
        if explicit in ("scheme", "schemes"):
            return "scheme"

        # 2) notification_type contains scheme/service
        nt = (notification_type or "").lower()
        if "scheme" in nt:
            return "scheme"
        if "service" in nt:
            return "service"

        # 3) Entity hints
        if metadata.get("scheme_id"):
            return "scheme"
        if metadata.get("service_id") or metadata.get("sub_type_id") or metadata.get("service_type"):
            return "service"
        if metadata.get("job_id"):
            return "job"

        # 4) Direct metadata name keys
        if metadata.get("scheme_name") or metadata.get("scheme_name_hindi"):
            return "scheme"
        if metadata.get("service_name") or metadata.get("sub_service_name"):
            return "service"
        if metadata.get("organization") or metadata.get("company") or metadata.get("job_title"):
            return "job"

        # 5) Default
        return "job"

    # ==================== ORGANIZATION NAME RESOLVER ====================

    def _resolve_organization_name(
        self,
        app_type: str,
        metadata: Dict[str, Any],
        title: Optional[str] = None,
    ) -> str:
        """
        ✅ v3: Resolve the human-readable organization/department/ministery
        name for the email header.

        Order:
          - explicit keys (organization / company / department / etc.)
          - scheme_name / scheme_name_hindi
          - service_name / sub_service_name / service_type
          - job_title / post_name
          - title-pattern extraction
          - last resort: "Details unavailable"
        """
        metadata = metadata or {}

        def _clean(v) -> Optional[str]:
            if v is None:
                return None
            s = str(v).strip()
            if not s:
                return None
            if s.lower() in ("none", "null", "n/a", "na", "-", "undefined", "nan"):
                return None
            return s

        def _pick(*keys) -> Optional[str]:
            for k in keys:
                cleaned = _clean(metadata.get(k))
                if cleaned:
                    return cleaned
            return None

        picked: Optional[str] = None

        if app_type == "scheme":
            picked = _pick(
                "scheme_name",
                "scheme_name_hindi",
                "department",
                "ministry",
                "sponsoring_ministry",
                "organization",
                "company",
                "scheme_id",
                "job_title",
                "post_name",
            )
        elif app_type == "service":
            picked = _pick(
                "service_name",
                "sub_service_name",
                "service_type",
                "department",
                "organization",
                "company",
                "service_id",
                "job_title",
                "post_name",
            )
        elif app_type == "job":
            picked = _pick(
                "organization",
                "company",
                "job_organization",
                "job_title",
                "post_name",
            )
        else:
            picked = _pick(
                "organization",
                "company",
                "service_name",
                "sub_service_name",
                "scheme_name",
                "scheme_name_hindi",
                "job_title",
                "post_name",
            )

        # Title-pattern fallback
        if not picked and title:
            extracted = _extract_name_from_title(title, app_type)
            if extracted:
                picked = extracted
                logger.info(
                    f"🛠️ Resolved {app_type} name from title fallback: {extracted}"
                )

        if not picked:
            logger.warning(
                f"⚠️ Email formatter: no organization/service/scheme name "
                f"in metadata OR title for type={app_type}. "
                f"Metadata keys: {list(metadata.keys())}. "
                f"Title: {title!r}"
            )
            picked = "Details unavailable"

        return picked

    # ==================== AI-BASED BEAUTIFUL EMAIL TEMPLATE ====================

    def _create_beautiful_email_html(
        self,
        notification_type: str,
        title: str,
        message: str,
        metadata: Optional[Dict] = None,
        related_id: Optional[str] = None
    ) -> str:
        """
        Routes to the ADVANCED AI formatter with different themes
        for Job / Service / Scheme.
        """
        metadata = metadata or {}

        app_type = self._detect_app_type(notification_type, metadata)

        user_name = (
            metadata.get("user_name")
            or metadata.get("applicant_name")
            or "Applicant"
        )

        # ✅ v3: pass title for title-based fallback
        org_or_dept = self._resolve_organization_name(
            app_type, metadata, title=title
        )

        details: Dict[str, Any] = {}

        if app_type == "job":
            details = {
                "Job Title": metadata.get("job_title"),
                "Company": metadata.get("organization"),
                "Location": metadata.get("location"),
                "Job Type": metadata.get("job_type"),
                "Applicant": metadata.get("applicant_name"),
                "Applicant Email": metadata.get("applicant_email"),
                "Application Number": (
                    metadata.get("application_number")
                    or metadata.get("application_id")
                ),
                "Status": metadata.get("status"),
                "Notes": metadata.get("notes") or metadata.get("admin_notes"),
            }
        elif app_type == "service":
            amount = metadata.get("amount")
            details = {
                "Service": metadata.get("service_name")
                    or metadata.get("service_type"),
                "Sub-Service": metadata.get("sub_service_name"),
                "Applicant": metadata.get("user_name"),
                "Applicant Email": metadata.get("user_email"),
                "Application Number": (
                    metadata.get("application_number")
                    or metadata.get("application_id")
                ),
                "Amount": (f"₹{amount}" if amount is not None else None),
                "Payment Status": metadata.get("payment_status"),
                "Transaction ID": metadata.get("transaction_id"),
                "Status": metadata.get("status"),
                "Notes": metadata.get("verification_notes")
                    or metadata.get("admin_notes"),
            }
        elif app_type == "scheme":
            amount = metadata.get("amount")
            details = {
                "Scheme": metadata.get("scheme_name"),
                "Scheme (Hindi)": metadata.get("scheme_name_hindi"),
                "Level": metadata.get("scheme_level"),
                "State": metadata.get("scheme_state"),
                "Applicant": metadata.get("user_name"),
                "Applicant Email": metadata.get("user_email"),
                "Application Number": (
                    metadata.get("application_number")
                    or metadata.get("application_id")
                ),
                "Amount": (f"₹{amount}" if amount is not None else None),
                "Payment Status": metadata.get("payment_status"),
                "Transaction ID": metadata.get("transaction_id"),
                "Status": metadata.get("status"),
                "Notes": metadata.get("admin_notes"),
            }
        else:
            details = {
                "Status": metadata.get("status"),
                "Notes": metadata.get("notes"),
            }

        # Remove empty values
        details = {
            k: v for k, v in details.items()
            if v is not None and str(v).strip() not in ("", "None", "null")
        }

        app_base_url = (settings.APP_BASE_URL or "").rstrip("/")

        if app_type == "job":
            action_url = (
                f"{app_base_url}/jobs/{related_id}" if related_id
                else f"{app_base_url}/jobs"
            )
        elif app_type == "service":
            action_url = f"{app_base_url}/user/services"
        elif app_type == "scheme":
            action_url = f"{app_base_url}/user/schemes"
        else:
            action_url = f"{app_base_url}/user/dashboard"

        # ✅ v4: Use the resolved application_number from metadata first
        # If missing, fall back to related_id
        reference_id = str(
            metadata.get("application_number")
            or metadata.get("application_id")
            or related_id
            or "N/A"
        )

        status_display = str(
            metadata.get("status", "updated")
        ).upper().replace("_", " ")

        try:
            return build_modern_ai_notification_email(
                app_type=app_type,
                title=title,
                organization_or_dept=str(org_or_dept),
                user_name=user_name,
                status=status_display,
                reference_id=reference_id,
                details=details,
                action_url=action_url,
            )
        except Exception as e:
            logger.warning(
                f"⚠️ AI email formatter failed ({e}) — using legacy template"
            )
            return self._legacy_beautiful_email_html(
                notification_type=notification_type,
                title=title,
                message=message,
                metadata=metadata,
                related_id=related_id,
            )

    # ==================== LEGACY FALLBACK TEMPLATE ====================

    def _legacy_beautiful_email_html(
        self,
        notification_type: str,
        title: str,
        message: str,
        metadata: Optional[Dict] = None,
        related_id: Optional[str] = None,
    ) -> str:
        """
        Legacy generic template — used only if AI formatter fails.
        """
        status_config = self._get_status_config(notification_type, metadata)
        current_date = datetime.now().strftime("%B %d, %Y")
        app_base_url = settings.APP_BASE_URL

        metadata = metadata or {}

        job_title = (
            metadata.get('job_title')
            or metadata.get('scheme_name')
            or metadata.get('service_name')
            or ''
        )
        organization = (
            metadata.get('organization')
            or metadata.get('company')
            or metadata.get('scheme_name')
            or metadata.get('scheme_name_hindi')
            or metadata.get('service_name')
            or metadata.get('sub_service_name')
            or ''
        )
        location = metadata.get('location', '')
        job_type = metadata.get('job_type', '')
        status = metadata.get('status', '')
        notes = metadata.get('notes', '')
        application_number = metadata.get('application_number', '')

        gradient_start = status_config.get('gradient_start', '#1e3a8a')
        gradient_end = status_config.get('gradient_end', '#3b82f6')
        badge_color = status_config.get('badge_color', '#3b82f6')
        highlight_bg = status_config.get('highlight_bg', '#eff6ff')
        rgb_color = status_config.get('rgb_color', '59, 130, 246')
        icon = status_config.get('icon', '📢')
        badge_text = status_config.get('badge_text', 'Notification')

        return f"""
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>{title}</title>
            <style>
                * {{ margin: 0; padding: 0; box-sizing: border-box; }}
                body {{
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    padding: 40px 20px;
                    line-height: 1.6;
                }}
                .email-container {{
                    max-width: 600px;
                    margin: 0 auto;
                    background: #ffffff;
                    border-radius: 24px;
                    overflow: hidden;
                    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
                }}
                .email-header {{
                    background: linear-gradient(135deg, {gradient_start}, {gradient_end});
                    padding: 40px 30px;
                    text-align: center;
                    color: white;
                }}
                .header-icon {{
                    width: 80px;
                    height: 80px;
                    background: rgba(255, 255, 255, 0.2);
                    border-radius: 50%;
                    display: inline-flex;
                    align-items: center;
                    justify-content: center;
                    margin-bottom: 20px;
                    font-size: 42px;
                }}
                .email-header h1 {{
                    font-size: 24px;
                    font-weight: 700;
                    margin-bottom: 10px;
                }}
                .status-badge {{
                    display: inline-block;
                    padding: 8px 20px;
                    background: {badge_color};
                    color: white;
                    border-radius: 50px;
                    font-weight: 600;
                    font-size: 14px;
                    margin-top: 20px;
                }}
                .email-content {{ padding: 40px 30px; }}
                .greeting {{
                    font-size: 18px;
                    font-weight: 600;
                    color: #1a202c;
                    margin-bottom: 20px;
                }}
                .message-text {{
                    color: #4a5568;
                    font-size: 16px;
                    margin-bottom: 25px;
                }}
                .job-details {{
                    background: #f8fafc;
                    border-radius: 20px;
                    padding: 25px;
                    margin: 25px 0;
                    border: 1px solid #e2e8f0;
                }}
                .job-title {{
                    font-size: 20px;
                    font-weight: 700;
                    color: #1e3a8a;
                    margin-bottom: 12px;
                }}
                .company-name {{
                    font-size: 16px;
                    color: #475569;
                    margin-bottom: 15px;
                }}
                .ref-number {{
                    font-size: 14px;
                    color: #1e3a8a;
                    font-weight: 700;
                    margin-bottom: 15px;
                    letter-spacing: 0.5px;
                }}
                .job-info-grid {{
                    display: grid;
                    grid-template-columns: repeat(2, 1fr);
                    gap: 12px;
                }}
                .info-item {{
                    font-size: 14px;
                    color: #334155;
                    padding: 8px 12px;
                    background: white;
                    border-radius: 12px;
                }}
                .status-update {{
                    background: {highlight_bg};
                    border-left: 4px solid {gradient_start};
                    border-radius: 12px;
                    padding: 20px;
                    margin: 25px 0;
                }}
                .status-label {{
                    font-size: 14px;
                    font-weight: 600;
                    color: {gradient_start};
                    margin-bottom: 8px;
                    text-transform: uppercase;
                }}
                .status-value {{
                    font-size: 24px;
                    font-weight: 700;
                    color: {gradient_start};
                    display: inline-block;
                    padding: 6px 16px;
                    background: rgba({rgb_color}, 0.1);
                    border-radius: 50px;
                }}
                .admin-notes {{
                    background: #fef3c7;
                    border-radius: 12px;
                    padding: 15px;
                    margin-top: 15px;
                    border-left: 4px solid #f59e0b;
                }}
                .admin-notes p {{ color: #92400e; font-size: 14px; margin: 0; }}
                .action-button {{ text-align: center; margin: 30px 0 20px; }}
                .btn {{
                    display: inline-block;
                    padding: 14px 32px;
                    background: linear-gradient(135deg, {gradient_start}, {gradient_end});
                    color: white;
                    text-decoration: none;
                    border-radius: 50px;
                    font-weight: 600;
                    font-size: 16px;
                    box-shadow: 0 4px 15px rgba(0,0,0,0.2);
                }}
                .email-footer {{
                    background: #f8fafc;
                    padding: 30px;
                    text-align: center;
                    border-top: 1px solid #e2e8f0;
                }}
                .footer-links a {{
                    color: #64748b;
                    text-decoration: none;
                    font-size: 13px;
                    margin: 0 10px;
                }}
                .copyright {{ color: #94a3b8; font-size: 12px; }}
            </style>
        </head>
        <body>
            <div class="email-container">
                <div class="email-header">
                    <div class="header-icon">{icon}</div>
                    <h1>{title}</h1>
                    <p>SevaNext - Your Career Partner</p>
                    <div class="status-badge">{badge_text}</div>
                </div>
                <div class="email-content">
                    <div class="greeting">Dear Job Seeker,</div>
                    <div class="message-text">{message}</div>
                    {self._get_job_details_html(job_title, organization, location, job_type, application_number)}
                    {self._get_status_update_html(notification_type, status, notes, status_config)}
                    {self._get_action_button_html(notification_type, metadata, related_id, app_base_url, status_config)}
                </div>
                <div class="email-footer">
                    <div class="footer-links">
                        <a href="{app_base_url}">Home</a>
                        <a href="{app_base_url}/jobs">Browse Jobs</a>
                        <a href="{app_base_url}/user/applications">My Applications</a>
                        <a href="{app_base_url}/support">Support</a>
                    </div>
                    <div class="copyright">
                        © {current_date} SevaNext. All rights reserved.<br>
                        Find Your Dream Job with AI-Powered Career Guidance
                    </div>
                </div>
            </div>
        </body>
        </html>
        """

    def _get_job_details_html(
        self,
        job_title: str,
        organization: str,
        location: str,
        job_type: str,
        application_number: str = "",
    ) -> str:
        if not job_title and not organization and not application_number:
            return ""

        job_type_display = {
            "private": "🏢 Private",
            "government": "🏛️ Government",
            "remote": "🏠 Remote",
            "hybrid": "🔄 Hybrid",
            "internship": "🎓 Internship",
        }.get(job_type, "💼 " + job_type.capitalize() if job_type else "")

        ref_html = ""
        if application_number:
            ref_html = (
                f'<div class="ref-number">📋 Application No: {application_number}</div>'
            )

        return f"""
        <div class="job-details">
            {ref_html}
            <div class="job-title">{job_title if job_title else 'Application Update'}</div>
            <div class="company-name">{organization if organization else 'Details unavailable'}</div>
            <div class="job-info-grid">
                <div class="info-item">📍 <strong>Location:</strong> {location if location else 'India'}</div>
                <div class="info-item">💼 <strong>Job Type:</strong> {job_type_display}</div>
            </div>
        </div>
        """

    def _get_status_update_html(
        self,
        notification_type: str,
        status: str,
        notes: str,
        status_config: Dict,
    ) -> str:
        status_types = (
            NotificationType.APPLICATION_STATUS,
            NotificationType.SCHEME_STATUS,
            NotificationType.SERVICE_STATUS,
        )
        if notification_type not in status_types or not status:
            return ""

        status_display = status.upper().replace('_', ' ')

        notes_html = ""
        if notes:
            notes_html = f"""
            <div class="admin-notes">
                <p><strong>📝 Admin Notes:</strong> {notes}</p>
            </div>
            """

        return f"""
        <div class="status-update">
            <div class="status-label">Application Status</div>
            <div>
                <span class="status-value">{status_display}</span>
            </div>
            {notes_html}
        </div>
        """

    def _get_action_button_html(
        self,
        notification_type: str,
        metadata: Optional[Dict],
        related_id: Optional[str],
        app_base_url: str,
        status_config: Dict,
    ) -> str:
        if notification_type == NotificationType.NEW_JOB and metadata and metadata.get("job_id"):
            return f"""
            <div class="action-button">
                <a href="{app_base_url}/jobs/{metadata['job_id']}" class="btn">🔍 View Job Details</a>
            </div>
            """

        elif notification_type == NotificationType.JOB_APPLICATION:
            return f"""
            <div class="action-button">
                <a href="{app_base_url}/admin/applications" class="btn">📋 View Applications</a>
            </div>
            """

        elif notification_type == NotificationType.APPLICATION_STATUS:
            if metadata and (metadata.get("scheme_id") or metadata.get("scheme_name")):
                url = f"{app_base_url}/user/schemes"
                label = "🏛️ View My Scheme Application"
            elif metadata and (metadata.get("service_id") or metadata.get("sub_type_id")):
                url = f"{app_base_url}/user/services"
                label = "⚙️ View My Service Application"
            else:
                url = f"{app_base_url}/user/applications"
                label = "📊 Track My Applications"
            return f"""
            <div class="action-button">
                <a href="{url}" class="btn">{label}</a>
            </div>
            """

        elif notification_type == NotificationType.USER_VERIFICATION:
            return f"""
            <div class="action-button">
                <a href="{app_base_url}/user/verification" class="btn">✅ Complete Verification</a>
            </div>
            """

        elif notification_type == NotificationType.PASSWORD_RESET:
            return f"""
            <div class="action-button">
                <a href="{app_base_url}/auth/login" class="btn">🔐 Login to Account</a>
            </div>
            """

        elif notification_type == NotificationType.USER_REGISTRATION:
            return f"""
            <div class="action-button">
                <a href="{app_base_url}/user/dashboard" class="btn">🚀 Go to Dashboard</a>
            </div>
            """

        elif notification_type in (
            NotificationType.NEW_SCHEME,
            NotificationType.SCHEME_APPLICATION,
            NotificationType.SCHEME_STATUS,
        ):
            return f"""
            <div class="action-button">
                <a href="{app_base_url}/user/schemes" class="btn">🏛️ View Schemes Dashboard</a>
            </div>
            """

        elif notification_type in (
            NotificationType.NEW_SERVICE,
            NotificationType.SERVICE_APPLICATION,
            NotificationType.SERVICE_STATUS,
        ):
            return f"""
            <div class="action-button">
                <a href="{app_base_url}/user/services" class="btn">⚙️ View Services Dashboard</a>
            </div>
            """

        return ""

    # ==================== STATUS CONFIGURATIONS ====================

    def _get_status_config(
        self,
        notification_type: str,
        metadata: Optional[Dict],
    ) -> Dict[str, str]:
        configs = {
            NotificationType.NEW_JOB: {
                "icon": "🚀",
                "badge_text": "New Job Opportunity",
                "gradient_start": "#1e3a8a",
                "gradient_end": "#3b82f6",
                "badge_color": "#3b82f6",
                "highlight_bg": "#eff6ff",
                "rgb_color": "59, 130, 246",
            },
            NotificationType.JOB_APPLICATION: {
                "icon": "📝",
                "badge_text": "Application Received",
                "gradient_start": "#7c3aed",
                "gradient_end": "#8b5cf6",
                "badge_color": "#8b5cf6",
                "highlight_bg": "#f5f3ff",
                "rgb_color": "139, 92, 246",
            },
            NotificationType.APPLICATION_STATUS: {
                "icon": "📋",
                "badge_text": "Status Update",
                "gradient_start": "#059669",
                "gradient_end": "#10b981",
                "badge_color": "#10b981",
                "highlight_bg": "#ecfdf5",
                "rgb_color": "16, 185, 129",
            },
            NotificationType.USER_REGISTRATION: {
                "icon": "🎉",
                "badge_text": "Welcome",
                "gradient_start": "#0284c7",
                "gradient_end": "#0ea5e9",
                "badge_color": "#0ea5e9",
                "highlight_bg": "#f0f9ff",
                "rgb_color": "14, 165, 233",
            },
            NotificationType.USER_VERIFICATION: {
                "icon": "✅",
                "badge_text": "Verification",
                "gradient_start": "#16a34a",
                "gradient_end": "#22c55e",
                "badge_color": "#22c55e",
                "highlight_bg": "#f0fdf4",
                "rgb_color": "34, 197, 94",
            },
            NotificationType.PASSWORD_RESET: {
                "icon": "🔒",
                "badge_text": "Security Alert",
                "gradient_start": "#ea580c",
                "gradient_end": "#f97316",
                "badge_color": "#f97316",
                "highlight_bg": "#fff7ed",
                "rgb_color": "249, 115, 22",
            },
            NotificationType.SYSTEM_ALERT: {
                "icon": "⚠️",
                "badge_text": "System Notification",
                "gradient_start": "#dc2626",
                "gradient_end": "#ef4444",
                "badge_color": "#ef4444",
                "highlight_bg": "#fef2f2",
                "rgb_color": "239, 68, 68",
            },
            NotificationType.ADMIN_ALERT: {
                "icon": "👑",
                "badge_text": "Admin Alert",
                "gradient_start": "#0891b2",
                "gradient_end": "#06b6d4",
                "badge_color": "#06b6d4",
                "highlight_bg": "#ecfeff",
                "rgb_color": "6, 182, 212",
            },
            NotificationType.NEW_SCHEME: {
                "icon": "🏛️",
                "badge_text": "Government Welfare Scheme",
                "gradient_start": "#b45309",
                "gradient_end": "#f59e0b",
                "badge_color": "#f59e0b",
                "highlight_bg": "#fef3c7",
                "rgb_color": "245, 158, 11",
            },
            NotificationType.SCHEME_APPLICATION: {
                "icon": "🏛️",
                "badge_text": "Scheme Application",
                "gradient_start": "#b45309",
                "gradient_end": "#f59e0b",
                "badge_color": "#f59e0b",
                "highlight_bg": "#fef3c7",
                "rgb_color": "245, 158, 11",
            },
            NotificationType.SCHEME_STATUS: {
                "icon": "🏛️",
                "badge_text": "Scheme Status Update",
                "gradient_start": "#b45309",
                "gradient_end": "#f59e0b",
                "badge_color": "#f59e0b",
                "highlight_bg": "#fef3c7",
                "rgb_color": "245, 158, 11",
            },
            NotificationType.NEW_SERVICE: {
                "icon": "⚙️",
                "badge_text": "Professional Service",
                "gradient_start": "#047857",
                "gradient_end": "#10b981",
                "badge_color": "#10b981",
                "highlight_bg": "#d1fae5",
                "rgb_color": "16, 185, 129",
            },
            NotificationType.SERVICE_APPLICATION: {
                "icon": "⚙️",
                "badge_text": "Service Application",
                "gradient_start": "#047857",
                "gradient_end": "#10b981",
                "badge_color": "#10b981",
                "highlight_bg": "#d1fae5",
                "rgb_color": "16, 185, 129",
            },
            NotificationType.SERVICE_STATUS: {
                "icon": "⚙️",
                "badge_text": "Service Status Update",
                "gradient_start": "#047857",
                "gradient_end": "#10b981",
                "badge_color": "#10b981",
                "highlight_bg": "#d1fae5",
                "rgb_color": "16, 185, 129",
            },
        }

        if notification_type == NotificationType.APPLICATION_STATUS and metadata:
            status = (metadata.get('status') or '').lower()
            if status == 'shortlisted':
                return {
                    "icon": "⭐",
                    "badge_text": "Shortlisted!",
                    "gradient_start": "#2563eb",
                    "gradient_end": "#3b82f6",
                    "badge_color": "#3b82f6",
                    "highlight_bg": "#eff6ff",
                    "rgb_color": "59, 130, 246",
                }
            elif status == 'interview':
                return {
                    "icon": "📞",
                    "badge_text": "Interview Scheduled",
                    "gradient_start": "#ea580c",
                    "gradient_end": "#f97316",
                    "badge_color": "#f97316",
                    "highlight_bg": "#fff7ed",
                    "rgb_color": "249, 115, 22",
                }
            elif status == 'offered':
                return {
                    "icon": "🎉",
                    "badge_text": "Offer Received!",
                    "gradient_start": "#059669",
                    "gradient_end": "#10b981",
                    "badge_color": "#10b981",
                    "highlight_bg": "#ecfdf5",
                    "rgb_color": "16, 185, 129",
                }
            elif status == 'rejected':
                return {
                    "icon": "📝",
                    "badge_text": "Application Status",
                    "gradient_start": "#dc2626",
                    "gradient_end": "#ef4444",
                    "badge_color": "#ef4444",
                    "highlight_bg": "#fef2f2",
                    "rgb_color": "239, 68, 68",
                }

        return configs.get(
            notification_type,
            configs[NotificationType.SYSTEM_ALERT],
        )

    # ==================== NEW JOB NOTIFICATION ====================

    async def notify_new_job(
        self,
        job_data: Dict,
        background_tasks: BackgroundTasks,
        publisher_role: str = "admin",
    ) -> Dict:
        db = await self._get_db()

        logger.info("=" * 60)
        logger.info(
            f"📢 Starting NEW JOB NOTIFICATION - Publisher Role: {publisher_role}"
        )
        logger.info("=" * 60)

        job_title = job_data.get("post_name", "New Job")
        organization = job_data.get("organization", "Company")
        job_id = str(job_data.get("_id"))
        location = job_data.get("location", "India")
        job_type = job_data.get("job_type", "private")

        title = f"🚀 New Job Alert: {job_title} at {organization}"
        message = (
            f"A new job opportunity '{job_title}' has been posted by "
            f"{organization}. Check out the details below and apply now!"
        )

        metadata = {
            "job_title": job_title,
            "organization": organization,
            "job_id": job_id,
            "location": location,
            "job_type": job_type,
            "application_type": "job",
        }

        publisher_role_lower = publisher_role.lower() if publisher_role else "admin"

        if publisher_role_lower == "customadmin":
            exclude_role = "admin"
            users = await self.get_active_users_for_notification(exclude_role="admin")
            logger.info("📊 CustomAdmin published job - Excluding 'admin' role")
        elif publisher_role_lower == "admin":
            exclude_role = "customadmin"
            users = await self.get_active_users_for_notification(exclude_role="customadmin")
            logger.info("📊 Admin published job - Excluding 'customadmin' role")
        else:
            exclude_role = None
            users = await self.get_active_users_for_notification(exclude_role=None)
            logger.info("📊 SuperAdmin published job - Sending to ALL users")

        user_ids = [str(user["_id"]) for user in users]

        logger.info(f"📊 Total active users for notification: {len(user_ids)}")

        if not user_ids:
            logger.warning("⚠️ No active users found to notify!")
            return {
                "success": False,
                "message": "No active users found to notify",
                "total_users": 0,
                "db_notifications": 0,
                "emails_sent": 0,
                "excluded_role": exclude_role,
            }

        result = await self.send_notification(
            user_ids=user_ids,
            notification_type=NotificationType.NEW_JOB,
            title=title,
            message=message,
            related_id=job_id,
            metadata=metadata,
            send_email=True,
            send_sms=False,
            send_whatsapp_flag=True,
            send_websocket=True,
        )

        result["excluded_role"] = exclude_role
        result["publisher_role"] = publisher_role

        logger.info("=" * 60)
        logger.info("✅ New Job Notification Complete!")
        logger.info("=" * 60)

        return result

    # ==================== NEW SCHEME NOTIFICATION ====================

    async def notify_new_scheme(
        self,
        scheme_data: Dict,
        publisher_role: str = "admin",
    ) -> Dict:
        logger.info("=" * 60)
        logger.info(
            f"🏛️ NEW SCHEME NOTIFICATION - Publisher Role: {publisher_role}"
        )
        logger.info("=" * 60)

        scheme_id = str(
            scheme_data.get("scheme_id")
            or scheme_data.get("_id")
            or ""
        )
        scheme_name = scheme_data.get("scheme_name", "") or ""
        scheme_name_hindi = scheme_data.get("scheme_name_hindi", "") or ""
        scheme_level = scheme_data.get("level", "central")
        scheme_state = scheme_data.get("state")
        scheme_category = scheme_data.get("category", "other")

        display_name = scheme_name or scheme_name_hindi or "Government Scheme"

        title = f"🏛️ New Government Scheme: {display_name}"
        message = (
            f"A new government scheme '{display_name}' has been published. "
            f"Check your eligibility and apply now!"
        )

        metadata = {
            "application_type": "scheme",
            "scheme_id": scheme_id,
            "scheme_name": scheme_name or display_name,
            "scheme_name_hindi": scheme_name_hindi,
            "scheme_level": scheme_level,
            "scheme_state": scheme_state,
            "scheme_category": scheme_category,
            "status": "new",
        }

        publisher_role_lower = (publisher_role or "admin").lower()
        exclude_role = None
        if publisher_role_lower == "customadmin":
            exclude_role = "admin"
        elif publisher_role_lower == "admin":
            exclude_role = "customadmin"

        users = await self.get_active_users_for_notification(exclude_role=exclude_role)
        user_ids = [str(u["_id"]) for u in users]

        if not user_ids:
            logger.warning("⚠️ No active users to notify for new scheme")
            return {
                "success": False,
                "message": "No active users",
                "total_users": 0,
                "emails_sent": 0,
                "excluded_role": exclude_role,
            }

        result = await self.send_notification(
            user_ids=user_ids,
            notification_type=NotificationType.NEW_SCHEME,
            title=title,
            message=message,
            related_id=scheme_id,
            metadata=metadata,
            send_email=True,
            send_sms=False,
            send_whatsapp_flag=True,
            send_websocket=True,
        )

        result["excluded_role"] = exclude_role
        result["publisher_role"] = publisher_role
        logger.info(f"✅ New Scheme Notification Complete: {result}")
        return result

    # ==================== NEW SERVICE NOTIFICATION ====================

    async def notify_new_service(
        self,
        service_data: Dict,
        publisher_role: str = "admin",
    ) -> Dict:
        logger.info("=" * 60)
        logger.info(
            f"⚙️ NEW SERVICE NOTIFICATION - Publisher Role: {publisher_role}"
        )
        logger.info("=" * 60)

        service_id = str(
            service_data.get("service_id")
            or service_data.get("_id")
            or ""
        )
        service_name = service_data.get("service_name", "") or ""
        sub_service_name = service_data.get("sub_service_name", "") or ""
        department = service_data.get("department", "") or "Government Service"

        display_name = service_name or sub_service_name or "Professional Service"

        title = f"⚙️ New Service Available: {display_name}"
        message = (
            f"A new service '{display_name}' is now available. "
            f"Apply online and complete your request quickly."
        )

        metadata = {
            "application_type": "service",
            "service_id": service_id,
            "service_name": service_name or display_name,
            "sub_service_name": sub_service_name,
            "service_type": department,
            "status": "new",
        }

        publisher_role_lower = (publisher_role or "admin").lower()
        exclude_role = None
        if publisher_role_lower == "customadmin":
            exclude_role = "admin"
        elif publisher_role_lower == "admin":
            exclude_role = "customadmin"

        users = await self.get_active_users_for_notification(exclude_role=exclude_role)
        user_ids = [str(u["_id"]) for u in users]

        if not user_ids:
            logger.warning("⚠️ No active users to notify for new service")
            return {
                "success": False,
                "message": "No active users",
                "total_users": 0,
                "emails_sent": 0,
                "excluded_role": exclude_role,
            }

        result = await self.send_notification(
            user_ids=user_ids,
            notification_type=NotificationType.NEW_SERVICE,
            title=title,
            message=message,
            related_id=service_id,
            metadata=metadata,
            send_email=True,
            send_sms=False,
            send_whatsapp_flag=True,
            send_websocket=True,
        )

        result["excluded_role"] = exclude_role
        result["publisher_role"] = publisher_role
        logger.info(f"✅ New Service Notification Complete: {result}")
        return result

    # ==================== SCHEME STATUS NOTIFICATION ====================

    async def notify_scheme_status(
        self,
        user_email: str,
        scheme_name: str,
        scheme_id: str,
        new_status: str,
        notes: Optional[str] = None,
        amount: Optional[int] = None,
        transaction_id: Optional[str] = None,
        payment_status: Optional[str] = None,
        application_number: Optional[str] = None,
        scheme_name_hindi: Optional[str] = None,
        scheme_level: Optional[str] = None,
        scheme_state: Optional[str] = None,
    ) -> Dict:
        db = await self._get_db()

        user = await db.auth.find_one({"email": user_email})
        if not user:
            logger.error(f"User not found for scheme notification: {user_email}")
            return {"success": False, "error": "User not found"}

        user_id = str(user["_id"])

        display_name = scheme_name or scheme_name_hindi or "Scheme Application"

        title = f"🏛️ Scheme Status Update: {display_name}"
        message = (
            f"Your scheme application for '{display_name}' is now "
            f"{new_status.upper().replace('_', ' ')}."
        )
        if application_number:
            message += f"\n\n📋 Application No: {application_number}"

        metadata = {
            "application_type": "scheme",
            "scheme_id": scheme_id,
            "scheme_name": scheme_name or display_name,
            "scheme_name_hindi": scheme_name_hindi,
            "scheme_level": scheme_level,
            "scheme_state": scheme_state,
            "application_id": application_number or scheme_id,
            "application_number": application_number or scheme_id,
            "status": new_status,
            "admin_notes": notes,
            "amount": amount,
            "transaction_id": transaction_id,
            "payment_status": payment_status,
            "user_name": user.get("name"),
            "user_email": user_email,
        }

        return await self.send_notification(
            user_ids=user_id,
            notification_type=NotificationType.SCHEME_STATUS,
            title=title,
            message=message,
            related_id=application_number or scheme_id,
            metadata=metadata,
            send_email=True,
            send_sms=True,
            send_whatsapp_flag=True,
            send_websocket=True,
        )

    # ==================== SERVICE STATUS NOTIFICATION ====================

    async def notify_service_status(
        self,
        user_email: str,
        service_name: str,
        service_id: str,
        new_status: str,
        notes: Optional[str] = None,
        amount: Optional[int] = None,
        transaction_id: Optional[str] = None,
        payment_status: Optional[str] = None,
        sub_service_name: Optional[str] = None,
        application_number: Optional[str] = None,
    ) -> Dict:
        db = await self._get_db()

        user = await db.auth.find_one({"email": user_email})
        if not user:
            logger.error(f"User not found for service notification: {user_email}")
            return {"success": False, "error": "User not found"}

        user_id = str(user["_id"])

        display_name = service_name or sub_service_name or "Service Application"

        title = f"⚙️ Service Status Update: {display_name}"
        message = (
            f"Your service application for '{display_name}' is now "
            f"{new_status.upper().replace('_', ' ')}."
        )
        if application_number:
            message += f"\n\n📋 Application No: {application_number}"

        metadata = {
            "application_type": "service",
            "service_id": service_id,
            "service_name": service_name or display_name,
            "sub_service_name": sub_service_name,
            "application_id": application_number or service_id,
            "application_number": application_number or service_id,
            "status": new_status,
            "admin_notes": notes,
            "amount": amount,
            "transaction_id": transaction_id,
            "payment_status": payment_status,
            "user_name": user.get("name"),
            "user_email": user_email,
        }

        return await self.send_notification(
            user_ids=user_id,
            notification_type=NotificationType.SERVICE_STATUS,
            title=title,
            message=message,
            related_id=application_number or service_id,
            metadata=metadata,
            send_email=True,
            send_sms=True,
            send_whatsapp_flag=True,
            send_websocket=True,
        )

    # ==================== ADMIN NOTIFICATIONS ====================

    async def notify_admins_new_job(self, job_data: Dict):
        db = await self._get_db()

        admins = await db.auth.find({
            "role": {"$in": [UserRole.ADMIN, UserRole.SUPERADMIN]},
            "is_email_verified": True,
        }).to_list(length=1000)

        admin_ids = [str(admin["_id"]) for admin in admins]

        if admin_ids:
            title = f"📢 Admin Alert: New Job Posted - {job_data.get('post_name')}"
            message = (
                f"A new job '{job_data.get('post_name')}' has been posted "
                f"by {job_data.get('organization')}"
            )

            await self.send_notification(
                user_ids=admin_ids,
                notification_type=NotificationType.ADMIN_ALERT,
                title=title,
                message=message,
                related_id=str(job_data.get("_id")),
                metadata={
                    "job_title": job_data.get("post_name"),
                    "organization": job_data.get("organization"),
                    "application_type": "job",
                },
                send_email=True,
                send_websocket=True,
            )

    async def notify_customadmins_new_job(self, job_data: Dict):
        db = await self._get_db()

        customadmins = await db.auth.find({
            "role": UserRole.CUSTOMADMIN,
            "is_email_verified": True,
        }).to_list(length=1000)

        customadmin_ids = [str(admin["_id"]) for admin in customadmins]

        if customadmin_ids:
            title = f"📢 CustomAdmin Alert: New Job Posted - {job_data.get('post_name')}"
            message = (
                f"A new job '{job_data.get('post_name')}' has been posted "
                f"by {job_data.get('organization')}"
            )

            await self.send_notification(
                user_ids=customadmin_ids,
                notification_type=NotificationType.CUSTOMADMIN_ALERT,
                title=title,
                message=message,
                related_id=str(job_data.get("_id")),
                metadata={
                    "job_title": job_data.get("post_name"),
                    "organization": job_data.get("organization"),
                    "application_type": "job",
                },
                send_email=True,
                send_websocket=True,
            )

    async def notify_new_application(
        self,
        application_data: Dict,
        job_data: Dict,
        admin_email: str,
    ) -> Dict:
        db = await self._get_db()

        admin_user = await db.auth.find_one({"email": admin_email})
        if not admin_user:
            logger.error(f"Admin not found: {admin_email}")
            return {"success": False, "error": "Admin not found"}

        admin_id = str(admin_user["_id"])

        job_title = job_data.get("post_name", "Unknown Job")
        organization = job_data.get("organization", "Company")
        applicant_name = application_data.get("applicant_name", "Someone")
        applicant_email = application_data.get("applicant_email", "")
        application_id = application_data.get("application_id", "")
        application_number = application_data.get("application_number", "")

        admin_title = f"📝 New Application Received: {job_title}"
        admin_message = (
            f"{applicant_name} has applied for '{job_title}' at {organization}"
        )
        if application_number:
            admin_message += f"\n\n📋 Application No: {application_number}"

        admin_metadata = {
            "application_type": "job",
            "job_title": job_title,
            "organization": organization,
            "applicant_name": applicant_name,
            "applicant_email": applicant_email,
            "application_id": application_id,
            "application_number": application_number or application_id,
        }

        admin_result = await self.send_notification(
            user_ids=admin_id,
            notification_type=NotificationType.JOB_APPLICATION,
            title=admin_title,
            message=admin_message,
            related_id=application_id,
            metadata=admin_metadata,
            send_email=True,
            send_whatsapp_flag=False,
            send_websocket=True,
        )

        applicant_user = await db.auth.find_one({"email": applicant_email})
        if applicant_user and applicant_user.get("is_email_verified"):
            applicant_id = str(applicant_user["_id"])

            user_title = f"✅ Application Submitted Successfully: {job_title}"
            user_message = (
                f"Your application for '{job_title}' at {organization} "
                f"has been submitted successfully!"
            )
            if application_number:
                user_message += f"\n\n📋 Application No: {application_number}"

            user_metadata = {
                "application_type": "job",
                "job_title": job_title,
                "organization": organization,
                "application_id": application_id,
                "application_number": application_number or application_id,
                "status": "pending",
            }

            await self.send_notification(
                user_ids=applicant_id,
                notification_type=NotificationType.APPLICATION_STATUS,
                title=user_title,
                message=user_message,
                related_id=application_id,
                metadata=user_metadata,
                send_email=True,
                send_sms=True,
                send_whatsapp_flag=True,
                send_websocket=True,
            )

        return admin_result

    # ==================== STATUS UPDATE DISPATCHER ====================
    # ✅✅✅ THIS IS THE KEY FIX — It now resolves the true application_number
    # ====================

    async def notify_status_update(
        self,
        application_id: str,
        new_status: str,
        notes: Optional[str],
        updated_by_email: str,
    ) -> Dict:
        """
        Notify user when admin updates application status.

        ✅ v4 FIX: Resolves the true application_number from DB when
                   `application_id` is a Mongo ObjectId.
        ✅ v3: Application doc is searched across all 3 collections,
                application_type is always set explicitly,
                and scheme_name_hindi / sub_service_name fallbacks are used.
        """
        db = await self._get_db()

        application = None
        app_type = "job"

        # 1. Unified applications collection (preferred)
        if ObjectId.is_valid(application_id):
            try:
                application = await db.applications.find_one(
                    {"_id": ObjectId(application_id)}
                )
            except Exception:
                application = None

        # 2. Fallback by application_id / application_number
        if not application:
            try:
                application = await db.applications.find_one({
                    "$or": [
                        {"application_id": application_id},
                        {"application_number": application_id},
                    ]
                })
            except Exception:
                application = None

        # 3. Legacy collections (if you still have them)
        if not application:
            try:
                application = await db.scheme_applications.find_one(
                    {"application_id": application_id}
                )
                if application:
                    app_type = "scheme"
            except Exception:
                pass

        if not application:
            try:
                application = await db.service_applications.find_one(
                    {"application_id": application_id}
                )
                if application:
                    app_type = "service"
            except Exception:
                pass

        if not application:
            return {"success": False, "error": "Application not found"}

        # Detect app_type from document
        doc_type = (
            application.get("application_type")
            or application.get("payment_type")
            or app_type
        )
        doc_type = str(doc_type).strip().lower()
        if doc_type in ("schemes", "scheme"):
            app_type = "scheme"
        elif doc_type in ("service", "services", "online_service"):
            app_type = "service"
        elif doc_type in ("job", "jobs"):
            app_type = "job"

        applicant_email = (
            application.get("applicant_email")
            or application.get("user_email")
        )

        # ------------------------------------------------------------
        # ✅✅✅ KEY FIX: Resolve the TRUE application_number
        # ------------------------------------------------------------
        # Priority:
        #   1. application["application_number"]  → YYYYMMDDSSSS (best)
        #   2. application["application_id"]      → may also be YYYYMMDDSSSS
        #   3. If either is a Mongo ObjectId, resolve via DB lookup
        #   4. Fall back to shortened ObjectId
        # ------------------------------------------------------------
        resolved_application_number = "N/A"

        raw_num = application.get("application_number")
        raw_id = application.get("application_id")

        if _is_human_readable(raw_num):
            resolved_application_number = str(raw_num).strip()
        elif _is_human_readable(raw_id):
            resolved_application_number = str(raw_id).strip()
        elif raw_id is not None and _is_mongo_object_id(raw_id):
            resolved_application_number = await resolve_application_number_async(str(raw_id))
        elif application.get("_id") is not None:
            resolved_application_number = await resolve_application_number_async(
                str(application["_id"])
            )

        if not resolved_application_number or resolved_application_number == "N/A":
            # Last resort: use the raw input if it's not an ObjectId
            if not _is_mongo_object_id(application_id):
                resolved_application_number = str(application_id)
            else:
                # Shorten the ObjectId so it doesn't look like garbage
                resolved_application_number = f"{application_id[:8]}...{application_id[-4:]}"

        logger.info("=" * 70)
        logger.info(f"📋 STATUS UPDATE — Application number resolution:")
        logger.info(f"   Input application_id       = {application_id}")
        logger.info(f"   Doc application_number    = {raw_num}")
        logger.info(f"   Doc application_id        = {raw_id}")
        logger.info(f"   Doc _id                   = {application.get('_id')}")
        logger.info(f"   ✅ RESOLVED NUMBER        = {resolved_application_number}")
        logger.info("=" * 70)

        # ------------------------------------------------------------
        # Build display names with full fallbacks
        # ------------------------------------------------------------
        scheme_name = (
            application.get("scheme_name")
            or application.get("scheme_name_hindi")
            or ""
        )
        scheme_name_hindi = application.get("scheme_name_hindi") or ""

        sub_service_name = application.get("sub_service_name") or ""
        service_name = application.get("service_name") or ""
        service_type = application.get("service_type") or ""

        job_title = application.get("job_title") or "Job Application"
        organization = application.get("organization") or "Company"

        if app_type == "scheme":
            job_title = scheme_name or scheme_name_hindi or "Scheme Application"
            organization = scheme_name or scheme_name_hindi or "Government Scheme"
        elif app_type == "service":
            job_title = sub_service_name or service_name or "Service Application"
            organization = sub_service_name or service_name or "Professional Service"

        added_by = application.get("added_by")
        job_poster = (
            await db.auth.find_one({"email": added_by}) if added_by else None
        )
        job_poster_id = str(job_poster["_id"]) if job_poster else None

        applicant_user = await db.auth.find_one({"email": applicant_email})
        if not applicant_user:
            return {"success": False, "error": "Applicant not found"}

        applicant_id = str(applicant_user["_id"])

        status_display = {
            "shortlisted": "SHORTLISTED",
            "interview": "INTERVIEW SCHEDULED",
            "offered": "OFFER RECEIVED",
            "rejected": "NOT SELECTED",
            "pending": "PENDING REVIEW",
            "submitted": "SUBMITTED",
            "pending_verification": "AWAITING VERIFICATION",
            "verification_successful": "VERIFICATION APPROVED",
            "verification_rejected": "VERIFICATION FAILED",
            "approved": "APPROVED",
            "completed": "COMPLETED",
        }.get(new_status.lower(), new_status.upper())

        # ------------------------------------------------------------
        # Notify applicant
        # ------------------------------------------------------------
        if app_type == "scheme":
            applicant_title = f"🏛️ Scheme Status Update: {job_title}"
            nt_type = NotificationType.SCHEME_STATUS
        elif app_type == "service":
            applicant_title = f"⚙️ Service Status Update: {job_title}"
            nt_type = NotificationType.SERVICE_STATUS
        else:
            applicant_title = f"📋 Application Status Update: {job_title}"
            nt_type = NotificationType.APPLICATION_STATUS

        applicant_message = (
            f"Your application for '{job_title}' at {organization} "
            f"is now {status_display}"
        )
        # ✅ Use the resolved human-readable application number
        applicant_message += f"\n\n📋 Application Number: {resolved_application_number}"
        if notes:
            applicant_message += f"\n\nAdmin Notes: {notes}"

        applicant_metadata = {
            "application_type": app_type,
            "job_title": job_title,
            "organization": organization,
            "application_id": resolved_application_number,
            "application_number": resolved_application_number,
            "status": new_status,
            "notes": notes,
            "user_name": applicant_user.get("name"),
            "user_email": applicant_email,
        }

        if app_type == "scheme":
            applicant_metadata.update({
                "scheme_id": application.get("scheme_id"),
                "scheme_name": scheme_name,
                "scheme_name_hindi": scheme_name_hindi,
                "scheme_level": application.get("scheme_level"),
                "scheme_state": application.get("scheme_state"),
                "amount": application.get("payment_amount")
                    or application.get("amount"),
                "payment_status": application.get("payment_verification_status"),
                "transaction_id": application.get("transaction_id"),
            })
        elif app_type == "service":
            applicant_metadata.update({
                "service_id": application.get("service_id"),
                "service_name": service_name or sub_service_name,
                "sub_service_name": sub_service_name,
                "service_type": service_type,
                "sub_type_id": application.get("sub_type_id"),
                "amount": application.get("payment_amount")
                    or application.get("amount"),
                "payment_status": application.get("payment_verification_status"),
                "transaction_id": application.get("transaction_id"),
            })
        else:
            applicant_metadata.update({
                "job_id": application.get("job_id"),
                "applicant_name": application.get("applicant_name")
                    or application.get("user_name"),
                "applicant_email": applicant_email,
                "location": application.get("location"),
                "job_type": application.get("job_type"),
            })

        applicant_result = await self.send_notification(
            user_ids=applicant_id,
            notification_type=nt_type,
            title=applicant_title,
            message=applicant_message,
            related_id=resolved_application_number,
            metadata=applicant_metadata,
            send_email=True,
            send_sms=True,
            send_whatsapp_flag=True,
            send_websocket=True,
        )

        # ------------------------------------------------------------
        # Notify admin (job poster / scheme creator)
        # ------------------------------------------------------------
        if job_poster_id:
            admin_title = f"📋 Application Status Updated: {job_title}"
            admin_message = (
                f"Application by {applicant_email} for '{job_title}' "
                f"is now {status_display}"
            )
            admin_message += f"\n\n📋 Application Number: {resolved_application_number}"
            if notes:
                admin_message += f"\n\nNotes: {notes}"

            admin_metadata = {
                "application_type": app_type,
                "job_title": job_title,
                "organization": organization,
                "applicant_email": applicant_email,
                "application_id": resolved_application_number,
                "application_number": resolved_application_number,
                "status": new_status,
                "notes": notes,
            }

            await self.send_notification(
                user_ids=job_poster_id,
                notification_type=NotificationType.ADMIN_ALERT,
                title=admin_title,
                message=admin_message,
                related_id=resolved_application_number,
                metadata=admin_metadata,
                send_email=True,
                send_sms=False,
                send_whatsapp_flag=False,
                send_websocket=True,
            )

            logger.info(
                f"📧 Status update notification also sent to admin: {added_by}"
            )

        # ------------------------------------------------------------
        # Notify custom admins
        # ------------------------------------------------------------
        if job_poster_id and added_by:
            customadmins = await db.auth.find(
                {"role": "customadmin", "is_active": True}
            ).to_list(100)

            for customadmin in customadmins:
                ca_email = customadmin.get("email")
                if ca_email != added_by:
                    ca_id = str(customadmin["_id"])
                    await self.send_notification(
                        user_ids=ca_id,
                        notification_type=NotificationType.CUSTOMADMIN_ALERT,
                        title=f"📋 Application Update: {job_title}",
                        message=(
                            f"Application by {applicant_email} for "
                            f"'{job_title}' is now {status_display}\n\n"
                            f"📋 Application Number: {resolved_application_number}"
                        ),
                        related_id=resolved_application_number,
                        metadata=admin_metadata,
                        send_email=True,
                        send_sms=False,
                        send_whatsapp_flag=False,
                        send_websocket=True,
                    )

        return {
            "success": True,
            "applicant_notified": applicant_result.get("total_users", 0) > 0,
            "admin_notified": job_poster_id is not None,
            "application_number": resolved_application_number,
            "message": "Status update notification sent to user and admin",
        }

    # ==================== USER NOTIFICATION METHODS ====================

    async def get_user_notifications(
        self,
        user_id: str,
        limit: int = 50,
        skip: int = 0,
        unread_only: bool = False,
    ) -> Dict:
        db = await self._get_db()

        query = {"user_id": user_id}
        if unread_only:
            query["read"] = False

        notifications = await db.notifications.find(query) \
            .sort("created_at", -1) \
            .skip(skip) \
            .limit(limit) \
            .to_list(limit)

        total = await db.notifications.count_documents(query)
        unread_count = await db.notifications.count_documents(
            {"user_id": user_id, "read": False}
        )

        for notif in notifications:
            notif["_id"] = str(notif["_id"])
            if notif.get("created_at"):
                notif["created_at"] = notif["created_at"].isoformat()

        return {
            "notifications": notifications,
            "total": total,
            "unread_count": unread_count,
            "skip": skip,
            "limit": limit,
        }

    async def mark_as_read(self, notification_id: str, user_id: str) -> Dict:
        db = await self._get_db()

        if not ObjectId.is_valid(notification_id):
            raise HTTPException(
                status_code=400, detail="Invalid notification ID"
            )

        result = await db.notifications.update_one(
            {"_id": ObjectId(notification_id), "user_id": user_id},
            {"$set": {"read": True, "read_at": datetime.utcnow()}},
        )

        if result.modified_count == 0:
            raise HTTPException(
                status_code=404, detail="Notification not found"
            )

        return {"message": "Notification marked as read"}

    async def mark_all_as_read(self, user_id: str) -> Dict:
        db = await self._get_db()

        result = await db.notifications.update_many(
            {"user_id": user_id, "read": False},
            {"$set": {"read": True, "read_at": datetime.utcnow()}},
        )

        return {
            "message": f"Marked {result.modified_count} notifications as read"
        }

    async def get_unread_count(self, user_id: str) -> int:
        db = await self._get_db()
        return await db.notifications.count_documents(
            {"user_id": user_id, "read": False}
        )

    # ==================== PAYMENT VERIFICATION ====================

    async def notify_payment_verification(
        self,
        payment_id: str,
        application_id: str,
        user_email: str,
        admin_email: str,
        amount: int,
        job_title: str,
        action: str,
        notes: Optional[str] = None,
        application_type: Optional[str] = None,
        application_number: Optional[str] = None,
        organization: Optional[str] = None,
    ) -> Dict[str, Any]:
        db = await self._get_db()

        if application_type is None:
            application_type = self._detect_app_type(
                NotificationType.APPLICATION_STATUS,
                {"job_title": job_title, "organization": organization},
            )
        app_type = application_type or "job"
        if app_type == "schemes":
            app_type = "scheme"

        # ✅ Resolve the TRUE application_number if only _id is given
        resolved_number = application_number
        if not resolved_number:
            resolved_number = await resolve_application_number_async(application_id)

        admin_user = await db.auth.find_one({"email": admin_email})
        admin_user_id = str(admin_user["_id"]) if admin_user else None

        user = await db.auth.find_one({"email": user_email})
        user_user_id = str(user["_id"]) if user else None

        results = {
            "user_notified": False,
            "admin_notified": False,
            "customadmin_notified": False,
        }

        final_org = organization or job_title

        if action == "approve":
            if user_user_id:
                await self.send_notification(
                    user_ids=[user_user_id],
                    notification_type=NotificationType.APPLICATION_STATUS,
                    title="✅ Payment Verified Successfully!",
                    message=(
                        f"Your payment of ₹{amount} for '{job_title}' has "
                        f"been verified successfully. Your application is now submitted.\n\n"
                        f"📋 Application Number: {resolved_number}"
                    ),
                    related_id=resolved_number,
                    metadata={
                        "application_type": app_type,
                        "status": "verification_successful",
                        "amount": amount,
                        "job_title": job_title,
                        "organization": final_org,
                        "application_id": resolved_number,
                        "application_number": resolved_number,
                        "payment_id": payment_id,
                        "admin_notes": notes,
                        "user_name": user.get("name") if user else "User",
                        "user_email": user_email,
                    },
                    send_email=True,
                    send_sms=True,
                    send_whatsapp_flag=True,
                    send_websocket=True,
                )
                results["user_notified"] = True

            if admin_user_id:
                await self.send_notification(
                    user_ids=[admin_user_id],
                    notification_type=NotificationType.APPLICATION_STATUS,
                    title="💰 Payment Approved",
                    message=(
                        f"Payment of ₹{amount} from {user_email} for "
                        f"'{job_title}' has been APPROVED. "
                        f"Application is now verified.\n\n"
                        f"📋 Application Number: {resolved_number}"
                    ),
                    related_id=resolved_number,
                    metadata={
                        "application_type": app_type,
                        "status": "payment_approved",
                        "amount": amount,
                        "job_title": job_title,
                        "organization": final_org,
                        "applicant_email": user_email,
                        "application_id": resolved_number,
                        "application_number": resolved_number,
                        "payment_id": payment_id,
                        "admin_notes": notes,
                    },
                    send_email=True,
                    send_sms=False,
                    send_whatsapp_flag=False,
                    send_websocket=True,
                )
                results["admin_notified"] = True

            customadmins = await db.auth.find(
                {"role": "customadmin", "is_active": True}
            ).to_list(100)
            for ca in customadmins:
                ca_id = str(ca["_id"])
                if ca_id != admin_user_id:
                    await self.send_notification(
                        user_ids=[ca_id],
                        notification_type=NotificationType.CUSTOMADMIN_ALERT,
                        title="💰 Payment Approved",
                        message=(
                            f"Payment of ₹{amount} from {user_email} for "
                            f"'{job_title}' has been APPROVED by {admin_email}\n\n"
                            f"📋 Application Number: {resolved_number}"
                        ),
                        related_id=resolved_number,
                        metadata={
                            "application_type": app_type,
                            "status": "payment_approved",
                            "amount": amount,
                            "job_title": job_title,
                            "organization": final_org,
                            "applicant_email": user_email,
                            "application_id": resolved_number,
                            "application_number": resolved_number,
                            "payment_id": payment_id,
                            "approved_by": admin_email,
                        },
                        send_email=True,
                        send_sms=False,
                        send_whatsapp_flag=False,
                        send_websocket=True,
                    )
                    results["customadmin_notified"] = True

            return results

        else:
            if user_user_id:
                await self.send_notification(
                    user_ids=[user_user_id],
                    notification_type=NotificationType.APPLICATION_STATUS,
                    title="❌ Payment Verification Failed",
                    message=(
                        f"Your payment of ₹{amount} for '{job_title}' has "
                        f"been REJECTED.\nReason: "
                        f"{notes if notes else 'Please contact support'}\n\n"
                        f"📋 Application Number: {resolved_number}"
                    ),
                    related_id=resolved_number,
                    metadata={
                        "application_type": app_type,
                        "status": "verification_rejected",
                        "amount": amount,
                        "job_title": job_title,
                        "organization": final_org,
                        "application_id": resolved_number,
                        "application_number": resolved_number,
                        "payment_id": payment_id,
                        "rejection_reason": notes,
                        "user_name": user.get("name") if user else "User",
                        "user_email": user_email,
                    },
                    send_email=True,
                    send_sms=True,
                    send_whatsapp_flag=True,
                    send_websocket=True,
                )
                results["user_notified"] = True

            if admin_user_id:
                await self.send_notification(
                    user_ids=[admin_user_id],
                    notification_type=NotificationType.APPLICATION_STATUS,
                    title="💰 Payment Rejected",
                    message=(
                        f"Payment of ₹{amount} from {user_email} for "
                        f"'{job_title}' has been REJECTED.\nReason: "
                        f"{notes if notes else 'No reason provided'}\n\n"
                        f"📋 Application Number: {resolved_number}"
                    ),
                    related_id=resolved_number,
                    metadata={
                        "application_type": app_type,
                        "status": "payment_rejected",
                        "amount": amount,
                        "job_title": job_title,
                        "organization": final_org,
                        "applicant_email": user_email,
                        "application_id": resolved_number,
                        "application_number": resolved_number,
                        "payment_id": payment_id,
                        "rejection_reason": notes,
                    },
                    send_email=True,
                    send_sms=False,
                    send_whatsapp_flag=False,
                    send_websocket=True,
                )
                results["admin_notified"] = True

            customadmins = await db.auth.find(
                {"role": "customadmin", "is_active": True}
            ).to_list(100)
            for ca in customadmins:
                ca_id = str(ca["_id"])
                if ca_id != admin_user_id:
                    await self.send_notification(
                        user_ids=[ca_id],
                        notification_type=NotificationType.CUSTOMADMIN_ALERT,
                        title="💰 Payment Rejected",
                        message=(
                            f"Payment of ₹{amount} from {user_email} for "
                            f"'{job_title}' has been REJECTED by {admin_email}.\n"
                            f"Reason: {notes if notes else 'No reason provided'}\n\n"
                            f"📋 Application Number: {resolved_number}"
                        ),
                        related_id=resolved_number,
                        metadata={
                            "application_type": app_type,
                            "status": "payment_rejected",
                            "amount": amount,
                            "job_title": job_title,
                            "organization": final_org,
                            "applicant_email": user_email,
                            "application_id": resolved_number,
                            "application_number": resolved_number,
                            "payment_id": payment_id,
                            "rejected_by": admin_email,
                            "rejection_reason": notes,
                        },
                        send_email=True,
                        send_sms=False,
                        send_whatsapp_flag=False,
                        send_websocket=True,
                    )
                    results["customadmin_notified"] = True

            return results

    # ==================== HIGH-LEVEL DISPATCH WRAPPERS ====================

    async def send_otp(
        self,
        email: Optional[str],
        mobile: Optional[str],
        otp: str,
        purpose: str = "verification",
        user_name: str = "User",
    ) -> Dict[str, bool]:
        return await dispatch_otp(
            email=email,
            mobile=mobile,
            otp=otp,
            purpose=purpose,
            user_name=user_name,
        )

    async def send_welcome(
        self,
        email: Optional[str],
        mobile: Optional[str],
        user_name: str,
    ) -> Dict[str, bool]:
        return await dispatch_welcome(
            email=email,
            mobile=mobile,
            user_name=user_name,
        )

    async def send_job_alert(
        self,
        email: Optional[str],
        mobile: Optional[str],
        user_name: str,
        job_title: str,
        organization: str,
        location: str,
        job_id: str,
    ) -> Dict[str, bool]:
        return await dispatch_job_alert(
            email=email,
            mobile=mobile,
            user_name=user_name,
            job_title=job_title,
            organization=organization,
            location=location,
            job_id=job_id,
        )

    async def send_payment_status(
        self,
        email: Optional[str],
        mobile: Optional[str],
        user_name: str,
        job_title: str,
        amount: int,
        action: str,
        notes: Optional[str] = None,
    ) -> Dict[str, bool]:
        return await dispatch_payment_status(
            email=email,
            mobile=mobile,
            user_name=user_name,
            job_title=job_title,
            amount=amount,
            action=action,
            notes=notes,
        )

    async def send_admin_alert(
        self,
        admin_email: str,
        title: str,
        message: str,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, bool]:
        return await dispatch_admin_alert(
            admin_email=admin_email,
            title=title,
            message=message,
            metadata=metadata,
        )


# Create global instance
central_notification = CentralNotificationService()

print("✅ Centralized Notification Service Loaded - BULK EMAIL for fast delivery")
print("   🎨 AI Email Templates: Job (Blue) | Service (Emerald) | Scheme (Gold)")
print("   📧 Email Provider: " + settings.EMAIL_PROVIDER)
print("   📱 SMS Provider: " + settings.SMS_PROVIDER)
print("   💬 WhatsApp Provider: " + settings.WHATSAPP_PROVIDER)
print("   🚀 Multi-channel: Email + SMS + WhatsApp + In-App + WebSocket")
print("   💰 Payment verification notification method included")
print("   ✅ FIXED (v3): 'Details unavailable' bug in email header")
print("   ✅✅✅ FIXED (v4): Application Number in emails shows Mongo _id")
print("      — _resolve_canonical_app_number_async() resolves the true")
print("        YYYYMMDDSSSS number via DB lookup when only _id is provided")
print("      — notify_status_update() passes the resolved number to")
print("        send_notification() in BOTH metadata['application_number']")
print("        and metadata['application_id']")
print("      — build_modern_ai_notification_email() shortens any accidental")
print("        24-char ObjectId to 'xxxxxxxx...xxxx' so users NEVER see")
print("        a raw DB id")