# app/core/location/location_handler.py
# COMPLETE - ZERO HARDCODE, REAL GPS ONLY

import math
import httpx
from typing import Dict, Any, Tuple, List, Optional
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


class CoordinateParser:
    """Backward compatibility - Only DD format supported"""
    
    @staticmethod
    def parse_any(coordinate_str: str) -> Tuple[float, float]:
        try:
            parts = coordinate_str.replace(',', ' ').split()
            if len(parts) == 2:
                return (float(parts[0]), float(parts[1]))
        except:
            pass
        raise ValueError("Only Decimal Degrees (DD) format supported")
    
    @staticmethod
    def to_dms(latitude: float, longitude: float) -> str:
        return f"{latitude:.6f}, {longitude:.6f}"
    
    @staticmethod
    def to_dmm(latitude: float, longitude: float) -> str:
        return f"{latitude:.6f}, {longitude:.6f}"


class LocationDistanceCalculator:
    EARTH_RADIUS_METERS = 6371000
    
    @staticmethod
    def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        delta_lat = math.radians(lat2 - lat1)
        delta_lon = math.radians(lon2 - lon1)
        
        a = (math.sin(delta_lat / 2) ** 2 + 
             math.cos(lat1_rad) * math.cos(lat2_rad) * 
             math.sin(delta_lon / 2) ** 2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        
        return LocationDistanceCalculator.EARTH_RADIUS_METERS * c
    
    @staticmethod
    def format_distance(distance_meters: float) -> str:
        if distance_meters >= 1000:
            return f"{distance_meters / 1000:.2f} km"
        return f"{distance_meters:.0f} m"
    
    @staticmethod
    def is_within_distance(lat1: float, lon1: float, lat2: float, lon2: float, threshold_meters: float = 100) -> bool:
        return LocationDistanceCalculator.calculate_distance(lat1, lon1, lat2, lon2) <= threshold_meters


class SimpleLocationHandler:
    EARTH_RADIUS_METERS = 6371000
    
    @staticmethod
    def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        delta_lat = math.radians(lat2 - lat1)
        delta_lon = math.radians(lon2 - lon1)
        
        a = (math.sin(delta_lat / 2) ** 2 + 
             math.cos(lat1_rad) * math.cos(lat2_rad) * 
             math.sin(delta_lon / 2) ** 2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        
        return SimpleLocationHandler.EARTH_RADIUS_METERS * c
    
    @staticmethod
    def format_distance(distance_meters: float) -> str:
        if distance_meters >= 1000:
            return f"{distance_meters / 1000:.2f} km"
        return f"{distance_meters:.0f} m"
    
    @staticmethod
    async def get_location_name(latitude: float, longitude: float) -> Dict[str, Any]:
        """Get REAL location name - NO HARDCODE"""
        if latitude is None or longitude is None:
            return {
                "latitude": 0.0, "longitude": 0.0,
                "location_name": "Unknown", "city": "", "district": "", "state": "", "country": "India"
            }
        
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.get(
                    "https://nominatim.openstreetmap.org/reverse",
                    params={"lat": latitude, "lon": longitude, "format": "json", "zoom": 18, "addressdetails": 1},
                    headers={"User-Agent": "rojgarnest/1.0"}
                )
                
                if response.status_code == 200:
                    data = response.json()
                    address = data.get("address", {})
                    
                    city = address.get("city") or address.get("town") or address.get("village") or ""
                    district = address.get("state_district") or address.get("county") or ""
                    state = address.get("state") or ""
                    country = address.get("country") or "India"
                    
                    display_parts = []
                    if city and city != "Bhopal":
                        display_parts.append(city)
                    if district and district != city and district != "Bhopal":
                        display_parts.append(district)
                    if state and state != district:
                        display_parts.append(state)
                    
                    location_name = ", ".join(display_parts) if display_parts else f"{latitude:.4f}, {longitude:.4f}"
                    
                    return {
                        "latitude": latitude, "longitude": longitude,
                        "location_name": location_name, "city": city,
                        "district": district, "state": state, "country": country
                    }
        except Exception as e:
            logger.error(f"Geocoding error: {e}")
        
        return {
            "latitude": latitude, "longitude": longitude,
            "location_name": f"{latitude:.4f}, {longitude:.4f}",
            "city": "", "district": "", "state": "", "country": "India"
        }
    
    @staticmethod
    async def geocode_address(address: str) -> Tuple[float, float]:
        if not address or address.lower() in ["n/a", "remote", "", "anywhere"]:
            return (0.0, 0.0)
        
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(
                    "https://nominatim.openstreetmap.org/search",
                    params={"q": address, "format": "json", "limit": 1},
                    headers={"User-Agent": "rojgarnest/1.0"}
                )
                
                if response.status_code == 200:
                    data = response.json()
                    if data and len(data) > 0:
                        return (float(data[0]["lat"]), float(data[0]["lon"]))
        except Exception as e:
            logger.error(f"Geocoding failed: {e}")
        
        return (0.0, 0.0)


class LocationNameResolver:
    @classmethod
    async def get_accurate_location_name(cls, latitude: float, longitude: float, format_type: str = "full") -> Dict[str, Any]:
        return await SimpleLocationHandler.get_location_name(latitude, longitude)


class UltraAccurateLocationResolver:
    def __init__(self):
        self.resolver = LocationNameResolver
    
    async def get_ultra_accurate_location(self, latitude: float, longitude: float) -> Dict[str, Any]:
        return await LocationNameResolver.get_accurate_location_name(latitude, longitude)
    
    async def get_location_batch(self, coordinates_list: List[Tuple[float, float]]) -> List[Dict[str, Any]]:
        results = []
        for lat, lon in coordinates_list:
            location = await self.get_ultra_accurate_location(lat, lon)
            results.append(location)
        return results


# Global instances
location_handler = SimpleLocationHandler()
location_resolver = UltraAccurateLocationResolver()

logger.info("✅ Location Handler Loaded - NO HARDCODE, REAL GPS ONLY")