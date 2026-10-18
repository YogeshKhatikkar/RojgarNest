# app/core/location/location_service.py
"""
Helper Location Service - NO SEPARATE DATABASE TABLE
Just helper functions for auth and job modules to use
"""

import math
import re
import httpx
import logging
from typing import Dict, Any, Optional, Tuple, List
from datetime import datetime

logger = logging.getLogger(__name__)


class LocationHelper:
    """Helper class for location operations - NO SEPARATE TABLE"""
    
    earth_radius_meters = 6371000
    _cache = {}
    
    # ==================== COORDINATE PARSING ====================
    
    @classmethod
    def parse_coordinates(cls, coordinate_str: str) -> Tuple[float, float]:
        """Parse any coordinate format to (latitude, longitude)"""
        coordinate_str = coordinate_str.strip()
        
        # Try DD first
        try:
            return cls._parse_dd(coordinate_str)
        except ValueError:
            pass
        
        # Try DMS format
        if '°' in coordinate_str:
            try:
                return cls._parse_dms(coordinate_str)
            except ValueError:
                pass
        
        # Try DMM format
        if re.match(r'\d+\s+\d+(?:\.\d+)?\s*[, ]\s*\d+\s+\d+(?:\.\d+)?', coordinate_str):
            try:
                return cls._parse_dmm(coordinate_str)
            except ValueError:
                pass
        
        raise ValueError(f"Unsupported coordinate format: {coordinate_str}")
    
    @classmethod
    def _parse_dd(cls, dd_str: str) -> Tuple[float, float]:
        parts = dd_str.replace(',', ' ').split()
        if len(parts) != 2:
            raise ValueError(f"Invalid DD format: {dd_str}")
        return float(parts[0]), float(parts[1])
    
    @classmethod
    def _parse_dms(cls, dms_str: str) -> Tuple[float, float]:
        pattern = r'(\d+)°(\d+)′?(\d+(?:\.\d+)?)?"?([NS])\s+(\d+)°(\d+)′?(\d+(?:\.\d+)?)?"?([EW])'
        match = re.match(pattern, dms_str.strip())
        if not match:
            raise ValueError(f"Invalid DMS format: {dms_str}")
        
        lat_deg = int(match.group(1))
        lat_min = int(match.group(2))
        lat_sec = float(match.group(3))
        lat_dir = match.group(4)
        
        lon_deg = int(match.group(5))
        lon_min = int(match.group(6))
        lon_sec = float(match.group(7))
        lon_dir = match.group(8)
        
        latitude = lat_deg + lat_min / 60 + lat_sec / 3600
        if lat_dir == 'S':
            latitude = -latitude
        
        longitude = lon_deg + lon_min / 60 + lon_sec / 3600
        if lon_dir == 'W':
            longitude = -longitude
        
        return latitude, longitude
    
    @classmethod
    def _parse_dmm(cls, dmm_str: str) -> Tuple[float, float]:
        pattern = r'(\d+)\s+(\d+(?:\.\d+)?)\s*[, ]\s*(\d+)\s+(\d+(?:\.\d+)?)'
        match = re.match(pattern, dmm_str.strip())
        if not match:
            raise ValueError(f"Invalid DMM format: {dmm_str}")
        
        lat_deg = int(match.group(1))
        lat_min = float(match.group(2))
        lon_deg = int(match.group(3))
        lon_min = float(match.group(4))
        
        latitude = lat_deg + lat_min / 60
        longitude = lon_deg + lon_min / 60
        
        upper_str = dmm_str.upper()
        if 'S' in upper_str:
            latitude = -abs(latitude)
        if 'W' in upper_str:
            longitude = -abs(longitude)
        
        return latitude, longitude
    
    # ==================== COORDINATE FORMATTING ====================
    
    @classmethod
    def to_dms(cls, latitude: float, longitude: float) -> str:
        lat_dir = 'N' if latitude >= 0 else 'S'
        lon_dir = 'E' if longitude >= 0 else 'W'
        
        lat_abs = abs(latitude)
        lon_abs = abs(longitude)
        
        lat_deg = int(lat_abs)
        lat_min = int((lat_abs - lat_deg) * 60)
        lat_sec = (lat_abs - lat_deg - lat_min / 60) * 3600
        
        lon_deg = int(lon_abs)
        lon_min = int((lon_abs - lon_deg) * 60)
        lon_sec = (lon_abs - lon_deg - lon_min / 60) * 3600
        
        return f"{lat_deg}°{lat_min:02d}'{lat_sec:.1f}\"{lat_dir} {lon_deg}°{lon_min:02d}'{lon_sec:.1f}\"{lon_dir}"
    
    @classmethod
    def to_dmm(cls, latitude: float, longitude: float) -> str:
        lat_abs = abs(latitude)
        lon_abs = abs(longitude)
        
        lat_deg = int(lat_abs)
        lat_min = (lat_abs - lat_deg) * 60
        
        lon_deg = int(lon_abs)
        lon_min = (lon_abs - lon_deg) * 60
        
        return f"{lat_deg} {lat_min:.4f}, {lon_deg} {lon_min:.4f}"
    
    # ==================== DISTANCE CALCULATION ====================
    
    @classmethod
    def calculate_distance(cls, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """Calculate distance in meters using Haversine formula"""
        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        delta_lat = math.radians(lat2 - lat1)
        delta_lon = math.radians(lon2 - lon1)
        
        a = (math.sin(delta_lat / 2) ** 2 + 
             math.cos(lat1_rad) * math.cos(lat2_rad) * 
             math.sin(delta_lon / 2) ** 2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        
        return cls.earth_radius_meters * c
    
    @classmethod
    def format_distance(cls, lat1: float, lon1: float, lat2: float, lon2: float) -> str:
        distance_m = cls.calculate_distance(lat1, lon1, lat2, lon2)
        if distance_m >= 1000:
            return f"{distance_m / 1000:.2f} km"
        else:
            return f"{distance_m:.0f} m"
    
    @classmethod
    def is_within_distance(cls, lat1: float, lon1: float, lat2: float, lon2: float, threshold_meters: float = 100) -> bool:
        return cls.calculate_distance(lat1, lon1, lat2, lon2) <= threshold_meters
    
    # ==================== REVERSE GEOCODING (FREE - OpenStreetMap) ====================
    
    @classmethod
    async def get_accurate_location(cls, latitude: float, longitude: float, custom_name: Optional[str] = None) -> Dict[str, Any]:
        """Get accurate location name using OpenStreetMap (FREE)"""
        
        cache_key = f"{latitude:.6f}:{longitude:.6f}"
        if cache_key in cls._cache:
            cached = cls._cache[cache_key]
            if (datetime.utcnow() - cached.get('cached_at', datetime.utcnow())).total_seconds() < 86400:
                return cached
        
        result = {
            "latitude": latitude,
            "longitude": longitude,
            "formats": {
                "dd": f"{latitude:.6f}, {longitude:.6f}",
                "dms": cls.to_dms(latitude, longitude),
                "dmm": cls.to_dmm(latitude, longitude)
            },
            "location_details": {},
            "source": "openstreetmap"
        }
        
        osm_data = await cls._reverse_geocode_osm(latitude, longitude)
        if osm_data:
            result["location_details"] = osm_data
            result["location_name"] = custom_name or osm_data.get("display_name", osm_data.get("formatted_name"))
            result["city"] = osm_data.get("city")
            result["state"] = osm_data.get("state")
            result["district"] = osm_data.get("district")
            result["country"] = osm_data.get("country")
            result["postal_code"] = osm_data.get("postcode")
        else:
            result["location_name"] = custom_name or f"{latitude:.6f}, {longitude:.6f}"
        
        result["cached_at"] = datetime.utcnow()
        cls._cache[cache_key] = result
        
        if len(cls._cache) > 1000:
            keys_to_remove = list(cls._cache.keys())[:200]
            for key in keys_to_remove:
                del cls._cache[key]
        
        return result
    
    @classmethod
    async def _reverse_geocode_osm(cls, latitude: float, longitude: float) -> Optional[Dict[str, Any]]:
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.get(
                    "https://nominatim.openstreetmap.org/reverse",
                    params={
                        "lat": latitude,
                        "lon": longitude,
                        "format": "json",
                        "zoom": 18,
                        "addressdetails": 1
                    },
                    headers={"User-Agent": "rojgarnest/1.0"}
                )
                
                if response.status_code == 200:
                    data = response.json()
                    address = data.get("address", {})
                    
                    return {
                        "display_name": data.get("display_name", ""),
                        "formatted_name": data.get("display_name", ""),
                        "city": address.get("city") or address.get("town") or address.get("village"),
                        "district": address.get("state_district") or address.get("county"),
                        "state": address.get("state"),
                        "country": address.get("country"),
                        "postcode": address.get("postcode")
                    }
                return None
        except Exception as e:
            logger.error(f"OSM reverse geocoding error: {e}")
            return None


location_helper = LocationHelper()


print("✅ Location Helper Loaded - No Separate Database Table")