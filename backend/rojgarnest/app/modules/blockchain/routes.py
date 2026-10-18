# app/modules/blockchain/routes.py
"""
Blockchain-based Certificate Verification (Mock Implementation)
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Dict, Optional
from datetime import datetime
import hashlib
import json

from app.core.services.dependencies import get_current_user
from app.core.utils.config import settings
from app.db.connection import get_db
from app.core.utils.logger import logger

router = APIRouter(prefix="/blockchain", tags=["Blockchain"])


class BlockchainVerifier:
    """Mock Blockchain-based certificate verification"""
    
    def __init__(self):
        self.contract_address = getattr(settings, 'CONTRACT_ADDRESS', '0x0')
    
    async def issue_certificate(self, recipient_address: str, 
                                certificate_data: Dict) -> str:
        """Mock issue certificate on blockchain"""
        
        # Generate certificate hash
        certificate_hash = self._generate_hash(certificate_data)
        
        # Mock transaction hash
        import secrets
        tx_hash = secrets.token_hex(32)
        
        return tx_hash
    
    async def verify_certificate(self, certificate_hash: str) -> bool:
        """Mock verify certificate authenticity"""
        # In real implementation, query blockchain
        db = get_db()
        cert = await db.blockchain_certificates.find_one({"certificate_hash": certificate_hash})
        return cert is not None
    
    def _generate_hash(self, data: Dict) -> str:
        """Generate SHA-256 hash of certificate data"""
        return hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()


blockchain = BlockchainVerifier()


@router.post("/issue-skill-certificate")
async def issue_skill_certificate(
    skill_name: str,
    wallet_address: str = Query(..., description="User's wallet address"),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Issue blockchain certificate for skill mastery"""
    
    # Verify skill mastery
    profile = await db.profile.find_one({"email": current_user["email"]})
    
    if not profile:
        raise HTTPException(404, "Profile not found")
    
    user_skills = [s.get("name") for s in profile.get("skills", [])]
    
    if skill_name not in user_skills:
        raise HTTPException(400, "Skill not found in profile")
    
    # Check skill level
    skill = next((s for s in profile.get("skills", []) if s.get("name") == skill_name), None)
    if not skill or skill.get("level") != "expert":
        raise HTTPException(400, "Certificate requires expert level")
    
    certificate_data = {
        "user_id": current_user["user_id"],
        "user_email": current_user["email"],
        "skill_name": skill_name,
        "skill_level": skill.get("level"),
        "completion_date": datetime.utcnow().isoformat(),
        "issuer": "RojgarNest"
    }
    
    # Issue on blockchain (mock)
    tx_hash = await blockchain.issue_certificate(wallet_address, certificate_data)
    cert_hash = blockchain._generate_hash(certificate_data)
    
    # Store certificate record
    await db.blockchain_certificates.insert_one({
        **certificate_data,
        "wallet_address": wallet_address,
        "transaction_hash": tx_hash,
        "certificate_hash": cert_hash,
        "issued_at": datetime.utcnow()
    })
    
    return {
        "success": True,
        "message": "Certificate issued successfully",
        "transaction_hash": tx_hash,
        "certificate_hash": cert_hash
    }


@router.get("/verify-certificate")
async def verify_certificate(
    certificate_hash: str = Query(..., description="Certificate hash to verify"),
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Verify certificate authenticity"""
    
    # Check in database
    cert = await db.blockchain_certificates.find_one({"certificate_hash": certificate_hash})
    
    is_valid = cert is not None
    
    return {
        "success": True,
        "certificate_hash": certificate_hash,
        "is_authentic": is_valid,
        "verified_at": datetime.utcnow().isoformat(),
        "details": {
            "skill": cert.get("skill_name") if cert else None,
            "issued_to": cert.get("user_email") if cert else None,
            "issued_at": cert.get("issued_at").isoformat() if cert and cert.get("issued_at") else None
        } if is_valid else None
    }


@router.get("/my-certificates")
async def get_my_certificates(
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db)
):
    """Get all certificates for current user"""
    
    certificates = await db.blockchain_certificates.find({
        "user_email": current_user["email"]
    }).sort("issued_at", -1).to_list(100)
    
    return {
        "success": True,
        "certificates": [
            {
                "certificate_hash": c["certificate_hash"],
                "skill_name": c["skill_name"],
                "skill_level": c["skill_level"],
                "issued_at": c["issued_at"].isoformat(),
                "transaction_hash": c["transaction_hash"]
            }
            for c in certificates
        ],
        "total": len(certificates)
    }


print("✅ Blockchain module loaded (Mock implementation)")