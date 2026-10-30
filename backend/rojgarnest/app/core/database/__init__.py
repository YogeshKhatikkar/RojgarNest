# app/core/database/__init__.py
"""
Database Module - Connection & Operations
"""

from app.core.database.connection import get_db, connect_db, close_db
from app.core.database.redis import redis_client
from app.core.database.indexes import setup_all_indexes

# ✅ BACKWARD-COMPATIBILITY ALIAS
# Many route modules do: from app.core.database import get_database
# The real function is get_db. This alias prevents ImportError.
get_database = get_db

__all__ = [
    'get_db',
    'get_database',      # alias → get_db
    'connect_db',
    'close_db',
    'redis_client',
    'setup_all_indexes'
]