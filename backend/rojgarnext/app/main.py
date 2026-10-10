# app/main.py - COMPLETE FIXED VERSION
# ✅ FIXED: HTTPException dict detail preserved for account lock info
# ✅ FIXED: All error handlers return proper dict details
# ✅ FIXED: No data loss on error responses

from fastapi import FastAPI, Request, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, ORJSONResponse
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.staticfiles import StaticFiles
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from contextlib import asynccontextmanager
import json
import uuid
import asyncio
import time
from datetime import datetime, timedelta
from typing import Dict, Any, Optional
import os

# ================= DATABASE & CORE =================
from app.db.connection import connect_db, close_db, get_db
from app.core.utils.logger import logger
from app.core.middleware.response import ApiResponse
from app.core.config.settings import settings

# ================= SECURITY IMPORTS =================
from app.core.security.security_middleware import SecurityMiddleware, UltraSecureAuth
from app.core.security.ip_blacklist import ip_blacklist
from app.core.security.encryption import encryption_manager, DataProtector

# ================= MODULE IMPORTS =================
from app.modules.auth.routes import router as auth_router
from app.modules.user.routes import router as user_router
from app.modules.admin.routes import router as admin_router
from app.modules.superadmin.routes import router as superadmin_router
from app.modules.jobs.routes import router as jobs_router
from app.modules.services.routes import router as service_router
from app.modules.notification.routes import router as notification_router
from app.modules.resume.routes import router as resume_router
from app.modules.user.career_routes import router as career_router
from app.modules.market.routes import router as market_router
from app.modules.customadmin.routes import router as customadmin_router
from app.modules.location.routes import router as location_router
from app.modules.payment.routes import router as payment_router
from app.modules.support.routes import router as support_router
from app.modules.schemes.routes import router as schemes_router
# ================= ORJSON FALLBACK =================
try:
    DefaultResponse = ORJSONResponse
    print("⚡ Using ORJSONResponse (Ultra Fast)")
except ImportError:
    DefaultResponse = JSONResponse
    print("⚠️ ORJSON not installed, falling back to JSONResponse")

security = HTTPBearer(auto_error=False)


async def verify_token(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
):
    """Global token verification"""
    if not credentials:
        raise HTTPException(status_code=401, detail="Not authenticated")
    return credentials.credentials


# ================= LIFESPAN =================
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("=" * 60)
    print("🚀 RojgarNext Ultra-Secure Backend Starting...")
    print("=" * 60)

    start_time = time.time()

    # ✅ Connect MongoDB
    try:
        await connect_db()
        logger.info("✅ MongoDB Connected")
    except Exception as e:
        logger.error(f"❌ MongoDB Connection Failed: {e}")

    # ✅ Connect Redis
    if settings.REDIS_URL:
        try:
            import redis.asyncio as redis
            redis_client = redis.from_url(
                settings.REDIS_URL, decode_responses=True
            )
            await redis_client.ping()
            logger.info("✅ Redis Connected")
        except Exception as e:
            logger.warning(f"⚠️ Redis connection failed: {e}")

    # ================= START SCHEDULERS =================
    scheduler = None
    try:
        from apscheduler.schedulers.asyncio import AsyncIOScheduler

        scheduler = AsyncIOScheduler(timezone="Asia/Kolkata")

        # Only add IP cleanup scheduler
        scheduler.add_job(
            ip_blacklist.cleanup_expired,
            trigger='interval',
            hours=1,
            id='ip_cleanup',
            replace_existing=True
        )

        scheduler.start()
        logger.info("✅ Scheduler started")

    except Exception as e:
        logger.error(f"❌ Scheduler error: {e}")

    # ✅ Auto Scheduler
    try:
        from app.core.task.auto_scheduler import auto_scheduler
        await auto_scheduler.start()
        logger.info("✅ Auto Scheduler Started")
    except Exception as e:
        logger.error(f"❌ Auto scheduler error: {e}")

    # ✅ AI Engines
    try:
        from app.core.ai.ultra_ai_engine import ultra_ai_engine
        from app.core.ai.ultra_career_ai import ultra_career_ai
        from app.core.ai.real_time_market_ai import real_time_market_ai
        logger.info("✅ AI Engines Initialized")
    except Exception as e:
        logger.error(f"❌ AI Engine error: {e}")

    startup_time = time.time() - start_time

    print("=" * 60)
    print(f"🎉 Server Started! ({startup_time:.2f}s)")
    print("⚠️⚠️⚠️ AUTO JOB FETCH: COMPLETELY DISABLED ⚠️⚠️⚠️")
    print("   - No automatic job fetching will run")
    print("   - Jobs can only be added manually by admins")
    print(f"📚 API Docs: http://localhost:8000/docs")
    print("=" * 60)

    yield

    print("🛑 Shutting down...")
    try:
        if scheduler:
            scheduler.shutdown(wait=False)
    except Exception:
        pass
    await close_db()
    print("👋 Shutdown Complete")


# ================= APP INITIALIZATION =================
app = FastAPI(
    title="RojgarNext API - Ultra Secure Enterprise Edition",
    version="5.0.0",
    description="World's Most Advanced AI-Powered Job Portal",
    lifespan=lifespan,
    default_response_class=DefaultResponse,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    swagger_ui_parameters={
        "persistAuthorization": True,
        "displayRequestDuration": True,
        "filter": True
    }
)

# ================= STATIC FILES =================
UPLOAD_DIR = "./uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

if os.path.exists(UPLOAD_DIR):
    app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")
    logger.info("✅ Static files mounted for uploads")


# ================= MIDDLEWARES =================

def is_docs_path(path: str) -> bool:
    return path.startswith(("/docs", "/redoc", "/openapi.json"))


@app.middleware("http")
async def ip_blacklist_middleware(request: Request, call_next):
    if is_docs_path(request.url.path):
        return await call_next(request)

    client_ip = request.headers.get("X-Forwarded-For", request.client.host)
    if client_ip:
        client_ip = client_ip.split(",")[0].strip()

    if await ip_blacklist.is_blacklisted(client_ip):
        return JSONResponse(
            status_code=403,
            content={
                "success": False,
                "message": "Access denied",
                "code": "E403"
            }
        )

    return await call_next(request)


@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = (
        "max-age=31536000; includeSubDomains"
    )
    response.headers["X-Request-ID"] = str(uuid.uuid4())[:8]
    return response


@app.middleware("http")
async def request_logging_middleware(request: Request, call_next):
    request_id = str(uuid.uuid4())[:8]
    start_time = time.time()

    is_docs = is_docs_path(request.url.path)

    if not is_docs:
        logger.info(f"📥 [{request_id}] {request.method} {request.url.path}")

    response = await call_next(request)

    process_time = time.time() - start_time

    if not is_docs:
        logger.info(
            f"📤 [{request_id}] Status: {response.status_code} | "
            f"Time: {process_time:.3f}s"
        )

    response.headers["X-Process-Time"] = str(process_time)
    response.headers["X-Request-ID"] = request_id

    return response


request_counts = {}


@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    if is_docs_path(request.url.path):
        return await call_next(request)

    client_ip = request.headers.get("X-Forwarded-For", request.client.host)
    if client_ip:
        client_ip = client_ip.split(",")[0].strip()

    now = time.time()
    window = 60
    max_requests = 100

    if client_ip not in request_counts:
        request_counts[client_ip] = []

    request_counts[client_ip] = [
        t for t in request_counts[client_ip] if t > now - window
    ]

    if len(request_counts[client_ip]) >= max_requests:
        return JSONResponse(
            status_code=429,
            content={
                "success": False,
                "message": "Too many requests",
                "code": "E429"
            }
        )

    request_counts[client_ip].append(now)
    return await call_next(request)


# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://127.0.0.1",
        "http://localhost:3000",
        "http://localhost:8000",
        "http://127.0.0.1:8000",
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "http://localhost:5000",
        "http://127.0.0.1:5000",
        "http://localhost:8081",
        "http://127.0.0.1:8081",
        "https://www.rojgarnext.com",
        "https://rojgarnext.com",
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allow_headers=["*"],
    expose_headers=["*"],
    max_age=3600,
)


# ================= ERROR HANDLERS =================

@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    """
    ✅ Handle HTTP exceptions with FULL detail support.

    - If `detail` is a **dict** → return it as-is (preserves account lock
      info like `code`, `seconds_remaining`, `lock_until`, etc.)
    - If `detail` is a **string** → wrap it in a standard error response.
    - If `detail` is a **list** → join as a message.
    """
    logger.debug(
        f"🔴 HTTPException [{exc.status_code}]: {exc.detail}"
    )

    # ============================================================
    # ✅ CASE 1: dict detail → preserve everything (account lock, etc.)
    # ============================================================
    if isinstance(exc.detail, dict):
        detail_dict = dict(exc.detail)

        # Extract top-level message / code if present
        message = (
            detail_dict.get("message")
            or detail_dict.get("detail")
            or "HTTP Error"
        )
        code = detail_dict.get("code") or f"E{exc.status_code}"

        # ✅ Return the full detail dict so the client can read
        #    `seconds_remaining`, `lock_until`, `remaining_attempts`, etc.
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "success": False,
                "code": code,
                "message": message,
                "detail": detail_dict,  # ✅ full nested info preserved
                "request_id": str(uuid.uuid4())[:8],
            },
        )

    # ============================================================
    # ✅ CASE 2: list detail → join into a single message
    # ============================================================
    if isinstance(exc.detail, list):
        message = "; ".join(str(item) for item in exc.detail)
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "success": False,
                "code": f"E{exc.status_code}",
                "message": message,
                "detail": exc.detail,
                "request_id": str(uuid.uuid4())[:8],
            },
        )

    # ============================================================
    # ✅ CASE 3: string detail (or anything else) → standard wrapper
    # ============================================================
    return ApiResponse.error(
        message=str(exc.detail) if exc.detail else "HTTP Error",
        code=f"E{exc.status_code}",
        status_code=exc.status_code,
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request, exc: RequestValidationError
):
    """Handle request validation errors."""
    return JSONResponse(
        status_code=422,
        content={
            "success": False,
            "code": "E422",
            "message": "Validation Error",
            "detail": exc.errors(),
            "request_id": str(uuid.uuid4())[:8],
        },
    )


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Handle ALL unhandled exceptions - never leaks stack to client."""
    logger.error(f"❌ Unhandled error: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "code": "E500",
            "message": "Internal Server Error",
            "detail": str(exc) if settings.ENVIRONMENT == "development" else None,
            "request_id": str(uuid.uuid4())[:8],
        },
    )


# ================= ROUTES =================
app.include_router(
    auth_router, prefix="/api/v1/auth", tags=["Authentication"]
)
app.include_router(
    user_router, prefix="/api/v1/user", tags=["User Management"]
)
app.include_router(
    admin_router, prefix="/api/v1/admin", tags=["Admin Management"]
)
app.include_router(
    customadmin_router,
    prefix="/api/v1/customadmin",
    tags=["Custom Admin Management"]
)
app.include_router(
    superadmin_router,
    prefix="/api/v1/superadmin",
    tags=["SuperAdmin Management"]
)
app.include_router(
    jobs_router, prefix="/api/v1/jobs", tags=["Job Management"]
)
app.include_router(
    service_router, prefix="/api/v1/services", tags=["Online Services"]
)
app.include_router(
    notification_router,
    prefix="/api/v1/notification",
    tags=["Notifications Management"]
)
app.include_router(
    resume_router, prefix="/api/v1/resume", tags=["Resume Management"]
)
app.include_router(
    career_router,
    prefix="/api/v1/career",
    tags=["Career Guidance Management"]
)
app.include_router(
    market_router,
    prefix="/api/v1/market",
    tags=["Market Intelligence Management"]
)
app.include_router(
    location_router, prefix="/api/v1/location", tags=["Location Services"]
)
app.include_router(
    payment_router, prefix="/api/v1/payment", tags=["Payment"]
)
app.include_router(
    support_router, prefix="/api/v1", tags=["Support"]
)
app.include_router(
    schemes_router, prefix="/api/v1/schemes", tags=["Government Schemes"]
)


# ================= ROOT & HEALTH ENDPOINTS =================

@app.get("/", tags=["Root"])
async def root():
    return ApiResponse.success(
        data={
            "name": "RojgarNext API",
            "version": "5.0.0",
            "status": "running",
            "docs": "/docs",
        },
        message="Welcome to RojgarNext API",
    )


@app.get("/api/v1/", tags=["Root"])
async def api_v1_root():
    return ApiResponse.success(
        data={
            "name": "RojgarNext API",
            "version": "5.0.0",
            "status": "running",
            "docs": "/docs",
            "api_version": "v1",
        },
        message="Welcome to RojgarNext API v1",
    )


@app.get("/health", tags=["Root"])
async def health_check():
    """Health check endpoint - FAST response"""
    db_status = "connected" if get_db() is not None else "disconnected"
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "services": {
            "database": db_status,
            "api": "running",
        },
        "version": "5.0.0",
        "auto_job_fetch": "disabled",
        "response_time_ms": 100,
    }


@app.get("/api/v1/health", tags=["Root"])
async def api_v1_health_check():
    db_status = "connected" if get_db() is not None else "disconnected"
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "services": {
            "database": db_status,
            "api": "running",
        },
        "version": "5.0.0",
        "api_version": "v1",
        "auto_job_fetch": "disabled",
        "response_time_ms": 100,
    }


@app.get("/security/status", tags=["Security"])
async def security_status():
    from app.models.security_model import SecurityType

    db = get_db()

    blacklist_stats = await ip_blacklist.get_blacklist_stats()

    security_logs_count = await db.security.count_documents(
        {
            "type": SecurityType.SECURITY_LOG,
            "created_at": {
                "$gte": datetime.utcnow() - timedelta(hours=24)
            },
        }
    )

    ai_insights_count = await db.ai_insights.count_documents({})
    active_sessions = await db.sessions.count_documents({"is_active": True})

    return ApiResponse.success(
        data={
            "ip_blacklist": blacklist_stats,
            "rate_limiting": {"active": True, "max_per_minute": 100},
            "encryption": {"active": bool(settings.ENCRYPTION_KEY)},
            "security_logs_24h": security_logs_count,
            "unified_collections": {
                "security": "IP blacklist + Security logs",
                "sessions": (
                    f"Active: {active_sessions} + Archived sessions"
                ),
                "ai_insights": (
                    f"Career + Learning + Training "
                    f"({ai_insights_count} records)"
                ),
            },
        },
        message="Security status retrieved",
    )


print("=" * 60)
print("✅ RojgarNext Backend Loaded Successfully!")
print("⚠️⚠️⚠️ AUTO JOB FETCH: COMPLETELY DISABLED ⚠️⚠️⚠️")
print("   - No automatic job fetching will run")
print("   - Jobs can only be added manually by admins")
print(f"📚 API Docs: http://localhost:8000/docs")
print("=" * 60)