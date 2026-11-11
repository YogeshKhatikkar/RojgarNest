# app/modules/payment/phonepe_simple_service.py
# Simplified PhonePe service without SDK dependency

import uuid
import hashlib
import base64
import json
import requests
from typing import Dict, Any
from datetime import datetime
import logging

from app.core.config.settings import settings

logger = logging.getLogger(__name__)


class PhonePeSimpleService:
    """Simplified PhonePe integration using direct API calls"""
    
    def __init__(self):
        self.merchant_id = getattr(settings, 'PHONEPE_MERCHANT_ID', 'PGTESTPAYUAT')
        self.salt_key = getattr(settings, 'PHONEPE_SALT_KEY', '099eb0cd-02cf-4e2a-8aca-3e6c6aff0399')
        self.salt_index = getattr(settings, 'PHONEPE_SALT_INDEX', '1')
        
        # Use sandbox URLs for testing
        self.base_url = "https://api-preprod.phonepe.com/apis/hermes/pg"
        self.pay_url = f"{self.base_url}/v1/pay"
        self.status_url = f"{self.base_url}/v1/status"
    
    def create_qr_payment(self, amount: int, order_id: str, 
                          user_email: str, job_id: str) -> Dict[str, Any]:
        """Create PhonePe UPI QR payment"""
        
        merchant_order_id = f"RJ{order_id[-12:]}{int(datetime.now().timestamp())}"
        
        # Create payload for PhonePe
        payload = {
            "merchantId": self.merchant_id,
            "merchantTransactionId": merchant_order_id,
            "merchantUserId": user_email.replace('@', '_'),
            "amount": amount,  # Already in paise
            "redirectUrl": f"{settings.APP_BASE_URL}/api/v1/payment/phonepe-callback",
            "redirectMode": "REDIRECT",
            "callbackUrl": f"{settings.APP_BASE_URL}/api/v1/payment/phonepe-callback",
            "mobileNumber": "9999999999",
            "paymentInstrument": {
                "type": "PAY_PAGE"
            }
        }
        
        try:
            # Encode payload
            base64_payload = base64.b64encode(json.dumps(payload).encode()).decode()
            
            # Generate checksum
            checksum_string = f"{base64_payload}/pg/v1/pay{self.salt_key}"
            checksum = hashlib.sha256(checksum_string.encode()).hexdigest()
            x_verify = f"{checksum}###{self.salt_index}"
            
            # Make API call
            headers = {
                "Content-Type": "application/json",
                "X-VERIFY": x_verify
            }
            
            response = requests.post(
                self.pay_url,
                json={"request": base64_payload},
                headers=headers,
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                if result.get("success"):
                    return {
                        "success": True,
                        "order_id": result.get("data", {}).get("orderId"),
                        "merchant_order_id": merchant_order_id,
                        "qr_data": result.get("data", {}).get("qrData"),
                        "intent_url": result.get("data", {}).get("intentUrl"),
                        "amount": amount
                    }
            
            logger.error(f"PhonePe payment error: {response.text}")
            return {"success": False, "error": "Payment creation failed"}
            
        except Exception as e:
            logger.error(f"PhonePe exception: {e}")
            return {"success": False, "error": str(e)}
    
    def check_payment_status(self, merchant_order_id: str) -> Dict[str, Any]:
        """Check PhonePe payment status"""
        
        try:
            # Generate checksum for status check
            checksum_string = f"/pg/v1/status/{self.merchant_id}/{merchant_order_id}{self.salt_key}"
            checksum = hashlib.sha256(checksum_string.encode()).hexdigest()
            x_verify = f"{checksum}###{self.salt_index}"
            
            headers = {
                "Content-Type": "application/json",
                "X-VERIFY": x_verify
            }
            
            response = requests.get(
                f"{self.status_url}/{self.merchant_id}/{merchant_order_id}",
                headers=headers,
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                if result.get("success"):
                    data = result.get("data", {})
                    state = data.get("state", "PENDING")
                    
                    status_map = {
                        "COMPLETED": "completed",
                        "PENDING": "pending", 
                        "FAILED": "failed"
                    }
                    
                    return {
                        "success": True,
                        "status": status_map.get(state, "pending"),
                        "transaction_id": data.get("transactionId"),
                        "amount": data.get("amount")
                    }
            
            return {"success": False, "status": "unknown"}
            
        except Exception as e:
            logger.error(f"PhonePe status check error: {e}")
            return {"success": False, "status": "error", "error": str(e)}


phonepe_simple_service = PhonePeSimpleService()