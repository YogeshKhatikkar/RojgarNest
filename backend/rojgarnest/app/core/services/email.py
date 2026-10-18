# app/core/services/email.py
# ============================================================
# 📧 UNIFIED EMAIL SERVICE
# Supports: SMTP (Gmail) | Brevo | SendGrid | Mailgun
# Switch via EMAIL_PROVIDER in .env — NO CODE CHANGES NEEDED
# ============================================================
# ✅ EMAIL IS ALWAYS REAL - NEVER BYPASSED
# ✅ Even when MOBILE_OTP_BYPASS=true, email OTP is sent for real
# ✅ Only SMS/WhatsApp are bypassed in development mode
# ============================================================

import smtplib
import ssl
import logging
import httpx
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.utils import formataddr
from typing import Optional, List

from app.core.config.settings import settings

logger = logging.getLogger(__name__)


# ============================================================
# BASE PROVIDER INTERFACE
# ============================================================
class BaseEmailProvider:
    """Abstract email provider."""

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
    """
    Selects provider based on settings.EMAIL_PROVIDER.
    Falls back to SMTP if primary fails (configurable).

    ✅ CRITICAL: EMAIL IS ALWAYS SENT FOR REAL - NEVER BYPASSED
    ✅ Even when MOBILE_OTP_BYPASS=true, email OTP is sent for real
    ✅ Only SMS/WhatsApp are bypassed in development mode
    """

    def __init__(self):
        self.provider_name = (settings.EMAIL_PROVIDER or "smtp").lower()
        self.provider: BaseEmailProvider = self._get_provider(self.provider_name)
        self.fallback: Optional[BaseEmailProvider] = None
        if self.provider_name != "smtp":
            self.fallback = SMTPEmailProvider()
        logger.info(f"📧 Email service initialized: primary={self.provider_name}")
        logger.info(f"   ✅ EMAIL IS ALWAYS REAL - NEVER BYPASSED")

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
        # ============================================================
        # ✅ CRITICAL FIX: EMAIL IS ALWAYS SENT FOR REAL
        # ============================================================
        # We REMOVED the MOBILE_OTP_BYPASS check here!
        # Email OTP is always real - even in development mode.
        # Only SMS/WhatsApp are bypassed.
        # ============================================================

        logger.info(f"📧 [REAL SEND] Sending email to {to_email}")
        logger.info(f"   Subject: {subject}")
        logger.info(f"   Provider: {self.provider_name}")

        ok = await self.provider.send(
            to_email, subject, html_body, text_body, from_email, from_name
        )
        if not ok and self.fallback:
            logger.warning("⚠️ Primary email provider failed, trying SMTP fallback")
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
        # ============================================================
        # ✅ CRITICAL FIX: EMAIL IS ALWAYS SENT FOR REAL
        # ============================================================
        # We REMOVED the MOBILE_OTP_BYPASS check here!
        # Email OTP is always real - even in development mode.
        # Only SMS/WhatsApp are bypassed.
        # ============================================================

        logger.info(f"📧 [REAL SEND] Sending email (sync) to {to_email}")
        logger.info(f"   Subject: {subject}")
        logger.info(f"   Provider: {self.provider_name}")

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


# -------- Public sync API (used by existing code) --------
def send_email(to_email: str, otp: str) -> bool:
    """
    Legacy helper: sends OTP email.
    ✅ ALWAYS sends real email - never bypassed.
    """
    html_body = _build_otp_email_html(otp, purpose="verification")
    subject = "Your RojgarNest Verification OTP"
    return get_email_service().send_email_sync(
        to_email=to_email,
        subject=subject,
        html_body=html_body,
        text_body=f"Your OTP is {otp}. It expires in 10 minutes.",
    )


def send_html_email(to_email: str, subject: str, html_body: str) -> bool:
    """
    Legacy helper: sends HTML email.
    ✅ ALWAYS sends real email - never bypassed.
    """
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
    """
    Async helper for new code.
    ✅ ALWAYS sends real email - never bypassed.
    """
    return await get_email_service().send_email(
        to_email=to_email,
        subject=subject,
        html_body=html_body,
        text_body=text_body,
    )


# ============================================================
# 🎨 PRETTY OTP EMAIL TEMPLATE
# ============================================================
def _build_otp_email_html(otp: str, purpose: str = "verification") -> str:
    return f"""<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
  body {{ font-family: 'Segoe UI', Arial, sans-serif; background:#f4f4f7; margin:0; padding:20px; }}
  .container {{ max-width:520px; margin:0 auto; background:#fff; border-radius:16px; overflow:hidden; box-shadow:0 6px 24px rgba(0,0,0,0.08); }}
  .header {{ background:linear-gradient(135deg,#6C63FF,#FF6588); padding:28px; text-align:center; color:#fff; }}
  .header h1 {{ margin:0; font-size:22px; letter-spacing:0.5px; }}
  .content {{ padding:30px; text-align:center; }}
  .otp-box {{ display:inline-block; background:#f0f0ff; color:#6C63FF; font-size:34px; font-weight:700; letter-spacing:10px; padding:16px 28px; border-radius:12px; margin:20px 0; border:2px dashed #6C63FF; }}
  .footer {{ text-align:center; padding:18px; background:#f8f9fc; color:#8a8a9a; font-size:12px; }}
  p {{ color:#4a4a5a; line-height:1.5; }}
</style>
</head>
<body>
  <div class="container">
    <div class="header"><h1>🔐 RojgarNest</h1></div>
    <div class="content">
      <p>Your one-time password (OTP) for <strong>{purpose}</strong> is:</p>
      <div class="otp-box">{otp}</div>
      <p>This code is valid for <strong>10 minutes</strong>.<br>Do not share it with anyone.</p>
    </div>
    <div class="footer">© RojgarNest — AI-Powered Career Platform</div>
  </div>
</body>
</html>"""


print("=" * 70)
print("✅ Unified Email Service Loaded")
print(f"   Provider: {settings.EMAIL_PROVIDER}")
print(f"   ✅ EMAIL IS ALWAYS REAL - NEVER BYPASSED")
print(f"   ✅ Even when MOBILE_OTP_BYPASS=true, emails are sent for real")
print("=" * 70)