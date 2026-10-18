# app/modules/location/schema.py
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
from datetime import datetime


class LocationFormats(BaseModel):
    """All coordinate formats for a location"""
    dd: str  # Decimal Degrees: "41.403380, 2.174030"
    dms: str  # DMS: "41°24'12.2\"N 2°10'26.5\"E"
    dmm: str  # DMM: "41 24.2028, 2 10.4418"


class LocationDetails(BaseModel):
    """Detailed location information"""
    city: Optional[str] = None
    district: Optional[str] = None
    state: Optional[str] = None
    country: Optional[str] = None
    postal_code: Optional[str] = None


class LocationData(BaseModel):
    """Location data structure"""
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    location_name: str
    location_details: Optional[LocationDetails] = None
    all_formats: Optional[LocationFormats] = None
    source: str = "openstreetmap"
    last_updated: datetime = Field(default_factory=datetime.utcnow)


class SaveLocationRequest(BaseModel):
    """Request to save user location"""
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    location_name: Optional[str] = None


class UpdateLocationRequest(BaseModel):
    """Request to update user location"""
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    location_name: Optional[str] = None
    force_update: bool = False


class GetNearbyRequest(BaseModel):
    """Get nearby jobs/users request"""
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    radius_km: float = Field(10.0, ge=1, le=500)
    limit: int = Field(50, ge=1, le=200)


class DistanceResponse(BaseModel):
    """Distance between two locations"""
    distance_meters: float
    distance_km: float
    formatted_distance: str
    from_location: LocationData
    to_location: LocationData


class LocationResponse(BaseModel):
    """Standard location response"""
    success: bool
    data: Optional[Dict[str, Any]] = None
    message: str
    error: Optional[str] = None