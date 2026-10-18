# app/core/services/whatsapp.py
# ============================================================
# 💬 UNIVERSAL WHATSAPP SERVICE
# ============================================================
# ✅ Auto-detects provider from .env
# ✅ Supports: Twilio | MSG91 | Meta | Disabled
# ✅ Correct status reporting (no false success)
# ✅ Clear "SKIPPED" reason when disabled
# ============================================================

import logging
import httpx
import asyncio
from typing import Optional

from app.core.config.settings import settings

logger = logging.getLogger(__name__)


class BaseWhatsAppProvider:
    name = "base"

    def is_configured(self) -> bool:
        return False

    async def send_message(self, *args, **kwargs) -> bool:
        raise NotImplementedError

    def send_message_sync(self, *args, **kwargs) -> bool:
        raise NotImplementedError


# ============================================================
# 💬 TWILIO WHATSAPP
# ============================================================
class TwilioWhatsAppProvider(BaseWhatsAppProvider):
    name = "twilio"
    _error_21654_logged = False

    def __init__(self):
        self.sid = settings.TWILIO_ACCOUNT_SID
        self.token = settings.TWILIO_AUTH_TOKEN
        self.from_number = settings.TWILIO_WHATSAPP_NUMBER or "whatsapp:+14155238886"

    def is_configured(self) -> bool:
        return bool(self.sid and self.token and self.from_number)

    def _format_mobile(self, mobile: str) -> str:
        mobile = str(mobile).strip().replace(" ", "").replace("-", "")
        if mobile.startswith("whatsapp:"):
            return mobile
        if mobile.startswith("+"):
            return f"whatsapp:{mobile}"
        if mobile.startswith("91") and len(mobile) == 12:
            return f"whatsapp:+{mobile}"
        return f"whatsapp:+91{mobile}"

    async def send_message(self, to_mobile, message, template_id=None, variables=None, media_url=None):
        if not self.is_configured():
            return False

        try:
            from twilio.rest import Client
            client = Client(self.sid, self.token)
            to = self._format_mobile(to_mobile)

            def _send():
                kwargs = {"body": message, "from_": self.from_number, "to": to}
                if media_url:
                    kwargs["media_url"] = [media_url]
                return client.messages.create(**kwargs)

            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(None, _send)
            logger.info(f"✅ [Twilio WhatsApp] Sent! SID: {result.sid}")
            return True
        except Exception as e:
            if not TwilioWhatsAppProvider._error_21654_logged:
                TwilioWhatsAppProvider._error_21654_logged = True
                logger.error(
                    "❌ [Twilio WhatsApp] Trial account needs ContentSid.\n"
                    "   ✅ SOLUTION: WHATSAPP_PROVIDER=disabled in .env"
                )
            return False

    def send_message_sync(self, to_mobile, message, template_id=None, variables=None, media_url=None):
        try:
            return asyncio.run(self.send_message(to_mobile, message, template_id, variables, media_url))
        except Exception:
            return False


# ============================================================
# 💬 MSG91 WHATSAPP
# ============================================================
class MSG91WhatsAppProvider(BaseWhatsAppProvider):
    name = "msg91"
    URL = "https://api.msg91.com/api/v5/whatsapp/whatsapp-outbound-message/bulk/"

    def __init__(self):
        self.api_key = settings.MSG91_WHATSAPP_API_KEY or settings.MSG91_AUTH_KEY
        self.integrated_number = settings.MSG91_WHATSAPP_INTEGRATED_NUMBER
        self.template_otp = settings.MSG91_WHATSAPP_TEMPLATE_OTP
        self.template_alert = settings.MSG91_WHATSAPP_TEMPLATE_ALERT

    def is_configured(self) -> bool:
        return bool(self.api_key and self.integrated_number)

    def _format_mobile(self, mobile: str) -> str:
        mobile = str(mobile).strip().replace(" ", "").replace("-", "")
        if mobile.startswith("+"):
            mobile = mobile[1:]
        if not mobile.startswith("91"):
            mobile = f"91{mobile}"
        return mobile

    async def send_message(self, to_mobile, message, template_id=None, variables=None, media_url=None):
        if not self.is_configured():
            return False

        mobile = self._format_mobile(to_mobile)
        tpl = template_id or (self.template_otp if variables and "otp" in variables else self.template_alert)
        
        if not tpl:
            logger.error("❌ [MSG91 WhatsApp] No template configured")
            return False

        payload = {
            "integrated_number": self.integrated_number,
            "content_type": "template",
            "payload": {
                "messaging_product": "whatsapp",
                "type": "template",
                "template": {
                    "name": tpl,
                    "language": {"code": "en", "policy": "deterministic"},
                    "to_and_components": [{
                        "to": [mobile],
                        "components": {
                            "body_1": {"type": "text", "value": str(variables.get("otp", "")) if variables else ""}
                        }
                    }],
                },
            },
        }

        headers = {"authkey": self.api_key, "Content-Type": "application/json"}
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                r = await client.post(self.URL, json=payload, headers=headers)
            if r.status_code in (200, 201):
                logger.info(f"✅ [MSG91 WhatsApp] Sent to {mobile}")
                return True
            logger.error(f"❌ [MSG91 WhatsApp] Failed: {r.status_code}")
            return False
        except Exception as e:
            logger.error(f"❌ [MSG91 WhatsApp] {type(e).__name__}: {e}")
            return False

    def send_message_sync(self, to_mobile, message, template_id=None, variables=None, media_url=None):
        try:
            return asyncio.run(self.send_message(to_mobile, message, template_id, variables, media_url))
        except Exception:
            return False


# ============================================================
# 💬 META WHATSAPP BUSINESS
# ============================================================
class MetaWhatsAppProvider(BaseWhatsAppProvider):
    name = "meta"

    def __init__(self):
        self.phone_number_id = settings.META_WA_PHONE_NUMBER_ID
        self.access_token = settings.META_WA_ACCESS_TOKEN
        self.template_otp = settings.META_WA_TEMPLATE_OTP
        self.template_alert = settings.META_WA_TEMPLATE_ALERT

    def is_configured(self) -> bool:
        return bool(self.phone_number_id and self.access_token)

    def _format_mobile(self, mobile: str) -> str:
        mobile = str(mobile).strip().replace(" ", "").replace("-", "")
        if mobile.startswith("+"):
            mobile = mobile[1:]
        if not mobile.startswith("91"):
            mobile = f"91{mobile}"
        return mobile

    async def send_message(self, to_mobile, message, template_id=None, variables=None, media_url=None):
        if not self.is_configured():
            return False

        to = self._format_mobile(to_mobile)
        url = f"https://graph.facebook.com/v20.0/{self.phone_number_id}/messages"
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
        }
        
        tpl = template_id or (self.template_otp if variables and "otp" in variables else self.template_alert)
        
        if tpl and variables:
            params = [{"type": "text", "text": str(v)} for k, v in sorted(variables.items())]
            payload = {
                "messaging_product": "whatsapp",
                "to": to,
                "type": "template",
                "template": {
                    "name": tpl,
                    "language": {"code": "en"},
                    "components": [{"type": "body", "parameters": params}],
                },
            }
        else:
            payload = {
                "messaging_product": "whatsapp",
                "to": to,
                "type": "text",
                "text": {"body": message},
            }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                r = await client.post(url, json=payload, headers=headers)
            if r.status_code in (200, 201):
                logger.info(f"✅ [Meta WhatsApp] Sent to {to}")
                return True
            logger.error(f"❌ [Meta WhatsApp] Failed: {r.status_code}")
            return False
        except Exception as e:
            logger.error(f"❌ [Meta WhatsApp] {type(e).__name__}: {e}")
            return False

    def send_message_sync(self, to_mobile, message, template_id=None, variables=None, media_url=None):
        try:
            return asyncio.run(self.send_message(to_mobile, message, template_id, variables, media_url))
        except Exception:
            return False


# ============================================================
# 🚫 DISABLED PROVIDER
# ============================================================
class DisabledWhatsAppProvider(BaseWhatsAppProvider):
    name = "disabled"

    def is_configured(self) -> bool:
        return False

    async def send_message(self, *args, **kwargs) -> bool:
        return False

    def send_message_sync(self, *args, **kwargs) -> bool:
        return False


# ============================================================
# 🎯 UNIVERSAL WHATSAPP SERVICE
# ============================================================
class UniversalWhatsAppService:
    def __init__(self):
        self.providers = {
            "twilio": TwilioWhatsAppProvider(),
            "msg91": MSG91WhatsAppProvider(),
            "meta": MetaWhatsAppProvider(),
            "disabled": DisabledWhatsAppProvider(),
        }
        self.primary_provider = settings.active_whatsapp_provider
        self.fallback_to_sms = settings.WHATSAPP_FALLBACK_TO_SMS
        self._log_startup()

    def _log_startup(self):
        logger.info("=" * 70)
        logger.info("💬 UNIVERSAL WHATSAPP SERVICE INITIALIZED")
        logger.info(f"   Primary: {self.primary_provider}")
        if self.primary_provider == "disabled":
            logger.info(f"   ⚠️ WhatsApp is DISABLED")
        logger.info(f"   Fallback to SMS: {self.fallback_to_sms}")
        logger.info(f"   Mode: {'DEVELOPMENT' if settings.MOBILE_OTP_BYPASS else 'PRODUCTION'}")
        logger.info("=" * 70)

    def _get_provider(self, name: str) -> BaseWhatsAppProvider:
        return self.providers.get(name.lower(), DisabledWhatsAppProvider())

    async def send(self, to_mobile, message, template_id=None, variables=None, media_url=None) -> bool:
        # DEV MODE
        if settings.MOBILE_OTP_BYPASS:
            logger.info(f"🔧 [DEV] WhatsApp bypassed for {to_mobile}")
            return True

        # DISABLED
        if self.primary_provider == "disabled":
            logger.info(f"⊘ WhatsApp skipped - provider is disabled")
            return False

        provider = self._get_provider(self.primary_provider)
        if not provider.is_configured():
            logger.error(f"❌ WhatsApp provider {self.primary_provider} not configured")
            return False

        try:
            result = await provider.send_message(to_mobile, message, template_id, variables, media_url)
            if result:
                return True
            # Only fallback if explicitly enabled
            if self.fallback_to_sms:
                return await self._fallback_to_sms(to_mobile, message, template_id, variables)
            return False
        except Exception as e:
            logger.error(f"❌ WhatsApp error: {e}")
            return False

    def send_sync(self, to_mobile, message, template_id=None, variables=None, media_url=None) -> bool:
        try:
            return asyncio.run(self.send(to_mobile, message, template_id, variables, media_url))
        except Exception:
            return False

    async def _fallback_to_sms(self, to_mobile, message, template_id, variables) -> bool:
        try:
            from app.core.services.sms import send_sms_async
            logger.warning("⚠️ WhatsApp failed, falling back to SMS")
            return await send_sms_async(
                to_mobile=to_mobile,
                message=message,
                template_id=settings.MSG91_TEMPLATE_ID_OTP if variables and "otp" in variables else settings.MSG91_TEMPLATE_ID_ALERT,
                variables=variables,
            )
        except Exception as e:
            logger.error(f"❌ SMS fallback failed: {e}")
            return False


# ============================================================
# 🌍 GLOBAL INSTANCE + PUBLIC HELPERS
# ============================================================
_whatsapp_service: Optional[UniversalWhatsAppService] = None


def get_whatsapp_service() -> UniversalWhatsAppService:
    global _whatsapp_service
    if _whatsapp_service is None:
        _whatsapp_service = UniversalWhatsAppService()
    return _whatsapp_service


async def send_whatsapp(to_mobile, message, template_id=None, variables=None, media_url=None) -> bool:
    return await get_whatsapp_service().send(to_mobile, message, template_id, variables, media_url)


def send_whatsapp_sync(to_mobile, message, template_id=None, variables=None, media_url=None) -> bool:
    return get_whatsapp_service().send_sync(to_mobile, message, template_id, variables, media_url)


print("=" * 70)
print("✅ Universal WhatsApp Service Loaded")
print(f"   Primary Provider: {settings.active_whatsapp_provider}")
print(f"   Fallback to SMS: {settings.WHATSAPP_FALLBACK_TO_SMS}")
print("=" * 70)