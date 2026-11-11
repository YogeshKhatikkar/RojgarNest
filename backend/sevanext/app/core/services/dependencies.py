# app/core/services/dependencies.py - COMPLETE FIXED VERSION

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer
from jose import jwt, JWTError
from app.core.config.settings import settings
from app.db.connection import get_db
from bson import ObjectId
from typing import List, Union

security = HTTPBearer()

async def get_current_user(credentials=Depends(security)):
    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.JWT_SECRET_KEY,
            algorithms=["HS256"]
        )
        
        if payload.get("type") != "access":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type"
            )
        
        user_id = payload.get("user_id")
        email = payload.get("email")
        name = payload.get("name")
        role = payload.get("role", "user")
        
        # ✅ Normalize "custom_admin" to "customadmin"
        if role in ["customadmin", "custom_admin"]:
            role = "customadmin"
        
        # If role not in token or email missing, fetch from database
        if not email or not user_id:
            db = get_db()
            if user_id and ObjectId.is_valid(user_id):
                user = await db.auth.find_one({"_id": ObjectId(user_id)})
            else:
                user = await db.auth.find_one({"email": email})
                
            if user:
                email = user.get("email")
                name = user.get("name")
                db_role = user.get("role", "user")
                # Normalize database role
                if db_role in ["customadmin", "custom_admin"]:
                    db_role = "customadmin"
                role = db_role
        
        return {
            "user_id": user_id,
            "role": role,
            "email": email,
            "name": name
        }
    
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token"
        )
    except Exception as e:
        print(f"Auth error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Could not validate credentials: {str(e)}"
        )


def role_required(allowed_roles: Union[str, List[str]]):
    """
    Check if user has any of the allowed roles
    Supports both "customadmin" and "custom_admin" formats
    """
    if isinstance(allowed_roles, str):
        allowed_roles = [allowed_roles]
    
    # ✅ Normalize allowed roles to lowercase
    normalized_allowed = []
    for role in allowed_roles:
        role_lower = role.lower()
        # Convert "custom_admin" to "customadmin" for comparison
        if role_lower == "custom_admin":
            normalized_allowed.append("customadmin")
        else:
            normalized_allowed.append(role_lower)
    
    def checker(current_user=Depends(get_current_user)):
        user_role = current_user.get("role", "").lower()
        
        if not user_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Role information missing"
            )
        
        # ✅ Convert user role for comparison
        if user_role == "custom_admin":
            user_role = "customadmin"
        
        print(f"🔐 Role Check - User: {user_role}, Allowed: {normalized_allowed}")
        
        if user_role not in normalized_allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. Required roles: {allowed_roles}, Your role: {user_role}"
            )
        
        return current_user
    return checker