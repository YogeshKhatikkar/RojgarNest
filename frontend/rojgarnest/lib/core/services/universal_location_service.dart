// lib/core/services/universal_location_service.dart
// ✅ COMPLETE LOCATION SERVICE - Works on All Platforms

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../utils/platform_utils.dart';

// ✅ Use conditional imports for web only when needed
// For web geolocation, we'll use a simpler approach without the web package

class UniversalLocationService {
  static const int maxAttempts = 3;
  static const int retryDelayMs = 1000;
  static const double minAcceptableAccuracy = 100.0;
  static const double maxAcceptableAccuracy = 10000.0;

  static Future<Map<String, dynamic>> getUniversalLocation() async {
    debugPrint('🌍 UNIVERSAL LOCATION SERVICE STARTED');
    debugPrint('=' * 60);
    debugPrint('📱 Platform: ${PlatformUtils.platformName}');

    Map<String, dynamic>? location;

    // Try GPS first (mobile only)
    if (PlatformUtils.supportsGPS) {
      location = await _getHighAccuracyGps();
      if (location != null && _isValidLocation(location)) {
        debugPrint('✅ Method 1: High Accuracy GPS');
        return await _enrichLocation(location);
      }
    }

    // Try IP Geolocation (fallback for all platforms - simpler and works everywhere)
    location = await _getIpGeolocation();
    if (location != null) {
      debugPrint('⚠️ Method 2: IP Geolocation (Approximate)');
      return await _enrichLocation(location);
    }

    throw Exception(_getHelpMessage());
  }

  /// Method 1: High Accuracy GPS
  static Future<Map<String, dynamic>?> _getHighAccuracyGps() async {
    if (PlatformUtils.isWeb) return null;

    debugPrint('📡 Trying High Accuracy GPS...');

    final hasPermission = await _requestLocationPermission();
    if (!hasPermission) {
      debugPrint('   Location permission denied');
      return null;
    }

    final isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      debugPrint('   GPS is disabled');
      return null;
    }

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 15),
        ).timeout(const Duration(seconds: 20));

        debugPrint('   Attempt $attempt: ${position.latitude}, ${position.longitude}');
        debugPrint('   Accuracy: ${position.accuracy} meters');

        if (position.accuracy < minAcceptableAccuracy &&
            position.latitude != 0.0 &&
            position.longitude != 0.0) {
          final name = await _reverseGeocode(position.latitude, position.longitude);
          return {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'location_name': name ?? '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
            'accuracy': position.accuracy,
            'source': 'gps',
            'confidence': 'high',
          };
        }

        await Future.delayed(Duration(milliseconds: retryDelayMs * attempt));
      } catch (e) {
        debugPrint('   GPS attempt $attempt failed: $e');
      }
    }
    return null;
  }

  /// Method 2: IP Geolocation - Fallback (works on all platforms)
  static Future<Map<String, dynamic>?> _getIpGeolocation() async {
    debugPrint('🌍 Trying IP Geolocation...');

    final List<String> ipServices = [
      'https://ipapi.co/json/',
      'https://ipinfo.io/json',
      'https://api.ipify.org?format=json',
    ];

    for (var service in ipServices) {
      try {
        final response = await http
            .get(Uri.parse(service))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          double lat = 0.0;
          double lon = 0.0;
          String? city;
          String? region;
          String? country;

          if (service.contains('ipapi')) {
            lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
            lon = (data['longitude'] as num?)?.toDouble() ?? 0.0;
            city = data['city'] as String?;
            region = data['region'] as String?;
            country = data['country_name'] as String?;
          } else if (service.contains('ipinfo')) {
            final loc = data['loc']?.toString().split(',') ?? [];
            if (loc.length == 2) {
              lat = double.tryParse(loc[0]) ?? 0.0;
              lon = double.tryParse(loc[1]) ?? 0.0;
            }
            city = data['city'] as String?;
            region = data['region'] as String?;
            country = data['country'] as String?;
          }

          if (lat != 0.0 && lon != 0.0) {
            final locationName = [city, region, country]
                .where((s) => s != null && s.isNotEmpty)
                .join(', ');

            debugPrint('   IP location: $locationName ($lat, $lon)');

            return {
              'latitude': lat,
              'longitude': lon,
              'location_name': locationName.isNotEmpty ? locationName : '$lat, $lon',
              'accuracy': 5000.0,
              'source': 'ip_geolocation',
              'confidence': 'low',
            };
          }
        }
      } catch (e) {
        debugPrint('   IP service $service failed: $e');
      }
    }
    return null;
  }

  static Future<bool> _requestLocationPermission() async {
    if (PlatformUtils.isWeb) return true;

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('⚠️ Location permission denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ Location permission permanently denied');
        return false;
      }

      debugPrint('✅ Location permission granted');
      return true;
    } catch (e) {
      debugPrint('❌ Permission error: $e');
      return false;
    }
  }

  static Future<String?> _reverseGeocode(double lat, double lon) async {
    if (lat == 0.0 && lon == 0.0) return null;

    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?'
            'lat=$lat&lon=$lon&format=json&zoom=18&addressdetails=1'),
        headers: {'User-Agent': 'rojgarnest/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>? ?? {};

        final String village = address['village']?.toString() ?? '';
        final String town = address['town']?.toString() ?? '';
        final String city = address['city']?.toString() ?? '';
        final String district = address['state_district']?.toString() ?? '';
        final String state = address['state']?.toString() ?? '';

        final List<String> parts = [];
        if (village.isNotEmpty) parts.add(village);
        if (town.isNotEmpty && town != village) parts.add(town);
        if (city.isNotEmpty && city != town) parts.add(city);
        if (district.isNotEmpty && district != city) parts.add(district);
        if (state.isNotEmpty && state != district) parts.add(state);

        if (parts.isNotEmpty) {
          return parts.join(', ');
        }

        final String displayName = data['display_name']?.toString() ?? '';
        if (displayName.isNotEmpty) {
          return displayName.split(',').take(3).join(',');
        }
      }
    } catch (e) {
      debugPrint('   Reverse geocoding error: $e');
    }
    return null;
  }

  static bool _isValidLocation(Map<String, dynamic> location) {
    final lat = location['latitude'] as double;
    final lon = location['longitude'] as double;
    final accuracy = location['accuracy'] as double;

    if (lat == 0.0 && lon == 0.0) return false;
    if (lat < -90 || lat > 90) return false;
    if (lon < -180 || lon > 180) return false;
    if (accuracy > maxAcceptableAccuracy) return false;

    return true;
  }

  static Future<Map<String, dynamic>> _enrichLocation(
      Map<String, dynamic> location) async {
    final name = location['location_name'] as String?;
    if (name == null || name.isEmpty || !name.contains(',')) {
      final detailedName = await _reverseGeocode(location['latitude'], location['longitude']);
      if (detailedName != null && detailedName.isNotEmpty) {
        location['location_name'] = detailedName;
      }
    }

    location['timestamp'] = DateTime.now().toIso8601String();
    location['platform'] = PlatformUtils.platformName;

    return location;
  }

  static String _getHelpMessage() {
    return '''
❌ LOCATION UNAVAILABLE

Please try:

📱 MOBILE USERS:
• Turn ON GPS/Location
• Allow location permission

💻 WEB USERS:
• Allow browser location access
• Use Chrome DevTools to set a location

📍 MANUAL ENTRY:
• You can manually enter your location in profile settings
''';
  }
}