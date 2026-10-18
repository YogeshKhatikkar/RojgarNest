// lib/core/services/location_service.dart
// ZERO HARDCODE - ONLY MOBILE GPS - ALL CURLY BRACES ADDED

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  static Future<bool> checkLocationPermission() async {
    try {
      final LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        final LocationPermission newPermission =
            await Geolocator.requestPermission();
        if (newPermission == LocationPermission.denied) {
          debugPrint('⚠️ Location permission denied');
          return false;
        }
      } else if (permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ Location permission permanently denied');
        return false;
      }

      debugPrint('✅ Location permission granted');
      return true;
    } catch (e) {
      debugPrint('❌ Permission check error: $e');
      return false;
    }
  }

  static Future<bool> isGpsEnabled() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ GPS is disabled');
        return false;
      }
      debugPrint('✅ GPS is enabled');
      return true;
    } catch (e) {
      debugPrint('❌ GPS check error: $e');
      return false;
    }
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      final bool hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        debugPrint('❌ No location permission');
        return null;
      }

      final bool gpsEnabled = await isGpsEnabled();
      if (!gpsEnabled) {
        debugPrint('❌ GPS not enabled');
        return null;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 20),
      );

      debugPrint('📍 GPS Position:');
      debugPrint('   Latitude: ${position.latitude}');
      debugPrint('   Longitude: ${position.longitude}');
      debugPrint('   Accuracy: ${position.accuracy} meters');

      if (position.latitude == 0.0 && position.longitude == 0.0) {
        debugPrint('❌ Invalid position (0,0)');
        return null;
      }

      return position;
    } catch (e) {
      debugPrint('❌ Error getting position: $e');
      return null;
    }
  }

  static Future<String?> getAddressFromCoordinates(
      double lat, double lon) async {
    try {
      debugPrint('🗺️ Reverse geocoding: $lat, $lon');

      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?'
            'lat=$lat&lon=$lon&format=json&zoom=18&addressdetails=1'),
        headers: {'User-Agent': 'rojgarnest/1.0'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final Map<String, dynamic> address = data['address'] ?? {};

        final String city =
            address['city'] ?? address['town'] ?? address['village'] ?? '';

        final String district =
            address['state_district'] ?? address['county'] ?? '';

        final String state = address['state'] ?? '';
        final String country = address['country'] ?? '';

        final List<String> locationParts = [];
        if (city.isNotEmpty) {
          locationParts.add(city);
        }
        if (district.isNotEmpty && district != city) {
          locationParts.add(district);
        }
        if (state.isNotEmpty && state != district) {
          locationParts.add(state);
        }
        if (country.isNotEmpty && country != 'India') {
          locationParts.add(country);
        }

        if (locationParts.isNotEmpty) {
          final locationName = locationParts.join(', ');
          debugPrint('✅ Location: $locationName');
          return locationName;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Reverse geocoding error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      final Position? position = await getCurrentPosition();
      if (position == null) {
        debugPrint('❌ No position available');
        return null;
      }

      final String? address = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'location_name':
            address ?? '${position.latitude}, ${position.longitude}',
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'mobile_gps',
        'is_geocoded': address != null,
      };
    } catch (e) {
      debugPrint('❌ Error getting location: $e');
      return null;
    }
  }

  static Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}
