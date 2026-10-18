# app/core/database/__init__.py
"""
Database Module - Connection & Operations
"""

from app.core.database.connection import get_db, connect_db, close_db
from app.core.database.redis import redis_client
from app.core.database.indexes import setup_all_indexes

__all__ = [
    'get_db',
    'connect_db',
    'close_db',
    'redis_client',
    'setup_all_indexes'
]