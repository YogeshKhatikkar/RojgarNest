# app/core/monitoring/system_monitor.py - Top of file
"""
Enterprise System Monitoring with Real-time Metrics
"""

import platform
import asyncio
import time
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from collections import deque
import json
import logging

# Try to import psutil, fallback to basic metrics
try:
    import psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False
    import psutil as psutil_fallback  # This will be None

from app.db.connection import get_db
from app.core.utils.logger import logger

logger = logging.getLogger(__name__)


class SystemMonitor:
    """Advanced system monitoring with metrics collection"""
    
    def __init__(self):
        self.metrics_history = deque(maxlen=10000)
        self.alert_history = deque(maxlen=1000)
        self.is_monitoring = False
        self.monitoring_task = None
    
    async def start_monitoring(self):
        """Start background monitoring"""
        if not PSUTIL_AVAILABLE:
            logger.warning("⚠️ psutil not installed. System monitoring disabled.")
            return
        
        self.is_monitoring = True
        self.monitoring_task = asyncio.create_task(self._collect_metrics_periodically())
        logger.info("✅ System monitoring started")
    
    async def get_system_metrics(self) -> Dict[str, Any]:
        """Get comprehensive system metrics"""
        if not PSUTIL_AVAILABLE:
            return {"error": "psutil not installed", "status": "monitoring_disabled"}
        
        try:
            # CPU metrics
            cpu_percent = psutil.cpu_percent(interval=1)
            cpu_per_core = psutil.cpu_percent(percpu=True)
            cpu_freq = psutil.cpu_freq()
            
            # Memory metrics
            memory = psutil.virtual_memory()
            swap = psutil.swap_memory()
            
            # Disk metrics
            disk = psutil.disk_usage('/')
            disk_io = psutil.disk_io_counters()
            
            # Network metrics
            net_io = psutil.net_io_counters()
            
            # Process metrics
            process = psutil.Process()
            
            # Database metrics
            db_metrics = await self._get_db_metrics()
            
            return {
                "timestamp": datetime.utcnow().isoformat(),
                "system": {
                    "hostname": platform.node(),
                    "os": f"{platform.system()} {platform.release()}",
                    "python_version": platform.python_version(),
                    "uptime_seconds": time.time() - psutil.boot_time()
                },
                "cpu": {
                    "usage_percent": cpu_percent,
                    "per_core": cpu_per_core,
                    "cores": psutil.cpu_count(),
                    "frequency_mhz": cpu_freq.current if cpu_freq else 0
                },
                "memory": {
                    "total_gb": round(memory.total / (1024**3), 2),
                    "available_gb": round(memory.available / (1024**3), 2),
                    "used_gb": round(memory.used / (1024**3), 2),
                    "usage_percent": memory.percent,
                    "swap_used_gb": round(swap.used / (1024**3), 2) if swap else 0
                },
                "disk": {
                    "total_gb": round(disk.total / (1024**3), 2),
                    "used_gb": round(disk.used / (1024**3), 2),
                    "free_gb": round(disk.free / (1024**3), 2),
                    "usage_percent": disk.percent,
                    "read_bytes_mb": round(disk_io.read_bytes / (1024**2), 2) if disk_io else 0,
                    "write_bytes_mb": round(disk_io.write_bytes / (1024**2), 2) if disk_io else 0
                },
                "network": {
                    "bytes_sent_mb": round(net_io.bytes_sent / (1024**2), 2),
                    "bytes_recv_mb": round(net_io.bytes_recv / (1024**2), 2),
                    "packets_sent": net_io.packets_sent,
                    "packets_recv": net_io.packets_recv
                },
                "process": {
                    "memory_mb": round(process.memory_info().rss / (1024**2), 2),
                    "cpu_percent": process.cpu_percent(),
                    "threads": process.num_threads(),
                    "open_files": len(process.open_files())
                },
                "database": db_metrics
            }
        except Exception as e:
            logger.error(f"Failed to get system metrics: {e}")
            return {}
    
    # ... rest of the methods remain the same ...


system_monitor = SystemMonitor()