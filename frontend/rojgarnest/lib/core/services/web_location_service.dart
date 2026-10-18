// lib/core/services/web_location_service.dart
// ZERO HARDCODE - ONLY BROWSER GPS

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class WebLocationService {
  static bool isGeolocationSupported() {
    return kIsWeb;
  }

  static Future<Map<String, dynamic>?> getCurrentLocation() async {
    if (!kIsWeb) {
      debugPrint('❌ Not running on web platform');
      return null;
    }

    debugPrint('🌐 Getting browser GPS location...');

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ Location services disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('⚠️ Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ Location permission permanently denied');
        return null;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );

      debugPrint('📍 Browser GPS position:');
      debugPrint('   Latitude: ${position.latitude}');
      debugPrint('   Longitude: ${position.longitude}');
      debugPrint('   Accuracy: ${position.accuracy} meters');

      if (position.latitude == 0.0 && position.longitude == 0.0) {
        debugPrint('❌ Invalid position (0,0)');
        return null;
      }

      final String? locationName = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'location_name':
            locationName ?? '${position.latitude}, ${position.longitude}',
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'browser_gps',
        'is_geocoded': locationName != null,
      };
    } catch (e) {
      debugPrint('❌ Browser GPS error: $e');
      return null;
    }
  }

  static Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?'
            'lat=$lat&lon=$lon&format=json&zoom=18&addressdetails=1'),
        headers: {'User-Agent': 'rojgarnest/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] ?? {};

        final String city =
            address['city'] ?? address['town'] ?? address['village'] ?? '';

        final String state = address['state'] ?? '';

        final List<String> parts = [];
        if (city.isNotEmpty) parts.add(city);
        if (state.isNotEmpty && state != city) parts.add(state);

        if (parts.isNotEmpty) {
          debugPrint('📍 Location: ${parts.join(', ')}');
          return parts.join(', ');
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Geocoding error: $e');
      return null;
    }
  }
}
