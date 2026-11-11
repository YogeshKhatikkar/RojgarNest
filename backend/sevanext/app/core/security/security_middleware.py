# app/core/security/security_middleware.py - UPDATED with unified security collection
"""
ULTRA SECURITY MIDDLEWARE - Military Grade Protection
Uses unified 'security' collection
"""

from fastapi import Request, HTTPException
from fastapi.security import HTTPBearer
from starlette.middleware.base import BaseHTTPMiddleware
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List
import hashlib
import re
import ipaddress
import time
from collections import defaultdict

from app.core.utils.logger import logger
from app.core.config.settings import settings
from app.models.security_model import SecurityType, Severity


class SecurityMiddleware(BaseHTTPMiddleware):
    """
    Enterprise-grade security middleware using unified security collection
    """
    
    def __init__(self, app):
        super().__init__(app)
        self.request_counts = defaultdict(list)
        self.suspicious_patterns = [
            r"(\%27)|(\')|(\-\-)|(\%23)|(#)",
            r"((\%3C)|<)((\%2F)|/)*[a-z0-9\%]+((\%3E)|>)",
            r"(UNION|SELECT|INSERT|DELETE|UPDATE|DROP|ALTER|CREATE|EXEC|MERGE|REPLACE)",
            r"<(script|iframe|object|embed|svg|math|link|meta)",
            r"on(load|click|error|mouseover|focus|blur|change|submit|reset)",
            r"javascript:|vbscript:|data:|expression:|eval\(|alert\(",
            r"eval\(|setTimeout\(|setInterval\(|Function\(",
            r"\\x[0-9a-fA-F]{2}|\\u[0-9a-fA-F]{4}",
            r"\.\.\/|\.\.\\",
            r"\$\{|\#\{|\%\{",
        ]
        self.compiled_patterns = [re.compile(p, re.IGNORECASE) for p in self.suspicious_patterns]
        
        self.whitelist_paths = [
            "/health",
            "/docs",
            "/redoc",
            "/openapi.json",
            "/api/v1/auth/register",
            "/api/v1/auth/login",
            "/api/v1/auth/verify-email",
            "/api/v1/auth/verify-mobile",
            "/api/v1/auth/forgot-password",
            "/api/v1/auth/reset-password"
        ]
    
    async def dispatch(self, request: Request, call_next):
        # Get client IP
        client_ip = self._get_client_ip(request)
        
        # Skip security checks for whitelisted paths
        if request.url.path in self.whitelist_paths:
            response = await call_next(request)
            return response
        
        # Check IP blacklist in unified security collection
        if await self._is_ip_blacklisted(client_ip):
            logger.warning(f"🚫 Blocked blacklisted IP: {client_ip}")
            await self._log_security_event(
                user_id=None,
                event_type="blacklisted_ip_blocked",
                details={"ip": client_ip, "path": request.url.path},
                severity="high"
            )
            raise HTTPException(status_code=403, detail="Access denied - IP blacklisted")
        
        # Rate limiting
        if not await self._check_rate_limit(client_ip):
            logger.warning(f"⚠️ Rate limit exceeded for IP: {client_ip}")
            await self._log_security_event(
                user_id=None,
                event_type="rate_limit_exceeded",
                details={"ip": client_ip, "path": request.url.path},
                severity="medium"
            )
            raise HTTPException(status_code=429, detail="Too many requests - rate limit exceeded")
        
        # Check request size
        if not await self._check_request_size(request):
            raise HTTPException(status_code=413, detail="Request too large - max 10MB")
        
        # Validate request headers
        if not await self._validate_headers(request):
            await self._log_security_event(
                user_id=None,
                event_type="invalid_headers",
                details={"ip": client_ip, "path": request.url.path, "headers": dict(request.headers)},
                severity="medium"
            )
            raise HTTPException(status_code=400, detail="Invalid request headers")
        
        # Check for suspicious patterns in query parameters
        if await self._check_query_params(request):
            await self._log_security_event(
                user_id=None,
                event_type="suspicious_query_params",
                details={"ip": client_ip, "path": request.url.path, "params": dict(request.query_params)},
                severity="high"
            )
            raise HTTPException(status_code=400, detail="Suspicious query parameters detected")
        
        # Check for suspicious patterns in request body
        if await self._check_request_body(request):
            await self._log_security_event(
                user_id=None,
                event_type="suspicious_body_content",
                details={"ip": client_ip, "path": request.url.path},
                severity="high"
            )
            raise HTTPException(status_code=400, detail="Suspicious request content detected")
        
        # Process request
        try:
            response = await call_next(request)
        except Exception as e:
            logger.error(f"Request processing error: {e}")
            raise
        
        # Add security headers to response
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload"
        response.headers["Content-Security-Policy"] = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=(), payment=(), usb=()"
        response.headers["Cache-Control"] = "no-store, max-age=0, must-revalidate"
        response.headers["Pragma"] = "no-cache"
        response.headers["X-Robots-Tag"] = "noindex, nofollow"
        
        return response
    
    def _get_client_ip(self, request: Request) -> str:
        """Get real client IP behind proxy"""
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            ips = forwarded.split(",")
            client_ip = ips[0].strip()
            try:
                ipaddress.ip_address(client_ip)
                return client_ip
            except:
                pass
        
        real_ip = request.headers.get("X-Real-IP")
        if real_ip:
            try:
                ipaddress.ip_address(real_ip)
                return real_ip
            except:
                pass
        
        if request.client and request.client.host:
            try:
                ipaddress.ip_address(request.client.host)
                return request.client.host
            except:
                pass
        
        return "0.0.0.0"
    
    async def _is_ip_blacklisted(self, ip: str) -> bool:
        """Check if IP is blacklisted in unified security collection"""
        from app.db.connection import get_db
        
        try:
            db = get_db()
            blacklisted = await db.security.find_one({
                "type": SecurityType.IP_BLACKLIST,
                "ip_address": ip,
                "$or": [
                    {"expires_at": {"$gt": datetime.utcnow()}},
                    {"permanent": True}
                ]
            })
            return blacklisted is not None
        except Exception as e:
            logger.error(f"IP blacklist check failed: {e}")
            return False
    
    async def _check_rate_limit(self, ip: str) -> bool:
        """Check rate limits per IP"""
        now = time.time()
        window = 60
        max_requests = 100
        
        self.request_counts[ip] = [t for t in self.request_counts[ip] if t > now - window]
        
        if len(self.request_counts[ip]) >= max_requests:
            return False
        
        self.request_counts[ip].append(now)
        return True
    
    async def _check_request_size(self, request: Request) -> bool:
        """Check request size limit"""
        content_length = request.headers.get("content-length")
        if content_length:
            try:
                size = int(content_length)
                if size > 10 * 1024 * 1024:
                    return False
            except ValueError:
                return False
        return True
    
    async def _validate_headers(self, request: Request) -> bool:
        """Validate request headers for security"""
        suspicious_headers = [
            "X-Forwarded-Host", "X-Original-URL", "X-Rewrite-URL",
            "X-HTTP-Method-Override", "X-Method-Override",
            "X-HTTP-Method", "X-Method"
        ]
        
        for header in suspicious_headers:
            if header in request.headers:
                logger.warning(f"Suspicious header detected: {header}")
                return False
        
        user_agent = request.headers.get("user-agent", "")
        if len(user_agent) > 1000:
            logger.warning(f"Excessively long User-Agent detected: {len(user_agent)} chars")
            return False
        
        if not user_agent and request.method != "OPTIONS":
            logger.warning("Empty User-Agent detected")
            return False
        
        if request.method in ["POST", "PUT", "PATCH"]:
            content_type = request.headers.get("content-type", "")
            allowed_types = ["application/json", "application/x-www-form-urlencoded", "multipart/form-data"]
            if content_type and not any(allowed in content_type for allowed in allowed_types):
                logger.warning(f"Invalid Content-Type: {content_type}")
                return False
        
        return True
    
    async def _check_query_params(self, request: Request) -> bool:
        """Check query parameters for suspicious patterns"""
        for key, value in request.query_params.items():
            if await self._scan_for_patterns(str(key)):
                logger.warning(f"Suspicious query param key: {key}")
                return True
            
            if await self._scan_for_patterns(str(value)):
                logger.warning(f"Suspicious query param value: {key}={value[:100]}")
                return True
        
        return False
    
    async def _check_request_body(self, request: Request) -> bool:
        """Check request body for suspicious patterns"""
        if request.method not in ["POST", "PUT", "PATCH"]:
            return False
        
        try:
            body = await request.body()
            if not body:
                return False
            
            try:
                body_str = body.decode('utf-8', errors='ignore')
            except:
                body_str = str(body)
            
            if await self._scan_for_patterns(body_str):
                logger.warning(f"Suspicious body content detected: {body_str[:500]}")
                return True
            
            try:
                import json
                data = json.loads(body_str)
                if isinstance(data, dict):
                    for key, value in data.items():
                        if await self._scan_for_patterns(str(key)):
                            return True
                        if isinstance(value, str) and await self._scan_for_patterns(value):
                            return True
            except:
                pass
            
        except Exception as e:
            logger.error(f"Body check error: {e}")
        
        return False
    
    async def _scan_for_patterns(self, text: str) -> bool:
        """Scan text for suspicious patterns"""
        if not text or len(text) > 10000:
            return False
        
        for pattern in self.compiled_patterns:
            if pattern.search(text):
                return True
        return False
    
    async def _log_security_event(self, user_id: Optional[str], event_type: str, 
                                   details: Dict[str, Any], severity: str = "medium"):
        """Log security events to unified security collection"""
        from app.db.connection import get_db
        from app.models.security_model import SecurityModel, Severity
        
        try:
            db = get_db()
            
            severity_map = {
                "low": Severity.LOW,
                "medium": Severity.MEDIUM,
                "high": Severity.HIGH,
                "critical": Severity.CRITICAL
            }
            
            security_log = SecurityModel.create_log(
                ip=details.get("ip", "unknown"),
                event_type=event_type,
                severity=severity_map.get(severity, Severity.MEDIUM),
                details=details,
                user_id=user_id
            )
            
            await db.security.insert_one(security_log.model_dump(by_alias=True))
        except Exception as e:
            logger.error(f"Failed to log security event: {e}")


class UltraSecureAuth(HTTPBearer):
    """
    Enhanced authentication with token validation
    """
    
    async def __call__(self, request: Request):
        # Get token
        auth_header = request.headers.get("Authorization")
        if not auth_header:
            raise HTTPException(status_code=401, detail="Missing authorization header")
        
        if not auth_header.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="Invalid authorization format")
        
        token = auth_header[7:]
        
        if len(token) < 20 or len(token) > 500:
            raise HTTPException(status_code=401, detail="Invalid token format")
        
        # Decode and validate token
        from jose import jwt, JWTError
        from app.db.connection import get_db
        from app.core.config.settings import settings
        
        try:
            payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=["HS256"])
            user_id = payload.get("user_id")
            
            if not user_id:
                raise HTTPException(status_code=401, detail="Invalid token payload")
            
            db = get_db()
            # Check session in unified sessions collection
            session = await db.sessions.find_one({
                "user_id": user_id,
                "is_active": True
            })
            
            if not session:
                raise HTTPException(status_code=401, detail="Session expired")
            
            return payload
            
        except JWTError as e:
            raise HTTPException(status_code=401, detail=f"Invalid token: {str(e)}")
        except Exception as e:
            logger.error(f"Auth error: {e}")
            raise HTTPException(status_code=401, detail="Authentication failed")


print("✅ Security Middleware Loaded Successfully - Using Unified Collections")