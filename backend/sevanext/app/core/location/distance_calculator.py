# app/core/location/distance_calculator.py
# PYTHON VERSION - BACKEND KE LIYE

import math

class DistanceCalculator:
    EARTH_RADIUS_KM = 6371.0
    EARTH_RADIUS_METERS = 6371000.0

    @staticmethod
    def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """
        दो coordinates के बीच हवाई दूरी निकाले (मीटर में)
        """
        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        delta_lat = math.radians(lat2 - lat1)
        delta_lon = math.radians(lon2 - lon1)

        a = math.sin(delta_lat / 2) ** 2 + \
            math.cos(lat1_rad) * math.cos(lat2_rad) * \
            math.sin(delta_lon / 2) ** 2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

        return DistanceCalculator.EARTH_RADIUS_METERS * c

    @staticmethod
    def calculate_distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """दूरी किलोमीटर में"""
        distance_m = DistanceCalculator.calculate_distance(lat1, lon1, lat2, lon2)
        return distance_m / 1000.0

    @staticmethod
    def format_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> str:
        """सुंदर फॉर्मेट में दूरी"""
        distance_m = DistanceCalculator.calculate_distance(lat1, lon1, lat2, lon2)
        if distance_m >= 1000:
            return f"{distance_m / 1000:.2f} km"
        else:
            return f"{distance_m:.0f} m"

    @staticmethod
    def is_within_distance(lat1: float, lon1: float, lat2: float, lon2: float, threshold_meters: float = 100) -> bool:
        """चेक करे कि दो location threshold के अंदर हैं या नहीं"""
        distance = DistanceCalculator.calculate_distance(lat1, lon1, lat2, lon2)
        return distance <= threshold_meters