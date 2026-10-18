# app/core/database/redis.py - COMPLETE FIXED VERSION

import logging
from app.core.config.settings import settings

logger = logging.getLogger(__name__)


class SafeRedis:
    """Safe Redis client with graceful fallback when Redis is unavailable"""
    
    def __init__(self):
        self.client = None
        self.enabled = False
        self._initialize()
    
    def _initialize(self):
        """Initialize Redis connection with proper error handling"""
        try:
            import redis.asyncio as redis
            
            redis_url = getattr(settings, 'REDIS_URL', None)
            if not redis_url:
                logger.info("ℹ️ Redis URL not configured - running in cache-disabled mode")
                return
            
            self.client = redis.from_url(
                redis_url,
                decode_responses=True,
                socket_connect_timeout=3,
                socket_timeout=3,
                retry_on_timeout=True,
                health_check_interval=30,
            )
            self.enabled = True
            logger.info("✅ Redis client initialized successfully")
            
        except ImportError:
            logger.warning("⚠️ redis package not installed - run: pip install redis")
            self.enabled = False
            
        except Exception as e:
            logger.warning(f"⚠️ Redis initialization failed: {e}")
            self.enabled = False
            self.client = None
    
    async def setex(self, key, time, value):
        """Set key with expiry"""
        if not self.enabled or not self.client:
            return None
        
        try:
            return await self.client.setex(key, time, value)
        except Exception as e:
            logger.debug(f"Redis setex failed: {e}")
            self.enabled = False
            return None
    
    async def get(self, key):
        """Get value by key"""
        if not self.enabled or not self.client:
            return None
        
        try:
            return await self.client.get(key)
        except Exception as e:
            logger.debug(f"Redis get failed: {e}")
            self.enabled = False
            return None
    
    async def delete(self, key):
        """Delete key"""
        if not self.enabled or not self.client:
            return None
        
        try:
            return await self.client.delete(key)
        except Exception as e:
            logger.debug(f"Redis delete failed: {e}")
            self.enabled = False
            return None
    
    async def exists(self, key):
        """Check if key exists"""
        if not self.enabled or not self.client:
            return False
        
        try:
            return await self.client.exists(key) > 0
        except Exception as e:
            logger.debug(f"Redis exists failed: {e}")
            self.enabled = False
            return False
    
    async def incr(self, key):
        """Increment key value"""
        if not self.enabled or not self.client:
            return None
        
        try:
            return await self.client.incr(key)
        except Exception as e:
            logger.debug(f"Redis incr failed: {e}")
            self.enabled = False
            return None
    
    async def expire(self, key, time):
        """Set expiry on key"""
        if not self.enabled or not self.client:
            return None
        
        try:
            return await self.client.expire(key, time)
        except Exception as e:
            logger.debug(f"Redis expire failed: {e}")
            self.enabled = False
            return None
    
    async def ping(self):
        """Ping Redis server"""
        if not self.enabled or not self.client:
            return False
        
        try:
            return await self.client.ping()
        except Exception as e:
            logger.debug(f"Redis ping failed: {e}")
            self.enabled = False
            return False


# Create global instance
redis_client = SafeRedis()

print(f"✅ Redis client loaded (enabled: {redis_client.enabled})")