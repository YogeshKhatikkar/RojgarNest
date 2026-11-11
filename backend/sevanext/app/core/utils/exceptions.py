# app/core/utils/exceptions.py
from fastapi import HTTPException, status

class CustomException(HTTPException):
    """Base custom exception"""
    def __init__(self, status_code: int, detail: str, code: str = "E000"):
        super().__init__(status_code=status_code, detail=detail)
        self.code = code

class NotFoundException(CustomException):
    """Resource not found"""
    def __init__(self, detail: str = "Resource not found"):
        super().__init__(status_code=status.HTTP_404_NOT_FOUND, detail=detail, code="E404")

class ValidationException(CustomException):
    """Validation error"""
    def __init__(self, detail: str = "Validation error"):
        super().__init__(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=detail, code="E422")

class UnauthorizedException(CustomException):
    """Unauthorized access"""
    def __init__(self, detail: str = "Unauthorized"):
        super().__init__(status_code=status.HTTP_401_UNAUTHORIZED, detail=detail, code="E401")

class ForbiddenException(CustomException):
    """Forbidden access"""
    def __init__(self, detail: str = "Forbidden"):
        super().__init__(status_code=status.HTTP_403_FORBIDDEN, detail=detail, code="E403")