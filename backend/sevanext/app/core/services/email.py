# app/core/services/email.py
# ============================================================
# 📧 UNIFIED EMAIL SERVICE WITH ADVANCED MODERN AI FORMATTING
# Supports: SMTP (Gmail) | Brevo | SendGrid | Mailgun
# Dynamically structures templates for Jobs, Services, and Schemes
#
# ✅ FIXED (2026-11):
#    - Added get_application_number() — canonical resolver.
#    - Added send_application_status_email() (async + sync).
#    - build_modern_ai_notification_email() now NEVER shows Mongo _id
#      in the "Reference ID" row if application_number exists.
#    - ✅ NEW (this build): NEVER render a 24-char ObjectId as reference_id.
#      If reference_id is a Mongo ObjectId, we look it up in the
#      applications collection via the global DB handle and use the
#      real application_number. Falls back to "N/A" if lookup fails.
# ============================================================

import re
import smtplib
import ssl
import logging
import httpx
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.utils import formataddr
from typing import Optional, List, Dict, Any

from app.core.config.settings import settings

logger = logging.getLogger(__name__)


# ============================================================
# ✅ APPLICATION NUMBER RESOLVER (canonical, single source of truth)
# ============================================================
_MONGO_OBJECT_ID_RE = re.compile(r"^[a-f0-9]{24}$", re.IGNORECASE)

_PLACEHOLDER_STRINGS = {
    "null", "undefined", "none", "n/a", "na", "-", "0", "false", "true",
    "not found", "notfound", "not_found", "deleted", "removed", "empty",
    "{}", "[]",
}


def _is_mongo_object_id(value: Any) -> bool:
    """Return True if value looks like a MongoDB ObjectId (24-char hex)."""
    if value is None:
        return False
    s = str(value).strip()
    if not s:
        return False
    return bool(_MONGO_OBJECT_ID_RE.match(s))


def _is_human_readable(value: Any) -> bool:
    """Return True if value is non-empty, non-placeholder, and NOT a Mongo _id."""
    if value is None:
        return False
    s = str(value).strip()
    if not s:
        return False
    if s.lower() in _PLACEHOLDER_STRINGS:
        return False
    if _is_mongo_object_id(s):
        return False
    return True


def get_application_number(app: Dict[str, Any], fallback: str = "N/A") -> str:
    """
    Resolve the human-readable application number from an application doc.

    Priority:
        1. app["application_number"]        (best — e.g. "20261000020")
        2. app["application_id"]            (only if NOT a Mongo ObjectId)
        3. app["_id"]                       (Mongo ObjectId → shortened to 8...4)
        4. `fallback`
    """
    if not isinstance(app, dict):
        return fallback

    # 1) application_number
    num = app.get("application_number")
    if _is_human_readable(num):
        return str(num).strip()

    # 2) application_id — must not be a Mongo _id
    app_id = app.get("application_id")
    if _is_human_readable(app_id):
        return str(app_id).strip()

    # 3) _id — Mongo ObjectId, only if nothing else exists
    mongo_id = app.get("_id")
    if mongo_id is not None:
        s = str(mongo_id).strip()
        if s:
            if _is_mongo_object_id(s) and len(s) > 12:
                return f"{s[:8]}...{s[-4:]}"
            return s

    # 4) fallback
    return fallback


# ============================================================
# ✅ NEW: Resolve application_number from Mongo _id via DB lookup
# ============================================================
async def resolve_application_number_async(
    raw_id: Optional[str],
    fallback: str = "N/A",
) -> str:
    """
    Given a raw ID (which may be a Mongo ObjectId, an application_id,
    or an application_number), return the canonical application_number.

    If the value is NOT an ObjectId, it's returned as-is (assuming it
    already IS the application_number).
    """
    if not raw_id:
        return fallback

    s = str(raw_id).strip()
    if not s:
        return fallback

    # If it's not a Mongo ObjectId, assume it's already the application_number
    if not _is_mongo_object_id(s):
        return s

    # Try to look it up
    try:
        from bson import ObjectId
        from app.db.connection import get_db

        db = get_db()
        if db is None:
            return f"{s[:8]}...{s[-4:]}"

        app = await db.applications.find_one(
            {"_id": ObjectId(s)},
            {"application_number": 1, "application_id": 1},
        )
        if app:
            num = app.get("application_number") or app.get("application_id")
            if _is_human_readable(num):
                return str(num).strip()

        # Fallback: shorten
        return f"{s[:8]}...{s[-4:]}"
    except Exception as e:
        logger.warning(f"resolve_application_number_async failed for {s}: {e}")
        return f"{s[:8]}...{s[-4:]}" if len(s) > 12 else s


# ============================================================
# BASE PROVIDER INTERFACE
# ============================================================
class BaseEmailProvider:
    name: str = "base"

    async def send(
        self,
        to_email: str,
        subject: str,
        html_body: str,
        text_body: Optional[str] = None,
        from_email: Optional[str] = None,
        from_name: Optional[str] = None,
    ) -> bool:
        raise NotImplementedError

    def send_sync(
        self,
        to_email: str,
        subject: str,
        html_body: str,
        text_body: Optional[str] = None,
        from_email: Optional[str] = None,
        from_name: Optional[str] = None,
    ) -> bool:
        raise NotImplementedError


# ============================================================
# 1️⃣ SMTP PROVIDER (Gmail / Any SMTP)
# ============================================================
class SMTPEmailProvider(BaseEmailProvider):
    name = "smtp"

    def __init__(self, use_brevo_smtp: bool = False):
        if use_brevo_smtp:
            self.host = settings.BREVO_SMTP_HOST
            self.port = settings.BREVO_SMTP_PORT
            self.user = settings.BREVO_SMTP_USER
            self.password = settings.BREVO_SMTP_PASSWORD
            self.from_email = settings.BREVO_SENDER_EMAIL or settings.SMTP_FROM
            self.from_name = settings.BREVO_SENDER_NAME
        else:
            self.host = settings.SMTP_HOST
            self.port = settings.SMTP_PORT
            self.user = settings.SMTP_USER
            self.password = settings.SMTP_PASSWORD
            self.from_email = settings.SMTP_FROM
            self.from_name = settings.SMTP_FROM_NAME

    def _build_message(
        self,
        to_email: str,
        subject: str,
        html_body: str,
        text_body: Optional[str] = None,
        from_email: Optional[str] = None,
        from_name: Optional[str] = None,
    ) -> MIMEMultipart:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = formataddr(
            (from_name or self.from_name, from_email or self.from_email)
        )
        msg["To"] = to_email

        if text_body:
            msg.attach(MIMEText(text_body, "plain"))
        msg.attach(MIMEText(html_body, "html"))
        return msg

    def send_sync(
        self,
        to_email: str,
        subject: str,
        html_body: str,
        text_body: Optional[str] = None,
        from_email: Optional[str] = None,
        from_name: Optional[str] = None,
    ) -> bool:
        if not self.host or not self.user:
            logger.warning("SMTP not configured, skipping email")
            return False

        try:
            msg = self._build_message(
                to_email, subject, html_body, text_body, from_email, from_name
            )
            context = ssl.create_default_context()
            with smtplib.SMTP(self.host, self.port, timeout=30) as server:
                server.starttls(context=context)
                server.login(self.user, self.password)
                server.sendmail(
                    from_email or self.from_email,
                    [to_email],
                    msg.as_string(),
                )
            logger.info(f"✅ [SMTP] Email sent to {to_email}")
            return True
        except smtplib.SMTPAuthenticationError as e:
            logger.error(f"❌ [SMTP] Auth failed: {e}")
            return False
        except Exception as e:
            logger.error(f"❌ [SMTP] Send failed: {e}")
            return False

    async def send(
        self,
        to_email: str,
        subject: str,
        html_body: str,
        text_body: Optional[str] = None,
        from_email: Optional[str] = None,
        from_name: Optional[str] = None,
    ) -> bool:
        import asyncio
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(
            None,
            lambda: self.send_sync(
                to_email, subject, html_body, text_body, from_email, from_name
            ),
        )


# ============================================================
# 2️⃣ BREVO PROVIDER (Transactional Email API v3)
# ============================================================
class BrevoEmailProvider(BaseEmailProvider):
    name = "brevo"
    API_URL = "https://api.brevo.com/v3/smtp/email"

    def __init__(self):
        self.api_key = settings.BREVO_API_KEY
        self.from_email = settings.BREVO_SENDER_EMAIL or settings.SMTP_FROM
        self.from_name = settings.BREVO_SENDER_NAME

    async def send(
        self,
        to_email: str,
        subject: str,
        html_body: str,
        text_body: Optional[str] = None,
        from_email: Optional[str] = None,
        from_name: Optional[str] = None,
    ) -> bool:
        if not self.api_key:
            logger.warning("❌ [Brevo] API key not configured")
            return False

        payload = {
            "sender": {
                "email": from_email or self.from_email,
                "name": from_name or self.from_name,
            },
            "to": [{"email": to_email}],
            "subject": subject,
            "htmlContent": html_body,
        }
        if text_body:
            payload["textContent"] = text_body

        headers = {
            "accept": "application/json",
            "api-key": self.api_key,
            "content-type": "application/json",
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                resp = await client.post(
                    self.API_URL, json=payload, headers=headers
                )
                if resp.status_code in (200, 201, 202):
                    logger.info(f"✅ [Brevo] Email sent to {to_email}")
                    return True
                logger.error(
                    f"❌ [Brevo] Failed: {resp.status_code} - {resp.text[:300]}"
                )
                return False
        except Exception as e:
            logger.error(f"❌ [Brevo] Exception: {e}")
            return False

    def send_sync(
        self,
        to_email: str,
        subject: str,
        html_body: str,
        text_body: Optional[str] = None,
        from_email: Optional[str] = None,
        from_name: Optional[str] = None,
    ) -> bool:
        if not self.api_key:
            logger.warning("❌ [Brevo] API key not configured")
            return False

        payload = {
            "sender": {
                "email": from_email or self.from_email,
                "name": from_name or self.from_name,
            },
            "to": [{"email": to_email}],
            "subject": subject,
            "htmlContent": html_body,
        }
        if text_body:
            payload["textContent"] = text_body

        headers = {
            "accept": "application/json",
            "api-key": self.api_key,
            "content-type": "application/json",
        }

        try:
            with httpx.Client(timeout=30.0) as client:
                resp = client.post(self.API_URL, json=payload, headers=headers)
                if resp.status_code in (200, 201, 202):
                    logger.info(f"✅ [Brevo] Email sent to {to_email}")
                    return True
                logger.error(
                    f"❌ [Brevo] Failed: {resp.status_code} - {resp.text[:300]}"
                )
                return False
        except Exception as e:
            logger.error(f"❌ [Brevo] Exception: {e}")
            return False


# ============================================================
# 3️⃣ SENDGRID PROVIDER
# ============================================================
class SendGridEmailProvider(BaseEmailProvider):
    name = "sendgrid"
    API_URL = "https://api.sendgrid.com/v3/mail/send"

    def __init__(self):
        self.api_key = settings.SENDGRID_API_KEY
        self.from_email = settings.SENDGRID_FROM_EMAIL or settings.SMTP_FROM
        self.from_name = settings.SENDGRID_FROM_NAME

    async def send(
        self,
        to_email: str,
        subject: str,
        html_body: str,
        text_body: Optional[str] = None,
        from_email: Optional[str] = None,
        from_name: Optional[str] = None,
    ) -> bool:
        if not self.api_key:
            logger.warning("❌ [SendGrid] API key not configured")
            return False

        payload = {
            "personalizations": [{"to": [{"email": to_email}]}],
            "from": {
                "email": from_email or self.from_email,
                "name": from_name or self.from_name,
            },
            "subject": subject,
            "content": [{"type": "text/html", "value": html_body}],
        }
        if text_body:
            payload["content"].insert(
                0, {"type": "text/plain", "value": text_body}
            )

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                resp = await client.post(
                    self.API_URL, json=payload, headers=headers
                )
                if resp.status_code in (200, 201, 202):
                    logger.info(f"✅ [SendGrid] Email sent to {to_email}")
                    return True
                logger.error(
                    f"❌ [SendGrid] Failed: {resp.status_code} - {resp.text[:300]}"
                )
                return False
        except Exception as e:
            logger.error(f"❌ [SendGrid] Exception: {e}")
            return False

    def send_sync(self, *args, **kwargs) -> bool:
        return False


# ============================================================
# 4️⃣ MAILGUN PROVIDER
# ============================================================
class MailgunEmailProvider(BaseEmailProvider):
    name = "mailgun"

    def __init__(self):
        self.api_key = settings.MAILGUN_API_KEY
        self.domain = settings.MAILGUN_DOMAIN
        self.from_email = settings.MAILGUN_FROM_EMAIL or settings.SMTP_FROM
        self.from_name = settings.MAILGUN_FROM_NAME

    async def send(
        self,
        to_email: str,
        subject: str,
        html_body: str,
        text_body: Optional[str] = None,
        from_email: Optional[str] = None,
        from_name: Optional[str] = None,
    ) -> bool:
        if not self.api_key or not self.domain:
            logger.warning("❌ [Mailgun] Not configured")
            return False

        url = f"https://api.mailgun.net/v3/{self.domain}/messages"
        data = {
            "from": f"{from_name or self.from_name} <{from_email or self.from_email}>",
            "to": to_email,
            "subject": subject,
            "html": html_body,
        }
        if text_body:
            data["text"] = text_body

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                resp = await client.post(
                    url, auth=("api", self.api_key), data=data
                )
                if resp.status_code in (200, 201, 202):
                    logger.info(f"✅ [Mailgun] Email sent to {to_email}")
                    return True
                logger.error(
                    f"❌ [Mailgun] Failed: {resp.status_code} - {resp.text[:300]}"
                )
                return False
        except Exception as e:
            logger.error(f"❌ [Mailgun] Exception: {e}")
            return False

    def send_sync(self, *args, **kwargs) -> bool:
        return False


# ============================================================
# 🎯 UNIFIED EMAIL SERVICE
# ============================================================
class UnifiedEmailService:
    def __init__(self):
        self.provider_name = (settings.EMAIL_PROVIDER or "smtp").lower()
        self.provider: BaseEmailProvider = self._get_provider(self.provider_name)
        self.fallback: Optional[BaseEmailProvider] = None
        if self.provider_name != "smtp":
            self.fallback = SMTPEmailProvider()
        logger.info(f"📧 Email service initialized: primary={self.provider_name}")

    def _get_provider(self, name: str) -> BaseEmailProvider:
        if name == "brevo":
            return BrevoEmailProvider()
        elif name == "sendgrid":
            return SendGridEmailProvider()
        elif name == "mailgun":
            return MailgunEmailProvider()
        else:
            return SMTPEmailProvider()

    async def send_email(
        self,
        to_email: str,
        subject: str,
        html_body: str,
        text_body: Optional[str] = None,
        from_email: Optional[str] = None,
        from_name: Optional[str] = None,
    ) -> bool:
        logger.info(f"📧 [REAL SEND] Sending email to {to_email}")
        ok = await self.provider.send(
            to_email, subject, html_body, text_body, from_email, from_name
        )
        if not ok and self.fallback:
            ok = await self.fallback.send(
                to_email, subject, html_body, text_body, from_email, from_name
            )
        return ok

    def send_email_sync(
        self,
        to_email: str,
        subject: str,
        html_body: str,
        text_body: Optional[str] = None,
        from_email: Optional[str] = None,
        from_name: Optional[str] = None,
    ) -> bool:
        logger.info(f"📧 [REAL SEND] Sending email (sync) to {to_email}")
        ok = self.provider.send_sync(
            to_email, subject, html_body, text_body, from_email, from_name
        )
        if not ok and self.fallback:
            ok = self.fallback.send_sync(
                to_email, subject, html_body, text_body, from_email, from_name
            )
        return ok


# ============================================================
# 🌍 GLOBAL INSTANCE + BACKWARD-COMPATIBLE FUNCTIONS
# ============================================================
_email_service: Optional[UnifiedEmailService] = None


def get_email_service() -> UnifiedEmailService:
    global _email_service
    if _email_service is None:
        _email_service = UnifiedEmailService()
    return _email_service


def send_email(to_email: str, otp: str) -> bool:
    html_body = _build_otp_email_html(otp, purpose="verification")
    subject = "Your SevaNext Verification OTP"
    return get_email_service().send_email_sync(
        to_email=to_email,
        subject=subject,
        html_body=html_body,
        text_body=f"Your OTP is {otp}. It expires in 10 minutes.",
    )


def send_html_email(to_email: str, subject: str, html_body: str) -> bool:
    return get_email_service().send_email_sync(
        to_email=to_email,
        subject=subject,
        html_body=html_body,
    )


async def send_email_async(
    to_email: str,
    subject: str,
    html_body: str,
    text_body: Optional[str] = None,
) -> bool:
    return await get_email_service().send_email(
        to_email=to_email,
        subject=subject,
        html_body=html_body,
        text_body=text_body,
    )


# ============================================================
# ✅ HIGH-LEVEL APPLICATION EMAIL HELPERS
# ============================================================

async def send_application_status_email(
    app_doc: Dict[str, Any],
    user_email: str,
    user_name: str,
    app_type: str,
    title: str,
    organization: str,
    status: str,
    details: Optional[Dict[str, Any]] = None,
    action_url: Optional[str] = None,
) -> bool:
    """
    Send an application status email (async).

    ✅ Guarantees the email body shows `application_number`,
       never the raw Mongo `_id`.
    ✅ NEW: If app_doc has no application_number but has _id,
       resolves it from the DB before rendering.
    """
    if not user_email:
        logger.warning("send_application_status_email: empty user_email, skipping")
        return False

    reference_id = get_application_number(app_doc)

    # ✅ If we still have an ObjectId, resolve via DB
    if _is_mongo_object_id(reference_id) or reference_id == "N/A":
        resolved = await resolve_application_number_async(
            app_doc.get("_id") or app_doc.get("application_id")
        )
        if resolved and resolved != "N/A":
            reference_id = resolved

    merged_details: Dict[str, Any] = {}
    if details:
        merged_details.update(details)

    # Ensure "Application Number" row exists exactly once
    has_app_number_key = any(
        str(k).lower().replace("_", " ").strip() == "application number"
        for k in merged_details.keys()
    )
    if not has_app_number_key:
        merged_details["Application Number"] = reference_id

    html_body = build_modern_ai_notification_email(
        app_type=app_type,
        title=title,
        organization_or_dept=organization,
        user_name=user_name or "Applicant",
        status=status,
        reference_id=reference_id,
        details=merged_details,
        action_url=action_url,
    )

    subject = f"SevaNext | {status} | {title} | #{reference_id}"

    text_body = (
        f"Hello {user_name or 'Applicant'},\n\n"
        f"Your {app_type} application '{title}' has been updated.\n"
        f"Status: {status}\n"
        f"Application Number: {reference_id}\n"
        f"Organization: {organization}\n\n"
        f"Track your status on https://www.rojgarnest.com\n"
    )

    logger.info(
        f"📧 Sending application email → {user_email} | "
        f"type={app_type} | ref={reference_id} | status={status}"
    )

    return await get_email_service().send_email(
        to_email=user_email,
        subject=subject,
        html_body=html_body,
        text_body=text_body,
    )


def send_application_status_email_sync(
    app_doc: Dict[str, Any],
    user_email: str,
    user_name: str,
    app_type: str,
    title: str,
    organization: str,
    status: str,
    details: Optional[Dict[str, Any]] = None,
    action_url: Optional[str] = None,
) -> bool:
    """Sync variant of send_application_status_email()."""
    if not user_email:
        logger.warning(
            "send_application_status_email_sync: empty user_email, skipping"
        )
        return False

    reference_id = get_application_number(app_doc)

    merged_details: Dict[str, Any] = {}
    if details:
        merged_details.update(details)

    has_app_number_key = any(
        str(k).lower().replace("_", " ").strip() == "application number"
        for k in merged_details.keys()
    )
    if not has_app_number_key:
        merged_details["Application Number"] = reference_id

    html_body = build_modern_ai_notification_email(
        app_type=app_type,
        title=title,
        organization_or_dept=organization,
        user_name=user_name or "Applicant",
        status=status,
        reference_id=reference_id,
        details=merged_details,
        action_url=action_url,
    )

    subject = f"SevaNext | {status} | {title} | #{reference_id}"

    text_body = (
        f"Hello {user_name or 'Applicant'},\n\n"
        f"Your {app_type} application '{title}' has been updated.\n"
        f"Status: {status}\n"
        f"Application Number: {reference_id}\n"
        f"Organization: {organization}\n\n"
        f"Track your status on https://www.rojgarnest.com\n"
    )

    logger.info(
        f"📧 [sync] Sending application email → {user_email} | "
        f"type={app_type} | ref={reference_id} | status={status}"
    )

    return get_email_service().send_email_sync(
        to_email=user_email,
        subject=subject,
        html_body=html_body,
        text_body=text_body,
    )


# ============================================================
# 🎨 OTP TEMPLATE
# ============================================================
def _build_otp_email_html(otp: str, purpose: str = "verification") -> str:
    return f"""<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><style>
  body {{ font-family: 'Segoe UI', Arial, sans-serif; background:#f4f4f7; margin:0; padding:20px; }}
  .container {{ max-width:520px; margin:0 auto; background:#fff; border-radius:16px; overflow:hidden; box-shadow:0 6px 24px rgba(0,0,0,0.08); }}
  .header {{ background:linear-gradient(135deg,#6C63FF,#FF6588); padding:28px; text-align:center; color:#fff; }}
  .header h1 {{ margin:0; font-size:22px; letter-spacing:0.5px; }}
  .content {{ padding:30px; text-align:center; }}
  .otp-box {{ display:inline-block; background:#f0f0ff; color:#6C63FF; font-size:34px; font-weight:700; letter-spacing:10px; padding:16px 28px; border-radius:12px; margin:20px 0; border:2px dashed #6C63FF; }}
  .footer {{ text-align:center; padding:18px; background:#f8f9fc; color:#8a8a9a; font-size:12px; }}
  p {{ color:#4a4a5a; line-height:1.5; }}
</style></head>
<body>
  <div class="container">
    <div class="header"><h1>🔐 SevaNext</h1></div>
    <div class="content">
      <p>Your one-time password (OTP) for <strong>{purpose}</strong> is:</p>
      <div class="otp-box">{otp}</div>
      <p>This code is valid for <strong>10 minutes</strong>.<br>Do not share it with anyone.</p>
    </div>
    <div class="footer">© SevaNext — AI-Powered Career Platform</div>
  </div>
</body></html>"""


# ============================================================
# 🎨 MODERN AI-BASED TEMPLATE ENGINE (JOB, SERVICE, SCHEME)
# ============================================================
def build_modern_ai_notification_email(
    app_type: str,  # 'job', 'service', or 'scheme'
    title: str,
    organization_or_dept: str,
    user_name: str,
    status: str,
    reference_id: str,
    details: Dict[str, Any],
    action_url: Optional[str] = None
) -> str:
    """
    Generates an advanced, ultra-modern AI formatted notification email
    specifically separated and custom-styled by application type.

    ✅ reference_id MUST be a human-readable application number.
       If a caller accidentally passes a Mongo ObjectId, we shorten it
       (or use "N/A") so the email NEVER shows a raw 24-char ObjectId.
    """
    app_type_clean = app_type.lower().strip()

    # ✅ SAFETY: never show a raw Mongo ObjectId as reference_id
    if reference_id is None:
        safe_reference = "N/A"
    else:
        safe_str = str(reference_id).strip()
        if not safe_str or safe_str.lower() in _PLACEHOLDER_STRINGS:
            safe_reference = "N/A"
        elif _is_mongo_object_id(safe_str) and len(safe_str) > 12:
            # Shorten accidental Mongo ObjectId pass-through
            safe_reference = f"{safe_str[:8]}...{safe_str[-4:]}"
        else:
            safe_reference = safe_str

    # ============================================================
    # THEME CONFIGURATION BASED ON APPLICATION TYPE
    # ============================================================
    if app_type_clean == "job":
        badge_text = "💼 Career / Job Opportunity"
        badge_icon = "💼"
        accent_color = "#3b82f6"
        accent_light = "#dbeafe"
        gradient_bg = "linear-gradient(135deg, #1e40af 0%, #3b82f6 100%)"
        target_label = "Company / Organization"
        footer_icon = "💼"
        type_display = "Job Application"
    elif app_type_clean == "service":
        badge_text = "⚙️ Government / Professional Service"
        badge_icon = "⚙️"
        accent_color = "#10b981"
        accent_light = "#d1fae5"
        gradient_bg = "linear-gradient(135deg, #047857 0%, #10b981 100%)"
        target_label = "Service Provider / Department"
        footer_icon = "⚙️"
        type_display = "Service Application"
    elif app_type_clean == "scheme":
        badge_text = "🏛️ Government Welfare Scheme"
        badge_icon = "🏛️"
        accent_color = "#f59e0b"
        accent_light = "#fef3c7"
        gradient_bg = "linear-gradient(135deg, #b45309 0%, #f59e0b 100%)"
        target_label = "Sponsoring Ministry / Department"
        footer_icon = "🏛️"
        type_display = "Scheme Application"
    else:
        badge_text = "🚀 Platform Notification"
        badge_icon = "🚀"
        accent_color = "#6c63ff"
        accent_light = "#e0e7ff"
        gradient_bg = "linear-gradient(135deg, #6c63ff 0%, #ff6588 100%)"
        target_label = "Organization"
        footer_icon = "🚀"
        type_display = "Application"

    # ============================================================
    # FORMAT DETAILS TABLE ROWS DYNAMICALLY
    # ============================================================
    details_html = ""
    if details:
        for k, v in details.items():
            if v is None or str(v).strip() == "":
                continue
            formatted_key = str(k).replace("_", " ").title()
            details_html += f"""
            <tr>
                <td style="padding: 12px 16px; color: #64748b; font-size: 14px; border-bottom: 1px solid #f1f5f9; width: 38%; font-weight: 600;">
                    {formatted_key}
                </td>
                <td style="padding: 12px 16px; color: #1e293b; font-size: 14px; border-bottom: 1px solid #f1f5f9; font-weight: 500; word-break: break-word;">
                    {v}
                </td>
            </tr>
            """

    # ============================================================
    # ACTION BUTTON (if URL provided)
    # ============================================================
    button_html = ""
    if action_url:
        button_html = f"""
        <div style="text-align: center; margin: 32px 0 10px 0;">
            <a href="{action_url}" target="_blank" style="
                background: {accent_color};
                color: #ffffff;
                padding: 14px 32px;
                font-size: 15px;
                font-weight: 600;
                text-decoration: none;
                border-radius: 10px;
                box-shadow: 0 4px 16px rgba(0,0,0,0.15);
                display: inline-block;
                letter-spacing: 0.3px;
            ">
                View Live Dashboard & Status →
            </a>
        </div>
        """

    # ============================================================
    # STATUS COLOR
    # ============================================================
    status_upper = str(status).upper()
    if any(x in status_upper for x in ["APPROVED", "SUCCESS", "VERIFIED", "COMPLETED", "OFFERED", "FINAL"]):
        status_bg = "#d1fae5"
        status_color = "#047857"
    elif any(x in status_upper for x in ["REJECTED", "FAILED", "CANCELLED"]):
        status_bg = "#fee2e2"
        status_color = "#b91c1c"
    elif any(x in status_upper for x in ["PENDING", "WAITING", "UNDER"]):
        status_bg = "#fef3c7"
        status_color = "#b45309"
    else:
        status_bg = "#e0e7ff"
        status_color = "#3730a3"

    # ============================================================
    # FINAL HTML TEMPLATE
    # ============================================================
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title}</title>
<style>
  body {{
    font-family: 'Segoe UI', 'Helvetica Neue', Arial, sans-serif;
    background-color: #f1f5f9;
    margin: 0;
    padding: 0;
    -webkit-font-smoothing: antialiased;
    line-height: 1.6;
  }}
  .wrapper {{
    width: 100%;
    table-layout: fixed;
    background: linear-gradient(180deg, #f1f5f9 0%, #e2e8f0 100%);
    padding: 40px 0;
  }}
  .main-card {{
    max-width: 620px;
    background-color: #ffffff;
    margin: 0 auto;
    border-radius: 20px;
    overflow: hidden;
    box-shadow: 0 20px 40px -10px rgba(0, 0, 0, 0.1), 0 10px 20px -5px rgba(0, 0, 0, 0.06);
    border: 1px solid #e2e8f0;
  }}
  .header {{
    background: {gradient_bg};
    padding: 40px 28px;
    text-align: center;
    color: #ffffff;
    position: relative;
    overflow: hidden;
  }}
  .header::before {{
    content: '';
    position: absolute;
    top: -50%;
    right: -50%;
    width: 200%;
    height: 200%;
    background: radial-gradient(circle, rgba(255,255,255,0.12) 0%, transparent 70%);
  }}
  .header-content {{
    position: relative;
    z-index: 1;
  }}
  .badge {{
    display: inline-block;
    background: rgba(255, 255, 255, 0.22);
    padding: 8px 18px;
    font-size: 12px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 1.2px;
    border-radius: 24px;
    margin-bottom: 16px;
    backdrop-filter: blur(10px);
    border: 1px solid rgba(255, 255, 255, 0.25);
  }}
  .header h1 {{
    margin: 0;
    font-size: 24px;
    font-weight: 700;
    line-height: 1.3;
    text-shadow: 0 2px 4px rgba(0,0,0,0.15);
  }}
  .header .subtitle {{
    margin-top: 10px;
    font-size: 14px;
    opacity: 0.9;
    font-weight: 400;
  }}
  .content {{
    padding: 36px 32px;
    color: #334155;
  }}
  .greeting {{
    font-size: 18px;
    font-weight: 700;
    color: #0f172a;
    margin-bottom: 8px;
  }}
  .greeting span {{
    color: {accent_color};
  }}
  .text-p {{
    font-size: 15px;
    line-height: 1.7;
    color: #475569;
    margin-bottom: 24px;
  }}
  .type-badge {{
    display: inline-block;
    background: {accent_light};
    color: {accent_color};
    padding: 4px 12px;
    border-radius: 8px;
    font-size: 12px;
    font-weight: 700;
    margin-bottom: 16px;
    letter-spacing: 0.5px;
  }}
  .info-table {{
    width: 100%;
    border-collapse: collapse;
    background: #f8fafc;
    border-radius: 12px;
    overflow: hidden;
    border: 1px solid #e2e8f0;
    margin-bottom: 28px;
  }}
  .info-table tr:last-child td {{
    border-bottom: none;
  }}
  .status-pill {{
    display: inline-block;
    background: {status_bg};
    color: {status_color};
    padding: 6px 14px;
    border-radius: 8px;
    font-weight: 700;
    font-size: 13px;
    letter-spacing: 0.3px;
  }}
  .ref-id {{
    font-family: 'Courier New', monospace;
    background: #ffffff;
    padding: 4px 8px;
    border-radius: 6px;
    font-weight: 700;
    color: {accent_color};
    border: 1px dashed {accent_color};
    font-size: 13px;
  }}
  .highlight-box {{
    background: {accent_light};
    border-left: 4px solid {accent_color};
    padding: 16px 20px;
    border-radius: 10px;
    margin: 24px 0;
  }}
  .highlight-box p {{
    margin: 0;
    color: #1e293b;
    font-size: 14px;
    line-height: 1.6;
  }}
  .footer {{
    background-color: #f8fafc;
    padding: 28px 24px;
    text-align: center;
    color: #94a3b8;
    font-size: 12px;
    border-top: 1px solid #e2e8f0;
  }}
  .footer .brand {{
    font-weight: 700;
    color: {accent_color};
    font-size: 14px;
    margin-bottom: 6px;
  }}
  .footer .links {{
    margin: 12px 0;
  }}
  .footer .links a {{
    color: #64748b;
    text-decoration: none;
    margin: 0 8px;
    font-size: 12px;
  }}
  .social-row {{
    margin-top: 16px;
    padding-top: 16px;
    border-top: 1px solid #e2e8f0;
  }}
  .social-row span {{
    display: inline-block;
    width: 32px;
    height: 32px;
    line-height: 32px;
    background: {accent_light};
    border-radius: 50%;
    margin: 0 4px;
    font-size: 16px;
  }}
</style>
</head>
<body>
  <center class="wrapper">
    <table class="main-card" width="100%" cellpadding="0" cellspacing="0" role="presentation">
      <tr>
        <td class="header">
          <div class="header-content">
            <div class="badge">{badge_icon} {badge_text}</div>
            <h1>{title}</h1>
            <div class="subtitle">{type_display} Notification</div>
          </div>
        </td>
      </tr>
      <tr>
        <td class="content">
          <div class="type-badge">{footer_icon} {type_display}</div>
          <div class="greeting">Hello, <span>{user_name}</span>! 👋</div>
          <p class="text-p">
            We have an important update regarding your {type_display.lower()}.
            Your request has been processed and is currently tracked under our advanced AI notification engine.
          </p>

          <table class="info-table" cellpadding="0" cellspacing="0" role="presentation">
            <tr>
              <td style="padding: 12px 16px; color: #64748b; font-size: 14px; border-bottom: 1px solid #f1f5f9; width: 38%; font-weight: 600;">
                Application Number
              </td>
              <td style="padding: 12px 16px; border-bottom: 1px solid #f1f5f9;">
                <span class="ref-id">{safe_reference}</span>
              </td>
            </tr>
            <tr>
              <td style="padding: 12px 16px; color: #64748b; font-size: 14px; border-bottom: 1px solid #f1f5f9; font-weight: 600;">
                {target_label}
              </td>
              <td style="padding: 12px 16px; color: #1e293b; font-size: 14px; border-bottom: 1px solid #f1f5f9; font-weight: 600;">
                {organization_or_dept}
              </td>
            </tr>
            <tr>
              <td style="padding: 12px 16px; color: #64748b; font-size: 14px; border-bottom: 1px solid #f1f5f9; font-weight: 600;">
                Current Status
              </td>
              <td style="padding: 12px 16px; border-bottom: 1px solid #f1f5f9;">
                <span class="status-pill">{status}</span>
              </td>
            </tr>
            {details_html}
          </table>

          {button_html}

          <div class="highlight-box">
            <p>💡 <strong>Tip:</strong> Keep your profile updated to receive better AI-powered matches and faster verification.</p>
          </div>

          <p style="font-size: 13px; color: #64748b; margin-top: 24px; text-align: center;">
            If you have any questions or require support, reply directly to this message
            or visit your SevaNext user portal.
          </p>
        </td>
      </tr>
      <tr>
        <td class="footer">
          <div class="brand">{footer_icon} SevaNext</div>
          <div>© 2026 SevaNext — Next-Gen AI Career, Service & Schemes Portal</div>
          <div class="links">
            <a href="https://www.rojgarnest.com">Home</a> |
            <a href="https://www.rojgarnest.com/jobs">Jobs</a> |
            <a href="https://www.rojgarnest.com/schemes">Schemes</a> |
            <a href="https://www.rojgarnest.com/support">Support</a>
          </div>
          <div class="social-row">
            <span>📘</span>
            <span>🐦</span>
            <span>💼</span>
            <span>📸</span>
          </div>
          <p style="margin-top: 16px; font-size: 11px; color: #cbd5e1;">
            This is an automated system notification. Please do not reply directly to this email address.
          </p>
        </td>
      </tr>
    </table>
  </center>
</body>
</html>"""


print("=" * 70)
print("✅ Modern Advanced AI Email Notification Service Loaded Successfully")
print("   - Formatted for: Jobs, Services, and Schemes")
print("   - Glassmorphism & Responsive CSS applied")
print("   - build_modern_ai_notification_email() ready for use")
print("   - send_application_status_email() / _sync() ready for routes")
print("   - ✅ NEW: resolve_application_number_async() — DB lookup for _id")
print("   - ✅ NEW: safe_reference never shows a raw 24-char ObjectId")
print("=" * 70)