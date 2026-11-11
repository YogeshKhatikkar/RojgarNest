# app/modules/services/__init__.py
"""
Services Module - Online Services Application
"""

from .routes import router
from .service import ServiceService

__all__ = ['router', 'ServiceService']