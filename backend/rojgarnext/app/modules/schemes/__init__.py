# app/modules/schemes/__init__.py
"""
Government Schemes Module
Provides Central and State Government schemes with application functionality
"""

from .routes import router
from .service import SchemeService

__all__ = ['router', 'SchemeService']