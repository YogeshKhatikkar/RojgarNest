# app/core/response.py
from fastapi.responses import JSONResponse
from typing import Any, Optional
import uuid
from app.core.utils.logger import logger

class ApiResponse:
    """Standardized API Response Wrapper"""

    @staticmethod
    def success(
        data: Any = None,
        message: str = "Operation successful",
        status_code: int = 200
    ):
        return JSONResponse(
            status_code=status_code,
            content={
                "success": True,
                "data": data,
                "message": message,
                "request_id": str(uuid.uuid4())[:8]
            }
        )

    @staticmethod
    def error(
        message: str,
        code: str = "E000",
        status_code: int = 400,
        detail: Optional[Any] = None
    ):
        logger.warning(f"API Error [{code}]: {message}")
        return JSONResponse(
            status_code=status_code,
            content={
                "success": False,
                "code": code,
                "message": message,
                "detail": detail,
                "request_id": str(uuid.uuid4())[:8]
            }
        )