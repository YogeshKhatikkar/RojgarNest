# app/core/security/rate_limiter.py
"""
Rate Limiting Module
"""

from datetime import datetime, timedelta
from typing import Dict, List
from collections import defaultdict
import time


class RateLimiter:
    """Advanced rate limiting with multiple strategies"""
    
    def __init__(self):
        self.request_counts = defaultdict(list)
        self.global_limits = {
            'per_minute': 100,
            'per_hour': 1000,
            'per_day': 5000
        }
    
    def is_allowed(self, client_ip: str) -> bool:
        """Check if request is allowed based on rate limits"""
        now = time.time()
        
        # Minute limit
        minute_requests = [t for t in self.request_counts[client_ip] if t > now - 60]
        if len(minute_requests) >= self.global_limits['per_minute']:
            return False
        
        # Hour limit  
        hour_requests = [t for t in self.request_counts[client_ip] if t > now - 3600]
        if len(hour_requests) >= self.global_limits['per_hour']:
            return False
        
        # Day limit
        day_requests = [t for t in self.request_counts[client_ip] if t > now - 86400]
        if len(day_requests) >= self.global_limits['per_day']:
            return False
        
        self.request_counts[client_ip].append(now)
        return True
    
    def get_remaining(self, client_ip: str) -> Dict:
        """Get remaining request limits"""
        now = time.time()
        
        minute_requests = len([t for t in self.request_counts[client_ip] if t > now - 60])
        hour_requests = len([t for t in self.request_counts[client_ip] if t > now - 3600])
        day_requests = len([t for t in self.request_counts[client_ip] if t > now - 86400])
        
        return {
            'minute': max(0, self.global_limits['per_minute'] - minute_requests),
            'hour': max(0, self.global_limits['per_hour'] - hour_requests),
            'day': max(0, self.global_limits['per_day'] - day_requests)
        }


rate_limiter = RateLimiter()