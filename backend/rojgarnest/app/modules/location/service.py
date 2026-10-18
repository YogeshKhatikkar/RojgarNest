# app/modules/location/service.py
"""
Centralized Location Service - Complete Implementation
Can be called by Auth, Jobs, Admin, or any other module
"""

import math
import re
import httpx
import logging
from typing import Dict, Any, Optional, List, Tuple
from datetime import datetime, timedelta
from bson import ObjectId

from app.db.connection import get_db

logger = logging.getLogger(__name__)


class LocationService:
    """Centralized location service for the entire application"""
    
    def __init__(self, db=None):
        self.db = db or get_db()
        self.earth_radius_meters = 6371000  # Earth's radius in meters
        self._cache = {}  # In-memory cache for location data
    
    # ==================== COORDINATE PARSING ====================
    
    def parse_coordinates(self, coordinate_str: str) -> Tuple[float, float]:
        """
        Parse any coordinate format to (latitude, longitude)
        Supports: DD, DMS, DMM formats
        """
        coordinate_str = coordinate_str.strip()
        
        # Try DD first (simple decimal numbers)
        try:
            return self._parse_dd(coordinate_str)
        except ValueError:
            pass
        
        # Try DMS format (has degree symbol)
        if '°' in coordinate_str:
            try:
                return self._parse_dms(coordinate_str)
            except ValueError:
                pass
        
        # Try DMM format (space separated numbers)
        if re.match(r'\d+\s+\d+(?:\.\d+)?\s*[, ]\s*\d+\s+\d+(?:\.\d+)?', coordinate_str):
            try:
                return self._parse_dmm(coordinate_str)
            except ValueError:
                pass
        
        raise ValueError(f"Unsupported coordinate format: {coordinate_str}")
    
    def _parse_dd(self, dd_str: str) -> Tuple[float, float]:
        """Parse Decimal Degrees format: 41.40338, 2.17403"""
        parts = dd_str.replace(',', ' ').split()
        if len(parts) != 2:
            raise ValueError(f"Invalid DD format: {dd_str}")
        
        try:
            latitude = float(parts[0])
            longitude = float(parts[1])
            return latitude, longitude
        except ValueError as e:
            raise ValueError(f"Cannot parse DD coordinates: {e}")
    
    def _parse_dms(self, dms_str: str) -> Tuple[float, float]:
        """Parse DMS format: 41°24'12.2\"N 2°10'26.5\"E"""
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
    
    def _parse_dmm(self, dmm_str: str) -> Tuple[float, float]:
        """Parse DMM format: 41 24.2028, 2 10.4418"""
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
        
        # Check for direction indicators
        upper_str = dmm_str.upper()
        if 'S' in upper_str:
            latitude = -abs(latitude)
        if 'W' in upper_str:
            longitude = -abs(longitude)
        
        return latitude, longitude
    
    # ==================== COORDINATE FORMATTING ====================
    
    def to_dms(self, latitude: float, longitude: float) -> str:
        """Convert decimal degrees to DMS format"""
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
    
    def to_dmm(self, latitude: float, longitude: float) -> str:
        """Convert decimal degrees to DMM format"""
        lat_abs = abs(latitude)
        lon_abs = abs(longitude)
        
        lat_deg = int(lat_abs)
        lat_min = (lat_abs - lat_deg) * 60
        
        lon_deg = int(lon_abs)
        lon_min = (lon_abs - lon_deg) * 60
        
        return f"{lat_deg} {lat_min:.4f}, {lon_deg} {lon_min:.4f}"
    
    # ==================== DISTANCE CALCULATION ====================
    
    def calculate_distance(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """
        Calculate distance between two coordinates in meters using Haversine formula
        """
        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        delta_lat = math.radians(lat2 - lat1)
        delta_lon = math.radians(lon2 - lon1)
        
        a = (math.sin(delta_lat / 2) ** 2 + 
             math.cos(lat1_rad) * math.cos(lat2_rad) * 
             math.sin(delta_lon / 2) ** 2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        
        return self.earth_radius_meters * c
    
    async def calculate_distance_between(
        self, 
        lat1: float, 
        lon1: float, 
        lat2: float, 
        lon2: float
    ) -> Dict[str, Any]:
        """Calculate distance with location names"""
        distance_m = self.calculate_distance(lat1, lon1, lat2, lon2)
        distance_km = distance_m / 1000
        
        # Get location names
        loc1_data = await self.get_accurate_location(lat1, lon1)
        loc2_data = await self.get_accurate_location(lat2, lon2)
        
        return {
            "distance_meters": round(distance_m, 2),
            "distance_km": round(distance_km, 2),
            "formatted_distance": f"{distance_km:.2f} km" if distance_km >= 1 else f"{distance_m:.0f} m",
            "from_location": loc1_data,
            "to_location": loc2_data
        }
    
    def is_within_distance(self, lat1: float, lon1: float, lat2: float, lon2: float, threshold_meters: float) -> bool:
        """Check if two locations are within threshold distance"""
        distance = self.calculate_distance(lat1, lon1, lat2, lon2)
        return distance <= threshold_meters
    
    # ==================== REVERSE GEOCODING (FREE - OpenStreetMap) ====================
    
    async def get_accurate_location(
        self, 
        latitude: float, 
        longitude: float,
        custom_name: Optional[str] = None
    ) -> Dict[str, Any]:
        """Get accurate location name using OpenStreetMap (FREE) with caching"""
        
        # Check cache first
        cache_key = f"{latitude:.6f}:{longitude:.6f}"
        if cache_key in self._cache:
            cached_data = self._cache[cache_key]
            if (datetime.utcnow() - cached_data.get('cached_at', datetime.utcnow())).total_seconds() < 86400:
                logger.info(f"📍 Location served from CACHE: {cached_data.get('location_name', 'Unknown')}")
                return cached_data
        
        result = {
            "latitude": latitude,
            "longitude": longitude,
            "formats": {
                "dd": f"{latitude:.6f}, {longitude:.6f}",
                "dms": self.to_dms(latitude, longitude),
                "dmm": self.to_dmm(latitude, longitude)
            },
            "location_details": {},
            "source": "openstreetmap"
        }
        
        # Try OpenStreetMap Nominatim (FREE, very accurate)
        osm_data = await self._reverse_geocode_osm(latitude, longitude)
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
        
        # Cache the result
        result["cached_at"] = datetime.utcnow()
        self._cache[cache_key] = result
        
        # Limit cache size
        if len(self._cache) > 1000:
            keys_to_remove = list(self._cache.keys())[:200]
            for key in keys_to_remove:
                del self._cache[key]
        
        return result
    
    async def _reverse_geocode_osm(self, latitude: float, longitude: float) -> Optional[Dict[str, Any]]:
        """Get location using OpenStreetMap Nominatim (COMPLETELY FREE)"""
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.get(
                    "https://nominatim.openstreetmap.org/reverse",
                    params={
                        "lat": latitude,
                        "lon": longitude,
                        "format": "json",
                        "zoom": 18,
                        "addressdetails": 1,
                        "extratags": 1,
                        "namedetails": 1
                    },
                    headers={"User-Agent": "rojgarnest/1.0 (https://rojgarnest.com)"}
                )
                
                if response.status_code == 200:
                    data = response.json()
                    address = data.get("address", {})
                    
                    location_data = {
                        "display_name": data.get("display_name", ""),
                        "formatted_name": data.get("display_name", ""),
                        "city": address.get("city") or address.get("town") or address.get("village"),
                        "district": address.get("state_district") or address.get("county"),
                        "state": address.get("state"),
                        "country": address.get("country"),
                        "postcode": address.get("postcode"),
                        "road": address.get("road"),
                        "house_number": address.get("house_number"),
                        "suburb": address.get("suburb"),
                        "neighbourhood": address.get("neighbourhood")
                    }
                    
                    return {k: v for k, v in location_data.items() if v is not None}
                
                logger.warning(f"OSM returned status {response.status_code}")
                return None
                
        except httpx.TimeoutException:
            logger.error("OSM reverse geocoding timeout")
            return None
        except Exception as e:
            logger.error(f"OSM reverse geocoding error: {e}")
            return None
    
    # ==================== USER LOCATION MANAGEMENT ====================
    
    async def save_user_location(
        self,
        user_email: str,
        latitude: float,
        longitude: float,
        location_data: Dict[str, Any]
    ) -> bool:
        """Save user's current location to database"""
        try:
            location_doc = {
                "latitude": latitude,
                "longitude": longitude,
                "location_name": location_data.get("location_name"),
                "location_details": location_data.get("location_details", {}),
                "all_formats": location_data.get("formats", {}),
                "source": location_data.get("source", "openstreetmap"),
                "last_updated": datetime.utcnow()
            }
            
            # Update auth collection
            result = await self.db.auth.update_one(
                {"email": user_email},
                {
                    "$set": {
                        "current_location": location_doc,
                        "last_location_update": datetime.utcnow()
                    }
                }
            )
            
            # Also update profile collection for cache
            await self.db.profile.update_one(
                {"email": user_email},
                {
                    "$set": {
                        "current_location": location_doc,
                        "last_location_update": datetime.utcnow()
                    }
                },
                upsert=True
            )
            
            logger.info(f"✅ Location saved for {user_email}")
            return result.modified_count > 0
            
        except Exception as e:
            logger.error(f"Failed to save location for {user_email}: {e}")
            return False
    
    async def get_user_location(self, user_email: str) -> Optional[Dict[str, Any]]:
        """Get user's current location"""
        user = await self.db.auth.find_one({"email": user_email})
        
        if user and user.get("current_location"):
            return user.get("current_location")
        
        return None
    
    async def smart_update_location(
        self,
        user_email: str,
        latitude: float,
        longitude: float,
        location_data: Dict[str, Any],
        force_update: bool = False
    ) -> Dict[str, Any]:
        """
        Smart location update - only updates if location changed significantly (>100m)
        """
        current_location = await self.get_user_location(user_email)
        
        result = {
            "updated": False,
            "reason": "no_change",
            "distance_moved": None
        }
        
        if force_update:
            result["updated"] = True
            result["reason"] = "force_update"
            
        elif current_location is None:
            result["updated"] = True
            result["reason"] = "first_location_save"
            
        else:
            old_lat = current_location.get("latitude")
            old_lng = current_location.get("longitude")
            
            if old_lat is not None and old_lng is not None:
                distance_moved = self.calculate_distance(old_lat, old_lng, latitude, longitude)
                result["distance_moved"] = round(distance_moved, 2)
                
                if distance_moved > 100:  # Update only if moved more than 100 meters
                    result["updated"] = True
                    result["reason"] = f"location_changed_{distance_moved:.0f}m"
                else:
                    result["reason"] = f"location_same_{distance_moved:.0f}m"
            else:
                result["updated"] = True
                result["reason"] = "incomplete_previous_location"
        
        if result["updated"]:
            await self.save_user_location(user_email, latitude, longitude, location_data)
        
        return result
    
    # ==================== NEARBY SEARCH ====================
    
    async def get_nearby_jobs(
        self,
        latitude: float,
        longitude: float,
        radius_km: float = 10.0,
        limit: int = 50
    ) -> List[Dict[str, Any]]:
        """Get jobs within radius of a location"""
        radius_meters = radius_km * 1000
        
        # Get all open jobs
        jobs = await self.db.job.find({"status": "open"}).to_list(500)
        
        nearby_jobs = []
        for job in jobs:
            job_location = job.get("geolocation", [0, 0])
            if len(job_location) == 2:
                job_lat, job_lon = job_location[1], job_location[0]  # [lng, lat] format
                distance = self.calculate_distance(latitude, longitude, job_lat, job_lon)
                
                if distance <= radius_meters:
                    job_copy = dict(job)
                    job_copy["_id"] = str(job_copy["_id"])
                    job_copy["distance_km"] = round(distance / 1000, 2)
                    job_copy["distance_meters"] = round(distance, 2)
                    nearby_jobs.append(job_copy)
        
        # Sort by distance
        nearby_jobs.sort(key=lambda x: x.get("distance_km", float('inf')))
        return nearby_jobs[:limit]
    
    async def get_nearby_users(
        self,
        exclude_email: str,
        latitude: float,
        longitude: float,
        radius_km: float = 10.0,
        limit: int = 50
    ) -> List[Dict[str, Any]]:
        """Get users within radius of a location (excluding self)"""
        radius_meters = radius_km * 1000
        
        # Get all users with location
        users = await self.db.auth.find({
            "email": {"$ne": exclude_email},
            "current_location": {"$exists": True}
        }).to_list(500)
        
        nearby_users = []
        for user in users:
            user_location = user.get("current_location", {})
            user_lat = user_location.get("latitude")
            user_lon = user_location.get("longitude")
            
            if user_lat is not None and user_lon is not None:
                distance = self.calculate_distance(latitude, longitude, user_lat, user_lon)
                
                if distance <= radius_meters:
                    nearby_users.append({
                        "email": user.get("email"),
                        "name": user.get("name"),
                        "role": user.get("role"),
                        "location": user_location.get("location_name"),
                        "distance_km": round(distance / 1000, 2),
                        "distance_meters": round(distance, 2)
                    })
        
        # Sort by distance
        nearby_users.sort(key=lambda x: x.get("distance_km", float('inf')))
        return nearby_users[:limit]
    
    # ==================== STATISTICS & HEALTH ====================
    
    async def get_location_stats(self) -> Dict[str, Any]:
        """Get location statistics for the platform"""
        total_users = await self.db.auth.count_documents({})
        users_with_location = await self.db.auth.count_documents({"current_location": {"$exists": True}})
        
        one_day_ago = datetime.utcnow() - timedelta(days=1)
        recent_updates = await self.db.auth.count_documents({
            "last_location_update": {"$gte": one_day_ago}
        })
        
        # Get location indexes status
        indexes = await self.db.auth.index_information()
        has_location_index = any("location" in str(k).lower() for k in indexes.keys())
        
        return {
            "total_users": total_users,
            "users_with_location": users_with_location,
            "location_coverage": round((users_with_location / max(1, total_users)) * 100, 2),
            "location_updates_last_24h": recent_updates,
            "location_index_exists": has_location_index,
            "supported_formats": ["Decimal Degrees (DD)", "DMS (Degrees, Minutes, Seconds)", "DMM (Degrees, Decimal Minutes)"],
            "geocoding_source": "OpenStreetMap (FREE)",
            "status": "healthy"
        }
    
    async def health_check(self) -> Dict[str, Any]:
        """Health check for location module"""
        return {
            "status": "healthy",
            "geocoding_service": "OpenStreetMap (active)",
            "distance_calculation": "Haversine formula (active)",
            "supported_coordinate_formats": ["DD", "DMS", "DMM"],
            "features": [
                "Coordinate parsing (DD, DMS, DMM)",
                "Distance calculation",
                "Reverse geocoding (FREE)",
                "Nearby job search",
                "Nearby user search",
                "Smart location updates"
            ]
        }
    

# Add this method to app/modules/location/service.py if not already present

async def geocode_address(self, address: str) -> Optional[Dict[str, Any]]:
    """
    Geocode an address to get coordinates
    """
    if not address:
        return None
    
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(
                "https://nominatim.openstreetmap.org/search",
                params={
                    "q": address,
                    "format": "json",
                    "limit": 1,
                    "countrycodes": "in",
                    "addressdetails": 1,
                    "namedetails": 1
                },
                headers={"User-Agent": "rojgarnest/1.0"}
            )
            
            if response.status_code == 200:
                data = response.json()
                if data and len(data) > 0:
                    lat = float(data[0]["lat"])
                    lon = float(data[0]["lon"])
                    address_data = data[0].get("address", {})
                    
                    city = address_data.get("city") or address_data.get("town") or address_data.get("village")
                    district = address_data.get("state_district") or address_data.get("county")
                    state = address_data.get("state")
                    country = address_data.get("country", "India")
                    
                    return {
                        "latitude": lat,
                        "longitude": lon,
                        "city": city,
                        "district": district,
                        "state": state,
                        "country": country,
                        "display_name": data[0].get("display_name", address),
                        "source": "openstreetmap"
                    }
            return None
    except Exception as e:
        logger.error(f"Geocoding error: {e}")
        return None


print("✅ Centralized Location Service Loaded - Can be called from any module")