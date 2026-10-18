# app/modules/payment/phonepe_sdk_service.py
import uuid
from typing import Dict, Any, Optional
from datetime import datetime
import logging
from uuid import uuid4

from phonepe.sdk.pg.payments.v2.standard_checkout_client import StandardCheckoutClient
from phonepe.sdk.pg.payments.v2.models.request.standard_checkout_pay_request import StandardCheckoutPayRequest
from phonepe.sdk.pg.common.models.request.meta_info import MetaInfo
from phonepe.sdk.pg.env import Env
from phonepe.sdk.pg.payments.v2.models.request.prefill_user_login_details import PrefillUserLoginDetails
from phonepe.sdk.pg.common.models.request.payment_mode_constraints.upi_intent_payment_mode import UpiIntentPaymentModeConstraint
from phonepe.sdk.pg.common.models.request.payment_mode_constraints.net_banking_payment_mode import NetBankingPaymentModeConstraint
from phonepe.sdk.pg.common.models.request.payment_mode_constraints.card_payment_mode import CardPaymentModeConstraint
from phonepe.sdk.pg.payments.v2.models.request.payment_mode_config import PaymentModeConfig
from phonepe.sdk.pg.common.models.request.payment_mode_constraints.card_type import CardType
from phonepe.sdk.pg.common.models.request.pg_v2_instrument_type import PgV2InstrumentType

from app.core.config.settings import settings
from app.core.utils.logger import logger

logger = logging.getLogger(__name__)


class PhonePeSDKService:
    """PhonePe Payment Gateway Integration using Official SDK"""
    
    def __init__(self):
        self.client_id = settings.PHONEPE_CLIENT_ID
        self.client_secret = settings.PHONEPE_CLIENT_SECRET
        self.client_version = int(getattr(settings, 'PHONEPE_CLIENT_VERSION', 1))
        self.env = Env.SANDBOX if getattr(settings, 'PHONEPE_MODE', 'SANDBOX') == 'SANDBOX' else Env.PRODUCTION
        self.redirect_url = getattr(settings, 'PHONEPE_REDIRECT_URL', 'http://localhost:8000/api/v1/payment/phonepe-callback')
        self.should_publish_events = False
        
        self.client = None
        self._initialize_client()
    
    def _initialize_client(self):
        """Initialize PhonePe SDK Client"""
        try:
            self.client = StandardCheckoutClient.get_instance(
                client_id=self.client_id,
                client_secret=self.client_secret,
                client_version=self.client_version,
                env=self.env,
                should_publish_events=self.should_publish_events
            )
            logger.info("✅ PhonePe SDK Client initialized successfully")
        except Exception as e:
            logger.error(f"❌ PhonePe SDK Client initialization failed: {e}")
            self.client = None
    
    def create_payment_with_selected_modes(
        self,
        amount: int,
        user_email: str,
        user_phone: str,
        job_id: str,
        job_title: str,
        enable_upi: bool = True,
        enable_cards: bool = True,
        enable_netbanking: bool = True
    ) -> Dict[str, Any]:
        """
        Create PhonePe payment with selected payment modes only
        
        Args:
            amount: Amount in paise
            user_email: User's email
            user_phone: User's phone
            job_id: Job ID
            job_title: Job title
            enable_upi: Enable UPI payments
            enable_cards: Enable Card payments
            enable_netbanking: Enable NetBanking
        
        Returns:
            Dictionary with payment details
        """
        if not self.client:
            self._initialize_client()
            if not self.client:
                return {"success": False, "error": "PhonePe client not initialized"}
        
        try:
            # Generate unique order ID
            unique_order_id = f"RJ{job_id[:8]}{uuid4().hex[:12].upper()}"
            
            # Build meta info
            meta_info = MetaInfo(
                udf1=job_id,
                udf2=job_title[:50],
                udf3=user_email,
                udf4=f"amount_{amount}",
                udf5="RojgarNest"
            )
            
            # Prefill user details for faster checkout
            prefill_details = PrefillUserLoginDetails(
                phone_number=user_phone[:10] if user_phone else "9999999999"
            )
            
            # Build enabled payment modes
            enabled_modes = []
            
            if enable_upi:
                enabled_modes.append(UpiIntentPaymentModeConstraint(PgV2InstrumentType.UPI_INTENT))
            
            if enable_cards:
                enabled_modes.append(CardPaymentModeConstraint(
                    card_types=[CardType.DEBIT_CARD, CardType.CREDIT_CARD]
                ))
            
            if enable_netbanking:
                enabled_modes.append(NetBankingPaymentModeConstraint(PgV2InstrumentType.NET_BANKING))
            
            # Create payment mode configuration
            payment_mode_config = PaymentModeConfig(enabled_payment_modes=enabled_modes)
            
            # Build payment request with selected modes
            pay_request = StandardCheckoutPayRequest.build_request(
                merchant_order_id=unique_order_id,
                amount=amount,
                meta_info=meta_info,
                payment_mode_config=payment_mode_config,
                redirect_url=self.redirect_url,
                message=f"Job Application Fee - {job_title[:50]}",
                expire_after=900,
                disable_payment_retry=False,
                prefill_user_login_details=prefill_details
            )
            
            # Make payment request
            response = self.client.pay(pay_request)
            checkout_url = response.redirect_url
            
            logger.info(f"✅ PhonePe payment created with selected modes: {unique_order_id}")
            
            return {
                "success": True,
                "order_id": unique_order_id,
                "redirect_url": checkout_url,
                "amount": amount,
                "enabled_modes": {
                    "upi": enable_upi,
                    "cards": enable_cards,
                    "netbanking": enable_netbanking
                }
            }
            
        except Exception as e:
            logger.error(f"❌ PhonePe payment creation failed: {e}")
            return {"success": False, "error": str(e)}
    
    def get_payment_status(self, merchant_order_id: str) -> Dict[str, Any]:
        """
        Get payment status from PhonePe
        
        Args:
            merchant_order_id: Merchant order ID
        
        Returns:
            Payment status details
        """
        if not self.client:
            self._initialize_client()
            if not self.client:
                return {"success": False, "status": "ERROR", "error": "Client not initialized"}
        
        try:
            # Get payment status
            response = self.client.get_payment_status(merchant_order_id)
            
            status_map = {
                "COMPLETED": "completed",
                "PENDING": "pending",
                "FAILED": "failed",
                "AUTHORIZED": "authorized",
                "REFUNDED": "refunded"
            }
            
            status = status_map.get(getattr(response, 'state', 'UNKNOWN'), 'unknown')
            
            return {
                "success": True,
                "status": status,
                "transaction_id": getattr(response, 'transaction_id', None),
                "amount": getattr(response, 'amount', None),
                "completed_at": getattr(response, 'completed_at', None)
            }
            
        except Exception as e:
            logger.error(f"❌ PhonePe status check failed: {e}")
            return {"success": False, "status": "ERROR", "error": str(e)}


# Create global instance
phonepe_sdk_service = PhonePeSDKService()