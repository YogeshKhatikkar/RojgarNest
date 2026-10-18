# app/core/services/sms.py
# ============================================================
# 📱 UNIVERSAL SMS SERVICE - Works with ANY Provider
# ============================================================
# ✅ Auto-detects provider from .env
# ✅ Supports: Twilio | MSG91 | Fast2SMS | Brevo
# ✅ Auto-fallback if primary provider fails
# ✅ Trial account support (Twilio)
# ✅ Zero code changes needed when switching providers
# ✅ FIXED: Prevents double SMS send (OTP mismatch)
# ✅ FIXED: Better error handling for Twilio trial
# ============================================================

import logging
import httpx
import asyncio
from typing import Optional, List, Dict, Any

from app.core.config.settings import settings

logger = logging.getLogger(__name__)


# ============================================================
# BASE PROVIDER INTERFACE
# ============================================================
class BaseSMSProvider:
    name = "base"

    def is_configured(self) -> bool:
        """Override in subclass"""
        return False

    async def send_sms(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        raise NotImplementedError

    def send_sms_sync(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        raise NotImplementedError


# ============================================================
# 📱 TWILIO SMS PROVIDER (Trial + Production)
# ============================================================
class TwilioSMSProvider(BaseSMSProvider):
    name = "twilio"
    
    # Class-level flags for one-time logging
    _error_572002_logged = False
    _error_21608_logged = False
    _error_20003_logged = False
    _trial_warning_logged = False

    def __init__(self):
        self.sid = settings.TWILIO_ACCOUNT_SID
        self.token = settings.TWILIO_AUTH_TOKEN
        self.from_number = settings.TWILIO_PHONE
        self.is_trial = settings.TWILIO_IS_TRIAL_ACCOUNT

    def is_configured(self) -> bool:
        return bool(self.sid and self.token and self.from_number)

    def _format_mobile(self, mobile: str) -> str:
        mobile = str(mobile).strip().replace(" ", "").replace("-", "")
        if mobile.startswith("whatsapp:"):
            mobile = mobile.replace("whatsapp:", "")
        if mobile.startswith("+"):
            return mobile
        if mobile.startswith("91") and len(mobile) == 12:
            return f"+{mobile}"
        if len(mobile) == 10:
            return f"+91{mobile}"
        return f"+{mobile}"

    def _get_body(self, message: str, variables: Optional[dict]) -> str:
        """
        For trial accounts, use a predefined template.
        For production, use custom message.
        
        ⚠️ IMPORTANT: Trial templates do NOT carry the actual OTP!
        This means verification will FAIL for trial accounts.
        Use MSG91 for real OTP delivery.
        """
        if not self.is_trial:
            return message
        
        # Log warning once
        if not TwilioSMSProvider._trial_warning_logged:
            TwilioSMSProvider._trial_warning_logged = True
            logger.warning("=" * 70)
            logger.warning("⚠️ TWILIO TRIAL MODE - OTP VERIFICATION WILL FAIL")
            logger.warning("   Trial templates don't send actual OTP digits.")
            logger.warning("   User will receive generic message, not your OTP.")
            logger.warning("   ")
            logger.warning("   ✅ FIX: Switch to MSG91 in .env:")
            logger.warning("      SMS_PROVIDER=msg91")
            logger.warning("      MSG91_AUTH_KEY=your_key")
            logger.warning("=" * 70)
        
        # Trial mode: use predefined template
        if variables and "otp" in variables:
            return "sms_2fa"
        return "sms_appointment_reminders"

    def _send_with_twilio(self, to: str, body: str):
        """Perform the actual Twilio API call."""
        from twilio.rest import Client
        client = Client(self.sid, self.token)
        return client.messages.create(
            body=body,
            from_=self.from_number,
            to=to,
        )

    def _handle_error(self, error: Exception, to: str) -> bool:
        """Handle Twilio errors gracefully - with one-time logging."""
        try:
            from twilio.base.exceptions import TwilioRestException
            if isinstance(error, TwilioRestException):
                code = getattr(error, "code", None)

                # Error 572002: Trial account cannot send to this number
                if code == 572002:
                    if not TwilioSMSProvider._error_572002_logged:
                        TwilioSMSProvider._error_572002_logged = True
                        logger.error(
                            "=" * 70 + "\n"
                            "❌ [Twilio] Error 572002 - Trial Account Restriction\n"
                            "   ─────────────────────────────────────────────\n"
                            "   Twilio trial accounts have strict limitations.\n"
                            "   \n"
                            "   ✅ SOLUTION: Switch to MSG91\n"
                            "   1. Sign up: https://msg91.com\n"
                            "   2. Get Auth Key\n"
                            "   3. Update .env:\n"
                            "      SMS_PROVIDER=msg91\n"
                            "      MSG91_AUTH_KEY=your_key\n"
                            "      MSG91_TEMPLATE_ID_OTP=your_template\n"
                            "=" * 70
                        )
                    return False

                # Error 572006: Invalid template name
                elif code == 572006:
                    if not TwilioSMSProvider._error_572002_logged:
                        TwilioSMSProvider._error_572002_logged = True
                        logger.error(
                            "❌ [Twilio] Error 572006 - Invalid Template\n"
                            "   Trial accounts can only use predefined templates.\n"
                            "   ✅ Switch to MSG91 for real OTP SMS"
                        )
                    return False

                # Error 21608: Unverified number
                elif code == 21608:
                    if not TwilioSMSProvider._error_21608_logged:
                        TwilioSMSProvider._error_21608_logged = True
                        logger.error(
                            f"❌ [Twilio] Number {to} not verified.\n"
                            f"   Verify at: https://console.twilio.com/us1/develop/phone-numbers/manage/verified"
                        )
                    return False

                # Error 20003: Auth failed
                elif code == 20003:
                    if not TwilioSMSProvider._error_20003_logged:
                        TwilioSMSProvider._error_20003_logged = True
                        logger.error(
                            "❌ [Twilio] Authentication failed.\n"
                            "   Check TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN"
                        )
                    return False

                # Other errors
                else:
                    logger.error(f"❌ [Twilio] Error {code}: {str(error)[:150]}")
                    return False
        except ImportError:
            pass

        logger.error(f"❌ [Twilio] {type(error).__name__}: {str(error)[:200]}")
        return False

    async def send_sms(self, to_mobile, message, template_id=None, variables=None):
        if not self.is_configured():
            logger.error("❌ [Twilio] Not configured")
            return False

        to = self._format_mobile(to_mobile)
        try:
            body = self._get_body(message, variables)
            
            logger.info(f"📱 [Twilio] Sending SMS to {to}")
            if self.is_trial:
                logger.info(f"   ⚠️ Trial mode: Using template '{body}'")
                logger.info(f"   ⚠️ Actual OTP '{variables.get('otp') if variables else 'N/A'}' will NOT appear in SMS")
            
            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(
                None, lambda: self._send_with_twilio(to, body)
            )
            
            logger.info(f"✅ [Twilio] SMS sent! SID: {result.sid}, Status: {result.status}")
            return True
        except Exception as e:
            return self._handle_error(e, to_mobile)

    def send_sms_sync(self, to_mobile, message, template_id=None, variables=None):
        if not self.is_configured():
            logger.error("❌ [Twilio] Not configured")
            return False

        to = self._format_mobile(to_mobile)
        try:
            body = self._get_body(message, variables)
            
            logger.info(f"📱 [Twilio] Sending SMS (sync) to {to}")
            if self.is_trial:
                logger.info(f"   ⚠️ Trial mode: Using template '{body}'")
            
            result = self._send_with_twilio(to, body)
            logger.info(f"✅ [Twilio] SMS sent! SID: {result.sid}")
            return True
        except Exception as e:
            return self._handle_error(e, to_mobile)


# ============================================================
# 📱 MSG91 SMS PROVIDER (RECOMMENDED FOR INDIA)
# ============================================================
class MSG91SMSProvider(BaseSMSProvider):
    name = "msg91"
    SEND_OTP_URL = "https://control.msg91.com/api/v5/otp"
    SEND_FLOW_URL = "https://control.msg91.com/api/v5/flow/"

    def __init__(self):
        self.auth_key = settings.MSG91_AUTH_KEY
        self.sender_id = settings.MSG91_SENDER_ID
        self.template_otp = settings.MSG91_TEMPLATE_ID_OTP
        self.template_verify = settings.MSG91_TEMPLATE_ID_VERIFY
        self.template_alert = settings.MSG91_TEMPLATE_ID_ALERT
        self.country = settings.MSG91_COUNTRY or "91"
        self.dlt_te_id = settings.MSG91_DLT_TE_ID

    def is_configured(self) -> bool:
        return bool(self.auth_key)

    def _format_mobile(self, mobile: str) -> str:
        mobile = str(mobile).strip().replace(" ", "").replace("-", "")
        if mobile.startswith("+"):
            mobile = mobile[1:]
        if mobile.startswith(self.country):
            return mobile
        return f"{self.country}{mobile}"

    def _build_payload(self, mobile, message, template_id, variables):
        if template_id and variables and "otp" in (variables or {}):
            return (
                self.SEND_OTP_URL,
                {
                    "template_id": template_id,
                    "mobile": mobile,
                    "otp": str(variables.get("otp")),
                    "otp_expiry": 10,
                },
            )
        tpl = template_id or self.template_alert
        if not tpl:
            return None, None
        payload = {
            "template_id": tpl,
            "sender": self.sender_id,
            "short_url": "0",
            "recipients": [{"mobiles": mobile, **(variables or {})}],
        }
        if self.dlt_te_id:
            payload["DLT_TE_ID"] = self.dlt_te_id
        return self.SEND_FLOW_URL, payload

    async def send_sms(self, to_mobile, message, template_id=None, variables=None):
        if not self.is_configured():
            logger.error("❌ [MSG91] Not configured - Set MSG91_AUTH_KEY in .env")
            return False

        mobile = self._format_mobile(to_mobile)
        headers = {"authkey": self.auth_key, "Content-Type": "application/json"}
        url, payload = self._build_payload(mobile, message, template_id, variables)
        
        if not url:
            logger.error("❌ [MSG91] No template ID configured")
            return False

        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                r = await client.post(url, json=payload, headers=headers)
            if r.status_code in (200, 201):
                logger.info(f"✅ [MSG91] SMS sent to {mobile}")
                return True
            logger.error(f"❌ [MSG91] Failed: {r.status_code} {r.text[:200]}")
            return False
        except Exception as e:
            logger.error(f"❌ [MSG91] {type(e).__name__}: {e}")
            return False

    def send_sms_sync(self, to_mobile, message, template_id=None, variables=None):
        if not self.is_configured():
            logger.error("❌ [MSG91] Not configured")
            return False

        mobile = self._format_mobile(to_mobile)
        headers = {"authkey": self.auth_key, "Content-Type": "application/json"}
        url, payload = self._build_payload(mobile, message, template_id, variables)
        
        if not url:
            logger.error("❌ [MSG91] No template ID configured")
            return False

        try:
            with httpx.Client(timeout=20.0) as client:
                r = client.post(url, json=payload, headers=headers)
            if r.status_code in (200, 201):
                logger.info(f"✅ [MSG91] SMS sent (sync) to {mobile}")
                return True
            logger.error(f"❌ [MSG91] Failed: {r.status_code} {r.text[:200]}")
            return False
        except Exception as e:
            logger.error(f"❌ [MSG91] Sync: {type(e).__name__}: {e}")
            return False


# ============================================================
# 📱 FAST2SMS PROVIDER
# ============================================================
class Fast2SMSProvider(BaseSMSProvider):
    name = "fast2sms"
    URL = "https://www.fast2sms.com/dev/bulkV2"

    def __init__(self):
        self.api_key = settings.FAST2SMS_API_KEY

    def is_configured(self) -> bool:
        return bool(self.api_key)

    def _build_payload(self, mobile, message, template_id, variables):
        if template_id and variables and "otp" in (variables or {}):
            return {
                "route": "otp",
                "variables_values": str(variables.get("otp")),
                "numbers": mobile,
            }
        return {
            "route": "q",
            "message": message,
            "language": "english",
            "flash": 0,
            "numbers": mobile,
        }

    async def send_sms(self, to_mobile, message, template_id=None, variables=None):
        if not self.is_configured():
            logger.error("❌ [Fast2SMS] Not configured")
            return False

        mobile = str(to_mobile).strip().replace(" ", "")[-10:]
        headers = {"authorization": self.api_key, "Content-Type": "application/json"}
        payload = self._build_payload(mobile, message, template_id, variables)

        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                r = await client.post(self.URL, json=payload, headers=headers)
            data = r.json()
            if r.status_code == 200 and data.get("return") is True:
                logger.info(f"✅ [Fast2SMS] SMS sent to {mobile}")
                return True
            logger.error(f"❌ [Fast2SMS] Failed: {r.status_code} {r.text[:200]}")
            return False
        except Exception as e:
            logger.error(f"❌ [Fast2SMS] {type(e).__name__}: {e}")
            return False

    def send_sms_sync(self, to_mobile, message, template_id=None, variables=None):
        if not self.is_configured():
            logger.error("❌ [Fast2SMS] Not configured")
            return False

        mobile = str(to_mobile).strip().replace(" ", "")[-10:]
        headers = {"authorization": self.api_key, "Content-Type": "application/json"}
        payload = self._build_payload(mobile, message, template_id, variables)

        try:
            with httpx.Client(timeout=20.0) as client:
                r = client.post(self.URL, json=payload, headers=headers)
            data = r.json()
            if r.status_code == 200 and data.get("return") is True:
                logger.info(f"✅ [Fast2SMS] SMS sent (sync) to {mobile}")
                return True
            logger.error(f"❌ [Fast2SMS] Failed: {r.status_code} {r.text[:200]}")
            return False
        except Exception as e:
            logger.error(f"❌ [Fast2SMS] Sync: {type(e).__name__}: {e}")
            return False


# ============================================================
# 📱 BREVO SMS PROVIDER
# ============================================================
class BrevoSMSProvider(BaseSMSProvider):
    name = "brevo"
    URL = "https://api.brevo.com/v3/transactionalSMS/sms"

    def __init__(self):
        self.api_key = settings.BREVO_SMS_API_KEY or settings.BREVO_API_KEY
        self.sender = settings.BREVO_SMS_SENDER

    def is_configured(self) -> bool:
        return bool(self.api_key)

    def _format_mobile(self, mobile):
        mobile = str(mobile).strip().replace(" ", "").replace("-", "")
        if mobile.startswith("+"):
            return mobile
        if mobile.startswith("91"):
            return f"+{mobile}"
        return f"+91{mobile}"

    async def send_sms(self, to_mobile, message, template_id=None, variables=None):
        if not self.is_configured():
            logger.error("❌ [Brevo SMS] Not configured")
            return False

        mobile = self._format_mobile(to_mobile)
        headers = {
            "accept": "application/json",
            "api-key": self.api_key,
            "content-type": "application/json",
        }
        payload = {
            "sender": self.sender,
            "recipient": mobile,
            "content": message,
            "type": "transactional",
        }

        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                r = await client.post(self.URL, json=payload, headers=headers)
            if r.status_code in (200, 201, 202):
                logger.info(f"✅ [Brevo SMS] Sent to {mobile}")
                return True
            logger.error(f"❌ [Brevo SMS] Failed: {r.status_code} {r.text[:200]}")
            return False
        except Exception as e:
            logger.error(f"❌ [Brevo SMS] {type(e).__name__}: {e}")
            return False

    def send_sms_sync(self, to_mobile, message, template_id=None, variables=None):
        if not self.is_configured():
            logger.error("❌ [Brevo SMS] Not configured")
            return False

        mobile = self._format_mobile(to_mobile)
        headers = {
            "accept": "application/json",
            "api-key": self.api_key,
            "content-type": "application/json",
        }
        payload = {
            "sender": self.sender,
            "recipient": mobile,
            "content": message,
            "type": "transactional",
        }

        try:
            with httpx.Client(timeout=20.0) as client:
                r = client.post(self.URL, json=payload, headers=headers)
            if r.status_code in (200, 201, 202):
                logger.info(f"✅ [Brevo SMS] Sent (sync) to {mobile}")
                return True
            logger.error(f"❌ [Brevo SMS] Failed: {r.status_code} {r.text[:200]}")
            return False
        except Exception as e:
            logger.error(f"❌ [Brevo SMS] Sync: {type(e).__name__}: {e}")
            return False


# ============================================================
# 🎯 UNIVERSAL SMS SERVICE (Auto-detect + Fallback)
# ============================================================
class UniversalSMSService:
    """
    Universal SMS Service with:
    - Auto provider detection from .env
    - Auto fallback if primary provider fails (OPTIONAL)
    - Trial account support (Twilio)
    - Zero code changes to switch providers
    """

    def __init__(self):
        self.providers = {
            "twilio": TwilioSMSProvider(),
            "msg91": MSG91SMSProvider(),
            "fast2sms": Fast2SMSProvider(),
            "brevo": BrevoSMSProvider(),
        }
        self.primary_provider = settings.active_sms_provider
        self.fallback_order = settings.sms_fallback_providers
        self.fallback_enabled = settings.SMS_FALLBACK_ENABLED
        
        self._log_startup()

    def _log_startup(self):
        """Log configuration once at startup."""
        logger.info("=" * 70)
        logger.info("📱 UNIVERSAL SMS SERVICE INITIALIZED")
        logger.info(f"   Primary: {self.primary_provider}")
        logger.info(f"   Fallback Enabled: {self.fallback_enabled}")
        if self.fallback_enabled:
            configured = [
                p for p in self.fallback_order
                if self.providers.get(p) and self.providers[p].is_configured()
            ]
            logger.info(f"   Fallback Order: {configured}")
        if settings.MOBILE_OTP_BYPASS:
            logger.info(f"   🔧 MODE: DEVELOPMENT (SMS bypassed)")
        else:
            logger.info(f"   🔴 MODE: PRODUCTION")
        logger.info("=" * 70)

    def _get_provider(self, name: str) -> Optional[BaseSMSProvider]:
        """Get provider instance by name."""
        return self.providers.get(name.lower())

    async def send(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        """Send SMS with automatic provider selection and fallback."""
        
        # DEV MODE: Skip real SMS
        if settings.MOBILE_OTP_BYPASS:
            logger.info("=" * 70)
            logger.info("🔧 [DEV MODE] SMS NOT sent (MOBILE_OTP_BYPASS=true)")
            logger.info(f"   To: {to_mobile}")
            if variables and "otp" in variables:
                logger.info(f"   OTP: {variables['otp']}")
            logger.info(f"   ⚠️ Use DEV_OTP_CODE ({settings.DEV_OTP_CODE})")
            logger.info("=" * 70)
            return True
        
        # PROD MODE: Try primary provider only
        if self.primary_provider == "none":
            logger.error("❌ No SMS provider configured!")
            return False
        
        provider = self._get_provider(self.primary_provider)
        if not provider:
            logger.error(f"❌ Provider {self.primary_provider} not found")
            return False
        
        if not provider.is_configured():
            logger.error(f"❌ Provider {self.primary_provider} not configured")
            # Try fallback if enabled
            if self.fallback_enabled:
                return await self._try_fallback(to_mobile, message, template_id, variables)
            return False
        
        try:
            logger.info(f"📱 Sending SMS via {self.primary_provider}")
            result = await provider.send_sms(
                to_mobile, message, template_id=template_id, variables=variables
            )
            
            if result:
                logger.info(f"✅ SMS sent via {self.primary_provider}")
                return True
            
            # Primary failed - try fallback if enabled
            if self.fallback_enabled:
                logger.warning(f"⚠️ {self.primary_provider} failed, trying fallback...")
                return await self._try_fallback(to_mobile, message, template_id, variables)
            
            return False
        except Exception as e:
            logger.error(f"❌ {self.primary_provider} exception: {e}")
            if self.fallback_enabled:
                return await self._try_fallback(to_mobile, message, template_id, variables)
            return False

    async def _try_fallback(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        """Try fallback providers (excluding primary)."""
        for provider_name in self.fallback_order:
            if provider_name == self.primary_provider:
                continue
            
            provider = self._get_provider(provider_name)
            if not provider or not provider.is_configured():
                continue
            
            try:
                logger.info(f"📱 Fallback: Trying {provider_name}")
                result = await provider.send_sms(
                    to_mobile, message, template_id=template_id, variables=variables
                )
                if result:
                    logger.info(f"✅ SMS sent via fallback {provider_name}")
                    return True
                else:
                    logger.warning(f"⚠️ Fallback {provider_name} failed")
            except Exception as e:
                logger.error(f"❌ Fallback {provider_name} exception: {e}")
        
        logger.error("❌ All SMS providers failed")
        return False

    def send_sync(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        """Sync version with fallback."""
        
        # DEV MODE
        if settings.MOBILE_OTP_BYPASS:
            logger.info("🔧 [DEV MODE] SMS NOT sent (MOBILE_OTP_BYPASS=true)")
            logger.info(f"   To: {to_mobile}")
            if variables and "otp" in variables:
                logger.info(f"   OTP: {variables['otp']}")
            return True
        
        # PROD MODE
        if self.primary_provider == "none":
            logger.error("❌ No SMS provider configured!")
            return False
        
        provider = self._get_provider(self.primary_provider)
        if not provider or not provider.is_configured():
            logger.error(f"❌ Provider {self.primary_provider} not configured")
            if self.fallback_enabled:
                return self._try_fallback_sync(to_mobile, message, template_id, variables)
            return False
        
        try:
            logger.info(f"📱 Sending SMS via {self.primary_provider} (sync)")
            result = provider.send_sms_sync(
                to_mobile, message, template_id=template_id, variables=variables
            )
            
            if result:
                logger.info(f"✅ SMS sent via {self.primary_provider}")
                return True
            
            if self.fallback_enabled:
                logger.warning(f"⚠️ {self.primary_provider} failed, trying fallback...")
                return self._try_fallback_sync(to_mobile, message, template_id, variables)
            
            return False
        except Exception as e:
            logger.error(f"❌ {self.primary_provider} exception: {e}")
            if self.fallback_enabled:
                return self._try_fallback_sync(to_mobile, message, template_id, variables)
            return False

    def _try_fallback_sync(
        self,
        to_mobile: str,
        message: str,
        template_id: Optional[str] = None,
        variables: Optional[dict] = None,
    ) -> bool:
        """Sync fallback to other providers."""
        for provider_name in self.fallback_order:
            if provider_name == self.primary_provider:
                continue
            
            provider = self._get_provider(provider_name)
            if not provider or not provider.is_configured():
                continue
            
            try:
                logger.info(f"📱 Fallback: Trying {provider_name} (sync)")
                result = provider.send_sms_sync(
                    to_mobile, message, template_id=template_id, variables=variables
                )
                if result:
                    logger.info(f"✅ SMS sent via fallback {provider_name}")
                    return True
            except Exception as e:
                logger.error(f"❌ Fallback {provider_name} exception: {e}")
        
        logger.error("❌ All SMS providers failed")
        return False


# ============================================================
# 🌍 GLOBAL INSTANCE + BACKWARD COMPATIBLE API
# ============================================================
_sms_service: Optional[UniversalSMSService] = None


def get_sms_service() -> UniversalSMSService:
    global _sms_service
    if _sms_service is None:
        _sms_service = UniversalSMSService()
    return _sms_service


def send_mobile_otp(mobile: str, otp: str) -> bool:
    """Legacy helper for sending OTP SMS."""
    service = get_sms_service()
    message = f"Your RojgarNest OTP is {otp}. Valid for 10 minutes."
    return service.send_sync(
        to_mobile=mobile,
        message=message,
        template_id=settings.MSG91_TEMPLATE_ID_OTP,
        variables={"otp": otp, "message": message},
    )


async def send_sms_async(
    to_mobile: str,
    message: str,
    template_id: Optional[str] = None,
    variables: Optional[dict] = None,
) -> bool:
    """Async send SMS."""
    return await get_sms_service().send(
        to_mobile=to_mobile,
        message=message,
        template_id=template_id,
        variables=variables,
    )


# ============================================================
# 🎯 STARTUP DIAGNOSTIC
# ============================================================
print("=" * 70)
print("✅ Universal SMS Service Loaded")
print(f"   Primary Provider: {settings.active_sms_provider}")
print(f"   Fallback Enabled: {settings.SMS_FALLBACK_ENABLED}")
print(f"   Mode: {'DEVELOPMENT' if settings.MOBILE_OTP_BYPASS else 'PRODUCTION'}")

# Warn if Twilio trial is being used
if settings.SMS_PROVIDER.lower() == "twilio" and settings.TWILIO_IS_TRIAL_ACCOUNT:
    print("=" * 70)
    print("⚠️  WARNING: TWILIO TRIAL ACCOUNT DETECTED")
    print("   Trial accounts CANNOT send actual OTP digits.")
    print("   Mobile OTP verification WILL FAIL.")
    print("   ")
    print("   ✅ RECOMMENDED: Switch to MSG91")
    print("      1. Sign up at https://msg91.com")
    print("      2. Get Auth Key from dashboard")
    print("      3. Update .env:")
    print("         SMS_PROVIDER=msg91")
    print("         MSG91_AUTH_KEY=your_key")
    print("         MSG91_TEMPLATE_ID_OTP=your_template")
print("=" * 70)