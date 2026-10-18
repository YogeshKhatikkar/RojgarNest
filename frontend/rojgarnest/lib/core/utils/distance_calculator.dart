// lib/core/utils/distance_calculator.dart
// COMPLETE DISTANCE CALCULATION BETWEEN TWO COORDINATES

import 'dart:math';

class DistanceCalculator {
  static const double earthRadiusMeters = 6371000.0;
  static const double earthRadiusKm = 6371.0;

  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);
    final deltaLat = _toRadians(lat2 - lat1);
    final deltaLon = _toRadians(lon2 - lon1);

    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  static double calculateDistanceInKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return calculateDistance(lat1, lon1, lat2, lon2) / 1000.0;
  }

  static String formatDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final distanceInMeters = calculateDistance(lat1, lon1, lat2, lon2);

    if (distanceInMeters >= 1000) {
      final km = distanceInMeters / 1000;
      return "${km.toStringAsFixed(2)} km";
    } else {
      return "${distanceInMeters.toStringAsFixed(0)} m";
    }
  }

  static bool isWithinDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
    double thresholdMeters,
  ) {
    return calculateDistance(lat1, lon1, lat2, lon2) <= thresholdMeters;
  }

  static bool areSameLocation(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return isWithinDistance(lat1, lon1, lat2, lon2, 100.0);
  }

  static double _toRadians(double degrees) {
    return degrees * pi / 180;
  }
}