// lib/core/services/real_location_service.dart
// ZERO HARDCODE - ONLY REAL GPS LOCATION - ALL ERRORS FIXED

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class RealLocationService {
  // Fixed: lowerCamelCase constant names
  static const int maxAttempts = 5;
  static const int retryDelayMs = 1000;
  static const double minAcceptableAccuracy = 500.0;

  static Future<Map<String, dynamic>> getRealLocation() async {
    debugPrint('🎯 Getting REAL browser GPS location...');
    debugPrint('=' * 50);

    final bool hasPermission = await _requestLocationPermission();
    if (!hasPermission) {
      throw Exception('Location permission denied');
    }

    final bool gpsEnabled = await _ensureGpsEnabled();
    if (!gpsEnabled && !kIsWeb) {
      throw Exception('GPS is disabled');
    }

    final location = await _getRealGpsLocation();
    if (location == null) {
      throw Exception('Could not get GPS location');
    }

    final locationName =
        await _getRealLocationName(location['latitude'], location['longitude']);

    final result = {
      'latitude': location['latitude'],
      'longitude': location['longitude'],
      'location_name': locationName ??
          _formatCoordinates(location['latitude'], location['longitude']),
      'accuracy': location['accuracy'],
      'timestamp': DateTime.now().toIso8601String(),
      'source': 'real_browser_gps',
      'altitude': location['altitude'],
      'speed': location['speed'],
      'heading': location['heading'],
    };

    debugPrint('✅ REAL LOCATION:');
    debugPrint('   Coordinates: ${result['latitude']}, ${result['longitude']}');
    debugPrint('   Location Name: ${result['location_name']}');
    debugPrint('   Accuracy: ${result['accuracy']} meters');
    debugPrint('=' * 50);

    return result;
  }

  static Future<bool> _requestLocationPermission() async {
    debugPrint('📍 Requesting location permission...');

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('❌ Permission denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ Permission permanently denied');
        if (!kIsWeb) {
          await Geolocator.openAppSettings();
        }
        return false;
      }

      debugPrint('✅ Permission granted');
      return true;
    } catch (e) {
      debugPrint('❌ Permission error: $e');
      return false;
    }
  }

  static Future<bool> _ensureGpsEnabled() async {
    if (kIsWeb) return true;

    debugPrint('📍 Checking GPS status...');

    try {
      final bool isEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isEnabled) {
        debugPrint('⚠️ GPS is disabled');
        await Geolocator.openLocationSettings();
        return false;
      }

      debugPrint('✅ GPS is enabled');
      return true;
    } catch (e) {
      debugPrint('❌ GPS check error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> _getRealGpsLocation() async {
    debugPrint('🛰️ Getting REAL GPS location...');

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      debugPrint('   Attempt $attempt/$maxAttempts');

      try {
        final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 15),
        );

        debugPrint('   Raw GPS: ${position.latitude}, ${position.longitude}');
        debugPrint('   Accuracy: ${position.accuracy} meters');

        if (position.accuracy > minAcceptableAccuracy) {
          debugPrint(
              '   ⚠️ Accuracy too low (${position.accuracy}m), retrying...');
          await Future.delayed(Duration(milliseconds: retryDelayMs));
          continue;
        }

        return {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'altitude': position.altitude,
          'speed': position.speed,
          'heading': position.heading,
        };
      } catch (e) {
        debugPrint('   Error: $e');
        await Future.delayed(Duration(milliseconds: retryDelayMs));
      }
    }

    return null;
  }

  static Future<String?> _getRealLocationName(double lat, double lon) async {
    debugPrint('🗺️ Getting real location name from coordinates...');

    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?'
            'lat=$lat&lon=$lon&format=json&zoom=18&addressdetails=1'),
        headers: {'User-Agent': 'rojgarnest/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final Map<String, dynamic> address = data['address'] ?? {};

        final String city = address['city'] ??
            address['town'] ??
            address['village'] ??
            address['hamlet'] ??
            address['suburb'] ??
            '';

        final String district = address['state_district'] ??
            address['county'] ??
            address['municipality'] ??
            '';

        final String state = address['state'] ?? '';
        final String country = address['country'] ?? '';

        final List<String> parts = [];
        if (city.isNotEmpty) {
          parts.add(city);
        }
        if (district.isNotEmpty && district != city) {
          parts.add(district);
        }
        if (state.isNotEmpty && state != district) {
          parts.add(state);
        }
        if (country.isNotEmpty && country != 'India') {
          parts.add(country);
        }

        if (parts.isNotEmpty) {
          final locationName = parts.join(', ');
          debugPrint('✅ Location name: $locationName');
          return locationName;
        }

        final displayName = data['display_name'];
        if (displayName != null && displayName.isNotEmpty) {
          debugPrint('✅ Using display name: $displayName');
          return displayName;
        }
      }

      debugPrint('⚠️ Could not get location name');
      return null;
    } catch (e) {
      debugPrint('❌ Reverse geocoding error: $e');
      return null;
    }
  }

  static String _formatCoordinates(double lat, double lon) {
    return '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
  }

  static Future<bool> isLocationAvailable() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final LocationPermission permission = await Geolocator.checkPermission();

      return serviceEnabled &&
          permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever;
    } catch (e) {
      return false;
    }
  }

  static Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }
}
