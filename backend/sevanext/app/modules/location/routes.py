# app/modules/location/routes.py
"""
Centralized Location API Routes
Can be accessed by any module (Auth, Jobs, etc.)
"""

from fastapi import APIRouter, Depends, HTTPException, Query, Body, Request
from typing import Optional, List, Tuple
from datetime import datetime
import math
import httpx
import logging

from app.modules.location.service import LocationService
from app.core.services.dependencies import get_current_user
from app.db.connection import get_db

# Setup logger
logger = logging.getLogger(__name__)

router = APIRouter(prefix="/location", tags=["Location Management"])


async def get_location_service(db=Depends(get_db)):
    return LocationService(db)


# ==================== HELPER: CONVERT DATETIME TO STRING ====================
def serialize_dates(obj):
    """Convert datetime objects to ISO string for JSON serialization"""
    if isinstance(obj, datetime):
        return obj.isoformat()
    if isinstance(obj, dict):
        return {k: serialize_dates(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [serialize_dates(item) for item in obj]
    return obj


# ==================== CORE LOCATION ENDPOINTS ====================

@router.post("/resolve")
async def resolve_location(
    latitude: float = Body(..., ge=-90, le=90),
    longitude: float = Body(..., ge=-180, le=180),
    service: LocationService = Depends(get_location_service)
):
    """
    Get accurate location name from coordinates
    Can be called from ANY module (Auth, Jobs, Admin)
    """
    try:
        location_data = await service.get_accurate_location(latitude, longitude)
        return {
            "success": True,
            "data": serialize_dates(location_data),
            "message": "Location resolved successfully"
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "message": "Failed to resolve location"
        }


@router.post("/parse")
async def parse_coordinates(
    coordinates: str = Body(..., description="Coordinates in any format (DD, DMS, DMM)"),
    service: LocationService = Depends(get_location_service)
):
    """
    Parse coordinates from any format
    Supports: DD, DMS, DMM formats
    """
    try:
        lat, lon = service.parse_coordinates(coordinates)
        return {
            "success": True,
            "data": {"latitude": lat, "longitude": lon},
            "message": "Coordinates parsed successfully"
        }
    except ValueError as e:
        return {
            "success": False,
            "error": str(e),
            "message": "Failed to parse coordinates"
        }


@router.post("/distance")
async def calculate_distance_between(
    lat1: float = Body(..., ge=-90, le=90),
    lon1: float = Body(..., ge=-180, le=180),
    lat2: float = Body(..., ge=-90, le=90),
    lon2: float = Body(..., ge=-180, le=180),
    service: LocationService = Depends(get_location_service)
):
    """
    Calculate distance between two coordinates
    Can be called from Jobs module for location-based matching
    """
    try:
        distance_data = await service.calculate_distance_between(lat1, lon1, lat2, lon2)
        return {
            "success": True,
            "data": serialize_dates(distance_data),
            "message": "Distance calculated successfully"
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "message": "Failed to calculate distance"
        }


@router.post("/save-location")
async def save_user_location(
    latitude: float = Body(..., ge=-90, le=90),
    longitude: float = Body(..., ge=-180, le=180),
    location_name: Optional[str] = Body(None),
    current_user: dict = Depends(get_current_user),
    service: LocationService = Depends(get_location_service)
):
    """
    Save current location for logged-in user
    Used by Auth module during login/register
    """
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    try:
        location_data = await service.get_accurate_location(latitude, longitude, location_name)
        
        saved = await service.save_user_location(
            user_email=user_email,
            latitude=latitude,
            longitude=longitude,
            location_data=location_data
        )
        
        if saved:
            return {
                "success": True,
                "data": serialize_dates(location_data),
                "message": "Location saved successfully"
            }
        else:
            return {
                "success": False,
                "message": "Failed to save location"
            }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "message": f"Error saving location: {str(e)}"
        }


@router.put("/update-location")
async def update_user_location(
    latitude: float = Body(..., ge=-90, le=90),
    longitude: float = Body(..., ge=-180, le=180),
    location_name: Optional[str] = Body(None),
    force_update: bool = Body(False),
    current_user: dict = Depends(get_current_user),
    service: LocationService = Depends(get_location_service)
):
    """
    Update user's current location (smart update)
    Used by Auth module during login
    """
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    try:
        location_data = await service.get_accurate_location(latitude, longitude, location_name)
        
        result = await service.smart_update_location(
            user_email=user_email,
            latitude=latitude,
            longitude=longitude,
            location_data=location_data,
            force_update=force_update
        )
        
        return {
            "success": True,
            "data": {
                "location_updated": result["updated"],
                "location_data": serialize_dates(location_data),
                "reason": result["reason"],
                "distance_moved_meters": result.get("distance_moved")
            },
            "message": "Location update processed"
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "message": f"Error updating location: {str(e)}"
        }


@router.get("/my-location")
async def get_my_location(
    format: str = Query("full", description="Response format: full, short, city_state"),
    current_user: dict = Depends(get_current_user),
    service: LocationService = Depends(get_location_service)
):
    """
    Get current user's location
    Used by User module to display location
    """
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    try:
        location = await service.get_user_location(user_email)
        
        if not location:
            return {
                "success": False,
                "message": "No location found for this user",
                "data": None
            }
        
        if format == "short":
            result = {
                "name": location.get("location_name"),
                "city": location.get("location_details", {}).get("city"),
                "state": location.get("location_details", {}).get("state"),
                "coordinates": {
                    "latitude": location.get("latitude"),
                    "longitude": location.get("longitude")
                }
            }
        elif format == "city_state":
            details = location.get("location_details", {})
            city = details.get("city")
            state = details.get("state")
            if city and state:
                result = f"{city}, {state}"
            elif city:
                result = city
            else:
                result = location.get("location_name")
        else:
            result = serialize_dates(location)
        
        return {
            "success": True,
            "data": result,
            "message": "Location retrieved successfully"
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "message": f"Error getting location: {str(e)}"
        }


@router.post("/nearby-jobs")
async def get_nearby_jobs(
    latitude: float = Body(..., ge=-90, le=90),
    longitude: float = Body(..., ge=-180, le=180),
    radius_km: float = Body(10.0, ge=1, le=500),
    limit: int = Body(50, ge=1, le=200),
    current_user: dict = Depends(get_current_user),
    service: LocationService = Depends(get_location_service)
):
    """
    Get jobs near a location
    Used by Jobs module for location-based job search
    """
    try:
        nearby_jobs = await service.get_nearby_jobs(
            latitude=latitude,
            longitude=longitude,
            radius_km=radius_km,
            limit=limit
        )
        
        return {
            "success": True,
            "data": {
                "jobs": nearby_jobs,
                "total": len(nearby_jobs),
                "radius_km": radius_km,
                "center": {"latitude": latitude, "longitude": longitude}
            },
            "message": f"Found {len(nearby_jobs)} nearby jobs"
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "message": f"Error finding nearby jobs: {str(e)}"
        }


@router.post("/nearby-users")
async def get_nearby_users(
    latitude: float = Body(..., ge=-90, le=90),
    longitude: float = Body(..., ge=-180, le=180),
    radius_km: float = Body(10.0, ge=1, le=500),
    limit: int = Body(50, ge=1, le=200),
    current_user: dict = Depends(get_current_user),
    service: LocationService = Depends(get_location_service)
):
    """
    Get users near a location
    Used by Admin module for analytics
    """
    user_email = current_user.get("email")
    if not user_email:
        raise HTTPException(status_code=400, detail="User email not found")
    
    try:
        nearby_users = await service.get_nearby_users(
            exclude_email=user_email,
            latitude=latitude,
            longitude=longitude,
            radius_km=radius_km,
            limit=limit
        )
        
        return {
            "success": True,
            "data": {
                "users": nearby_users,
                "total": len(nearby_users),
                "radius_km": radius_km
            },
            "message": f"Found {len(nearby_users)} nearby users"
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "message": f"Error finding nearby users: {str(e)}"
        }


@router.get("/stats")
async def get_location_stats(
    current_user: dict = Depends(get_current_user),
    service: LocationService = Depends(get_location_service)
):
    """
    Get location statistics for the platform
    Used by Admin module for analytics
    """
    try:
        stats = await service.get_location_stats()
        return {
            "success": True,
            "data": stats,
            "message": "Location statistics retrieved"
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "message": f"Error getting stats: {str(e)}"
        }


@router.get("/health")
async def location_health(
    service: LocationService = Depends(get_location_service)
):
    """
    Health check for location module
    """
    try:
        status = await service.health_check()
        return {
            "success": True,
            "data": status,
            "message": "Location module is healthy"
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "message": "Location module health check failed"
        }


# ==================== GEOCODING ENDPOINT ====================

@router.post("/geocode")
async def geocode_address(
    request: Request,
    db=Depends(get_db)
):
    """
    Geocode an address to get coordinates
    Uses OpenStreetMap API (FREE)
    This endpoint can be called from frontend to get lat/long for any address
    """
    try:
        body = await request.json()
        address = body.get('address', '')
        
        if not address:
            return {
                "success": False,
                "error": "Address is required",
                "message": "Please provide an address to geocode"
            }
        
        logger.info(f"🌍 Geocoding address: {address}")
        
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(
                "https://nominatim.openstreetmap.org/search",
                params={
                    "q": address,
                    "format": "json",
                    "limit": 1,
                    "countrycodes": "in",
                    "addressdetails": 1,
                    "namedetails": 1,
                    "extratags": 1
                },
                headers={"User-Agent": "rojgarnest/1.0 (https://rojgarnest.com; support@rojgarnest.com)"}
            )
            
            if response.status_code == 200:
                data = response.json()
                if data and len(data) > 0:
                    lat = float(data[0]["lat"])
                    lon = float(data[0]["lon"])
                    address_data = data[0].get("address", {})
                    
                    # Extract location components
                    city = address_data.get("city") or address_data.get("town") or address_data.get("village") or ""
                    district = address_data.get("state_district") or address_data.get("county") or ""
                    state = address_data.get("state") or ""
                    country = address_data.get("country") or "India"
                    
                    logger.info(f"✅ Geocoding success: {lat}, {lon} - {city}, {district}, {state}")
                    
                    return {
                        "success": True,
                        "data": {
                            "latitude": lat,
                            "longitude": lon,
                            "city": city,
                            "district": district,
                            "state": state,
                            "country": country,
                            "display_name": data[0].get("display_name", address),
                            "source": "openstreetmap"
                        },
                        "message": "Address geocoded successfully"
                    }
                else:
                    logger.warning(f"⚠️ No results found for address: {address}")
                    return {
                        "success": False,
                        "error": "Location not found",
                        "message": f"Could not find coordinates for: {address}"
                    }
            else:
                logger.error(f"❌ OSM API error: {response.status_code}")
                return {
                    "success": False,
                    "error": f"Geocoding service error: {response.status_code}",
                    "message": "Failed to geocode address"
                }
            
    except httpx.TimeoutException:
        logger.error("❌ Geocoding timeout")
        return {
            "success": False,
            "error": "Request timeout",
            "message": "Geocoding request timed out. Please try again."
        }
    except Exception as e:
        logger.error(f"❌ Geocoding error: {e}")
        return {
            "success": False,
            "error": str(e),
            "message": "Failed to geocode address"
        }


print("✅ Centralized Location Module Routes Loaded")