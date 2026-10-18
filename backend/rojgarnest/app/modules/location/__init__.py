# app/modules/location/__init__.py
"""
Centralized Location Module
Can be called from Auth, Jobs, Admin, or any other module
"""

from app.modules.location.routes import router
from app.modules.location.service import LocationService

__all__ = ['router', 'LocationService']