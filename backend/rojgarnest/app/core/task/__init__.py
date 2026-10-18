# app/core/tasks/__init__.py
"""
Background Tasks Module
"""

from app.core.task.auto_scheduler import auto_scheduler

__all__ = ['auto_scheduler']